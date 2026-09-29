# Credits

Every third-party asset in the build and its licence. This file is a release blocker: a CC-BY line
missing here is a licence violation, not a typo. Sourcing notes live in the workspace `ASSETS.md`; raw
downloads live in the private `game-assets` repo checked out at `faceplant/assets_incoming`, whose
`PROVENANCE.md` has the full table.

Only CC0, CC-BY and SIL OFL (fonts) ship. Note every modification (rescaled, recoloured, retimed).

## Fonts

| Asset | Author | Licence | Notes |
| --- | --- | --- | --- |
| Outfit (`assets/fonts/Outfit-Light.ttf` and `assets/fonts/Outfit-Medium.ttf`, and the light one again as `web/Outfit-Light.ttf` for the loading page) | The Outfit Project Authors | SIL Open Font License 1.1 (`assets/fonts/Outfit-OFL.txt`) | Modified: static weight-300 and weight-500 instances of the variable font with overlapping contours merged, written by `tools/make_font.py` from the unmodified source in `assets/fonts/source/`. The variable font's overlaps showed as faint seams across stems. The licence declares no Reserved Font Name. |

## Sound effects and music

All synthesised by `tools/make_sfx.py`, including the ambient music loop. None are third-party.

## Everything else

Code, generated art and synthesised audio are original to this project.
