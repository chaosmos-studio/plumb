class_name Brand
extends RefCounted

## The kit reads the game's name, colours, fonts and scenes only from here. The board keeps its own
## colours in Palette.

const NAME: String = "Plumb"
const WORDMARK: String = "plumb"
const TAGLINE: String = "Roll every marble home"

## A new player starts in this look.
const NATIVE_DARK: bool = false
const HAS_MUSIC: bool = true

const LIGHT: Dictionary = {
	"bg": Color("f4efe7"),
	"surface": Color("fffdf9"),
	"line": Color(0.18, 0.2, 0.24, 0.1),
	"ink": Color("2f333d"),
	"muted": Color("857d6f"),
	"accent": Color("f05a5a"),
	"accent_ink": Color("ffffff"),
	"gold": Color("ffb627"),
	"danger": Color("e5484d"),
	"shadow": Color(0.3, 0.22, 0.12, 0.1),
	"scrim": Color("2f333d"),
}

const DARK: Dictionary = {
	"bg": Color("1b1d22"),
	"surface": Color("272a31"),
	"line": Color(0.95, 0.93, 0.89, 0.1),
	"ink": Color("f1ece3"),
	"muted": Color("a39b8d"),
	"accent": Color("ff7b7b"),
	"accent_ink": Color("1b1d22"),
	"gold": Color("ffc24a"),
	"danger": Color("ff6b6b"),
	"shadow": Color(0.0, 0.0, 0.0, 0.3),
	"scrim": Color("08090b"),
}

static var BG: Color = LIGHT["bg"]
static var SURFACE: Color = LIGHT["surface"]
static var LINE: Color = LIGHT["line"]
static var INK: Color = LIGHT["ink"]
static var MUTED: Color = LIGHT["muted"]
static var ACCENT: Color = LIGHT["accent"]
static var ACCENT_INK: Color = LIGHT["accent_ink"]
static var GOLD: Color = LIGHT["gold"]
static var DANGER: Color = LIGHT["danger"]
static var SHADOW: Color = LIGHT["shadow"]
static var SCRIM: Color = LIGHT["scrim"]

const FONT_DISPLAY: String = "res://assets/fonts/Outfit-Light.ttf"
const FONT_UI: String = "res://assets/fonts/Outfit-Medium.ttf"

const TITLE_SCENE: String = "res://scenes/shell/title.tscn"
const LEVELS_SCENE: String = "res://kit/shell/levels.tscn"
const GAME_SCENE: String = "res://scenes/game/game.tscn"

static func use(dark: bool) -> void:
	var p: Dictionary = DARK if dark else LIGHT
	BG = p["bg"]
	SURFACE = p["surface"]
	LINE = p["line"]
	INK = p["ink"]
	MUTED = p["muted"]
	ACCENT = p["accent"]
	ACCENT_INK = p["accent_ink"]
	GOLD = p["gold"]
	DANGER = p["danger"]
	SHADOW = p["shadow"]
	SCRIM = p["scrim"]
	Palette.use(dark)

## Gold and danger stay the game's own.
static func use_theme(t: Dictionary, dark: bool) -> void:
	use(dark)
	BG = t["bg"]
	SURFACE = t["surface"]
	LINE = t["line"]
	INK = t["ink"]
	MUTED = t["muted"]
	ACCENT = t["accent"]
	ACCENT_INK = t["accent_ink"]
	SHADOW = t["shadow"]
	SCRIM = t["scrim"]
	Palette.use_theme(t, dark)
