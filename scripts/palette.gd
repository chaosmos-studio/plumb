class_name Palette
extends RefCounted

## The four marble colours stay distinct for the common kinds of colour blindness. In the dark palette the
## walls are lighter than the floor, so walls, floor and pits still read as three different heights.

const LIGHT: Dictionary = {
	"tray": Color("e2d8c8"),
	"tray_shadow": Color(0.36, 0.30, 0.22, 0.18),
	"tile": Color("fbf7f0"),
	"wall": Color("4f586a"),
	"wall_lip": Color("363c49"),
	"hole": Color("2c3140"),
	"pit": Color("16171d"),
	"danger": Color("ff6b6b"),
	"stone": Color("a39b8f"),
	"jelly": Color("5aa62a"),
	"marbles": [Color("ff6b6b"), Color("22b5a6"), Color("ffb020"), Color("7b6cf6")],
}

const DARK: Dictionary = {
	"tray": Color("15171b"),
	"tray_shadow": Color(0.0, 0.0, 0.0, 0.45),
	"tile": Color("30343d"),
	"wall": Color("7a8499"),
	"wall_lip": Color("555d6e"),
	"hole": Color("111217"),
	"pit": Color("050506"),
	"danger": Color("ff7b7b"),
	"stone": Color("9b968e"),
	"jelly": Color("a3e05e"),
	"marbles": [Color("ff7474"), Color("2cc4b4"), Color("ffbb33"), Color("8f82ff")],
}

static var TRAY: Color = LIGHT["tray"]
static var TRAY_SHADOW: Color = LIGHT["tray_shadow"]
static var TILE: Color = LIGHT["tile"]
static var WALL: Color = LIGHT["wall"]
static var WALL_LIP: Color = LIGHT["wall_lip"]
static var HOLE: Color = LIGHT["hole"]
static var PIT: Color = LIGHT["pit"]
static var DANGER: Color = LIGHT["danger"]
## A stone's grey: no marble colour, so it never reads as one that belongs in a hole.
static var STONE: Color = LIGHT["stone"]
## A bouncy block's lime, a hue no marble set, wall or tile wears, so it reads as jelly before anything else.
static var JELLY: Color = LIGHT["jelly"]
static var MARBLES: Array[Color] = Array(LIGHT["marbles"], TYPE_COLOR, &"", null)
## The deeper edge along the tray's foot that gives Street's board its depth. Clear in Classic, which draws none.
static var TRAY_RIM: Color = Color.TRANSPARENT

static func marble(colour: int) -> Color:
	return STONE if colour == TiltBoard.STONE else MARBLES[colour % MARBLES.size()]

static func use(dark: bool) -> void:
	var p: Dictionary = DARK if dark else LIGHT
	TRAY_RIM = Color.TRANSPARENT
	TRAY = p["tray"]
	TRAY_SHADOW = p["tray_shadow"]
	TILE = p["tile"]
	WALL = p["wall"]
	WALL_LIP = p["wall_lip"]
	HOLE = p["hole"]
	PIT = p["pit"]
	DANGER = p["danger"]
	STONE = p["stone"]
	JELLY = p["jelly"]
	MARBLES.assign(GameLooks.marbles(dark, p["marbles"]))

## Street's board, from the round 2 concept (build/review/revamp2/3-play.png): a sky-blue tray, pale blue tiles and
## slate walls, with the game's own marble colours, so a hole's ring always matches its marble.
const STREET: Dictionary = {
	"tray": Color("6fcdf2"),
	"tray_rim": Color("2f9fd3"),
	"tray_shadow": Color(0.12, 0.33, 0.45, 0.28),
	"tile": Color("d6f2fd"),
	"wall": Color("3f5359"),
	"wall_lip": Color("2c3b40"),
	"hole": Color("2b3140"),
	"pit": Color("16171d"),
	"danger": Color("ff6b6b"),
	"stone": Color("a39b8f"),
	"jelly": Color("5aa62a"),
	"marbles": [Color("ff6b6b"), Color("22b5a6"), Color("ffb020"), Color("7b6cf6")],
}

static func use_street() -> void:
	var p: Dictionary = STREET
	TRAY_RIM = p["tray_rim"]
	TRAY = p["tray"]
	TRAY_SHADOW = p["tray_shadow"]
	TILE = p["tile"]
	WALL = p["wall"]
	WALL_LIP = p["wall_lip"]
	HOLE = p["hole"]
	PIT = p["pit"]
	DANGER = p["danger"]
	STONE = p["stone"]
	JELLY = p["jelly"]
	MARBLES.assign(p["marbles"])

## Walls are lighter than the floor by night and darker by day, as in the game's own palettes.
static func use_theme(t: Dictionary, dark: bool) -> void:
	use(dark)
	var bg: Color = t["bg"]
	var surface: Color = t["surface"]
	var ink: Color = t["ink"]
	TRAY = bg.darkened(0.25) if dark else bg.lerp(ink, 0.1)
	TILE = surface.lerp(ink, 0.1) if dark else surface
	WALL = ink.lerp(bg, 0.45) if dark else ink.lerp(bg, 0.22)
	WALL_LIP = WALL.darkened(0.3)
	HOLE = bg.darkened(0.6) if dark else ink.darkened(0.1)
	PIT = bg.darkened(0.85) if dark else ink.darkened(0.55)
