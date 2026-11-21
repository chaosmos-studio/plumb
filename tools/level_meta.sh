#!/bin/bash
# Measures every bundled board into levels/meta.json in N parts side by side (tools/level_meta.gd), then joins them.
# Run from the project: tools/level_meta.sh [N]   (default 4). Run it inside one memory-capped scope on this laptop:
#   flock /tmp/godot.lock systemd-run --user --scope -q -p MemoryMax=3G -- tools/level_meta.sh 4
set -e
N=${1:-4}
for ((k = 0; k < N; k++)); do
  godot --headless --path . -s res://tools/level_meta.gd -- part=$k/$N > "${TMPDIR:-/tmp}/plumb_meta_$k.log" 2>&1 &
done
wait
godot --headless --path . -s res://tools/level_meta.gd -- merge=$N 2>&1 | grep LEVEL_META
