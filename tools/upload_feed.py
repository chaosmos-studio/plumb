#!/usr/bin/env python3
"""Uploads a bucket that tools/publish_levels.py wrote to the level feed on Cloudflare (REVAMP_PLAN.md section 6):
the R2 bucket `chaosmos-levels` in the Chaosmos Studio account, served at https://levels.chaosmos.studio/, where
the game reads https://levels.chaosmos.studio/plumb/v1/ (autoload/feed.gd, BASE).

    tools/upload_feed.py build/feed/plumb/v1            what would go up, and the live serial
    tools/upload_feed.py build/feed/plumb/v1 --apply    uploads it

Files named by their hash (episodes, rescores, the update card's picture) go up first and are cached for a year,
since they never change. Then the signature and the manifest, last and close together, cached for five minutes, so
a player never meets a manifest whose files are not there yet. A manifest whose serial is not above the live one is
refused, since the game refuses one too (a rollback). Uploads go through Wrangler, signed in to an account that can
write the bucket. No key is read or sent: the bucket holds only what was signed on this laptop.
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ACCOUNT = "8bc19d12de5e264d90d6667284a711c8"
BUCKET = "chaosmos-levels"
SITE = "https://levels.chaosmos.studio/"
TYPES = {".json": "application/json", ".png": "image/png", ".sig": "text/plain"}
FOREVER = "public, max-age=31536000, immutable"
SHORT = "public, max-age=300"


def live_serial(prefix: str) -> int:
    request = urllib.request.Request(SITE + prefix + "manifest.json", headers={"User-Agent": "chaosmos-feed-upload"})
    try:
        with urllib.request.urlopen(request, timeout=20) as reply:
            return int(json.load(reply).get("serial", 0))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return 0
        raise


def put(key: str, path: Path, cache: str) -> None:
    cmd = ["wrangler", "r2", "object", "put", "%s/%s" % (BUCKET, key), "--file", str(path), "--remote",
           "--content-type", TYPES[path.suffix], "--cache-control", cache]
    result = subprocess.run(cmd, capture_output=True, text=True, env=dict(os.environ, CLOUDFLARE_ACCOUNT_ID=ACCOUNT))
    if result.returncode != 0:
        sys.exit("upload of %s failed: %s" % (key, (result.stderr or result.stdout)[-600:]))
    print("up", key, "(%d bytes)" % path.stat().st_size)


def main() -> None:
    a = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    a.add_argument("bucket", type=Path, help="the folder publish_levels.py wrote, ending in <game>/v<n>")
    a.add_argument("--apply", action="store_true", help="upload; without it, only say what would go up")
    args = a.parse_args()
    root: Path = args.bucket
    manifest = json.loads((root / "manifest.json").read_text())
    prefix = "%s/%s/" % (root.parent.name, root.name)
    if manifest.get("game") != root.parent.name:
        sys.exit("the manifest is for %s, the folder for %s" % (manifest.get("game"), root.parent.name))
    hashed = [p for p in sorted(root.rglob("*")) if p.is_file() and p.parent != root]
    listed = {str(e["file"]) for e in manifest.get("episodes", [])}
    listed |= {str(manifest["rescore"]["file"])} if "rescore" in manifest else set()
    listed |= {str(manifest["app"]["picture"]["file"])} if "picture" in manifest.get("app", {}) else set()
    missing = sorted(f for f in listed if not (root / f).exists())
    if missing:
        sys.exit("the manifest lists files the folder lacks: %s" % ", ".join(missing))
    live = live_serial(prefix)
    print("%s: local serial %d, live serial %d, %d files listed" % (prefix, manifest["serial"], live, len(listed)))
    if manifest["serial"] <= live:
        sys.exit("refused: the live manifest's serial is not below this one, and the game refuses a rollback")
    if not args.apply:
        print("would upload %d hashed files, then manifest.json.sig and manifest.json" % len(hashed))
        return
    for path in hashed:
        put(prefix + path.relative_to(root).as_posix(), path, FOREVER)
    put(prefix + "manifest.json.sig", root / "manifest.json.sig", SHORT)
    put(prefix + "manifest.json", root / "manifest.json", SHORT)
    print("live serial now %d" % live_serial(prefix))


if __name__ == "__main__":
    main()
