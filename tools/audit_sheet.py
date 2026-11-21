#!/usr/bin/env python3
"""M6's audit sheet (REVAMP_PLAN.md, M6 step 1): every screen a player can reach from Street on one page per screen
shape, Street's own screens tagged green and the kit's Classic screens red, each with the count of labels that run
out of their boxes, then each concept beside today's screen. Reads what `tools/street_shots.tscn -- audit ...` wrote.

    tools/audit_sheet.py 1080x2400        writes build/review/m6/audit/index-1080x2400.png and its .txt
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REVIEW = ROOT / "build" / "review"
STREET = ["1-chooser", "2-map", "3-card", "4-play", "5-win-home", "6-win-stars", "11-gift", "14-milestone-rise",
          "17-card-helpers", "18-play-helpers", "19-shop", "20-settings", "21-settings-access", "22-colour-help",
          "23-update-card"]
CONCEPTS = [("1-map", "2-map"), ("2-start", "3-card"), ("3-play", "4-play"), ("4-win", "5-win-home"),
            ("5-gift", "11-gift"), ("6-shop", "19-shop"), ("7-settings", "20-settings")]
GREEN, RED, INK, PAPER = (46, 160, 67), (214, 60, 52), (40, 40, 40), (246, 244, 238)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in ["/usr/share/fonts/google-noto/NotoSans-Bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf"]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def thumb(path: Path, box: tuple[int, int]) -> Image.Image:
    im = Image.open(path).convert("RGB")
    im.thumbnail(box)
    return im


def tile(im: Image.Image, title: str, tag: str, colour: tuple[int, int, int], note: str, width: int) -> Image.Image:
    out = Image.new("RGB", (width, im.size[1] + 118), PAPER)
    out.paste(im, ((width - im.size[0]) // 2, 0))
    d = ImageDraw.Draw(out)
    d.rectangle([0, im.size[1] + 8, width, im.size[1] + 48], fill=colour)
    d.text((10, im.size[1] + 14), tag, fill=(255, 255, 255), font=font(24))
    d.text((10, im.size[1] + 54), title, fill=INK, font=font(24))
    if note:
        d.text((10, im.size[1] + 84), note, fill=RED, font=font(22))
    return out


def grid(tiles: list[Image.Image], cols: int, gap: int = 24) -> Image.Image:
    w = max(t.size[0] for t in tiles)
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    hs = [max(t.size[1] for t in r) for r in rows]
    out = Image.new("RGB", (cols * (w + gap) + gap, sum(hs) + gap * (len(rows) + 1)), PAPER)
    y = gap
    for r, h in zip(rows, hs):
        for i, t in enumerate(r):
            out.paste(t, (gap + i * (w + gap), y))
        y += h + gap
    return out


def heading(text: str, width: int) -> Image.Image:
    out = Image.new("RGB", (width, 90), PAPER)
    ImageDraw.Draw(out).text((24, 22), text, fill=INK, font=font(44))
    return out


def main() -> None:
    size = sys.argv[1]
    w, h = (int(v) for v in size.split("x"))
    box = (300, 660) if h > w else (640, 300)
    cols = 6 if h > w else 3
    audit = REVIEW / "m6" / "audit" / size
    street_over: dict = json.loads((audit / "street-report.json").read_text())
    kit = json.loads((audit / "report.json").read_text())
    lines = []
    tiles = []
    for name in STREET:
        path = REVIEW / "street" / size / (name + ".png")
        if not path.exists():
            continue
        over = street_over.get(name, [])
        tiles.append(tile(thumb(path, box), name, "Street", GREEN, "%d labels out of their boxes" % len(over) if over else "",
                          box[0] + 20))
        lines += ["%s: %s" % (name, o) for o in over]
    kit_tiles = []
    for entry in kit:
        over = entry["overflow"]
        kit_tiles.append(tile(thumb(audit / (entry["name"] + ".png"), box), entry["name"], "Classic kit", RED,
                              "%d labels out of their boxes" % len(over) if over else "", box[0] + 20))
        lines += ["%s: %s" % (entry["name"], o) for o in over]
    pairs = []
    for concept, shot in CONCEPTS:
        c = REVIEW / "revamp2" / (concept + ".png")
        s = REVIEW / "street" / size / (shot + ".png")
        if c.exists() and s.exists():
            pairs.append(tile(thumb(c, box), "concept " + concept, "Concept", (120, 120, 120), "", box[0] + 20))
            pairs.append(tile(thumb(s, box), "today " + shot, "Street", GREEN, "", box[0] + 20))
    parts = [grid(tiles, cols), grid(kit_tiles, cols), grid(pairs, cols if h > w else 2)]
    width = max(p.size[0] for p in parts)
    sections = [heading("Street's own screens (%s)" % size, width), parts[0],
                heading("Kit screens a Street player still reaches: Classic's look", width), parts[1],
                heading("Each concept beside today's screen", width), parts[2]]
    sheet = Image.new("RGB", (width, sum(s.size[1] for s in sections)), PAPER)
    y = 0
    for s in sections:
        sheet.paste(s, (0, y))
        y += s.size[1]
    out = REVIEW / "m6" / "audit" / ("index-%s.png" % size)
    sheet.save(out, optimize=True)
    (REVIEW / "m6" / "audit" / ("index-%s.txt" % size)).write_text("\n".join(lines) + "\n")
    print(out, sheet.size, "%d labels out of their boxes" % len(lines))


if __name__ == "__main__":
    main()
