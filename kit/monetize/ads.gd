class_name Ads
extends RefCounted

## An ad that is not loaded simply does not show, so the game never waits for one.
##
## The kit expects from the game:
## - `GameMonetize` (res://monetize.gd) with ADMOB, APP_ID, BANNER_ID, INTERSTITIAL_ID, REWARDED_ID and
##   SUPPORTER_ID. Debug builds use Google's test units whatever it says. With ADMOB false the studio's own
##   house banner stands in (HouseAds), one line to switch back. With it on the house banner still fills
##   in, under AdMob, whenever AdMob has no banner to give.
## - The AdMob plugin in addons/admob, enabled, with the project setting admob/general/android/app_id
##   equal to GameMonetize.APP_ID, since the plugin writes that setting into the manifest.
## - Save._ready calling `Supporter.start()` and then `Ads.start()` once progress is restored.
## - `EventBus.level_won` on every solve, `Save.best`, `Pack.count`, and `Save.sound_on`, since ads start
##   muted for a player who turned sound off.
## - The play screen calling `RatePrompt.or_ad` on its Next level path and nowhere else, and routing its
##   hint through HintGate.

## Any phone in portrait gets about the same adaptive banner, so the stand-in assumes one width.
const PREVIEW_WIDTH_DP: float = 360.0
## Clear space between the banner and the system navigation (the gesture bar or the buttons), in dp, so a
## swipe home or back never starts on the ad: with Android's 24 dp gesture bar that keeps the ad 48 dp, a
## full touch target, from the screen's edge. AdMob counts a tap made while leaving the app as invalid.
const EDGE_DP: float = 24.0
## The least the banner's bottom ever sits above the screen's edge, in dp. A game runs full screen with the
## navigation hidden, where the inset is 0 but Android still keeps a 32 dp strip at the bottom for the swipe home
## (its mandatory system gestures, measured on a Nothing phone): 24 dp alone left the ad's lowest 8 dp in it.
const FLOOR_DP: float = 48.0

## Desktop captures only: shows a stand-in banner at the real adaptive size.
static var preview: bool = false
## Lets a robot skip the pacing gaps without waiting.
static var skew: float = 0.0

static var _backend: AdBackend
static var _since: int = 0
static var _last_fullscreen: float = -1.0
static var _busy: bool = false
static var _covers: int = 0
## A banner drawn by the game (the house banner, the capture's stand-in) sits above sheets, as AdMob's native
## view does, so a result sheet's strip shows it rather than covering it. Every other sheet hides it.
const BANNER_LAYER: int = Sheet.LAYER + 1
## The banner's own height in design pixels while one is loaded, else 0.
static var _height: float = 0.0
## Every screen that carries the banner, oldest first: {"id": instance id, "on_height": Callable}.
static var _screens: Array[Dictionary] = []
## Whether a screen that carries the banner is open and one is due, and whether it is on screen right now
## (wanted, with no sheet over it). refresh() sets both.
static var _wanted: bool = false
static var _showing: bool = false
## The last room told, and to which screen.
static var _told_id: int = 0
static var _told_room: float = 0.0
static var _stand_in: CanvasLayer

## Supporter calls this again when Play says the pack is no longer owned.
static func start() -> void:
	if not EventBus.level_won.is_connected(_on_solved):
		EventBus.level_won.connect(_on_solved)
	# A cloud save restored after launch can make the banner due on the screen already open.
	if not EventBus.settings_changed.is_connected(refresh):
		EventBus.settings_changed.connect(refresh)
	if Supporter.active():
		return
	if is_instance_valid(_backend):
		_backend.resume()
		refresh()
		return
	if not OS.has_feature("android"):
		return
	if not GameMonetize.ADMOB:
		_attach(HouseAds.new(), true)
		return
	if not Engine.has_singleton("PoingGodotAdMob"):
		return
	var admob: GDScript = load("res://kit/monetize/android/admob.gd")
	_attach(admob.new(), true)

## How a reward is earned, for the buttons that offer one: a video when AdMob has one ready, and otherwise it is
## free, while the house ads stand in and whenever AdMob has none (offline, no fill, an ad blocker). Nothing earns
## then anyway, so the player gets the good feeling instead.
static func with_one() -> String:
	return "with a video" if video_ready() else "free"

static func video_ready() -> bool:
	return live() and _backend.video_ready()

static func use(backend: AdBackend) -> void:
	if is_instance_valid(_backend):
		_backend.queue_free()
	_backend = null
	_since = 0
	_last_fullscreen = -1.0
	_busy = false
	_height = 0.0
	if backend != null:
		_attach(backend, false)

static func live() -> bool:
	return is_instance_valid(_backend) and not Supporter.active()

static func rewards() -> bool:
	return live()

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0 + skew

static func solved() -> int:
	var n: int = 0
	for i: int in range(Pack.count()):
		if Save.best(i) > 0:
			n += 1
	return n

## A screen that carries the banner calls this once, as it opens. `on_height` hears the room the banner takes
## (the ad and its clear space, in design pixels) on every change, and 0 when there is none. The newest screen
## still in the tree owns the banner, and a screen drops out by itself as it leaves the tree, so the order in
## which a screen change adds the new screen and frees the old one never matters.
static func show_banner(host: Node, on_height: Callable) -> void:
	_drop(host.get_instance_id())
	_screens.append({"id": host.get_instance_id(), "on_height": on_height})
	if not host.has_meta(&"ads_banner"):
		host.set_meta(&"ads_banner", true)
		host.tree_exiting.connect(hide_banner.bind(host), CONNECT_ONE_SHOT)
	refresh()

## A screen lets the banner go the moment the player leaves it, before its fade is over. With no screen named,
## every screen lets go, as the app does on its way out.
static func hide_banner(host: Node = null) -> void:
	if host == null:
		_screens.clear()
	else:
		_drop(host.get_instance_id())
	refresh()

## Works out from scratch whether the banner is on screen, and tells the backend and the screen that owns it.
## Everything that can change the answer calls this: a screen opening or leaving, a sheet opening or closing,
## a banner loading, the backend arriving, the Supporter pack.
static func refresh() -> void:
	var owner: Dictionary = _owner()
	_wanted = not owner.is_empty() and AdPacing.banner_due(solved(), Supporter.active()) and (preview or live())
	_showing = _wanted and _covers == 0
	if preview:
		_place_stand_in(_wanted)
	elif live() and _backend.is_inside_tree():
		_backend.set_banner(_showing)
	_tell(owner, _wanted)

## A play screen reserves this from its first frame, so its board never jumps when the ad arrives. Like every
## height Ads reports, it is the banner and its clear space above the system navigation.
static func expected_banner_height(host: Node) -> float:
	if not AdPacing.banner_due(solved(), Supporter.active()) or not (preview or live()):
		return 0.0
	if _height > 0.0:
		return _height + clearance()
	return banner_height(host) + clearance()

## The gap kept between the banner and the system navigation inset below it, in design pixels: EDGE_DP, or more
## where that would leave the banner under FLOOR_DP from the screen's edge.
static func clearance() -> float:
	var root: Viewport = (Engine.get_main_loop() as SceneTree).root
	var view: Vector2 = root.get_visible_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var width_dp: float = window.x * 160.0 / dpi if dpi > 0.0 and window.x > 0.0 else PREVIEW_WIDTH_DP
	var per_dp: float = view.x / width_dp
	var inset_dp: float = float(UI.safe_margins(root)["bottom"]) / per_dp
	return gap_dp(inset_dp) * per_dp

## The gap in dp above an inset `inset_dp` tall, which AdMob's own banner keeps too.
static func gap_dp(inset_dp: float) -> float:
	return maxf(EDGE_DP, FLOOR_DP - inset_dp)

## Where a banner the game draws stands, bottom edge up, in design pixels: above the system navigation inset
## and the clear space.
static func banner_bottom(host: Node) -> float:
	return float(UI.safe_margins(host.get_viewport())["bottom"]) + clearance()

## The height a phone's adaptive banner takes, in design pixels.
static func banner_height(host: Node) -> float:
	# A node not yet in the tree has no viewport: the root's is the same screen. A release build does not stop
	# at a call on null as a debug build does, it crashes (puzzle-kit.md, Release builds crash where debug ones
	# only complain).
	var port: Viewport = host.get_viewport() if host.is_inside_tree() else (Engine.get_main_loop() as SceneTree).root
	var view: Vector2 = port.get_visible_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var width_dp: float = window.x * 160.0 / dpi if dpi > 0.0 and window.x > 0.0 else PREVIEW_WIDTH_DP
	var per_dp: float = view.x / width_dp
	return adaptive_height_dp(width_dp, view.y / per_dp) * per_dp

## The banner's room while it is on screen, else 0: what a Sheet that keeps the banner leaves clear below it.
static func banner_room() -> float:
	return _height + clearance() if _height > 0.0 and _showing else 0.0

## A Sheet calls this as it opens and closes, so the banner is never on screen with one, except one that keeps
## it in a strip of its own below the panel (Sheet.keeps_banner).
static func cover(on: bool) -> void:
	_covers = maxi(_covers + (1 if on else -1), 0)
	refresh()

## Google's anchored adaptive banner height: in proportion to a 320 by 50 banner, never under 50 dp, and
## never over 90 dp or 15% of the screen.
static func adaptive_height_dp(width: float, height: float) -> float:
	var most: float = maxf(50.0, minf(90.0, roundf(height * 0.15)))
	return clampf(roundf(width * 50.0 / 320.0), 50.0, most)

static func maybe_interstitial(on_done: Callable, after_guide: bool = false) -> void:
	if after_guide or _busy or not live() or not interstitial_due() \
			or not _backend.ready_to_show(AdBackend.INTERSTITIAL):
		on_done.call()
		return
	_busy = true
	_backend.present(AdBackend.INTERSTITIAL)
	var result: Array = await _backend.finished
	_busy = false
	if bool(result[1]):
		_last_fullscreen = now()
		_since = 0
	if on_done.is_valid():
		on_done.call()

static func interstitial_due() -> bool:
	return AdPacing.interstitial_due(solved(), _since, now(), _last_fullscreen, Supporter.active())

## Plays a video and gives the reward once it is watched through. With no video to play (house ads standing in,
## offline, no fill, consent refused) the reward is simply given. A video closed early gives nothing.
static func rewarded(on_reward: Callable) -> void:
	if _busy:
		return
	if not live() or not _backend.ready_to_show(AdBackend.REWARDED):
		if on_reward.is_valid():
			on_reward.call()
		return
	_busy = true
	_backend.present(AdBackend.REWARDED)
	var result: Array = await _backend.finished
	_busy = false
	var shown: bool = result[1]
	if shown:
		_last_fullscreen = now()
	# Watched through, or never shown at all: either way the reward is the player's.
	if (bool(result[2]) or not shown) and on_reward.is_valid():
		on_reward.call()

## UMP says whether the player must be able to change their consent. Settings shows Privacy choices only
## then.
static func privacy_options_required() -> bool:
	return live() and _backend.privacy_required()

static func open_privacy_options() -> void:
	if live():
		_backend.open_privacy()

static func stop() -> void:
	if is_instance_valid(_backend):
		_backend.stop()
	if is_instance_valid(_stand_in):
		_stand_in.queue_free()
	_stand_in = null
	_height = 0.0
	refresh()

## A backend is added to the tree a frame late, while the first screen is already asking for the banner: the
## banner is applied once the backend is there to take it.
static func _attach(backend: AdBackend, deferred: bool) -> void:
	_backend = backend
	backend.banner_changed.connect(_on_banner)
	backend.ready.connect(refresh, CONNECT_ONE_SHOT)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if deferred:
		tree.root.add_child.call_deferred(backend)
	else:
		tree.root.add_child(backend)

static func _on_banner(height: float) -> void:
	_height = height
	_tell(_owner(), _wanted)

static func _on_solved(_level: int, _count: int, _stars: int) -> void:
	_since += 1

## The newest screen that asked for the banner and is still in the tree, or {}.
static func _owner() -> Dictionary:
	for i: int in range(_screens.size() - 1, -1, -1):
		var node: Node = instance_from_id(int(_screens[i]["id"])) as Node
		if node != null and node.is_inside_tree():
			return _screens[i]
	return {}

static func _drop(id: int) -> void:
	for i: int in range(_screens.size() - 1, -1, -1):
		if int(_screens[i]["id"]) == id:
			_screens.remove_at(i)

## Tells the owning screen the banner's room. Until a banner has loaded it keeps the room the screen reserved
## from its first frame (expected_banner_height), so nothing jumps when the ad arrives.
## Only a change is told: a screen lays itself out again when it hears, and a sheet opening or closing over it
## changes nothing below.
static func _tell(owner: Dictionary, wanted: bool) -> void:
	if owner.is_empty() or (wanted and _height <= 0.0):
		return
	var room: float = _height + clearance() if wanted else 0.0
	if int(owner["id"]) == _told_id and is_equal_approx(room, _told_room):
		return
	_told_id = int(owner["id"])
	_told_room = room
	var on_height: Callable = owner["on_height"]
	if on_height.is_valid():
		on_height.call(room)

## Desktop captures: a stand-in at the real adaptive size, drawn inside the owning screen so a capture's own
## viewport shows it.
static func _place_stand_in(wanted: bool) -> void:
	var owner: Dictionary = _owner()
	var host: Node = null if owner.is_empty() else instance_from_id(int(owner["id"])) as Node
	if not wanted or host == null:
		if is_instance_valid(_stand_in):
			_stand_in.queue_free()
		_stand_in = null
		_height = 0.0
		return
	if not is_instance_valid(_stand_in) or _stand_in.get_parent() != host:
		if is_instance_valid(_stand_in):
			_stand_in.queue_free()
		var view: Vector2 = host.get_viewport().get_visible_rect().size
		var per_dp: float = view.x / PREVIEW_WIDTH_DP
		_height = adaptive_height_dp(PREVIEW_WIDTH_DP, view.y / per_dp) * per_dp
		_stand_in = CanvasLayer.new()
		_stand_in.layer = BANNER_LAYER
		host.add_child(_stand_in)
		# With AdMob off the stand-in is the house banner itself, as a phone would show it.
		var box: Control = _StandIn.new() if GameMonetize.ADMOB or Studio.others().is_empty() else HouseBanner.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		box.offset_bottom = -banner_bottom(host)
		box.offset_top = box.offset_bottom - _height
		_stand_in.add_child(box)
		if box is HouseBanner:
			(box as HouseBanner).show_game(HouseAds.next_game())
	_stand_in.visible = _showing

## A real ad's neutral colours, whatever the theme.
class _StandIn extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f1f1f1"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 2.0)), Color("d6d6d6"))
		var font: Font = UI.ui_font()
		var text: String = "Test ad"
		var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, size.y * 0.5 + 9.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
			Color("8a8a8a"))
