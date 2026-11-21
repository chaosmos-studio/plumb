extends Node

## Plays the banner through every way a phone reaches it, with a fake backend, and prints one line a check.
## Run: godot --headless --path . res://kit/tools/banner_check.tscn
## Screens change in two orders: kit v3 adds the new screen before freeing the old one, older kits free the
## old one first. The app starts a screen in the frame before its ad backend is in the tree. Each of these once
## left the banner off until the player changed screens again.

var _failures: int = 0

func _ready() -> void:
	# The studio's opening keeps the banner back while it plays (tests/run_tests.gd checks that), so the screens here
	# open as they do once it has played.
	Intro.enabled = false
	Save.path = "user://banner_check.cfg"
	Save.supporter = false
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(Pack.count())
	for i: int in range(AdPacing.BANNER_AFTER):
		stars[i] = 3
	Save.stars = stars
	await _run()
	print("BANNER CHECK: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

func _run() -> void:
	Ads.use(null)
	var fake: _Fake = _Fake.new()
	# As at launch: the backend joins the tree a frame after the first screen asks for the banner.
	Ads._attach(fake, true)
	var title: Node = load(Brand.TITLE_SCENE).instantiate()
	add_child(title)
	await _frames(3)
	_check(fake.banner_on, "the title has the banner from launch")

	var levels: Node = load(Brand.LEVELS_SCENE).instantiate()
	add_child(levels)
	await _frames(1)
	title.queue_free()
	await _frames(3)
	_check(fake.banner_on, "it stays when the new screen comes before the old one goes")

	levels.queue_free()
	await _frames(1)
	title = load(Brand.TITLE_SCENE).instantiate()
	add_child(title)
	await _frames(3)
	_check(fake.banner_on, "and when the old screen goes first")

	var sheet: Sheet = Sheet.open(title)
	await _frames(3)
	_check(not fake.banner_on, "a sheet hides it")
	sheet.close()
	await get_tree().create_timer(0.6).timeout
	_check(fake.banner_on, "and it comes back when the sheet closes")

	var result: Sheet = Sheet.open(title, true, false, true)
	await _frames(3)
	_check(fake.banner_on and Ads.banner_room() > 0.0, "a result sheet keeps it, with room under the panel")
	result.close()
	await get_tree().create_timer(0.6).timeout

	_check(Ads.BANNER_LAYER > Sheet.LAYER, "a banner the game draws sits above sheets")

	Ads.hide_banner(title)
	await _frames(1)
	_check(not fake.banner_on, "leaving a screen takes the banner with it at once")
	title.queue_free()
	await _frames(2)
	_check(not fake.banner_on, "and no screen, no banner")
	Ads.use(null)

func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1

func _frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().process_frame

class _Fake extends AdBackend:
	var banner_on: bool = false

	func ready_to_show(_kind: StringName) -> bool:
		return false

	func present(kind: StringName) -> void:
		finished.emit.call_deferred(kind, false, false)

	func set_banner(on: bool) -> void:
		var first: bool = on and not banner_on
		banner_on = on
		if first:
			banner_changed.emit.call_deferred(112.0)
