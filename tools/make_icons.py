"""The motion is the game's own rule, one swipe moving every marble at once, so the trails all run the same
way. Mint because it is light, stands apart from the dark icons most marble puzzles use, and is the cool
opposite of the warm marbles, so they stand out on it.

Run from the project root: python3 tools/make_icons.py   (needs Pillow)

assets/branding/icon.png is full square, as Play asks, since Play rounds and shadows it itself.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "kit", "tools"))
from adaptive_icon import write_adaptive  # noqa: E402
from icon_draw import (SUPER, PART_SIZE, hexc, finish, rounded, ground, marble, hole, tray, cell,  # noqa: E402
                       trail, write_parts)

MINT = hexc("c9efe6")
# The board in a deeper mint, so ground and board read as one and only the marbles carry colour.
TRAY, TRAY_EDGE = hexc("8fd6c5"), hexc("6fbfac")
CELL, CELL_UNDER = hexc("f3fbf8"), hexc("cfe9e2")
MARBLES = [(hexc("ff6b6b"), hexc("c75353")), (hexc("ffb627"), hexc("c98b10")), (hexc("7c6cf0"), hexc("5a4cc0"))]
TILT = 12.0
ALL = (0, 1, 2)


def board(size, frame=True, holes=ALL, trails=ALL, marbles=ALL):
    return finish(board_large(size, frame, holes, trails, marbles), size)


def board_large(size, frame=True, holes=ALL, trails=ALL, marbles=ALL):
    s = size * SUPER
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    x0, x1 = 0.15 * s, 0.85 * s
    pad, gap = 0.03 * s, 0.018 * s
    side = (x1 - x0 - 2 * pad - 2 * gap) / 3
    if frame:
        tray(img, [x0, x0, x1, x1], int(0.12 * s), TRAY, TRAY_EDGE)
        for i in range(3):
            for j in range(3):
                cx0 = x0 + pad + i * (side + gap)
                cy0 = x0 + pad + j * (side + gap)
                cell(img, [cx0, cy0, cx0 + side, cy0 + side], int(side * 0.24), CELL, CELL_UNDER)
    r = side * 0.37
    row = [x0 + pad + j * (side + gap) + side / 2 for j in range(3)]
    for i, (body, rim) in enumerate(MARBLES):
        cx = x0 + pad + i * (side + gap) + side / 2
        if i in holes:
            hole(img, cx, row[2], r * 1.02, body)
        if i in trails:
            trail(img, (cx, row[0] - side * 0.32), (cx, row[1] + side * 0.06), r, body)
        if i in marbles:
            marble(img, cx, row[1] + side * 0.06, r, body, rim)
    return img.rotate(TILT, resample=Image.BICUBIC, center=(s / 2, s / 2))


def icon(size, rounded_corners=True):
    s = size * SUPER
    img = ground(s, MINT)
    img.alpha_composite(board_large(size))
    return finish(rounded(img) if rounded_corners else img, size)


def parts():
    """intro.gd finds where each marble rolls to from the centre of its hole part."""
    n = PART_SIZE
    out = {"ground": finish(rounded(ground(n * SUPER, MINT)), n), "board": board(n, holes=ALL, trails=(), marbles=())}
    for i in ALL:
        out["trail_%d" % i] = board(n, frame=False, holes=(), trails=(i,), marbles=())
        out["marble_%d" % i] = board(n, frame=False, holes=(), trails=(), marbles=(i,))
        out["hole_%d" % i] = board(n, frame=False, holes=(i,), trails=(), marbles=())
    return out


def main():
    os.makedirs("web", exist_ok=True)
    os.makedirs("assets/branding", exist_ok=True)
    for size in (16, 32, 48):
        icon(size).save("web/favicon-%d.png" % size)
    icon(48).save("web/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    icon(180, rounded_corners=False).convert("RGB").save("web/apple-touch-icon-180.png")
    icon(192).save("web/icon-192.png")
    icon(512).save("web/icon-512.png")
    icon(512, rounded_corners=False).save("assets/branding/icon.png")
    write_adaptive(lambda n: board(n), lambda n: finish(ground(n * SUPER, MINT), n))
    write_parts(parts())
    print("wrote web/ icons, assets/branding/icon.png, the adaptive icon layers and the intro's parts")


if __name__ == "__main__":
    main()
