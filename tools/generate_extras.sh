#!/bin/bash
# Makes Street's bundled extras into levels/pool.json in N parts side by side (tools/generate_extras.gd), then joins
# them. Run from the project inside one memory-capped scope on this laptop:
#   flock /tmp/godot.lock systemd-run --user --scope -q -p MemoryMax=3G -- tools/generate_extras.sh 4
# then tools/level_meta.sh to measure them.
set -e
N=${1:-4}
for ((k = 0; k < N; k++)); do
  godot --headless --path . -s res://tools/generate_extras.gd -- part=$k/$N > "${TMPDIR:-/tmp}/plumb_extras_$k.log" 2>&1 &
done
wait
godot --headless --path . -s res://tools/generate_extras.gd -- merge=$N 2>&1 | grep GENERATE_EXTRAS
