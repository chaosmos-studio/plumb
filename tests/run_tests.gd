extends SceneTree

# Run: godot --headless --path . -s res://tests/run_tests.gd [-- quick]
# CI greps for "0 failed", so keep that wording. `quick` skips re-solving the whole level pack, the one
# slow check. CI always runs it.

const InputMapGen: GDScript = preload("res://tools/make_input_map.gd")
const LevelTool: GDScript = preload("res://tools/generate_levels.gd")
const FakeIntermission: GDScript = preload("res://tests/fake_intermission.gd")
## The least contrast each pairing needs, as a WCAG ratio, in both palettes: body text, the quiet
## captions, the primary button's label and the reset warning.
const CONTRAST: Array = [["ink", "bg", 7.0], ["ink", "surface", 7.0], ["muted", "bg", 3.0],
	["muted", "surface", 3.0], ["accent_ink", "accent", 3.0], ["danger", "surface", 3.0]]

## SHA-256 of the JSON of levels 1 to 180, which the plateau kept, and of the old levels 181 to 500, which became the
## Hard levels (MATH.md section 16). Neither may ever change: players' stars are on them.
const KEPT_DIGEST: String = "0faf82c7eaf937b5e4f32d5f7246fd2cb0c46972c5affa87d819478145d66ca9"
const HARD_DIGEST: String = "c9d1aea0c3a9b410689d76fc824533d7e5e043acf6215062b0434f8c9bc658ab"
## The same for the plateau as it was built before the bouncy blocks, now a chapter later, and for the generator's
## random state after each of the chapters made by then (MATH.md section 22).
const SHIFTED_DIGEST: String = "d586c72a78dfdc57b7d5a4c2d07baa0fdb96a92dc807912b2f66927145e38861"
const STATES_DIGEST: String = "c2e7b05a193561acd8990ed665a59351cdda0c9bad54c9fddea9eddf8a0a177c"
## Random players tried on each plateau level, and the share of levels, one in this many, that a naive player may
## clear in par before the plateau counts as too easy for thought.
const NAIVE_TRIES: int = 40
const NAIVE_SHARE: int = 10
## A bouncy block's least contrast with the floor, and the least hue (a share of a turn) between it and a marble.
const JELLY_CONTRAST: float = 2.5
const JELLY_HUE_GAP: float = 0.1

var _passed: int = 0
var _failed: int = 0
## Set by a test to open a sheet from _process, which runs just before process_frame: where a tap lands
## on a fast-refresh phone's frame that had no physics step to lay the new sheet out first.
var _open_in_process: Callable = Callable()
var _opened: Control

func _initialize() -> void:
	_test_input_map_is_wired()
	_test_orientation_is_an_int()
	_test_screen_lock()
	_test_shrink_rules()
	_test_tilt_rules()
	_test_phone_tilt()
	_test_chapter_tiles()
	_test_wave_two_tiles()
	_test_wave_three_tiles()
	_test_bounce()
	_test_solver()
	_test_difficulty()
	_test_novelty()
	_test_serialisation()
	_test_stars()
	_test_street_projection()
	_test_street_path()
	_test_street_layout()
	_test_jiggle()
	_test_street_rewards()
	_test_street_rating()
	_test_street_picker()
	_test_street_migration()
	_test_street_doors()
	_test_feed()
	if not OS.get_cmdline_user_args().has("quick"):
		_test_level_pack()
	_test_opening()
	_test_appearance()
	_test_contrast()
	_test_themes()
	_test_marble_sets()
	_test_gaze()
	_test_mood()
	_test_spin()
	_test_cast()
	_test_star_notes()
	_test_wall_animals()
	_test_jelly_reads()
	_test_saved_settings()
	_test_guide_and_ending()
	_test_banner_pacing()
	_test_interstitial_pacing()
	_test_hint_pacing()
	_test_banner_size()
	_test_monetize_ids()
	_test_presets_and_plugins()
	_test_consent()
	_test_test_ads()
	_test_changelog()
	_test_saved_monetization()
	_test_settings_variants()
	_test_about_variants()
	_test_finale_variants()
	_test_ending_line_and_milestones()
	_test_support_and_hint_sheets()
	_test_supporter_entry_points()
	_test_shop()
	_test_analytics()
	_test_daily_calendar()
	_test_daily_bank()
	_test_daily_result_lines()
	_test_cloud_save()
	await _test_title_follows_a_restore()
	_test_play_games()
	_test_game_stats()
	# The root takes new children only once _initialize has handed control back to the engine.
	await process_frame
	_test_daily_records()
	await _test_board_follows_tilt()
	await _test_walls_follow_pets()
	await _test_one_off_screens_carry_no_banner()
	_test_interstitial_switch()
	_test_chapter_ticks()
	_test_streak_keeping()
	_test_chapter_colours()
	_test_unlocks()
	_test_hard_shelf()
	_test_rate_prompt()
	_test_play_core()
	_test_more_games()
	await _test_passes()
	_test_cheers()
	await _test_win_sheet()
	_test_qr()
	_test_volumes()
	_test_sheets_fit_a_phone()
	_test_credits_scroll_by_drag()
	_test_maker_link()
	_test_play_screen_banner()
	await _test_go_back()
	_test_house_ads()
	await _test_levelplay_backend()
	await _test_sheet_rises_before_layout()
	await _test_sheet_drags_closed()
	await _test_levels_swipe()
	print("\n==== TESTS: %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _process(_delta: float) -> bool:
	if _open_in_process.is_valid():
		_opened = _open_in_process.call()
		_open_in_process = Callable()
	return false

func _check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL: ", name)

# An action can exist with zero events, and then every is_action_pressed() silently returns false.
func _test_input_map_is_wired() -> void:
	var table: Dictionary = InputMapGen.bindings()
	for action: String in table:
		_check("action %s exists, re-run tools/make_input_map.gd" % action, InputMap.has_action(action))
		if InputMap.has_action(action):
			_check("action %s has bindings" % action, InputMap.action_get_events(action).size() > 0)

# A string here converts to 0, which is Landscape, whatever the string said.
func _test_orientation_is_an_int() -> void:
	var value: Variant = ProjectSettings.get_setting("display/window/handheld/orientation")
	_check("handheld orientation is stored as an int, re-run tools/configure_project.gd",
		typeof(value) == TYPE_INT)

# Play counts a locked orientation against large screens, so the manifest locks nothing and ScreenLock keeps
# a phone in portrait at runtime while a tablet or an open foldable turns.
func _test_screen_lock() -> void:
	_check("the manifest leaves the orientation free",
		ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_SENSOR)
	var lock: GDScript = load("res://kit/ui/screen_lock.gd")
	_check("a phone stays in portrait, and a tablet and an open foldable turn",
		lock.call("orientation_for", Vector2i(1080, 2400), 420) == DisplayServer.SCREEN_PORTRAIT
		and lock.call("orientation_for", Vector2i(1600, 2560), 320) == DisplayServer.SCREEN_SENSOR
		and lock.call("orientation_for", Vector2i(2208, 1840), 420) == DisplayServer.SCREEN_SENSOR)
	_check("Save starts the screen lock", FileAccess.get_file_as_string("res://autoload/save.gd").contains("ScreenLock.start()"))

# R8 strips and renames what nothing calls, and the kit reaches some Java classes only by name, through
# JavaClassWrapper, so each one outside Android's own must have a keep rule or it fails only on a phone.
func _test_shrink_rules() -> void:
	var rules: String = FileAccess.get_file_as_string("res://addons/shrink_build/plugin.gd")
	var named: Array[String] = [String(load("res://kit/shell/play_core.gd").get_script_constant_map()["HELPER"])]
	var wrap: RegEx = RegEx.create_from_string("JavaClassWrapper\\.wrap\\(\"([^\"]+)\"\\)")
	for path: String in _scripts("res://kit"):
		for found: RegExMatch in wrap.search_all(FileAccess.get_file_as_string(path)):
			named.append(found.get_string(1))
	var kept: Array[String] = []
	for found: RegExMatch in RegEx.create_from_string("-keep class ([\\w.$*]+) \\{").search_all(rules):
		kept.append(found.get_string(1))
	var missing: Array[String] = []
	for java: String in named:
		if java.begins_with("android.") or java.begins_with("java."):
			continue
		var covered: bool = false
		for rule: String in kept:
			covered = covered or rule == java or (rule.ends_with(".**") and java.begins_with(rule.trim_suffix("**")))
		if not covered:
			missing.append(java)
	_check("every Java class the kit names has a keep rule %s" % [missing], named.size() > 1 and missing.is_empty())

func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found

static func _board(rows: Array, marbles: Array) -> TiltBoard:
	return TiltBoard.from_dict({"rows": rows, "marbles": marbles})

## Gravity for a phone held `back` degrees off vertical, then leaned `side` degrees right and `forward`
## degrees top-edge-down, in the screen's axes as Godot reports it on Android.
static func _gravity(back: float, side: float, forward: float) -> Vector3:
	var g: Vector3 = Vector3(0.0, -cos(deg_to_rad(back)), -sin(deg_to_rad(back))) * 9.8
	return g.rotated(Vector3.FORWARD, deg_to_rad(-side)).rotated(Vector3.RIGHT, deg_to_rad(forward))

func _test_phone_tilt() -> void:
	var phone: PhoneTilt = PhoneTilt.new()
	_check("a phone with no gravity tilts nothing", phone.feed(Vector3.ZERO) == -1)
	_check("the first reading is the rest", phone.feed(_gravity(40, 0, 0)) == -1)
	_check("a small wobble tilts nothing", phone.feed(_gravity(40, 8, 0)) == -1)
	_check("lowering the right edge tilts right", phone.feed(_gravity(40, 25, 0)) == TiltBoard.RIGHT)
	_check("holding the lean does not tilt again", phone.feed(_gravity(40, 30, 0)) == -1)
	_check("coming back to rest tilts nothing", phone.feed(_gravity(40, 2, 0)) == -1)
	_check("then lowering the left edge tilts left", phone.feed(_gravity(40, -25, 0)) == TiltBoard.LEFT)
	phone.feed(_gravity(40, 0, 0))
	_check("tipping the top edge down tilts up", phone.feed(_gravity(40, 0, 25)) == TiltBoard.UP)
	phone.feed(_gravity(40, 0, 0))
	_check("raising the top edge tilts down", phone.feed(_gravity(40, 0, -25)) == TiltBoard.DOWN)
	phone.reset()
	phone.feed(_gravity(80, 0, 0))
	_check("held nearly flat, a lean reads from the new rest", phone.feed(_gravity(80, 0, -20)) == TiltBoard.DOWN)

func _test_tilt_rules() -> void:
	var b: TiltBoard = _board(["..."], [[0, 0, 0]])
	var m: TiltMove = b.tilt(TiltBoard.RIGHT)
	_check("a marble rolls to the wall", b.marble_cell[0] == 2 and m.length() == 2)
	_check("a tilt into the wall changes nothing", not b.tilt(TiltBoard.RIGHT).changed())

	b = _board(["...."], [[0, 0, 0], [1, 0, 0]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("a line of marbles rolls as a train", b.marble_cell[1] == 3 and b.marble_cell[0] == 2 and m.length() == 2)

	b = _board(["..0"], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble drops into a hole of its colour", b.marble_cell[0] == TiltBoard.GONE and b.is_won())

	b = _board([".1."], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble rolls over a hole of another colour", b.marble_cell[0] == 2 and not b.is_won())

	b = _board([".x."], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a pit swallows the marble and loses", b.lost and not b.is_won())

	b = _board([".#."], [[0, 0, 0]])
	_check("a wall blocks", not b.tilt(TiltBoard.RIGHT).changed())

	b = _board(["0.."], [[1, 0, 0], [2, 0, 0]])
	m = b.tilt(TiltBoard.LEFT)
	_check("the front marble sinks and the one behind rolls through", b.is_won() and m.events.size() == 2)

static func _tiled(rows: Array, marbles: Array, tiles: Array) -> TiltBoard:
	return TiltBoard.from_dict({"rows": rows, "marbles": marbles, "tiles": tiles})

## The bouncy block (MATH.md section 22): back the way it came, once a tilt.
func _test_bounce() -> void:
	var b: TiltBoard = _tiled(["....."], [[1, 0, 0]], [[4, 0, "bounce", 0]])
	var m: TiltMove = b.tilt(TiltBoard.RIGHT)
	_check("a marble that rolls into a bouncy block goes straight back until something stops it",
		b.marble_cell[0] == 0 and m.length() == 5 and m.events.size() == 1 and m.events[0]["kind"] == &"rebound"
		and int(m.events[0]["step"]) == 2 and m.cells[2][0] == 2)
	b = _tiled(["...."], [[2, 0, 0]], [[3, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("one resting against it bounces too, on the same step it would have moved", b.marble_cell[0] == 0)
	b = _tiled(["....."], [[2, 0, 0]], [[0, 0, "bounce", 0], [4, 0, "bounce", 0]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("and only once a tilt: the second bouncy block stops it like a wall", b.marble_cell[0] == 1
		and m.events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"rebound").size() == 1)
	b = _tiled(["....."], [[0, 0, 0], [1, 0, 0]], [[4, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble that bounces into the one behind it stops against it", b.marble_cell[1] == 3 and b.marble_cell[0] == 2)
	b = _tiled(["....."], [[0, 0, 0], [2, 0, 0]], [[4, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("and one rolling behind it meets it halfway, the front marble going first", b.marble_cell[1] == 2
		and b.marble_cell[0] == 1)
	b = _tiled(["x..."], [[1, 0, 0]], [[3, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a bounce can carry a marble back into a pit", b.lost)
	b = _tiled(["0..."], [[1, 0, 0]], [[3, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("or home", b.is_won())
	b = _tiled(["...."], [[0, 0, 0]], [[1, 0, "gate", TiltBoard.RIGHT], [3, 0, "bounce", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a one-way gate holds a marble bounced back against its way", b.marble_cell[0] == 2)
	b = _tiled(["...."], [[0, 0, 0]], [[3, 0, "bounce", 0]])
	_check("a bouncy block is no cell to land on, and a board that changes nothing is no move",
		not b.enterable(3, 0, TiltBoard.RIGHT) and not _tiled(["...."], [[0, 0, 0], [1, 0, 0], [2, 0, 0]],
		[[3, 0, "bounce", 0]]).tilt(TiltBoard.RIGHT).changed())
	_check("it is its own kind of cell to the likeness test", TiltNovelty.layout(b)[3] == TiltNovelty.Kind.BOUNCE
		and TiltNovelty.canonical(b).contains("v"))
	var needed: TiltBoard = _tiled(["0....", "....."], [[4, 0, 0]], [[2, 0, "bounce", 0]])
	_check("a board the bouncy block turns from one tilt into three needs it", TiltSolver.new().solve(needed).size() == 3
		and TiltGenerator.needs(needed, "bounce", 3))

func _test_wave_two_tiles() -> void:
	var s: int = TiltBoard.STONE
	var b: TiltBoard = _tiled(["0.."], [[2, 0, s]], [])
	b.tilt(TiltBoard.LEFT)
	_check("a stone rolls over a hole and never drops in", b.marble_cell[0] == 0)
	_check("and a board with only stones left is won", b.is_won())
	b = _tiled(["0x.."], [[3, 0, 0], [2, 0, s]], [])
	var m: TiltMove = b.tilt(TiltBoard.LEFT)
	_check("a stone fills the pit it rolls into", b.cells[1] == TiltBoard.Cell.FLOOR and b.marble_cell[1] == TiltBoard.GONE
		and not b.lost and b.key().contains("|"))
	_check("and the marble behind rolls over it home", b.marble_cell[0] == TiltBoard.GONE and b.is_won()
		and m.events.any(func(e: Dictionary) -> bool: return e["kind"] == &"fill"))

	b = _tiled(["......"], [[0, 0, 0]], [[1, 0, "portal", 0], [4, 0, "portal", 0]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("a marble that rolls into a portal comes out of its twin, still rolling", b.marble_cell[0] == 5
		and m.events.any(func(e: Dictionary) -> bool: return e["kind"] == &"portal" and int(e["to"]) == 4))
	_check("and the animation is told it landed on the twin", m.cells[0][0] == 4)
	b = _tiled(["...#"], [[0, 0, 0], [2, 0, 1]], [[1, 0, "portal", 0], [2, 0, "portal", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a portal whose twin is taken is shut", b.marble_cell[0] == 0)

	b = _tiled([".....", "....."], [[0, 0, 0]], [[2, 0, "bumper", TiltBoard.BACKSLASH]])
	b.tilt(TiltBoard.RIGHT)
	_check("a backslash bumper turns a marble rolling right downwards", b.marble_cell[0] == b.index(Vector2i(2, 1)))
	b = _tiled([".....", "....."], [[0, 1, 0]], [[2, 1, "bumper", TiltBoard.SLASH]])
	b.tilt(TiltBoard.RIGHT)
	_check("and a slash bumper upwards", b.marble_cell[0] == b.index(Vector2i(2, 0)))
	b = _tiled(["...", ".#.", "..."], [[1, 0, 0]], [[2, 0, "bumper", TiltBoard.BACKSLASH],
		[2, 2, "bumper", TiltBoard.SLASH], [0, 2, "bumper", TiltBoard.BACKSLASH], [0, 0, "bumper", TiltBoard.SLASH]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("a marble sent round a loop of bumpers stops once round", m.length() < 12 and b.marble_cell[0] != TiltBoard.GONE)

	b = _tiled(["....", ".#.."], [[0, 0, 0]], [[2, 0, "hatch", 0], [0, 1, "switch", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a hatch is shut while nothing rests on its switch", b.marble_cell[0] == 1)
	b = _tiled(["....", ".#.."], [[0, 0, 0], [0, 1, s]], [[2, 0, "hatch", 0], [0, 1, "switch", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("and open while a stone rests on it", b.marble_cell[0] == 3)

	b = _tiled(["......"], [[0, 0, 0]], [[1, 0, "key", 0], [4, 0, "lock", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("rolling over a key opens the lock of its colour for good", b.marble_cell[0] == 5
		and b.tiles[4] == TiltBoard.Tile.NONE and b.tiles[1] == TiltBoard.Tile.NONE and b.key().contains("|"))
	b = _tiled(["......"], [[2, 0, 0]], [[1, 0, "key", 0], [4, 0, "lock", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a lock stays shut until its key is used", b.marble_cell[0] == 3)
	b = _tiled(["......"], [[0, 0, 0]], [[1, 0, "key", 1], [4, 0, "lock", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("and another colour's key leaves it shut", b.marble_cell[0] == 3)

	var dressed: TiltBoard = _tiled(["....", "...."], [[0, 0, 0], [3, 1, s]], [[1, 0, "portal", 0], [2, 1, "portal", 0],
		[2, 0, "bumper", 1], [0, 1, "switch", 0], [3, 0, "hatch", 0], [1, 1, "key", 2], [3, 1, "lock", 2]])
	_check("the new tiles and stones survive a round trip", TiltBoard.from_dict(dressed.to_dict()).to_dict() == dressed.to_dict())
	var mirrored: TiltBoard = TiltNovelty.transform(dressed, 1)
	_check("mirroring a board turns its bumpers the other way", mirrored.tile_value[mirrored.index(Vector2i(1, 0))] == 0)
	_check("a stone is told apart from a marble in a layout", TiltNovelty.layout(dressed)[dressed.index(Vector2i(3, 1))]
		== TiltNovelty.Kind.STONE)
	var plain: TiltBoard = TiltGenerator.without(dressed, "stone")
	_check("taking stones away leaves the marbles", plain.marble_cell.size() == 1 and not plain.is_stone(0))
	plain = TiltGenerator.without(dressed, "switch")
	_check("taking switches away takes their hatches too", not plain.tiles.has(TiltBoard.Tile.SWITCH)
		and not plain.tiles.has(TiltBoard.Tile.HATCH))

func _test_wave_three_tiles() -> void:
	var b: TiltBoard = _tiled(["...."], [[0, 0, 0]], [[2, 0, "blink", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a blinking wall that is up stops a marble, and the beat moves on", b.marble_cell[0] == 1 and b.beat == 1
		and b.key().contains("|b1"))
	b = _tiled(["...."], [[0, 0, 0]], [[2, 0, "blink", 1]])
	b.tilt(TiltBoard.RIGHT)
	_check("one that is down lets it roll over", b.marble_cell[0] == 3)
	_check("a tilt that moves nothing leaves the beat", not b.tilt(TiltBoard.RIGHT).changed() and b.beat == 1)
	b = _tiled(["...."], [[0, 0, 0], [1, 0, 0]], [[1, 0, "blink", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a blinking wall never rises under a marble", b.marble_cell[0] == 2 and b.marble_cell[1] == 3)

	b = _tiled(["....", "...."], [[0, 0, 0]], [[3, 0, "conveyor", TiltBoard.DOWN]])
	b.tilt(TiltBoard.RIGHT)
	_check("once the board stops, a conveyor carries its marble on", b.marble_cell[0] == b.index(Vector2i(3, 1)))
	b = _tiled(["....", "...."], [[0, 0, 0]], [[1, 0, "conveyor", TiltBoard.DOWN]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble rolling over a conveyor is not carried", b.marble_cell[0] == 3)
	b = _tiled(["...."], [[3, 0, 0]], [[3, 0, "conveyor", TiltBoard.RIGHT]])
	_check("a conveyor heading into a wall is no move", not b.tilt(TiltBoard.UP).changed())

	b = _tiled(["..#.."], [[0, 0, 0]], [[1, 0, "spring", 0]])
	var m: TiltMove = b.tilt(TiltBoard.RIGHT)
	_check("a spring jumps a marble over the next square", b.marble_cell[0] == 4
		and m.events.any(func(e: Dictionary) -> bool: return e["kind"] == &"jump" and int(e["to"]) == 3))
	b = _tiled(["..#"], [[0, 0, 0]], [[1, 0, "spring", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a spring with nowhere to land keeps its marble", b.marble_cell[0] == 1)

	b = TiltBoard.from_dict({"rows": ["0..."], "marbles": [[2, 0, 0]], "wrap": TiltBoard.WRAP_X})
	m = b.tilt(TiltBoard.RIGHT)
	_check("off one edge and back in at the other", b.is_won() and m.events.any(func(e: Dictionary) -> bool:
		return e["kind"] == &"wrap"))
	b = TiltBoard.from_dict({"rows": ["...."], "marbles": [[1, 0, 0]], "wrap": TiltBoard.WRAP_X})
	b.tilt(TiltBoard.RIGHT)
	_check("with nothing in the way, a marble comes round to where it began and stops", b.marble_cell[0] == 1)

	b = _tiled(["......", "......"], [[0, 0, 0]], [[3, 1, "magnet", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble rolling past a magnet stops beside it", b.marble_cell[0] == 3)
	b = _tiled(["......", "......"], [[0, 1, 0]], [[3, 1, "magnet", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("and one rolling at it stops before it", b.marble_cell[0] == b.index(Vector2i(2, 1)))

	b = _board(["0...#.0"], [[2, 0, 0, 2], [5, 0, 0, 1]])
	b.tilt(TiltBoard.LEFT)
	_check("a numbered marble rolls onto its hole out of turn and waits there", b.marble_cell[0] == 0)
	b.tilt(TiltBoard.RIGHT)
	_check("number 1 drops first", b.marble_cell[1] == TiltBoard.GONE and b.marble_cell[0] == 3)
	b.tilt(TiltBoard.LEFT)
	_check("then number 2", b.is_won())
	b = _board(["0..", "0.."], [[0, 0, 0, 2], [2, 1, 0, 1]])
	b.tilt(TiltBoard.LEFT)
	_check("one waiting on its hole drops as soon as its turn comes", b.marble_cell[0] == TiltBoard.GONE
		and b.marble_cell[1] == TiltBoard.GONE)

	b = _tiled(["....."], [[0, 0, 0]], [[3, 0, "glass", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a glass post stops a marble, then shatters", b.marble_cell[0] == 2 and b.tiles[3] == TiltBoard.Tile.NONE
		and b.key().contains("|"))
	b.tilt(TiltBoard.RIGHT)
	_check("and the marble rolls on next time", b.marble_cell[0] == 4)
	b = _tiled(["....."], [[2, 0, 0]], [[3, 0, "glass", 0]])
	_check("striking glass counts as a move even when nothing rolls", b.tilt(TiltBoard.RIGHT).changed()
		and b.marble_cell[0] == 2)

	b = _tiled([".0.."], [[3, 0, 0]], [[1, 0, "ice", 0]])
	b.tilt(TiltBoard.LEFT)
	_check("an ice hole lets a marble roll over it", b.marble_cell[0] == 0)
	b = _tiled(["#0.."], [[3, 0, 0]], [[1, 0, "ice", 0]])
	m = b.tilt(TiltBoard.LEFT)
	_check("and takes one that stops on it", b.is_won() and m.changed())

	b = TiltBoard.from_dict({"rows": ["....", "...."], "marbles": [[0, 0, 0]], "locked": TiltBoard.RIGHT})
	_check("the locked direction does nothing", not b.tilt(TiltBoard.RIGHT).changed() and b.marble_cell[0] == 0
		and b.locked == TiltBoard.RIGHT)
	b.tilt(TiltBoard.DOWN)
	_check("a tilt that moves turns the lock a quarter clockwise", b.locked == TiltBoard.DOWN and b.key().contains("|l"))
	b.tilt(TiltBoard.RIGHT)
	_check("so the way that was locked opens", b.marble_cell[0] == b.index(Vector2i(3, 1)) and b.locked == TiltBoard.LEFT)

	var dressed: TiltBoard = TiltBoard.from_dict({"rows": ["0...", "..1."], "marbles": [[1, 0, 0, 1], [3, 1, 1, 2]],
		"tiles": [[2, 0, "blink", 1], [3, 0, "conveyor", TiltBoard.DOWN], [0, 1, "spring", 0], [1, 1, "magnet", 0],
		[3, 0, "glass", 0], [2, 1, "ice", 0]], "wrap": TiltBoard.WRAP_Y, "locked": TiltBoard.UP})
	_check("the wave three marks survive a round trip", TiltBoard.from_dict(dressed.to_dict()).to_dict() == dressed.to_dict())
	var turned: TiltBoard = TiltNovelty.transform(dressed, 4)
	_check("swapping the axes swaps the wrapping edge and turns the locked direction",
		turned.wrap == TiltBoard.WRAP_X and turned.locked == TiltBoard.LEFT and turned.marble_number[0] == 1)
	_check("a layout tells an ice hole from a hole", TiltNovelty.layout(dressed)[dressed.index(Vector2i(2, 1))]
		== TiltNovelty.Kind.ICE)
	var on: PackedStringArray = TiltGenerator.rules_on(dressed)
	_check("a board lists the rules it carries", on.has("blink") and on.has("glass") and on.has("ice")
		and on.has("number") and on.has("wrap") and on.has("locked"))
	var plain: TiltBoard = TiltGenerator.without(dressed, "number")
	_check("taking the rules off: numbers", plain.marble_number[0] == 0 and plain.marble_number[1] == 0)
	plain = TiltGenerator.without(TiltGenerator.without(TiltGenerator.without(dressed, "ice"), "wrap"), "locked")
	_check("ice, wrap and the locked direction", not plain.ice.has(1) and plain.wrap == 0 and plain.locked == -1)
	plain = TiltGenerator.without(dressed, "glass")
	_check("and a tile", not plain.tiles.has(TiltBoard.Tile.GLASS))
	var needed: TiltBoard = _tiled(["..", ".0"], [[0, 0, 0]], [[1, 0, "conveyor", TiltBoard.DOWN]])
	_check("a board needs a rule its solution cannot do without", TiltGenerator.needs(needed, "conveyor", 1)
		and TiltGenerator.needs(needed, "mix", 1))

func _test_chapter_tiles() -> void:
	var m: TiltMove
	var b: TiltBoard = _tiled(["...."], [[0, 0, 0]], [[2, 0, "stop", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a stop pad halts a marble rolling onto it", b.marble_cell[0] == 2)
	b.tilt(TiltBoard.RIGHT)
	_check("and the next tilt rolls it off again", b.marble_cell[0] == 3)

	b = _tiled(["...."], [[0, 0, 0], [1, 0, 0]], [[3, 0, "stop", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble behind stops against one on a pad", b.marble_cell[1] == 3 and b.marble_cell[0] == 2)

	b = _tiled(["..."], [[0, 0, 0]], [[1, 0, "gate", TiltBoard.LEFT]])
	_check("a gate blocks a marble coming the wrong way", not b.tilt(TiltBoard.RIGHT).changed())
	b = _tiled(["..."], [[2, 0, 0]], [[1, 0, "gate", TiltBoard.LEFT]])
	b.tilt(TiltBoard.LEFT)
	_check("and lets one through its own way", b.marble_cell[0] == 0)

	b = _tiled(["..."], [[0, 0, 1]], [[1, 0, "door", 0]])
	_check("a door blocks other colours", not b.tilt(TiltBoard.RIGHT).changed())
	b = _tiled(["..."], [[0, 0, 0]], [[1, 0, "door", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("and lets its own colour through", b.marble_cell[0] == 2)

	b = _tiled(["..1"], [[0, 0, 0]], [[1, 0, "paint", 1]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("paint repaints a marble, which then drops into its new colour", b.is_won() and m.events[0]["kind"] == &"paint")

	b = _tiled(["..."], [[0, 0, 0]], [[1, 0, "crack", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("cracked floor gives way once a marble has rolled off it", b.cells[1] == TiltBoard.Cell.PIT and not b.lost)
	_check("and the opened pit is part of the solver's key", b.key().contains("|"))
	b = _tiled(["...."], [[0, 0, 0], [1, 0, 0]], [[1, 0, "crack", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("so a marble following another across it falls in", b.lost)

	b = _tiled(["..0."], [[0, 0, 0], [3, 0, 0]], [[2, 0, "plug", 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a plug takes one marble", b.marble_cell[0] == TiltBoard.GONE and b.holes[2] == TiltBoard.NO_HOLE)
	b.tilt(TiltBoard.LEFT)
	_check("then closes, so the next marble rolls over it", b.marble_cell[1] == 0)
	_check("and the closed plug is part of the solver's key", b.key().contains("|"))

	var round_trip: TiltBoard = TiltBoard.from_dict(_tiled(["0..."], [[3, 0, 0]],
		[[1, 0, "gate", 2], [2, 0, "paint", 1], [0, 0, "plug", 0]]).to_dict())
	_check("tiles and plugs survive the level file", round_trip.tiles[1] == TiltBoard.Tile.GATE
		and round_trip.tile_value[1] == 2 and round_trip.tiles[2] == TiltBoard.Tile.PAINT and round_trip.plugs[0] == 1)

	var turned: TiltBoard = TiltNovelty.transform(_tiled(["..."], [[0, 0, 0]], [[1, 0, "gate", TiltBoard.RIGHT]]), 1)
	_check("mirroring a board turns its gates", turned.tile_value[1] == TiltBoard.LEFT)

	# Only the pad can stop the marble above the hole.
	var pad: TiltBoard = _tiled(["....", "#0##"], [[0, 0, 0]], [[1, 0, "stop", 0]])
	_check("a level needs a helping rule when the plain board can't be solved", TiltGenerator.needs(pad, "stop", 2))
	var gate: TiltBoard = _tiled(["0..", "..."], [[2, 0, 0]], [[1, 0, "gate", TiltBoard.RIGHT]])
	_check("and a restricting rule when the plain board solves in fewer moves", TiltGenerator.needs(gate, "gate", 3))
	var idle: TiltBoard = _tiled(["...0", "...."], [[0, 0, 0]], [[1, 1, "stop", 0]])
	_check("and does not when the tile changes nothing", not TiltGenerator.needs(idle, "stop", 1))
	var cluttered: TiltBoard = _tiled(["0..", "...", "..."], [[2, 0, 0]],
		[[1, 0, "gate", TiltBoard.RIGHT], [1, 1, "stop", 0]])
	var pruned: TiltBoard = TiltGenerator.prune(cluttered, 3)
	_check("pruning takes off a tile that changes nothing and keeps one that matters",
		pruned.tiles[pruned.index(Vector2i(1, 1))] == TiltBoard.Tile.NONE
		and pruned.tiles[pruned.index(Vector2i(1, 0))] == TiltBoard.Tile.GATE)
	var twice: TiltBoard = _tiled(["0...", "....", "...."], [[3, 0, 0]],
		[[1, 0, "gate", TiltBoard.RIGHT], [2, 0, "gate", TiltBoard.RIGHT]])
	var once: TiltBoard = TiltGenerator.prune(twice, 3)
	_check("and of two gates that do the same job keeps one", once.tiles.count(TiltBoard.Tile.GATE) == 1)

func _test_solver() -> void:
	var solver: TiltSolver = TiltSolver.new()
	var b: TiltBoard = _board(["..0", "...", "..."], [[0, 2, 0]])
	var path: PackedInt32Array = solver.solve(b)
	_check("the solver finds the two-move solution", path.size() == 2)
	var replay: TiltBoard = b.copy()
	for dir: int in path:
		replay.tilt(dir)
	_check("replaying the solution wins", replay.is_won())

	b = _board(["0#."], [[2, 0, 0]])
	path = solver.solve(b)
	_check("a marble walled off from its hole is unsolvable", path.is_empty() and solver.exhausted())
	path = solver.solve(_board(["..0", "...", "..."], [[0, 2, 0]]), TiltSolver.DEFAULT_LIMIT, 1)
	_check("a search held to one move finds no two-move solution, and says it looked", path.is_empty() and solver.exhausted())

	b = _board(["x..0"], [[1, 0, 0]])
	path = solver.solve(b)
	_check("the solver never routes through a pit", path.size() == 1 and path[0] == TiltBoard.RIGHT)

	# Through the one-way gate is a dead end with no marble lost: the marble can never come back to its hole.
	var start: TiltBoard = _tiled(["0...."], [[1, 0, 0]], [[2, 0, "gate", TiltBoard.RIGHT]])
	var through: TiltBoard = start.copy()
	through.tilt(TiltBoard.RIGHT)
	var back_once: TiltBoard = through.copy()
	_check("a tilt back toward the gate still moves the marble", back_once.tilt(TiltBoard.LEFT).changed())
	_check("past the gate there is no way home", solver.solve(back_once).is_empty() and solver.exhausted())
	var history: Array[TiltBoard] = [start, through]
	_check("the way back from the dead end is two tilts, to the start", solver.way_back(history) == 2
		and solver.route == PackedInt32Array([TiltBoard.LEFT]))
	history = [start]
	_check("one tilt into the dead end is one tilt back", solver.way_back(history) == 1)
	history = [through]
	_check("a history of dead ends has no way back", solver.way_back(history) == -1 and solver.route.is_empty())

func _test_difficulty() -> void:
	var d: TiltDifficulty = TiltDifficulty.of(_board(["..0"], [[0, 0, 0]]))
	_check("a forced win needs no luck", d.par == 1 and d.bits == 0.0)
	d = TiltDifficulty.of(_board(["...", "..0", "..."], [[1, 1, 0]]))
	_check("one winning tilt in four is two bits", d.par == 1 and is_equal_approx(d.bits, 2.0))
	var open: TiltDifficulty = TiltDifficulty.of(_board(["...", "...", "..0"], [[1, 1, 0]]))
	var pit: TiltDifficulty = TiltDifficulty.of(_board(["...", "x..", "..0"], [[1, 1, 0]]))
	_check("a pit in reach is in play", pit.risk > 0.0 and open.risk == 0.0)
	_check("the measure finds the solver's route", open.path == TiltSolver.new().solve(_board(["...", "...", "..0"], [[1, 1, 0]])))

func _test_novelty() -> void:
	var b: TiltBoard = _board(["#.0.", "..x1", "...."], [[0, 2, 1], [3, 2, 0]])
	var recoloured: TiltBoard = _board(["#.1.", "..x0", "...."], [[0, 2, 0], [3, 2, 1]])
	var turned: TiltBoard = TiltNovelty.transform(recoloured, 3)
	_check("a board turned and recoloured is the same level", TiltNovelty.canonical(turned) == TiltNovelty.canonical(b))
	var views: TiltNovelty.Views = TiltNovelty.views(b, TiltDifficulty.of(b).path)
	var mirror: TiltBoard = TiltNovelty.transform(b, 1)
	_check("a mirrored board is a replay", TiltNovelty.clash(views, TiltNovelty.views(mirror, TiltDifficulty.of(mirror).path)) == "layout")
	var bare: TiltBoard = _board(["...0", "....", "....", "...."], [[0, 0, 0]])
	var walled: TiltBoard = _board(["...0", "....", "###.", ".###"], [[0, 0, 0]])
	var other: TiltBoard = _board(["0..#", "#...", ".#..", "..#."], [[3, 3, 0]])
	var bare_views: TiltNovelty.Views = TiltNovelty.views(bare, TiltDifficulty.of(bare).path)
	_check("new walls around the same one-tilt route are a replay",
		TiltNovelty.clash(bare_views, TiltNovelty.views(walled, TiltDifficulty.of(walled).path)) == "route")
	_check("a different board is new", TiltNovelty.clash(bare_views, TiltNovelty.views(other, TiltDifficulty.of(other).path)) == "")

func _test_serialisation() -> void:
	var b: TiltBoard = _board(["#.0", ".x1"], [[1, 0, 0], [0, 1, 1]])
	var again: TiltBoard = TiltBoard.from_dict(b.to_dict())
	_check("a board survives a round trip", again.to_dict() == b.to_dict())
	var swapped: TiltBoard = _board(["#.0", ".x1"], [[0, 1, 1], [1, 0, 0]])
	_check("the solver key ignores marble order", swapped.key() == b.key())

func _test_stars() -> void:
	_check("par or better is three stars", Stars.earned(5, 5) == 3 and Stars.earned(4, 5) == 3)
	_check("a little over par is two", Stars.earned(7, 5) == 2)
	_check("well over par is one", Stars.earned(12, 5) == 1)
	_check("the two-star leeway grows with par", Stars.leeway(12) > Stars.leeway(4))
	_check("the play screen's meter holds three stars while the goal can still be met",
		Stars.possible(0, 5, false) == 3 and Stars.possible(4, 5, false) == 3)
	_check("and drops one at the goal unsolved, since a win needs another move",
		Stars.possible(5, 5, false) == 2 and Stars.possible(5, 5, true) == 3)
	_check("and another past the two-star leeway", Stars.possible(5 + Stars.leeway(5), 5, false) == 1)

## The rolling street's projection (MATH.md section 25).
func _test_street_projection() -> void:
	var p: StreetProjection = StreetProjection.new(1150.0, 900.0, 1400.0, 360.0, 0.0002)
	var near: Vector3 = p.place(0.0, 0.0)
	_check("the street's near edge sits at the near edge, full size", near.is_equal_approx(Vector3(360.0, 1400.0, 1.0)))
	var rising: bool = true
	var shrinking: bool = true
	var last: Vector3 = near
	for i: int in range(1, 91):
		var at: Vector3 = p.place(p.radius * PI * 0.5 * float(i) / 90.0, 0.0)
		rising = rising and at.y < last.y
		shrinking = shrinking and at.z < last.z and at.z > 0.0
		last = at
	_check("farther along the street is higher up the screen, up to the horizon", rising)
	_check("and smaller", shrinking)
	_check("the horizon is the radius above the near edge", is_equal_approx(last.y, p.horizon_y()))
	var sinks: bool = p.place(400.0, 300.0).y > p.place(400.0, 0.0).y and p.place(400.0, -300.0).y > p.place(400.0, 0.0).y
	_check("the street sinks toward both sides, as a small planet", sinks)
	var grabbed: bool = true
	for s: float in [0.0, 150.0, 600.0, 1100.0]:
		grabbed = grabbed and absf(p.s_rel_at(p.place(s, 0.0).y) - s) < 0.01
	_check("a finger's height finds the point of the street under it", grabbed)
	_check("past the crest a point is hidden, before it is not", p.behind_crest(p.radius * 1.6) and not p.behind_crest(p.radius * 1.5))
	_check("tall things are placed a little past the horizon, to rise over it",
		is_equal_approx(p.far_s_rel(0.0), p.radius * (PI * 0.5 + StreetProjection.BEYOND)))
	var flat: StreetProjection = StreetProjection.new(1.0e7, 900.0, 1400.0, 360.0, 0.0)
	var level: bool = true
	for s: float in [0.0, 500.0, 1200.0]:
		var at: Vector3 = flat.place(s, 200.0)
		level = level and absf(at.y - (1400.0 - s)) < 0.5 and absf(at.z - 1.0) < 0.001
	_check("a very large radius is a flat scroll (Reduce motion)", level)
	_check("and a flat street is placed only as far as the screen's top", absf(flat.far_s_rel(0.0) - (1400.0 + StreetProjection.MARGIN)) < 1.0)
	var tilted: StreetProjection = StreetProjection.new(1340.0, 600.0, 1662.0, 360.0, 0.0)
	tilted.tilt = 0.8
	tilted.normalise_at(437.0)
	var at_rest: float = tilted.place(437.0, 0.0).z
	var next: float = tilted.place(737.0, 0.0).z
	_check("a tilted camera draws the door at rest at its painted size", absf(at_rest - 1.0) < 0.0001)
	_check("and the next door, one gap on, at about three quarters", next > 0.65 and next < 0.8)
	_check("and leaves heights on the screen to the drum", is_equal_approx(tilted.place(737.0, 0.0).y,
		1662.0 - 1340.0 * sin(737.0 / 1340.0)))

## Where the road runs and what stands beside it.
func _test_street_path() -> void:
	var alternate: bool = true
	var found: bool = true
	var passes: bool = true
	for n: int in range(1, 400):
		alternate = alternate and StreetPath.door_side(n) != StreetPath.door_side(n + 1)
		found = found and StreetPath.door_near(StreetPath.door_s(n)) == n
		# Just in front of each door the road swings out to that door's side, where the cast waits.
		var front: float = StreetPath.road_x(StreetPath.door_s(n) - StreetPath.FRONT)
		passes = passes and signf(front) == float(StreetPath.door_side(n)) \
			and absf(front - StreetPath.door_x(n)) < StreetPath.DOOR_X
	_check("doors alternate sides of the street", alternate)
	_check("the door nearest a door's place is that door", found and StreetPath.door_near(-1000.0) == 1)
	_check("the road passes just in front of every door, on its side", passes)
	var smooth: bool = true
	var slope: bool = true
	for i: int in range(5000):
		var s: float = float(i) * 7.0
		# The bend's steepness changes smoothly: the slope moves by under 3% from one pixel along to the next.
		smooth = smooth and absf(StreetPath.road_slope(s + 1.0) - StreetPath.road_slope(s)) < 0.03
		slope = slope and absf((StreetPath.road_x(s + 0.01) - StreetPath.road_x(s - 0.01)) / 0.02
			- StreetPath.road_slope(s)) < 0.01
	_check("the road bends without kinks", smooth)
	_check("and its slope is the true slope, which the ground uses for its width", slope)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(StreetPath.SHARE.size() + 1)
	var off_road: bool = true
	var off_doors: bool = true
	var same: bool = true
	var free: int = 0
	for slot: int in range(20000):
		for side: int in [-1, 1]:
			var spot: Vector2 = StreetPath.scenery(slot, side)
			same = same and spot == StreetPath.scenery(slot, side)
			var s: float = StreetPath.slot_s(slot)
			var door: int = StreetPath.door_near(s)
			var by_house: bool = StreetPath.door_side(door) == side and absf(StreetPath.door_s(door) - s) < StreetPath.DOOR_CLEAR
			free += 0 if by_house else 1
			counts[int(spot.x)] += 0 if by_house else 1
			if int(spot.x) == StreetPath.Kind.NONE:
				continue
			off_road = off_road and absf(spot.y - StreetPath.road_x(s)) >= StreetPath.ROAD_HALF + 15.0
			off_doors = off_doors and not by_house
	_check("a scenery slot always holds the same thing", same)
	_check("scenery stands off the road", off_road)
	_check("and clear of the houses on its side", off_doors)
	# The ground in front of each door is kept clear of anything taller than a flowerbed, so flowers turn up as often
	# as their share and taller things less, never more.
	var shares: bool = true
	for k: int in range(StreetPath.SHARE.size()):
		var seen: float = float(counts[k + 1]) / float(free) * 100.0
		var least: float = StreetPath.SHARE[k] * (1.0 if k + 1 == StreetPath.Kind.FLOWERS else 0.3) - 2.0
		shares = shares and seen <= StreetPath.SHARE[k] + 2.0 and seen >= least
	_check("each kind of scenery turns up as often as its share, or less where it would hide a door", shares)
	var rows_apart: bool = true
	for slot: int in range(4000):
		for side: int in [-1, 1]:
			var near_kind: int = int(StreetPath.scenery(slot, side).x)
			var back_kind: int = int(StreetPath.scenery(slot, side, true).x)
			rows_apart = rows_apart and near_kind != StreetPath.Kind.TREE and near_kind != StreetPath.Kind.SIDE_HOUSE \
				and back_kind != StreetPath.Kind.LAMP and back_kind != StreetPath.Kind.FLOWERS
	_check("the road's edge holds low things and the row behind holds trees and houses", rows_apart)
	# A wide screen's meadow: trees and bushes only, in their band, beyond the street's own scenery.
	var meadow: bool = true
	var filled: int = 0
	for slot: int in range(4000):
		for side: int in [-1, 1]:
			for band: int in range(1, 5):
				var spot: Vector2 = StreetPath.far_scenery(slot, side, band)
				if int(spot.x) == StreetPath.Kind.NONE:
					continue
				filled += 1
				var out: float = (spot.y - StreetPath.road_x(StreetPath.slot_s(slot))) * float(side)
				var inner: float = StreetPath.SCENERY_SET.y + StreetPath.FAR_BAND * float(band - 1)
				meadow = meadow and (int(spot.x) == StreetPath.Kind.TREE or int(spot.x) == StreetPath.Kind.BUSH) \
					and out > inner and out <= inner + StreetPath.FAR_BAND
	_check("a wide screen's meadow holds trees and bushes in their own bands", meadow)
	_check("and about FAR_SHARE of its spots are filled",
		absf(float(filled) / (4000.0 * 2.0 * 4.0) * 100.0 - StreetPath.FAR_SHARE) < 3.0)

# Street's rewards (REVAMP_PLAN.md section 4.7): generous, on a steady rhythm, and help is never sold as power.
# Glicko-1 (MATH.md section 29): Glickman's own worked example, the outcome's order, and the deviation shrinking.
func _test_street_rating() -> void:
	var after: PackedFloat64Array = StreetRating.update(1500.0, 200.0,
		[[1400.0, 30.0, 1.0], [1550.0, 100.0, 0.0], [1700.0, 300.0, 0.0]])
	_check("Glickman's example comes to 1464 and 151.4", absf(after[0] - 1464.0) < 1.0 and absf(after[1] - 151.4) < 0.5)
	var clean: float = StreetRating.outcome(true, 8, 8, 0, 0, 0, 20.0)
	var over: float = StreetRating.outcome(true, 10, 8, 0, 0, 0, 20.0)
	var hinted: float = StreetRating.outcome(true, 10, 8, 1, 0, 0, 20.0)
	var slow: float = StreetRating.outcome(true, 8, 8, 0, 0, 0, 400.0)
	_check("a clean solve scores 1, help and over-par and slowness less, never under 0.1", clean == 1.0
		and over < clean and hinted < over and slow < clean and StreetRating.outcome(true, 40, 8, 5, 3, 9, 9000.0) == 0.1)
	_check("a quit after real play scores 0, and leaving at once does not count", StreetRating.outcome(false, 3, 8,
		0, 0, 0, 5.0) == 0.0 and StreetRating.counts_as_quit(3, 5.0) and not StreetRating.counts_as_quit(1, 10.0))
	var mu: float = StreetRating.START_MU
	var phi: float = StreetRating.START_PHI
	for i: int in range(12):
		var next: PackedFloat64Array = StreetRating.after(mu, phi, 3.0 + i, 1.0)
		mu = next[0]
		phi = next[1]
	_check("wins raise the rating and narrow the deviation", mu > StreetRating.START_MU and phi < 150.0)
	_check("a long absence widens it again", StreetRating.rested(phi, 365.0) > phi
		and StreetRating.rested(phi, 10000.0) == StreetRating.MAX_PHI)
	_check("the band is the rating's hundred, as text", StreetRating.band(1287.4) == "1200")

# The picker on simulated players of known skill (REVAMP_PLAN.md section 13): the opening fixed, never an easier board
# (in the band, never below its floor), par never falling, rules only once taught, no board twice, the same street for
# the same seed, the pace tracking skill and never under its least, fallbacks only when needed, and a recycled board
# solving in its source's par.
func _test_street_picker() -> void:
	var pool: StreetPool = StreetPool.bundled()
	if pool.main_ref.is_empty() or pool.d_of("main-0100") <= 0.0:
		_check("the bundled boards carry their metadata (levels/meta.json)", false)
		return
	var opening: bool = true
	var never_easier: bool = true
	var par_kept: bool = true
	var taught_first: bool = true
	var unique: bool = true
	var reached: Dictionary = {}
	var fallback_early: bool = false
	var pace_ok: bool = true
	# Three players in the quick pass, and a crowd from 1000 to 2300 in the full one.
	var skills: Array[float] = [1100.0, 1500.0, 1900.0]
	if not OS.get_cmdline_user_args().has("quick"):
		for s: int in range(1000, 2301, 50):
			skills.append(float(s) + 7.0)
	var steps: Dictionary = {}
	# How far a strong player's boards stray above the target once past the opening, in bits, on average.
	var strong_gap: float = 0.0
	var strong_doors: int = 0
	for skill: float in skills:
		var state: Dictionary = StreetPicker.fresh()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(skill)
		var seen: Dictionary = {}
		for door: int in range(1, 121):
			var picked: Dictionary = StreetPicker.pick(pool, state, door, "sim%d" % int(skill))
			if door <= StreetPicker.OPENING and str(picked["id"]) != "main-%04d" % door:
				opening = false
			var doors: PackedStringArray = state["doors"]
			if not doors.is_empty():
				var last_d: float = (state["door_d"] as PackedFloat64Array)[-1]
				var last_par: int = (state["door_par"] as PackedInt32Array)[-1]
				if float(picked["d"]) < minf(last_d, StreetPicker.CEIL_FLOOR) - 0.0001:
					never_easier = false
				if int(picked["par"]) < mini(last_par, StreetPicker.CEIL_PAR):
					par_kept = false
			# Taught by the climb, or by where the floor already stands on the main path.
			var reach: float = maxf(float(state["p"]), float(pool.level_at(float(state["floor"]))))
			if not StreetPicker._taught(pool.info(str(picked["id"])), pool.taught(maxf(reach, 5.0))):
				taught_first = false
			if seen.has(picked["id"]):
				unique = false
			seen[picked["id"]] = true
			if str(picked["step"]) == "recycle" and door < 60:
				fallback_early = true
			steps[picked["step"]] = int(steps.get(picked["step"], 0)) + 1
			StreetPicker.record(state, pool, picked)
			if skill >= 1900.0 and door > 30:
				strong_gap += float(picked["d"]) - StreetPicker.target(state, pool)
				strong_doors += 1
			# Play until solved: each attempt succeeds by the player's true skill, and every attempt is rated.
			var d: float = float(picked["d"])
			var solved: bool = false
			while not solved:
				solved = rng.randf() < StreetRating.expected(skill, StreetRating.board_rating(d), 0.0)
				var next: PackedFloat64Array = StreetRating.after(float(state["mu"]), float(state["phi"]), d,
					1.0 if solved else 0.0)
				state["mu"] = next[0]
				state["phi"] = next[1]
			var step: float = StreetPicker.climbed(state, pool) - float(state["p"])
			if step < StreetPicker.PACE_MIN - 0.0001 or step > StreetPicker.PACE_MAX + 0.0001:
				pace_ok = false
			state["p"] = float(state["p"]) + step
		reached[skill] = float(state["p"])
	strong_gap /= maxf(float(strong_doors), 1.0)
	print("picker: %d simulated players, steps %s, strong players %.2f bits above target on average" % [skills.size(),
		steps, strong_gap])
	_check("a strong player's boards stay near the target, under a bit above on average", strong_gap <= 0.75)
	_check("doors 1 to 5 are always the opening", opening)
	_check("no door is easier than the last (in the band, none below its floor)", never_easier)
	_check("par never falls (in the band, never below its floor)", par_kept)
	_check("a board's rules are always taught first", taught_first)
	_check("no board twice on a street", unique)
	_check("the pace stays between its least and its most", pace_ok)
	_check("a stronger player climbs faster", float(reached[1900.0]) > float(reached[1500.0])
		and float(reached[1500.0]) > float(reached[1100.0]))
	_check("recycling only when the pool runs dry", not fallback_early)
	var a: Dictionary = StreetPicker.pick(pool, _street_after(pool, 30, "same"), 31, "same")
	var b: Dictionary = StreetPicker.pick(pool, _street_after(pool, 30, "same"), 31, "same")
	_check("the same player and door always get the same board", a["id"] == b["id"])
	var turned: TiltBoard = pool.board("main-0150~31")
	var turned_par: int = TiltSolver.new().solve(turned, 400000).size()
	_check("a recycled board solves in its source's par", turned_par == pool.par_of("main-0150"))

## Save layout 3 (REVAMP_PLAN.md sections 4.6 and 13): layouts 1 and 2 move on, every star stays on the board it was
## won on, Hard, keys and gate-opened chapters carry over, the street starts where the player was, the welcome purse
## comes once, and moving on twice changes nothing.
func _test_street_migration() -> void:
	var pool: StreetPool = StreetPool.shared()
	var unlocks: GDScript = load("res://kit/monetize/unlocks.gd")
	var gate: float = unlocks.get_script_constant_map()["GATE"]
	# A 1.5 player: main levels 1 to 150 solved but 60, a key spent on 152, the old levels 181 to 200 solved in
	# Hard, 3 keys left.
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(150)
	stars.fill(2)
	stars[59] = 0
	stars[149] = 3
	var hard: PackedByteArray = PackedByteArray()
	hard.resize(200)
	for i: int in range(HardShelf.FIRST, 200):
		hard[i] = 1
	var two: ConfigFile = ConfigFile.new()
	two.set_value("progress", "layout", 2)
	two.set_value("progress", "stars", stars)
	two.set_value("progress", "hard", hard)
	two.set_value("progress", "opened", PackedInt32Array([151]))
	two.set_value("progress", "hard_opened", PackedInt32Array([205]))
	two.set_value("monetize", "keys", 3)
	var file: ConfigFile = ConfigFile.new()
	file.parse(two.encode_to_text())
	_check("a layout 2 save moves on to layout 3", StreetMigrate.upgrade(file, pool)
		and int(file.get_value("progress", "layout")) == StreetMigrate.LAYOUT)
	_check("its stars stay by position: main and Hard keep theirs, nothing else moves",
		file.get_value("progress", "stars") == stars and file.get_value("progress", "hard") == hard
		and (file.get_value("progress", "best") as Dictionary).is_empty())
	_check("keys and opened levels carry over", int(file.get_value("monetize", "keys")) == 3
		and file.get_value("progress", "opened") == PackedInt32Array([151])
		and file.get_value("progress", "hard_opened") == PackedInt32Array([205]))
	var state: Dictionary = file.get_value("street", "state")
	var doors: PackedStringArray = state["doors"]
	var in_order: bool = doors.size() == 152
	for i: int in range(doors.size()):
		in_order = in_order and doors[i] == "main-%04d" % (i + 1)
	_check("the street is main-0001 to the furthest level solved or opened, in order", in_order)
	var hardest: float = 0.0
	for i: int in range(150):
		if stars[i] > 0:
			hardest = maxf(hardest, pool.d_of("main-%04d" % (i + 1)))
	_check("the climb is there, the floor the hardest solved, the rating that board's plus 50 and sure to 200",
		float(state["p"]) == 152.0 and is_equal_approx(float(state["floor"]), hardest)
		and is_equal_approx(float(state["mu"]), StreetRating.board_rating(pool.d_of("main-0152")) + 50.0)
		and float(state["phi"]) == 200.0 and int(state["solved"]) == 149)
	var total: int = 0
	for s: int in stars:
		total += s
	for s: int in hard:
		total += s
	_check("the welcome purse pays 5 coins a star, once", int(file.get_value("street", "coins")) == 5 * total
		and bool(file.get_value("street", "welcomed")))
	var gifts: PackedInt32Array = file.get_value("street", "gifts")
	_check("the parcels and milestones behind the player count as opened, with the first helpers in hand",
		gifts.size() == 30 and gifts.has(5) and gifts.has(140) and gifts.has(150) and not gifts.has(155)
		and file.get_value("street", "boosters") == {"footprints": 3, "ghosts": 3, "spare_step": 3})
	var text: String = file.encode_to_text()
	_check("and moving on twice changes nothing", not StreetMigrate.upgrade(file, pool) and file.encode_to_text() == text)
	var get_best: Callable = func(id: String) -> int:
		var index: int = int(id.substr(5)) - 1
		var of: PackedByteArray = stars if id.begins_with("main-") else hard
		var at: int = index + (HardShelf.FIRST if id.begins_with("hard-") else 0)
		return of[at] if at < of.size() else 0
	_check("the lit door is the one after the furthest solved, and a level skipped stays an open door behind it",
		StreetDoors.current(state, get_best) == 151 and StreetDoors.id_of(state, 60) == "main-0060"
		and int(get_best.call("main-0060")) == 0)
	# Every star is on a board identical to the one it was won on: the pool's main and Hard boards are the levels
	# Classic plays at those positions.
	var levels: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json")) as Dictionary)["levels"]
	var shelf: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/hard.json")) as Dictionary)["levels"]
	var same: bool = true
	for i: int in [0, 59, 149, 179, 519]:
		same = same and JSON.stringify(pool.boards["main-%04d" % (i + 1)]) == JSON.stringify(levels[i])
	for j: int in [0, 19, 319]:
		same = same and JSON.stringify(pool.boards["hard-%04d" % (j + 1)]) == JSON.stringify(shelf[j])
	_check("and every id names the board its position always held", same)
	# A layout 1 save (before Hard) goes through both steps.
	var one: ConfigFile = ConfigFile.new()
	var old: PackedByteArray = PackedByteArray()
	old.resize(230)
	old.fill(1)
	one.set_value("progress", "stars", old)
	one.set_value("progress", "opened", PackedInt32Array([240]))
	HardShelf.migrate(one, gate)
	StreetMigrate.upgrade(one, pool)
	var one_state: Dictionary = one.get_value("street", "state")
	var main_opened: PackedInt32Array = one.get_value("progress", "opened")
	_check("a layout 1 save goes through Hard's step and then Street's", int(one.get_value("progress", "layout")) == 3
		and (one.get_value("progress", "hard") as PackedByteArray)[200] == 1
		and (one_state["doors"] as PackedStringArray).size() == StreetMigrate.furthest(
			one.get_value("progress", "stars"), main_opened) and main_opened.has(HardShelf.FIRST))
	var fresh: ConfigFile = ConfigFile.new()
	StreetMigrate.upgrade(fresh, pool)
	_check("a new player's street is empty, at the start, with no purse",
		(fresh.get_value("street", "state")["doors"] as PackedStringArray).is_empty()
		and int(fresh.get_value("street", "coins", 0)) == 0)

	# Through the save itself: the backup, the move, and the purse paid once.
	var save: Node = root.get_node("Save")
	var kept: Array = [save.get("path"), save.get("stars"), save.get("hard_stars"), save.get("opened"),
		save.get("hard_opened"), save.get("coins"), save.get("street"), save.get("best_ids"), save.get("welcomed"),
		save.get("keys")]
	save.set("path", "user://test_layout3.cfg")
	two.save("user://test_layout3.cfg")
	var original: PackedByteArray = FileAccess.get_file_as_bytes("user://test_layout3.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(String(save.call("backup_path"))))
	save.call("restore")
	_check("the save keeps a copy of the old file before moving on",
		FileAccess.get_file_as_bytes(String(save.call("backup_path"))) == original)
	var moved: ConfigFile = ConfigFile.new()
	moved.load("user://test_layout3.cfg")
	_check("and moves on as it loads, kept that way", int(moved.get_value("progress", "layout")) == 3
		and ((save.get("street") as Dictionary)["doors"] as PackedStringArray).size() == 152
		and int(save.get("coins")) == 5 * total)
	save.call("store")
	save.call("restore")
	_check("a second launch pays no second purse", int(save.get("coins")) == 5 * total)
	_check("stars read by id: main by position, Hard from its first, the rest by id",
		int(save.call("best_of", "main-0150")) == 3 and int(save.call("best_of", "main-0060")) == 0
		and int(save.call("best_of", "hard-0001")) == 1 and int(save.call("best_of", "x-0001")) == 0)
	save.call("record_id", "x-0001", 2)
	save.call("record_id", "main-0060", 3)
	save.call("record_id", "x-0001", 1)
	_check("and recorded by id, keeping the best", int(save.call("best_of", "x-0001")) == 2
		and (save.get("stars") as PackedByteArray)[59] == 3 and int(save.call("best", 59)) == 3)

	# The cloud save, both ways: an old phone's layout 2 copy joins this one, and this one joins the old phone's.
	var cloud: GDScript = load("res://kit/play_games/cloud_save.gd")
	var mine: ConfigFile = ConfigFile.new()
	mine.load("user://test_layout3.cfg")
	mine.set_value("street", "boosters", {"ghosts": 2, "footprints": 0})
	mine.set_value("street", "owned", PackedStringArray(["hat_1"]))
	var theirs: ConfigFile = ConfigFile.new()
	var more: PackedByteArray = stars.duplicate()
	more.resize(170)
	for i: int in range(150, 170):
		more[i] = 3
	theirs.set_value("progress", "layout", 2)
	theirs.set_value("progress", "stars", more)
	theirs.set_value("street", "boosters", {"footprints": 4})
	theirs.set_value("street", "owned", PackedStringArray(["hat_2", "hat_1"]))
	var theirs_too: ConfigFile = ConfigFile.new()
	theirs_too.parse(theirs.encode_to_text())
	cloud.call("merge", mine, theirs)
	var joined: Dictionary = mine.get_value("street", "state")
	_check("an old copy with more solved brings its street and rating", (joined["doors"] as PackedStringArray).size() == 170
		and int(joined["solved"]) == 169)
	_check("stars by id keep the better, helpers the larger of each, things owned join",
		int((mine.get_value("progress", "best") as Dictionary).get("x-0001", 0)) == 2
		and mine.get_value("street", "boosters") == {"ghosts": 3, "footprints": 4, "spare_step": 3}
		and (mine.get_value("street", "owned") as PackedStringArray).size() == 2)
	var other: ConfigFile = ConfigFile.new()
	other.load("user://test_layout3.cfg")
	cloud.call("merge", theirs_too, other)
	_check("and the other way round the same street wins", ((theirs_too.get_value("street", "state") as Dictionary)
		["doors"] as PackedStringArray).size() == 170 and int((theirs_too.get_value("progress", "best") as Dictionary)
		.get("x-0001", 0)) == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_layout3.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(String(save.call("backup_path"))))
	for k: int in range(kept.size()):
		save.set(["path", "stars", "hard_stars", "opened", "hard_opened", "coins", "street", "best_ids", "welcomed",
			"keys"][k], kept[k])

## The street's doors and the look switch (REVAMP_PLAN.md section 4.5): the lit door, Classic's progress joining the
## street and the street's opening Classic, a solve and a quit rated once, and replays never.
func _test_street_doors() -> void:
	var pool: StreetPool = StreetPool.shared()
	var state: Dictionary = StreetPicker.fresh()
	for id: String in ["main-0001", "main-0002", "main-0003", "main-0004", "main-0005", "x-0001", "main-0007"]:
		StreetPicker.record(state, pool, {"id": id, "d": pool.d_of(id), "par": pool.par_of(id), "step": "fit"})
	var won: Dictionary = {"main-0001": 3, "main-0002": 2, "main-0003": 3, "main-0004": 1, "main-0005": 3, "x-0001": 2}
	var best: Callable = func(id: String) -> int: return int(won.get(id, 0))
	_check("the lit door is the one after the furthest solved", StreetDoors.current(state, best) == 7
		and StreetDoors.highest_main(state) == 7)
	var classic: PackedByteArray = PackedByteArray()
	classic.resize(40)
	for i: int in range(40):
		classic[i] = 2 if i != 20 else 0
	_check("Street to Classic opens every main level the street passed, unsolved there",
		StreetDoors.open_in_classic(state, PackedByteArray([3, 3])) == PackedInt32Array([2, 3, 4, 5, 6]))
	_check("Classic to Street brings every main board solved past the street's, in order",
		StreetDoors.absorb_classic(state, classic, pool) and StreetDoors.id_of(state, 8) == "main-0008"
		and StreetDoors.id_of(state, 39) == "main-0040" and (state["doors"] as PackedStringArray).size() == 39
		and float(state["p"]) == 40.0 and not StreetDoors.absorb_classic(state, classic, pool))
	var skip: Dictionary = StreetDoors.solved_off_street(classic, PackedByteArray(), HardShelf.FIRST)
	var picked: Dictionary = StreetPicker.pick(pool, state, 40, "doors", skip)
	_check("and the picker never offers a board solved in Classic as new", not skip.has(picked["id"])
		and not (state["doors"] as PackedStringArray).has(str(picked["id"])))
	var rated: Dictionary = StreetPicker.fresh()
	StreetDoors.rate(rated, 4.0, 1.0, 1000000)
	var mu: float = float(rated["mu"])
	var phi: float = float(rated["phi"])
	var rested: Dictionary = rated.duplicate()
	StreetDoors.rate(rated, 4.0, 1.0, 1000000 + 86400)
	StreetDoors.rate(rested, 4.0, 1.0, 1000000 + 86400 * 400)
	_check("a rated attempt moves the rating, and a long rest first widens how sure it is",
		mu > StreetRating.START_MU and phi < StreetRating.START_PHI and float(rested["phi"]) > float(rated["phi"]))
	# Through the save: a first solve rates and climbs, a replay and a quit on a solved door change nothing.
	var save: Node = root.get_node("Save")
	var kept: Array = [save.get("path"), save.get("stars"), save.get("street"), save.get("best_ids"),
		save.get("player_id")]
	save.set("path", "user://test_street_doors.cfg")
	save.set("stars", PackedByteArray())
	save.set("best_ids", {})
	save.set("street", StreetPicker.fresh())
	save.set("player_id", "testdoors")
	var street: GDScript = load("res://scenes/street/street.gd")
	var first_id: String = street.call("board_id", 1)
	_check("door 1 is picked as it is needed, and only the lit door is", first_id == "main-0001"
		and String(street.call("board_id", 3)) == "" and int(street.call("current")) == 1)
	var solved_first: bool = street.call("won", 1, 3, 2, 0, 0, 0, 8.0)
	var after_win: Dictionary = (save.get("street") as Dictionary).duplicate()
	var replayed: bool = street.call("won", 1, 3, 2, 0, 0, 0, 8.0)
	street.call("quit", 1, 9, 60.0)
	_check("a first solve rates and climbs, a replay or leaving a solved door does not", solved_first
		and not replayed and float(after_win["p"]) > 1.0 and float(after_win["mu"]) > StreetRating.START_MU
		and (save.get("street") as Dictionary)["mu"] == after_win["mu"] and int(street.call("current")) == 2)
	street.call("board_id", 2)
	street.call("quit", 2, 1, 4.0)
	var leave_at_once: float = float((save.get("street") as Dictionary)["mu"])
	street.call("quit", 2, 5, 40.0)
	_check("leaving at once costs nothing, a quit after real play lowers the rating",
		leave_at_once == float(after_win["mu"]) and float((save.get("street") as Dictionary)["mu"]) < leave_at_once)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_street_doors.cfg"))
	for k: int in range(kept.size()):
		save.set(["path", "stars", "street", "best_ids", "player_id"][k], kept[k])

## The level feed (REVAMP_PLAN.md sections 6 and 13), on fixtures signed with a test key (tools/publish_levels.py):
## a signed manifest taken and a flipped byte refused, rollback and oversize refused, unknown rules skipped, bad boards
## refused, retire and rescore applied, writes atomic, and street boards kept when pruning.
func _test_feed() -> void:
	var keys: PackedStringArray = [FileAccess.get_file_as_string("res://tests/fixtures/feed/test_key.pub.pem")]
	var bucket: String = "res://tests/fixtures/feed/bucket/"
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bucket + "manifest.json")
	var signature: String = FileAccess.get_file_as_string(bucket + "manifest.json.sig")
	var taken: Dictionary = FeedCheck.manifest(bytes, signature, keys, 0)
	_check("a manifest signed with the key is taken", bool(taken["ok"]) and taken["why"] == "ok")
	if not bool(taken["ok"]):
		return
	var flipped: PackedByteArray = bytes.duplicate()
	flipped[20] = flipped[20] ^ 1
	var game_keys: PackedStringArray = (load("res://autoload/feed.gd") as GDScript).get_script_constant_map()["KEYS"]
	_check("a flipped byte is refused, and so is a key the game does not carry",
		FeedCheck.manifest(flipped, signature, keys, 0)["why"] == "bad_signature"
		and FeedCheck.manifest(bytes, signature, game_keys, 0)["why"] == "bad_signature"
		and FeedCheck.manifest(bytes, "", keys, 0)["why"] == "bad_signature")
	_check("an older serial is refused as a rollback, the same one needs nothing",
		FeedCheck.manifest(bytes, signature, keys, 2)["why"] == "rollback"
		and FeedCheck.manifest(bytes, signature, keys, 1)["why"] == "same")
	var big: PackedByteArray = PackedByteArray()
	big.resize(FeedCheck.MAX_BYTES + 1)
	_check("an oversized manifest is refused", not bool(FeedCheck.manifest(big, signature, keys, 0)["ok"]))
	# A manifest signed with the test key that lists a file outside the feed's folders.
	_check("a listed file can never land outside the feed's folder", FeedCheck.manifest(
		FileAccess.get_file_as_bytes("res://tests/fixtures/feed/traversal.json"),
		FileAccess.get_file_as_string("res://tests/fixtures/feed/traversal.json.sig"), keys, 0)["why"] == "error")
	var manifest: Dictionary = taken["manifest"]
	var entry: Dictionary = (manifest["episodes"] as Array)[0]
	var episode_bytes: PackedByteArray = FileAccess.get_file_as_bytes(bucket + str(entry["file"]))
	_check("a file matching the signed manifest is taken, one byte short is not",
		FeedCheck.file(episode_bytes, entry) == "" and FeedCheck.file(episode_bytes.slice(1), entry) == "bad_hash")
	var episode: Dictionary = FeedCheck.episode(episode_bytes, entry)
	_check("its boards pass", bool(episode["ok"]) and (episode["boards"] as Array).size() == 3)
	var newer: Dictionary = entry.duplicate()
	newer["rules"] = FeedCheck.RULES + 1
	_check("an episode for rules this build does not know is skipped", FeedCheck.episode(episode_bytes, newer)["why"] == "rules")
	var good: Dictionary = (episode["boards"] as Array)[0]
	var bad: Array[Dictionary] = []
	for i: int in range(8):
		bad.append(good.duplicate(true))
	var rows: Array = bad[0]["rows"]
	for k: int in range(11):
		rows.append(str(rows[0]))
	bad[1]["marbles"] = [[0, 0, 0], [0, 0, 1]]
	bad[2]["par"] = 31
	bad[3]["tiles"] = [[0, 0, "laser", 0]]
	bad[4]["id"] = "main-0001"
	bad[5]["d"] = -1.0
	var many: Array = []
	for k: int in range(9):
		many.append([k % 7, 0, 0])
	bad[6]["marbles"] = many
	bad[7]["set"] = ["teleport"]
	var refused: bool = FeedCheck.board(good) == ""
	for b: Dictionary in bad:
		refused = refused and FeedCheck.board(b) != ""
	_check("a sound board passes, and a board too big, overlapping, over par, with an unknown tile or rule, a wrong id or "
		+ "difficulty, or too many marbles is refused", refused)
	var twice: Dictionary = {"format": 1, "id": "ep0001", "boards": [good, good]}
	_check("and an episode naming a board twice is refused",
		FeedCheck.episode(JSON.stringify(twice).to_utf8_buffer(), {"id": "ep0001"})["why"] == "bad_board")
	var rescore_bytes: PackedByteArray = FileAccess.get_file_as_bytes(bucket + str((manifest["rescore"] as Dictionary)["file"]))
	var pool: StreetPool = StreetPool.bundled()
	var added: int = FeedCheck.merge(pool, [{"boards": episode["boards"], "listed": true}], manifest["retired"],
		FeedCheck.rescores(rescore_bytes), [])
	_check("new boards join the pool, retired ids leave future picks, rescores apply", added == 3 and pool.has("ep0001-02")
		and pool.retired.has("main-0101") and is_equal_approx(pool.d_of("main-0100"), 19.5)
		and is_equal_approx(pool.d_of("ep0001-01"), float(good["d"])))
	var retuned: Dictionary = good.duplicate(true)
	retuned["rev"] = 2
	retuned["par"] = 10
	_check("a board joins once, and a higher revision replaces it",
		FeedCheck.merge(pool, [{"boards": episode["boards"]}], [], {}, []) == 0
		and FeedCheck.merge(pool, [{"boards": [retuned]}], [], {}, []) == 1 and pool.par_of("ep0001-01") == 10)
	var kept_pool: StreetPool = StreetPool.bundled()
	FeedCheck.merge(kept_pool, [{"boards": episode["boards"], "listed": false}], [], {}, ["ep0001-03"])
	_check("an unlisted episode kept for the street stays playable but leaves future picks, a dropped board never joins",
		kept_pool.has("ep0001-01") and kept_pool.retired.has("ep0001-01") and not kept_pool.has("ep0001-03"))

	# The client's files: atomic writes, a half-written file never read, the kept feed merged, and pruning.
	var feed: Node = root.get_node("Feed")
	var was: Array = [feed.get("dir"), feed.get("keys")]
	var dir: String = "user://test_feed/"
	feed.set("dir", dir)
	feed.set("keys", keys)
	for file: String in ["manifest.json", "manifest.json.sig", str(entry["file"]),
			str((manifest["rescore"] as Dictionary)["file"])]:
		feed.call("write_atomic", dir + file, FileAccess.get_file_as_bytes(bucket + file))
	_check("a file is written whole, with no part left behind",
		FileAccess.get_file_as_bytes(dir + str(entry["file"])) == episode_bytes
		and not FileAccess.file_exists(dir + str(entry["file"]) + ".part"))
	var stale: FileAccess = FileAccess.open(dir + "episodes/ep0007-0badf00d.json.part", FileAccess.WRITE)
	stale.store_string("{\"format\": 1, \"id\": \"ep00")
	stale.close()
	var stored_pool: StreetPool = StreetPool.bundled()
	_check("the kept feed joins the pool as it loads, and a half-written file is never read",
		int(feed.call("merge_stored", stored_pool)) == 3 and stored_pool.retired.has("main-0101")
		and not FileAccess.file_exists(dir + "episodes/ep0007-0badf00d.json.part"))
	feed.call("write_atomic", dir + "episodes/ep0002-aaaaaaaa.json", episode_bytes)
	feed.call("write_atomic", dir + "episodes/ep0009-bbbbbbbb.json", episode_bytes)
	feed.call("prune", manifest, PackedStringArray(["main-0001", "ep0002-05~31"]))
	_check("pruning drops unlisted files but keeps an episode holding a board on the street",
		FileAccess.file_exists(dir + "episodes/ep0002-aaaaaaaa.json")
		and not FileAccess.file_exists(dir + "episodes/ep0009-bbbbbbbb.json")
		and FileAccess.file_exists(dir + str(entry["file"])))
	for folder: String in ["episodes", "rescore", ""]:
		for file: String in DirAccess.get_files_at(dir + folder):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + folder.path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + folder))
	feed.set("dir", was[0])
	feed.set("keys", was[1])

## Ads between levels ship off (21 November): they show only once the kept, signed feed turns them on, with the
## pacing and the trouble pause as before. Off by default, on through a signed manifest, and a bad signature leaves
## them off.
func _test_interstitial_switch() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var feed: Node = root.get_node("Feed")
	var was: Array = [feed.get("dir"), feed.get("keys")]
	var keys: PackedStringArray = [FileAccess.get_file_as_string("res://tests/fixtures/feed/test_key.pub.pem")]
	feed.set("keys", keys)
	var verdicts: Array[bool] = []
	for bucket: String in ["none", "bucket_ads", "bucket_ads_badsig", "bucket"]:
		var dir: String = "user://test_feed_ads_%s/" % bucket
		feed.set("dir", dir)
		if bucket != "none":
			for file: String in ["manifest.json", "manifest.json.sig"]:
				feed.call("write_atomic", dir + file,
					FileAccess.get_file_as_bytes("res://tests/fixtures/feed/%s/%s" % [bucket, file]))
		feed.call("forget")
		verdicts.append(bool(ads.call("interstitials_allowed")))
		for file: String in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + file))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	feed.set("dir", was[0])
	feed.set("keys", was[1])
	feed.call("forget")
	_check("Plumb's ads between levels answer to the feed", ads.get("interstitial_switch") == Callable(feed, "interstitials_on"))
	_check("with no feed kept they are off", not verdicts[0])
	_check("a signed manifest turns them on", verdicts[1])
	_check("a bad signature leaves them off", not verdicts[2])
	_check("and so does a signed manifest that says nothing of them", not verdicts[3])
	_check("off, none is ever due, whatever the pacing", not ads.call("interstitial_due"))
	_check("and a game without a switch keeps its pacing alone", (func() -> bool:
		var switch: Callable = ads.get("interstitial_switch")
		ads.set("interstitial_switch", Callable())
		var open: bool = ads.call("interstitials_allowed")
		ads.set("interstitial_switch", switch)
		return open).call())

## Decision 7: the banner shows on the map only, never on a one-off screen. The look chooser's live street is a
## preview that asks for no banner, and the studio's opening keeps the banner back while it plays.
func _test_one_off_screens_carry_no_banner() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var before: int = (ads.get("_screens") as Array).size()
	var chooser: Node = (load("res://scenes/street/chooser.tscn") as PackedScene).instantiate()
	root.add_child(chooser)
	await process_frame
	await process_frame
	_check("the look chooser, with its live street, asks for no banner", (ads.get("_screens") as Array).size() == before)
	chooser.queue_free()
	await process_frame
	var covers: int = int(ads.get("_covers"))
	var intro: Node = (load("res://kit/ui/intro.gd") as GDScript).new()
	root.add_child(intro)
	var during: int = int(ads.get("_covers"))
	intro.queue_free()
	await process_frame
	_check("and the opening keeps the banner back while it plays", during == covers + 1
		and int(ads.get("_covers")) == covers)

## A street of `n` doors picked for `player`, each solved at once.
func _street_after(pool: StreetPool, n: int, player: String) -> Dictionary:
	var state: Dictionary = StreetPicker.fresh()
	for door: int in range(1, n + 1):
		StreetPicker.record(state, pool, StreetPicker.pick(pool, state, door, player))
		state["p"] = StreetPicker.climbed(state, pool)
	return state

func _test_street_rewards() -> void:
	_check("a win pays 10, 5 a star and 5 more when clean", StreetRewards.win_coins(3, true) == 30
		and StreetRewards.win_coins(1, false) == 15)
	_check("the knocker needs par with no hint and no restart", StreetRewards.knocker(8, 8, false, false)
		and not StreetRewards.knocker(9, 8, false, false) and not StreetRewards.knocker(8, 8, true, false)
		and not StreetRewards.knocker(8, 8, false, true))
	_check("a spare step gives one move of leeway for the stars", StreetRewards.stars(9, 8, true) == 3
		and StreetRewards.stars(9, 8, false) < 3)
	var parcels: PackedInt32Array = PackedInt32Array()
	var milestones: PackedInt32Array = PackedInt32Array()
	for n: int in range(1, 101):
		if StreetRewards.has_parcel(n):
			parcels.append(n)
		if StreetRewards.is_milestone(n):
			milestones.append(n)
	_check("a parcel every fifth door, a milestone every twentieth in its place",
		parcels == PackedInt32Array([5, 10, 15, 25, 30, 35, 45, 50, 55, 65, 70, 75, 85, 90, 95])
		and milestones == PackedInt32Array([20, 40, 60, 80, 100]))
	var firsts: bool = true
	for b: int in range(3):
		var gift: Dictionary = StreetRewards.parcel(StreetRewards.BOOSTER_AT[b])
		firsts = firsts and int(gift["booster"]) == b and int(gift["count"]) == StreetRewards.BOOSTER_FIRST
	_check("the first three parcels each bring a new helper, three of it", firsts)
	var later: bool = true
	var hats: int = 0
	for n: int in range(25, 400, 5):
		if not StreetRewards.has_parcel(n):
			continue
		var gift: Dictionary = StreetRewards.parcel(n)
		later = later and int(gift["coins"]) == StreetRewards.PARCEL_COINS \
			and (int(gift["booster"]) >= 0) != (int(gift["hat"]) >= 0)
		hats += 1 if int(gift["hat"]) >= 0 else 0
	_check("later parcels bring coins and either a helper or a hat", later and hats > 0)
	_check("helpers open after their parcel's door", not StreetRewards.booster_open(0, 5)
		and StreetRewards.booster_open(0, 6) and StreetRewards.booster_open(2, 16))
	_check("families arrive in turn at each milestone", StreetRewards.family_of(20) == 0
		and StreetRewards.family_of(40) == 1 and StreetRewards.family_of(100) == 0)
	_test_street_purse()

# Street's purse and keepsakes survive a restart, and a parcel opens once.
func _test_street_purse() -> void:
	var save: Node = root.get_node("Save")
	var real: String = save.get("path")
	var fields: PackedStringArray = ["coins", "boosters", "gifts", "knockers", "street_owned", "worn", "daily_paid"]
	var kept: Array[Variant] = []
	for field: String in fields:
		kept.append(save.get(field))
	save.set("path", "user://test_street.cfg")
	save.set("coins", 0)
	save.set("boosters", {})
	save.set("gifts", PackedInt32Array())
	save.call("add_coins", 45)
	var spent: bool = save.call("spend_coins", 20)
	var broke: bool = save.call("spend_coins", 999)
	_check("coins are spent only when there are enough", spent and not broke and int(save.get("coins")) == 25)
	save.call("add_booster", "ghosts", 3)
	var first: bool = save.call("claim_gift", 5)
	var again: bool = save.call("claim_gift", 5)
	_check("a parcel opens once", first and not again)
	var unsolved: bool = save.call("pay_daily", 400, false)
	var paid: bool = save.call("pay_daily", 400, true)
	var again_paid: bool = save.call("pay_daily", 400, true)
	_check("the day's puzzle pays its coins once, when solved", not unsolved and paid and not again_paid
		and int(save.get("coins")) == 25 + StreetRewards.DAILY)
	save.set("coins", 25)
	save.call("set_knocker", 7)
	save.call("own_street", "hat_2")
	save.call("wear", 1, 2)
	save.set("coins", 0)
	save.set("boosters", {})
	save.set("gifts", PackedInt32Array())
	save.set("knockers", PackedInt32Array())
	save.set("street_owned", PackedStringArray())
	save.set("worn", PackedInt32Array([0, 0, 0, 0]))
	save.call("restore")
	var count: int = save.call("booster_count", "ghosts")
	var gifts: PackedInt32Array = save.get("gifts")
	var knockers: PackedInt32Array = save.get("knockers")
	var owned: PackedStringArray = save.get("street_owned")
	var worn: PackedInt32Array = save.get("worn")
	_check("coins, helpers, parcels, knockers, things owned and hats worn are saved", int(save.get("coins")) == 25
		and count == 3 and gifts.has(5) and knockers.has(7) and owned.has("hat_2") and worn[1] == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_street.cfg"))
	save.set("path", real)
	for i: int in range(fields.size()):
		save.set(fields[i], kept[i])

# A tap's wobble (MATH.md section 27): it squashes about an eighth, keeps its area, rocks a little, and rests
# within about half a second, the same however the frames fall.
func _test_jiggle() -> void:
	var j: Jiggle = Jiggle.new()
	j.kick()
	var peak: float = 0.0
	var area: bool = true
	var tilt: float = 0.0
	var t: float = 0.0
	while j.step(1.0 / 60.0) and t < 3.0:
		t += 1.0 / 60.0
		peak = maxf(peak, j.s)
		var sq: Vector2 = j.squash()
		area = area and absf(sq.x * sq.y - 1.0) < 0.0001
		tilt = maxf(tilt, absf(j.tilt()))
	_check("a tap squashes about an eighth", peak > 0.09 and peak < 0.16)
	_check("the wobble keeps the area", area)
	_check("it rocks a few degrees at most", tilt > 0.02 and tilt < 0.09)
	_check("and rests in 0.35 to 0.6 s", t > 0.35 and t < 0.6)
	_check("at rest it is exactly still", j.squash() == Vector2.ONE and j.tilt() == 0.0)
	var slow: Jiggle = Jiggle.new()
	slow.kick()
	var fast: Jiggle = Jiggle.new()
	fast.kick()
	slow.step(0.1)
	for i: int in range(12):
		fast.step(0.1 / 12.0)
	_check("a slow frame lands where many quick ones do", absf(slow.s - fast.s) < 0.001)

# Shravan's rule: portrait is the design and a wide screen gets its own layout, on a base whose short side is 720
# units, so the hand sees one size either way (REVAMP_PLAN.md section 16).
func _test_street_layout() -> void:
	var shapes: Array[Vector2] = [Vector2(1080, 2400), Vector2(2400, 1080), Vector2(1920, 1080), Vector2(2560, 1080),
		Vector2(2048, 1536), Vector2(1536, 2048), Vector2(720, 1280), Vector2(1000, 1000)]
	var short_side: bool = true
	var keeps_shape: bool = true
	var covers_base: bool = true
	for pixels: Vector2 in shapes:
		var design: Vector2 = StreetLayout.design_size(pixels)
		var base: Vector2 = StreetLayout.base_for(pixels)
		short_side = short_side and minf(design.x, design.y) >= StreetLayout.SHORT - 0.01 \
			and (absf(design.x - base.x) < 0.01 or absf(design.y - base.y) < 0.01)
		keeps_shape = keeps_shape and is_equal_approx(design.x / design.y, pixels.x / pixels.y)
		covers_base = covers_base and design.x >= base.x - 0.01 and design.y >= base.y - 0.01
	_check("every screen's short side is at least 720 units, and one side matches the base", short_side)
	_check("the design keeps the screen's shape: nothing stretches", keeps_shape)
	_check("and always holds the whole base for its orientation", covers_base)
	_check("a landscape phone is wide, a portrait one and a square are not",
		StreetLayout.wide(StreetLayout.design_size(Vector2(2400, 1080)))
		and not StreetLayout.wide(StreetLayout.design_size(Vector2(1080, 2400)))
		and not StreetLayout.wide(StreetLayout.design_size(Vector2(1000, 1000))))
	var a142: Vector2 = StreetLayout.design_size(Vector2(1084, 2412))
	_check("a portrait phone shows the same design as before the rule",
		absf(a142.x - 720.0) < 0.01 and absf(a142.y - 2412.0 * 720.0 / 1084.0) < 0.01)

# Every shipped level, on the main path and in Hard, is re-solved against the current rules, so a rule change that
# alters a par or makes a level unsolvable fails before a build can ship it.
func _test_level_pack() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	var hard_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/hard.json"))
	_check("levels.json and hard.json parse", typeof(data) == TYPE_DICTIONARY and typeof(hard_data) == TYPE_DICTIONARY)
	if typeof(data) != TYPE_DICTIONARY or typeof(hard_data) != TYPE_DICTIONARY:
		return
	var levels: Array = (data as Dictionary)["levels"]
	var hard: Array = (hard_data as Dictionary)["levels"]
	var plateau: int = TiltGenerator.chapter_start(TiltGenerator.PLATEAU_FROM)
	_check("the pack has every level", levels.size() == TiltGenerator.level_count())
	_check("the pack lists every chapter", _same_chapters((data as Dictionary).get("chapters", []), TiltGenerator.chapter_list()))
	_check("levels 1 to %d are as they shipped before the plateau" % plateau,
		JSON.stringify(levels.slice(0, plateau)).sha256_text() == KEPT_DIGEST)
	_check("the Hard levels are the old levels %d to %d, in order and unchanged" % [plateau + 1, HardShelf.COUNT],
		int((hard_data as Dictionary)["first"]) == plateau and HardShelf.FIRST == plateau
		and hard.size() == HardShelf.COUNT - plateau and JSON.stringify(hard).sha256_text() == HARD_DIGEST)
	# The bouncy blocks came in at the plateau's start after the rest of it was made, which moved on a chapter as it was.
	var added: int = HardShelf.ADDED * HardShelf.CHAPTER
	var states: Array = (data as Dictionary)["rng_states"]
	_check("the plateau made before the bouncy blocks is a chapter later and otherwise unchanged",
		JSON.stringify(levels.slice(plateau + added)).sha256_text() == SHIFTED_DIGEST)
	_check("and the generator's state after each chapter made before them is kept, in the order they were made",
		states.size() == TiltGenerator.CHAPTERS.size()
		and JSON.stringify(states.slice(0, states.size() - HardShelf.ADDED)).sha256_text() == STATES_DIGEST
		and TiltGenerator.CHAPTERS[TiltGenerator.making_order()[-1]].get("after_hard", false))
	# Both sets as one list: the main path, then each Hard level by its index in the game's numbering and under the
	# name analytics gives it, "h1" on.
	var all: Array = levels.duplicate()
	all.append_array(hard)
	var numbers: PackedInt32Array = PackedInt32Array()
	var names: PackedStringArray = PackedStringArray()
	for i: int in range(all.size()):
		numbers.append(i if i < levels.size() else i - levels.size() + plateau)
		names.append(str(i + 1) if i < levels.size() else "h%d" % (i - levels.size() + 1))
	var solver: TiltSolver = TiltSolver.new()
	var boards: Array[TiltBoard] = []
	var measures: Array[TiltDifficulty] = []
	var views: Array[TiltNovelty.Views] = []
	var wrong: PackedStringArray = PackedStringArray()
	for i: int in range(all.size()):
		var level: Dictionary = all[i]
		var board: TiltBoard = TiltBoard.from_dict(level)
		var path: PackedInt32Array = solver.solve(board, 100000)
		if path.size() != int(level["par"]):
			wrong.append(names[i])
		var measure: TiltDifficulty = TiltDifficulty.of(board)
		boards.append(board)
		measures.append(measure)
		views.append(TiltNovelty.views(board, measure.path))
	_check("every level solves in exactly its par (wrong: %s)" % ", ".join(wrong), wrong.is_empty())

	var same: PackedStringArray = PackedStringArray()
	var replays: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for i: int in range(all.size()):
		var key: String = TiltNovelty.canonical(boards[i])
		if seen.has(key):
			same.append("%s=%s" % [names[int(seen[key])], names[i]])
		seen[key] = i
		for j: int in range(i + 1, all.size()):
			var why: String = TiltNovelty.clash(views[i], views[j])
			if why != "":
				replays.append("%s-%s %s" % [names[i], names[j], why])
	_check("no two levels of either set are the same level (%s)" % ", ".join(same), same.is_empty())
	_check("no level of either set is a near replay of another (%s)" % ", ".join(replays), replays.is_empty())

	# The climb: levels 1 to 180, then the Hard levels after them, as they all shipped before the plateau.
	var climb: Array[int] = []
	climb.assign(range(plateau))
	climb.append_array(range(levels.size(), all.size()))
	_check_climb(climb, numbers, names, boards, measures)
	# The main path from the plateau on.
	var flat: Array[int] = []
	flat.assign(range(plateau - 1, levels.size()))
	_check_plateau(flat, numbers, names, boards, measures)
	var not_needed: PackedStringArray = PackedStringArray()
	for i: int in range(plateau, levels.size()):
		var c: int = TiltGenerator.chapter_at(i)
		if not TiltGenerator.needs(boards[i], TiltGenerator.CHAPTERS[c]["rule"], measures[i].par,
				int(TiltGenerator.CHAPTERS[c].get("search", TiltGenerator.SEARCH_LIMIT))):
			not_needed.append(names[i])
	_check("every level of the plateau needs its chapter's rule (not: %s)" % ", ".join(not_needed), not_needed.is_empty())
	_check_naive_players(boards.slice(plateau, levels.size()), measures.slice(plateau, levels.size()))

## The rules of MATH.md sections 6, 8 and 10 over a run of levels, `at` indexing into the other arrays, and `numbers`
## the index of each level in the game's numbering.
func _check_climb(at: Array[int], numbers: PackedInt32Array, names: PackedStringArray, boards: Array[TiltBoard],
		measures: Array[TiltDifficulty]) -> void:
	var easier: PackedStringArray = PackedStringArray()
	var shorter: PackedStringArray = PackedStringArray()
	var flat: PackedStringArray = PackedStringArray()
	# Where par-first order began on the climb, which has no chapter added after the Hard levels.
	var by_par_from: int = 0
	for c: int in range(TiltGenerator.BY_PAR_FROM):
		if not TiltGenerator.CHAPTERS[c].get("after_hard", false):
			by_par_from += TiltGenerator.chapter_size(c)
	var run: int = 1
	for k: int in range(1, at.size()):
		var i: int = at[k]
		var was: int = at[k - 1]
		# From chapter 11 levels ship par first, so bits may start lower when par steps up.
		var by_par: bool = k >= by_par_from
		if measures[i].before(measures[was]) if by_par else measures[i].easier_than(measures[was]):
			easier.append(names[i])
		if measures[i].par < measures[was].par:
			shorter.append(names[i])
		run = run + 1 if measures[i].same_as(measures[was], by_par) else 1
		if run > TiltGenerator.RUN:
			flat.append(names[i])
	_check("on the climb no level is easier than the one before (at: %s)" % ", ".join(easier), easier.is_empty())
	_check("on the climb par never falls (at: %s)" % ", ".join(shorter), shorter.is_empty())
	_check("on the climb no more than %d levels in a row are equally hard (at: %s)" % [TiltGenerator.RUN,
		", ".join(flat)], flat.is_empty())
	_check_chapters(at, numbers, names, boards, measures, "on the climb")

## The plateau from the level before it: never below level 160's par and bits, never more than the band above them,
## climbing within a chapter, and falling, at a chapter's first level, by no more than the band.
func _check_plateau(at: Array[int], numbers: PackedInt32Array, names: PackedStringArray, boards: Array[TiltBoard],
		measures: Array[TiltDifficulty]) -> void:
	var floor: TiltDifficulty = measures[TiltGenerator.PLATEAU_LEVEL - 1]
	var below: PackedStringArray = PackedStringArray()
	var above: PackedStringArray = PackedStringArray()
	var easier: PackedStringArray = PackedStringArray()
	var falls: PackedStringArray = PackedStringArray()
	var flat: PackedStringArray = PackedStringArray()
	var run: int = 1
	for k: int in range(1, at.size()):
		var i: int = at[k]
		var was: int = at[k - 1]
		var m: TiltDifficulty = measures[i]
		# Bits in the plateau's own measure, so a three-way board counts against three tilts (TiltGenerator.bits_scale).
		var scale: float = TiltGenerator.bits_scale(TiltGenerator.chapter_at(numbers[i]))
		var scale_was: float = TiltGenerator.bits_scale(TiltGenerator.chapter_at(numbers[was]))
		if m.par < floor.par or m.bits < floor.bits * scale:
			below.append(names[i])
		if m.par > floor.par + TiltGenerator.PLATEAU_PARS \
				or m.bits > floor.bits * scale + TiltGenerator.PLATEAU_BITS * scale:
			above.append(names[i])
		if k > 1 and not _opens_chapter(numbers[i]) and m.before(measures[was]):
			easier.append(names[i])
		if k > 1 and (measures[was].par - m.par > TiltGenerator.PLATEAU_PARS
				or measures[was].bits / scale_was - m.bits / scale > TiltGenerator.PLATEAU_BITS):
			falls.append(names[i])
		run = run + 1 if m.same_as(measures[was], true) else 1
		if run > TiltGenerator.RUN:
			flat.append(names[i])
	_check("no level of the plateau is easier than level %d (at: %s)" % [TiltGenerator.PLATEAU_LEVEL,
		", ".join(below)], below.is_empty())
	_check("no level of the plateau sits above its band of %d moves and %.1f bits (at: %s)" % [TiltGenerator.PLATEAU_PARS,
		TiltGenerator.PLATEAU_BITS, ", ".join(above)], above.is_empty())
	_check("within a chapter of the plateau no level is easier than the one before (at: %s)" % ", ".join(easier),
		easier.is_empty())
	_check("on the plateau no level falls from the one before by more than the band (at: %s)" % ", ".join(falls),
		falls.is_empty())
	_check("on the plateau no more than %d levels in a row are equally hard (at: %s)" % [TiltGenerator.RUN,
		", ".join(flat)], flat.is_empty())
	_check_chapters(at.slice(1), numbers, names, boards, measures, "on the plateau")

func _check_chapters(at: Array[int], numbers: PackedInt32Array, names: PackedStringArray, boards: Array[TiltBoard],
		measures: Array[TiltDifficulty], where: String) -> void:
	var less: PackedStringArray = PackedStringArray()
	var tame: PackedStringArray = PackedStringArray()
	for k: int in range(at.size()):
		var i: int = at[k]
		if _pits(boards[i]) > 0 and measures[i].risk <= 0.0:
			tame.append(names[i])
		# A new chapter's tiles carry some of the load, so its first board may hold less than the last chapter's.
		if k == 0 or _opens_chapter(numbers[i]):
			continue
		var a: TiltBoard = boards[at[k - 1]]
		var b: TiltBoard = boards[i]
		if b.cells.size() < a.cells.size() or b.marbles_left() < a.marbles_left() or _colours(b) < _colours(a) \
				or _pits(b) < _pits(a):
			less.append(names[i])
	_check("%s, within a chapter no level takes away room, a colour, a marble or a pit (at: %s)" % [where,
		", ".join(less)], less.is_empty())
	_check("%s, every pit level has a pit in play (not: %s)" % [where, ", ".join(tame)], tame.is_empty())

static func _opens_chapter(index: int) -> bool:
	return TiltGenerator.chapter_start(TiltGenerator.chapter_at(index)) == index

## Neither a player who tilts at random nor one who always takes the tilt that looks best clears the plateau in par
## most of the time (MATH.md section 16).
func _check_naive_players(boards: Array[TiltBoard], measures: Array[TiltDifficulty]) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var greedy: int = 0
	var lucky: int = 0
	for k: int in range(boards.size()):
		greedy += 1 if TiltNaive.greedy(boards[k], measures[k].par) else 0
		lucky += 1 if TiltNaive.lucky(boards[k], measures[k].par, NAIVE_TRIES, rng) > 0 else 0
	print("  naive players on the plateau: greedy clears %d of %d in par, %d random tries clear %d" % [greedy,
		boards.size(), NAIVE_TRIES, lucky])
	_check("greedy tilting clears fewer than one plateau level in %d in par" % NAIVE_SHARE,
		greedy * NAIVE_SHARE < boards.size())
	_check("random tilting clears fewer than one plateau level in %d in par" % NAIVE_SHARE,
		lucky * NAIVE_SHARE < boards.size())

# A rule change that quietly undoes an opening level's trait fails here, and so does a splice that would
# touch anything in the level file but the opening.
func _test_opening() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var levels: Array = (data as Dictionary)["levels"]
	for k: int in range(TiltShowcase.SLOTS.size()):
		var slot: Dictionary = TiltShowcase.SLOTS[k]
		_check("opening level %d shows %s" % [k + 1, ", ".join(PackedStringArray(slot["traits"]))],
			TiltShowcase.holds(TiltBoard.from_dict(levels[k]), slot))
	var long: Dictionary = {"marbles": 1, "par": 1, "traits": ["long"]}
	_check("a roll of three cells home is long, of two is not", TiltShowcase.holds(_board(["0..."], [[3, 0, 0]]), long)
		and not TiltShowcase.holds(_board(["0.."], [[2, 0, 0]]), long))
	var together: Dictionary = {"marbles": 2, "par": 1, "traits": ["together", "busy"]}
	_check("two marbles in a line drop together", TiltShowcase.holds(_board(["0.."], [[1, 0, 0], [2, 0, 0]]), together))
	_check("a mirrored board is symmetric, a lopsided one less so",
		TiltShowcase.symmetry(_board(["#.#", "...", ".0."], []), false) == 1.0
		and TiltShowcase.symmetry(_board(["#..", "...", ".0."], []), false) < 1.0)
	var file: Dictionary = {"levels": [{"marbles": [[1, 0, 0]], "par": 1, "rows": ["#.0"]},
		{"marbles": [[2.0, 1.0, 0.0]], "par": 2.0, "rows": ["0..", "..."], "tiles": [[0, 1, "stop", 0]]}],
		"rng_states": ["7"], "seed": 2026}
	var fresh: Dictionary = {"marbles": [[0, 0, 0], [1, 0, 0]], "par": 1, "rows": ["..0", "#.#"]}
	var after: Dictionary = file.duplicate(true)
	(after["levels"] as Array)[0] = fresh
	_check("a new opening is spliced into the level file and nothing else changes",
		LevelTool.splice(JSON.stringify(file, "\t"), [fresh]) == JSON.stringify(after, "\t"))

## JSON reads every number back as a float.
static func _same_chapters(read: Array, made: Array) -> bool:
	if read.size() != made.size():
		return false
	for c: int in range(made.size()):
		var a: Dictionary = read[c]
		var b: Dictionary = made[c]
		if a.get("name") != b["name"] or a.get("line") != b["line"] or int(a.get("count", -1)) != int(b["count"]):
			return false
	return true

static func _colours(b: TiltBoard) -> int:
	var seen: Dictionary = {}
	for c: int in b.marble_colour:
		if c != TiltBoard.STONE:
			seen[c] = true
	return seen.size()

static func _pits(b: TiltBoard) -> int:
	return b.cells.count(TiltBoard.Cell.PIT)

# Kit classes that talk to the autoloads compile only once those exist, which is after this script, so
# they are loaded here rather than named.
func _test_appearance() -> void:
	var appearance: GDScript = load("res://kit/ui/appearance.gd")
	var choice: Dictionary = appearance.get_script_constant_map()["Choice"]
	_check("light and dark are fixed choices", not appearance.call("resolve", choice["LIGHT"]) and appearance.call("resolve", choice["DARK"]))
	_check("a new player starts in plumb's own look", appearance.call("native") == choice["LIGHT"])
	Brand.use(true)
	var dark_ok: bool = Brand.BG == Brand.DARK["bg"] and Palette.TILE == Palette.DARK["tile"] \
		and Palette.marble(0) == (Palette.DARK["marbles"] as Array)[0]
	Brand.use(false)
	_check("dark swaps the kit's palette and the board's", dark_ok)
	_check("light puts them back", Brand.BG == Brand.LIGHT["bg"] and Palette.TILE == Palette.LIGHT["tile"])
	for key: String in Brand.LIGHT:
		_check("the dark palette has %s" % key, Brand.DARK.has(key))
	for key: String in Palette.LIGHT:
		_check("the dark board has %s" % key, Palette.DARK.has(key))

func _test_contrast() -> void:
	for palette: String in ["LIGHT", "DARK"]:
		var p: Dictionary = Brand.LIGHT if palette == "LIGHT" else Brand.DARK
		for pair: Array in CONTRAST:
			var fore: Color = p.get(pair[0], Color.BLACK)
			var back: Color = p.get(pair[1], Color.BLACK)
			var ratio: float = _contrast(fore, back)
			_check("Brand.%s %s on %s has contrast %.1f, needs %.1f" % [palette, pair[0], pair[1], ratio, pair[2]],
				ratio >= float(pair[2]))

func _test_themes() -> void:
	var themes: GDScript = load("res://kit/ui/themes.gd")
	for id: String in themes.call("ids"):
		for dark: bool in [false, true]:
			var t: Dictionary = themes.call("colours", id, dark)
			if t.is_empty():
				continue
			var p: Dictionary = t.duplicate()
			p["danger"] = (Brand.DARK if dark else Brand.LIGHT)["danger"]
			var short: PackedStringArray = PackedStringArray()
			for pair: Array in CONTRAST:
				var ratio: float = _contrast(p[pair[0]], p[pair[1]])
				if ratio < float(pair[2]):
					short.append("%s on %s %.1f" % [pair[0], pair[1], ratio])
			# The board needs no more than the game's own dark board gives: holes also carry a coloured ring.
			Brand.use_theme(t, dark)
			for pair: Array in [["wall", Palette.WALL, 2.0], ["hole", Palette.HOLE, 1.5], ["pit", Palette.PIT, 1.5]]:
				var ratio: float = _contrast(pair[1], Palette.TILE)
				if ratio < float(pair[2]):
					short.append("%s on floor %.1f" % [pair[0], ratio])
			_check("the %s theme reads in %s: %s" % [id, "dark" if dark else "light", ", ".join(short)], short.is_empty())
	Brand.use(Brand.NATIVE_DARK)

func _test_marble_sets() -> void:
	var families: Array = Palette.LIGHT["marbles"]
	var finishes: Array[int] = []
	var bad: PackedStringArray = PackedStringArray()
	var strays: PackedStringArray = PackedStringArray()
	for look: Dictionary in GameLooks.LOOKS:
		var id: String = look["id"]
		var entry: Array = GameLooks.SETS.get(id, [])
		var colours: Array = entry[0] if entry.size() == 2 else []
		if entry.size() != 2 or (colours.size() != 4 and not (colours.is_empty() and id == "classic")) \
				or finishes.has(int(entry[1])):
			bad.append(id)
			continue
		finishes.append(int(entry[1]))
		for k: int in range(colours.size()):
			var nearest: int = 0
			for j: int in range(families.size()):
				if _hue_gap(colours[k], families[j]) < _hue_gap(colours[k], families[nearest]):
					nearest = j
			if nearest != k:
				strays.append("%s %d" % [id, k])
	_check("every marble set has four colours and a finish of its own: %s" % ", ".join(bad),
		bad.is_empty() and GameLooks.SETS.size() == GameLooks.LOOKS.size())
	_check("every marble set keeps Classic's red, teal, amber and violet in order: %s" % ", ".join(strays), strays.is_empty())
	var given: int = (load("res://kit/ui/looks.gd") as GDScript).get_script_constant_map()["FREE"]
	var counts: PackedStringArray = PackedStringArray(["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"])
	var named: bool = GameLooks.PACK_ROW.begins_with(counts[GameLooks.LOOKS.size() - given - 1] + " more")
	for k: int in range(GameLooks.LOOKS.size()):
		var set_name: String = String(GameLooks.LOOKS[k]["name"]).to_lower()
		named = named and GameLooks.PACK_LINE.to_lower().contains(set_name) == (k >= given)
	_check("the Marble pack counts and names the sets it opens, and none of the free ones", named)

func _test_gaze() -> void:
	var white: Vector2 = Vector2(0.22, 0.26)
	var pupil: float = 0.1
	var outside: int = 0
	for k: int in range(32):
		var at: Vector2 = Gaze.inside(white, pupil, Vector2.from_angle(TAU * k / 32.0) * 3.0)
		if pow(at.x / (white.x - pupil), 2.0) + pow(at.y / (white.y - pupil), 2.0) > 1.0001:
			outside += 1
	_check("a pupil never leaves its eye, however far it looks (%d out)" % outside, outside == 0)
	_check("a pupil looking nowhere sits in the middle", Gaze.inside(white, pupil, Vector2.ZERO) == Vector2.ZERO)
	var target: Vector2 = Vector2(0.0, 0.25)
	var left: Vector2 = Gaze.pupil_for_point(Vector2(-0.27, -0.1), white, pupil, target) - Vector2(-0.27, -0.1)
	var right: Vector2 = Gaze.pupil_for_point(Vector2(0.27, -0.1), white, pupil, target) - Vector2(0.27, -0.1)
	_check("eyes on something close turn toward each other", left.x > 0.0 and right.x < 0.0)
	_check("a far look reaches further than a near one", Gaze.toward(Vector2(5, 0)).x > Gaze.toward(Vector2(0.5, 0)).x)
	for dt: float in [1.0 / 60.0, 0.5]:
		var g: Gaze = Gaze.new()
		var most: float = 0.0
		for i: int in range(int(1.0 / dt) + 1):
			g.step(Vector2(1, 0), dt)
			most = maxf(most, g.at.x)
		_check("a look settles without overshooting at %d ms a frame (peak %.4f)" % [int(dt * 1000.0), most],
			most <= 1.0001 and g.at.x > 0.99)
	var quick: Gaze = Gaze.new()
	for i: int in range(12):
		quick.step(Vector2(1, 0), 1.0 / 60.0)
	_check("a glance is most of the way there in a fifth of a second", quick.at.x > 0.9)

func _test_mood() -> void:
	var m: Mood = Mood.new(3)
	m.bump()
	m.worry(true)
	m.moving(Vector2(60, 0), 0.5)
	m.fall()
	_check("a fall shows over worry, a bump and rolling", m.resolve() == Mood.Feel.FALL)
	m.reset()
	m.worry(true)
	m.bump()
	_check("worry shows over a bump", m.resolve() == Mood.Feel.WORRY)
	m.reset()
	for i: int in range(18):
		m.moving(Vector2(50, 0), 1.0 / 60.0)
		m.step(1.0 / 60.0)
	_check("rolling widens the eyes and looks ahead", m.feel == Mood.Feel.ROLL and m.wide > 1.1 and m.look.x > 0.5)
	for i: int in range(40):
		m.moving(Vector2.ZERO, 1.0 / 60.0)
		m.step(1.0 / 60.0)
	_check("and at rest the face settles", m.feel == Mood.Feel.IDLE and m.wide < 1.03)
	var startled: Mood = Mood.new(4)
	startled.bump()
	startled.surprise()
	for i: int in range(12):
		startled.step(1.0 / 60.0)
	_check("a bounce startles a marble over its bump: eyes wide, brows up, mouth round",
		startled.feel == Mood.Feel.SURPRISE and startled.wide > 1.2 and startled.brow > 0.5 and startled.gape > 0.4)
	for i: int in range(60):
		startled.step(1.0 / 60.0)
	_check("and the surprise passes", startled.feel == Mood.Feel.IDLE)
	var squint: Mood = Mood.new(5)
	squint.bump()
	for i: int in range(4):
		squint.step(1.0 / 60.0)
	var shut: float = squint.open
	for i: int in range(40):
		squint.step(1.0 / 60.0)
	_check("a bump squints and the eyes open again (%.2f then %.2f)" % [shut, squint.open], shut < 0.4 and squint.open > 0.9)
	var blinks: int = 0
	var idle: Mood = Mood.new(7)
	var was_open: bool = true
	for i: int in range(60 * 30):
		idle.step(1.0 / 60.0)
		if was_open and idle.open < 0.2:
			blinks += 1
		was_open = idle.open >= 0.2
	_check("a face at rest blinks every few seconds (%d in 30 s)" % blinks, blinks >= 6 and blinks <= 16)
	var home: Mood = Mood.new(1)
	home.home()
	for i: int in range(12):
		home.step(1.0 / 60.0)
	_check("going home shuts the eyes happily and smiles", home.happy > 0.9 and home.smile > 0.8)
	var lengths: Array[float] = []
	for shown: int in range(5):
		lengths.append(Mood.memorial_length(shown))
	_check("the first memorials of a session play in full, and later ones shorter", lengths[0] == lengths[2]
		and lengths[3] < lengths[2] and lengths[4] == lengths[3] and lengths[0] <= 1.2)

func _test_spin() -> void:
	var top: Vector3 = Vector3(0, 0, 1)
	_check("rolling right turns the top of the ball right", (Spin.roll(Basis.IDENTITY, Vector2(5, 0), 10.0, 1.0) * top).x > 0.4)
	_check("rolling down the screen turns it down", (Spin.roll(Basis.IDENTITY, Vector2(0, 5), 10.0, 1.0) * top).y > 0.4)
	var quarter: Vector3 = Spin.roll(Basis.IDENTITY, Vector2(PI * 0.5 * 10.0, 0), 10.0, 1.0) * top
	_check("rolling a quarter of the way round brings the top to the edge", quarter.distance_to(Vector3(1, 0, 0)) < 0.001)
	var turned: Basis = Basis.IDENTITY
	for i: int in range(500):
		turned = Spin.roll(turned, Vector2(3, 2), 10.0)
	_check("a long roll stays a rotation", absf(turned.determinant() - 1.0) < 0.001
		and absf((turned * top).length() - 1.0) < 0.001)
	_check("rolling right along a bar seen from the side turns clockwise",
		(Spin.roll_side(Basis.IDENTITY, 2.0, 10.0) * Vector3(1, 0, 0)).y > 0.0)
	var img: Image = Spin.light(64)
	var middle: Color = img.get_pixel(32, 32)
	var near: Color = img.get_pixel(18, 16)
	var far: Color = img.get_pixel(46, 47)
	_check("the light leaves a ball's middle near its own colour", middle.a < 0.08)
	_check("and lightens the side facing the light", near.r > 0.9 and near.a > 0.1)
	_check("and darkens the far side", far.r < 0.1 and far.a > 0.2)
	_check("and nothing outside the ball", img.get_pixel(1, 1).a == 0.0 and img.get_pixel(62, 2).a == 0.0)

func _test_cast() -> void:
	var names: Dictionary = {}
	var short: bool = true
	for k: int in range(Cast.CAST.size()):
		var who: Cast.Who = Cast.of(k)
		names[who.name] = true
		short = short and who.name.length() <= 5 and who.name.length() >= 3 and not who.name.contains(";")
	_check("four characters, one for each colour, with short names of their own", Cast.CAST.size() == 4
		and names.size() == 4 and short)
	_check("the teal marble is Steve", Cast.of(1).name == "Steve" and Palette.LIGHT["marbles"][1] == Color("22b5a6"))
	_check("a stone is a rock with no name", Cast.of(TiltBoard.STONE).mark == Cast.Mark.ROCK and Cast.of(TiltBoard.STONE).name == "")
	_check("a colour past the fourth wraps round to a character", Cast.of(5) == Cast.of(1))

## A finished chapter's moment counts through the level numbers a player sees, Hard's own included, and lands on the
## chapter's. Loaded, since the party uses autoloads, which a test script cannot name when it compiles.
func _test_chapter_ticks() -> void:
	var celebration: GDScript = load("res://scenes/celebrate/celebration.gd")
	var pack: Node = root.get_node("Pack")
	var count: int = int((pack.get("chapters") as Array)[0]["count"])
	var main: PackedInt32Array = celebration.call("ticks", 0)
	_check("chapter 1's moment counts 1 to %d and lands on 1" % count, main.size() == count + 1 and main[0] == 1
		and main[count - 1] == count and main[count] == 1)
	var last: int = (pack.get("chapters") as Array).size() - 1
	var end: PackedInt32Array = celebration.call("ticks", last)
	_check("the last main chapter counts up to the last level and lands on its own number",
		end[end.size() - 2] == pack.call("count") and end[end.size() - 1] == last + 1)
	if int(pack.get("hard_from")) <= 0:
		return
	pack.call("use", 1)
	var hard: PackedInt32Array = celebration.call("ticks", pack.call("chapter_of", pack.get("hard_from")))
	pack.call("use", 0)
	_check("Hard's first chapter counts its own levels from 1 and lands on its chapter 1", hard[0] == 1
		and hard[hard.size() - 2] == hard.size() - 1 and hard[hard.size() - 1] == 1)

func _test_star_notes() -> void:
	var audio: GDScript = load("res://autoload/audio.gd")
	var notes: Array[float] = []
	for k: int in range(3):
		notes.append(audio.call("star_pitch", 1.0 + 0.08 * k))
	_check("the three stars climb the chord: E, G, then C", is_equal_approx(notes[0], 0.8409) and is_equal_approx(notes[1], 1.0)
		and is_equal_approx(notes[2], 1.3348))
	_check("any other pitch for a star is kept", is_equal_approx(audio.call("star_pitch", 0.9), 0.9))

func _test_wall_animals() -> void:
	var themes: GDScript = load("res://kit/ui/themes.gd")
	var short: PackedStringArray = PackedStringArray()
	var palettes: Array[Dictionary] = [{}]
	for id: String in themes.call("ids"):
		palettes.append({"id": id})
	for entry: Dictionary in palettes:
		for dark: bool in [false, true]:
			var t: Dictionary = {} if entry.is_empty() else themes.call("colours", entry["id"], dark)
			if entry.is_empty() or t.is_empty():
				Brand.use(dark)
			else:
				Brand.use_theme(t, dark)
			for family: int in range(Litter.Family.size()):
				for coat: int in range(Litter.Coat.size()):
					var fur: Color = Litter.fur(coat as Litter.Coat, family as Litter.Family, Palette.WALL, Palette.TILE)
					var ratio: float = _contrast(fur, Palette.TILE)
					if ratio < 2.0:
						short.append("%s %s %d %d: %.1f" % [entry.get("id", "plumb"), "dark" if dark else "light", family, coat, ratio])
	Brand.use(Brand.NATIVE_DARK)
	_check("every animal's coat reads as a wall on the floor, in every theme (short: %s)" % ", ".join(short), short.is_empty())
	_check("cats and dogs take turns level by level", Litter.family_for(0) == Litter.Family.CAT
		and Litter.family_for(1) == Litter.Family.DOG and Litter.family_for(2) == Litter.Family.CAT)
	var coats: Dictionary = {}
	for cell: int in range(36):
		coats[Litter.coat_for(cell, 7)] = true
	_check("a board's walls wear a mix of coats (%d of %d)" % [coats.size(), Litter.Coat.size()], coats.size() >= 4)

## A bouncy block reads on the floor in every theme, light and dark, and never as a marble of any look.
func _test_jelly_reads() -> void:
	var themes: GDScript = load("res://kit/ui/themes.gd")
	var short: PackedStringArray = PackedStringArray()
	var palettes: Array[Dictionary] = [{}]
	for id: String in themes.call("ids"):
		palettes.append({"id": id})
	for entry: Dictionary in palettes:
		for dark: bool in [false, true]:
			var t: Dictionary = {} if entry.is_empty() else themes.call("colours", entry["id"], dark)
			if entry.is_empty() or t.is_empty():
				Brand.use(dark)
			else:
				Brand.use_theme(t, dark)
			var ratio: float = _contrast(Palette.JELLY, Palette.TILE)
			if ratio < JELLY_CONTRAST:
				short.append("%s %s: %.1f" % [entry.get("id", "plumb"), "dark" if dark else "light", ratio])
	Brand.use(Brand.NATIVE_DARK)
	_check("a bouncy block reads on the floor in every theme (short: %s)" % ", ".join(short), short.is_empty())
	var close: PackedStringArray = PackedStringArray()
	for jelly: Color in [Palette.LIGHT["jelly"], Palette.DARK["jelly"]]:
		for id: String in GameLooks.SETS:
			for marble: Color in GameLooks.swatch(id):
				if _hue_gap(jelly, marble) < JELLY_HUE_GAP:
					close.append("%s %s" % [id, marble.to_html(false)])
	_check("and its hue is no marble's, in any look (close: %s)" % ", ".join(close), close.is_empty())

## Walls are plain blocks unless Pets is on, and turning it on mid-level makes them animals at once.
func _test_walls_follow_pets() -> void:
	var save: Node = root.get_node("Save")
	var fresh: Node = (load("res://autoload/save.gd") as GDScript).new()
	_check("a new player starts with faces and plain walls", bool(fresh.get("faces")) and not bool(fresh.get("pets")))
	fresh.free()
	var old_pets: bool = save.get("pets")
	var old_path: String = save.get("path")
	save.set("path", "user://test_pets.cfg")
	save.set("pets", false)
	var b: TiltBoard = TiltBoard.create(3, 3)
	b.cells[b.index(Vector2i(1, 1))] = TiltBoard.Cell.WALL
	b.add_marble(Vector2i(0, 0), 0)
	var view: Node2D = (load("res://scenes/game/board_view.gd") as GDScript).new()
	root.add_child(view)
	view.call("show_board", b, Vector2(400, 400))
	_check("walls are plain blocks by default", view.find_children("*", "Loaf", false, false).is_empty())
	save.call("set_pets", true)
	_check("and sleeping animals once Pets is on", view.find_children("*", "Loaf", false, false).size() == 1)
	save.call("set_pets", false)
	await process_frame
	_check("and plain again when it goes off", view.find_children("*", "Loaf", false, false).is_empty())
	view.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pets.cfg"))
	save.set("path", old_path)
	save.set("pets", old_pets)
	await process_frame

## The view draws the board the tilt led to, so a cracked cell shows as the pit it became.
func _test_board_follows_tilt() -> void:
	var b: TiltBoard = TiltBoard.create(4, 1)
	b.set_tile(Vector2i(1, 0), TiltBoard.Tile.CRACK)
	b.add_marble(Vector2i(0, 0), 0)
	# Loaded, not named: the view uses autoloads, which a test script cannot name when it compiles.
	var view: Node2D = (load("res://scenes/game/board_view.gd") as GDScript).new()
	root.add_child(view)
	view.call("show_board", b, Vector2(400, 200))
	var next: TiltBoard = b.copy()
	var move: TiltMove = next.tilt(TiltBoard.RIGHT)
	await view.call("play", move, next)
	var shown: TiltBoard = view.get("board")
	_check("after a tilt the view draws the board it led to", shown == next and shown.cells[1] == TiltBoard.Cell.PIT)
	view.queue_free()
	await process_frame

static func _hue_gap(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h)
	return minf(d, 1.0 - d)

func _test_chapter_colours() -> void:
	var themes: GDScript = load("res://kit/ui/themes.gd")
	var appearance: GDScript = load("res://kit/ui/appearance.gd")
	var style: GDScript = load("res://kit/ui/chapter_style.gd")
	var was: bool = appearance.get("dark")
	var chapters: int = TiltGenerator.chapter_list().size()
	var short: PackedStringArray = PackedStringArray()
	var close: PackedStringArray = PackedStringArray()
	for id: String in themes.call("ids"):
		for dark: bool in [false, true]:
			var t: Dictionary = themes.call("colours", id, dark)
			if t.is_empty():
				Brand.use(dark)
			else:
				Brand.use_theme(t, dark)
			appearance.set("dark", dark)
			for chapter: int in range(chapters):
				var tint: Color = style.call("tint", chapter)
				var worst: float = minf(_contrast(tint, Brand.BG), _contrast(tint, Brand.SURFACE))
				if worst < 3.0:
					short.append("%s %s %d: %.1f" % [id, "dark" if dark else "light", chapter + 1, worst])
				var next: Color = style.call("tint", chapter + 1)
				var apart: float = absf(tint.ok_hsl_h - next.ok_hsl_h)
				if minf(apart, 1.0 - apart) < 0.25:
					close.append("%s %d" % [id, chapter + 1])
	_check("every chapter's colour reads on the background and on a card (short: %s)" % ", ".join(short), short.is_empty())
	_check("the next chapter's colour is always a different hue (close: %s)" % ", ".join(close), close.is_empty())
	var hues: Array[float] = []
	for chapter: int in range(chapters):
		hues.append(snappedf((style.call("tint", chapter) as Color).ok_hsl_h, 0.005))
	var distinct: Dictionary = {}
	for hue: float in hues:
		distinct[hue] = true
	_check("no two chapters share a hue", distinct.size() == chapters)
	appearance.set("dark", was)
	Brand.use(Brand.NATIVE_DARK)

static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _test_saved_settings() -> void:
	var save: Node = root.get_node("Save")
	var real: String = save.get("path")
	var old_theme: int = save.get("theme")
	var old_seen: bool = save.get("tutorial_seen")
	save.set("path", "user://test_settings.cfg")
	save.set("theme", 2)
	save.set("tutorial_seen", true)
	save.call("store")
	save.set("theme", 0)
	save.set("tutorial_seen", false)
	save.call("restore")
	_check("the theme is saved", int(save.get("theme")) == 2)
	_check("a seen guide stays seen", bool(save.get("tutorial_seen")))
	var old_faces: bool = save.get("faces")
	var old_pets: bool = save.get("pets")
	save.set("faces", false)
	save.set("pets", true)
	save.call("store")
	save.set("faces", true)
	save.set("pets", false)
	save.call("restore")
	_check("faces turned off stay off", not bool(save.get("faces")))
	_check("pets turned on stay on", bool(save.get("pets")))
	var older: ConfigFile = ConfigFile.new()
	older.set_value("settings", "theme", 1)
	older.save("user://test_settings.cfg")
	save.call("restore")
	_check("a player from before faces gets them", bool(save.get("faces")))
	_check("and plain walls, since pets are for those who ask", not bool(save.get("pets")))
	save.set("faces", old_faces)
	save.set("pets", old_pets)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	save.set("path", real)
	save.set("theme", old_theme)
	save.set("tutorial_seen", old_seen)

func _test_guide_and_ending() -> void:
	var coach: GDScript = load("res://kit/ui/coach.gd")
	var finale: GDScript = load("res://kit/shell/finale.gd")
	var save: Node = root.get_node("Save")
	var old_seen: bool = save.get("tutorial_seen")
	var old_stars: PackedByteArray = save.get("stars")
	save.set("tutorial_seen", false)
	_check("level 1 opens with the guide", coach.call("due", 0))
	_check("no other level does", not coach.call("due", 1))
	save.set("tutorial_seen", true)
	_check("a seen guide does not come back by itself", not coach.call("due", 0))
	coach.set("requested", true)
	_check("settings can ask for it again", coach.call("due", 0))
	coach.set("enabled", false)
	_check("tools can turn it off", not coach.call("due", 0))
	coach.set("enabled", true)
	coach.set("requested", false)
	var pack: Node = root.get_node("Pack")
	var old_levels: Array[Dictionary] = pack.get("levels")
	var three: Array[Dictionary] = [{}, {}, {}]
	pack.set("levels", three)
	var last: int = 2
	save.set("stars", PackedByteArray())
	_check("the last level ends nothing while others are unsolved", not finale.call("due", last))
	save.set("stars", PackedByteArray([1, 3, 0]))
	_check("solving the last unsolved level ends the game", finale.call("due", last))
	save.set("stars", PackedByteArray([1, 0, 2]))
	_check("wherever it sits", finale.call("due", 1) and not finale.call("due", 0))
	save.set("stars", PackedByteArray([1, 3, 2]))
	_check("replaying with every level solved does not", not finale.call("due", last))
	save.set("stars", old_stars)
	save.set("tutorial_seen", old_seen)
	pack.set("levels", old_levels)

func _test_banner_pacing() -> void:
	_check("no banner before any level is solved", not AdPacing.banner_due(0, false))
	_check("no banner with two levels solved", not AdPacing.banner_due(AdPacing.BANNER_AFTER - 1, false))
	_check("the banner comes with the third solve", AdPacing.banner_due(AdPacing.BANNER_AFTER, false))
	_check("and stays", AdPacing.banner_due(119, false))
	_check("never for a Supporter", not AdPacing.banner_due(119, true))
	_check("the banner waits for 3 solves", AdPacing.BANNER_AFTER == 3)

# The spec's numbers, then each rule on its edge with every other rule satisfied.
func _test_interstitial_pacing() -> void:
	_check("the between-level pacing is 12 solves, every 4, 4 minutes apart, 3 minutes in",
		AdPacing.INTERSTITIAL_AFTER == 12 and AdPacing.INTERSTITIAL_EVERY == 4
		and is_equal_approx(AdPacing.FULLSCREEN_GAP, 240.0) and is_equal_approx(AdPacing.LAUNCH_GAP, 180.0))
	var ok: Callable = func(solved: int, since: int, now: float, last: float) -> bool:
		return AdPacing.interstitial_due(solved, since, now, last, false)
	_check("due once every rule is met", ok.call(12, 4, 180.0, -1.0))
	_check("never before 12 levels are solved", not ok.call(11, 40, 9999.0, -1.0))
	_check("never before 4 solves this session", not ok.call(60, 3, 9999.0, -1.0))
	_check("due on the fourth solve", ok.call(60, 4, 9999.0, -1.0))
	_check("never in the first 3 minutes after launch", not ok.call(60, 9, 179.9, -1.0))
	_check("due at 3 minutes", ok.call(60, 9, 180.0, -1.0))
	_check("never within 4 minutes of a full-screen ad", not ok.call(60, 9, 1000.0, 1000.0 - 239.9))
	_check("due 4 minutes after one", ok.call(60, 9, 1000.0, 1000.0 - 240.0))
	_check("never for a Supporter", not AdPacing.interstitial_due(60, 9, 9999.0, -1.0, true))
	_check("never in the player's first launch", not AdPacing.interstitial_due(60, 9, 9999.0, -1.0, false, true))
	_check("only right after a win", not AdPacing.interstitial_due(60, 9, 9999.0, -1.0, false, false, false))
	_check("never while a misbehaving ad paused them",
		not AdPacing.interstitial_due(60, 9, 9999.0, -1.0, false, false, true, true))
	_check("a misbehaving ad pauses them for a day", AdPacing.TROUBLE_PAUSE_HOURS == 24)
	_check("the gap after any full-screen ad is at least 3 minutes", AdPacing.FULLSCREEN_GAP >= 180.0)
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var old_state: String = ads.get("state_path")
	var old_first: bool = ads.get("first_session")
	ads.set("state_path", "user://test_ads_state.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ads.get("state_path")))
	_check("the first launch is counted as the first", ads.call("count_launch") == 1)
	_check("and the next as the second", ads.call("count_launch") == 2)
	_check("nothing is paused at first", not ads.call("interstitials_paused"))
	ads.call("pause_interstitials")
	_check("a pause holds", ads.call("interstitials_paused"))
	var state: ConfigFile = ConfigFile.new()
	state.load(ads.get("state_path"))
	var until: int = int(state.get_value("pacing", "interstitials_from", 0)) - int(Time.get_unix_time_from_system())
	_check("for 24 hours, kept across launches (%d s)" % until, absi(until - 24 * 3600) <= 5)
	state.set_value("pacing", "interstitials_from", int(Time.get_unix_time_from_system()) - 1)
	state.save(ads.get("state_path"))
	_check("and ends after them", not ads.call("interstitials_paused"))
	ads.set("first_session", false)
	var bus: Node = root.get_node("EventBus")
	ads.call("start")
	bus.emit_signal(&"level_started", 20)
	_check("a level started and not won is no time for one", not ads.get("_won_last"))
	bus.emit_signal(&"level_won", 20, 9, 3)
	_check("a won one is", ads.get("_won_last"))
	ads.set("_last_fullscreen", -1.0)
	ads.call("note_purchase")
	_check("a purchase sheet counts as a full-screen moment",
		float(ads.get("_last_fullscreen")) >= 0.0 and int(ads.get("_since")) == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ads.get("state_path")))
	ads.set("state_path", old_state)
	ads.set("first_session", old_first)

func _test_hint_pacing() -> void:
	_check("the first 15 levels have free hints, then 3 a day",
		AdPacing.FREE_HINT_LEVELS == 15 and AdPacing.DAILY_HINTS == 3)
	_check("level 1's hints are free however many are used", AdPacing.hint_cost(0, 99, false) == AdPacing.Hint.FREE)
	_check("level 15's too", AdPacing.hint_cost(14, 99, false) == AdPacing.Hint.FREE)
	_check("level 16 draws on the day's allowance", AdPacing.hint_cost(15, 0, false) == AdPacing.Hint.ALLOWANCE)
	_check("the third free hint of the day is still free", AdPacing.hint_cost(40, 2, false) == AdPacing.Hint.ALLOWANCE)
	_check("the fourth asks for a video", AdPacing.hint_cost(40, 3, false) == AdPacing.Hint.VIDEO)
	_check("a video gives three hints: this one now and two more free today",
		AdPacing.hints_left(AdPacing.used_after_video(3)) == 2 and AdPacing.hint_cost(40, AdPacing.used_after_video(3), false) == AdPacing.Hint.ALLOWANCE)
	_check("a Supporter's hints are all free", AdPacing.hint_cost(40, 50, true) == AdPacing.Hint.FREE)
	_check("hints left count down to none", AdPacing.hints_left(0) == 3 and AdPacing.hints_left(2) == 1
		and AdPacing.hints_left(3) == 0 and AdPacing.hints_left(7) == 0)
	_check("today's hints count today", AdPacing.used_today("2026-09-30", 2, "2026-09-30") == 2)
	_check("yesterday's hints are forgotten at midnight", AdPacing.used_today("2026-09-29", 3, "2026-09-30") == 0)
	_check("a never-saved day counts none", AdPacing.used_today("", 3, "2026-09-30") == 0)

func _test_banner_size() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	_check("the banner is LevelPlay's 50 dp one", is_equal_approx(ads.get("BANNER_DP"), 50.0))
	var host: Node = Node.new()
	var view: Vector2 = root.get_visible_rect().size
	var window: Vector2 = Vector2(DisplayServer.window_get_size())
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var width_dp: float = window.x * 160.0 / dpi if dpi > 0.0 and window.x > 0.0 else ads.get("PREVIEW_WIDTH_DP")
	_check("its height in design pixels follows the screen's density",
		is_equal_approx(ads.call("banner_height", host), 50.0 * view.x / width_dp))
	host.free()

# LevelPlay's app keys are short hex strings and its ad unit ids 16 letters and digits. They ship in the app.
func _test_monetize_ids() -> void:
	var key: RegEx = RegEx.create_from_string("^[0-9a-f]{8,10}$")
	var unit: RegEx = RegEx.create_from_string("^[0-9a-z]{16}$")
	_check("the LevelPlay app key looks like one", key.search(GameMonetize.LEVELPLAY_APP_KEY) != null)
	var ids: Array[String] = [GameMonetize.LEVELPLAY_BANNER_ID, GameMonetize.LEVELPLAY_INTERSTITIAL_ID,
		GameMonetize.LEVELPLAY_REWARDED_ID]
	for id: String in ids:
		_check("%s is a LevelPlay ad unit id" % id, unit.search(id) != null)
	_check("each format has its own ad unit", ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	_check("ads are on", GameMonetize.ADS)
	_check("the Unity Ads placements are bidding ones, for LevelPlay to fill",
		Array(GameMonetize.UNITY_PLACEMENTS).all(func(p: String) -> bool: return p.begins_with("BP_")))
	_check("the Supporter pack is the product 'supporter'", GameMonetize.SUPPORTER_ID == "supporter")
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	_check("LevelPlay runs where it is on, in the build and has a key",
		ads.call("network_ads", true, true, "29be3810d", false))
	_check("a debug build needs no key, since it asks LevelPlay's demo app", ads.call("network_ads", true, true, "", true))
	_check("a release build without a key shows the house banner", not ads.call("network_ads", true, true, "", false))
	_check("so does a build without the plugin", not ads.call("network_ads", true, false, "29be3810d", true))
	_check("and ads switched off", not ads.call("network_ads", false, true, "29be3810d", false))

func _test_presets_and_plugins() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_check("the Intermission plugin is enabled", enabled.has("res://addons/intermission/plugin.cfg"))
	_check("and the AdMob one is gone", not enabled.has("res://addons/admob/plugin.cfg")
		and not DirAccess.dir_exists_absolute("res://addons/admob"))
	_check("the Play billing plugin is enabled", enabled.has("res://addons/GodotGooglePlayBilling/plugin.cfg"))
	var export_plugin: GDScript = load("res://addons/intermission/export_plugin.gd")
	for debug: bool in [true, false]:
		var aar: String = export_plugin.call("library", debug)
		_check("res://addons/%s is in place, so no build downloads it" % aar,
			FileAccess.file_exists("res://addons/".path_join(aar)))
	_check("the Firebase plugins are enabled", enabled.has("res://addons/godotx_firebase/plugin.cfg")
		and enabled.has("res://addons/firebase_build/plugin.cfg"))
	_check("the Play Core plugin is enabled, with the Java helper it builds in",
		enabled.has("res://addons/play_core/plugin.cfg") and FileAccess.file_exists("res://addons/play_core/PlayCore.java"))
	_check("the Analytics User plugin is enabled, with the Java helper it builds in",
		enabled.has("res://addons/analytics_user/plugin.cfg")
		and FileAccess.file_exists("res://addons/analytics_user/AnalyticsUser.java"))
	_check("the shrink plugin is enabled, so release builds run R8", enabled.has("res://addons/shrink_build/plugin.cfg"))
	_check("the Play Games plugin is enabled", enabled.has("res://addons/play_games/plugin.cfg"))
	for module: String in ["firebase_core", "firebase_analytics"]:
		for build: String in ["release", "debug"]:
			var aar: String = "res://android/%s/%s.%s.aar" % [module, module, build]
			_check("%s is in place" % aar, FileAccess.file_exists(aar))
	var presets: ConfigFile = ConfigFile.new()
	_check("export_presets.cfg reads", presets.load("res://export_presets.cfg") == OK)
	for section: String in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "platform"):
			continue
		var preset_name: String = presets.get_value(section, "name")
		var exclude: String = presets.get_value(section, "exclude_filter", "")
		if presets.get_value(section, "platform") == "Android":
			var options: String = section + ".options"
			_check("%s may use the network" % preset_name, bool(presets.get_value(options, "permissions/internet", false)))
			_check("%s builds with Gradle, which the plugins need" % preset_name,
				bool(presets.get_value(options, "gradle_build/use_gradle_build", false)))
			_check("%s leaves the Intermission editor scripts out" % preset_name,
				exclude.contains("addons/intermission/intermission_plugin.gd")
				and exclude.contains("addons/intermission/export_plugin.gd"))
			# Android's own backup carries user:// to the player's next install, so progress survives a reinstall.
			_check("%s lets Android back up the save" % preset_name, bool(presets.get_value(options, "user_data_backup/allow", false)))
			_check("%s builds Firebase Core and Analytics" % preset_name,
				bool(presets.get_value(options, "firebase/enable_core", false))
				and bool(presets.get_value(options, "firebase/enable_analytics", false)))
			_check("%s leaves Crashlytics and Messaging out" % preset_name,
				not bool(presets.get_value(options, "firebase/enable_crashlytics", true))
				and not bool(presets.get_value(options, "firebase/enable_messaging", true)))
			_check("%s starts Firebase with collection off" % preset_name,
				bool(presets.get_value(options, "firebase/privacy_safe_defaults", false)))
			_check("%s leaves the editor-only Firebase scripts out" % preset_name,
				exclude.contains("addons/godotx_firebase/*") and exclude.contains("addons/firebase_build/*"))
			_check("%s leaves the Play Core plugin's own files out" % preset_name, exclude.contains("addons/play_core/*"))
			_check("%s leaves the Analytics User plugin's own files out" % preset_name,
				exclude.contains("addons/analytics_user/*"))
			_check("%s leaves the shrink plugin out" % preset_name, exclude.contains("addons/shrink_build/*"))
			_check("%s leaves the Play Games plugin's own files out" % preset_name, exclude.contains("addons/play_games/*"))
		elif presets.get_value(section, "platform") == "Web":
			_check("the web build leaves the plugins out", exclude.contains("addons/*")
				and exclude.contains("kit/monetize/android/*"))
			_check("and the Firebase config, since the web build is public", exclude.contains("google-services.json"))

# The release workflow reads CHANGELOG.md by these rules, so a changelog it would refuse fails here first.
func _test_changelog() -> void:
	var top: Changelog.Entry = Changelog.parse(FileAccess.get_file_as_string(Changelog.PATH))
	_check("CHANGELOG.md's newest section can be released: %s" % top.error, top.error == "")
	_check("Settings and About show that section's version", top.version != "" and Changelog.version() == top.version)
	_check("project.godot keeps no second version",
		str(ProjectSettings.get_setting("application/config/version", "")) == "")
	var presets: ConfigFile = ConfigFile.new()
	presets.load("res://export_presets.cfg")
	for section: String in presets.get_sections():
		if presets.has_section_key(section, "include_filter"):
			_check("%s ships CHANGELOG.md" % presets.get_value(section, "name"),
				String(presets.get_value(section, "include_filter")).contains("CHANGELOG.md"))
			_check("%s ships the Play Games catalog and ids" % presets.get_value(section, "name"),
				String(presets.get_value(section, "include_filter")).contains("play_games.json")
				and String(presets.get_value(section, "include_filter")).contains("kit/play_games/catalog.json"))
	var dated: Changelog.Entry = Changelog.parse("<!--\n## 9.9.9\n-->\n# Changelog\n\n## 1.2.3 - 2026-10-01\n\n- One\n- Two\n\n## 1.2.2\n\n- Old\n")
	_check("a dated heading reads as its version, past a heading in a comment", dated.error == "" and dated.version == "1.2.3")
	_check("the section ends at the next heading", dated.notes == PackedStringArray(["One", "Two"]))
	_check("Play's text is one - line per note", dated.play_text() == "- One\n- Two")
	_check("1.2.3 is version code 10203 and 1.0.0 is 10000",
		dated.code == 10203 and Changelog.parse("## 1.0.0\n- A").code == 10000)
	_check("Play's text may be exactly its limit", Changelog.parse("## 1.0.0\n- " + "x".repeat(Changelog.PLAY_LIMIT - 2)).error == "")
	for bad: String in ["", "## Unreleased\n- A", "## 1.2\n- A", "## v1.2.3\n- A", "## 1.02.3\n- A", "## 1.100.0\n- A",
			"## 1.0.100\n- A", "## 0.0.0\n- A", "## 1.0.0\n", "## 1.0.0\n- A\n  wrapped", "## 1.0.0\n### Fixes\n- A",
			"## 1.0.0\n-\n", "## 1.0.0\n- " + "x".repeat(Changelog.PLAY_LIMIT - 1)]:
		_check("the release rules refuse \"%s\"" % bad.left(40).c_escape(), Changelog.parse(bad).error != "")

# The sheet is asked in the EEA, the UK and Switzerland, guessed from a European clock and a locale that agrees.
func _test_consent() -> void:
	var consent: GDScript = load("res://kit/monetize/consent.gd")
	var status: Dictionary = consent.get_script_constant_map()["Status"]
	for locale: String in ["de_DE", "en_GB", "fr_CH", "nb_NO", "sr_Latn_SI", "en_IE"]:
		_check("a phone set to %s on Central European time is asked" % locale, consent.call("needs", locale, 60))
	for locale: String in ["en_IN", "hi_IN", "en_US", "en_GB", "de_DE", "en"]:
		_check("a phone set to %s on Indian time is not asked" % locale, not consent.call("needs", locale, 330))
	_check("a European phone set to US English is asked by its clock", consent.call("needs", "en_US", 60))
	_check("so is one on Lisbon's winter clock", consent.call("needs", "en_US", 0))
	_check("and one whose locale names no country", consent.call("needs", "en", 120))
	_check("but not one on New York's", not consent.call("needs", "en_US", -300))
	_check("nor a South African phone on the same clock as Finland", not consent.call("needs", "en_ZA", 120))
	_check("a locale's region is read whatever its script", consent.call("country", "sr_Latn_RS") == "RS")
	_check("a locale with no region has none", consent.call("country", "en") == "")
	var old_path: String = consent.get("path")
	consent.set("path", "user://test_consent.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(consent.get("path")))
	_check("nothing is forced without the debug key", not consent.call("forced"))
	var forced: ConfigFile = ConfigFile.new()
	forced.set_value("debug", "force", true)
	forced.save(consent.get("path"))
	_check("a debug build can be made to ask anywhere", consent.call("required") and consent.call("forced"))
	_check("asked and not answered yet", consent.call("status") == status["UNKNOWN"])
	consent.call("answer", false)
	_check("a refusal is kept", consent.call("status") == status["DENIED"])
	consent.call("answer", true)
	_check("and so is a yes", consent.call("status") == status["GRANTED"])
	_check("Analytics counts where no consent is needed or the player said yes",
		consent.call("counts", status["NOT_REQUIRED"]) and consent.call("counts", status["GRANTED"]))
	_check("and nowhere else", not consent.call("counts", status["UNKNOWN"]) and not consent.call("counts", status["DENIED"]))
	var host: Node = Node.new()
	var sheet: Control = consent.call("ask", host, func() -> void: pass, false)
	var texts: PackedStringArray = []
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	_check("the sheet offers both answers alike and the policy (%s)" % ", ".join(texts),
		texts.has("Allow") and texts.has("Don't allow") and texts.has("Privacy policy"))
	_check("the launch sheet cannot be swiped away unanswered", not bool(sheet.get("dismissable")))
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(consent.get("path")))
	consent.set("path", old_path)

# Test ads on every phone that is not a player's: debug builds, and the tester switch, seven quick taps.
func _test_test_ads() -> void:
	var test_ads: GDScript = load("res://kit/monetize/test_ads.gd")
	var taps: int = test_ads.get("TAPS")
	var old_path: String = test_ads.get("path")
	test_ads.set("path", "user://test_ads.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_ads.get("path")))
	_check("a debug build asks for test ads", test_ads.call("test_mode"))
	_check("the switch starts off", not test_ads.call("tester"))
	var host: Node = Node.new()
	var flipped: int = 0
	for i: int in range(taps):
		if test_ads.call("tap", host):
			flipped += 1
	_check("seven quick taps turn the switch on", flipped == 1 and test_ads.call("tester"))
	for i: int in range(taps - 1):
		test_ads.call("tap", host)
	_check("six more do nothing yet", test_ads.call("tester"))
	test_ads.set("_last_tap", -10.0)
	test_ads.call("tap", host)
	_check("and a slow tap starts the count again", test_ads.call("tester"))
	for i: int in range(taps - 1):
		test_ads.call("tap", host)
	_check("seven more turn it off", not test_ads.call("tester"))
	host.free()
	var own: ConfigFile = ConfigFile.new()
	own.set_value("testing", "own_app", true)
	own.save(test_ads.get("path"))
	_check("a debug build on a registered test device can ask the game's own app", not test_ads.call("test_mode"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_ads.get("path")))
	test_ads.set("path", old_path)

# Counted where no consent is needed or the player said yes, never in a debug build. Levels reach Analytics
# numbered from 1, as players see them.
func _test_analytics() -> void:
	var analytics: GDScript = load("res://kit/monetize/analytics.gd")
	var status: Dictionary = (load("res://kit/monetize/consent.gd") as GDScript).get_script_constant_map()["Status"]
	_check("a release build counts where no consent is needed", analytics.counts(status["NOT_REQUIRED"], false))
	_check("and where the player said yes", analytics.counts(status["GRANTED"], false))
	_check("a debug build never counts", not analytics.counts(status["NOT_REQUIRED"], true))
	for state: String in ["UNKNOWN", "DENIED"]:
		_check("consent %s counts nothing" % state, not analytics.counts(status[state], false))
	_check("nothing is counted off Android", not analytics.counting())
	var heard: Array[Array] = []
	analytics.sink = func(event: StringName, params: Dictionary) -> void: heard.append([event, params])
	analytics.start()
	var bus: Node = root.get_node("EventBus")
	bus.emit_signal(&"level_started", 4)
	bus.emit_signal(&"level_won", 4, 9, 3)
	var lost: bool = bus.has_signal(&"level_failed")
	if lost:
		bus.emit_signal(&"level_failed", 4)
	analytics.sink = Callable()
	_check("each level event is heard once", heard.size() == (3 if lost else 2))
	if heard.size() < 2:
		return
	_check("a start is level_start with the level's number", heard[0][0] == &"level_start" and heard[0][1]["level"] == 5)
	_check("level and success reach GA as text, so their dimensions fill, and stars stay a number",
		analytics.for_ga({"level": 5, "success": 1, "stars": 3}) == {"level": "5", "success": "1", "stars": 3})
	var won: Dictionary = heard[1][1]
	_check("a win is a successful level_end with its stars", heard[1][0] == &"level_end" and won["level"] == 5
		and won["success"] == 1 and won["stars"] == 3 and won.has("seconds"))
	if lost and heard.size() == 3:
		_check("a loss is a failed level_end", heard[2][0] == &"level_end" and heard[2][1]["success"] == 0)
	# Plumb 2.0's level events (REVAMP_PLAN.md section 5.2): the board, its path and difficulty, the rating, the pick.
	heard.clear()
	analytics.sink = func(event: StringName, params: Dictionary) -> void: heard.append([event, params])
	analytics.set("level_context", {"board": "x-0042", "path": "street", "difficulty": 18.8567, "rating": 1544.6,
		"pick": "fit", "replay": "no"})
	bus.emit_signal(&"level_started", 40)
	analytics.set("solve_measures", {"moves": 13, "par": 12, "hints": 1, "undos": 2, "restarts": 0, "boosters": 1,
		"coins": 25})
	bus.emit_signal(&"level_won", 40, 13, 2)
	analytics.call("user_property", "rating_band", "1500")
	analytics.call("user_property", "rating_band", "1500")
	analytics.call("user_property", "furthest_level", "41")
	analytics.sink = Callable()
	var started: Dictionary = heard[0][1] if heard.size() > 0 else {}
	var ended: Dictionary = heard[1][1] if heard.size() > 1 else {}
	_check("a level's start carries its board, path, difficulty, the rating, the pick and whether it is a replay",
		started.get("board") == "x-0042" and started.get("path") == "street" and started.get("pick") == "fit"
		and started.get("replay") == "no" and started.get("level") == 41)
	_check("and its end how the solve went, without the pick", ended.get("moves") == 13 and ended.get("par") == 12
		and ended.get("hints") == 1 and ended.get("undos") == 2 and ended.get("coins") == 25
		and ended.get("board") == "x-0042" and not ended.has("pick")
		and (analytics.get("solve_measures") as Dictionary).is_empty())
	var sent: Dictionary = analytics.for_ga(started)
	_check("grouping parameters reach GA as text, the difficulty to hundredths and the rating whole",
		sent["board"] == "x-0042" and sent["level"] == "41" and sent["replay"] == "no"
		and is_equal_approx(float(sent["difficulty"]), 18.86) and sent["rating"] == 1545)
	var props: Array = heard.filter(func(e: Array) -> bool: return e[0] == &"user_property")
	_check("user properties are sent once a change, cut to GA's 36 characters", props.size() == 2
		and props[0][1] == {"rating_band": "1500"} and props[1][1] == {"furthest_level": "41"})
	analytics.set("level_context", {})

func _test_saved_monetization() -> void:
	var save: Node = root.get_node("Save")
	var real: String = save.get("path")
	var old: Array = [save.get("supporter"), save.get("hint_day"), save.get("hints_used"), save.get("stars"),
		save.get("owned"), save.get("tips"), save.get("look")]
	save.set("path", "user://test_monetize.cfg")
	save.set("supporter", true)
	save.set("hint_day", "2026-09-30")
	save.set("hints_used", 2)
	save.set("owned", PackedStringArray([GameMonetize.LEVELS_ID]))
	save.set("tips", 3)
	save.set("look", "gems")
	save.call("store")
	save.set("supporter", false)
	save.set("hint_day", "")
	save.set("hints_used", 0)
	save.set("owned", PackedStringArray())
	save.set("tips", 0)
	save.set("look", "")
	save.call("restore")
	_check("the Supporter pack is saved", bool(save.get("supporter")))
	_check("today's free hints are saved", String(save.get("hint_day")) == "2026-09-30" and int(save.get("hints_used")) == 2)
	_check("other purchases, tips and the look are saved", (save.get("owned") as PackedStringArray) == PackedStringArray([GameMonetize.LEVELS_ID])
		and int(save.get("tips")) == 3 and String(save.get("look")) == "gems")
	save.call("reset")
	save.call("restore")
	_check("resetting progress keeps every purchase and tip", bool(save.get("supporter"))
		and (save.get("owned") as PackedStringArray).size() == 1 and int(save.get("tips")) == 3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_monetize.cfg"))
	save.set("path", real)
	save.set("supporter", old[0])
	save.set("hint_day", old[1])
	save.set("hints_used", old[2])
	save.set("stars", old[3])
	save.set("owned", old[4])
	save.set("tips", old[5])
	save.set("look", old[6])

## The host stays outside the tree so nothing animates.
func _buttons(opener: GDScript, method: String = "open") -> PackedStringArray:
	var host: Node = Node.new()
	opener.call(method, host)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	return texts

func _test_settings_variants() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var settings: GDScript = load("res://kit/shell/settings.gd")
	var save: Node = root.get_node("Save")
	var old_supporter: bool = save.get("supporter")
	save.set("supporter", false)
	var plain: PackedStringArray = _labels(settings, "open")
	_check("settings offers the colours, the looks and a way to support the game", plain.has("Colours")
		and plain.has(GameLooks.TITLE) and plain.has("SUPPORT"))
	_check("and no privacy choices where no consent message asks for them", not plain.has("Privacy choices"))
	var consent: _ConsentAds = _ConsentAds.new()
	ads.call("use", consent)
	_check("privacy choices appear when the consent message requires them", _labels(settings, "open").has("Privacy choices"))
	save.set("supporter", true)
	var supporter: PackedStringArray = _labels(settings, "open")
	_check("a Supporter still finds a way to support the game", supporter.has("SUPPORT"))
	_check("but no privacy choices, since no ads load for them", not supporter.has("Privacy choices"))
	ads.call("use", null)
	save.set("supporter", old_supporter)

func _test_about_variants() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var about: GDScript = load("res://kit/shell/about.gd")
	var old: bool = supporter.get("on_play")
	supporter.set("on_play", true)
	var play: PackedStringArray = _buttons(about)
	_check("About on Google Play links to Privacy and Help", play.has("Privacy") and play.has("Help"))
	_check("and not to the website, which has sponsor links", not play.has("Website"))
	supporter.set("on_play", false)
	var web: PackedStringArray = _buttons(about)
	_check("About on the web links to the website and Privacy", web.has("Website") and web.has("Privacy") and not web.has("Help"))
	var more: String = load("res://kit/shell/more_games.gd").call("title")
	_check("About leads to the studio's other games on both", play.has(more) and web.has(more))
	var rate: String = load("res://kit/shell/rate_prompt.gd").call("button_text")
	_check("About on Google Play always offers a rating, and the web build does not", play.has(rate) and not web.has(rate))
	supporter.set("on_play", old)

## The homepage has a sponsor link, and Play does not let an app lead to one.
func _test_maker_link() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var about: GDScript = load("res://kit/shell/about.gd")
	var credits: GDScript = load("res://kit/shell/credits.gd")
	var old: bool = supporter.get("on_play")
	var studio: String = "https://shravangoswami.com/projects/studio/"
	supporter.set("on_play", true)
	_check("on Google Play the maker's name opens the studio page, which has no sponsor links",
		_name_link(about) == studio and _name_link(credits) == studio)
	supporter.set("on_play", false)
	_check("elsewhere it opens his homepage", _name_link(about) == "https://shravangoswami.com/"
		and _name_link(credits) == "https://shravangoswami.com/")
	supporter.set("on_play", old)

func _name_link(opener: GDScript) -> String:
	var host: Control = Control.new()
	root.add_child(host)
	opener.call("open", host)
	var uri: String = ""
	for b: Node in host.find_children("*", "LinkButton", true, false):
		if (b as LinkButton).text == "Shravan Goswami":
			uri = (b as LinkButton).uri
	host.free()
	return uri

# The ending says one short line, and the studio hears once when a player passes each milestone, never again
# on a replay, and once when every level is solved.
func _test_ending_line_and_milestones() -> void:
	var line: String = GameCredits.ENDING
	var regex: RegEx = RegEx.create_from_string("[0-9]")
	_check("the ending's line is short, ends with a full stop and names no count",
		line.length() > 0 and line.length() <= 22 and line.ends_with(".") and regex.search(line) == null)
	_check("the ending's motif is a Control that plays", ResourceLoader.exists("res://scenes/shell/ending_motif.gd")
		and (load("res://scenes/shell/ending_motif.gd") as GDScript).new().has_method("play"))
	var analytics: GDScript = load("res://kit/monetize/analytics.gd")
	var save: Node = root.get_node("Save")
	var pack: Node = root.get_node("Pack")
	var old_levels: Array[Dictionary] = pack.get("levels")
	var old_stars: PackedByteArray = save.get("stars")
	var old_sink: Callable = analytics.get("sink")
	var heard: Array[String] = []
	analytics.set("sink", func(name: StringName, _params: Dictionary) -> void:
		if String(name).begins_with("solved_"):
			heard.append(String(name)))
	var levels: Array[Dictionary] = []
	for i: int in range(320):
		levels.append({})
	pack.set("levels", levels)
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(320)
	for i: int in range(299):
		stars[i] = 1
	save.set("stars", stars)
	analytics.call("_on_started", 299)
	stars[299] = 2
	save.set("stars", stars)
	analytics.call("_on_won", 299, 0, 2)
	_check("the 300th solve sends solved_300 (%s)" % [heard], heard == ["solved_300"])
	analytics.call("_on_started", 299)
	analytics.call("_on_won", 299, 0, 3)
	_check("a replay sends nothing", heard.size() == 1)
	for i: int in range(320):
		stars[i] = 1
	stars[5] = 0
	save.set("stars", stars)
	analytics.call("_on_started", 5)
	stars[5] = 1
	save.set("stars", stars)
	analytics.call("_on_won", 5, 0, 1)
	_check("the last unsolved level sends solved_all", heard.size() == 2 and heard[1] == "solved_all")
	analytics.set("sink", old_sink)
	pack.set("levels", old_levels)
	save.set("stars", old_stars)

func _test_daily_calendar() -> void:
	var edge: int = int(Time.get_unix_time_from_datetime_string("2026-10-21T06:59:59"))
	_check("the daily turns over at midnight UTC-7, with Play Games' daily leaderboards",
		DailyDays.index(edge + 1) == DailyDays.index(edge) + 1 and DailyDays.left(edge) == 1)
	var day: int = DailyDays.from_date("2026-10-21")
	_check("a day's number and its date agree", day == DailyDays.index(edge + 1) and DailyDays.short(day) == "21 October"
		and DailyDays.long(day) == "Wednesday, 21 October")
	var leap: int = DailyDays.from_date("2028-02-10")
	_check("months start and end on the right days", DailyDays.month_start(leap) == DailyDays.from_date("2028-02-01")
		and DailyDays.month_length(leap) == 29 and DailyDays.month_length(DailyDays.from_date("2026-12-31")) == 31
		and DailyDays.month_name(day) == "October 2026")
	_check("times read as a clock", DailyDays.clock(83000) == "1:23" and DailyDays.clock(3723000) == "1:02:03"
		and DailyDays.clock(999) == "0:00")
	_check("a wait reads in hours and minutes", DailyDays.wait(11520) == "3 h 12 min" and DailyDays.wait(30) == "1 min")
	var run: Dictionary = {10: true, 11: true, 12: true, 14: true}
	_check("a streak runs back from today, or from yesterday while today is open",
		DailyDays.streak(run, 14) == 1 and DailyDays.streak(run, 13) == 3 and DailyDays.streak(run, 15) == 1)
	_check("and ends once a whole day goes by unsolved", DailyDays.streak(run, 16) == 0)
	_check("the longest run is found anywhere", DailyDays.longest(run) == 3 and DailyDays.longest({}) == 0)

func _test_daily_records() -> void:
	var daily: GDScript = load("res://kit/daily/daily.gd")
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("path"), save.get("daily"), save.get("owned"), save.get("supporter")]
	save.set("path", "user://test_daily.cfg")
	save.set("daily", {})
	save.set("owned", PackedStringArray())
	save.set("supporter", false)
	var today: int = daily.call("today")
	var first: Dictionary = daily.call("record", today, 61000)
	_check("today's first solve is on time and kept", bool(first["first"]) and bool(first["on_time"])
		and int(daily.call("time_of", today)) == 61000)
	var again: Dictionary = daily.call("record", today, 30000)
	_check("a replay keeps the first time", not bool(again["first"]) and int(again["best_ms"]) == 61000)
	var late: Dictionary = daily.call("record", today - 1, 90000)
	_check("a past day solved now is late", bool(late["first"]) and not bool(late["on_time"]) and daily.call("late", today - 1))
	_check("and a late solve does not hold the streak", int(daily.call("streak")) == 1 and int(daily.call("solves")) == 2)
	save.call("restore")
	_check("the record survives a restart", int(daily.call("time_of", today)) == 61000 and daily.call("late", today - 1))
	daily.call("keep_time", today - 3, 12000)
	_check("time spent on an unsolved day is kept", int(daily.call("spent", today - 3)) == 12000)
	daily.call("record", today - 3, 20000)
	_check("and dropped once it is solved", int(daily.call("spent", today - 3)) == 0)
	_check("with no ads to show, every past day plays free", daily.call("plays_free", today - 5))
	ads.call("use", _VideoAds.new())
	_check("with ads a past day waits for a video, and today never does", not daily.call("plays_free", today - 5)
		and daily.call("plays_free", today) and daily.call("plays_free", today - 1))
	daily.call("open_day", today - 5)
	_check("a day a video opened stays open", daily.call("plays_free", today - 5))
	save.set("supporter", true)
	_check("the Supporter pack, with no ads, opens every past day", daily.call("plays_free", today - 9))
	save.set("supporter", false)
	ads.call("use", null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_daily.cfg"))
	save.set("path", old[0])
	save.set("daily", old[1])
	save.set("owned", old[2])
	save.set("supporter", old[3])

func _test_streak_keeping() -> void:
	var daily: GDScript = load("res://kit/daily/daily.gd")
	var shop: GDScript = load("res://kit/monetize/shop.gd")
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("path"), save.get("daily"), supporter.get("on_play"), daily.get("skew")]
	save.set("path", "user://test_keep.cfg")
	# Well after the bank's first day, so a whole week back is there to keep.
	daily.set("skew", 60 * DailyDays.DAY)
	var today: int = daily.call("today")
	save.set("daily", {"times": {today - 3: 50000, today - 2: 40000}})
	_check("a missed day after a run can be kept, and none before the first day that counts",
		daily.call("keepable") == PackedInt32Array([today - 1]) and int(daily.call("streak")) == 0)
	daily.call("keep_day", today - 1, "video")
	_check("a kept day joins the run", int(daily.call("streak")) == 3 and daily.call("kept", today - 1)
		and (daily.call("keepable") as PackedInt32Array).is_empty())
	save.set("daily", {"times": {today - 9: 50000, today - 5: 50000}})
	_check("only the last week can be kept, newest first", daily.call("keepable")
		== PackedInt32Array([today - 1, today - 2, today - 3, today - 4, today - 6, today - 7]))
	daily.call("bought_keeper")
	_check("a Streak keeper bought with no day waiting is kept for later", int(daily.call("keepers")) == 1)
	daily.call("keep", today - 4, "keeper")
	_check("using one keeps the day and spends it", daily.call("kept", today - 4) and int(daily.call("keepers")) == 0)
	daily.call("keep", today - 3, "keeper")
	_check("with none left nothing is kept", not daily.call("kept", today - 3))
	daily.call("keep", today - 3, "buy")
	daily.call("bought_keeper")
	_check("one bought for a day keeps that day once Play confirms it", daily.call("kept", today - 3)
		and int(daily.call("keepers")) == 0)
	supporter.set("on_play", false)
	_check("where there is neither a video nor Play, keeping is free", daily.call("keeps_free"))
	supporter.set("on_play", true)
	_check("on Google Play it takes a video or a Streak keeper", not daily.call("keeps_free"))
	_check("the Streak keeper is bought again and again, and is no pack", shop.call("is_consumable", GameMonetize.STREAK_ID)
		and shop.call("all_ids").has(GameMonetize.STREAK_ID) and not shop.call("one_time_ids").has(GameMonetize.STREAK_ID)
		and not shop.call("parts").has(GameMonetize.STREAK_ID))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_keep.cfg"))
	save.set("path", old[0])
	save.set("daily", old[1])
	supporter.set("on_play", old[2])
	daily.set("skew", old[3])

func _test_daily_bank() -> void:
	var daily: GDScript = load("res://kit/daily/daily.gd")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/daily.json"))
	_check("daily.json parses", data is Dictionary)
	if not data is Dictionary:
		return
	var levels: Array = (data as Dictionary)["levels"]
	var campaign_levels: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json")) as Dictionary)["levels"]
	var count: int = campaign_levels.size()
	_check("the daily bank holds more than a year", levels.size() >= 366)
	_check("its first day is a real date", DailyDays.from_date(String(data["first"])) > DailyDays.from_date("2026-01-01"))
	_check("it opens after a chapter or two", int(data["opens_after"]) > 0 and int(data["opens_after"]) < count)
	var start: int = daily.call("first")
	_check("each day takes the next level, and the bank repeats once it runs out",
		daily.call("entry_for", start) == levels[0] and daily.call("entry_for", start + 1) == levels[1]
		and daily.call("entry_for", start + levels.size()) == levels[0])
	var campaign: Dictionary = {}
	for level: Variant in campaign_levels:
		campaign[_shape(level)] = true
	var repeats: Array[int] = []
	var seen: Dictionary = {}
	for i: int in range(levels.size()):
		var shape: String = _shape(levels[i])
		if campaign.has(shape) or seen.has(shape):
			repeats.append(i)
		seen[shape] = true
	_check("no day repeats a campaign level or another day (%s)" % str(repeats), repeats.is_empty())
	var checked: int = levels.size() if not OS.get_cmdline_user_args().has("quick") else 14
	var wrong: Array[int] = []
	var solver: TiltSolver = TiltSolver.new()
	for i: int in range(checked):
		if solver.solve(TiltBoard.from_dict(levels[i]), 100000).size() != int((levels[i] as Dictionary)["par"]):
			wrong.append(i)
	_check("every day solves in exactly its par (wrong: %s)" % str(wrong), wrong.is_empty())

static func _shape(level: Variant) -> String:
	var copy: Dictionary = (level as Dictionary).duplicate()
	copy.erase("par")
	return JSON.stringify(copy, "", true)

func _test_daily_result_lines() -> void:
	var result: GDScript = load("res://kit/daily/daily_result.gd")
	var replay: Dictionary = {"first": false, "on_time": true, "ms": 50000, "best_ms": 83000}
	var today: Dictionary = {"first": true, "on_time": true, "ms": 83000, "best_ms": 83000}
	var late: Dictionary = {"first": true, "on_time": false, "ms": 83000, "best_ms": 83000}
	var lines: PackedStringArray = [result.call("line", replay, true, true), result.call("line", late, true, true),
		result.call("line", today, true, true), result.call("line", today, true, false), result.call("line", today, false, false)]
	_check("a replay names the time that counts", lines[0] == "Your first time was 1:23. Only that one counts.")
	_check("a late solve says it holds neither the board nor the streak", lines[1].contains("not on the leaderboard or the streak"))
	_check("today's solve points to the leaderboard, or to signing in", lines[2].contains("on today's leaderboard")
		and lines[3].contains("Sign in") and lines[4].contains("tomorrow"))
	var clean: bool = true
	for line: String in lines:
		clean = clean and not line.contains(";") and line.ends_with(".")
	_check("every line is a plain sentence", clean)
	var said: String = result.call("share_text", DailyDays.from_date("2026-10-21"), 83000)
	var link: String = (load("res://share.gd") as GDScript).get_script_constant_map()["GET"]
	_check("the share names the game, the day, the time and the link", said.begins_with(Brand.NAME)
		and said.contains("21 October") and said.contains("1:23") and said.contains(link + "?from=daily"))

func _test_cloud_save() -> void:
	var cloud: GDScript = load("res://kit/play_games/cloud_save.gd")
	var a: Dictionary = {"times": {10: 50000, 11: 70000}, "late": [11], "open": [3], "clock": {12: 4000}}
	var b: Dictionary = {"times": {11: 65000, 12: 30000}, "late": [], "open": [4, 3], "clock": {13: 9000}}
	var joined: Dictionary = cloud.call("join_daily", a, b)
	_check("each day keeps its faster first solve", joined["times"] == {10: 50000, 11: 65000, 12: 30000})
	_check("a day is late only where every phone that solved it was late", (joined["late"] as Array).is_empty()
		and (cloud.call("join_daily", a, {}) as Dictionary)["late"] == [11])
	_check("opened days join, and a clock goes once its day is solved",
		(joined["open"] as Array).size() == 2 and joined["clock"] == {13: 9000})
	var keeps: Dictionary = cloud.call("join_daily", {"kept": [5], "keepers": 1}, {"kept": [6, 5], "keepers": 2})
	_check("kept days join, and unused Streak keepers are the most either phone had",
		(keeps["kept"] as Array).size() == 2 and int(keeps["keepers"]) == 2)
	var mine: ConfigFile = ConfigFile.new()
	var theirs: ConfigFile = ConfigFile.new()
	mine.set_value("progress", "stars", PackedByteArray([3, 1, 0]))
	theirs.set_value("progress", "stars", PackedByteArray([1, 2, 2, 3]))
	mine.set_value("progress", "opened", PackedInt32Array([150]))
	theirs.set_value("progress", "opened", PackedInt32Array([151, 150]))
	mine.set_value("monetize", "keys", 1)
	theirs.set_value("monetize", "keys", 4)
	mine.set_value("settings", "theme", 1)
	theirs.set_value("settings", "theme", 2)
	theirs.set_value("monetize", "supporter", true)
	cloud.call("merge", mine, theirs)
	_check("stars keep the best of each level", mine.get_value("progress", "stars") == PackedByteArray([3, 2, 2, 3]))
	_check("opened levels and level keys join", (mine.get_value("progress", "opened") as PackedInt32Array).size() == 2
		and int(mine.get_value("monetize", "keys")) == 4)
	_check("settings and purchases stay this phone's own", int(mine.get_value("settings", "theme")) == 1
		and not mine.has_section_key("monetize", "supporter"))
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("path"), save.get("stars"), save.get("daily")]
	save.set("path", "user://test_cloud.cfg")
	save.set("stars", PackedByteArray([1]))
	save.set("daily", {})
	save.call("store")
	var other: ConfigFile = ConfigFile.new()
	other.set_value("progress", "stars", PackedByteArray([2, 3]))
	other.set_value("daily", "record", {"times": {20000: 40000}})
	cloud.call("absorb", other.encode_to_text())
	_check("a copy from the cloud lands in the save", save.get("stars") == PackedByteArray([2, 3])
		and int(((save.get("daily") as Dictionary)["times"] as Dictionary)[20000]) == 40000)
	cloud.call("absorb", "not a save")
	_check("and anything unreadable changes nothing", save.get("stars") == PackedByteArray([2, 3]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_cloud.cfg"))
	save.set("path", old[0])
	save.set("stars", old[1])
	save.set("daily", old[2])

## Play Games hands back a fresh install's progress a moment after launch, while the title is already up.
func _test_title_follows_a_restore() -> void:
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("path"), save.get("stars")]
	save.set("path", "user://test_title_restore.cfg")
	save.set("stars", PackedByteArray())
	save.call("store")
	var canvas: CanvasLayer = CanvasLayer.new()
	root.add_child(canvas)
	var title: Node = (load(Brand.TITLE_SCENE) as PackedScene).instantiate()
	canvas.add_child(title)
	await process_frame
	var count: Label = title.find_child("Tally", true, false).find_children("*", "Label", true, false)[0]
	var levels: int = int(root.get_node("Pack").call("total"))
	_check("a fresh title tallies no stars, out of both sets' levels", count.text == "0 / %d" % (levels * 3))
	var cloud: ConfigFile = ConfigFile.new()
	cloud.set_value("progress", "stars", PackedByteArray([3, 2]))
	(load("res://kit/play_games/cloud_save.gd") as GDScript).call("absorb", cloud.encode_to_text())
	_check("the title tallies the stars a restore brings", count.text == "5 / %d" % (levels * 3))
	var shown: Array = title.find_children("*", "Label", true, false).filter(func(n: Node) -> bool:
		return (n as Label).text == "Level 3")
	_check("and points Play at the level after them", shown.size() == 1 and (shown[0] as Label).is_visible_in_tree())
	canvas.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_title_restore.cfg"))
	save.set("path", old[0])
	save.set("stars", old[1])

func _test_play_games() -> void:
	var games: GDScript = load("res://kit/play_games/play_games.gd")
	var catalog: Dictionary = games.call("catalog")
	var achievements: Array = catalog.get("achievements", [])
	var points: int = 0
	var fair: bool = true
	var keys: Dictionary = {}
	for entry: Variant in achievements:
		var a: Dictionary = entry
		points += int(a["points"])
		var measured: bool = a.has("solved") or a.has("three") or a.has("dailies") or a.has("streak")
		fair = fair and int(a["points"]) % 5 == 0 and int(a["points"]) <= 200 and measured \
			and String(a["name"]).length() <= 100 and String(a["text"]).ends_with(".") and not keys.has(a["key"])
		keys[a["key"]] = true
	_check("Play Games gets the five achievements it needs to publish", achievements.size() >= 5)
	_check("each achievement is measured and worth points in fives, 1000 at most in all", fair and points <= 1000)
	var boards: Dictionary = {}
	for entry: Variant in catalog.get("leaderboards", []):
		boards[(entry as Dictionary)["key"]] = entry
	_check("the daily board ranks the fastest time", boards.has("daily")
		and boards["daily"]["order"] == "SMALLER_IS_BETTER" and boards["daily"]["format"] == "TIME_DURATION")
	_check("and the all-time boards are stars and the longest streak", boards.has("stars") and boards.has("streak"))
	_check("nothing is earned at the start", (games.call("earned", 0, 0, 0, 0) as PackedStringArray).is_empty())
	_check("each threshold earns its achievement", games.call("earned", 25, 0, 1, 7)
		== PackedStringArray(["solved_1", "solved_25", "daily_1", "streak_7"]))
	var steps_fit: bool = true
	for entry: Variant in achievements:
		var a: Dictionary = entry
		var goal: int = games.call("goal", a)
		steps_fit = steps_fit and (goal == 1 or (goal >= 2 and goal <= 10000))
	_check("an achievement is one step or an incremental 2 to 10,000", steps_fit)
	var steps: Dictionary = games.call("progress", 30, 0, 0, 0)
	_check("progress counts up to each goal and stops there", int(steps["solved_1"]) == 1
		and int(steps["solved_25"]) == 25 and int(steps["solved_100"]) == 30 and int(steps["streak_7"]) == 0)
	var has_ids: bool = FileAccess.file_exists("res://play_games.json")
	_check("Play Games is on only once the game has its project", (String(games.call("app_id")) != "") == has_ids)
	if has_ids:
		var missing: PackedStringArray = PackedStringArray()
		for kind: String in ["achievements", "leaderboards"]:
			for entry: Variant in catalog.get(kind, []):
				if String(games.call("id_of", kind, StringName((entry as Dictionary)["key"]))) == "":
					missing.append(String((entry as Dictionary)["key"]))
		_check("play_games.json has an id for everything in the catalog (%s)" % ", ".join(missing), missing.is_empty())
	var plugin: String = FileAccess.get_file_as_string("res://addons/play_games/plugin.gd")
	_check("the build adds the library and SDK only with a project id", plugin.contains("play_games/bin/%s-%s.aar")
		and plugin.contains("play-services-games-v2") and plugin.contains('if app() == ""'))
	for build: String in ["release", "debug"]:
		var aar: String = "res://addons/play_games/bin/GodotPlayGameServices-%s.aar" % build
		_check("the %s library is in place, with no uncaught exception handler" % build,
			FileAccess.file_exists(aar) and _aar_has(aar, "GodotAndroidPlugin") and not _aar_has(aar, "setDefaultUncaughtExceptionHandler"))
		_check("and it has Game Stats and achievement steps", _aar_has(aar, "recordGameEvent")
			and _aar_has(aar, "uploadGameEvents") and _aar_has(aar, "setAchievementSteps"))
	_check("the build asks for the Play Games SDK with Game Stats", plugin.contains("play-services-games-v2:22.1.0"))

## Game Stats, held to Play Console's import rules so the files it is given never bounce.
func _test_game_stats() -> void:
	var games: GDScript = load("res://kit/play_games/play_games.gd")
	var catalog: Dictionary = games.call("catalog")
	var events: Dictionary = catalog.get("events", {})
	var name_ok: RegEx = RegEx.create_from_string("^[A-Za-z0-9_]{1,50}$")
	var reserved: PackedStringArray = ["id", "count", "key", "value", "where", "from", "and", "or", "true", "false"]
	var schema_ok: bool = events.size() >= 1 and events.size() <= 20
	for event: String in events:
		var props: Dictionary = events[event]
		schema_ok = schema_ok and name_ok.search(event) != null and props.size() >= 1 and props.size() <= 20
		for prop: String in props:
			schema_ok = schema_ok and name_ok.search(prop) != null and not reserved.has(prop.to_lower()) \
				and ["INT64", "DOUBLE", "STRING", "BOOL", "DURATION"].has(String(props[prop]))
	_check("every event and property name and type is one Play Console takes", schema_ok)
	_check("progress goes up as progressUpdate's whole-number currentProgress",
		events.has("progressUpdate") and (events["progressUpdate"] as Dictionary).get("currentProgress") == "INT64")
	var stats: Array = catalog.get("stats", [])
	var progression: Dictionary = catalog.get("progression", {})
	var id_ok: RegEx = RegEx.create_from_string("^[A-Za-z0-9_]{1,100}$")
	var units: PackedStringArray = ["", "UNITLESS", "SECOND", "MINUTE", "HOUR", "SECONDS", "MINUTES", "HOURS"]
	var formats: PackedStringArray = ["", "UNIT_BASED", "COMPONENT_NUMERIC", "COMPONENT_TEXT"]
	var keys: Dictionary = {progression.get("key", ""): true}
	var names: Dictionary = {progression.get("name", ""): true}
	var stats_ok: bool = true
	var competitive: int = 0
	for entry: Variant in stats:
		var s: Dictionary = entry
		var props: Dictionary = events.get(s["event"], {})
		stats_ok = stats_ok and id_ok.search(s["key"]) != null and not keys.has(s["key"]) and s["event"] != "progressUpdate" \
			and props.has(s["property"]) and ["SUM", "MAX", "MIN", "COUNT"].has(s["aggregation"]) \
			and String(s["name"]).length() <= 50 and not names.has(s["name"]) and String(s["text"]).length() <= 500 \
			and String(s["text"]).ends_with(".") and units.has(String(s.get("unit", ""))) \
			and formats.has(String(s.get("format", ""))) and (props[s["property"]] == "DURATION") == s.has("format")
		if s.has("filter"):
			var f: Array = s["filter"]
			stats_ok = stats_ok and props.has(f[0]) and ["=", "!=", ">", "<", ">=", "<="].has(f[1])
		if s.has("competitive"):
			competitive += 1
			stats_ok = stats_ok and (s["competitive"] as Array).size() == 2 and int(s["competitive"][0]) < int(s["competitive"][1])
		keys[s["key"]] = true
		names[s["name"]] = true
	_check("each stat names a real event and property, with a unique id and name", stats_ok)
	_check("five repetitive stats, one of them competitive, as Play's guidelines ask",
		stats.size() >= 5 and stats.size() <= 49 and competitive >= 1)
	_check("the progression stat reads currentProgress and its text fits in 50",
		progression.get("property") == "currentProgress" and id_ok.search(progression.get("key", "")) != null
		and String(progression.get("text", "")).length() <= 50 and String(progression.get("name", "")).length() <= 50)
	var solve: Dictionary = games.call("solve_event", 12, 3, 1, 5000.0, false)
	var levels: Dictionary = events.get("levelCompleted", {})
	var typed: bool = solve.size() == levels.size()
	for prop: String in levels:
		var want: int = {"INT64": TYPE_INT, "DOUBLE": TYPE_FLOAT, "BOOL": TYPE_BOOL, "STRING": TYPE_STRING,
			"DURATION": TYPE_DICTIONARY}[levels[prop]]
		typed = typed and solve.has(prop) and typeof(solve[prop]) == want
		if levels[prop] == "DURATION":
			typed = typed and typeof((solve[prop] as Dictionary).get("seconds")) == TYPE_FLOAT
	_check("a solve sends every levelCompleted property, each in its declared type", typed)
	var daily: Dictionary = games.call("solve_event", 0, 0, 0, 12.0, true)
	_check("and one solve adds an hour at most to the time spent", float(solve["time"]["seconds"]) == 3600.0
		and float(daily["time"]["seconds"]) == 12.0)

## Whether any class in an Android library's classes.jar names `text`.
func _aar_has(path: String, text: String) -> bool:
	var aar: ZIPReader = ZIPReader.new()
	if aar.open(path) != OK:
		return false
	var jar_path: String = "user://test_classes.jar"
	var jar_file: FileAccess = FileAccess.open(jar_path, FileAccess.WRITE)
	jar_file.store_buffer(aar.read_file("classes.jar"))
	jar_file.close()
	aar.close()
	var jar: ZIPReader = ZIPReader.new()
	var found: bool = false
	if jar.open(jar_path) == OK:
		var needle: String = text.to_utf8_buffer().hex_encode()
		for name: String in jar.get_files():
			if name.ends_with(".class") and (name.contains(text) or jar.read_file(name).hex_encode().contains(needle)):
				found = true
				break
		jar.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jar_path))
	return found

func _test_finale_variants() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var finale: GDScript = load("res://kit/shell/finale.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), save.get("supporter")]
	save.set("supporter", false)
	supporter.set("on_play", true)
	_check("the Play ending offers the Supporter pack", finale.call("support_line") == GameCredits.SUPPORT_LINE_PLAY
		and finale.call("support_button") == "Supporter pack")
	supporter.set("on_play", false)
	_check("the web ending offers GitHub Sponsors", finale.call("support_line") == GameCredits.SUPPORT_LINE_WEB
		and finale.call("support_button") == "Sponsor on GitHub")
	save.set("supporter", true)
	_check("a Supporter's ending thanks them and asks for nothing", finale.call("support_line") == GameCredits.THANKS_LINE
		and finale.call("support_button") == "")
	_check("the Play line names the pack and the web line does not",
		GameCredits.SUPPORT_LINE_PLAY.contains("Supporter pack") and not GameCredits.SUPPORT_LINE_WEB.contains("Supporter"))
	supporter.set("on_play", old[0])
	save.set("supporter", old[1])

func _test_rate_prompt() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var prompt: GDScript = load("res://kit/shell/rate_prompt.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), save.get("path"), save.get("stars"), save.get("rate_asked"), save.get("rated")]
	save.set("path", "user://test_rating.cfg")
	supporter.set("on_play", true)
	save.set("rated", false)
	save.set("rate_asked", 0)
	var count: int = root.get_node("Pack").call("count")
	var solve: Callable = func(n: int) -> void:
		var stars: PackedByteArray = PackedByteArray()
		stars.resize(count)
		for i: int in range(n):
			stars[i] = 1
		save.set("stars", stars)
	solve.call(9)
	_check("no rating ask before the first milestone", prompt.call("due") == 0)
	solve.call(10)
	_check("the first ask comes at the first milestone", prompt.call("due") == 10)
	var went: Array[bool] = [false]
	prompt.call("or_ad", root, func() -> void: went[0] = true)
	_check("at a milestone, Next level asks for Play's review card in place of an ad, then goes on",
		went[0] and int(save.get("rate_asked")) == 10)
	_check("once asked, it waits for the next milestone", prompt.call("due") == 0)
	solve.call(60)
	_check("the next milestone asks again, since Play never says whether a rating came", prompt.call("due") == 60)
	solve.call(70)
	prompt.call("at_end")
	_check("the ending asks only when the session has not asked already", int(save.get("rate_asked")) == 10)
	prompt.set("_asked_this_session", false)
	prompt.call("at_end")
	_check("and otherwise asks once more", int(save.get("rate_asked")) == 70)
	save.set("rate_asked", 0)
	solve.call(130)
	_check("a player past several milestones is asked once, at the highest", prompt.call("due") == 120)
	save.call("set_rating", 120, true)
	solve.call(200)
	_check("after Rate it never asks again", prompt.call("due") == 0 and not prompt.call("open_to_asking"))
	save.set("rated", false)
	save.set("rate_asked", 7)
	save.call("restore")
	_check("where the prompt stands is saved", int(save.get("rate_asked")) == 120 and bool(save.get("rated")))
	save.set("rated", false)
	save.set("rate_asked", 0)
	supporter.set("on_play", false)
	_check("the web build never asks", prompt.call("due") == 0 and not prompt.call("open_to_asking"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_rating.cfg"))
	supporter.set("on_play", old[0])
	save.set("path", old[1])
	save.set("stars", old[2])
	save.set("rate_asked", old[3])
	save.set("rated", old[4])
	prompt.set("_asked_this_session", false)

# PlayCore calls PlayCore.java by name, so a renamed method would fail only on a phone. Off Android there is no
# helper: the review goes straight on and no update is ever ready.
func _test_play_core() -> void:
	var core: GDScript = load("res://kit/shell/play_core.gd")
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var java: String = FileAccess.get_file_as_string("res://addons/play_core/PlayCore.java")
	var helper: PackedStringArray = String(core.get_script_constant_map()["HELPER"]).rsplit(".", true, 1)
	_check("PlayCore looks for the helper's own package and class",
		java.contains("package %s;" % helper[0]) and java.contains("public final class %s " % helper[1]))
	var missing: PackedStringArray = PackedStringArray()
	for method: String in ["requestReview", "reviewState", "checkForUpdate", "updateState", "completeUpdate"]:
		if not core.source_code.contains('"%s"' % method) or RegEx.create_from_string(
				"public static \\w+ %s\\(" % method).search(java) == null:
			missing.append(method)
	_check("every helper method PlayCore calls exists in the Java (%s)" % ", ".join(missing), missing.is_empty())
	var plugin: String = FileAccess.get_file_as_string("res://addons/play_core/plugin.gd")
	_check("the build adds the review and update libraries the helper imports",
		plugin.contains("com.google.android.play:review:") and plugin.contains("com.google.android.play:app-update:")
		and java.contains("com.google.android.play.core.review.") and java.contains("com.google.android.play.core.appupdate."))
	var old: bool = supporter.get("on_play")
	supporter.set("on_play", true)
	var went: Array[bool] = [false]
	core.call("review", func() -> void: went[0] = true)
	_check("without the helper the review goes straight on, and no update is ready",
		went[0] and not core.call("available") and not core.call("update_ready"))
	supporter.set("on_play", old)
	var host: Control = Control.new()
	root.add_child(host)
	core.call("offer_update", host)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	core.set("_offered", false)
	_check("a downloaded update is offered with Restart and Later", texts == PackedStringArray(["Restart", "Later"]))

func _test_more_games() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var studio: GDScript = load("res://kit/shell/studio.gd")
	var name: String = load("res://brand.gd").get_script_constant_map()["NAME"]
	var games: Array = studio.get_script_constant_map()["GAMES"]
	var old: bool = supporter.get("on_play")
	var names: PackedStringArray = PackedStringArray()
	for game: Dictionary in games:
		names.append(String(game["name"]))
		_check("%s's icon ships in the kit" % game["name"], ResourceLoader.exists(String(game["icon"])))
	_check("the studio's list includes this game", names.has(name))
	var others: Array = studio.call("others")
	var out: Array = games.filter(func(game: Dictionary) -> bool:
		return String(game["name"]) != name and bool(game.get("live", true)))
	_check("More games shows every other game out on Google Play, and not this one", others.size() == out.size()
		and others.all(func(game: Dictionary) -> bool: return out.has(game)))
	supporter.set("on_play", true)
	_check("on Google Play a game opens its Play page", String(studio.call("link", others[0])).begins_with("https://play.google.com/"))
	supporter.set("on_play", false)
	_check("on the web it opens the game in the browser", String(studio.call("link", others[0])).ends_with("/play/"))
	var host: Node = Node.new()
	load("res://kit/shell/more_games.gd").call("open", host)
	var cards: int = 0
	var all: bool = false
	for b: Node in host.find_children("*", "Button", true, false):
		cards += 1 if (b as Button).text == "" else 0
		all = all or (b as Button).text == "Every game at chaosmos.studio"
	host.free()
	_check("the sheet has a card per other game and a way to every game", cards == others.size() and all)
	supporter.set("on_play", old)

func _test_support_and_hint_sheets() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var gate: GDScript = load("res://kit/monetize/hint_gate.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), supporter.get("price"), save.get("supporter")]
	save.set("supporter", false)
	supporter.set("on_play", false)
	_check("the web's support sheet is one Sponsor on GitHub button", _buttons(supporter) == PackedStringArray(["Sponsor on GitHub"]))
	supporter.set("on_play", true)
	supporter.set("price", "")
	_check("the Play sheet sells the pack, restores it, and leads to the shop",
		_buttons(supporter) == PackedStringArray(["Support the game", "Restore purchase", "See the shop"]))
	supporter.set("price", "$2.99")
	_check("with the price once Play gives it", _buttons(supporter).has("Support for $2.99"))
	save.set("supporter", true)
	_check("a Supporter's sheet thanks them and sells nothing", _buttons(supporter) == PackedStringArray(["See the shop"]))
	var host: Node = Node.new()
	gate.call("ask", host, func() -> void: pass)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	_check("the video prompt asks with Watch and Not now", texts == PackedStringArray(["Watch", "Not now"]))
	supporter.set("on_play", old[0])
	supporter.set("price", old[1])
	save.set("supporter", old[2])

func _test_supporter_entry_points() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var gate: GDScript = load("res://kit/monetize/hint_gate.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), save.get("supporter")]
	save.set("supporter", false)
	supporter.set("on_play", true)
	var host: Node = Node.new()
	gate.call("ask", host, func() -> void: pass)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	_check("on Google Play the video prompt also offers the pack",
		texts == PackedStringArray(["Watch", "Remove ads, unlimited hints", "Not now"]))
	# The tip jar is always there, so the title's shop button shows on Google Play always.
	var old_owned: PackedStringArray = save.get("owned")
	for case: Array in [[true, false, [], true], [false, false, [], false], [true, true, [], true],
			[true, false, [GameMonetize.COMPLETE_ID], true]]:
		supporter.set("on_play", case[0])
		save.set("supporter", case[1])
		save.set("owned", PackedStringArray(case[2]))
		var ui: Control = Control.new()
		var gear: Control = Control.new()
		gear.offset_left = -128.0
		gear.offset_right = -32.0
		supporter.call("add_title_button", ui, ui, gear)
		_check("the title's shop button shows on Google Play only (%s)" % [case],
			(ui.get_child_count() == 1) == bool(case[3]))
		ui.free()
		gear.free()
	supporter.set("on_play", old[0])
	save.set("supporter", old[1])
	save.set("owned", old_owned)

## For sheets whose rows are labels inside buttons.
func _labels(opener: GDScript, method: String, args: Array = []) -> PackedStringArray:
	var host: Node = Node.new()
	opener.callv(method, [host] + args)
	var texts: PackedStringArray = PackedStringArray()
	for l: Node in host.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	for b: Node in host.find_children("*", "Button", true, false):
		if (b as Button).text != "":
			texts.append((b as Button).text)
	host.free()
	return texts

func _test_shop() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var shop: GDScript = load("res://kit/monetize/shop.gd")
	var looks: GDScript = load("res://kit/ui/looks.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), save.get("supporter"), save.get("owned"), save.get("tips"), save.get("look"),
		save.get("path")]
	save.set("path", "user://test_shop.cfg")
	supporter.set("on_play", true)
	save.set("supporter", false)
	save.set("owned", PackedStringArray())
	_check("with nothing bought, ads stay, levels open by solving, and only the first two looks are open",
		not shop.call("ads_off") and not shop.call("levels_open") and not shop.call("looks_open")
		and looks.call("is_open", "classic") and looks.call("is_open", "glass") and not looks.call("is_open", "gems"))
	_check("a level not reached yet is locked", not save.call("unlocked", 150))
	var sold: PackedStringArray = _labels(shop, "open")
	_check("the shop lists the Complete pack, every pack, the tip jar and Restore", sold.has("Complete pack")
		and sold.has("Supporter pack") and sold.has("Every level") and sold.has(GameLooks.PACK) and sold.has("Themes pack")
		and sold.has("Tip jar") and sold.has("Restore purchases"))
	var themes: GDScript = load("res://kit/ui/themes.gd")
	_check("with nothing bought only the game's own colours and Sepia are open", not shop.call("themes_open")
		and themes.call("is_open", "own") and themes.call("is_open", "sepia") and not themes.call("is_open", "nord"))
	save.set("palette", "nord")
	_check("a saved theme the pack has not opened falls back to the game's own", themes.call("current") == "own")
	shop.call("grant", GameMonetize.THEMES_ID, true)
	_check("the Themes pack opens every theme", shop.call("themes_open") and themes.call("current") == "nord")
	shop.call("grant", GameMonetize.THEMES_ID, false)
	save.set("palette", "")
	shop.call("grant", GameMonetize.LEVELS_ID, true)
	_check("Every level opens every level", shop.call("levels_open") and save.call("unlocked", 150)
		and save.call("unlocked", TiltGenerator.level_count() - 1))
	_check("and once part of it is owned the Complete pack is no longer sold", not shop.call("offers_complete")
		and not _labels(shop, "open").has("Complete pack"))
	shop.call("grant", GameMonetize.LEVELS_ID, false)
	_check("a refund locks the levels again", not save.call("unlocked", 150))
	shop.call("grant", GameMonetize.COMPLETE_ID, true)
	_check("the Complete pack holds all four", shop.call("ads_off") and shop.call("levels_open") and shop.call("looks_open")
		and shop.call("themes_open") and shop.call("has_everything") and looks.call("is_open", "gems"))
	shop.call("grant", GameMonetize.COMPLETE_ID, false)
	save.set("look", "gems")
	_check("a look the pack no longer opens falls back to the free one", looks.call("current") == "classic")
	var jar: PackedStringArray = _labels(shop, "tips")
	_check("the tip jar holds a tip for each size", jar.count("Tip") == GameMonetize.TIP_IDS.size())
	var tips: int = save.get("tips")
	shop.call("tipped")
	_check("a tip that went through is counted", int(save.get("tips")) == tips + 1)
	supporter.set("on_play", false)
	_check("off Google Play every look is open and nothing is sold", shop.call("looks_open") and looks.call("is_open", "gems")
		and _labels(shop, "open").has("Sponsor on GitHub"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_shop.cfg"))
	supporter.set("on_play", old[0])
	save.set("supporter", old[1])
	save.set("owned", old[2])
	save.set("tips", old[3])
	save.set("look", old[4])
	save.set("path", old[5])

func _test_cheers() -> void:
	var cheers: GDScript = load("res://kit/shell/cheers.gd")
	var result: GDScript = load("res://kit/shell/result.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("stars"), save.get("path")]
	save.set("path", "user://test_cheers.cfg")
	save.set("stars", PackedByteArray([3, 3, 3, 3]))
	var moment: Object = (result.get_script_constant_map()["Moment"] as GDScript).new()
	moment.set("level", 3)
	moment.set("summary", "5 moves, goal 5")
	moment.set("clean", true)
	var first: PackedStringArray = cheers.call("pick", moment, 3)
	_check("a perfect first try is news", first[1] == "First try, and perfect."
		and ((cheers.get_script_constant_map()["HEADINGS"] as Array)[2] as Array).has(first[0]))
	moment.set("before", 1)
	_check("more stars than before is news", (cheers.call("pick", moment, 3) as PackedStringArray)[1] == "Up from 1 star.")
	moment.set("before", 2)
	var said: String = ""
	var repeats: int = 0
	for k: int in range(12):
		var line: String = (cheers.call("pick", moment, 2) as PackedStringArray)[1]
		repeats += 1 if line == said else 0
		said = line
	_check("a run of wins never says the same line twice running", repeats == 0)
	save.set("stars", old[0])
	save.set("path", old[1])

func _test_win_sheet() -> void:
	var result: GDScript = load("res://kit/shell/result.gd")
	var replay_script: GDScript = load("res://kit/shell/replay.gd")
	var host: Node = Node.new()
	root.add_child(host)
	var moment: Object = (result.get_script_constant_map()["Moment"] as GDScript).new()
	moment.set("level", 3)
	moment.set("summary", "4 moves, goal 4")
	moment.set("before", 3)
	moment.set("watch", func() -> void: pass)
	var none: Callable = func() -> void: pass
	result.call("won", host, "", 3, PackedStringArray(["4 moves, goal 4"]), "Next level", none, none, none, moment)
	var texts: PackedStringArray = PackedStringArray()
	for l: Node in host.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	_check("a win offers Watch, Again and Levels, sharing being the snapshot's", texts.has("WATCH")
		and texts.has("AGAIN") and texts.has("LEVELS") and not texts.has("SHARE"))
	_check("and names the moment", (moment.get("words") as PackedStringArray).size() == 2
		and texts.has((moment.get("words") as PackedStringArray)[0]))
	var controls: CanvasLayer = CanvasLayer.new()
	controls.layer = 1
	var backdrop: CanvasLayer = CanvasLayer.new()
	backdrop.layer = -1
	host.add_child(controls)
	host.add_child(backdrop)
	var replay: CanvasLayer = replay_script.call("begin", host)
	_check("a replay puts the controls away, not the backdrop", not controls.visible and backdrop.visible)
	await replay.call("opening")
	_check("and runs the clock fast once it opens", Engine.time_scale > 1.0)
	replay.call("beat")
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	replay.call("_on_input", tap)
	_check("a tap asks to skip the rest", bool(replay.get("skipping")))
	replay.call("closing")
	replay.call("finish")
	await process_frame
	_check("and it puts the clock, the controls and the board back when it ends", is_equal_approx(Engine.time_scale, 1.0)
		and controls.visible and host.get_viewport().canvas_transform == Transform2D.IDENTITY)
	host.free()

func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: Node in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out

func _test_qr() -> void:
	var qr: GDScript = load("res://kit/ui/qr.gd")
	var small: PackedStringArray = qr.call("rows", "hi")
	_check("a short text fits the smallest code", small.size() == 21 and small[0].length() == 21)
	# Loaded, not named: GameShare uses the autoloads, which an import run has not made yet.
	var link: String = String(load("res://share.gd").get_script_constant_map()["GET"]) + "?from=card"
	var rows: PackedStringArray = qr.call("rows", link)
	var n: int = rows.size()
	_check("the share card's link fits version 5 at level H, 37 modules a side, so its code stays small", n == 37)
	var eyes: bool = true
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(n - 7, 0), Vector2i(0, n - 7)]:
		for y: int in range(7):
			for x: int in range(7):
				var ring: int = maxi(absi(x - 3), absi(y - 3))
				eyes = eyes and (rows[corner.y + y][corner.x + x] == "1") == (ring != 2)
	_check("each corner has a finder eye", eyes)
	var timing: bool = true
	for x: int in range(8, n - 8):
		timing = timing and (rows[6][x] == "1") == (x % 2 == 0)
	_check("the timing row alternates", timing)
	var format: int = 0
	var spots: Array[Vector2i] = [Vector2i(8, 0), Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3), Vector2i(8, 4),
		Vector2i(8, 5), Vector2i(8, 7), Vector2i(8, 8), Vector2i(7, 8), Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8),
		Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8)]
	for i: int in range(15):
		format |= (1 if rows[spots[i].y][spots[i].x] == "1" else 0) << i
	format ^= 0x5412
	var data: int = format >> 10
	var rem: int = data
	for k: int in range(10):
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	_check("the format says level H, and its check bits agree", data >> 3 == 2 and rem == (format & 0x3FF))

## The sliders follow a square law.
func _test_volumes() -> void:
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("sound_volume"), save.get("music_volume"), save.get("path")]
	save.set("path", "user://test_volumes.cfg")
	_check("a slider's end is full volume and its middle about half as loud",
		is_zero_approx(float(save.call("volume_db", 1.0))) and absf(float(save.call("volume_db", 0.5)) + 12.04) < 0.1
		and float(save.call("volume_db", 0.0)) <= -60.0)
	save.call("set_sound_volume", 0.4)
	save.call("set_music_volume", 0.0)
	_check("a volume of 0 is off, and any other is on", bool(save.get("sound_on")) and not bool(save.get("music_on")))
	save.call("restore")
	_check("volumes are saved", is_equal_approx(float(save.get("sound_volume")), 0.4)
		and is_zero_approx(float(save.get("music_volume"))))
	var older: ConfigFile = ConfigFile.new()
	older.set_value("settings", "sound_on", false)
	older.set_value("settings", "music_on", true)
	older.save("user://test_volumes.cfg")
	save.call("restore")
	_check("a save from before the sliders keeps its switches as volumes", is_zero_approx(float(save.get("sound_volume")))
		and is_equal_approx(float(save.get("music_volume")), 1.0) and not bool(save.get("sound_on")))
	var host: Node = Node.new()
	root.add_child(host)
	load("res://kit/shell/settings.gd").call("open", host)
	var sliders: Array[Node] = host.find_children("*", "Range", true, false)
	_check("settings has a slider for the sound, and one for the music where there is music",
		sliders.size() == (2 if Brand.HAS_MUSIC else 1))
	var sound: Range = sliders[0] as Range
	var detents: Array[float] = []
	sound.value_changed.connect(func(v: float) -> void: detents.append(v))
	sound.value = 0.33
	var heard: float = float(save.get("sound_volume"))
	sound.value = 0.34
	sound.value = 0.0
	_check("a volume slider moves in detents, each one heard at once",
		detents.size() == 2 and is_equal_approx(detents[0], 0.35) and is_equal_approx(heard, 0.35)
		and is_zero_approx(detents[1]) and is_zero_approx(float(save.get("sound_volume"))))
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_volumes.cfg"))
	save.call("hear_sound_volume", old[0])
	save.call("hear_music_volume", old[1])
	save.set("path", old[2])

func _test_unlocks() -> void:
	var unlocks: GDScript = load("res://kit/monetize/unlocks.gd")
	var shop: GDScript = load("res://kit/monetize/shop.gd")
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var save: Node = root.get_node("Save")
	var pack: Node = root.get_node("Pack")
	var old: Array = [save.get("stars"), save.get("keys"), save.get("opened"), save.get("owned"), save.get("path"),
		supporter.get("on_play")]
	save.set("path", "user://test_unlocks.cfg")
	save.set("owned", PackedStringArray())
	save.set("opened", PackedInt32Array())
	save.set("keys", 0)
	var second: int = int(pack.call("chapter_first", 1))
	var gate: int = int(unlocks.call("gate", 0))
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(gate - 1)
	stars.fill(2)
	save.set("stars", stars)
	_check("a chapter opens at seven in ten of the one before", gate == ceili(0.7 * TiltGenerator.chapter_size(0)))
	_check("one short of the gate, the next chapter is shut and says what opens it",
		not save.call("unlocked", second) and String(unlocks.call("how", second)).contains("1 more level in chapter 1"))
	save.call("record", gate - 1, 1)
	_check("at the gate the next chapter's first level opens, and the win says so",
		save.call("unlocked", second) and int(unlocks.call("gate_opened_by", gate - 1)) == 1)
	_check("but not the level after it", not save.call("unlocked", second + 1))
	_check("a level two ahead of play is shut", not save.call("unlocked", gate + 1))
	_check("with no key there is none to use", not unlocks.call("use_key", gate + 1))
	shop.call("keyed", GameMonetize.KEY_IDS[1])
	_check("a pack of keys Play delivered is counted", int(save.get("keys")) == GameMonetize.KEY_COUNTS[1])
	_check("a key opens any one level, for good", unlocks.call("use_key", gate + 1) and save.call("unlocked", gate + 1)
		and int(save.get("keys")) == GameMonetize.KEY_COUNTS[1] - 1)
	save.call("restore")
	_check("keys and the levels they opened are saved", int(save.get("keys")) == GameMonetize.KEY_COUNTS[1] - 1
		and (save.get("opened") as PackedInt32Array).has(gate + 1))
	_check("keys and tips are used up on purchase, packs are not", shop.call("is_consumable", GameMonetize.KEY_IDS[0])
		and shop.call("is_consumable", GameMonetize.TIP_IDS[0]) and not shop.call("is_consumable", GameMonetize.LEVELS_ID))
	supporter.set("on_play", true)
	_check("the shop leads to the level keys", _labels(shop, "open").has("Level keys"))
	var keys: PackedStringArray = _labels(shop, "keys")
	_check("the keys sheet sells one key and five", keys.has("1 level key") and keys.has("%d level keys" % GameMonetize.KEY_COUNTS[1]))
	var offer: PackedStringArray = _labels(unlocks, "offer", [second + 3])
	_check("a locked level on Google Play offers a key and Every level", offer.has("Use a key (%d left)" % (GameMonetize.KEY_COUNTS[1] - 1))
		and offer.has("Open every level"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_unlocks.cfg"))
	save.set("stars", old[0])
	save.set("keys", old[1])
	save.set("opened", old[2])
	save.set("owned", old[3])
	save.set("path", old[4])
	supporter.set("on_play", old[5])

## A save from before the Hard levels: stars and keys go with the boards they were won on, and the main path keeps
## open every chapter the player had reached (MATH.md section 16).
func _test_hard_shelf() -> void:
	var save: Node = root.get_node("Save")
	var pack: Node = root.get_node("Pack")
	var unlocks: GDScript = load("res://kit/monetize/unlocks.gd")
	var analytics: GDScript = load("res://kit/monetize/analytics.gd")
	var cloud: GDScript = load("res://kit/play_games/cloud_save.gd")
	var first: int = HardShelf.FIRST
	# Old levels 1 to 250 solved, level 201 with three stars, and a key spent on old level 306.
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(250)
	stars.fill(2)
	stars[200] = 3
	var old: ConfigFile = ConfigFile.new()
	old.set_value("progress", "stars", stars)
	old.set_value("progress", "opened", PackedInt32Array([40, 305]))
	var file: ConfigFile = ConfigFile.new()
	file.parse(old.encode_to_text())
	_check("a save from before the Hard levels moves on", HardShelf.migrate(file, unlocks.GATE)
		and int(file.get_value("progress", "layout")) == HardShelf.LAYOUT)
	var main: PackedByteArray = file.get_value("progress", "stars")
	var hard: PackedByteArray = file.get_value("progress", "hard")
	var opened: PackedInt32Array = file.get_value("progress", "opened")
	var hard_opened: PackedInt32Array = file.get_value("progress", "hard_opened")
	_check("stars before the plateau stay on the main path, and its new boards start with none",
		main == stars.slice(0, first))
	_check("stars won on the old boards move with them to Hard", hard.size() == stars.size() and hard[200] == 3
		and hard[249] == 2 and hard.slice(0, first).count(0) == first)
	_check("a key spent on an old board stays with it in Hard", hard_opened == PackedInt32Array([305])
		and opened.has(40) and not opened.has(305))
	# Old chapter 16 (index 15) was the furthest reached. On the main path it is chapter 17 now, after the bouncy blocks.
	var starts: bool = true
	for c: int in range(9, 17):
		starts = starts and opened.has(c * HardShelf.CHAPTER)
	_check("the main path opens the bouncy blocks and every chapter up to the furthest reached, a chapter later now",
		starts and not opened.has(340))
	_check("and moving on twice changes nothing", not HardShelf.migrate(file, unlocks.GATE))
	var gated: PackedByteArray = PackedByteArray()
	gated.resize(234)
	gated.fill(1)
	var by_gate: Dictionary = HardShelf.split(gated, PackedInt32Array(), unlocks.GATE)
	_check("a chapter its gate had opened stays open", (by_gate["opened"] as PackedInt32Array).has(260)
		and not (by_gate["opened"] as PackedInt32Array).has(280))
	var before: Dictionary = HardShelf.split(PackedByteArray([2, 2, 2]), PackedInt32Array([150]), unlocks.GATE)
	var paint: PackedByteArray = PackedByteArray()
	paint.resize(170)
	paint.fill(1)
	_check("a player still short of chapter 10 gets nothing opened past it", not (HardShelf.split(paint,
		PackedInt32Array(), unlocks.GATE)["opened"] as PackedInt32Array).has(180) and not (before["opened"] as
		PackedInt32Array).has(180))
	var early: Dictionary = HardShelf.split(PackedByteArray([3, 3, 1]), PackedInt32Array(), unlocks.GATE)
	_check("a player who never reached the plateau has nothing to move", early["stars"] == PackedByteArray([3, 3, 1])
		and (early["opened"] as PackedInt32Array).is_empty() and (early["hard"] as PackedByteArray).is_empty())

	var kept: Array = [save.get("path"), save.get("stars"), save.get("hard_stars"), save.get("opened"),
		save.get("hard_opened"), int(pack.get("section")), save.get("street"), save.get("coins"), save.get("best_ids")]
	save.set("path", "user://test_hard_shelf.cfg")
	old.save("user://test_hard_shelf.cfg")
	save.call("restore")
	var moved: ConfigFile = ConfigFile.new()
	moved.load("user://test_hard_shelf.cfg")
	_check("a save is moved on as it loads, and kept that way", int(moved.get_value("progress", "layout", 1)) >= HardShelf.LAYOUT
		and (save.get("stars") as PackedByteArray).size() == first)
	pack.call("use", 1)
	var hard_from: int = int(pack.get("hard_from"))
	_check("in Hard each old board has its stars and its place", hard_from == first and int(save.call("best", 200)) == 3
		and save.call("unlocked", 250) and not save.call("unlocked", 251) and save.call("unlocked", 305))
	# The old level 201 is Hard's 21st: Hard counts its own levels and chapters from 1, on screen and in analytics.
	var shown: GDScript = load("res://kit/shell/shown.gd")
	var share: GDScript = load("res://kit/shell/share_card.gd")
	var moment: GDScript = (load("res://kit/shell/result.gd") as GDScript).get_script_constant_map()["Moment"]
	var won: Object = moment.new()
	won.set("level", 200)
	_check("and analytics names its levels apart, as Hard counts them", (analytics.call("tagged", {"level": 201}) as
		Dictionary)["level"] == "h21")
	_check("Hard shows its own numbers from 1, its chapters too", int(shown.call("level", hard_from)) == 1
		and int(shown.call("level", HardShelf.COUNT - 1)) == HardShelf.COUNT - first and int(shown.call("chapter", 9)) == 1
		and int(shown.call("chapter", 24)) == 16 and String(shown.call("word", 200)) == "Hard"
		and int(shown.call("stat", 200)) == 1021)
	var heading: Node = (load("res://kit/shell/hud.gd") as GDScript).call("level_heading", 200)
	_check("on the play screen, the share card and a locked level's sheet", (heading.get_child(0) as Label).text == "HARD"
		and (heading.get_child(1) as Label).text == "21" and String(share.call("_file_name", won)) == "plumb-hard-21.png"
		and String(unlocks.call("how", 201)).contains("Hard 21"))
	heading.free()
	pack.call("use", 0)
	_check("while the main path counts as ever", int(shown.call("level", 200)) == 201 and int(shown.call("chapter", 9)) == 10
		and String(share.call("_file_name", won)) == "plumb-level-201.png" and int(shown.call("stat", 200)) == 201)
	_check("on the main path each reached chapter opens, and its new boards wait to be solved",
		save.call("unlocked", 300) and save.call("unlocked", first) and not save.call("unlocked", first + 1)
		and not save.call("unlocked", 305) and int(save.call("best", 200)) == 0)
	_check("where the main path's levels keep their own names", (analytics.call("tagged", {"level": 201}) as Dictionary)["level"] == 201)
	_check("a total counts the stars of both", int(save.call("total_stars")) == stars.size() * 2 + 1)
	var theirs: ConfigFile = ConfigFile.new()
	var cloud_stars: PackedByteArray = PackedByteArray()
	cloud_stars.resize(first + 11)
	cloud_stars[first + 10] = 3
	theirs.set_value("progress", "stars", cloud_stars)
	cloud.call("absorb", theirs.encode_to_text())
	pack.call("use", 1)
	_check("an old copy from the cloud lands its stars on the Hard boards they were won on",
		int(save.call("best", first + 10)) == 3)
	pack.call("use", 0)
	_check("and never on the main path's new ones", int(save.call("best", first + 10)) == 0)
	save.set("stars", PackedByteArray())
	save.set("hard_stars", PackedByteArray())
	save.set("opened", PackedInt32Array())
	save.set("hard_opened", PackedInt32Array())
	pack.call("use", 1)
	_check("Hard is open from the start", save.call("unlocked", hard_from) and not save.call("unlocked", hard_from + 1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hard_shelf.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hard_shelf.layout2.cfg"))
	save.set("path", kept[0])
	save.set("stars", kept[1])
	save.set("hard_stars", kept[2])
	save.set("opened", kept[3])
	save.set("hard_opened", kept[4])
	pack.call("use", kept[5])
	save.set("street", kept[6])
	save.set("coins", kept[7])
	save.set("best_ids", kept[8])

func _test_passes() -> void:
	var passes: GDScript = load("res://kit/monetize/passes.gd")
	var shop: GDScript = load("res://kit/monetize/shop.gd")
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var themes: GDScript = load("res://kit/ui/themes.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("passes"), save.get("owned"), save.get("keys"), save.get("palette"), save.get("stars"),
		save.get("opened"), save.get("path"), supporter.get("on_play")]
	save.set("path", "user://test_passes.cfg")
	save.set("owned", PackedStringArray())
	save.set("passes", {})
	save.set("stars", PackedByteArray())
	save.set("opened", PackedInt32Array())
	save.set("palette", "nord")
	supporter.set("on_play", true)
	ads.call("use", _VideoAds.new())
	var hours: int = passes.get("HOURS")
	_check("a video lends the looks, the themes and every level, never the Supporter or the Complete pack",
		passes.call("offers", GameMonetize.LOOKS_ID) and passes.call("offers", GameMonetize.THEMES_ID)
		and passes.call("offers", GameMonetize.LEVELS_ID) and not passes.call("offers", GameMonetize.SUPPORTER_ID)
		and not passes.call("offers", GameMonetize.COMPLETE_ID))
	_check("a pack's sheet offers it beside the price",
		_labels(shop, "offer", [GameMonetize.THEMES_ID]).has("Try it for %d hours %s" % [hours, ads.call("with_one")]))
	_check("and says a purchase is for good", _labels(shop, "offer", [GameMonetize.THEMES_ID]).has(shop.get("KEEP_ROW")))
	passes.call("lend", GameMonetize.THEMES_ID)
	await process_frame
	await process_frame
	_check("a video watched through opens the Themes pack, lent, not owned", shop.call("themes_open")
		and themes.call("current") == "nord" and not shop.call("has", GameMonetize.THEMES_ID)
		and not passes.call("offers", GameMonetize.THEMES_ID))
	_check("for its hours", String(passes.call("say_left", GameMonetize.THEMES_ID)) == "%d h" % hours)
	save.call("restore")
	_check("a pass is saved", passes.call("active", GameMonetize.THEMES_ID))
	passes.set("skew", hours * 3600 + 1)
	_check("it runs out after its hours, and the theme in use goes back to the game's own",
		not shop.call("themes_open") and themes.call("current") == "own")
	passes.set("skew", -60)
	_check("a clock turned back past its start ends it too", not passes.call("active", GameMonetize.THEMES_ID))
	passes.set("skew", 0)
	var last: int = int(root.get_node("Pack").call("count")) - 1
	_check("the last level is shut", not save.call("unlocked", last))
	passes.call("lend", GameMonetize.LEVELS_ID)
	await process_frame
	await process_frame
	_check("a pass for Every level opens every level", save.call("unlocked", last))
	var keys: int = save.get("keys")
	_check("the keys sheet offers a key for a video", _labels(shop, "keys").has("Watch a video for a key"))
	passes.call("give_key")
	await process_frame
	await process_frame
	_check("which gives one", int(save.get("keys")) == keys + 1)
	ads.call("use", null)
	passes.set("_running", PackedStringArray())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_passes.cfg"))
	save.set("passes", old[0])
	save.set("owned", old[1])
	save.set("keys", old[2])
	save.set("palette", old[3])
	save.set("stars", old[4])
	save.set("opened", old[5])
	save.set("path", old[6])
	supporter.set("on_play", old[7])

func _test_play_screen_banner() -> void:
	var hud: GDScript = load("res://kit/shell/hud.gd")
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	_check("no banner, no lift", is_zero_approx(float(hud.call("banner_lift", 0.0))))
	var height: float = 120.0
	var lift: float = hud.call("banner_lift", height)
	_check("the bottom row clears a banner by the gap",
		is_equal_approx(lift + float(hud.get("BOTTOM_LIFT")) - height, float(hud.get("BANNER_GAP"))))
	var save: Node = root.get_node("Save")
	var old: Array = [save.get("stars"), ads.get("preview")]
	var stars: PackedByteArray = PackedByteArray()
	stars.resize(int(root.get_node("Pack").call("count")))
	for i: int in range(int(AdPacing.BANNER_AFTER)):
		stars[i] = 3
	save.set("stars", stars)
	var host: Control = Control.new()
	root.add_child(host)
	ads.set("preview", true)
	var room: float = ads.call("expected_banner_height", host)
	_check("a play screen holds the banner's room before the ad loads (%.0f)" % room, room >= 50.0)
	ads.set("preview", false)
	_check("and none where no ad can show", is_zero_approx(float(ads.call("expected_banner_height", host))))
	host.free()
	save.set("stars", old[0])
	ads.set("preview", old[1])

# A line that cannot wrap widens the whole sheet past the screen.
# A control that stops the mouse inside a scrolling list keeps a drag that starts on it from scrolling the
# list on a phone. Buttons keep their taps, and the list's own scroll bars are sliders.
func _test_credits_scroll_by_drag() -> void:
	var host: Control = Control.new()
	root.add_child(host)
	load("res://kit/shell/credits.gd").call("open", host)
	var blockers: PackedStringArray = PackedStringArray()
	for scroll: Node in host.find_children("*", "ScrollContainer", true, false):
		for node: Node in scroll.find_children("*", "Control", true, false):
			var control: Control = node
			if control.mouse_filter == Control.MOUSE_FILTER_STOP and not (control is BaseButton or control is Range):
				blockers.append(control.get_class())
	_check("a drag anywhere on the credits list scrolls it (%s)" % ", ".join(blockers), blockers.is_empty())
	host.free()

func _test_sheets_fit_a_phone() -> void:
	var design_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var old: bool = supporter.get("on_play")
	var openers: Dictionary = {
		"settings": load("res://kit/shell/settings.gd"),
		"about": load("res://kit/shell/about.gd"),
		"credits": load("res://kit/shell/credits.gd"),
		"supporter": supporter,
	}
	for play: bool in [true, false]:
		supporter.set("on_play", play)
		for kind: String in openers:
			var host: Control = Control.new()
			root.add_child(host)
			var sheet: Control = (openers[kind] as GDScript).call("open", host)
			var width: float = (sheet.get("_panel") as Control).get_combined_minimum_size().x
			_check("the %s sheet fits a phone's width (%.0f of %.0f)" % [kind, width, design_width], width <= design_width)
			host.free()
	# A price as long as Play is likely to give in any currency, since a dollar price fits anything.
	var shop: GDScript = load("res://kit/monetize/shop.gd")
	var unlocks: GDScript = load("res://kit/monetize/unlocks.gd")
	var prices: Dictionary = (shop.get("prices") as Dictionary).duplicate()
	var long: Dictionary = {}
	for id: String in shop.call("all_ids"):
		long[id] = "COP 199.900,00"
	shop.set("prices", long)
	supporter.set("on_play", true)
	var priced: Array = [["shop", "open", []], ["level keys", "keys", []], ["tip jar", "tips", []]]
	for id: String in shop.call("one_time_ids"):
		priced.append(["%s offer" % id, "offer", [id]])
	for entry: Array in priced:
		var host: Control = Control.new()
		root.add_child(host)
		var sheet: Control = shop.callv(String(entry[1]), [host] + (entry[2] as Array))
		var width: float = (sheet.get("_panel") as Control).get_combined_minimum_size().x
		_check("the %s sheet fits a phone's width at any price (%.0f of %.0f)" % [entry[0], width, design_width],
			width <= design_width)
		host.free()
	var shut: Control = Control.new()
	root.add_child(shut)
	var locked: Control = unlocks.call("offer", shut, 2)
	var locked_width: float = (locked.get("_panel") as Control).get_combined_minimum_size().x
	_check("a locked level's sheet fits a phone's width at any price (%.0f of %.0f)" % [locked_width, design_width],
		locked_width <= design_width)
	shut.free()
	shop.set("prices", prices)
	supporter.set("on_play", old)

# With LevelPlay off, the studio's house banner stands in, as tall as a phone's ad: no interstitials and nothing in a
# video's place. A reward with no video to play is simply given. The banner has a light and a dark look per game.
func _test_house_ads() -> void:
	var house: GDScript = load("res://kit/monetize/house_ads.gd")
	var looks: GDScript = load("res://kit/monetize/house_games.gd")
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var backend: Node = house.new()
	root.add_child(backend)
	_check("house ads are a banner only: no interstitial and nothing in a video's place",
		not backend.call("ready_to_show", &"interstitial") and not backend.call("ready_to_show", &"rewarded"))
	var heights: Array[float] = []
	backend.connect("banner_changed", func(h: float) -> void: heights.append(h))
	backend.call("set_banner", true)
	_check("the house banner takes a phone banner's height", heights.size() == 1 and heights[0] > 0.0)
	backend.call("stop")
	_check("and gives the room back when ads stop", heights.size() == 2 and is_zero_approx(heights[1]))
	backend.free()
	ads.call("use", house.new())
	var given: Array[bool] = [false]
	ads.call("rewarded", func() -> void: given[0] = true)
	_check("with no video to play, a reward is simply given", given[0])
	_check("and the buttons that offer one say it is free", String(ads.call("with_one")) == "free")
	ads.call("use", _VideoAds.new())
	_check("once LevelPlay has a video, they offer it", String(ads.call("with_one")) == "with a video")
	ads.call("use", null)
	var styles: Dictionary = looks.get_script_constant_map()["STYLES"]
	var both: Array[String] = []
	for name: String in styles:
		var light: Dictionary = looks.call("style", name, false)
		var dark: Dictionary = looks.call("style", name, true)
		if _contrast(light["ink"], light["bg"]) >= 4.5 and _contrast(dark["ink"], dark["bg"]) >= 4.5 \
				and (light["bg"] as Color).get_luminance() > 0.7 and (dark["bg"] as Color).get_luminance() < 0.2:
			both.append(name)
	_check("every house game has a readable light banner and a readable dark one (%s)" % ", ".join(both),
		both.size() == styles.size() and both.size() >= 4)

# The LevelPlay backend against a stand-in for the plugin: consent and test mode before the SDK starts, both
# full-screen formats loaded once it has, a video's reward kept, the house banner holding the strip until
# LevelPlay's loads, an ad that leaves the app or never ends logged as trouble, and nothing for a Supporter.
func _test_levelplay_backend() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var save: Node = root.get_node("Save")
	var old_supporter: bool = save.get("supporter")
	save.set("supporter", false)
	var consent_script: GDScript = load("res://kit/monetize/consent.gd")
	var test_ads: GDScript = load("res://kit/monetize/test_ads.gd")
	var analytics: GDScript = load("res://kit/monetize/analytics.gd")
	var old_consent: String = consent_script.get("path")
	var old_test: String = test_ads.get("path")
	consent_script.set("path", "user://test_consent.cfg")
	test_ads.set("path", "user://test_ads.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_ads.get("path")))
	# Asked and answered, wherever the machine running the tests is.
	var consent: ConfigFile = ConfigFile.new()
	consent.set_value("debug", "force", true)
	consent.set_value("consent", "answer", "granted")
	consent.save(consent_script.get("path"))
	var heard: Array[Array] = []
	analytics.sink = func(event: StringName, params: Dictionary) -> void: heard.append([event, params])
	var old_state: String = ads.get("state_path")
	ads.set("state_path", "user://test_ads_state.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ads.get("state_path")))
	var plugin: RefCounted = FakeIntermission.new()
	var backend: AdBackend = (load("res://kit/monetize/android/levelplay.gd") as GDScript).new()
	backend.set("plugin", plugin)
	var heights: Array[float] = []
	backend.banner_changed.connect(func(h: float) -> void: heights.append(h))
	var done: Array[Array] = []
	backend.finished.connect(func(kind: StringName, shown: bool, earned: bool) -> void: done.append([kind, shown, earned]))
	ads.call("use", backend)
	var calls: PackedStringArray = plugin.get("calls")
	var key: String = GameMonetize.LEVELPLAY_APP_KEY
	_check("consent and test mode go to the SDK before it starts (%s)" % ", ".join(calls), calls == PackedStringArray([
		"overlong 75.0", "gdpr true", "coppa false", "initialize %s true" % key]))
	_check("nothing is ready before the SDK is", not backend.video_ready())
	plugin.emit_signal(&"initialized", true, "none", 0, "")
	calls = plugin.get("calls")
	var interstitial: String = GameMonetize.LEVELPLAY_INTERSTITIAL_ID
	var rewarded: String = GameMonetize.LEVELPLAY_REWARDED_ID
	_check("both full-screen formats load once it starts", calls.has("load interstitial %s" % interstitial)
		and calls.has("load rewarded %s" % rewarded))
	plugin.call("fill", "rewarded", rewarded)
	_check("a loaded video is offered", backend.video_ready() and String(ads.call("with_one")) == "with a video")
	var given: Array[int] = [0]
	ads.call("rewarded", func() -> void: given[0] += 1)
	_check("the video plays at its placement", (plugin.get("calls") as PackedStringArray).has("show %s reward" % rewarded))
	plugin.emit_signal(&"ad_shown", "rewarded", rewarded, "ironSource")
	plugin.emit_signal(&"app_left", "rewarded", rewarded, false)
	plugin.emit_signal(&"ad_overlong", "rewarded", rewarded, 75.5)
	plugin.emit_signal(&"app_left", "rewarded", rewarded, true)
	plugin.emit_signal(&"ad_closed", "rewarded", rewarded, true)
	await process_frame
	await process_frame
	_check("a video watched through gives its reward once", given[0] == 1 and done.back() == [&"rewarded", true, true])
	var trouble: Array[Dictionary] = []
	for event: Array in heard:
		if event[0] == &"ad_trouble":
			trouble.append(event[1])
	_check("an ad that left the app by itself and one that ran long are trouble, a tap is not (%s)" % str(trouble),
		trouble.size() == 2 and trouble[0]["kind"] == "left_app" and trouble[0]["network"] == "ironSource"
		and trouble[1]["kind"] == "overlong" and trouble[1]["seconds"] == 75 and trouble[0]["format"] == "rewarded")
	_check("the next video loads after one is shown",
		(plugin.get("calls") as PackedStringArray).count("load rewarded %s" % rewarded) == 2)
	_check("trouble with a video leaves ads between levels on", not ads.call("interstitials_paused"))
	plugin.emit_signal(&"app_left", "interstitial", interstitial, false)
	_check("an ad between levels that left the app by itself pauses them", ads.call("interstitials_paused"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ads.get("state_path")))
	plugin.emit_signal(&"ad_overlong", "interstitial", interstitial, 80.0)
	_check("and so does one that never ends", ads.call("interstitials_paused"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ads.get("state_path")))
	ads.set("state_path", old_state)
	plugin.call("fill", "rewarded", rewarded)
	ads.call("rewarded", func() -> void: given[0] += 1)
	plugin.emit_signal(&"ad_shown", "rewarded", rewarded, "ironSource")
	plugin.emit_signal(&"ad_closed", "rewarded", rewarded, false)
	await process_frame
	await process_frame
	_check("a video closed early gives nothing", given[0] == 1 and done.back() == [&"rewarded", true, false])
	plugin.call("fill", "interstitial", interstitial)
	backend.present(AdBackend.INTERSTITIAL)
	plugin.emit_signal(&"ad_failed_to_show", "interstitial", interstitial, "expired", 0, "")
	await process_frame
	await process_frame
	_check("an ad that fails to show ends at once, unshown", done.back() == [&"interstitial", false, false])
	backend.set_banner(true)
	calls = plugin.get("calls")
	_check("the banner loads at its size and stands at the foot",
		calls.has("banner %s banner screen_foot" % GameMonetize.LEVELPLAY_BANNER_ID) and calls.has("show banner bottom"))
	_check("the house banner holds the strip meanwhile", heights.size() == 1 and heights[0] > 0.0)
	plugin.emit_signal(&"banner_loaded", GameMonetize.LEVELPLAY_BANNER_ID, 320, 50)
	_check("LevelPlay's banner takes over at its own height", heights.size() == 2 and heights[1] > 0.0)
	plugin.emit_signal(&"banner_loaded", GameMonetize.LEVELPLAY_BANNER_ID, 320, 50)
	_check("a refresh at the same size changes nothing", heights.size() == 2)
	backend.set_banner(false)
	_check("leaving the screen hides it", (plugin.get("calls") as PackedStringArray).has("hide banner"))
	ads.call("stop")
	_check("a Supporter's purchase takes the banner away", (plugin.get("calls") as PackedStringArray).has("destroy banner")
		and is_zero_approx(heights.back()))
	var loads: int = (plugin.get("calls") as PackedStringArray).size()
	save.set("supporter", true)
	ads.call("start")
	_check("and nothing starts again for a Supporter", (plugin.get("calls") as PackedStringArray).size() == loads
		and not bool(ads.call("live")))
	ads.call("use", null)
	analytics.sink = Callable()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(consent_script.get("path")))
	consent_script.set("path", old_consent)
	test_ads.set("path", old_test)
	save.set("supporter", old_supporter)

# Android's back button goes back a screen and asks before the game closes, instead of quitting outright.
func _test_go_back() -> void:
	_check("the back button never quits the app outright",
		ProjectSettings.get_setting("application/config/quit_on_go_back") == false)
	var sheets: GDScript = load("res://kit/ui/sheet.gd")
	var go_back: GDScript = load("res://kit/shell/go_back.gd")
	_check("with no sheet open, back is the screen's to handle", not sheets.call("back"))
	var host: Control = Control.new()
	root.add_child(host)
	go_back.call("ask", host)
	_check("on the title it asks before closing the game", sheets.call("any_open"))
	_check("and back answers that by staying", sheets.call("back"))
	await create_timer(0.8).timeout
	_check("so the game carries on", not sheets.call("any_open"))
	var went: Array[bool] = [false]
	var none: Callable = func() -> void: pass
	load("res://kit/shell/result.gd").call("won", host, "Solved", 3, PackedStringArray(), "Next level", none, none,
		func() -> void: went[0] = true)
	_check("on the win sheet, back goes to the level grid", sheets.call("back") and went[0])
	host.free()

func _test_sheet_rises_before_layout() -> void:
	var settings: GDScript = load("res://kit/shell/settings.gd")
	var canvas: CanvasLayer = CanvasLayer.new()
	root.add_child(canvas)
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(host)
	_open_in_process = func() -> Control: return settings.call("open", host)
	while _open_in_process.is_valid():
		await process_frame
	await create_timer(0.8).timeout
	var view: Rect2 = _opened.get_viewport_rect()
	var panel: Rect2 = (_opened.get("_panel") as Control).get_global_rect()
	_check("a sheet opened before layout still rises fully (top %.0f, bottom %.0f of %.0f)" % [panel.position.y, panel.end.y, view.size.y],
		absf(panel.end.y - view.size.y) < 2.0 and panel.position.y >= 0.0)
	canvas.free()

func _test_sheet_drags_closed() -> void:
	var settings: GDScript = load("res://kit/shell/settings.gd")
	var canvas: CanvasLayer = CanvasLayer.new()
	root.add_child(canvas)
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(host)
	var sheet: Control = settings.call("open", host)
	await create_timer(0.6).timeout
	var panel: Control = sheet.get("_panel")
	var grip: Vector2 = panel.get_global_rect().position + Vector2(panel.size.x * 0.5, 30.0)
	_touch_drag(sheet, grip, grip + Vector2(0.0, 40.0))
	await create_timer(0.4).timeout
	_check("a short drag down springs the sheet back", is_instance_valid(sheet) and is_zero_approx(float(sheet.get("_drop"))))
	_touch_drag(sheet, grip, grip + Vector2(0.0, panel.size.y * 0.6))
	await create_timer(0.5).timeout
	_check("a long drag down closes it", not is_instance_valid(sheet))
	canvas.free()

func _test_levels_swipe() -> void:
	var levels: Node = load(Brand.LEVELS_SCENE).instantiate()
	root.add_child(levels)
	await process_frame
	var first: int = levels.get("_page")
	var step: int = -1 if first > 0 else 1
	var mid: Vector2 = (levels.get("_centre") as Control).get_global_rect().get_center()
	_touch_drag(levels, mid, mid + Vector2(-200.0 * step, 10.0))
	_check("a sideways swipe on the grid turns the page", int(levels.get("_page")) == first + step)
	var pack: Node = root.get_node("Pack")
	# Kit classes are named by string here, since this script compiles before the autoloads they read.
	var switch: Array[Node] = levels.find_children("*", "Segmented", true, false)
	_check("the Levels screen has a switch with the two sets' names alone", switch.size() == 1
		and switch[0].get("options") == PackedStringArray(["Main", "Hard"]))
	if switch.size() == 1:
		switch[0].emit_signal(&"chosen", 1)
		var hard_page: int = int(levels.get("_page"))
		_check("Hard opens on its own first chapter, its chapter 1, and the pages before it are not there",
			hard_page == TiltGenerator.PLATEAU_FROM and int(pack.get("section")) == 1
			and bool((levels.get("_prev") as Node).get("disabled"))
			and (levels.get("_chapter_number") as Label).text.begins_with("CHAPTER 1 "))
		_touch_drag(levels, mid, mid + Vector2(200.0, 10.0))
		_check("so a swipe back from it stays", int(levels.get("_page")) == hard_page)
		switch[0].emit_signal(&"chosen", 0)
		_check("and Main comes back", int(pack.get("section")) == 0)
	levels.queue_free()
	await process_frame

## Sent the way a phone hands a tap over: the mouse button made from the touch, then the touch itself.
func _screen_tap(at: Vector2) -> void:
	var on_screen: Vector2 = root.get_final_transform() * at
	for down: bool in [true, false]:
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		mouse.position = on_screen
		mouse.global_position = on_screen
		root.push_input(mouse)
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.pressed = down
		touch.position = on_screen
		root.push_input(touch)

func _touch_drag(target: Node, from: Vector2, to: Vector2) -> void:
	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.pressed = true
	press.position = from
	target.call("_input", press)
	for k: int in range(1, 6):
		var move: InputEventScreenDrag = InputEventScreenDrag.new()
		move.position = from.lerp(to, k / 5.0)
		target.call("_input", move)
	var lift: InputEventScreenTouch = InputEventScreenTouch.new()
	lift.position = to
	target.call("_input", lift)

class _ConsentAds extends AdBackend:
	func privacy_required() -> bool:
		return true

class _VideoAds extends AdBackend:
	func ready_to_show(_kind: StringName) -> bool:
		return true

	func video_ready() -> bool:
		return true

	func present(kind: StringName) -> void:
		finished.emit.call_deferred(kind, true, true)
