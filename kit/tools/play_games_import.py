#!/usr/bin/env python3
"""Writes build/play_games/achievements.zip, the file Play Console's Import achievements takes: every achievement
in kit/play_games/catalog.json with a 512 px icon drawn in the game's own colours (brand.gd's native palette).
Also an icon for each leaderboard, leaderboard_<key>.png, since leaderboards have no import and are made by hand.

Run from the game's folder: python3 kit/tools/play_games_import.py
Then Play Console: Play Games Services, Achievements, Import achievements, upload the zip, Save as draft.

The CSVs have no header row and no commas in a name or description, as the import requires. Play Games shows an
icon inside a circle and makes the locked one grey by itself, so each icon is one bold glyph on a full-bleed fill.
"""

import csv
import io
import json
import re
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CATALOG = Path("kit/play_games/catalog.json")
OUT = Path("build/play_games")
SIZE = 512
SCALE = 4
FONT = Path("assets/fonts/Outfit-Medium.ttf")


def palette() -> dict:
    """The native palette's colours from brand.gd, as hex strings."""
    text = Path("brand.gd").read_text()
    dark = re.search(r"const NATIVE_DARK: bool = (\w+)", text).group(1) == "true"
    block = re.search(r"const %s: Dictionary = \{(.*?)\n\}" % ("DARK" if dark else "LIGHT"), text, re.S).group(1)
    return {k: "#" + v for k, v in re.findall(r'"(\w+)": Color\("([0-9a-fA-F]{6})"\)', block)}


def luminance(hex_colour: str) -> float:
    def channel(c: int) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def star_colour(colours: dict) -> str:
    """Gold where it stands out from the fill, as the game's stars do, and the ink where it would not."""
    gold, fill = colours.get("gold", colours["accent_ink"]), colours["accent"]
    hi, lo = sorted((luminance(gold), luminance(fill)), reverse=True)
    return gold if (hi + 0.05) / (lo + 0.05) >= 2.0 else colours["accent_ink"]


def star(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str) -> None:
    import math
    points = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        points.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(points, fill=fill)


def flame(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str, hole: str) -> None:
    import math

    def shape(tip_y: float, base_r: float, base_y: float, lean: float) -> list:
        # The tip leans right of the base, the left side swells out on its way down and the right side has a
        # notch, so it reads as a flame and not a drop.
        tip_x = cx + lean
        pts = []
        for k in range(21):
            u = k / 20
            swell = math.sin(u * math.pi) * base_r * 0.28
            pts.append((tip_x + (cx - base_r - tip_x) * u - swell, tip_y + (base_y - tip_y) * u))
        for k in range(1, 20):
            a = math.pi - k / 20 * math.pi
            pts.append((cx + math.cos(a) * base_r, base_y + math.sin(a) * base_r))
        for k in range(21):
            u = 1 - k / 20
            notch = math.sin(u * math.pi * 2) * base_r * 0.12
            pts.append((tip_x + (cx + base_r - tip_x) * u + notch, tip_y + (base_y - tip_y) * u))
        return pts
    draw.polygon(shape(cy - r, r * 0.62, cy + r * 0.25, r * 0.22), fill=fill)
    draw.polygon(shape(cy - r * 0.05, r * 0.27, cy + r * 0.47, r * 0.1), fill=hole)


def calendar(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str, hole: str) -> None:
    w = r * 1.5
    h = r * 1.35
    box = (cx - w / 2, cy - h / 2 + r * 0.1, cx + w / 2, cy + h / 2 + r * 0.1)
    draw.rounded_rectangle(box, radius=r * 0.18, fill=fill)
    draw.rectangle((box[0] + r * 0.14, box[1] + r * 0.42, box[2] - r * 0.14, box[3] - r * 0.14), fill=hole)
    for dx in (-0.38, 0.38):
        draw.rounded_rectangle((cx + dx * r - r * 0.08, box[1] - r * 0.22, cx + dx * r + r * 0.08, box[1] + r * 0.18),
                               radius=r * 0.06, fill=fill)
    draw.rounded_rectangle((cx - r * 0.18, cy + r * 0.2, cx + r * 0.18, cy + r * 0.56), radius=r * 0.06, fill=fill)


def icon(entry: dict, colours: dict) -> Image.Image:
    s = SIZE * SCALE
    img = Image.new("RGB", (s, s), colours["accent"])
    draw = ImageDraw.Draw(img)
    ink = colours["accent_ink"]
    c = s / 2
    font_big = ImageFont.truetype(str(FONT), int(s * 0.3))
    font_small = ImageFont.truetype(str(FONT), int(s * 0.17))

    def number(text: str, y: float, font: ImageFont.FreeTypeFont) -> None:
        draw.text((c, y), text, font=font, fill=ink, anchor="mm")

    if "solved" in entry:
        draw.ellipse((c - s * 0.3, c - s * 0.3, c + s * 0.3, c + s * 0.3), outline=ink, width=int(s * 0.045))
        number(str(entry["solved"]), c + s * 0.01, font_big if entry["solved"] < 100 else font_small)
    elif "three" in entry:
        for k, dx in enumerate((-0.2, 0.0, 0.2)):
            star(draw, c + dx * s, c - s * 0.1 - (0.04 * s if k == 1 else 0), s * 0.11, star_colour(colours))
        number(str(entry["three"]), c + s * 0.2, font_small)
    elif "dailies" in entry or entry.get("key") == "daily":
        calendar(draw, c, c, s * 0.3, ink, colours["accent"])
    elif "streak" in entry:
        flame(draw, c, c - s * 0.08, s * 0.24, ink, colours["accent"])
        number(str(entry["streak"]), c + s * 0.27, font_small)
    elif entry.get("key") == "stars":
        star(draw, c, c + s * 0.02, s * 0.3, star_colour(colours))
    elif entry.get("key") == "streak":
        flame(draw, c, c, s * 0.3, ink, colours["accent"])
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    colours = palette()
    OUT.mkdir(parents=True, exist_ok=True)
    metadata = io.StringIO()
    mappings = io.StringIO()
    meta = csv.writer(metadata, lineterminator="\n")
    maps = csv.writer(mappings, lineterminator="\n")
    files = {}
    for order, entry in enumerate(catalog["achievements"], start=1):
        name, text = entry["name"], entry["text"]
        if "," in name or "," in text:
            raise SystemExit(f"{entry['key']}: the import forbids commas in a name or description")
        meta.writerow([name, text, "False", "", "Revealed", entry["points"], order])
        png = f"{entry['key']}.png"
        maps.writerow([name, png])
        buffer = io.BytesIO()
        image = icon(entry, colours)
        image.save(buffer, "PNG")
        image.save(OUT / png)
        files[png] = buffer.getvalue()
    for board in catalog["leaderboards"]:
        icon(board, colours).save(OUT / f"leaderboard_{board['key']}.png")
    zip_path = OUT / "achievements.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("AchievementsMetadata.csv", metadata.getvalue())
        z.writestr("AchievementsIconsMappings.csv", mappings.getvalue())
        for png, data in files.items():
            z.writestr(png, data)
    print(f"wrote {zip_path}: {len(files)} achievements, icons in {OUT}")


if __name__ == "__main__":
    main()
