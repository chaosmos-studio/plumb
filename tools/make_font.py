"""Writes the game's fonts: static instances of the Outfit variable font with their overlaps removed.

Run from the project root: python3 tools/make_font.py   (needs fonttools and skia-pathops)

A variable font keeps overlapping contours so its weights can interpolate, and Godot's glyph rasteriser
shows every overlap as a faint seam across the stems. Instancing one weight and merging the overlaps
gives the same letters without the seams. The UI kit uses two weights: light for display text, medium
for everything else. The source stays in assets/fonts/source, which Godot ignores.
"""

import subprocess
import sys

SOURCE = "assets/fonts/source/Outfit-Variable.ttf"
WEIGHTS = {"assets/fonts/Outfit-Light.ttf": 300, "assets/fonts/Outfit-Medium.ttf": 500}

for out, weight in WEIGHTS.items():
    subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", SOURCE, "wght=%d" % weight,
                    "--remove-overlaps", "--update-name-table", "-q", "-o", out], check=True)
    print("wrote", out)
