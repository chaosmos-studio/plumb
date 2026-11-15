extends Node

# ConfigFile rather than a Resource, because the file stays readable and a corrupt or older file degrades
# to defaults instead of failing to load.

const PATH: String = "user://plumb.cfg"

## Overridable so test robots never touch the player's real progress.
var path: String = PATH

## Best stars per level of the main path, 0 for not yet solved.
var stars: PackedByteArray = PackedByteArray()
## The same for the Hard levels, by their index in Pack's Hard section, so 0 before Pack.hard_from.
var hard_stars: PackedByteArray = PackedByteArray()
## Set from the volumes, 0 being off.
var sound_on: bool = true
var music_on: bool = true
## 0 to 1, as the Settings sliders set them.
var sound_volume: float = 1.0
var music_volume: float = 1.0
var haptics_on: bool = true
var phone_tilt: bool = false
## The marbles' faces, on for everyone until turned off.
var faces: bool = true:
	set(value):
		faces = value
		Cast.showing = value
## Walls drawn as sleeping cats and dogs, off until a player turns it on: some want calm, plain walls.
var pets: bool = false
## An Appearance.Choice.
var theme: int = Appearance.native()
var tutorial_seen: bool = false
## As Play last said, so the Supporter pack holds offline.
var supporter: bool = false
## The other one-time products owned, by GameMonetize id, kept the same way.
var owned: PackedStringArray = PackedStringArray()
var tips: int = 0
## Level keys not yet used, and the levels opened with a key or a video (Unlocks), on the main path and in Hard.
var keys: int = 0
var opened: PackedInt32Array = PackedInt32Array()
var hard_opened: PackedInt32Array = PackedInt32Array()
## Packs lent by a video, by product id: [start, end] in Unix seconds (Passes).
var passes: Dictionary = {}
## A GameLooks id, or "" for the game's own.
var look: String = ""
## A Themes id, or "" for the game's own.
var palette: String = ""
## A local date, and the free hints taken on it.
var hint_day: String = ""
var hints_used: int = 0
## The milestone RatePrompt last asked at, and whether the player chose to rate.
var rate_asked: int = 0
var rated: bool = false
## The daily puzzles: the first time of each day solved, the days solved late, the days a video opened and the
## time spent on days not solved yet (Daily).
var daily: Dictionary = {}

func _ready() -> void:
	ScreenLock.start()
	restore()
	Looks.use_saved()
	Appearance.apply(theme)
	Supporter.start()
	Ads.start()
	Analytics.start()
	PlayCore.start()
	PlayGames.start()

## Of the level in Pack's section now.
func best(level: int) -> int:
	return best_in(Pack.is_hard(level), level)

func best_in(hard: bool, level: int) -> int:
	var of: PackedByteArray = hard_stars if hard else stars
	return of[level] if level < of.size() else 0

func unlocked(level: int) -> bool:
	return Unlocks.is_open(level)

func record(level: int, earned: int) -> bool:
	var hard: bool = Pack.is_hard(level)
	var of: PackedByteArray = hard_stars if hard else stars
	if of.size() <= level:
		of.resize(level + 1)
	if earned <= of[level]:
		return false
	of[level] = earned
	if hard:
		hard_stars = of
	else:
		stars = of
	store()
	return true

## The first level not yet solved in Pack's section now, from the first it shows.
func frontier(count: int) -> int:
	for i: int in range(Pack.first_level(), count):
		if best(i) == 0:
			return i
	return count - 1

## Where Play goes: the first level of the main path not yet solved, whichever section is shown.
func main_frontier() -> int:
	var count: int = Pack.main_count()
	for i: int in range(count):
		if best_in(false, i) == 0:
			return i
	return count - 1

## Both sections'.
func total_stars() -> int:
	var n: int = 0
	for s: int in stars:
		n += s
	for s: int in hard_stars:
		n += s
	return n

## Unlocks asks this rather than reading `opened`, so each section has its own.
func was_opened(level: int) -> bool:
	return (hard_opened if Pack.is_hard(level) else opened).has(level)

## Forgets the stars only: settings, purchases, keys and the levels they opened stay.
func reset() -> void:
	stars = PackedByteArray()
	hard_stars = PackedByteArray()
	store()
	EventBus.settings_changed.emit()

func set_sound(on: bool) -> void:
	set_sound_volume(1.0 if on else 0.0)

func set_music(on: bool) -> void:
	set_music_volume(1.0 if on else 0.0)

## While a slider moves: heard at once, and saved by the setter only when it comes to rest.
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

func set_faces(on: bool) -> void:
	faces = on
	store()
	EventBus.settings_changed.emit()

func set_pets(on: bool) -> void:
	pets = on
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
	if was_opened(level):
		return
	if Pack.is_hard(level):
		hard_opened.append(level)
	else:
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

func set_daily(record: Dictionary) -> void:
	daily = record
	store()

## A save from before the Hard levels moves on to them once, here, and so does a copy from the cloud (CloudSave).
func upgrade(file: ConfigFile) -> bool:
	return HardShelf.migrate(file, Unlocks.GATE)

func restore() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	if upgrade(file):
		file.save(path)
	var saved: Variant = file.get_value("progress", "stars", PackedByteArray())
	if saved is PackedByteArray:
		stars = saved
	var hard_saved: Variant = file.get_value("progress", "hard", PackedByteArray())
	if hard_saved is PackedByteArray:
		hard_stars = hard_saved
	sound_on = bool(file.get_value("settings", "sound_on", true))
	music_on = bool(file.get_value("settings", "music_on", true))
	# A save from before the sliders has only the switches: on is full volume.
	hear_sound_volume(float(file.get_value("settings", "sound_volume", 1.0 if sound_on else 0.0)))
	hear_music_volume(float(file.get_value("settings", "music_volume", 1.0 if music_on else 0.0)))
	haptics_on = bool(file.get_value("settings", "haptics_on", true))
	phone_tilt = bool(file.get_value("settings", "phone_tilt", false))
	faces = bool(file.get_value("settings", "faces", true))
	pets = bool(file.get_value("settings", "pets", false))
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
	var hard_opened_saved: Variant = file.get_value("progress", "hard_opened", PackedInt32Array())
	if hard_opened_saved is PackedInt32Array:
		hard_opened = hard_opened_saved
	var lent: Variant = file.get_value("monetize", "passes", {})
	if lent is Dictionary:
		passes = lent
	look = str(file.get_value("settings", "look", ""))
	palette = str(file.get_value("settings", "palette", ""))
	rate_asked = maxi(int(file.get_value("rating", "asked", 0)), 0)
	rated = bool(file.get_value("rating", "rated", false))
	var record: Variant = file.get_value("daily", "record", {})
	if record is Dictionary:
		daily = record

func store() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("progress", "layout", HardShelf.LAYOUT)
	file.set_value("progress", "stars", stars)
	file.set_value("progress", "hard", hard_stars)
	file.set_value("progress", "hard_opened", hard_opened)
	file.set_value("settings", "sound_on", sound_on)
	file.set_value("settings", "music_on", music_on)
	file.set_value("settings", "sound_volume", sound_volume)
	file.set_value("settings", "music_volume", music_volume)
	file.set_value("settings", "haptics_on", haptics_on)
	file.set_value("settings", "phone_tilt", phone_tilt)
	file.set_value("settings", "faces", faces)
	file.set_value("settings", "pets", pets)
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
	file.set_value("daily", "record", daily)
	file.save(path)
