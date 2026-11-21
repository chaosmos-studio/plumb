#!/usr/bin/env python3
"""Writes the level feed's bucket (REVAMP_PLAN.md section 6): episode files named by their hash, the rescore file,
manifest.json and its signature, manifest.json.sig (ECDSA P-256 over SHA-256, base64 DER), ready for the server step
to upload as they are. The game checks every byte against a public key it carries (autoload/feed.gd), so a bucket
signed with any other key is refused.

Each episode is a JSON file of boards already measured (TiltBoard's fields plus the metadata of section 4.1: d, par,
w, h, marble_count, colours, set, need, positions, feel), {"format": 1, "id": "ep0001", "boards": [...]}, with board
ids ep0001-01 and on. This tool checks the same fields and ranges the game does before it signs anything.

  tools/publish_levels.py --episodes levels/feed --out build/feed/plumb/v1 \
      --key ../../studio/release-keys/plumb-feed-1.pem [--retired main-0310 ...] [--rescore rescore.json]

The serial is one more than the manifest already in --out, or --serial. The private key is read by path and never
printed. The test fixtures in tests/fixtures/feed/bucket are made the same way with the test key,
studio/release-keys/plumb-feed-test.pem, whose public half (tests/fixtures/feed/test_key.pub.pem) the game trusts only
when a debug build is told to:

  tools/publish_levels.py --episodes tests/fixtures/feed/source --out tests/fixtures/feed/bucket \
      --key ../../studio/release-keys/plumb-feed-test.pem --serial 1 --retired main-0101 \
      --rescore tests/fixtures/feed/rescore.json --issued 2026-11-21T00:00:00Z
"""

import argparse
import base64
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

GAME = "plumb"
FORMAT = 1
RULES = 1
MAX_BYTES = 512 * 1024
MAX_SIDE = 10
MAX_MARBLES = 8
MAX_PAR = 30
MAX_BITS = 60.0
STONE = 9
TILES = {"stop", "gate", "door", "paint", "crack", "portal", "bumper", "switch", "hatch", "key", "lock", "blink",
         "conveyor", "spring", "magnet", "glass", "bounce"}
OTHER_RULES = {"plug", "ice", "locked", "number", "stone", "wrap"}
EPISODE_ID = re.compile(r"^ep[0-9]{4}$")
BOARD_ID = re.compile(r"^ep[0-9]{4}-[0-9]{2,3}$")


def board_problem(b: dict) -> str:
    """What is wrong with a board, as the game's FeedCheck.board sees it, or ""."""
    if not BOARD_ID.match(str(b.get("id", ""))) or int(b.get("rev", 0)) < 1:
        return "id"
    rows = b.get("rows")
    if not isinstance(rows, list) or not rows or len(rows) > MAX_SIDE:
        return "rows"
    w, h = len(rows[0]), len(rows)
    if not 1 <= w <= MAX_SIDE or int(b.get("w", w)) != w or int(b.get("h", h)) != h:
        return "size"
    walls = set()
    for y, row in enumerate(rows):
        if not isinstance(row, str) or len(row) != w:
            return "rows"
        for x, ch in enumerate(row):
            if not (ch in ".#x" or (ch.isdigit() and int(ch) < STONE)):
                return "cell"
            if ch == "#":
                walls.add((x, y))
    marbles = b.get("marbles")
    if not isinstance(marbles, list) or not marbles or len(marbles) > MAX_MARBLES:
        return "marbles"
    taken = set()
    for m in marbles:
        if not isinstance(m, list) or not 3 <= len(m) <= 4:
            return "marble"
        at = (int(m[0]), int(m[1]))
        if not (0 <= at[0] < w and 0 <= at[1] < h) or at in walls or at in taken or not 0 <= int(m[2]) <= STONE:
            return "marble"
        taken.add(at)
    if int(b.get("marble_count", len(marbles))) != len(marbles):
        return "marbles"
    for t in b.get("tiles", []):
        if not isinstance(t, list) or len(t) != 4:
            return "tile"
        if not (0 <= int(t[0]) < w and 0 <= int(t[1]) < h) or str(t[2]) not in TILES | {"plug", "ice"}:
            return "tile"
    if not 1 <= int(b.get("par", 0)) <= MAX_PAR:
        return "par"
    if not 0.0 <= float(b.get("d", -1.0)) <= MAX_BITS:
        return "d"
    if not 0 <= int(b.get("wrap", 0)) <= 3 or not -1 <= int(b.get("locked", -1)) <= 3:
        return "edges"
    if any(str(r) not in TILES | OTHER_RULES for r in b.get("set", [])):
        return "set"
    return ""


def stable(data: object) -> bytes:
    return (json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode()


def put(out: Path, folder: str, stem: str, body: bytes, ext: str = "json") -> dict:
    digest = hashlib.sha256(body).hexdigest()
    name = "%s/%s-%s.%s" % (folder, stem, digest[:8], ext)
    if len(body) > MAX_BYTES:
        sys.exit("%s is %d bytes, over the %d the game takes" % (name, len(body), MAX_BYTES))
    (out / folder).mkdir(parents=True, exist_ok=True)
    (out / name).write_bytes(body)
    return {"file": name, "bytes": len(body), "sha256": digest}


def main() -> None:
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("--episodes", type=Path, required=True, help="a folder of episode JSON files")
    a.add_argument("--out", type=Path, required=True, help="the bucket folder to write (plumb/v1)")
    a.add_argument("--key", type=Path, required=True, help="the private signing key, PEM")
    a.add_argument("--serial", type=int, help="the manifest's serial (default: one more than --out's)")
    a.add_argument("--retired", nargs="*", default=[], help="board ids to take out of future picks")
    a.add_argument("--rescore", type=Path, help='a rescore file, {"boards": {id: {"d": bits, "sd": bits}}}')
    a.add_argument("--issued", help="the issue time, ISO 8601 (default: now), so fixtures stay byte-stable")
    a.add_argument("--app-latest", type=int, help="the update card's version code: the newest build on Play")
    a.add_argument("--app-line", help="the update card's one line of what is new, at most 60 characters")
    a.add_argument("--app-picture", type=Path, help="the update card's picture, a PNG")
    a.add_argument("--urgent-below", type=int, help="versions below this code update at once (Play's immediate flow)")
    a.add_argument("--interstitials", choices=["on", "off"],
                   help="ads between levels: off unless a signed manifest says on (they ship off)")
    args = a.parse_args()

    out: Path = args.out
    serial = args.serial
    if serial is None:
        old = out / "manifest.json"
        serial = json.loads(old.read_text())["serial"] + 1 if old.exists() else 1
    seen: set[str] = set()
    episodes = []
    for path in sorted(args.episodes.glob("*.json")):
        ep = json.loads(path.read_text())
        if ep.get("format") != FORMAT or not EPISODE_ID.match(str(ep.get("id", ""))) or not ep.get("boards"):
            sys.exit("%s is not an episode" % path)
        tiles: set[str] = set()
        low, high = MAX_BITS, 0.0
        for b in ep["boards"]:
            problem = board_problem(b)
            if problem or b["id"] in seen or not b["id"].startswith(ep["id"] + "-"):
                sys.exit("%s: board %s: %s" % (path, b.get("id"), problem or "id repeated or not its episode's"))
            seen.add(b["id"])
            tiles.update(t[2] for t in b.get("tiles", []))
            low, high = min(low, float(b["d"])), max(high, float(b["d"]))
        entry = put(out, "episodes", ep["id"], stable(ep))
        entry.update({"id": ep["id"], "rules": int(ep.get("rules", RULES)), "boards": len(ep["boards"]),
                      "d": [round(low, 2), round(high, 2)], "tiles": sorted(tiles)})
        episodes.append(entry)
    manifest = {"format": FORMAT, "game": GAME, "serial": serial, "rules": RULES,
                "issued": args.issued or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "episodes": episodes, "retired": sorted(args.retired)}
    if args.rescore:
        manifest["rescore"] = put(out, "rescore", "%04d" % serial, stable(json.loads(args.rescore.read_text())))
    if args.app_latest is not None:
        line = (args.app_line or "").strip()
        if len(line) > 60 or ";" in line:
            sys.exit("the card's line is one short sentence: at most 60 characters, no semicolons")
        app = {"latest": args.app_latest, "line": line, "urgent_below": args.urgent_below or 0}
        if args.app_picture:
            body = args.app_picture.read_bytes()
            if not body.startswith(b"\x89PNG\r\n\x1a\n"):
                sys.exit("the card's picture must be a PNG")
            app["picture"] = put(out, "app", str(args.app_latest), body, "png")
        manifest["app"] = app
    if args.interstitials:
        manifest["ads"] = {"interstitials": args.interstitials == "on"}
    body = stable(manifest)
    key = serialization.load_pem_private_key(args.key.read_bytes(), None)
    if not isinstance(key, ec.EllipticCurvePrivateKey) or key.curve.name != "secp256r1":
        sys.exit("the key must be an ECDSA P-256 private key")
    signature = key.sign(body, ec.ECDSA(hashes.SHA256()))
    out.mkdir(parents=True, exist_ok=True)
    (out / "manifest.json").write_bytes(body)
    (out / "manifest.json.sig").write_text(base64.b64encode(signature).decode() + "\n")
    print("published serial %d: %d episodes, %d boards, %d retired%s" % (
        serial, len(episodes), len(seen), len(args.retired), ", a rescore" if args.rescore else ""))


if __name__ == "__main__":
    main()
