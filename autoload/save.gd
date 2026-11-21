extends Node

# ConfigFile rather than a Resource, because the file stays readable and a corrupt or older file degrades
# to defaults instead of failing to load.

const PATH: String = "user://plumb.cfg"
## The dev package's own screenshots for device checks, loaded by path and started only in a debug build with the
## dev_build feature: every other export preset leaves kit/debug/ out.
const DEV_SHOTS: String = "res://kit/debug/dev_shots.gd"

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
## Street holds still: no idle sway or bob, a flat street instead of a rolling one, and a tap answers with a short
## fade instead of a wobble (REVAMP_PLAN.md section 8).
var reduce_motion: bool = false
## Colour help: each colour's shape (ColourHelp) on its marbles and holes, so colours never need telling apart.
var colour_help: bool = false
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
## The look the game is played in (AppLook), and whether the player has chosen it. A save from before the looks has
## no choice yet, so a player updating sees the chooser once, as a new player does.
var app_look: String = AppLook.STREET
var look_chosen: bool = false
## Street's purse and keepsakes (REVAMP_PLAN.md section 4.7): coins, each helper's count by StreetRewards id, the
## doors whose parcel or milestone has been opened, the doors wearing a golden knocker, the shop's things owned
## (such as "hat_2" or "marbles_gems") and the hat each cast member wears (0 for none).
var coins: int = 0
var boosters: Dictionary = {}
var gifts: PackedInt32Array = PackedInt32Array()
var knockers: PackedInt32Array = PackedInt32Array()
var street_owned: PackedStringArray = PackedStringArray()
var worn: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## The day (Daily.today) whose daily puzzle Street last paid its coins for.
var daily_paid: int = -1
## Save layout 3 (REVAMP_PLAN.md section 4.6, StreetMigrate): stars by id for every board off the two fixed paths
## (extras, feed and recycled boards), the street with the rating (StreetPicker.fresh), whether the welcome purse
## was paid, and the player's random id (16 hex characters, never personal) and when it was made.
var best_ids: Dictionary = {}
var street: Dictionary = StreetPicker.fresh()
var welcomed: bool = false
var player_id: String = ""
var player_since: int = 0
## The level feed's serial last taken and when it was last looked at, in Unix seconds (Feed).
var feed_serial: int = 0
var feed_checked_at: int = 0
## The update card (PlayCore, UpdatePolicy): the day each offered version was last shown (by version code, as text),
## the version an update was started for from the card (0 for none), and the version code running last launch.
var update_shown: Dictionary = {}
var update_started: int = 0
var last_code: int = 0

signal coins_changed(total: int)
signal street_changed

func _ready() -> void:
	ScreenLock.start()
	if dev_shots_allowed(OS.is_debug_build(), OS.has_feature("dev_build")):
		add_child((load(DEV_SHOTS) as GDScript).new() as Node)
	restore()
	if player_id == "":
		player_id = new_player_id()
		player_since = int(Time.get_unix_time_from_system())
		store()
	StreetPool.warm()
	Looks.use_saved()
	Appearance.apply(theme)
	Supporter.start()
	Ads.start()
	Analytics.start()
	# The user properties (REVAMP_PLAN.md section 5.1), each launch.
	Analytics.user_property("player_id", player_id)
	if look_chosen:
		Analytics.user_property("app_look", app_look)
	Street.tell_analytics()
	PlayCore.start()
	PlayGames.start()

## Whether this build takes its own screenshots on request (DEV_SHOTS): a debug build of the dev package only.
static func dev_shots_allowed(debug: bool, dev_build: bool) -> bool:
	return debug and dev_build

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

## Every board's: both sections' and the boards kept by id.
func total_stars() -> int:
	var n: int = 0
	for s: int in stars:
		n += s
	for s: int in hard_stars:
		n += s
	for id: Variant in best_ids:
		n += int(best_ids[id])
	return n

## Boards solved, every one counted once, in either look.
func solved_count() -> int:
	var n: int = 0
	for s: int in stars:
		n += 1 if s > 0 else 0
	for s: int in hard_stars:
		n += 1 if s > 0 else 0
	for id: Variant in best_ids:
		n += 1 if int(best_ids[id]) > 0 else 0
	return n

## The best stars on board `id` (REVAMP_PLAN.md section 4.1): the two fixed paths' boards read their arrays by position,
## the rest the map by id.
func best_of(id: String) -> int:
	var index: int = _path_index(id)
	if index >= 0:
		return best_in(id.begins_with("hard-"), index)
	return int(best_ids.get(id, 0))

## Records stars on board `id`, and answers whether they beat the best.
func record_id(id: String, earned: int) -> bool:
	var index: int = _path_index(id)
	if index < 0:
		if earned <= int(best_ids.get(id, 0)):
			return false
		best_ids[id] = earned
		store()
		return true
	var hard: bool = id.begins_with("hard-")
	var of: PackedByteArray = hard_stars if hard else stars
	if of.size() <= index:
		of.resize(index + 1)
	if earned <= of[index]:
		return false
	of[index] = earned
	if hard:
		hard_stars = of
	else:
		stars = of
	store()
	return true

## A main or Hard board's index in its array, or -1 for a board kept by id.
static func _path_index(id: String) -> int:
	if id.contains("~") or id.length() != 9:
		return -1
	if id.begins_with("main-"):
		return int(id.substr(5)) - 1
	if id.begins_with("hard-"):
		return HardShelf.FIRST + int(id.substr(5)) - 1
	return -1

## 16 random hex characters: a player's id for analytics and the picker's seed, made on the first launch.
static func new_player_id(with_crypto: bool = not OS.has_feature("web")) -> String:
	# The web build's slim template has no crypto module, where Crypto.new() fails and stops the game at launch: there
	# a generator seeded by the system stands in, which is plenty for an id that only tells players apart.
	if with_crypto and ClassDB.can_instantiate(&"Crypto"):
		var crypto: Crypto = Crypto.new()
		return crypto.generate_random_bytes(8).hex_encode()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in range(8):
		bytes.append(rng.randi_range(0, 255))
	return bytes.hex_encode()

## The update card was shown for version `code` on day `day`. Only the latest few versions are kept.
func note_update_shown(code: int, day: String) -> void:
	update_shown[str(code)] = day
	while update_shown.size() > 4:
		update_shown.erase(update_shown.keys()[0])
	store()

func note_update_started(code: int) -> void:
	update_started = code
	store()

func note_running(code: int) -> void:
	if code != last_code:
		last_code = code
		store()

func set_feed(serial: int, checked_at: int) -> void:
	feed_serial = serial
	feed_checked_at = checked_at
	store()

## The street changed (a door picked, a solve rated): kept at once.
func set_street(state: Dictionary) -> void:
	street = state
	store()
	street_changed.emit()

## Unlocks asks this rather than reading `opened`, so each section has its own.
func was_opened(level: int) -> bool:
	return (hard_opened if Pack.is_hard(level) else opened).has(level)

## Forgets the stars only, with the street they made and the knockers they earned: settings, purchases, keys, coins,
## opened parcels and the levels they opened stay.
func reset() -> void:
	stars = PackedByteArray()
	hard_stars = PackedByteArray()
	best_ids = {}
	street = StreetPicker.fresh()
	knockers = PackedInt32Array()
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
	_setting("sounds", "%.1f" % sound_volume)
	EventBus.settings_changed.emit()

func set_music_volume(volume: float) -> void:
	hear_music_volume(volume)
	store()
	_setting("music", "%.1f" % music_volume)
	EventBus.settings_changed.emit()

## A setting changed, for analytics (REVAMP_PLAN.md section 5.2).
static func _setting(name: String, value: String) -> void:
	Analytics.event(&"setting", {"setting": name, "value": value})

## A volume as decibels, on a square law: the middle of a slider sounds about half as loud as the end.
static func volume_db(volume: float) -> float:
	return linear_to_db(volume * volume) if volume > 0.0 else -80.0

func set_haptics(on: bool) -> void:
	haptics_on = on
	store()
	_setting("haptics", "on" if on else "off")
	EventBus.settings_changed.emit()

func set_phone_tilt(on: bool) -> void:
	phone_tilt = on
	store()
	EventBus.settings_changed.emit()

func set_faces(on: bool) -> void:
	faces = on
	store()
	EventBus.settings_changed.emit()

func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	store()
	_setting("reduce_motion", "on" if on else "off")
	EventBus.settings_changed.emit()

func set_colour_help(on: bool) -> void:
	colour_help = on
	ColourHelp.on = on
	store()
	_setting("colour_help", "on" if on else "off")
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

func add_coins(n: int) -> void:
	coins = maxi(coins + n, 0)
	store()
	coins_changed.emit(coins)

## Spends `n` coins if there are enough, and answers whether it did.
func spend_coins(n: int) -> bool:
	if coins < n:
		return false
	add_coins(-n)
	return true

func booster_count(id: String) -> int:
	var n: int = boosters.get(id, 0)
	return n

func add_booster(id: String, n: int) -> void:
	boosters[id] = maxi(booster_count(id) + n, 0)
	store()
	street_changed.emit()

## Marks door `n`'s parcel or milestone as opened, and answers whether it was still waiting.
func claim_gift(n: int) -> bool:
	if gifts.has(n):
		return false
	gifts.append(n)
	store()
	return true

func set_knocker(n: int) -> void:
	if not knockers.has(n):
		knockers.append(n)
		store()

func own_street(item: String) -> void:
	if not street_owned.has(item):
		street_owned.append(item)
		store()
		street_changed.emit()

## Pays the day's puzzle's coins once, when it is solved, and answers whether it paid.
func pay_daily(day: int, solved: bool) -> bool:
	if not solved or daily_paid == day:
		return false
	daily_paid = day
	add_coins(StreetRewards.DAILY)
	return true

## Puts hat `hat` (1 and up, or 0 for none) on cast member `member`.
func wear(member: int, hat: int) -> void:
	worn[member] = hat
	store()
	street_changed.emit()

func set_app_look(look: String) -> void:
	if not AppLook.valid(look):
		return
	var from: String = app_look if look_chosen else ""
	app_look = look
	look_chosen = true
	# Each look picks up where the other left off (REVAMP_PLAN.md section 4.5).
	if look == AppLook.STREET:
		Street.absorb_classic()
	else:
		Street.open_in_classic()
	store()
	Analytics.event(&"look_choose", {"look": look, "from": from, "how": "settings" if from != "" else "first"})
	Analytics.user_property("app_look", look)
	EventBus.settings_changed.emit()

## A save from before the Hard levels moves on to them once, here, then one from before Street to layout 3, and so
## does a copy from the cloud (CloudSave).
func upgrade(file: ConfigFile) -> bool:
	var shelved: bool = HardShelf.migrate(file, Unlocks.GATE)
	var streeted: bool = StreetMigrate.upgrade(file, StreetPool.shared())
	return shelved or streeted

## Where a save older than layout 3 is copied, once, before it moves on.
func backup_path() -> String:
	return path.get_basename() + ".layout2.cfg"

## The cloud save's join rules for the keys layout 3 added, beside the kit's own (CloudSave.RULES): stars by id keep
## the better, helpers and coins the larger (the generous side), opened gifts, knockers and things owned join, and the
## street with its rating comes from the copy with more doors solved.
func cloud_rules() -> Dictionary:
	return {
		"progress/best": &"most_each",
		"street/state": &"street",
		"street/coins": &"most",
		"street/boosters": &"most_each",
		"street/gifts": &"union",
		"street/knockers": &"union",
		"street/owned": &"words",
		"street/welcomed": &"either",
		"street/daily_paid": &"most",
	}

func cloud_join(rule: StringName, a: Variant, b: Variant) -> Variant:
	match rule:
		&"most_each":
			return StreetMigrate.join_most_each(a, b)
		&"street":
			return StreetMigrate.join_street(a, b)
		&"words":
			return StreetMigrate.join_words(a, b)
	return a

func restore() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	if int(file.get_value("progress", "layout", 1)) < StreetMigrate.LAYOUT and not FileAccess.file_exists(backup_path()):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path()))
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
	reduce_motion = bool(file.get_value("settings", "reduce_motion", false))
	colour_help = bool(file.get_value("settings", "colour_help", false))
	ColourHelp.on = colour_help
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
	var look: String = str(file.get_value("settings", "app_look", AppLook.STREET))
	app_look = look if AppLook.valid(look) else AppLook.STREET
	look_chosen = bool(file.get_value("settings", "look_chosen", false))
	coins = int(file.get_value("street", "coins", 0))
	var helpers: Variant = file.get_value("street", "boosters", {})
	boosters = helpers if helpers is Dictionary else {}
	gifts = PackedInt32Array(file.get_value("street", "gifts", PackedInt32Array()))
	knockers = PackedInt32Array(file.get_value("street", "knockers", PackedInt32Array()))
	street_owned = PackedStringArray(file.get_value("street", "owned", PackedStringArray()))
	var hats: PackedInt32Array = PackedInt32Array(file.get_value("street", "worn", PackedInt32Array([0, 0, 0, 0])))
	worn = hats if hats.size() == 4 else PackedInt32Array([0, 0, 0, 0])
	daily_paid = int(file.get_value("street", "daily_paid", -1))
	var by_id: Variant = file.get_value("progress", "best", {})
	best_ids = by_id if by_id is Dictionary else {}
	street = StreetPicker.fresh()
	var saved_street: Variant = file.get_value("street", "state", {})
	if saved_street is Dictionary:
		street.merge(saved_street as Dictionary, true)
	welcomed = bool(file.get_value("street", "welcomed", false))
	player_id = str(file.get_value("player", "id", ""))
	player_since = int(file.get_value("player", "since", 0))
	feed_serial = int(file.get_value("feed", "serial", 0))
	feed_checked_at = int(file.get_value("feed", "checked_at", 0))
	var shown: Variant = file.get_value("update", "shown", {})
	update_shown = shown if shown is Dictionary else {}
	update_started = int(file.get_value("update", "started", 0))
	last_code = int(file.get_value("update", "last_code", 0))

func store() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("progress", "layout", StreetMigrate.LAYOUT)
	file.set_value("progress", "best", best_ids)
	file.set_value("street", "state", street)
	file.set_value("street", "welcomed", welcomed)
	file.set_value("player", "id", player_id)
	file.set_value("player", "since", player_since)
	file.set_value("feed", "serial", feed_serial)
	file.set_value("feed", "checked_at", feed_checked_at)
	file.set_value("update", "shown", update_shown)
	file.set_value("update", "started", update_started)
	file.set_value("update", "last_code", last_code)
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
	file.set_value("settings", "reduce_motion", reduce_motion)
	file.set_value("settings", "colour_help", colour_help)
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
	file.set_value("settings", "app_look", app_look)
	file.set_value("settings", "look_chosen", look_chosen)
	file.set_value("street", "coins", coins)
	file.set_value("street", "boosters", boosters)
	file.set_value("street", "gifts", gifts)
	file.set_value("street", "knockers", knockers)
	file.set_value("street", "owned", street_owned)
	file.set_value("street", "worn", worn)
	file.set_value("street", "daily_paid", daily_paid)
	file.save(path)
