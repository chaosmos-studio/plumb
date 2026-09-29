"""Writes the game's font: a static instance of the Baloo 2 variable font with its overlaps removed.

Run from the project root: python3 tools/make_font.py   (needs fonttools and skia-pathops)

A variable font keeps overlapping contours so its weights can interpolate, and Godot's glyph rasteriser
shows every overlap as a faint seam across the stems ('h', 'n', 'a', 'i'). Instancing one weight and
merging the overlaps gives the same letters without the seams. The source stays in assets/fonts/source,
which Godot ignores.
"""

import subprocess
import sys

SOURCE = "assets/fonts/source/Baloo2-Variable.ttf"
OUT = "assets/fonts/Baloo2.ttf"
WEIGHT = 400

subprocess.run([sys.executable, "-m", "fontTools.varLib.instancer", SOURCE, "wght=%d" % WEIGHT,
                "--remove-overlaps", "--update-name-table", "-q", "-o", OUT], check=True)
print("wrote", OUT)
