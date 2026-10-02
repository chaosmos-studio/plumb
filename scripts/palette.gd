class_name Palette
extends RefCounted

## Every colour on the board, in one place: warm paper, a slate that reads as solid, and four marble
## colours chosen to stay distinct for the common kinds of colour blindness when paired with the hole
## rings' positions. At dusk the paper darkens and the walls turn lighter than the floor, so walls,
## floor and pits still read as three different heights.

const LIGHT: Dictionary = {
	"tray": Color("e2d8c8"),
	"tray_shadow": Color(0.36, 0.30, 0.22, 0.18),
	"tile": Color("fbf7f0"),
	"wall": Color("4f586a"),
	"wall_lip": Color("363c49"),
	"hole": Color("2c3140"),
	"pit": Color("16171d"),
	"danger": Color("ff6b6b"),
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
static var MARBLES: Array[Color] = Array(LIGHT["marbles"], TYPE_COLOR, &"", null)

static func marble(colour: int) -> Color:
	return MARBLES[colour % MARBLES.size()]

static func use(dark: bool) -> void:
	var p: Dictionary = DARK if dark else LIGHT
	TRAY = p["tray"]
	TRAY_SHADOW = p["tray_shadow"]
	TILE = p["tile"]
	WALL = p["wall"]
	WALL_LIP = p["wall_lip"]
	HOLE = p["hole"]
	PIT = p["pit"]
	DANGER = p["danger"]
	MARBLES.assign(GameLooks.marbles(dark, p["marbles"]))
