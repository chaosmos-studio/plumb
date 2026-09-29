extends Node

# Progress and settings. ConfigFile rather than a Resource, because the file stays readable and a corrupt
# or older file degrades to defaults instead of failing to load.

const PATH: String = "user://tilt.cfg"

## Best stars per level, 0 for not yet solved.
var stars: PackedByteArray = PackedByteArray()
var sound_on: bool = true
var haptics_on: bool = true

func _ready() -> void:
	restore()

func best(level: int) -> int:
	return stars[level] if level < stars.size() else 0

## Level 0 is always open; any other opens once the one before it has been solved.
func unlocked(level: int) -> bool:
	return level == 0 or best(level - 1) > 0

## Keeps the best result. Returns true if this was an improvement.
func record(level: int, earned: int) -> bool:
	if stars.size() <= level:
		stars.resize(level + 1)
	if earned <= stars[level]:
		return false
	stars[level] = earned
	store()
	return true

## The first level not yet solved, which is where Play takes you.
func frontier(count: int) -> int:
	for i: int in range(count):
		if best(i) == 0:
			return i
	return count - 1

func total_stars() -> int:
	var n: int = 0
	for s: int in stars:
		n += s
	return n

func set_sound(on: bool) -> void:
	sound_on = on
	store()
	EventBus.settings_changed.emit()

func set_haptics(on: bool) -> void:
	haptics_on = on
	store()
	EventBus.settings_changed.emit()

func restore() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(PATH) != OK:
		return
	var saved: Variant = file.get_value("progress", "stars", PackedByteArray())
	if saved is PackedByteArray:
		stars = saved
	sound_on = bool(file.get_value("settings", "sound_on", true))
	haptics_on = bool(file.get_value("settings", "haptics_on", true))

func store() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("progress", "stars", stars)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "haptics_on", haptics_on)
	file.save(PATH)
