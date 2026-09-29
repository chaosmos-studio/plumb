"""Composes a game's Google Play store images from raw captures and a small spec.

Run from the project root, after capturing (godot --path . res://kit/tools/capture.tscn):
  python3 kit/tools/store/compose.py            # reads store/store.json, writes assets/store/

Writes the set the Play Console asks for, at the sizes it asks for (checked 2026-09):
  play_store_icon_512.png                 512x512, 32-bit PNG
  feature_graphic_1024x500.png            1024x500, 24-bit PNG, no alpha
  screenshots/phone/NN_name.png           1080x1920 (9:16), up to 8
  screenshots/tablet7/NN_name.png         1920x1080 (7-inch tablets, 16:9)
  screenshots/tablet10/NN_name.png        1920x1080 (10-inch tablets, 16:9)
  gpg_pc_feature_1920x1080.png            Google Play Games on PC, 16:9, no text
  gpg_pc_logo_600x400.png                 Google Play Games on PC, transparent wordmark
  listing.md                              title, short and full description, release notes, checked
                                          against Play's length limits

Phone shots put a headline and a muted subline over the real game frame, a rounded card that runs off
the bottom edge. Tablet shots are landscape, because Play wants tablet shots at 16:9 or 9:16: the
headline on the left, the game's tablet-shaped frame on the right. The frame is a plain card, not a
phone, since Play asks for no device imagery. The raw frames come from the game's own renderer, so
nothing in them is mocked up. Captions are checked against Play's graphic rules: no ranking, no price,
no call to action.
"""

import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SPEC = "store/store.json"
RAW = "build/store/raw"
OUT = "assets/store"
SUPER = 2  # draw rounded masks at 2x and downsample for clean edges

LIMITS = {"title": 30, "short": 80, "full": 4000}
TABLET = (1920, 1080)
# Play's rules for text in graphics (checked 2026-09): nothing that suggests ranking, price, a Play
# category or a promotion, and no call to action.
BANNED = [r"\bbest\b", r"#1\b", r"\btop\b", r"\bnew\b", r"\bdiscount", r"\bsale\b", r"\bfree\b",
          r"\b(download|install|play|try|get it) now\b"]


def rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def background(size, colours, dark):
    """A quiet vertical gradient: a touch lighter at the top on light brands, a touch deeper at the
    bottom on dark ones."""
    w, h = size
    top = mix(colours["bg"], (255, 255, 255), 0.35) if not dark else mix(colours["bg"], (255, 255, 255), 0.06)
    bottom = colours["bg"] if not dark else mix(colours["bg"], (0, 0, 0), 0.35)
    img = Image.new("RGB", size, colours["bg"])
    px = ImageDraw.Draw(img)
    for y in range(h):
        px.line([(0, y), (w, y)], fill=mix(top, bottom, y / max(1, h - 1)))
    return img


def rounded_mask(size, radius):
    w, h = size
    big = Image.new("L", (w * SUPER, h * SUPER), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, w * SUPER - 1, h * SUPER - 1], radius=radius * SUPER, fill=255)
    return big.resize(size, Image.LANCZOS)


def shadow(canvas, box, radius, blur, alpha, offset=(0, 30)):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
                                            radius=radius, fill=(0, 0, 0, alpha))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def autocrop(img, bg, threshold=18, margin=0.04):
    """Crops to whatever is not background: with the HUD hidden, that is the playfield and its shadow."""
    px = img.load()
    w, h = img.size
    step = max(1, min(w, h) // 400)
    xs, ys = [], []
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return img
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    m = int(max(x1 - x0, y1 - y0) * margin)
    return img.crop((max(0, x0 - m), max(0, y0 - m), min(w, x1 + m), min(h, y1 + m)))


def font(path, size):
    return ImageFont.truetype(path, size)


def wrap(draw, text, face, max_width):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=face) <= max_width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def balanced(draw, text, face, max_width):
    """The fewest lines that fit, then as even as those lines allow, so a headline never ends on one
    stranded word."""
    lines = wrap(draw, text, face, max_width)
    low, high = max_width * 0.4, max_width
    while high - low > 4:
        mid = (low + high) / 2
        if len(wrap(draw, text, face, mid)) == len(lines):
            high = mid
        else:
            low = mid
    return wrap(draw, text, face, high)


def centred_text(draw, text, face, y, width, colour, spacing=1.12, max_width=None):
    lines = balanced(draw, text, face, max_width or width * 0.86)
    size = face.size
    for i, line in enumerate(lines):
        w = draw.textlength(line, font=face)
        draw.text(((width - w) / 2, y + i * size * spacing), line, font=face, fill=colour)
    return y + len(lines) * size * spacing


def card(raw, width, colours, dark):
    """The raw frame as a rounded card with a hairline edge, so it reads as a screen without drawing a
    phone around it."""
    scale = width / raw.width
    screen = raw.resize((width, int(raw.height * scale)), Image.LANCZOS).convert("RGBA")
    radius = width // 14
    framed = Image.new("RGBA", screen.size, (0, 0, 0, 0))
    framed.paste(screen, (0, 0), rounded_mask(screen.size, radius))
    edge = Image.new("RGBA", (screen.width * SUPER, screen.height * SUPER), (0, 0, 0, 0))
    ink = colours["ink"] if not dark else (255, 255, 255)
    ImageDraw.Draw(edge).rounded_rectangle([0, 0, edge.width - 1, edge.height - 1], radius=radius * SUPER,
                                           outline=ink + (26,), width=2 * SUPER)
    framed.alpha_composite(edge.resize(screen.size, Image.LANCZOS))
    return framed


def screenshot(spec, shot, canvas_size, raw_name, fonts, colours, dark):
    raw = Image.open(os.path.join(RAW, raw_name + ".png")).convert("RGB")
    w, h = canvas_size
    canvas = background(canvas_size, colours, dark).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    head = font(fonts["display"], int(w * 0.088))
    sub = font(fonts["ui"], int(w * 0.036))
    y = centred_text(draw, shot["caption"], head, h * 0.075, w, colours["ink"])
    if shot.get("sub"):
        centred_text(draw, shot["sub"], sub, y + h * 0.012, w, colours["muted"], max_width=w * 0.8)
    framed = card(raw, int(w * 0.74), colours, dark)
    x = (w - framed.width) // 2
    top = int(h * 0.285)
    shadow(canvas, (x, top, x + framed.width, top + framed.height), framed.width // 14, 38, 60 if not dark else 140)
    canvas.alpha_composite(framed, (x, top))
    return canvas.convert("RGB")


def tablet_screenshot(spec, shot, raw_name, fonts, colours, dark, size=TABLET):
    """Landscape: the words on the left, the tablet-shaped game frame on the right, running off the
    bottom edge."""
    raw = Image.open(os.path.join(RAW, raw_name + ".png")).convert("RGB")
    w, h = size
    canvas = background(size, colours, dark).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    frame_h = int(h * 1.08)
    framed = card(raw, int(raw.width * frame_h / raw.height), colours, dark)
    x = int(w * 0.93) - framed.width
    top = int(h * 0.1)
    shadow(canvas, (x, top, x + framed.width, top + framed.height), framed.width // 14, 38, 60 if not dark else 140)
    canvas.alpha_composite(framed, (x, top))
    head = font(fonts["display"], int(h * 0.1))
    sub = font(fonts["ui"], int(h * 0.036))
    left, width = int(w * 0.08), x - int(w * 0.14)
    heads = balanced(draw, shot["caption"], head, width)
    subs = wrap(draw, shot.get("sub", ""), sub, width) if shot.get("sub") else []
    block = len(heads) * head.size * 1.12 + (h * 0.03 + len(subs) * sub.size * 1.3 if subs else 0)
    y = (h - block) / 2
    for line in heads:
        draw.text((left, y), line, font=head, fill=colours["ink"])
        y += head.size * 1.12
    y += h * 0.03
    for line in subs:
        draw.text((left, y), line, font=sub, fill=colours["muted"])
        y += sub.size * 1.3
    return canvas.convert("RGB")


def feature(spec, fonts, colours, dark, size=(1024, 500), text=True):
    w, h = size
    canvas = background(size, colours, dark).convert("RGBA")
    hero = Image.open(os.path.join(RAW, spec["feature"]["raw"] + ".png")).convert("RGB")
    crop = spec["feature"].get("crop")
    if crop:
        hero = hero.crop(tuple(int(v) for v in crop))
    elif spec["feature"].get("autocrop", True):
        hero = autocrop(hero, colours["bg"])
    art_h = int(h * (0.86 if text else 0.8))
    art = hero.resize((int(hero.width * art_h / hero.height), art_h), Image.LANCZOS).convert("RGBA")
    art = Image.composite(art, Image.new("RGBA", art.size, (0, 0, 0, 0)), rounded_mask(art.size, art_h // 12))
    angle = spec["feature"].get("tilt", -4)
    art = art.rotate(angle, resample=Image.BICUBIC, expand=True)
    ax = int(w * 0.52) if text else (w - art.width) // 2
    ay = (h - art.height) // 2
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shade.paste((0, 0, 0, 90 if not dark else 150), (ax + 14, ay + 24), art.split()[3])
    canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(22)))
    canvas.alpha_composite(art, (ax, ay))
    if text:
        draw = ImageDraw.Draw(canvas)
        left = int(w * 0.07)
        # A long name shrinks to fit the room left of the art instead of running into it.
        room = ax - left - int(w * 0.04)
        size = int(h * 0.3)
        while size > 40 and ImageDraw.Draw(canvas).textlength(spec["wordmark"], font=font(fonts["display"], size)) > room:
            size -= 4
        mark = font(fonts["display"], size)
        tag = font(fonts["ui"], int(h * 0.058))
        mark_box = draw.textbbox((0, 0), spec["wordmark"], font=mark)
        mark_h = mark_box[3] - mark_box[1]
        top = (h - mark_h) / 2 - h * 0.08
        draw.text((left, top - mark_box[1]), spec["wordmark"], font=mark, fill=colours["ink"])
        draw.text((left + 6, top + mark_h + h * 0.06), spec["tagline"], font=tag, fill=colours["muted"])
    return canvas.convert("RGB")


def logo(spec, fonts, colours, size=(600, 400)):
    w, h = size
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    face = font(fonts["display"], int(h * 0.42))
    box = draw.textbbox((0, 0), spec["wordmark"], font=face)
    tw, th = box[2] - box[0], box[3] - box[1]
    ink = colours["logo"] if "logo" in colours else colours["ink"]
    draw.text(((w - tw) / 2 - box[0], (h - th) / 2 - box[1]), spec["wordmark"], font=face, fill=ink)
    return canvas


def listing(spec):
    text = spec["listing"]
    problems = [k for k, n in LIMITS.items() if len(text.get(k, "")) > n]
    lines = [
        "# Play Store listing: %s" % spec["name"],
        "",
        "Generated by kit/tools/store/compose.py from store/store.json. Limits are checked on every run.",
        "",
        "## App name (%d / %d)" % (len(text["title"]), LIMITS["title"]),
        "", text["title"], "",
        "## Short description (%d / %d)" % (len(text["short"]), LIMITS["short"]),
        "", text["short"], "",
        "## Full description (%d / %d)" % (len(text["full"]), LIMITS["full"]),
        "", text["full"], "",
        "## Release notes", "", text.get("release_notes", ""), "",
        "## Category and tags", "", text.get("category", ""), "",
    ]
    return "\n".join(lines), problems


def policy(spec):
    """Every word that ends up inside a graphic, checked against Play's rules for text in graphics."""
    texts = [spec["wordmark"], spec["tagline"]]
    for shot in spec["phone"] + spec["tablet"]:
        texts += [shot["caption"], shot.get("sub", "")]
    return ["%r matches %s" % (t, b) for t in texts for b in BANNED if re.search(b, t, re.IGNORECASE)]


def main():
    spec = json.load(open(SPEC))
    colours = {k: rgb(v) for k, v in spec["colours"].items()}
    dark = spec.get("dark", False)
    fonts = {"display": spec["fonts"]["display"], "ui": spec["fonts"]["ui"]}
    for sub in ("screenshots/phone", "screenshots/tablet7", "screenshots/tablet10"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    for i, shot in enumerate(spec["phone"]):
        path = os.path.join(OUT, "screenshots/phone/%02d_%s.png" % (i + 1, shot["raw"].replace("phone_", "")))
        screenshot(spec, shot, (1080, 1920), shot["raw"], fonts, colours, dark).save(path)
        print("wrote", path)
    for i, shot in enumerate(spec["tablet"]):
        name = shot["raw"].replace("tablet_", "")
        image = tablet_screenshot(spec, shot, shot["raw"], fonts, colours, dark)
        for folder in ("tablet7", "tablet10"):
            path = os.path.join(OUT, "screenshots/%s/%02d_%s.png" % (folder, i + 1, name))
            image.save(path)
            print("wrote", path)
    feature(spec, fonts, colours, dark).save(os.path.join(OUT, "feature_graphic_1024x500.png"))
    feature(spec, fonts, colours, dark, (1920, 1080), text=False).save(os.path.join(OUT, "gpg_pc_feature_1920x1080.png"))
    logo(spec, fonts, colours).save(os.path.join(OUT, "gpg_pc_logo_600x400.png"))
    icon = Image.open(spec["icon"]).convert("RGBA").resize((512, 512), Image.LANCZOS)
    icon.save(os.path.join(OUT, "play_store_icon_512.png"))
    text, problems = listing(spec)
    open(os.path.join(OUT, "listing.md"), "w").write(text)
    print("wrote feature graphic, pc images, icon and listing.md")
    words = policy(spec)
    for problem in words:
        print("NOT ALLOWED IN A GRAPHIC: %s" % problem)
    if problems:
        print("OVER LIMIT: %s" % ", ".join(problems))
    if problems or words:
        sys.exit(1)


if __name__ == "__main__":
    main()
