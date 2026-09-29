#!/usr/bin/env python3
"""Makes the website's pictures from the real game: phone shots, blog covers and explanatory graphics.

Run from the website folder:  python3 scripts/make_art.py [--force] [--only name,name]

Reads art/art.json. Every picture starts as a capture of the game itself, staged by the game's Director
(tools/director.gd) and rendered by the kit's capture tool, so nothing is mocked up and a picture can be
remade after any change to the game. The captures are then composed into one of these kinds:

  phone    a capture inside a modern 19.5:9 phone, on a transparent background, for the home page
  cover    a 16:9 blog cover: the brand's colours, soft orbs, and a board tilted in on the right
  board    one board on a card, with numbered markers at chosen points and an optional note
  strip    several boards in a row, numbered, with a label under each: a move by move sequence
  compare  two boards side by side, labelled, for a before and after
  turns    one board shown in all eight turns and mirrors, for posts about symmetry
  tree     one board and the four boards a tilt in each direction leads to
  chart    a per-level series from levels/levels.json drawn as a filled line

Pictures are written as WebP (lossy, quality 90) into the paths art.json gives, usually a post's
images/ folder. Astro then makes the responsive sizes. Captures are cached in art/build/raw and only
remade with --force, or when a shot's action changes.
"""

import argparse
import hashlib
import json
import math
import os
import random
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.dirname(HERE)
SPEC = os.path.join(SITE, "art", "art.json")
RAW = os.path.join(SITE, "art", "build", "raw")


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgba(h, a):
    return rgb(h) + (int(a * 255),)


class Art:
    def __init__(self, spec):
        self.spec = spec
        self.game = os.path.normpath(os.path.join(SITE, spec.get("game_dir", "..")))
        self.p = {k: rgb(v) for k, v in spec["palette"].items()}
        fonts = spec["fonts"]
        self.display = os.path.join(self.game, fonts["display"])
        self.ui = os.path.join(self.game, fonts["ui"])
        self.crop_default = spec.get("crop", "auto")

    def font(self, size, display=False):
        return ImageFont.truetype(self.display if display else self.ui, int(size))

    # --- Captures -------------------------------------------------------------------------------------

    def shot_key(self, name):
        s = self.spec["shots"][name]
        size = s.get("size", [1080, 1920])
        return "%s_%s" % (name, hashlib.sha1(json.dumps([s["action"], size]).encode()).hexdigest()[:8])

    def capture(self, names, force):
        os.makedirs(RAW, exist_ok=True)
        want = []
        for n in names:
            path = os.path.join(RAW, self.shot_key(n) + ".png")
            if force or not os.path.exists(path):
                s = self.spec["shots"][n]
                want.append({"name": self.shot_key(n), "size": s.get("size", [1080, 1920]), "action": s["action"]})
        if not want:
            return
        rel = os.path.relpath(SITE, self.game).replace(os.sep, "/")
        spec_path = os.path.join(SITE, "art", "build", "shots.json")
        with open(spec_path, "w") as f:
            json.dump({"shots": want}, f)
        cmd = ["godot", "--path", self.game, "res://kit/tools/capture.tscn", "--",
               "spec=res://%s/art/build/shots.json" % rel, "out=res://%s/art/build/raw" % rel]
        if shutil.which("systemd-run"):
            cmd = ["systemd-run", "--user", "--scope", "--quiet", "-p", "MemoryMax=2G", "-p", "MemorySwapMax=0", "--"] + cmd
        env = dict(os.environ, DISPLAY=os.environ.get("DISPLAY", ":0"))
        print("capturing %d shots" % len(want), flush=True)
        # A capture window that is hidden or minimised can stop rendering; give up rather than hang.
        try:
            out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=60 + 15 * len(want))
        except subprocess.TimeoutExpired:
            sys.exit("capture timed out: keep the capture window visible on DISPLAY=:0 and run again")
        if "CAPTURE_DONE" not in out.stdout:
            sys.exit("capture failed:\n" + out.stdout[-2000:] + out.stderr[-2000:])

    def raw(self, name):
        return Image.open(os.path.join(RAW, self.shot_key(name) + ".png")).convert("RGB")

    def board(self, name, crop=None):
        """The playfield out of a capture: by the art's crop fractions, or by trimming the background."""
        img = self.raw(name)
        crop = crop or self.spec["shots"][name].get("crop") or self.crop_default
        if crop == "auto":
            return autocrop(img, self.p["bg"])
        w, h = img.size
        return img.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))

    # --- Kinds ----------------------------------------------------------------------------------------

    def phone(self, item):
        raw = self.raw(item["shot"])
        sw, sh = raw.size
        # A real phone keeps a status bar under its camera, so the game starts below it.
        status = int(sh * 0.035)
        screen = Image.new("RGB", (sw, sh), raw.getpixel((4, 4)))
        screen.paste(raw.crop((0, 0, sw, sh - status)), (0, status))
        bezel = int(sw * 0.028)
        radius = int(sw * 0.13)
        w, h = sw + bezel * 2, sh + bezel * 2
        pad = int(w * 0.12)
        canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle([pad + 10, pad + int(w * 0.06), pad + w - 10, pad + h + int(w * 0.02)], radius=radius + bezel, fill=(0, 0, 0, 90))
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(w * 0.05)))
        body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(body).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius + bezel, fill=(26, 28, 34, 255), outline=(92, 96, 108, 255), width=max(2, w // 300))
        mask = Image.new("L", screen.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=radius, fill=255)
        body.paste(screen, (bezel, bezel), mask)
        d = ImageDraw.Draw(body)
        hole = int(sw * 0.026)
        cx, cy = w // 2, bezel + status // 2
        d.ellipse([cx - hole, cy - hole, cx + hole, cy + hole], fill=(11, 12, 16, 255))
        canvas.alpha_composite(body, (pad, pad))
        return canvas

    def cover(self, item):
        W, H = 1600, 900
        rng = random.Random(item.get("seed", item["out"]))
        img = self.backdrop((W, H), rng)
        art = self.board(item["shot"])
        art = card(art, int(H * 0.8), self.p, radius=0.05)
        angle = item.get("tilt", rng.choice([-6, -4, 4, 6]))
        art = art.rotate(angle, resample=Image.BICUBIC, expand=True)
        x = int(W * item.get("x", 0.5)) - art.width // 2 + int(W * 0.14)
        y = (H - art.height) // 2
        drop(img, art, (x, y), 40)
        img.alpha_composite(art, (x, y))
        if item.get("badge"):
            self.badge(img, item["badge"], (int(W * 0.07), int(H * 0.1)), size=int(H * 0.06))
        return img

    def backdrop(self, size, rng):
        W, H = size
        img = Image.new("RGBA", size, self.p["bg"] + (255,))
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        g = ImageDraw.Draw(glow)
        for colour in self.spec.get("orbs", ["accent", "gold"]):
            r = rng.randint(int(H * 0.25), int(H * 0.5))
            cx, cy = rng.randint(0, int(W * 0.5)), rng.randint(0, H)
            g.ellipse([cx - r, cy - r, cx + r, cy + r], fill=self.p[colour] + (70,))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(H * 0.12)))
        grid = Image.new("RGBA", size, (0, 0, 0, 0))
        gd = ImageDraw.Draw(grid)
        step = int(H * 0.06)
        line = self.p["ink"] + (14,)
        for x in range(0, W, step):
            gd.line([(x, 0), (x, H)], fill=line, width=1)
        for y in range(0, H, step):
            gd.line([(0, y), (W, y)], fill=line, width=1)
        img.alpha_composite(grid)
        return img

    def board_card(self, item):
        art = self.board(item["shot"])
        target = item.get("height", 1100)
        scale = target / art.height
        art = art.resize((int(art.width * scale), target), Image.LANCZOS)
        d = ImageDraw.Draw(art)
        for m in item.get("marks", []):
            self.mark(d, (m["at"][0] * art.width, m["at"][1] * art.height), m.get("n", ""), art.width * 0.045, m.get("ring", False))
        body = card(art, art.height, self.p, radius=0.04)
        pad = 60
        out = Image.new("RGBA", (body.width + pad * 2, body.height + pad * 2 + (90 if item.get("note") else 0)), self.p["surface"] + (255,))
        drop(out, body, (pad, pad), 24)
        out.alpha_composite(body, (pad, pad))
        if item.get("note"):
            self.caption_line(out, item["note"], out.height - 70)
        return out

    def strip(self, item):
        shots = item["shots"]
        labels = item.get("labels", [""] * len(shots))
        h = item.get("height", 700)
        cards = []
        for n in shots:
            art = self.board(n)
            art = art.resize((int(art.width * h / art.height), h), Image.LANCZOS)
            cards.append(card(art, h, self.p, radius=0.05))
        gap, pad, foot = 70, 60, 120
        W = sum(c.width for c in cards) + gap * (len(cards) - 1) + pad * 2
        out = Image.new("RGBA", (W, h + pad * 2 + foot), self.p["surface"] + (255,))
        d = ImageDraw.Draw(out)
        x = pad
        for i, c in enumerate(cards):
            drop(out, c, (x, pad), 20)
            out.alpha_composite(c, (x, pad))
            self.mark(d, (x + 38, pad + 38), str(i + 1), 30, False)
            f = self.font(40)
            tw = d.textlength(labels[i], font=f)
            d.text((x + (c.width - tw) / 2, pad + h + 34), labels[i], font=f, fill=self.p["ink"])
            if i < len(cards) - 1:
                ax = x + c.width + gap / 2
                ay = pad + h / 2
                d.polygon([(ax - 12, ay - 20), (ax + 14, ay), (ax - 12, ay + 20)], fill=self.p["accent"])
            x += c.width + gap
        return out

    def compare(self, item):
        item = dict(item)
        item.setdefault("labels", ["Before", "After"])
        return self.strip(item)

    def turns(self, item):
        art = self.board(item["shot"])
        size = item.get("size", 360)
        art = art.resize((size, int(art.height * size / art.width)), Image.LANCZOS)
        ops = [lambda a: a, lambda a: a.rotate(90, expand=True), lambda a: a.rotate(180, expand=True), lambda a: a.rotate(270, expand=True),
               lambda a: a.transpose(Image.FLIP_LEFT_RIGHT), lambda a: a.transpose(Image.FLIP_LEFT_RIGHT).rotate(90, expand=True),
               lambda a: a.transpose(Image.FLIP_TOP_BOTTOM), lambda a: a.transpose(Image.FLIP_LEFT_RIGHT).rotate(270, expand=True)]
        tiles = [card(op(art), size, self.p, radius=0.06) for op in ops]
        gap, pad = 40, 60
        cell = max(max(t.width, t.height) for t in tiles)
        out = Image.new("RGBA", (pad * 2 + cell * 4 + gap * 3, pad * 2 + cell * 2 + gap), self.p["surface"] + (255,))
        for i, t in enumerate(tiles):
            cx = pad + (i % 4) * (cell + gap) + (cell - t.width) // 2
            cy = pad + (i // 4) * (cell + gap) + (cell - t.height) // 2
            drop(out, t, (cx, cy), 14)
            out.alpha_composite(t, (cx, cy))
        return out

    def tree(self, item):
        root = self.board(item["root"])
        kids = [self.board(n) for n in item["children"]]
        labels = item.get("labels", ["Left", "Right", "Up", "Down"])
        rh, kh = 520, 360
        root = card(root.resize((int(root.width * rh / root.height), rh), Image.LANCZOS), rh, self.p, radius=0.05)
        kids = [card(k.resize((int(k.width * kh / k.height), kh), Image.LANCZOS), kh, self.p, radius=0.05) for k in kids]
        gap, pad = 50, 70
        W = max(root.width, sum(k.width for k in kids) + gap * (len(kids) - 1)) + pad * 2
        H = pad + rh + 170 + kh + 110 + pad
        out = Image.new("RGBA", (W, H), self.p["surface"] + (255,))
        d = ImageDraw.Draw(out)
        rx = (W - root.width) // 2
        drop(out, root, (rx, pad), 20)
        out.alpha_composite(root, (rx, pad))
        total = sum(k.width for k in kids) + gap * (len(kids) - 1)
        x = (W - total) // 2
        ky = pad + rh + 170
        for k, label in zip(kids, labels):
            d.line([(W / 2, pad + rh + 10), (x + k.width / 2, ky - 12)], fill=self.p["muted"] + (255,), width=4)
            drop(out, k, (x, ky), 16)
            out.alpha_composite(k, (x, ky))
            f = self.font(38)
            tw = d.textlength(label, font=f)
            d.text((x + (k.width - tw) / 2, ky + kh + 26), label, font=f, fill=self.p["ink"])
            x += k.width + gap
        return out

    def chart(self, item):
        W, H = 1600, 820
        levels = json.load(open(os.path.join(self.game, "levels", "levels.json")))["levels"]
        key = item["series"]
        ys = [float(len(l[key])) if isinstance(l[key], list) else float(l[key]) for l in levels]
        img = Image.new("RGBA", (W, H), self.p["surface"] + (255,))
        d = ImageDraw.Draw(img)
        left, right, top, bottom = 150, 70, 110, 130
        lo, top_value = 0.0, max(ys) * 1.08
        whole = all(float(y).is_integer() for y in ys)
        step = nice_step(top_value / 5, whole)
        ticks = max(1, math.ceil(top_value / step))
        hi = step * ticks
        def pt(i, y):
            return (left + (W - left - right) * i / (len(ys) - 1), H - bottom - (H - top - bottom) * (y - lo) / (hi - lo))
        for k in range(ticks + 1):
            y = lo + step * k
            _, py = pt(0, y)
            d.line([(left, py), (W - right, py)], fill=self.p["ink"] + (22,), width=2)
            d.text((left - 20, py), ("%d" % round(y)) if whole else ("%g" % round(y, 1)), font=self.font(30), fill=self.p["muted"], anchor="rm")
        pts = [pt(i, y) for i, y in enumerate(ys)]
        area = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(area).polygon(pts + [(pts[-1][0], H - bottom), (pts[0][0], H - bottom)], fill=self.p["accent"] + (48,))
        img.alpha_composite(area)
        d.line(pts, fill=self.p["accent"], width=6, joint="curve")
        for i in range(0, len(ys), max(1, len(ys) // 6)):
            x, _ = pt(i, lo)
            d.text((x, H - bottom + 30), str(i + 1), font=self.font(30), fill=self.p["muted"], anchor="mt")
        d.text((left, 40), item.get("title", key), font=self.font(46), fill=self.p["ink"])
        d.text(((W + left - right) / 2, H - 50), item.get("x_label", "Level"), font=self.font(32), fill=self.p["muted"], anchor="mm")
        return img

    # --- Drawing helpers ------------------------------------------------------------------------------

    def mark(self, d, at, text, r, ring):
        x, y = at
        if ring:
            d.ellipse([x - r * 1.6, y - r * 1.6, x + r * 1.6, y + r * 1.6], outline=self.p["accent"], width=max(4, int(r * 0.18)))
            return
        d.ellipse([x - r, y - r, x + r, y + r], fill=self.p["accent"])
        if text:
            d.text((x, y + 1), str(text), font=self.font(r * 1.2), fill=self.p.get("accent_ink", (255, 255, 255)), anchor="mm")

    def badge(self, img, text, at, size):
        d = ImageDraw.Draw(img)
        f = self.font(size)
        w = d.textlength(text, font=f)
        x, y = at
        d.rounded_rectangle([x, y, x + w + size * 1.4, y + size * 1.8], radius=size * 0.9, fill=self.p["surface"] + (235,))
        d.text((x + size * 0.7, y + size * 0.9), text, font=f, fill=self.p["ink"], anchor="lm")

    def caption_line(self, img, text, y):
        d = ImageDraw.Draw(img)
        f = self.font(38)
        w = d.textlength(text, font=f)
        d.text(((img.width - w) / 2, y), text, font=f, fill=self.p["muted"])


def nice_step(raw, whole):
    """A tick step of 1, 2 or 5 times a power of ten, whole when the data is whole."""
    power = 10 ** math.floor(math.log10(max(raw, 1e-9)))
    for m in (1, 2, 5, 10):
        if m * power >= raw:
            step = m * power
            return max(1, round(step)) if whole else step
    return raw


def autocrop(img, bg, threshold=24, margin=0.04):
    px = img.load()
    w, h = img.size
    step = max(1, min(w, h) // 300)
    xs, ys = [], []
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > threshold:
                xs.append(x)
                ys.append(y)
    if not xs:
        return img
    m = int(max(max(xs) - min(xs), max(ys) - min(ys)) * margin)
    return img.crop((max(0, min(xs) - m), max(0, min(ys) - m), min(w, max(xs) + m), min(h, max(ys) + m)))


def card(img, height, p, radius=0.05):
    img = img.convert("RGBA")
    if img.height != height:
        img = img.resize((int(img.width * height / img.height), height), Image.LANCZOS)
    r = int(min(img.size) * radius)
    big = Image.new("L", (img.width * 2, img.height * 2), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, img.width * 2 - 1, img.height * 2 - 1], radius=r * 2, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), big.resize(img.size, Image.LANCZOS))
    return out


def drop(canvas, art, at, blur):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    alpha = art.split()[3].point(lambda a: int(a * 0.35))
    layer.paste((0, 0, 0, 255), (at[0] + blur // 3, at[1] + blur // 2), alpha)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(blur)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--force", action="store_true", help="recapture every shot")
    ap.add_argument("--only", default="", help="comma-separated output names to make")
    args = ap.parse_args()
    spec = json.load(open(SPEC))
    art = Art(spec)
    only = [s for s in args.only.split(",") if s]
    items = [i for i in spec["images"] if not only or any(o in i["out"] for o in only)]
    needed = set()
    for i in items:
        for k in ("shot", "root"):
            if k in i:
                needed.add(i[k])
        needed.update(i.get("shots", []))
        needed.update(i.get("children", []))
    art.capture(sorted(needed), args.force)
    kinds = {"phone": art.phone, "cover": art.cover, "board": art.board_card, "strip": art.strip, "compare": art.compare,
             "turns": art.turns, "tree": art.tree, "chart": art.chart}
    for i in items:
        img = kinds[i["kind"]](i)
        out = os.path.join(SITE, i["out"])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if img.mode == "RGBA" and (i["kind"] != "phone" or i.get("flatten")):
            flat = Image.new("RGB", img.size, art.p["surface"])
            flat.paste(img, (0, 0), img)
            img = flat
        width = i.get("width")
        if width and img.width > width:
            img = img.resize((width, int(img.height * width / img.width)), Image.LANCZOS)
        img.save(out, "WEBP", quality=90, method=6)
        print("wrote %s (%dx%d)" % (i["out"], img.width, img.height))


if __name__ == "__main__":
    main()
