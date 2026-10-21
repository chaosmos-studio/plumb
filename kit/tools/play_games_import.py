#!/usr/bin/env python3
"""Writes what Play Console's imports take for a game's Play Games project, from kit/play_games/catalog.json,
with every icon drawn at 512 px in the game's own colours (brand.gd's native palette):

- build/play_games/achievements.zip: Achievements, Import achievements, then Save as draft. An achievement with
  a goal past one is incremental, with its goal as the steps, so Play Games shows how far along it is.
- leaderboard_<key>.png: an icon for each leaderboard, since leaderboards have no import and are made by hand.
- PlayerGameEvent.csv: Game Stats, Add an event, Import via CSV.
- game_stats.zip: Game Stats, Add a stat, Import via ZIP, after the events.

Run from the game's folder: python3 kit/tools/play_games_import.py

The achievement CSVs have no header row and no commas in a name or description, as that import requires. The
Game Stats CSVs have a header row. Play Games shows an achievement's icon inside a circle and greys the locked
one by itself, so each is one bold glyph on a full-bleed fill. A stat's icon sits on a transparent ground.
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


def check(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str) -> None:
    pts = [(cx - r * 0.62, cy + r * 0.02), (cx - r * 0.18, cy + r * 0.46), (cx + r * 0.66, cy - r * 0.44)]
    draw.line(pts, fill=fill, width=int(r * 0.26), joint="curve")
    for x, y in (pts[0], pts[2]):
        draw.ellipse((x - r * 0.13, y - r * 0.13, x + r * 0.13, y + r * 0.13), fill=fill)


def bulb(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str, hole: str) -> None:
    """A light bulb struck through: solved without a hint."""
    glass_r = r * 0.56
    gy = cy - r * 0.28
    draw.ellipse((cx - glass_r, gy - glass_r, cx + glass_r, gy + glass_r), fill=fill)
    draw.polygon([(cx - r * 0.42, gy + r * 0.3), (cx + r * 0.42, gy + r * 0.3), (cx + r * 0.27, cy + r * 0.5),
                  (cx - r * 0.27, cy + r * 0.5)], fill=fill)
    for k in range(2):
        y = cy + r * (0.6 + k * 0.22)
        draw.rounded_rectangle((cx - r * 0.27, y, cx + r * 0.27, y + r * 0.13), radius=r * 0.065, fill=fill)
    a, b = (cx - r * 0.78, cy - r * 0.78), (cx + r * 0.78, cy + r * 0.78)
    w = int(r * 0.14)
    draw.line([a, b], fill=hole, width=int(w * 2.6))
    draw.line([a, b], fill=fill, width=w)
    for x, y in (a, b):
        draw.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=fill)


def clock(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str) -> None:
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=fill, width=int(r * 0.18))
    draw.line([(cx, cy), (cx, cy - r * 0.6)], fill=fill, width=int(r * 0.16))
    draw.line([(cx, cy), (cx + r * 0.42, cy + r * 0.2)], fill=fill, width=int(r * 0.16))
    draw.ellipse((cx - r * 0.12, cy - r * 0.12, cx + r * 0.12, cy + r * 0.12), fill=fill)


def steps(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill: str) -> None:
    """Rising bars: levels climbed."""
    for k in range(3):
        x = cx - r * 0.9 + k * r * 0.64
        top = cy + r * 0.7 - (k + 1) * r * 0.5
        draw.rounded_rectangle((x, top, x + r * 0.5, cy + r * 0.7), radius=r * 0.08, fill=fill)


def stat_icon(key: str, colours: dict) -> Image.Image:
    """A Game Stats icon: one glyph on a disc in the accent, on a transparent ground."""
    s = SIZE * SCALE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    ink, fill = colours["accent_ink"], colours["accent"]
    c = s / 2
    draw.ellipse((s * 0.04, s * 0.04, s * 0.96, s * 0.96), fill=fill)
    if key == "puzzles_solved":
        check(draw, c, c, s * 0.3, ink)
    elif key == "stars_collected":
        star(draw, c, c + s * 0.02, s * 0.3, star_colour(colours))
    elif key == "three_star_solves":
        for k, dx in enumerate((-0.2, 0.0, 0.2)):
            star(draw, c + dx * s, c + s * 0.02 - (0.06 * s if k == 1 else 0), s * 0.12, star_colour(colours))
    elif key == "hint_free_solves":
        bulb(draw, c, c, s * 0.28, ink, fill)
    elif key == "time_solving":
        clock(draw, c, c, s * 0.27, ink)
    elif key == "levels_solved":
        steps(draw, c, c, s * 0.32, ink)
    else:
        raise SystemExit(f"{key}: no stat icon is drawn for it")
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def write_game_stats(catalog: dict, colours: dict) -> None:
    events = io.StringIO()
    out = csv.writer(events, lineterminator="\n")
    out.writerow(["Event Name", "Property Name", "Property Type"])
    for event, props in catalog["events"].items():
        for prop, kind in props.items():
            out.writerow([event, prop, kind])
    (OUT / "PlayerGameEvent.csv").write_text(events.getvalue())

    repetitive = io.StringIO()
    out = csv.writer(repetitive, lineterminator="\n")
    out.writerow(["Stat Id", "Event Name", "Event Property Name", "Aggregation Type", "Stat Display Name",
                  "Stat Description", "Filter Property", "Filter Operator", "Filter Value", "Is Competitive",
                  "Min limit", "Max limit", "Icon File Name", "Good value direction", "Unit"])
    files = {}
    for s in catalog["stats"]:
        f = s.get("filter", ["", "", ""])
        lo, hi = s.get("competitive", ["", ""])
        png = f"stat_{s['key']}.png"
        out.writerow([s["key"], s["event"], s["property"], s["aggregation"], s["name"], s["text"], f[0], f[1], f[2],
                      "true" if "competitive" in s else "false", lo, hi, png, "INCREASING", s.get("unit", "")])
        files[png] = stat_icon(s["key"], colours)
    p = catalog["progression"]
    progression = io.StringIO()
    out = csv.writer(progression, lineterminator="\n")
    out.writerow(["Stat Id", "Event Property Name", "Stat Display Name", "Stat Description", "Icon File Name",
                  "Good value direction", "Unit"])
    png = f"stat_{p['key']}.png"
    out.writerow([p["key"], p["property"], p["name"], p["text"], png, "INCREASING", p.get("unit", "")])
    files[png] = stat_icon(p["key"], colours)
    with zipfile.ZipFile(OUT / "game_stats.zip", "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("RepetitiveStatsConfig.csv", repetitive.getvalue())
        z.writestr("ProgressionStatConfig.csv", progression.getvalue())
        for png, image in files.items():
            buffer = io.BytesIO()
            image.save(buffer, "PNG")
            image.save(OUT / png)
            z.writestr(png, buffer.getvalue())
    print(f"wrote {OUT / 'PlayerGameEvent.csv'} and {OUT / 'game_stats.zip'}: {len(files)} stats")


def goal(entry: dict) -> int:
    """The kit's PlayGames.goal: an achievement's threshold, and so its steps."""
    for measure in ("solved", "three", "dailies", "streak"):
        if measure in entry:
            return int(entry[measure])
    return 1


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
        steps_needed = goal(entry)
        meta.writerow([name, text, "True" if steps_needed > 1 else "False", steps_needed if steps_needed > 1 else "",
                       "Revealed", entry["points"], order])
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
    write_game_stats(catalog, colours)


if __name__ == "__main__":
    main()
