extends Node

# Progress and settings. ConfigFile rather than a Resource, because the file stays readable and a corrupt
# or older file degrades to defaults instead of failing to load.

const PATH: String = "user://plumb.cfg"

## Overridable so test robots never touch the player's real progress.
var path: String = PATH

## Best stars per level, 0 for not yet solved.
var stars: PackedByteArray = PackedByteArray()
var sound_on: bool = true
var music_on: bool = true
var haptics_on: bool = true
## An Appearance.Choice.
var theme: int = Appearance.native()
## Whether the first level's guide has been seen through or skipped.
var tutorial_seen: bool = false
## Whether this Google account owns the Supporter pack, as Play last said, so it holds offline.
var supporter: bool = false
## The local date of the last free hint taken, and how many were taken that day.
var hint_day: String = ""
var hints_used: int = 0

func _ready() -> void:
	restore()
	Appearance.apply(theme)
	Supporter.start()
	Ads.start()

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

## Forgets every star. Settings, the Supporter pack and today's hints are kept.
func reset() -> void:
	stars = PackedByteArray()
	store()
	EventBus.settings_changed.emit()

func set_sound(on: bool) -> void:
	sound_on = on
	store()
	EventBus.settings_changed.emit()

func set_music(on: bool) -> void:
	music_on = on
	store()
	EventBus.settings_changed.emit()

func set_haptics(on: bool) -> void:
	haptics_on = on
	store()
	EventBus.settings_changed.emit()

func set_theme(choice: int) -> void:
	theme = choice
	store()

func set_tutorial_seen(seen: bool) -> void:
	tutorial_seen = seen
	store()

func set_supporter(on: bool) -> void:
	supporter = on
	store()
	EventBus.settings_changed.emit()

func set_hints(day: String, used: int) -> void:
	hint_day = day
	hints_used = used
	store()

func restore() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	var saved: Variant = file.get_value("progress", "stars", PackedByteArray())
	if saved is PackedByteArray:
		stars = saved
	sound_on = bool(file.get_value("settings", "sound_on", true))
	music_on = bool(file.get_value("settings", "music_on", true))
	haptics_on = bool(file.get_value("settings", "haptics_on", true))
	theme = clampi(int(file.get_value("settings", "theme", Appearance.native())), 0, Appearance.Choice.size() - 1)
	tutorial_seen = bool(file.get_value("progress", "tutorial_seen", false))
	supporter = bool(file.get_value("monetize", "supporter", false))
	hint_day = str(file.get_value("monetize", "hint_day", ""))
	hints_used = maxi(int(file.get_value("monetize", "hints_used", 0)), 0)

func store() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("progress", "stars", stars)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "music_on", music_on)
	file.set_value("settings", "haptics_on", haptics_on)
	file.set_value("settings", "theme", theme)
	file.set_value("progress", "tutorial_seen", tutorial_seen)
	file.set_value("monetize", "supporter", supporter)
	file.set_value("monetize", "hint_day", hint_day)
	file.set_value("monetize", "hints_used", hints_used)
	file.save(path)
