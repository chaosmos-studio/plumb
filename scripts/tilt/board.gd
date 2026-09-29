class_name TiltBoard
extends RefCounted

## The whole game as data: a grid of cells, coloured holes, and marbles. Tilting moves every marble at
## once, one cell per step, until nothing can move. A marble drops into a hole of its own colour the
## moment it rolls over it, and a pit swallows any marble, which loses the level.
##
## Pure logic with no nodes, so the solver, the level generator and the tests all run the exact rules
## the player sees.

enum Cell { FLOOR, WALL, PIT }

const NO_HOLE: int = -1
const GONE: int = -1

const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const LEFT: int = 0
const RIGHT: int = 1
const UP: int = 2
const DOWN: int = 3

var width: int = 0
var height: int = 0
var cells: PackedByteArray = PackedByteArray()
## The colour of the hole in each cell, or NO_HOLE.
var holes: PackedInt32Array = PackedInt32Array()
## Cell index of each marble, or GONE once it has dropped into a hole or a pit.
var marble_cell: PackedInt32Array = PackedInt32Array()
var marble_colour: PackedInt32Array = PackedInt32Array()
var lost: bool = false

static func create(w: int, h: int) -> TiltBoard:
	var board: TiltBoard = TiltBoard.new()
	board.width = w
	board.height = h
	board.cells.resize(w * h)
	board.cells.fill(Cell.FLOOR)
	board.holes.resize(w * h)
	board.holes.fill(NO_HOLE)
	return board

func index(at: Vector2i) -> int:
	return at.y * width + at.x

func coords(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)

func inside(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < width and at.y < height

func add_marble(at: Vector2i, colour: int) -> void:
	marble_cell.append(index(at))
	marble_colour.append(colour)

func marbles_left() -> int:
	var n: int = 0
	for c: int in marble_cell:
		if c != GONE:
			n += 1
	return n

func is_won() -> bool:
	return not lost and marbles_left() == 0

func copy() -> TiltBoard:
	var b: TiltBoard = TiltBoard.new()
	b.width = width
	b.height = height
	b.cells = cells.duplicate()
	b.holes = holes.duplicate()
	b.marble_cell = marble_cell.duplicate()
	b.marble_colour = marble_colour.duplicate()
	b.lost = lost
	return b

## Tilts the board in `dir` and returns what happened, step by step, for the animation. The board is
## changed in place. Marbles are advanced front first, so a line of marbles rolls as a train rather
## than the back one waiting a step for the front one to clear.
func tilt(dir: int) -> TiltMove:
	var move: TiltMove = TiltMove.new()
	move.dir = dir
	var d: Vector2i = DIRS[dir]
	var stride: int = d.x + d.y * width
	var occupied: PackedInt32Array = PackedInt32Array()
	occupied.resize(cells.size())
	occupied.fill(-1)
	# Front first: the marble furthest along the direction of travel moves before the ones behind it.
	# An insertion sort, stable, as the few marbles on a board need.
	var order: PackedInt32Array = PackedInt32Array()
	var ahead: PackedInt32Array = PackedInt32Array()
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c == GONE:
			continue
		occupied[c] = m
		var along: int = (c % width) * d.x + (c / width) * d.y
		var k: int = order.size()
		order.append(m)
		ahead.append(along)
		while k > 0 and ahead[k - 1] < along:
			order[k] = order[k - 1]
			ahead[k] = ahead[k - 1]
			k -= 1
		order[k] = m
		ahead[k] = along
	var rolled: PackedByteArray = PackedByteArray()
	rolled.resize(marble_cell.size())
	var step: int = 0
	while true:
		var moved: Array[int] = []
		for m: int in order:
			var from: int = marble_cell[m]
			if from == GONE:
				continue
			var x: int = from % width + d.x
			var y: int = from / width + d.y
			if x < 0 or y < 0 or x >= width or y >= height:
				continue
			var to: int = from + stride
			if cells[to] == Cell.WALL or occupied[to] >= 0:
				continue
			occupied[from] = -1
			marble_cell[m] = to
			rolled[m] = 1
			moved.append(m)
			if cells[to] == Cell.PIT:
				marble_cell[m] = GONE
				lost = true
				move.events.append({"step": step, "marble": m, "kind": &"pit", "cell": to})
			elif holes[to] == marble_colour[m]:
				marble_cell[m] = GONE
				move.events.append({"step": step, "marble": m, "kind": &"sink", "cell": to})
			else:
				occupied[to] = m
		if moved.is_empty():
			break
		move.steps.append(moved)
		step += 1
	for m: int in order:
		if marble_cell[m] != GONE and rolled[m] == 1:
			move.stopped.append(m)
	return move

## A compact, order-independent key for the solver: the sorted list of (cell, colour) of live marbles.
func key() -> String:
	var parts: PackedInt32Array = PackedInt32Array()
	for m: int in range(marble_cell.size()):
		if marble_cell[m] != GONE:
			parts.append(marble_cell[m] * 16 + marble_colour[m])
	parts.sort()
	var text: PackedStringArray = PackedStringArray()
	for v: int in parts:
		text.append(str(v))
	return ",".join(text)

func to_dict() -> Dictionary:
	var rows: Array[String] = []
	for y: int in range(height):
		var row: String = ""
		for x: int in range(width):
			var i: int = index(Vector2i(x, y))
			match cells[i]:
				Cell.WALL:
					row += "#"
				Cell.PIT:
					row += "x"
				_:
					row += "." if holes[i] == NO_HOLE else str(holes[i])
		rows.append(row)
	var marbles: Array = []
	for m: int in range(marble_cell.size()):
		var at: Vector2i = coords(marble_cell[m])
		marbles.append([at.x, at.y, marble_colour[m]])
	return {"rows": rows, "marbles": marbles}

## Rows are strings: `.` floor, `#` wall, `x` pit, a digit is a hole of that colour.
static func from_dict(data: Dictionary) -> TiltBoard:
	var rows: Array = data["rows"]
	var board: TiltBoard = create(String(rows[0]).length(), rows.size())
	for y: int in range(board.height):
		var row: String = rows[y]
		for x: int in range(board.width):
			var ch: String = row[x]
			var i: int = board.index(Vector2i(x, y))
			if ch == "#":
				board.cells[i] = Cell.WALL
			elif ch == "x":
				board.cells[i] = Cell.PIT
			elif ch.is_valid_int():
				board.holes[i] = int(ch)
	for entry: Variant in data["marbles"]:
		var e: Array = entry
		board.add_marble(Vector2i(int(e[0]), int(e[1])), int(e[2]))
	return board
