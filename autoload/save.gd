extends Node

# Progress and settings. ConfigFile rather than a Resource, because the file stays readable and a corrupt
# or older file degrades to defaults instead of failing to load.

const PATH: String = "user://plumb.cfg"

## Overridable so test robots never touch the player's real progress.
var path: String = PATH

## Best stars per level, 0 for not yet solved.
var stars: PackedByteArray = PackedByteArray()
## Whether the sounds and the music are on: set from their volumes, 0 being off.
var sound_on: bool = true
var music_on: bool = true
## How loud the sounds and the music are, 0 to 1, as the Settings sliders set them.
var sound_volume: float = 1.0
var music_volume: float = 1.0
var haptics_on: bool = true
## Whether tipping the phone tilts the board too (PhoneTilt), as well as swiping.
var phone_tilt: bool = false
## An Appearance.Choice.
var theme: int = Appearance.native()
## Whether the first level's guide has been seen through or skipped.
var tutorial_seen: bool = false
## Whether this Google account owns the Supporter pack, as Play last said, so it holds offline.
var supporter: bool = false
## The other one-time products it owns (GameMonetize ids), the same way.
var owned: PackedStringArray = PackedStringArray()
## How many tips it has given. They open nothing; About says thank you.
var tips: int = 0
## Level keys not yet used, and the levels opened one by one, with a key or a video (Unlocks).
var keys: int = 0
var opened: PackedInt32Array = PackedInt32Array()
## Packs lent by a video, by product id: [start, end] in Unix seconds (Passes).
var passes: Dictionary = {}
## The look in use (GameLooks), or "" for the game's own.
var look: String = ""
## The colour theme in use (Themes), or "" for the game's own.
var palette: String = ""
## The local date of the last free hint taken, and how many were taken that day.
var hint_day: String = ""
var hints_used: int = 0
## The last milestone the rating prompt asked at (RatePrompt), and whether the player chose to rate.
var rate_asked: int = 0
var rated: bool = false

func _ready() -> void:
	restore()
	Looks.use_saved()
	Appearance.apply(theme)
	Supporter.start()
	Ads.start()
	Analytics.start()

func best(level: int) -> int:
	return stars[level] if level < stars.size() else 0

func unlocked(level: int) -> bool:
	return Unlocks.is_open(level)

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

## Forgets every star. Settings, purchases, keys, the levels they opened, tips, today's hints and the rating
## prompt's place are kept.
func reset() -> void:
	stars = PackedByteArray()
	store()
	EventBus.settings_changed.emit()

func set_sound(on: bool) -> void:
	set_sound_volume(1.0 if on else 0.0)

func set_music(on: bool) -> void:
	set_music_volume(1.0 if on else 0.0)

## A volume taken while a slider moves, heard at once and saved by the setter when it comes to rest.
func hear_sound_volume(volume: float) -> void:
	sound_volume = clampf(volume, 0.0, 1.0)
	sound_on = sound_volume > 0.0

func hear_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	music_on = music_volume > 0.0

func set_sound_volume(volume: float) -> void:
	hear_sound_volume(volume)
	store()
	EventBus.settings_changed.emit()

func set_music_volume(volume: float) -> void:
	hear_music_volume(volume)
	store()
	EventBus.settings_changed.emit()

## A volume as decibels, on a square law: the middle of a slider sounds about half as loud as the end.
static func volume_db(volume: float) -> float:
	return linear_to_db(volume * volume) if volume > 0.0 else -80.0

func set_haptics(on: bool) -> void:
	haptics_on = on
	store()
	EventBus.settings_changed.emit()

func set_phone_tilt(on: bool) -> void:
	phone_tilt = on
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

func set_owned(id: String, on: bool) -> void:
	if owned.has(id) == on:
		return
	if on:
		owned.append(id)
	else:
		owned.remove_at(owned.find(id))
	store()
	EventBus.settings_changed.emit()

func add_tip() -> void:
	tips += 1
	store()

func add_keys(n: int) -> void:
	keys = maxi(keys + n, 0)
	store()
	EventBus.settings_changed.emit()

func open_level(level: int) -> void:
	if opened.has(level):
		return
	opened.append(level)
	store()
	EventBus.settings_changed.emit()

func set_pass(id: String, start: int, end: int) -> void:
	passes[id] = [start, end]
	store()
	EventBus.settings_changed.emit()

func set_look(id: String) -> void:
	look = id
	store()

func set_palette(id: String) -> void:
	palette = id
	store()

func set_hints(day: String, used: int) -> void:
	hint_day = day
	hints_used = used
	store()

func set_rating(asked: int, did_rate: bool) -> void:
	rate_asked = asked
	rated = rated or did_rate
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
	# A save from before the sliders has only the switches: on is full volume.
	hear_sound_volume(float(file.get_value("settings", "sound_volume", 1.0 if sound_on else 0.0)))
	hear_music_volume(float(file.get_value("settings", "music_volume", 1.0 if music_on else 0.0)))
	haptics_on = bool(file.get_value("settings", "haptics_on", true))
	phone_tilt = bool(file.get_value("settings", "phone_tilt", false))
	theme = clampi(int(file.get_value("settings", "theme", Appearance.native())), 0, Appearance.Choice.size() - 1)
	tutorial_seen = bool(file.get_value("progress", "tutorial_seen", false))
	supporter = bool(file.get_value("monetize", "supporter", false))
	hint_day = str(file.get_value("monetize", "hint_day", ""))
	hints_used = maxi(int(file.get_value("monetize", "hints_used", 0)), 0)
	var bought: Variant = file.get_value("monetize", "owned", PackedStringArray())
	if bought is PackedStringArray:
		owned = bought
	tips = maxi(int(file.get_value("monetize", "tips", 0)), 0)
	keys = maxi(int(file.get_value("monetize", "keys", 0)), 0)
	var opened_saved: Variant = file.get_value("progress", "opened", PackedInt32Array())
	if opened_saved is PackedInt32Array:
		opened = opened_saved
	var lent: Variant = file.get_value("monetize", "passes", {})
	if lent is Dictionary:
		passes = lent
	look = str(file.get_value("settings", "look", ""))
	palette = str(file.get_value("settings", "palette", ""))
	rate_asked = maxi(int(file.get_value("rating", "asked", 0)), 0)
	rated = bool(file.get_value("rating", "rated", false))

func store() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("progress", "stars", stars)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "music_on", music_on)
	file.set_value("settings", "sound_volume", sound_volume)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "haptics_on", haptics_on)
	file.set_value("settings", "phone_tilt", phone_tilt)
	file.set_value("settings", "theme", theme)
	file.set_value("progress", "tutorial_seen", tutorial_seen)
	file.set_value("monetize", "supporter", supporter)
	file.set_value("monetize", "hint_day", hint_day)
	file.set_value("monetize", "hints_used", hints_used)
	file.set_value("monetize", "owned", owned)
	file.set_value("monetize", "tips", tips)
	file.set_value("monetize", "keys", keys)
	file.set_value("progress", "opened", opened)
	file.set_value("monetize", "passes", passes)
	file.set_value("settings", "look", look)
	file.set_value("settings", "palette", palette)
	file.set_value("rating", "asked", rate_asked)
	file.set_value("rating", "rated", rated)
	file.save(path)
