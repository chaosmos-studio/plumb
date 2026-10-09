class_name GameLooks
extends RefCounted

## Each marble set keeps Classic's colour families (red, teal, amber, violet), so the colours stay as easy
## to tell apart.

const TITLE: String = "Marbles"
const PACK: String = "Marble pack"
const PACK_LINE: String = "Glass, gems, planets and candy"
const PACK_ROW: String = "Four more marble sets"

const LOOKS: Array = [
	{"id": "classic", "name": "Classic"},
	{"id": "glass", "name": "Glass"},
	{"id": "gems", "name": "Gems"},
	{"id": "planets", "name": "Planets"},
	{"id": "candy", "name": "Candy"},
]

enum Finish { GLOSS, GLASS, GEM, PLANET, CANDY }

## Each set's colours, [] for the palette's own, and its finish.
const SETS: Dictionary = {
	"classic": [[], Finish.GLOSS],
	"glass": [[Color("ff7a7a"), Color("39c6b8"), Color("ffc54d"), Color("8f84ff")], Finish.GLASS],
	"gems": [[Color("e3245f"), Color("0fa57a"), Color("f0a00a"), Color("8a4fe2")], Finish.GEM],
	"planets": [[Color("dd6544"), Color("2f9fb0"), Color("e3b264"), Color("8b78dc")], Finish.PLANET],
	"candy": [[Color("ff7fa0"), Color("3fd3b9"), Color("ffcb4c"), Color("a88cff")], Finish.CANDY],
}

static var finish: Finish = Finish.GLOSS
static var _look: String = "classic"

static func use(id: String) -> void:
	_look = id if SETS.has(id) else "classic"
	finish = SETS[_look][1]

static func marbles(dark: bool, own: Array) -> Array:
	var colours: Array = SETS[_look][0]
	if colours.is_empty():
		return own
	return colours.map(func(c: Color) -> Color: return c.lightened(0.06) if dark else c)

static func swatch(id: String) -> Array:
	var colours: Array = SETS.get(id, SETS["classic"])[0]
	return colours if not colours.is_empty() else Palette.LIGHT["marbles"]

static func sample(id: String, colour: Color, radius: float) -> Node2D:
	var marble: Marble = Marble.new()
	marble.radius = radius
	marble.colour = colour
	marble.finish = SETS.get(id, SETS["classic"])[1]
	return marble

static func preview(_id: String) -> void:
	pass
