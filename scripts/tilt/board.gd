class_name TiltBoard
extends RefCounted

## The whole game as data: a grid of cells, coloured holes, and marbles. Tilting moves every marble at
## once, one cell per step, until nothing can move. A marble drops into a hole of its own colour the
## moment it rolls over it, and a pit swallows any marble, which loses the level.
##
## A floor cell can also carry a tile, each a chapter's rule: a stop pad halts a marble that rolls onto
## it, a gate lets marbles in only one way, a door only its own colour, a paint pad repaints a marble that
## crosses it, and cracked floor gives way, becoming a pit, once a marble has rolled off it. A hole can be
## a plug, which closes into floor once it has taken a marble.
##
## Pure logic with no nodes, so the solver, the level generator and the tests all run the exact rules
## the player sees.

enum Cell { FLOOR, WALL, PIT }
enum Tile { NONE, STOP, GATE, DOOR, PAINT, CRACK }

const NO_HOLE: int = -1
const GONE: int = -1
## Tiles by the name the level file gives them, in Tile order.
const TILE_NAMES: Array[String] = ["", "stop", "gate", "door", "paint", "crack"]
const PLUG_NAME: String = "plug"

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
## The tile on each cell, a Tile.
var tiles: PackedByteArray = PackedByteArray()
## A gate's direction (an index into DIRS), or a door's or paint pad's colour.
var tile_value: PackedByteArray = PackedByteArray()
## 1 where a hole is a plug.
var plugs: PackedByteArray = PackedByteArray()
## Cell index of each marble, or GONE once it has dropped into a hole or a pit.
var marble_cell: PackedInt32Array = PackedInt32Array()
var marble_colour: PackedInt32Array = PackedInt32Array()
var lost: bool = false
## The lasting changes play has made, which the solver's key has to tell apart: a cell's index times two
## for cracked floor that gave way, plus one for a plug that closed.
var changes: PackedInt32Array = PackedInt32Array()

static func create(w: int, h: int) -> TiltBoard:
	var board: TiltBoard = TiltBoard.new()
	board.width = w
	board.height = h
	board.cells.resize(w * h)
	board.cells.fill(Cell.FLOOR)
	board.holes.resize(w * h)
	board.holes.fill(NO_HOLE)
	board.tiles.resize(w * h)
	board.tile_value.resize(w * h)
	board.plugs.resize(w * h)
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
	b.tiles = tiles.duplicate()
	b.tile_value = tile_value.duplicate()
	b.plugs = plugs.duplicate()
	b.marble_cell = marble_cell.duplicate()
	b.marble_colour = marble_colour.duplicate()
	b.lost = lost
	b.changes = changes.duplicate()
	return b

func set_tile(at: Vector2i, tile: Tile, value: int = 0) -> void:
	tiles[index(at)] = tile
	tile_value[index(at)] = value

## Whether a marble moving in `dir` may roll onto cell `to`, leaving aside other marbles.
func enterable(to: int, m: int, dir: int) -> bool:
	if cells[to] == Cell.WALL:
		return false
	match tiles[to]:
		Tile.GATE:
			return tile_value[to] == dir
		Tile.DOOR:
			return tile_value[to] == marble_colour[m]
	return true

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
	# Marbles that rolled onto a stop pad: they are done for this tilt.
	var halted: PackedByteArray = PackedByteArray()
	halted.resize(marble_cell.size())
	var step: int = 0
	while true:
		var moved: Array[int] = []
		for m: int in order:
			var from: int = marble_cell[m]
			if from == GONE or halted[m] == 1:
				continue
			var x: int = from % width + d.x
			var y: int = from / width + d.y
			if x < 0 or y < 0 or x >= width or y >= height:
				continue
			var to: int = from + stride
			if occupied[to] >= 0 or not enterable(to, m, dir):
				continue
			occupied[from] = -1
			marble_cell[m] = to
			rolled[m] = 1
			moved.append(m)
			if tiles[from] == Tile.CRACK:
				_give_way(from, step, move)
			if cells[to] == Cell.PIT:
				marble_cell[m] = GONE
				lost = true
				move.events.append({"step": step, "marble": m, "kind": &"pit", "cell": to})
			elif holes[to] == marble_colour[m]:
				marble_cell[m] = GONE
				move.events.append({"step": step, "marble": m, "kind": &"sink", "cell": to})
				if plugs[to] == 1:
					holes[to] = NO_HOLE
					plugs[to] = 0
					changes.append(to * 2 + 1)
					move.events.append({"step": step, "marble": m, "kind": &"plug", "cell": to})
			else:
				occupied[to] = m
				match tiles[to]:
					Tile.STOP:
						halted[m] = 1
					Tile.PAINT:
						if marble_colour[m] != tile_value[to]:
							marble_colour[m] = tile_value[to]
							move.events.append({"step": step, "marble": m, "kind": &"paint", "cell": to,
								"colour": tile_value[to]})
		if moved.is_empty():
			break
		move.steps.append(moved)
		step += 1
	for m: int in order:
		if marble_cell[m] != GONE and rolled[m] == 1:
			move.stopped.append(m)
	return move

## Cracked floor that a marble has rolled off becomes a pit, and stays one.
func _give_way(cell: int, step: int, move: TiltMove) -> void:
	cells[cell] = Cell.PIT
	tiles[cell] = Tile.NONE
	changes.append(cell * 2)
	move.events.append({"step": step, "marble": -1, "kind": &"crack", "cell": cell})

## A compact, order-independent key for the solver: the sorted list of (cell, colour) of live marbles,
## then the sorted lasting changes, since two boards with the marbles in the same places differ if a crack
## gave way or a plug closed on one of them.
func key() -> String:
	var parts: PackedInt32Array = PackedInt32Array()
	for m: int in range(marble_cell.size()):
		if marble_cell[m] != GONE:
			parts.append(marble_cell[m] * 16 + marble_colour[m])
	parts.sort()
	var text: PackedStringArray = PackedStringArray()
	for v: int in parts:
		text.append(str(v))
	if changes.is_empty():
		return ",".join(text)
	var lasting: PackedInt32Array = changes.duplicate()
	lasting.sort()
	var tail: PackedStringArray = PackedStringArray()
	for v: int in lasting:
		tail.append(str(v))
	return ",".join(text) + "|" + ",".join(tail)

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
	var out: Dictionary = {"rows": rows, "marbles": marbles}
	var extra: Array = []
	for i: int in range(cells.size()):
		var at: Vector2i = coords(i)
		if tiles[i] != Tile.NONE:
			extra.append([at.x, at.y, TILE_NAMES[tiles[i]], tile_value[i]])
		if plugs[i] == 1:
			extra.append([at.x, at.y, PLUG_NAME, 0])
	if not extra.is_empty():
		out["tiles"] = extra
	return out

## Rows are strings: `.` floor, `#` wall, `x` pit, a digit is a hole of that colour. An optional "tiles"
## list holds [x, y, name, value] for each tile (TILE_NAMES) and each plug.
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
	var extra: Array = data.get("tiles", [])
	for entry: Variant in extra:
		var t: Array = entry
		var at: Vector2i = Vector2i(int(t[0]), int(t[1]))
		if String(t[2]) == PLUG_NAME:
			board.plugs[board.index(at)] = 1
		else:
			board.set_tile(at, TILE_NAMES.find(String(t[2])) as Tile, int(t[3]))
	return board
