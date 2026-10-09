extends Node

const PATH: String = "res://levels/levels.json"

var levels: Array[Dictionary] = []
## Each {"name", "line", "count"}. Empty for a level file without chapters.
var chapters: Array[Dictionary] = []
var current: int = 0

func _ready() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("pack: cannot read %s" % PATH)
		return
	for entry: Variant in (data as Dictionary)["levels"]:
		levels.append(entry as Dictionary)
	for entry: Variant in (data as Dictionary).get("chapters", []):
		chapters.append(entry as Dictionary)

func count() -> int:
	return levels.size()

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
