class_name HardShelf
extends RefCounted

## Brings a save made before the Hard levels to the levels as they are now (MATH.md sections 16 and 22). The old
## levels from FIRST on are the Hard levels, so the stars won on them and the keys spent on them go with them. The
## main path's boards from FIRST on are new, so its stars there start again, and the first level of every chapter up
## to the furthest the player had reached opens, so no chapter they could play before is shut.

## The save layout since the Hard levels. A save without one is older.
const LAYOUT: int = 2
## The first level, 0-based, that moved to Hard, the size of every chapter before the move and the levels in all.
const FIRST: int = 180
const CHAPTER: int = 20
const COUNT: int = 500
## Chapters the main path has gained at FIRST since (Bouncy blocks): every old chapter from FIRST on now comes this
## many chapters later there.
const ADDED: int = 1

## Moves `file` on to LAYOUT in place, if it is older. True when it was.
static func migrate(file: ConfigFile, gate: float) -> bool:
	if int(file.get_value("progress", "layout", 1)) >= LAYOUT:
		return false
	var saved_stars: Variant = file.get_value("progress", "stars", PackedByteArray())
	var saved_opened: Variant = file.get_value("progress", "opened", PackedInt32Array())
	var stars: PackedByteArray = saved_stars if saved_stars is PackedByteArray else PackedByteArray()
	var opened: PackedInt32Array = saved_opened if saved_opened is PackedInt32Array else PackedInt32Array()
	var moved: Dictionary = split(stars, opened, gate)
	file.set_value("progress", "stars", moved["stars"])
	file.set_value("progress", "opened", moved["opened"])
	file.set_value("progress", "hard", moved["hard"])
	file.set_value("progress", "hard_opened", moved["hard_opened"])
	file.set_value("progress", "layout", LAYOUT)
	return true

## {"stars", "opened"} for the main path and {"hard", "hard_opened"} for the Hard levels, both by the old index.
static func split(stars: PackedByteArray, opened: PackedInt32Array, gate: float) -> Dictionary:
	var main: PackedByteArray = stars.slice(0, mini(stars.size(), FIRST))
	var hard: PackedByteArray = PackedByteArray()
	if stars.size() > FIRST:
		hard = stars.duplicate()
		for i: int in range(FIRST):
			hard[i] = 0
	var kept: PackedInt32Array = PackedInt32Array()
	var hard_opened: PackedInt32Array = PackedInt32Array()
	for level: int in opened:
		if level >= FIRST:
			hard_opened.append(level)
		else:
			kept.append(level)
	# On the main path today: the chapters added at FIRST, then each old chapter reached, ADDED chapters on.
	var furthest: int = furthest_chapter(stars, opened, gate)
	@warning_ignore("integer_division")
	var from: int = FIRST / CHAPTER
	if furthest >= from:
		for c: int in range(from, furthest + ADDED + 1):
			if not kept.has(c * CHAPTER):
				kept.append(c * CHAPTER)
	return {"stars": main, "opened": kept, "hard": hard, "hard_opened": hard_opened}

## The furthest chapter, 0-based, with any level open under the rules the save was made with (Unlocks). -1 for none
## past the ones that stayed.
static func furthest_chapter(stars: PackedByteArray, opened: PackedInt32Array, gate: float) -> int:
	# A chapter's gate can open its first level past the last one with stars.
	var last: int = stars.size() + CHAPTER
	for level: int in opened:
		last = maxi(last, level)
	for level: int in range(mini(last, COUNT - 1), FIRST - 1, -1):
		if was_open(level, stars, opened, gate):
			@warning_ignore("integer_division")
			return level / CHAPTER
	return -1

## Unlocks.reached as it stood before the Hard levels: the level before solved, a key or a video, or seven in ten
## of the chapter before.
static func was_open(level: int, stars: PackedByteArray, opened: PackedInt32Array, gate: float) -> bool:
	if level <= 0 or _best(stars, level - 1) > 0 or opened.has(level):
		return true
	if level % CHAPTER != 0:
		return false
	var solved: int = 0
	for i: int in range(level - CHAPTER, level):
		solved += 1 if _best(stars, i) > 0 else 0
	return solved >= ceili(gate * CHAPTER)

static func _best(stars: PackedByteArray, level: int) -> int:
	return stars[level] if level >= 0 and level < stars.size() else 0
