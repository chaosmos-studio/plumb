"""Draws Tilt's icon, a glossy coral marble on warm paper, at every size the web build and stores use.

Run from the project root: python3 tools/make_icons.py   (needs Pillow)

Writes web/ (favicons, touch icon, 192/512 app icons) and assets/branding/icon.png (the project icon,
also the source for the Play Store's 512 icon). Drawn at 4x and downsampled, which is the cheap way to
get clean anti-aliased edges out of PIL.
"""

import os

from PIL import Image, ImageDraw, ImageFilter

PAPER = (243, 237, 227)
TRAY = (226, 216, 200)
CORAL = (255, 107, 107)
CORAL_RIM = (199, 83, 83)
SUPER = 4


def icon(size, rounded=True):
    s = size * SUPER
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    radius = int(s * 0.22) if rounded else 0
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius, fill=PAPER)
    inset = int(s * 0.14)
    d.rounded_rectangle([inset, inset, s - inset, s - inset], radius=int(s * 0.12), fill=TRAY)
    # Shadow, rim, body, gloss: the same layering the game draws marbles with.
    cx, cy, r = s * 0.5, s * 0.5, s * 0.25
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([cx - r + s * 0.02, cy - r + s * 0.055, cx + r + s * 0.02, cy + r + s * 0.055],
                                   fill=(60, 45, 30, 70))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(s * 0.02)))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CORAL_RIM)
    b = r * 0.88
    ox, oy = -r * 0.06, -r * 0.08
    d.ellipse([cx + ox - b, cy + oy - b, cx + ox + b, cy + oy + b], fill=CORAL)
    g = r * 0.3
    gx, gy = cx - r * 0.3, cy - r * 0.34
    d.ellipse([gx - g, gy - g, gx + g, gy + g], fill=(255, 255, 255, 128))
    h = r * 0.13
    hx, hy = cx - r * 0.36, cy - r * 0.4
    d.ellipse([hx - h, hy - h, hx + h, hy + h], fill=(255, 255, 255, 220))
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs("web", exist_ok=True)
    os.makedirs("assets/branding", exist_ok=True)
    for size in (16, 32, 48):
        icon(size).save("web/favicon-%d.png" % size)
    icon(48).save("web/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    icon(180, rounded=False).convert("RGB").save("web/apple-touch-icon-180.png")
    icon(192).save("web/icon-192.png")
    icon(512).save("web/icon-512.png")
    icon(512, rounded=False).save("assets/branding/icon.png")
    print("wrote web/ icons and assets/branding/icon.png")


if __name__ == "__main__":
    main()
