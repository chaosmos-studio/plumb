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
	_test_difficulty()
	_test_novelty()
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
	for i: int in range(levels.size()):
		if _pits(boards[i]) > 0 and measures[i].risk <= 0.0:
			tame.append(i + 1)
		if i == 0:
			continue
		if measures[i].easier_than(measures[i - 1]):
			easier.append(i + 1)
		if measures[i].par < measures[i - 1].par:
			shorter.append(i + 1)
		var a: TiltBoard = boards[i - 1]
		var b: TiltBoard = boards[i]
		if (b.cells.size() < a.cells.size() or b.marble_cell.size() < a.marble_cell.size()
				or _colours(b) < _colours(a) or _pits(b) < _pits(a)):
			less.append(i + 1)
	_check("no level is easier than the one before (at: %s)" % str(easier), easier.is_empty())
	_check("par never falls (at: %s)" % str(shorter), shorter.is_empty())
	_check("no level takes away room, a colour, a marble or a pit (at: %s)" % str(less), less.is_empty())
	_check("every pit level has a pit in play (not: %s)" % str(tame), tame.is_empty())

static func _colours(b: TiltBoard) -> int:
	var seen: Dictionary = {}
	for c: int in b.marble_colour:
		seen[c] = true
	return seen.size()

static func _pits(b: TiltBoard) -> int:
	return b.cells.count(TiltBoard.Cell.PIT)
