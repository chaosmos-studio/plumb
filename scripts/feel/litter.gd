class_name Litter
extends RefCounted

## Which animals a level's walls are, and their coats (MATH.md section 20). Loaf draws them.

enum Family { CAT, DOG }
enum Coat { GREY, DARK, PALE, WARM, PATCHED }

## How far a coat may move from the wall's colour: darker, lighter, or toward a warm ginger or tan.
const DARKER: float = 0.13
const LIGHTER: float = 0.2
const WARMTH: float = 0.36
const GINGER: Color = Color("c8743a")
const TAN: Color = Color("b98a52")
## The least contrast a coat keeps with the floor: a little over the 2:1 the plain wall must meet.
const FLOOR_CONTRAST: float = 2.2

## The family for a level: they take turns level by level, so the board changes every time.
static func family_for(level: int) -> Family:
	return Family.CAT if posmod(level, 2) == 0 else Family.DOG

## A coat for a cell, fixed for a level, so neighbours mostly differ and a board looks like a litter.
static func coat_for(cell: int, level: int) -> Coat:
	var h: int = (cell * 2654435761 + level * 40503 + 12345) & 0x7fffffff
	var k: int = (h >> 7) % Coat.size()
	return k as Coat

## The coat's colour from the wall's: every coat stays within a step of the wall, so walls still read as walls,
## and a coat that would come closer to the floor than FLOOR_CONTRAST steps back toward the wall until it does
## not. Darker or lighter, the theme decides.
static func fur(coat: Coat, family: Family, wall: Color, floor: Color) -> Color:
	var want: Color = wall
	match coat:
		Coat.DARK:
			want = wall.darkened(DARKER)
		Coat.PALE:
			want = wall.lightened(LIGHTER)
		Coat.PATCHED:
			want = wall.lightened(LIGHTER * 0.6)
		Coat.WARM:
			want = wall.lerp(GINGER if family == Family.CAT else TAN, WARMTH)
	for k: int in range(10, -1, -1):
		var c: Color = wall.lerp(want, k / 10.0)
		if contrast(c, floor) >= FLOOR_CONTRAST:
			return c
	return wall

## The WCAG contrast ratio of two colours, from their relative luminance.
static func contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
