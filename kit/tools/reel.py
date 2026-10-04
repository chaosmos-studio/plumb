#!/usr/bin/env python3
"""Records a level's reel as an MP4, the same reel a player opens from a win's snapshot, for the game's
own channels: a title card, the solve with its kicks, and the end card with the QR code to the store.

Run from the game's folder:  python3 kit/tools/reel.py LEVEL [dark|light]
Writes out/reel-<game>-<level>.mp4 at 1080 by 1920, 30 frames a second, with the game's sound.

Movie Maker writes the root viewport, so the size goes in an override.cfg the game never sees otherwise,
removed whatever happens. The game keeps its own layout and stretches to fill the frame.
"""

import os
import subprocess
import sys

GODOT = os.environ.get("GODOT", "godot")
SIZE = (1080, 1920)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    level = int(sys.argv[1])
    look = sys.argv[2] if len(sys.argv) > 2 else ""
    game = os.path.basename(os.getcwd())
    os.makedirs("out", exist_ok=True)
    open(os.path.join("out", ".gdignore"), "a").close()
    avi = os.path.join("out", "reel-%s-%d.avi" % (game, level))
    mp4 = os.path.join("out", "reel-%s-%d%s.mp4" % (game, level, "-" + look if look else ""))
    with open("override.cfg", "w") as f:
        f.write("[display]\n\nwindow/size/window_width_override=%d\nwindow/size/window_height_override=%d\n" % SIZE)
    try:
        args = [GODOT, "--path", ".", "--write-movie", avi, "--fixed-fps", "30", "res://kit/tools/reel.tscn", "--",
                "level=%d" % level]
        if look:
            args.append(look)
        env = dict(os.environ, DISPLAY=os.environ.get("DISPLAY", ":0"))
        subprocess.run(args, env=env, check=True, timeout=600)
    finally:
        os.remove("override.cfg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi, "-c:v", "libx264", "-preset", "slow", "-crf", "18",
                    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", mp4], check=True)
    os.remove(avi)
    print(mp4)


if __name__ == "__main__":
    main()
