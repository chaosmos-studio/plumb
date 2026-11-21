#!/usr/bin/env python3
"""Re-scores Plumb's boards from real play (REVAMP_PLAN.md section 6.4, MATH.md section 29) into a rescore file for
the level feed (tools/publish_levels.py --rescore).

For each board, Analytics has its starts (with the player's rating as each began), its solves and its quits. A board
of rating R is solved by a player of rating mu with probability E = 1 / (1 + 10^((R - mu) / 400)) (the rating's own
model, StreetRating.expected), so the share solved and the players' mean rating give the rating the board played at,
R = mean_mu + 400 log10((1 - p) / p), and its difficulty in bits, (R - 1000) / 50. A board few people played moves
only part of the way from the solver's value, by n / (n + N0), where n is its plays and N0 the plays needed to trust
them halfway. Its deviation narrows the same way. The picker uses the result for future picks only.

    tools/rescore.py --out rescore.json [--days 28] [--stream Plumb]   from GA4, with the studio-ops key
    tools/rescore.py --rows rows.json --out rescore.json                 from rows saved before, or made by hand

Rows are {"board", "starts", "solves", "quits", "rating_sum"} each. The key is read from
~/.config/chaosmos/studio-ops.json and never printed. Google's test devices and Shravan's phone are left out, as
studio/social-media/tools/ga.py does.
"""

import argparse
import json
import math
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

KEY = Path.home() / ".config" / "chaosmos" / "studio-ops.json"
PROPERTY = "558339480"
API = "https://analyticsdata.googleapis.com/v1beta/properties/%s:runReport" % PROPERTY
NOT_PLAYERS = ["OnePlus8Pro", "sdk_gphone64_arm64", "sdk_gphone16k_x86_64", "sdk_gphone64_x86_64", "A142"]
META = Path(__file__).resolve().parent.parent / "levels" / "meta.json"

# As in scripts/street/rating.gd: a board's rating from its bits, and its fixed deviation before real play.
BOARD_BASE = 1000.0
BOARD_PER_BIT = 50.0
BOARD_PHI = 60.0
# The plays needed to trust real play halfway, and the fewest plays worth a line at all.
N0 = 20.0
MIN_PLAYS = 3
# The most real play may move a board from the solver's value, in bits, and the range the feed takes. A share solved
# near all or nothing says little more than "easy" or "hard" for these players, and the cap keeps one odd week of
# data from throwing a board across the whole climb.
MAX_SHIFT = 3.0
MAX_BITS = 60.0


def token() -> str:
    import jwt  # PyJWT, as ga.py uses
    key = json.loads(KEY.read_text())
    now = int(time.time())
    claim = {"iss": key["client_email"], "scope": "https://www.googleapis.com/auth/analytics.readonly",
             "aud": key["token_uri"], "iat": now, "exp": now + 900}
    signed = jwt.encode(claim, key["private_key"], algorithm="RS256", headers={"kid": key["private_key_id"]})
    body = ("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=" + signed).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as reply:
        return json.load(reply)["access_token"]


def from_ga(days: int, stream: str) -> list[dict]:
    """Per board: starts, solves and quits, and the sum of the players' ratings as they started."""
    request = {
        "dateRanges": [{"startDate": "%ddaysAgo" % days, "endDate": "today"}],
        "dimensions": [{"name": "customEvent:board"}, {"name": "eventName"}],
        "metrics": [{"name": "eventCount"}, {"name": "customEvent:rating"}],
        "dimensionFilter": {"andGroup": {"expressions": [
            {"filter": {"fieldName": "eventName", "inListFilter": {"values": ["level_start", "level_end", "level_quit"]}}},
            {"filter": {"fieldName": "streamName", "stringFilter": {"matchType": "CONTAINS", "value": stream,
                                                                    "caseSensitive": False}}},
            {"notExpression": {"filter": {"fieldName": "deviceModel", "inListFilter": {"values": NOT_PLAYERS}}}},
        ]}},
        "limit": 100000,
    }
    req = urllib.request.Request(API, data=json.dumps(request).encode(), method="POST",
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as reply:
            data = json.load(reply)
    except urllib.error.HTTPError as e:
        sys.exit("Data API %s: %s" % (e.code, e.read().decode()[:600]))
    boards: dict[str, dict] = {}
    for r in data.get("rows", []):
        board, event = (v["value"] for v in r["dimensionValues"])
        count, rating = (float(v["value"]) for v in r["metricValues"])
        if not board or board == "(not set)":
            continue
        row = boards.setdefault(board, {"board": board, "starts": 0, "solves": 0, "quits": 0, "rating_sum": 0.0})
        if event == "level_start":
            row["starts"] += int(count)
            row["rating_sum"] += rating
        elif event == "level_end":
            row["solves"] += int(count)
        else:
            row["quits"] += int(count)
    return list(boards.values())


def fit(row: dict, solver_d: float) -> dict | None:
    """The board's re-scored difficulty and deviation in bits, or None with too few plays."""
    n = float(row["starts"])
    if n < MIN_PLAYS:
        return None
    mean_mu = float(row["rating_sum"]) / n
    # The share solved, pulled half a play toward even so a board everyone solved or no one did stays finite.
    p = (min(float(row["solves"]), n) + 0.5) / (n + 1.0)
    played = (mean_mu + 400.0 * math.log10((1.0 - p) / p) - BOARD_BASE) / BOARD_PER_BIT
    weight = n / (n + N0)
    shift = max(-MAX_SHIFT, min(MAX_SHIFT, played - solver_d))
    d = max(0.0, min(MAX_BITS, solver_d + weight * shift))
    sd = BOARD_PHI / BOARD_PER_BIT * math.sqrt(1.0 - weight)
    return {"d": round(d, 3), "sd": round(sd, 3), "n": int(n), "played": round(played, 3)}


def main() -> None:
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--out", type=Path, required=True)
    a.add_argument("--rows", type=Path, help="rows saved before, instead of asking GA4")
    a.add_argument("--save-rows", type=Path, help="also keep the rows GA4 gave")
    a.add_argument("--days", type=int, default=28)
    a.add_argument("--stream", default="Plumb")
    a.add_argument("--meta", type=Path, action="append", default=[META],
                   help="board metadata files with each board's solver difficulty (levels/meta.json and feed episodes)")
    args = a.parse_args()

    solver: dict[str, float] = {}
    for path in args.meta:
        data = json.loads(path.read_text())
        boards = data.get("boards", {})
        if isinstance(boards, dict):
            solver.update({k: float(v["d"]) for k, v in boards.items() if "d" in v})
        else:
            solver.update({b["id"]: float(b["d"]) for b in boards if "d" in b})
    rows = json.loads(args.rows.read_text()) if args.rows else from_ga(args.days, args.stream)
    if args.save_rows:
        args.save_rows.write_text(json.dumps(rows, indent=1) + "\n")
    # A recycled board (main-0310~52) plays as its source, so their plays add up.
    joined: dict[str, dict] = {}
    for row in rows:
        board = row["board"].split("~")[0]
        into = joined.setdefault(board, {"board": board, "starts": 0, "solves": 0, "quits": 0, "rating_sum": 0.0})
        for k in ("starts", "solves", "quits", "rating_sum"):
            into[k] += row.get(k, 0)
    out = {}
    for board, row in joined.items():
        if board not in solver:
            continue
        scored = fit(row, solver[board])
        if scored:
            out[board] = scored
    args.out.write_text(json.dumps({"boards": dict(sorted(out.items()))}, indent=1) + "\n")
    print("re-scored %d boards from %d with plays" % (len(out), len(rows)))
    for board, s in sorted(out.items(), key=lambda kv: -kv[1]["n"])[:12]:
        print("  %-12s n %4d  solver %6.2f  played %6.2f  now %6.2f +- %.2f" % (
            board, s["n"], solver[board], s["played"], s["d"], s["sd"]))


if __name__ == "__main__":
    main()
