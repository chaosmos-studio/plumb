"""Drawing pieces the games' icon scripts share: glossy marbles and dots, sunk-in holes, a board and its
cells, soft trails, strokes with round caps and filled arrowheads.

Every function draws on an RGBA image with coordinates in pixels; the scripts work in fractions of the
icon's side and multiply up. Draw at SUPER times the final size and downsample, the cheap way to clean
anti-aliased edges in PIL. Shapes go on their own layers where they are translucent, because ImageDraw
replaces pixels rather than blending them.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SUPER = 4
## The size the launch flourish's parts are written at.
PART_SIZE = 512


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def layer(img):
    return Image.new("RGBA", img.size, (0, 0, 0, 0))


def finish(img, size):
    return img.resize((size, size), Image.LANCZOS)


def rounded(img, share=0.22):
    """The icon with rounded corners, for the web's favicons and app icons. Play rounds its own."""
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=int(img.width * share), fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def ground(s, colour, lift=0.06):
    """A full-bleed backdrop, a touch lighter in the middle so the motif sits in a soft light."""
    img = Image.new("RGBA", (s, s), colour)
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    r = s * 0.42
    ImageDraw.Draw(glow).ellipse([s / 2 - r, s / 2 - r, s / 2 + r, s / 2 + r], fill=(255, 255, 255, int(255 * lift)))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(s * 0.12)))
    return img


def shadow(img, draw_shape, dy, blur, alpha, colour=(40, 50, 45)):
    sh = layer(img)
    draw_shape(ImageDraw.Draw(sh), dy, colour + (alpha,))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))


def marble(img, cx, cy, r, body, rim, cast=True):
    """The game's marble: a darker rim, the body set a little up and left, and two gloss spots."""
    if cast:
        shadow(img, lambda d, dy, c: d.ellipse([cx - r * 0.92, cy - r * 0.92 + dy, cx + r * 0.92, cy + r * 0.92 + dy], fill=c),
               r * 0.26, r * 0.14, 70)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rim)
    b = r * 0.88
    d.ellipse([cx - r * 0.06 - b, cy - r * 0.08 - b, cx - r * 0.06 + b, cy - r * 0.08 + b], fill=body)
    g = layer(img)
    gd = ImageDraw.Draw(g)
    q = r * 0.3
    gd.ellipse([cx - r * 0.32 - q, cy - r * 0.36 - q, cx - r * 0.32 + q, cy - r * 0.36 + q], fill=(255, 255, 255, 120))
    q = r * 0.12
    gd.ellipse([cx - r * 0.38 - q, cy - r * 0.42 - q, cx - r * 0.38 + q, cy - r * 0.42 + q], fill=(255, 255, 255, 235))
    img.alpha_composite(g)


def hole(img, cx, cy, r, ring, well=hexc("2f333d")):
    """A ring in the marble's colour round a dark well, shaded inside so it reads as sunk in."""
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ring)
    i = r * 0.74
    d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=well)
    inner = layer(img)
    idr = ImageDraw.Draw(inner)
    idr.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(8, 10, 16, 150))
    idr.ellipse([cx - i * 0.92, cy - i * 0.72, cx + i * 0.92, cy + i * 1.08], fill=(0, 0, 0, 0))
    img.alpha_composite(inner.filter(ImageFilter.GaussianBlur(i * 0.08)))


def tray(img, box, radius, top, edge, cast_alpha=55):
    """A raised board: its shadow, a darker lip below, and the face."""
    shadow(img, lambda d, dy, c: d.rounded_rectangle([box[0], box[1] + dy, box[2], box[3] + dy], radius=radius, fill=c),
           (box[3] - box[1]) * 0.03, (box[3] - box[1]) * 0.035, cast_alpha)
    d = ImageDraw.Draw(img)
    lip = (box[3] - box[1]) * 0.014
    d.rounded_rectangle([box[0], box[1] + lip, box[2], box[3] + lip], radius=radius, fill=edge)
    d.rounded_rectangle(box, radius=radius, fill=top)


def cell(img, box, radius, face, under):
    d = ImageDraw.Draw(img)
    drop = (box[3] - box[1]) * 0.02
    d.rounded_rectangle([box[0], box[1] + drop, box[2], box[3] + drop], radius=radius, fill=under)
    d.rounded_rectangle(box, radius=radius, fill=face)


def trail(img, tail, head, r, colour):
    """A soft streak from `tail` to a marble of radius `r` at `head`, widening and strengthening toward it."""
    g = layer(img)
    gd = ImageDraw.Draw(g)
    n = 48
    for k in range(n):
        t = k / (n - 1)
        x = tail[0] + (head[0] - tail[0]) * t
        y = tail[1] + (head[1] - tail[1]) * t
        rr = r * (0.3 + 0.7 * t)
        gd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=colour[:3] + (int(14 + 110 * t ** 1.5),))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(r * 0.12)))


def dot(img, cx, cy, r, colour):
    """A bell or a sun: a flat disc with one soft gloss, and a darker rim for a little roundness."""
    d = ImageDraw.Draw(img)
    rim = tuple(max(0, int(c * 0.8)) for c in colour[:3]) + (255,)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rim)
    b = r * 0.9
    d.ellipse([cx - r * 0.05 - b, cy - r * 0.07 - b, cx - r * 0.05 + b, cy - r * 0.07 + b], fill=colour)
    g = layer(img)
    q = r * 0.34
    ImageDraw.Draw(g).ellipse([cx - r * 0.3 - q, cy - r * 0.34 - q, cx - r * 0.3 + q, cy - r * 0.34 + q], fill=(255, 255, 255, 120))
    q = r * 0.12
    ImageDraw.Draw(g).ellipse([cx - r * 0.36 - q, cy - r * 0.42 - q, cx - r * 0.36 + q, cy - r * 0.42 + q], fill=(255, 255, 255, 220))
    img.alpha_composite(g)


def stroke(img, pts, colour, w):
    """A polyline with round caps and joins."""
    g = layer(img)
    d = ImageDraw.Draw(g)
    d.line(pts, fill=colour, width=int(w), joint="curve")
    for p in (pts[0], pts[-1]):
        d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=colour)
    img.alpha_composite(g)


def arrowhead(img, tip, angle, size, colour, width=0.62):
    """A filled arrowhead with its point at `tip`, facing `angle` in radians."""
    d = ImageDraw.Draw(img)
    back = (tip[0] - size * math.cos(angle), tip[1] - size * math.sin(angle))
    side = (math.cos(angle + math.pi / 2) * size * width, math.sin(angle + math.pi / 2) * size * width)
    d.polygon([tip, (back[0] + side[0], back[1] + side[1]), (back[0] - side[0], back[1] - side[1])], fill=colour)


def write_parts(parts, folder="assets/branding/intro"):
    """The icon's parts for the launch flourish (kit Intro): name to image, each full frame at the icon's
    size and drawn where it sits in the icon, so laid one over another they make the icon again."""
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        if old.endswith(".png") and old[:-4] not in parts:
            os.remove(os.path.join(folder, old))
            if os.path.exists(os.path.join(folder, old + ".import")):
                os.remove(os.path.join(folder, old + ".import"))
    for name, img in parts.items():
        img.save(os.path.join(folder, name + ".png"))


def ellipse_points(cx, cy, rx, ry, tilt, a0, a1, n=160):
    """Points on an ellipse tilted by `tilt` degrees, from angle a0 to a1 in degrees."""
    t = math.radians(tilt)
    out = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * math.cos(t) - y * math.sin(t), cy + x * math.sin(t) + y * math.cos(t)))
    return out
