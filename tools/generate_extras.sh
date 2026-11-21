#!/bin/bash
# Makes Street's bundled extras into levels/pool.json in N parts side by side (tools/generate_extras.gd), then joins
# them. Run from the project inside one memory-capped scope on this laptop:
#   flock /tmp/godot.lock systemd-run --user --scope -q -p MemoryMax=3G -- tools/generate_extras.sh 4 [round]
# then tools/level_meta.sh to measure them. Round 2 appends the denser stretch to the file round 1 wrote.
set -e
N=${1:-4}
R=${2:-1}
for ((k = 0; k < N; k++)); do
  godot --headless --path . -s res://tools/generate_extras.gd -- part=$k/$N round=$R > "${TMPDIR:-/tmp}/plumb_extras_r${R}_$k.log" 2>&1 &
done
wait
godot --headless --path . -s res://tools/generate_extras.gd -- merge=$N round=$R 2>&1 | grep GENERATE_EXTRAS
