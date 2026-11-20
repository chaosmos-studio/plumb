"""Packs the street's art into what the game draws (REVAMP_PLAN.md section 10).

Reads Codex's painted sources in art/street/ and writes assets/street/:

- atlas.png and atlas.json: every upright cut-out (houses, doors, windows, trees, bushes, lamp, fence, planter, padlock,
  clouds, sun, the cast's bodies and hats), trimmed to its alpha and scaled by SCALE, plus the small shapes the game
  needs and draws no better itself (the cast's face parts, the current door's glow, the door plaque, stars and a contact
  shadow), drawn here at four times their size and scaled down. One texture, so the map's props batch into a few draw
  calls (MATH.md section 25). atlas.json gives each piece's box and base point in atlas pixels, and each house's door
  and windows.
- ui.png and ui.json: the screens' pieces (buttons, icons, pills, slots, the start card, the sign, the bunting), kept
  whole on their own page so their nine-slice margins and layout points stay in source pixels, as Codex recorded them.
- town.png and town.json: what the rewards bring to the street and its moments (the families' houses, the windmill's
  sails, the plot and its signs, the marble folk and their props, the finish ribbon and its halves, fireworks and the
  parcel's flaps), trimmed and indexed as the atlas is, its houses with their door and windows. A page of its own, so
  the street's atlas keeps its room.
- rooms.png and rooms.json: the shop's stall, awning, counter and trays, and Settings' arch, bow, panel, rows, tabs and
  toggles, kept whole with their nine-slice records, as the UI page keeps its pieces. Loaded only when a room opens.
- play_backdrop.png, win_backdrop.png, gift_backdrop.png, shop_backdrop.png and settings_backdrop.png, with their
  `_wide` versions: whole screens, each its own texture.
- grass.png, road.png, hills.png and sky.png, which the map tiles or stretches.

A piece drawn here is a stand-in: once Codex paints one of the same name, the painted one is used.

Run: python3 tools/pack_street.py
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "street"
OUT = ROOT / "assets" / "street"
SIZE = (2048, 4096)
UI_SIZE = (2048, 3072)
TOWN_SIZE = (2048, 2048)
ROOMS_SIZE = (2048, 3072)
PAD = 4
# The rewards' pieces, which go on the town page, and the rooms' pieces, which go on theirs. Checked before UI, so the
# finish ribbon's pieces are the town's and the card's ribbon stays the UI page's.
TOWN = ("milestone_", "folk_", "prop_", "ribbon_finish", "ribbon_half_", "firework_", "plot_sign_", "parcel_flaps_")
ROOMS = ("shop_", "settings_", "toggle_")
# The screens' pieces, which go on the UI page, and the whole-screen backdrops.
UI = ("button_", "card_", "icon_", "pill_", "ribbon", "sign_", "slot_", "star_big", "rays", "sparks",
      "confetti_", "title_", "front_", "grass_front", "coin")
BACKDROPS = tuple(name + wide for name in ("play_backdrop", "win_backdrop", "gift_backdrop", "shop_backdrop",
                                           "settings_backdrop") for wide in ("", "_wide"))
SKIP = ("grass_tile", "road_tile", "hills", "sky")
# The houses whose records (base, door, windows) are read from their JSON, and the windmill's sails' hub on its house,
# in its source pixels (Codex, the final windmill).
HOUSES = ("house_", "milestone_bakery", "milestone_windmill", "milestone_clock_tower", "milestone_tree_house")
HUBS = {"milestone_windmill": (386, 235)}
# The parcel's flaps turn about their shared hinge, in their source pixels.
HINGE = (208, 111)
# The finish ribbon's halves sit at these x on the whole ribbon's canvas, so each is drawn from the whole one's base.
RIBBON_HALVES = {"ribbon_half_left": 0, "ribbon_half_right": 340}
# Soft pieces that lose nothing packed smaller: their share of full size. ui.json records it, and the game draws them
# back at full size.
UI_SCALE = {"rays": 0.5}
# Painted pieces that take over a stand-in's name in the game.
ALIAS = {"star_small": "star", "star_small_empty": "star_dim", "star_big_empty": "star_big_dim"}
# Pieces whose base point is their centre rather than their foot. A folk prop's centre is where it attaches, and its
# JSON gives that point's offset from the body's centre.
CENTRED = ("door_", "window_", "padlock", "cloud", "sun", "marble_", "parcel_lid", "parcel_bow", "plaque", "star",
           "knocker", "folk_", "prop_", "firework_", "milestone_windmill_sails")
# Atlas pixels per source pixel. At 1 the houses keep all of Codex's detail, since the street shows them about as wide
# as they were painted. The game imports the atlas VRAM-compressed, about 11 MB with its mipmaps.
SCALE = 1.0
SKY_SCALE = 0.5
# The drawn pieces were first sized for houses at 0.6, and grow with them.
GROW = SCALE / 0.6
# A cut-out's base point sits this far above its source canvas's bottom edge (the brief's rule).
BASE_MARGIN = 16
COLOURS = ["red", "teal", "yellow", "purple"]
BODY = {"red": (255, 107, 107), "teal": (34, 181, 166), "yellow": (255, 176, 32), "purple": (123, 108, 246)}
# The cast's body diameter in the atlas: Codex's 232 px ball at SCALE.
BODY_PX = round(232 * SCALE)
SS = 4
INK = (43, 34, 40, 255)


def trim(im: Image.Image, anchor: tuple[float, float]) -> tuple[Image.Image, tuple[float, float]]:
    box = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
    x0, y0, x1, y1 = max(box[0] - 2, 0), max(box[1] - 2, 0), min(box[2] + 2, im.width), min(box[3] + 2, im.height)
    return im.crop((x0, y0, x1, y1)), (anchor[0] - x0, anchor[1] - y0)


def scaled(im: Image.Image, factor: float) -> Image.Image:
    return im.resize((max(1, round(im.width * factor)), max(1, round(im.height * factor))), Image.Resampling.LANCZOS)


def canvas(w: int, h: int, colour: tuple = (0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGBA", (w * SS, h * SS), colour[:3] + (0,))
    return im, ImageDraw.Draw(im)


def done(im: Image.Image, w: int, h: int) -> Image.Image:
    return im.resize((w, h), Image.Resampling.LANCZOS)


def ellipse(d: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, fill: tuple) -> None:
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=fill)


def arc(d: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, start: float, end: float, width: float,
        fill: tuple) -> None:
    d.arc([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], start, end, fill=fill,
          width=max(1, round(width * SS)))


def star_points(cx: float, cy: float, r: float) -> list[tuple[float, float]]:
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.47
        pts.append(((cx + rr * math.cos(a)) * SS, (cy + rr * math.sin(a)) * SS))
    return pts


def drawn_pieces() -> dict[str, tuple[Image.Image, tuple[float, float]]]:
    """The shapes drawn here, each with its base point (for face parts and badges, their centre)."""
    out = {}
    d_body = BODY_PX
    # Eyes: the concepts' black ovals with one glint, a happy closed arc, and a sleepy line.
    w, h = round(d_body * 0.16), round(d_body * 0.22)
    im, d = canvas(w, h)
    ellipse(d, w / 2, h / 2, w * 0.42, h * 0.45, INK)
    ellipse(d, w * 0.36, h * 0.3, w * 0.13, w * 0.13, (255, 255, 255, 235))
    out["eye"] = (done(im, w, h), (w / 2, h / 2))
    w, h = round(d_body * 0.18), round(d_body * 0.12)
    im, d = canvas(w, h)
    arc(d, w / 2, h * 0.95, w * 0.36, h * 0.6, 200, 340, d_body * 0.035, INK)
    out["eye_happy"] = (done(im, w, h), (w / 2, h / 2))
    im, d = canvas(w, h)
    arc(d, w / 2, h * 0.15, w * 0.36, h * 0.45, 20, 160, d_body * 0.032, INK)
    out["eye_closed"] = (done(im, w, h), (w / 2, h / 2))
    # Mouths: a small smile, a wide grin, an open laugh, and a little "o".
    w, h = round(d_body * 0.3), round(d_body * 0.16)
    im, d = canvas(w, h)
    arc(d, w / 2, h * 0.1, w * 0.3, h * 0.55, 25, 155, d_body * 0.032, INK)
    out["mouth_smile"] = (done(im, w, h), (w / 2, h / 2))
    im, d = canvas(w, h)
    arc(d, w / 2, h * 0.0, w * 0.4, h * 0.75, 20, 160, d_body * 0.036, INK)
    out["mouth_grin"] = (done(im, w, h), (w / 2, h / 2))
    w, h = round(d_body * 0.28), round(d_body * 0.2)
    im, d = canvas(w, h)
    d.chord([w * 0.12 * SS, -h * 0.55 * SS, w * 0.88 * SS, h * 0.92 * SS], 0, 180, fill=(92, 30, 38, 255))
    ellipse(d, w / 2, h * 0.72, w * 0.18, h * 0.14, (238, 120, 128, 255))
    out["mouth_laugh"] = (done(im, w, h), (w / 2, h / 2))
    w, h = round(d_body * 0.14), round(d_body * 0.16)
    im, d = canvas(w, h)
    ellipse(d, w / 2, h / 2, w * 0.36, h * 0.4, (92, 30, 38, 255))
    out["mouth_o"] = (done(im, w, h), (w / 2, h / 2))
    w, h = round(d_body * 0.2), round(d_body * 0.11)
    im, d = canvas(w, h, (255, 120, 140))
    ellipse(d, w / 2, h / 2, w * 0.45, h * 0.42, (255, 120, 140, 90))
    out["blush"] = (done(im, w, h).filter(ImageFilter.GaussianBlur(1)), (w / 2, h / 2))
    # The current door's glow: a soft warm disc and short rounded rays hugging the door's ring (outer radius 62 atlas
    # pixels at 0.6, so 62 GROW now), as round door 12 in the concept.
    g = round(210 * GROW)
    im, d = canvas(g, g, (255, 214, 90))
    for i in range(16, 0, -1):
        ellipse(d, g / 2, g / 2, (56 + i * 2.2) * GROW, (56 + i * 2.2) * GROW, (255, 214, 90, 20))
    for k in range(10):
        a = math.radians(-90 + k * 36 + 18)
        x0, y0 = g / 2 + math.cos(a) * 76 * GROW, g / 2 + math.sin(a) * 76 * GROW
        x1, y1 = g / 2 + math.cos(a) * 96 * GROW, g / 2 + math.sin(a) * 96 * GROW
        d.line([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=(255, 205, 60, 235), width=round(9 * GROW * SS))
        ellipse(d, x0, y0, 4.5 * GROW, 4.5 * GROW, (255, 205, 60, 235))
        ellipse(d, x1, y1, 4.5 * GROW, 4.5 * GROW, (255, 205, 60, 235))
    out["glow"] = (done(im, g, g), (g / 2, g / 2))
    # The plaque a solved door wears, and its stars.
    w, h = round(86 * GROW), round(34 * GROW)
    im, d = canvas(w, h, (240, 185, 65))
    r = 10 * GROW
    d.rounded_rectangle([2 * SS, 3 * GROW * SS, (w - 2) * SS, (h - 1) * SS], radius=r * SS, fill=(204, 140, 30, 255))
    d.rounded_rectangle([2 * SS, 1 * SS, (w - 2) * SS, (h - 4 * GROW) * SS], radius=r * SS, fill=(250, 196, 64, 255))
    d.rounded_rectangle([7 * GROW * SS, 4 * GROW * SS, (w - 7 * GROW) * SS, 11 * GROW * SS], radius=5 * GROW * SS,
                        fill=(255, 226, 140, 170))
    out["plaque"] = (done(im, w, h), (w / 2, h / 2))
    for name, fill, rim, s in (("star", (255, 216, 64, 255), (214, 140, 20, 255), round(30 * GROW)),
                               ("star_dim", (255, 246, 230, 150), (220, 200, 180, 150), round(30 * GROW)),
                               ("star_big", (255, 214, 58, 255), (222, 136, 18, 255), 300),
                               ("star_big_dim", (255, 250, 240, 120), (215, 205, 190, 140), 300)):
        im, d = canvas(s, s, fill)
        d.polygon(star_points(s / 2, s / 2 + s * 0.02, s * 0.48), fill=rim)
        d.polygon(star_points(s / 2, s / 2, s * 0.43), fill=fill)
        if s > 100:
            # A glossy highlight on the big stars, as the concept's win stars.
            hi, hd = canvas(s, s, (255, 255, 255))
            hd.polygon(star_points(s / 2 - s * 0.02, s / 2 - s * 0.05, s * 0.3), fill=(255, 255, 255, 120))
            im.alpha_composite(hi.filter(ImageFilter.GaussianBlur(s * SS * 0.03)))
        out[name] = (done(im, s, s), (s / 2, s / 2))
    # Soft rays of light, which turn slowly behind the win's stars.
    s = 720
    im, d = canvas(s, s, (255, 245, 200))
    for k in range(14):
        a = math.radians(k * 360 / 14)
        b = math.radians(k * 360 / 14 + 360 / 28)
        d.polygon([(s / 2 * SS, s / 2 * SS), ((s / 2 + math.cos(a) * s * 0.5) * SS, (s / 2 + math.sin(a) * s * 0.5) * SS),
                   ((s / 2 + math.cos(b) * s * 0.5) * SS, (s / 2 + math.sin(b) * s * 0.5) * SS)],
                  fill=(255, 245, 200, 120))
    mask = Image.new("L", (s * SS, s * SS), 0)
    md = ImageDraw.Draw(mask)
    for i in range(30, 0, -1):
        md.ellipse([(s / 2 - s * 0.5 * i / 30) * SS, (s / 2 - s * 0.5 * i / 30) * SS, (s / 2 + s * 0.5 * i / 30) * SS,
                    (s / 2 + s * 0.5 * i / 30) * SS], fill=round(255 * (1 - i / 30) ** 0.7))
    im.putalpha(Image.composite(im.getchannel("A"), Image.new("L", im.size, 0), mask))
    out["rays"] = (done(im, s, s), (s / 2, s / 2))
    # A soft contact shadow, stretched under anything that stands on the ground.
    w, h = 160, 48
    im, d = canvas(w, h)
    for i in range(10, 0, -1):
        ellipse(d, w / 2, h / 2, w * 0.05 * i, h * 0.05 * i, (40, 60, 20, 16))
    out["shadow"] = (done(im, w, h), (w / 2, h / 2))
    return out


DIGIT_PX = 220
DIGIT_FILL = (255, 243, 223)
# Each digit's advance, in atlas pixels, filled by digit_pieces and written into the index after packing.
ADVANCES: dict[str, float] = {}


def digit_pieces() -> tuple[dict, dict]:
    """The door numbers' digits, set in Baloo 2 at its heaviest and packed with the houses, so a door's number draws in
    the same run as its house instead of breaking the batch with text. Each is centred on its ink, and its advance
    (how far the next digit starts) is kept for setting numbers."""
    from PIL import ImageFont
    font = ImageFont.truetype(str(ROOT / "assets" / "fonts" / "Baloo2.ttf"), DIGIT_PX)
    try:
        font.set_variation_by_axes([800])
    except (OSError, AttributeError):
        pass
    out, advances = {}, {}
    for d in "0123456789":
        x0, y0, x1, y1 = font.getbbox(d)
        w, h = x1 - x0 + 8, y1 - y0 + 8
        im = Image.new("RGBA", (w, h), DIGIT_FILL + (0,))
        ImageDraw.Draw(im).text((4 - x0, 4 - y0), d, font=font, fill=DIGIT_FILL + (255,))
        out["digit_" + d] = (im, (w / 2, h / 2))
        advances["digit_" + d] = round(font.getlength(d), 2)
    return out, advances


def stand_in_body(colour: str) -> Image.Image:
    """A glossy ball for a cast member whose painted body has not arrived."""
    r, g, b = BODY[colour]
    s = BODY_PX
    im, d = canvas(s, s, (r, g, b))
    for i in range(24):
        t = i / 23
        k = 0.78 + 0.32 * t
        c = (min(255, round(r * k)), min(255, round(g * k)), min(255, round(b * k)), 255)
        rr = s * 0.48 * (1 - t * 0.55)
        ellipse(d, s / 2 - s * 0.1 * t, s / 2 - s * 0.12 * t, rr, rr, c)
    ellipse(d, s * 0.36, s * 0.27, s * 0.13, s * 0.08, (255, 255, 255, 170))
    return done(im, s, s)


def collect() -> dict[str, dict]:
    """Every page's pieces, by page: "atlas" and "town" (trimmed cut-outs, with their houses' and pieces' records) and
    "ui" and "rooms" (whole screen pieces, with their layout records)."""
    pages: dict[str, dict] = {page: {"pieces": {}, "meta": {}} for page in ("atlas", "town", "ui", "rooms")}
    for path in sorted(SRC.glob("*.png")):
        source = path.stem
        name = ALIAS.get(source, source)
        if name in SKIP or name in BACKDROPS or name.startswith("faces_"):
            continue
        spec = SRC / (source + ".json")
        data = json.loads(spec.read_text()) if spec.exists() else {}
        im = Image.open(path).convert("RGBA")
        whole = "rooms" if name.startswith(ROOMS) else "ui" if name == "bunting" or (
            name.startswith(UI) and not name.startswith(TOWN)) else ""
        if whole:
            if name in UI_SCALE:
                im = scaled(im, UI_SCALE[name])
                data["scale"] = UI_SCALE[name]
            pages[whole]["pieces"][name] = (im, (im.width / 2, im.height / 2))
            pages[whole]["meta"][name] = data
            continue
        page = "town" if name.startswith(TOWN) else "atlas"
        factor = SKY_SCALE if name.startswith(("cloud", "sun")) else SCALE
        meta: dict = {}
        if name.startswith(CENTRED):
            anchor = (im.width / 2, im.height / 2)
        else:
            anchor = (im.width / 2, im.height - BASE_MARGIN)
        if name.startswith(HOUSES) and "base" in data:
            anchor = tuple(data["base"])
            meta = {"house": data}
        elif "base" in data:
            anchor = tuple(data["base"])
        if name.startswith("prop_") and "anchor" in data:
            # Where it sits on a body: its centre's offset from the body's centre, in body pixels.
            meta["offset"] = [round(v * factor, 2) for v in data["anchor"]]
        if name.startswith("parcel_flaps_"):
            anchor = HINGE
        if name in RIBBON_HALVES:
            whole_w = Image.open(SRC / "ribbon_finish.png").width
            anchor = (whole_w / 2 - RIBBON_HALVES[name], im.height - BASE_MARGIN)
        if name in HUBS:
            hx, hy = HUBS[name]
            meta["hub"] = [round((hx - anchor[0]) * factor, 2), round((hy - anchor[1]) * factor, 2)]
        cut, anchor = trim(im, anchor)
        pages[page]["pieces"][name] = (scaled(cut, factor), (anchor[0] * factor, anchor[1] * factor))
        if meta:
            meta["factor"] = factor
            pages[page]["meta"][name] = meta
    atlas = pages["atlas"]["pieces"]
    for colour in COLOURS:
        if "marble_" + colour not in atlas:
            atlas["marble_" + colour] = (stand_in_body(colour), (BODY_PX / 2, BODY_PX / 2))
    for name, drawn in drawn_pieces().items():
        if name not in atlas and name not in pages["ui"]["pieces"]:
            atlas[name] = drawn
    digits, advances = digit_pieces()
    atlas.update(digits)
    ADVANCES.update(advances)
    return pages


def cut_records(index: dict, meta: dict) -> None:
    """Writes a cut-out page's records into its index: each house's door and windows from its base point, a sail's
    hub, a prop's offset, all at the page's scale."""
    for name, data in meta.items():
        f = data["factor"]
        if "house" in data:
            house = data["house"]
            bx, by = house["base"]
            if "door" in house:
                cx, cy, r = house["door"]
                index[name]["door"] = [round((cx - bx) * f, 2), round((cy - by) * f, 2), round(r * f, 2)]
            if "windows" in house:
                index[name]["windows"] = [[round((wx - bx) * f, 2), round((wy - by) * f, 2), round(ww * f, 2),
                                           round(wh * f, 2)] for wx, wy, ww, wh in house["windows"]]
        for key in ("hub", "offset"):
            if key in data:
                index[name][key] = data[key]


def pack(pieces: dict, size: tuple[int, int] = SIZE) -> tuple[Image.Image, dict]:
    """A skyline packer: the page's filled outline is kept as a list of steps (x, width, height), and each piece,
    tallest first, goes where its top lands lowest. It fills a page far tighter than rows of shelves do."""
    atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    index = {}
    sky = [[0, size[0], 0]]
    for name, (im, anchor) in sorted(pieces.items(), key=lambda kv: (-kv[1][0].height, -kv[1][0].width, kv[0])):
        w, h = im.width + PAD, im.height + PAD
        best = None
        for i in range(len(sky)):
            x = sky[i][0]
            if x + w > size[0]:
                break
            # The piece rests on the highest step it spans.
            top, span, j = 0, 0, i
            while span < w:
                top = max(top, sky[j][2])
                span += sky[j][1]
                j += 1
            if top + h <= size[1] and (best is None or top < best[1] or (top == best[1] and x < best[0])):
                best = (x, top)
        if best is None:
            raise SystemExit(f"the page is full at {name}")
        x, y = best
        atlas.alpha_composite(im, (x + PAD // 2, y + PAD // 2))
        index[name] = {"rect": [x + PAD // 2, y + PAD // 2, im.width, im.height],
                       "anchor": [round(anchor[0], 2), round(anchor[1], 2)]}
        # The piece's top becomes a new step, cutting the steps it covers.
        steps = []
        for sx, sw, sh in sky:
            if sx + sw <= x or sx >= x + w:
                steps.append([sx, sw, sh])
                continue
            if sx < x:
                steps.append([sx, x - sx, sh])
            if sx + sw > x + w:
                steps.append([x + w, sx + sw - (x + w), sh])
        steps.append([x, w, y + h])
        steps.sort()
        sky = []
        for step in steps:
            if sky and sky[-1][2] == step[2] and sky[-1][0] + sky[-1][1] == step[0]:
                sky[-1][1] += step[1]
            else:
                sky.append(step)
    return atlas, index


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pages = collect()
    sizes = {"atlas": SIZE, "town": TOWN_SIZE, "ui": UI_SIZE, "rooms": ROOMS_SIZE}
    for name, page in pages.items():
        image, index = pack(page["pieces"], sizes[name])
        if name in ("ui", "rooms"):
            for piece, data in page["meta"].items():
                index[piece].update(data)
        else:
            cut_records(index, page["meta"])
        head = {"pieces": index}
        if name == "atlas":
            for piece, advance in ADVANCES.items():
                index[piece]["advance"] = advance
            head.update({"scale": SCALE, "body": BODY_PX})
        image.save(OUT / (name + ".png"), optimize=True)
        (OUT / (name + ".json")).write_text(json.dumps(head, indent=1, sort_keys=True) + "\n")
        used = sum(v["rect"][2] * v["rect"][3] for v in index.values())
        print(f"{name}: packed {len(index)} pieces, {100 * used / sizes[name][0] / sizes[name][1]:.0f}% of the page")
    for name in BACKDROPS:
        if (SRC / (name + ".png")).exists():
            Image.open(SRC / (name + ".png")).convert("RGB").save(OUT / (name + ".png"), optimize=True)
    Image.open(SRC / "grass_tile.png").convert("RGB").save(OUT / "grass.png", optimize=True)
    Image.open(SRC / "road_tile.png").convert("RGB").save(OUT / "road.png", optimize=True)
    Image.open(SRC / "hills.png").convert("RGBA").save(OUT / "hills.png", optimize=True)
    sky = Image.open(SRC / "sky.png").convert("RGB")
    sky.resize((16, sky.height // 2), Image.Resampling.LANCZOS).save(OUT / "sky.png", optimize=True)


if __name__ == "__main__":
    main()
