class_name Brand
extends RefCounted

## Everything the shared UI kit needs to know about this game: its name, its colours and fonts, and where
## its screens are. The kit reads only this, so restyling the game means changing only this file.

const NAME: String = "Plumb"
const WORDMARK: String = "plumb"
const TAGLINE: String = "Roll every marble home"

const BG: Color = Color("f4efe7")
const SURFACE: Color = Color("fffdf9")
const LINE: Color = Color(0.18, 0.2, 0.24, 0.1)
const INK: Color = Color("2f333d")
const MUTED: Color = Color("9b9384")
const ACCENT: Color = Color("ff6b6b")
const ACCENT_INK: Color = Color("ffffff")
const GOLD: Color = Color("ffb627")
const DANGER: Color = Color("e5484d")
const SHADOW: Color = Color(0.3, 0.22, 0.12, 0.1)
## The colour the screen dims toward under a sheet or a hint.
const SCRIM: Color = Color("2f333d")

const FONT_DISPLAY: String = "res://assets/fonts/Outfit-Light.ttf"
const FONT_UI: String = "res://assets/fonts/Outfit-Medium.ttf"

const TITLE_SCENE: String = "res://scenes/shell/title.tscn"
const LEVELS_SCENE: String = "res://kit/shell/levels.tscn"
const GAME_SCENE: String = "res://scenes/game/game.tscn"
