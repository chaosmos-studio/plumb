#!/usr/bin/env python3
"""Registers Plumb 2.0's custom definitions in GA4 (REVAMP_PLAN.md section 5.3) through the Admin API, as the
studio-ops service account, before the first build that sends them: registration is not retroactive.

    tools/ga4_definitions.py            lists what is registered and what would be added
    tools/ga4_definitions.py --apply    adds what is missing

Every game is a stream in one property (558339480), so a definition serves them all. Names already registered are
left as they are. The key is read from ~/.config/chaosmos/studio-ops.json and never printed. GA4 reserves some
names for its own reports (`currency` among them, so the shop says `paid_with`).
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY = Path.home() / ".config" / "chaosmos" / "studio-ops.json"
PROPERTY = "558339480"
ADMIN = "https://analyticsadmin.googleapis.com/v1beta/properties/%s/" % PROPERTY

USER = ["app_look", "player_id", "rating_band", "furthest_level", "feed_serial"]
EVENT = ["board", "path", "pick", "booster", "how", "gift", "family", "look", "from", "setting", "value", "update",
         "mode", "version", "stage", "feed", "paid_with", "replay", "item", "kind", "format", "network"]
METRICS = ["difficulty", "rating", "moves", "par", "hints", "undos", "restarts", "boosters", "coins", "price", "added",
           "count"]


def token() -> str:
    import jwt  # PyJWT, as studio/social-media/tools/ga.py uses
    key = json.loads(KEY.read_text())
    now = int(time.time())
    claim = {"iss": key["client_email"], "scope": "https://www.googleapis.com/auth/analytics.edit",
             "aud": key["token_uri"], "iat": now, "exp": now + 900}
    signed = jwt.encode(claim, key["private_key"], algorithm="RS256", headers={"kid": key["private_key_id"]})
    body = ("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + signed).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as reply:
        return json.load(reply)["access_token"]


def call(auth: str, method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(ADMIN + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + auth, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as reply:
            return json.load(reply)
    except urllib.error.HTTPError as e:
        sys.exit("Admin API %s on %s: %s" % (e.code, path, e.read().decode()[:600]))


def listed(auth: str, kind: str) -> list[dict]:
    out, page = [], ""
    while True:
        data = call(auth, "GET", kind + "?pageSize=200" + ("&pageToken=" + page if page else ""))
        out += data.get(kind, [])
        page = data.get("nextPageToken", "")
        if not page:
            return out


def title(name: str) -> str:
    return name.replace("_", " ").capitalize()


def main() -> None:
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--apply", action="store_true", help="add the missing definitions")
    args = a.parse_args()
    auth = token()
    dims = listed(auth, "customDimensions")
    mets = listed(auth, "customMetrics")
    have_user = {d["parameterName"] for d in dims if d.get("scope") == "USER"}
    have_event = {d["parameterName"] for d in dims if d.get("scope") == "EVENT"}
    have_metric = {m["parameterName"] for m in mets}
    print("registered: %d event dimensions, %d user dimensions, %d metrics" % (len(have_event), len(have_user),
                                                                               len(have_metric)))
    adds = [("customDimensions", {"parameterName": n, "displayName": title(n), "scope": "USER"})
            for n in USER if n not in have_user]
    adds += [("customDimensions", {"parameterName": n, "displayName": title(n), "scope": "EVENT"})
             for n in EVENT if n not in have_event]
    adds += [("customMetrics", {"parameterName": n, "displayName": title(n), "scope": "EVENT",
                                "measurementUnit": "STANDARD"}) for n in METRICS if n not in have_metric]
    for kind, body in adds:
        print("%s %s %s (%s)" % ("adding" if args.apply else "missing", kind, body["parameterName"], body["scope"]))
        if args.apply:
            call(auth, "POST", kind, body)
    if not adds:
        print("nothing to add")


if __name__ == "__main__":
    main()
