"""Side-by-side sheets of each Street screen: the approved concept beside the build, at the same height, so a stranger
could tell at a glance whether they are the same game at the same quality (the M2 parity pass).

Reads the concepts in build/review/revamp2/ and Codex's paste-ups in build/review/art/, and the build's shots from
tools/street_shots.gd in build/review/street/1080x2400/. Writes build/review/parity/<screen>.png.

Run: python3 tools/parity_sheet.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REVIEW = ROOT / "build" / "review"
OUT = REVIEW / "parity"
HEIGHT = 1400
GAP = 24
LABEL = 54
BACK = (34, 44, 62)

# Each screen: the pictures to set side by side, with a label each. A crop is (left, top, right, bottom) as shares.
SCREENS = {
    "map": [("Concept", "revamp2/1-map.png", None), ("Codex paste-up", "art/g-street.png", None),
            ("Build", "street/1080x2400/2-map.png", None)],
    "card": [("Concept", "revamp2/2-start.png", None), ("Build", "street/1080x2400/3-card.png", None)],
    "play": [("Concept", "revamp2/3-play.png", None), ("Codex paste-up", "art/b-play.png", None),
             ("Build", "street/1080x2400/4-play.png", None)],
    "win": [("Concept", "revamp2/4-win.png", (0.318, 0.0, 0.682, 1.0)), ("Codex paste-up", "art/c-win.png", None),
            ("Build", "street/1080x2400/6-win-stars.png", None)],
    "walk": [("Concept", "revamp2/4-win.png", (0.682, 0.0, 1.0, 1.0)), ("Build", "street/1080x2400/7-walk.png", None)],
    "chooser": [("Concept world", "revamp2/board.png", (0.0, 0.0, 0.142, 1.0)),
                ("Build", "street/1080x2400/1-chooser.png", None)],
    "plot": [("Codex lineup", "art/d1-milestone-lineup.png", None), ("Build", "street/1080x2400/9-plot.png", None),
             ("Build, settled", "street/1080x2400/10-family.png", None)],
    "gift": [("Codex paste-up", "art/d1-gift.png", None), ("Build", "street/1080x2400/11-gift.png", None),
             ("Build, opened", "street/1080x2400/13-gift-done.png", None)],
    "milestone": [("Codex paste-up", "art/h2-milestone.png", None),
                  ("Build", "street/1080x2400/14-milestone-rise.png", None),
                  ("Build, done", "street/1080x2400/16-milestone-done.png", None)],
    "families": [("Codex lineups", "art/h1-lineups.png", None), ("Build", "street/1080x2400/15-milestone-family.png", None)],
    "helpers": [("Concept", "revamp2/2-start.png", None), ("Build", "street/1080x2400/17-card-helpers.png", None),
                ("Build, play", "street/1080x2400/18-play-helpers.png", None)],
    "shop": [("Concept", "revamp2/6-shop.png", None), ("Codex paste-up", "art/d2-shop.png", None),
             ("Build", "street/1080x2400/19-shop.png", None)],
    "settings": [("Concept", "revamp2/7-settings.png", None), ("Build, General", "street/1080x2400/20-settings.png", None),
                 ("Build, Accessibility", "street/1080x2400/21-settings-access.png", None)],
}


def font(size: int) -> ImageFont.ImageFont:
    for path in ("/usr/share/fonts/google-noto/NotoSans-Regular.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf"):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    label_font = font(34)
    for screen, parts in SCREENS.items():
        tiles = []
        for label, rel, crop in parts:
            path = REVIEW / rel
            if not path.exists():
                print(f"{screen}: missing {rel}")
                continue
            im = Image.open(path).convert("RGB")
            if crop:
                im = im.crop((round(crop[0] * im.width), round(crop[1] * im.height), round(crop[2] * im.width),
                              round(crop[3] * im.height)))
            im = im.resize((round(im.width * HEIGHT / im.height), HEIGHT), Image.Resampling.LANCZOS)
            tiles.append((label, im))
        width = sum(im.width for _, im in tiles) + GAP * (len(tiles) + 1)
        sheet = Image.new("RGB", (width, HEIGHT + LABEL + GAP * 2), BACK)
        draw = ImageDraw.Draw(sheet)
        x = GAP
        for label, im in tiles:
            draw.text((x, GAP // 2), label, font=label_font, fill=(235, 238, 245))
            sheet.paste(im, (x, LABEL + GAP))
            x += im.width + GAP
        sheet.save(OUT / f"{screen}.png")
        print(OUT / f"{screen}.png")


if __name__ == "__main__":
    main()
