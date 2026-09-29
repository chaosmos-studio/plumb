extends Node

# The level set, loaded once from the generated file, and which level is being played.

const PATH: String = "res://levels/levels.json"

var levels: Array[Dictionary] = []
var current: int = 0

func _ready() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("pack: cannot read %s" % PATH)
		return
	for entry: Variant in (data as Dictionary)["levels"]:
		levels.append(entry as Dictionary)

func count() -> int:
	return levels.size()

func board(level: int) -> TiltBoard:
	return TiltBoard.from_dict(levels[level])

func par(level: int) -> int:
	return int(levels[level]["par"])
