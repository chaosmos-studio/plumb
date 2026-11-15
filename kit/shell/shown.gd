class_name Shown
extends RefCounted

## The numbers and the word a player sees for a level and a chapter. A game with a second set of levels that counts
## from 1 on its own (Plumb's Hard) answers through Pack.number, Pack.chapter_number and Pack.level_word, and
## every other game shows index + 1 and "level".

## How many levels a second set's number is moved on by in Play Games' levelCompleted event, whose level is a
## number, so a second set's level 12 goes as 1012 and never counts as the main path's.
const SET_STAT: int = 1000

static func level(index: int) -> int:
	return int(Pack.call("number", index)) if Pack.has_method("number") else index + 1

static func chapter(index: int) -> int:
	return int(Pack.call("chapter_number", index)) if Pack.has_method("chapter_number") else index + 1

## "level", or a second set's own name for its levels, such as "Hard".
static func word(index: int) -> String:
	return String(Pack.call("level_word", index)) if Pack.has_method("level_word") else "level"

## The level as Play Games records it.
static func stat(index: int) -> int:
	return level(index) + (0 if word(index) == "level" else SET_STAT)
