"""Android masks an adaptive icon's layers to roughly their inner two thirds, and its launch screen to a
circle inside that, so a motif drawn edge to edge for the store icon is fitted in here. See
https://developer.android.com/develop/ui/views/launch/icon_design_adaptive

Used by each game's tools/make_icons.py: write_adaptive(motif, backdrop), where motif(size) and
backdrop(size) return RGBA images of that size.
"""

from PIL import Image

LAYER = 432
# The share of the layer the motif's bounding box may span. Android keeps a circle 66/108 across safe
# from every mask, and a round motif boxed at this size sits inside it.
SAFE = 0.58
# Alpha up to this counts as empty when finding the motif's bounds, so a glow's faint tail does not
# shrink the motif for nothing.
SOLID = 8


def write_adaptive(motif, backdrop, folder="assets/branding"):
    backdrop(LAYER).convert("RGB").convert("RGBA").save(folder + "/adaptive_background.png")
    art = motif(LAYER * 2)
    box = art.getchannel("A").point(lambda a: 255 if a > SOLID else 0).getbbox()
    art = art.crop(box)
    k = SAFE * LAYER / max(art.size)
    art = art.resize((max(1, round(art.width * k)), max(1, round(art.height * k))), Image.LANCZOS)
    layer = Image.new("RGBA", (LAYER, LAYER), (0, 0, 0, 0))
    layer.alpha_composite(art, ((LAYER - art.width) // 2, (LAYER - art.height) // 2))
    layer.save(folder + "/adaptive_foreground.png")
