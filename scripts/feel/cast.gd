class_name Cast
extends RefCounted

## Each marble colour is a character, in the palette's order: red, teal, amber, violet. A stone is a sleepy
## rock with no name. Sizes are in the marble's radius.

enum Mark { FRECKLES, GOOGLY, BLUSH, LASHES, ROCK }

## Whether faces show, kept in step with the Faces setting by Save, so a marble can read it without naming an
## autoload.
static var showing: bool = true

class Who extends RefCounted:
	var name: String = ""
	## Half the gap between the eyes, and how high they sit (negative is up).
	var eyes: Vector2 = Vector2(0.28, -0.12)
	## The left eye's white, as radii, and the right one's size against it.
	var white: Vector2 = Vector2(0.22, 0.25)
	var odd: float = 1.0
	var pupil: float = 0.11
	## Resting lids (1 wide open), mouth (-1 to 1) and brows (-1 bold to 1 worried), and whether brows show at
	## rest.
	var lids: float = 1.0
	var smile: float = 0.5
	var brow: float = 0.0
	var brows: bool = false
	## The mouth's half width and how low it sits.
	var mouth: Vector2 = Vector2(0.2, 0.32)
	var mark: Mark = Mark.GOOGLY
	## The pitch of its little cry down a pit.
	var voice: float = 1.0

	func _init(n: String, e: Vector2, w: Vector2, o: float, p: float, l: float, s: float, b: float, show: bool,
			m: Vector2, k: Mark, v: float) -> void:
		name = n
		eyes = e
		white = w
		odd = o
		pupil = p
		lids = l
		smile = s
		brow = b
		brows = show
		mouth = m
		mark = k
		voice = v

## Rosie is bold, with brows and freckles. Steve has the reel's googly eyes, one bigger than the other, and a
## lopsided smile. Pip is all eyes and blushes. Lulu is dreamy, half asleep under long lashes.
static var CAST: Array[Who] = [
	Who.new("Rosie", Vector2(0.27, -0.12), Vector2(0.19, 0.25), 1.0, 0.105, 1.0, 0.65, -0.45, true,
		Vector2(0.22, 0.33), Mark.FRECKLES, 1.0),
	Who.new("Steve", Vector2(0.27, -0.13), Vector2(0.22, 0.22), 1.16, 0.11, 1.0, 0.5, 0.0, false,
		Vector2(0.2, 0.33), Mark.GOOGLY, 0.88),
	Who.new("Pip", Vector2(0.25, -0.1), Vector2(0.25, 0.26), 1.0, 0.14, 1.0, 0.85, 0.0, false,
		Vector2(0.17, 0.34), Mark.BLUSH, 1.16),
	Who.new("Lulu", Vector2(0.28, -0.1), Vector2(0.21, 0.2), 1.0, 0.11, 0.5, 0.4, 0.15, false,
		Vector2(0.13, 0.33), Mark.LASHES, 1.06),
]
static var ROCK: Who = Who.new("", Vector2(0.26, -0.06), Vector2(0.17, 0.12), 1.0, 0.06, 0.0, 0.0, 0.0, false,
	Vector2(0.09, 0.3), Mark.ROCK, 0.8)

## The character for a marble's colour index, or the rock for a stone.
static func of(colour: int) -> Who:
	if colour == TiltBoard.STONE:
		return ROCK
	return CAST[posmod(colour, CAST.size())]
