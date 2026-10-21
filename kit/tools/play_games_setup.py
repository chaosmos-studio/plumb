#!/usr/bin/env python3
"""Creates a game's Play Games achievements and leaderboards from kit/play_games/catalog.json, then writes
play_games.json with their ids, which turns Play Games on in the next Android build.

Run from the game's folder, once its Play Games project exists in Play Console:
    python3 kit/tools/play_games_setup.py <project id> [--key ~/.config/chaosmos/studio-ops.json] [--dry-run]

The project id is the number Play Console shows under Play Games Services, Setup and management,
Configuration. The key is a service account invited to Play Console, and the Cloud project it belongs to needs
the Google Play Games Services Publishing API enabled. Anything already there, matched by its English name, is
kept as it is, so the script can run again after the catalog grows. Icons cannot be set this way, since Google
retired the upload: Play Games shows its own until one is added in Play Console.
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

API = "https://www.googleapis.com/games/v1configuration"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
LOCALE = "en-US"
CATALOG = Path("kit/play_games/catalog.json")
IDS = Path("play_games.json")


def token(key_path: Path) -> str:
    key = json.loads(key_path.read_text())
    now = int(time.time())
    claim = {"iss": key["client_email"], "scope": SCOPE, "aud": key["token_uri"], "iat": now, "exp": now + 600}
    signed = jwt.encode(claim, key["private_key"], algorithm="RS256", headers={"kid": key["private_key_id"]})
    body = ("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + signed).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as reply:
        return json.load(reply)["access_token"]


def call(auth: str, method: str, path: str, body: dict | None = None) -> dict:
    request = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                     headers={"Authorization": "Bearer " + auth, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as reply:
            return json.load(reply)
    except urllib.error.HTTPError as error:
        message = json.load(error).get("error", {}).get("message", "")
        sys.exit(f"{method} {path}: HTTP {error.code}: {message}")


def listed(auth: str, path: str) -> list:
    items, page = [], ""
    while True:
        reply = call(auth, "GET", path + (f"?pageToken={page}" if page else ""))
        items += reply.get("items", [])
        page = reply.get("nextPageToken", "")
        if not page:
            return items


def bundle(text: str) -> dict:
    return {"kind": "gamesConfiguration#localizedStringBundle",
            "translations": [{"kind": "gamesConfiguration#localizedString", "locale": LOCALE, "value": text}]}


def english(item: dict) -> str:
    for side in ("published", "draft"):
        for entry in item.get(side, {}).get("name", {}).get("translations", []):
            if entry.get("locale", "").startswith("en"):
                return entry["value"]
    return ""


def achievement(a: dict) -> dict:
    return {"achievementType": "STANDARD", "initialState": "REVEALED",
            "draft": {"name": bundle(a["name"]), "description": bundle(a["text"]), "pointValue": a["points"]}}


def leaderboard(board: dict) -> dict:
    form = {"numberFormatType": board["format"]}
    if board["format"] == "NUMERIC":
        form["numDecimalPlaces"] = 0
        if "suffix" in board:
            one, other = board["suffix"]
            form["suffix"] = {"one": bundle(" " + one), "other": bundle(" " + other)}
    return {"scoreOrder": board["order"], "scoreMin": str(board["min"]), "scoreMax": str(board["max"]),
            "draft": {"name": bundle(board["name"]), "scoreFormat": form}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("app", help="the Play Games project id")
    parser.add_argument("--key", type=Path, default=Path.home() / ".config/chaosmos/studio-ops.json")
    parser.add_argument("--dry-run", action="store_true", help="say what would be made, and make nothing")
    args = parser.parse_args()
    if not CATALOG.exists():
        sys.exit("run this from the game's folder, beside kit/")
    catalog = json.loads(CATALOG.read_text())
    auth = token(args.key)
    ids = {"app": args.app, "leaderboards": {}, "achievements": {}}
    for kind, path, shape in (("leaderboards", "leaderboards", leaderboard), ("achievements", "achievements", achievement)):
        have = {english(item): item["id"] for item in listed(auth, f"/applications/{args.app}/{path}")}
        for entry in catalog[kind]:
            if entry["name"] in have:
                ids[kind][entry["key"]] = have[entry["name"]]
                print(f"kept    {kind[:-1]} {entry['name']}")
            elif args.dry_run:
                print(f"would make {kind[:-1]} {entry['name']}")
            else:
                made = call(auth, "POST", f"/applications/{args.app}/{path}", shape(entry))
                ids[kind][entry["key"]] = made["id"]
                print(f"made    {kind[:-1]} {entry['name']}")
    if args.dry_run:
        return
    IDS.write_text(json.dumps(ids, indent="\t") + "\n")
    print(f"wrote {IDS}: Play Games is on from the next Android build. Publish the draft in Play Console.")


if __name__ == "__main__":
    main()
