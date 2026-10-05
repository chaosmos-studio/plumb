class_name Passes
extends RefCounted

## Packs lent for a short video. On Google Play the Looks pack, the Themes pack and Every level can each be
## had for HOURS after a rewarded video, as often as the player likes, so the free game can try everything
## the shop sells. The Supporter pack is not lent, since a video for no videos says nothing, and nor is the
## Complete pack, which is the four together. A pass counts from the wall clock and is saved, so it
## survives the app being closed; a clock turned back past its start ends it. When one runs out, whatever
## it lent is put back at once: a look or theme in use goes back to the free one, and the level grid shuts
## again. A level being played through it is left to finish, and every level solved stays solved, so the
## one after it stays open.
##
## The kit expects from the game: in `Save`, `passes` (product id to [start, end] in Unix seconds) and
## `set_pass(id, start, end)`, and Save._ready calling `Supporter.start()`, which starts the watch here.

const HOURS: int = 6
## How often a running pass is looked at, in seconds. Timers stop while the app is in the background, so
## the clock is read rather than trusted to a single timer.
const CHECK_EVERY: float = 20.0

## Seconds added to the clock, so tests can run a pass out.
static var skew: int = 0

static var _watch: _Watch
static var _running: PackedStringArray = PackedStringArray()

static func now() -> int:
	return int(Time.get_unix_time_from_system()) + skew

## The packs a video can lend.
static func lendable() -> PackedStringArray:
	return PackedStringArray([GameMonetize.LEVELS_ID, GameMonetize.LOOKS_ID, GameMonetize.THEMES_ID])

static func active(id: String) -> bool:
	return left(id) > 0

## Seconds the pass for `id` has left, or 0.
static func left(id: String) -> int:
	var span: Variant = Save.passes.get(id)
	if not span is Array or (span as Array).size() != 2:
		return 0
	var t: int = now()
	var start: int = int((span as Array)[0])
	var end: int = int((span as Array)[1])
	return end - t if t >= start and t < end else 0

## Whether a video could lend `id` now: one of the packs lent, not owned, not already lent, and a video to
## be had.
static func offers(id: String) -> bool:
	return Supporter.on_play and lendable().has(id) and not Shop.has(id) and not active(id) and Ads.rewards()

## A video, then `id` for HOURS. `on_lent` runs once it is lent.
static func lend(id: String, on_lent: Callable = Callable()) -> void:
	var lent: Callable = func() -> void:
		var t: int = now()
		Save.set_pass(id, t, t + HOURS * 3600)
		_settle()
		Supporter.say("Trying %s for %d hours" % [_called(id), HOURS])
		if on_lent.is_valid():
			on_lent.call()
	Ads.rewarded(lent, _no_video)

## A video for one level key.
static func give_key(on_given: Callable = Callable()) -> void:
	var given: Callable = func() -> void:
		Save.add_keys(1)
		Supporter.say("A key is yours. You have %d" % Save.keys)
		if on_given.is_valid():
			on_given.call()
	Ads.rewarded(given, _no_video)

## The time a pass has left, in words: "5 h 12 min", "40 min", or "1 min" at the last.
static func say_left(id: String) -> String:
	var minutes: int = maxi(1, ceili(left(id) / 60.0))
	var hours: int = floori(minutes / 60.0)
	if hours == 0:
		return "%d min" % minutes
	return "%d h %d min" % [hours, minutes % 60] if minutes % 60 > 0 else "%d h" % hours

## A pack's name inside a sentence: "the Themes pack", but "Every level".
static func _called(id: String) -> String:
	return Shop.title(id) if id == GameMonetize.LEVELS_ID else "the " + Shop.title(id)

static func _no_video() -> void:
	Supporter.say("No video right now. Try again in a moment")

## Starts looking after the passes, once, at launch.
static func start() -> void:
	_running = _now_running()
	if is_instance_valid(_watch):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_watch = _Watch.new()
	tree.root.add_child.call_deferred(_watch)

## Puts back what passes that have ended had lent, and remembers the ones still running.
static func _settle() -> void:
	var was: PackedStringArray = _running
	_running = _now_running()
	for id: String in was:
		if not _running.has(id):
			_ended(id)

static func _now_running() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: String in lendable():
		if active(id):
			out.append(id)
	return out

## A pass ran out. A look or theme it lent that is in use goes back to the free one, rebuilding the screen
## in it, and the level grid shuts what it opened. A level being played is left to finish.
static func _ended(id: String) -> void:
	if Shop.has(id):
		return
	Supporter.say("Your try of %s has ended" % _called(id))
	EventBus.settings_changed.emit()
	var in_use: bool = (id == GameMonetize.LOOKS_ID and Save.look != "" and Save.look != Looks.free_id()) \
		or (id == GameMonetize.THEMES_ID and Save.palette != "" and Save.palette != Themes.OWN)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if in_use and tree != null:
		GameLooks.use(Looks.current())
		Appearance.apply(Save.theme)
		Appearance.rebuild(tree)

## Reads the clock every few seconds and as the app comes back, so a pass ends on time.
class _Watch extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var timer: Timer = Timer.new()
		timer.wait_time = CHECK_EVERY
		timer.timeout.connect(Passes._settle)
		add_child(timer)
		timer.start()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			Passes._settle()
