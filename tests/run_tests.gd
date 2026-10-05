extends SceneTree

# Headless tests for the pure logic in scripts/ (no framework dependency). Same shape as Faceplant's.
# Run: godot --headless --path . -s res://tests/run_tests.gd [-- quick]
# CI greps the last line for "0 failed", so keep that wording. `quick` skips re-solving the whole level
# pack, the one slow check, for iterating on everything else; CI always runs it.

const InputMapGen: GDScript = preload("res://tools/make_input_map.gd")
const LevelTool: GDScript = preload("res://tools/generate_levels.gd")
## Google's official test app, which the AdMob plugin also falls back to when the setting is unset.
const ADMOB_SETTINGS: GDScript = preload("res://addons/admob/internal/services/project_settings_service.gd")
const APP_ID_SETTING: String = "admob/general/android/app_id"
## The least contrast each pairing needs, as a WCAG ratio, in both palettes: body text, the quiet
## captions, the primary button's label and the reset warning.
const CONTRAST: Array = [["ink", "bg", 7.0], ["ink", "surface", 7.0], ["muted", "bg", 3.0],
	["muted", "surface", 3.0], ["accent_ink", "accent", 3.0], ["danger", "surface", 3.0]]

var _passed: int = 0
var _failed: int = 0
## Set by a test to open a sheet from _process, which runs just before process_frame: where a tap lands
## on a fast-refresh phone's frame that had no physics step to lay the new sheet out first.
var _open_in_process: Callable = Callable()
var _opened: Control

func _initialize() -> void:
	_test_input_map_is_wired()
	_test_orientation_is_an_int()
	_test_tilt_rules()
	_test_chapter_tiles()
	_test_wave_two_tiles()
	_test_wave_three_tiles()
	_test_solver()
	_test_difficulty()
	_test_novelty()
	_test_serialisation()
	_test_stars()
	if not OS.get_cmdline_user_args().has("quick"):
		_test_level_pack()
	_test_opening()
	_test_appearance()
	_test_contrast()
	_test_themes()
	_test_saved_settings()
	_test_guide_and_ending()
	_test_banner_pacing()
	_test_interstitial_pacing()
	_test_hint_pacing()
	_test_adaptive_banner()
	_test_monetize_ids()
	_test_presets_and_plugins()
	_test_changelog()
	_test_saved_monetization()
	_test_settings_variants()
	_test_about_variants()
	_test_finale_variants()
	_test_support_and_hint_sheets()
	_test_supporter_entry_points()
	_test_shop()
	# The root takes new children only once _initialize has handed control back to the engine.
	await process_frame
	_test_chapter_colours()
	_test_unlocks()
	await _test_passes()
	_test_cheers()
	await _test_win_sheet()
	_test_qr()
	_test_volumes()
	_test_reel_video()
	_test_sheets_fit_a_phone()
	_test_maker_link()
	_test_play_screen_banner()
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

static func _board(rows: Array, marbles: Array) -> TiltBoard:
	return TiltBoard.from_dict({"rows": rows, "marbles": marbles})

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
	# Four bumpers round a wall send a marble round and round: it stops where it came round to.
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
	# Only the conveyor brings the marble home: with it taken off there is no solution, so the rule is needed.
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

	# The pad is the only way to stop above the hole; without it the marble can't get in at all.
	var pad: TiltBoard = _tiled(["....", "#0##"], [[0, 0, 0]], [[1, 0, "stop", 0]])
	_check("a level needs a helping rule when the plain board can't be solved", TiltGenerator.needs(pad, "stop", 2))
	# The gate turns the marble back, so it has to go round: two moves instead of one without it.
	var gate: TiltBoard = _tiled(["0..", "..."], [[2, 0, 0]], [[1, 0, "gate", TiltBoard.RIGHT]])
	_check("and a restricting rule when the plain board solves in fewer moves", TiltGenerator.needs(gate, "gate", 3))
	# Here the pad sits off the marble's path, so the plain board solves just as fast.
	var idle: TiltBoard = _tiled(["...0", "...."], [[0, 0, 0]], [[1, 1, "stop", 0]])
	_check("and does not when the tile changes nothing", not TiltGenerator.needs(idle, "stop", 1))

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

# Every shipped level is re-solved against the current rules. If a rule change alters a par or makes a
# level unsolvable, this fails before a build can ship it. The same measures the generator uses then
# check the set as a whole: no level repeats another, and none is easier than the one before.
func _test_level_pack() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	_check("levels.json parses", typeof(data) == TYPE_DICTIONARY)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var levels: Array = (data as Dictionary)["levels"]
	_check("the pack has every level", levels.size() == TiltGenerator.level_count())
	_check("the pack lists every chapter", _same_chapters((data as Dictionary).get("chapters", []), TiltGenerator.chapter_list()))
	var opens: Dictionary = {}
	var at: int = 0
	for chapter: Dictionary in TiltGenerator.chapter_list():
		opens[at] = true
		at += int(chapter["count"])
	var solver: TiltSolver = TiltSolver.new()
	var boards: Array[TiltBoard] = []
	var measures: Array[TiltDifficulty] = []
	var views: Array[TiltNovelty.Views] = []
	var wrong: Array[int] = []
	for i: int in range(levels.size()):
		var level: Dictionary = levels[i]
		var board: TiltBoard = TiltBoard.from_dict(level)
		var path: PackedInt32Array = solver.solve(board, 100000)
		if path.size() != int(level["par"]):
			wrong.append(i + 1)
		var measure: TiltDifficulty = TiltDifficulty.of(board)
		boards.append(board)
		measures.append(measure)
		views.append(TiltNovelty.views(board, measure.path))
	_check("every level solves in exactly its par (wrong: %s)" % str(wrong), wrong.is_empty())

	var same: Array[String] = []
	var replays: Array[String] = []
	var seen: Dictionary = {}
	for i: int in range(levels.size()):
		var key: String = TiltNovelty.canonical(boards[i])
		if seen.has(key):
			same.append("%d=%d" % [int(seen[key]) + 1, i + 1])
		seen[key] = i
		for j: int in range(i + 1, levels.size()):
			var why: String = TiltNovelty.clash(views[i], views[j])
			if why != "":
				replays.append("%d-%d %s" % [i + 1, j + 1, why])
	_check("no two levels are the same level (%s)" % ", ".join(same), same.is_empty())
	_check("no level is a near replay of another (%s)" % ", ".join(replays), replays.is_empty())

	var easier: Array[int] = []
	var shorter: Array[int] = []
	var less: Array[int] = []
	var tame: Array[int] = []
	var flat: Array[int] = []
	var run: int = 1
	var by_par_from: int = 0
	for c: int in range(TiltGenerator.BY_PAR_FROM):
		by_par_from += TiltGenerator.chapter_size(c)
	for i: int in range(levels.size()):
		if _pits(boards[i]) > 0 and measures[i].risk <= 0.0:
			tame.append(i + 1)
		if i == 0:
			continue
		# From chapter 11 levels ship par first, so bits may start lower when par steps up.
		var by_par: bool = i >= by_par_from
		if measures[i].before(measures[i - 1]) if by_par else measures[i].easier_than(measures[i - 1]):
			easier.append(i + 1)
		if measures[i].par < measures[i - 1].par:
			shorter.append(i + 1)
		run = run + 1 if measures[i].same_as(measures[i - 1], by_par) else 1
		if run > TiltGenerator.RUN:
			flat.append(i + 1)
		# A new chapter's tiles carry some of the load, so its first board may hold less than the last
		# chapter's, as long as it measures no easier. Stones are a rule's mark, not marbles, so in the mixed
		# chapter a board without the stone rule holds no less.
		var a: TiltBoard = boards[i - 1]
		var b: TiltBoard = boards[i]
		if not opens.has(i) and (b.cells.size() < a.cells.size() or b.marbles_left() < a.marbles_left()
				or _colours(b) < _colours(a) or _pits(b) < _pits(a)):
			less.append(i + 1)
	_check("no level is easier than the one before (at: %s)" % str(easier), easier.is_empty())
	_check("par never falls (at: %s)" % str(shorter), shorter.is_empty())
	_check("no more than %d levels in a row are equally hard (at: %s)" % [TiltGenerator.RUN, str(flat)], flat.is_empty())
	_check("within a chapter no level takes away room, a colour, a marble or a pit (at: %s)" % str(less),
		less.is_empty())
	_check("every pit level has a pit in play (not: %s)" % str(tame), tame.is_empty())

# The opening is picked for what its levels show (TiltShowcase), so a rule change that quietly undoes a trait
# fails here, and so does a splice that would touch anything in the level file but the opening.
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

## Whether a chapter list read back from JSON, where every number is a float, matches the generator's.
static func _same_chapters(read: Array, made: Array) -> bool:
	if read.size() != made.size():
		return false
	for c: int in range(made.size()):
		var a: Dictionary = read[c]
		var b: Dictionary = made[c]
		if a.get("name") != b["name"] or a.get("line") != b["line"] or int(a.get("count", -1)) != int(b["count"]):
			return false
	return true

## The marble colours on a board, a stone's grey not among them.
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

## Every colour theme, light and dark, reads as well as the game's own palettes, and so does the board in it.
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

## Every chapter's colour reads on the background and on a card, in every theme, light and dark; the next
## chapter's is always a clearly different hue, and no two chapters share one.
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

# The theme and the guide's state live with the other settings, and survive a restart of the app.
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
	_check("solving the last level ends the game", finale.call("due", last))
	_check("no other level does", not finale.call("due", last - 1))
	var some: PackedByteArray = PackedByteArray()
	some.resize(last + 1)
	some[last] = 2
	save.set("stars", some)
	_check("replaying a solved last level does not", not finale.call("due", last))
	save.set("stars", old_stars)
	save.set("tutorial_seen", old_seen)
	pack.set("levels", old_levels)

# --- Monetization -------------------------------------------------------------------------------------

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

func _test_hint_pacing() -> void:
	_check("the first 15 levels have free hints, then 3 a day",
		AdPacing.FREE_HINT_LEVELS == 15 and AdPacing.DAILY_HINTS == 3)
	_check("level 1's hints are free however many are used", AdPacing.hint_cost(0, 99, false) == AdPacing.Hint.FREE)
	_check("level 15's too", AdPacing.hint_cost(14, 99, false) == AdPacing.Hint.FREE)
	_check("level 16 draws on the day's allowance", AdPacing.hint_cost(15, 0, false) == AdPacing.Hint.ALLOWANCE)
	_check("the third free hint of the day is still free", AdPacing.hint_cost(40, 2, false) == AdPacing.Hint.ALLOWANCE)
	_check("the fourth asks for a video", AdPacing.hint_cost(40, 3, false) == AdPacing.Hint.VIDEO)
	_check("a Supporter's hints are all free", AdPacing.hint_cost(40, 50, true) == AdPacing.Hint.FREE)
	_check("hints left count down to none", AdPacing.hints_left(0) == 3 and AdPacing.hints_left(2) == 1
		and AdPacing.hints_left(3) == 0 and AdPacing.hints_left(7) == 0)
	_check("today's hints count today", AdPacing.used_today("2026-09-30", 2, "2026-09-30") == 2)
	_check("yesterday's hints are forgotten at midnight", AdPacing.used_today("2026-09-29", 3, "2026-09-30") == 0)
	_check("a never-saved day counts none", AdPacing.used_today("", 3, "2026-09-30") == 0)

# The stand-in banner the captures draw has the height Google gives a phone's anchored adaptive banner.
func _test_adaptive_banner() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	_check("a 360 dp phone gets a 56 dp banner", is_equal_approx(ads.call("adaptive_height_dp", 360.0, 800.0), 56.0))
	_check("a 412 dp phone gets 64 dp", is_equal_approx(ads.call("adaptive_height_dp", 412.0, 915.0), 64.0))
	_check("never under 50 dp", is_equal_approx(ads.call("adaptive_height_dp", 240.0, 300.0), 50.0))
	_check("never over 90 dp", is_equal_approx(ads.call("adaptive_height_dp", 1000.0, 1400.0), 90.0))
	_check("never over 15% of a short screen", is_equal_approx(ads.call("adaptive_height_dp", 412.0, 400.0), 60.0))

# The plugin writes the project setting into the manifest (falling back to Google's test app when it is
# unset), so the one the game's code names must be the one that ships.
func _test_monetize_ids() -> void:
	var setting: String = ProjectSettings.get_setting(APP_ID_SETTING, ADMOB_SETTINGS.ANDROID_DEFAULT_APP_ID)
	_check("the manifest's AdMob app id is GameMonetize.APP_ID (%s)" % setting, setting == GameMonetize.APP_ID)
	var app: RegEx = RegEx.create_from_string("^ca-app-pub-\\d{16}~\\d{10}$")
	var unit: RegEx = RegEx.create_from_string("^ca-app-pub-\\d{16}/\\d{10}$")
	_check("the app id is an AdMob app id", app.search(GameMonetize.APP_ID) != null)
	for id: String in [GameMonetize.BANNER_ID, GameMonetize.INTERSTITIAL_ID, GameMonetize.REWARDED_ID]:
		_check("%s is an AdMob unit id" % id, unit.search(id) != null)
	var ids: Array[String] = [GameMonetize.BANNER_ID, GameMonetize.INTERSTITIAL_ID, GameMonetize.REWARDED_ID]
	_check("each placement has its own unit", ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	_check("the Supporter pack is the product 'supporter'", GameMonetize.SUPPORTER_ID == "supporter")

# The Android builds carry the plugins and may reach the network; the web build carries neither plugin.
func _test_presets_and_plugins() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_check("the AdMob plugin is enabled", enabled.has("res://addons/admob/plugin.cfg"))
	_check("the Play billing plugin is enabled", enabled.has("res://addons/GodotGooglePlayBilling/plugin.cfg"))
	_check("the Android binaries are in place, so no build downloads them",
		FileAccess.file_exists("res://addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar")
		and FileAccess.file_exists("res://addons/admob/android/bin/package.gd")
		and FileAccess.file_exists("res://addons/admob/ios/bin/package.gd"))
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
			_check("%s leaves the plugin's samples out" % preset_name, exclude.contains("addons/admob/gdscript/sample/*"))
		elif presets.get_value(section, "platform") == "Web":
			_check("the web build leaves the plugins out", exclude.contains("addons/*")
				and exclude.contains("kit/monetize/android/*"))

# The release workflow names the build, derives Play's version code and fills Play's "What's new" from
# CHANGELOG.md's newest section by these same rules, so a changelog it would refuse fails here first.
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

## The text of every button a kit sheet builds, on a host outside the tree so nothing animates.
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
	supporter.set("on_play", old)

## The maker's name in About and Credits opens his homepage, except on Google Play, where it opens the studio
## page: the homepage has a sponsor link, and Play does not let an app lead to one.
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

## The page the maker's name opens on `opener`'s sheet, or "" when it opens none.
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
	# On Google Play, on the web, for a Supporter, and for an owner of the Complete pack: the title's shop
	# button, then whether one should show. The tip jar is always there, so it shows on Google Play always.
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

## Every label a kit sheet builds, for sheets whose rows are labels inside buttons.
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
	_check("with nothing bought, ads stay, levels open by solving, and only the first look is open",
		not shop.call("ads_off") and not shop.call("levels_open") and not shop.call("looks_open")
		and looks.call("is_open", "classic") and not looks.call("is_open", "gems"))
	_check("a level not reached yet is locked", not save.call("unlocked", 150))
	var sold: PackedStringArray = _labels(shop, "open")
	_check("the shop lists the Complete pack, every pack, the tip jar and Restore", sold.has("Complete pack")
		and sold.has("Supporter pack") and sold.has("Every level") and sold.has(GameLooks.PACK) and sold.has("Themes pack")
		and sold.has("Tip jar") and sold.has("Restore purchases"))
	var themes: GDScript = load("res://kit/ui/themes.gd")
	_check("with nothing bought only the game's own colours are open", not shop.call("themes_open")
		and themes.call("is_open", "own") and not themes.call("is_open", "nord"))
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

## The words on a win: news before praise, and never the same line twice running.
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

## The win sheet's quiet actions, and the replay putting the clock and the controls back.
func _test_win_sheet() -> void:
	var result: GDScript = load("res://kit/shell/result.gd")
	var replay_script: GDScript = load("res://kit/shell/replay.gd")
	var host: Node = Node.new()
	root.add_child(host)
	var moment: Object = (result.get_script_constant_map()["Moment"] as GDScript).new()
	moment.set("level", 3)
	moment.set("summary", "4 moves, goal 4")
	moment.set("before", 3)
	moment.set("watch", func(_reel: bool) -> void: pass)
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
	replay.call("finish")
	await process_frame
	_check("and puts both back when it ends", is_equal_approx(Engine.time_scale, 1.0) and controls.visible)
	var reel: CanvasLayer = replay_script.call("begin", host, moment, 2)
	var framed: PackedStringArray = _texts(reel)
	_check("a reel frames the moves with the game's name, the level and the score", framed.has(Brand.NAME)
		and framed.has("LEVEL 4") and framed.has("4 moves, goal 4"))
	reel.call("beat")
	reel.call("closing")
	await process_frame
	_check("and ends on a card with a code to scan", _texts(reel).has("SCAN TO PLAY")
		and _texts(reel).has("Get %s on Google Play" % Brand.NAME))
	var asked: Array[bool] = [false]
	var card_script: GDScript = replay_script.get_script_constant_map()["_Card"]
	var offered: Control = card_script.new(moment, true, func() -> void: asked[0] = true)
	(reel.get("_root") as Control).add_child(offered)
	await process_frame
	await process_frame
	var save: Button = offered.find_children("*", "Button", true, false)[0]
	_screen_tap(save.get_global_rect().get_center())
	_check("a tap on the end card's Save video asks for the film rather than closing the reel",
		asked[0] and not bool(reel.get("skipping")))
	offered.free()
	await create_timer(1.2).timeout
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	reel.call("_on_input", tap)
	await process_frame
	reel.call("finish")
	await process_frame
	_check("which a tap closes, leaving the board where it was",
		host.get_viewport().canvas_transform == Transform2D.IDENTITY and is_equal_approx(Engine.time_scale, 1.0))
	host.free()

func _texts(node: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: Node in node.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out

## The codes the reel ends on: the right size for the text, and the patterns and format a reader looks for.
func _test_qr() -> void:
	var qr: GDScript = load("res://kit/ui/qr.gd")
	var small: PackedStringArray = qr.call("rows", "hi")
	_check("a short text fits the smallest code", small.size() == 21 and small[0].length() == 21)
	# Loaded, not named: GameShare uses the autoloads, which an import run has not made yet.
	var store: String = load("res://share.gd").get_script_constant_map()["STORE"]
	var rows: PackedStringArray = qr.call("rows", store)
	var n: int = rows.size()
	_check("the store link fits version 8 at level H, 49 modules a side", n == 49)
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

## A saved reel: frames handed over under half the film's rate, so the recorder's time lapse plays them at
## true speed, at a size its encoder takes, and nothing on hand off Android.
func _test_reel_video() -> void:
	var video: GDScript = load("res://kit/shell/reel_video.gd")
	var fps: int = video.get_script_constant_map()["FPS"]
	var fast: float = video.call("rate_for", 5.0)
	var slow: float = video.call("rate_for", 400.0)
	_check("frames go over under half the film's rate, however quick the phone", fast < fps * 0.5 and fast >= slow)
	_check("and never so few that the film stutters", slow >= 4.0)
	var size: Vector2i = video.call("size_for", Vector2i(1080, 2400))
	_check("a 20:9 phone films at 720 by 1600, both multiples of 16", size == Vector2i(720, 1600))
	_check("a film can only be made on Android", not video.call("available"))

## The volume sliders: a square law, 0 as off, saved, and an older save's switches read as volumes.
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
	load("res://kit/shell/settings.gd").call("open", host)
	var sliders: int = host.find_children("*", "Range", true, false).size()
	_check("settings has a slider for the sound, and one for the music where there is music",
		sliders == (2 if Brand.HAS_MUSIC else 1))
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_volumes.cfg"))
	save.call("hear_sound_volume", old[0])
	save.call("hear_music_volume", old[1])
	save.set("path", old[2])

## Chapters open on the gate, and a single level opens with a key that Play delivered.
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

## Packs a video lends for a while: which ones, what they open, for how long, and a key for a video.
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
		_labels(shop, "offer", [GameMonetize.THEMES_ID]).has("Try it for %d hours with a video" % hours))
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

# A line that cannot wrap widens the whole sheet past the screen, as one long credit once did.
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
	# Every sheet that shows a price, with a price as long as Play is likely to give in any currency: a
	# dollar price fits anything, a rupee or peso one is what pushed the tip jar off the screen.
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
	levels.queue_free()
	await process_frame

## A tap at `at` on the canvas, sent through the window the way a phone hands one over: the mouse button
## made from the touch, then the touch itself, pressed and lifted.
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

## A finger pressed at `from`, moved to `to` in a few steps and lifted, handed to `target`'s _input.
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

## An ad network whose consent message asks for privacy choices.
class _ConsentAds extends AdBackend:
	func privacy_required() -> bool:
		return true

## An ad network with a video always ready, and always watched through.
class _VideoAds extends AdBackend:
	func ready_to_show(_kind: StringName) -> bool:
		return true

	func present(kind: StringName) -> void:
		finished.emit.call_deferred(kind, true, true)
