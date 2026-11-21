extends Node

const PATH: String = "res://levels/levels.json"
const HARD_PATH: String = "res://levels/hard.json"

## The main path, and the Hard levels: the old climb from chapter 10 on, open from the start (MATH.md section 16).
enum Section { MAIN, HARD }
const SECTION_NAMES: PackedStringArray = ["Main", "Hard"]

## The section being shown and played, by index. Hard keeps each level's number: its levels before `hard_from` are
## the main path's, which it shares and never shows.
var levels: Array[Dictionary] = []
## Each {"name", "line", "count"}, for the section being shown. Empty for a level file without chapters. Hard's
## leave out the main path's chapters marked "after_hard", added after its levels were shelved (MATH.md section 22).
var chapters: Array[Dictionary] = []
var current: int = 0
var section: Section = Section.MAIN
## The index of the first Hard level.
var hard_from: int = 0
var _main: Array[Dictionary] = []
var _hard: Array[Dictionary] = []
var _main_chapters: Array[Dictionary] = []
var _hard_chapters: Array[Dictionary] = []

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("pack: cannot read %s" % PATH)
		return
	for entry: Variant in (data as Dictionary)["levels"]:
		_main.append(entry as Dictionary)
	for entry: Variant in (data as Dictionary).get("chapters", []):
		var chapter: Dictionary = entry
		_main_chapters.append(chapter)
		if not chapter.get("after_hard", false):
			_hard_chapters.append(chapter)
	_hard.assign(_main)
	var hard: Variant = JSON.parse_string(FileAccess.get_file_as_string(HARD_PATH)) if FileAccess.file_exists(HARD_PATH) \
		else null
	if typeof(hard) == TYPE_DICTIONARY:
		hard_from = int((hard as Dictionary)["first"])
		_hard.resize(hard_from)
		for entry: Variant in (hard as Dictionary)["levels"]:
			_hard.append(entry as Dictionary)
	use(section)

## The Levels screen's switch, which the kit shows when this exists.
func sections() -> PackedStringArray:
	return SECTION_NAMES if hard_from > 0 else PackedStringArray()

func use(which: int) -> void:
	section = which as Section
	levels = _hard if section == Section.HARD else _main
	chapters = _hard_chapters if section == Section.HARD else _main_chapters

func count() -> int:
	return levels.size()

func main_count() -> int:
	return _main.size()

## Levels in both sections, each counted once.
func total() -> int:
	return _main.size() + _hard.size() - hard_from

## The first level the section shows.
func first_level() -> int:
	return hard_from if section == Section.HARD else 0

## Whether `level` of the section in play is a Hard board, whose progress Save keeps apart.
func is_hard(level: int) -> bool:
	return section == Section.HARD and level >= hard_from

## The number a player sees (Shown): Hard counts its own levels from 1, while its index stays the one its saves and
## hard.json use.
func number(level: int) -> int:
	return level - hard_from + 1 if is_hard(level) else level + 1

## Hard counts its own chapters from 1 too.
func chapter_number(c: int) -> int:
	if section == Section.HARD and hard_from > 0:
		return c - chapter_of(hard_from) + 1
	return c + 1

## What a level is called before its number: a Hard level by the section's name.
func level_word(level: int) -> String:
	return SECTION_NAMES[Section.HARD] if is_hard(level) else "level"

## How analytics names a Hard level, from the number the kit sends (index + 1): "h" and the number Hard shows, so it
## never counts as the main path's level of that number. "" for a level of the main path, named by its number alone.
func level_tag(sent: int) -> String:
	return "h%d" % number(sent - 1) if is_hard(sent - 1) else ""

## The board id of a level of the section in play (REVAMP_PLAN.md section 4.1): main-0042 for the main path's 42nd,
## hard-0001 for Hard's first.
func id_of(level: int) -> String:
	return "hard-%04d" % (level - hard_from + 1) if is_hard(level) else "main-%04d" % (level + 1)

func board(level: int) -> TiltBoard:
	return TiltBoard.from_dict(levels[level])

func par(level: int) -> int:
	return int(levels[level]["par"])

## -1 when there are no chapters or `level` is past the last.
func chapter_of(level: int) -> int:
	var end: int = 0
	for c: int in range(chapters.size()):
		end += int(chapters[c]["count"])
		if level < end:
			return c
	return -1

func chapter_first(c: int) -> int:
	var first: int = 0
	for k: int in range(c):
		first += int(chapters[k]["count"])
	return first

func chapter_name(c: int) -> String:
	return String(chapters[c]["name"])

func chapter_line(c: int) -> String:
	return String(chapters[c]["line"])
