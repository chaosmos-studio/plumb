class_name Palette
extends RefCounted

## Every colour in the game, in one place: warm paper, a slate that reads as solid, and four marble
## colours chosen to stay distinct for the common kinds of colour blindness when paired with the hole
## rings' positions.

const BG: Color = Color("f3ede3")
const TRAY: Color = Color("e2d8c8")
const TRAY_SHADOW: Color = Color(0.36, 0.30, 0.22, 0.18)
const TILE: Color = Color("fbf7f0")
const WALL: Color = Color("4f586a")
const WALL_LIP: Color = Color("363c49")
const INK: Color = Color("3a3f4b")
const MUTED: Color = Color("a0967f")
const HOLE: Color = Color("2c3140")
const PIT: Color = Color("16171d")
const DANGER: Color = Color("ff6b6b")
const GOLD: Color = Color("ffb627")
const PANEL: Color = Color("fffcf6")

const MARBLES: Array[Color] = [Color("ff6b6b"), Color("22b5a6"), Color("ffb020"), Color("7b6cf6")]

static func marble(colour: int) -> Color:
	return MARBLES[colour % MARBLES.size()]
