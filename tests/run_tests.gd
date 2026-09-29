extends SceneTree

# Headless tests for the pure logic in scripts/ (no framework dependency). Same shape as Faceplant's.
# Run: godot --headless --path . -s res://tests/run_tests.gd
# CI greps the last line for "0 failed", so keep that wording.

const InputMapGen: GDScript = preload("res://tools/make_input_map.gd")

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	_test_input_map_is_wired()
	_test_orientation_is_an_int()
	_test_tilt_rules()
	_test_solver()
	_test_serialisation()
	_test_stars()
	_test_level_pack()
	print("\n==== TESTS: %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

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

	b = _board(["x..0"], [[1, 0, 0]])
	path = solver.solve(b)
	_check("the solver never routes through a pit", path.size() == 1 and path[0] == TiltBoard.RIGHT)

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

# Every shipped level is re-solved against the current rules. If a rule change alters a par or makes a
# level unsolvable, this fails before a build can ship it.
func _test_level_pack() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	_check("levels.json parses", typeof(data) == TYPE_DICTIONARY)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var levels: Array = (data as Dictionary)["levels"]
	_check("the pack has every level", levels.size() == TiltGenerator.level_count())
	var solver: TiltSolver = TiltSolver.new()
	var wrong: Array[int] = []
	for i: int in range(levels.size()):
		var level: Dictionary = levels[i]
		var path: PackedInt32Array = solver.solve(TiltBoard.from_dict(level), 100000)
		if path.size() != int(level["par"]):
			wrong.append(i + 1)
	_check("every level solves in exactly its par (wrong: %s)" % str(wrong), wrong.is_empty())
