class_name TiltBoard
extends RefCounted

## The whole game as data: a grid of cells, coloured holes, and marbles. Tilting moves every marble at
## once, one cell per step, until nothing can move. A marble drops into a hole of its own colour the
## moment it rolls over it, and a pit swallows any marble, which loses the level.
##
## A floor cell can also carry a tile, each a chapter's rule: a stop pad halts a marble that rolls onto
## it, a gate lets marbles in only one way, a door only its own colour, a paint pad repaints a marble that
## crosses it, and cracked floor gives way, becoming a pit, once a marble has rolled off it. A portal sends
## a marble out of its twin still rolling the same way, a bumper turns it a quarter, a hatch is open only
## while something rests on its switch, and a key opens every lock of its colour for good. A hole can be a
## plug, which closes into floor once it has taken a marble.
##
## A stone moves like a marble but is never taken by a hole, and fills the pit it rolls into. Stones are
## kept with the marbles, in the colour STONE, and need not leave the board to win.
##
## Pure logic with no nodes, so the solver, the level generator and the tests all run the exact rules
## the player sees.

enum Cell { FLOOR, WALL, PIT }
enum Tile { NONE, STOP, GATE, DOOR, PAINT, CRACK, PORTAL, BUMPER, SWITCH, HATCH, KEY, LOCK }
## What a lasting change was, kept as cell * Change.size() + kind.
enum Change { CRACK, PLUG, FILL, KEY }

const NO_HOLE: int = -1
const GONE: int = -1
const STONE: int = 9
## Tiles by the name the level file gives them, in Tile order.
const TILE_NAMES: Array[String] = ["", "stop", "gate", "door", "paint", "crack", "portal", "bumper", "switch",
	"hatch", "key", "lock"]
const PLUG_NAME: String = "plug"
## A bumper's two slants.
const SLASH: int = 0
const BACKSLASH: int = 1

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
## A gate's direction (an index into DIRS); a door's, paint pad's, key's or lock's colour; a portal's pair;
## a bumper's slant; the pair a switch and its hatch share.
var tile_value: PackedByteArray = PackedByteArray()
## 1 where a hole is a plug.
var plugs: PackedByteArray = PackedByteArray()
## Cell index of each marble, or GONE once it has dropped into a hole or a pit.
var marble_cell: PackedInt32Array = PackedInt32Array()
var marble_colour: PackedInt32Array = PackedInt32Array()
var lost: bool = false
## The lasting changes play has made, which the solver's key has to tell apart (Change): cracked floor
## that gave way, a plug that closed, a pit a stone filled, a key that was used.
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

func is_stone(m: int) -> bool:
	return marble_colour[m] == STONE

## Marbles still to drop in; stones are not counted.
func marbles_left() -> int:
	var n: int = 0
	for m: int in range(marble_cell.size()):
		if marble_cell[m] != GONE and marble_colour[m] != STONE:
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

## Whether a marble heading `dir` may roll onto cell `to`, leaving aside other marbles. `open` holds 1 for
## each hatch pair whose switch is held this tilt.
func enterable(to: int, m: int, dir: int, open: PackedByteArray = PackedByteArray()) -> bool:
	if cells[to] == Cell.WALL:
		return false
	match tiles[to]:
		Tile.GATE:
			return tile_value[to] == dir
		Tile.DOOR:
			return tile_value[to] == marble_colour[m]
		Tile.HATCH:
			return tile_value[to] < open.size() and open[tile_value[to]] == 1
		Tile.LOCK:
			return false
	return true

## The hatch pairs held open for a tilt: any marble or stone resting on their switch as it starts.
func held_open() -> PackedByteArray:
	var open: PackedByteArray = PackedByteArray()
	open.resize(16)
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c != GONE and tiles[c] == Tile.SWITCH:
			open[tile_value[c]] = 1
	return open

## Each portal's twin, by cell.
func twins() -> Dictionary:
	var first: Dictionary = {}
	var out: Dictionary = {}
	for i: int in range(tiles.size()):
		if tiles[i] != Tile.PORTAL:
			continue
		var pair: int = tile_value[i]
		if first.has(pair):
			out[i] = first[pair]
			out[first[pair]] = i
		else:
			first[pair] = i
	return out

## The heading a bumper of `slant` turns `dir` into: "/" sends a marble rolling right up, "\" sends it down.
static func deflect(dir: int, slant: int) -> int:
	var d: Vector2i = DIRS[dir]
	var turned: Vector2i = Vector2i(-d.y, -d.x) if slant == SLASH else Vector2i(d.y, d.x)
	return DIRS.find(turned)

## Tilts the board in `dir` and returns what happened, step by step, for the animation. The board is
## changed in place. Every marble starts heading `dir` and keeps its heading until a bumper turns it. On
## each step every marble that can advances one cell, a marble moving into a cell another has just left
## included, so a line of marbles rolls as a train rather than the back one waiting a step for the front
## one to clear.
func tilt(dir: int) -> TiltMove:
	var move: TiltMove = TiltMove.new()
	move.dir = dir
	var count: int = marble_cell.size()
	var occupied: PackedInt32Array = PackedInt32Array()
	occupied.resize(cells.size())
	occupied.fill(-1)
	# Front first: the marble furthest along the direction of travel tries before the ones behind it.
	# An insertion sort, stable, as the few marbles on a board need.
	var d: Vector2i = DIRS[dir]
	var order: PackedInt32Array = PackedInt32Array()
	var ahead: PackedInt32Array = PackedInt32Array()
	for m: int in range(count):
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
	var heading: PackedInt32Array = PackedInt32Array()
	heading.resize(count)
	heading.fill(dir)
	var rolled: PackedByteArray = PackedByteArray()
	rolled.resize(count)
	# Marbles that rolled onto a stop pad, or came round to where they were heading the same way before,
	# which only bumpers and portals together can do: they are done for this tilt.
	var halted: PackedByteArray = PackedByteArray()
	halted.resize(count)
	var seen: Dictionary = {}
	var open: PackedByteArray = held_open()
	var twin: Dictionary = twins()
	var step: int = 0
	while true:
		var moved: Array[int] = []
		var landed: PackedInt32Array = PackedInt32Array()
		var went: PackedByteArray = PackedByteArray()
		went.resize(count)
		var progress: bool = true
		while progress:
			progress = false
			for m: int in order:
				var from: int = marble_cell[m]
				if from == GONE or halted[m] == 1 or went[m] == 1:
					continue
				var h: Vector2i = DIRS[heading[m]]
				var x: int = from % width + h.x
				var y: int = from / width + h.y
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				var to: int = y * width + x
				if occupied[to] >= 0 or not enterable(to, m, heading[m], open):
					continue
				var lands: int = to
				if tiles[to] == Tile.PORTAL:
					lands = int(twin.get(to, -1))
					# A portal whose twin is taken is shut.
					if lands < 0 or occupied[lands] >= 0:
						continue
					move.events.append({"step": step, "marble": m, "kind": &"portal", "cell": to, "to": lands})
				occupied[from] = -1
				marble_cell[m] = lands
				rolled[m] = 1
				went[m] = 1
				progress = true
				moved.append(m)
				landed.append(lands)
				if tiles[from] == Tile.CRACK:
					_give_way(from, step, move)
				_arrive(m, lands, step, move, occupied, halted, heading, seen)
		if moved.is_empty():
			break
		move.steps.append(moved)
		move.cells.append(landed)
		step += 1
	for m: int in order:
		if marble_cell[m] != GONE and rolled[m] == 1:
			move.stopped.append(m)
	return move

## What a cell does to the marble that has just arrived on it.
func _arrive(m: int, cell: int, step: int, move: TiltMove, occupied: PackedInt32Array, halted: PackedByteArray,
		heading: PackedInt32Array, seen: Dictionary) -> void:
	if cells[cell] == Cell.PIT:
		marble_cell[m] = GONE
		if is_stone(m):
			cells[cell] = Cell.FLOOR
			changes.append(cell * Change.size() + Change.FILL)
			move.events.append({"step": step, "marble": m, "kind": &"fill", "cell": cell})
		else:
			lost = true
			move.events.append({"step": step, "marble": m, "kind": &"pit", "cell": cell})
		return
	if holes[cell] == marble_colour[m]:
		marble_cell[m] = GONE
		move.events.append({"step": step, "marble": m, "kind": &"sink", "cell": cell})
		if plugs[cell] == 1:
			holes[cell] = NO_HOLE
			plugs[cell] = 0
			changes.append(cell * Change.size() + Change.PLUG)
			move.events.append({"step": step, "marble": m, "kind": &"plug", "cell": cell})
		return
	occupied[cell] = m
	match tiles[cell]:
		Tile.STOP:
			halted[m] = 1
		Tile.PAINT:
			if not is_stone(m) and marble_colour[m] != tile_value[cell]:
				marble_colour[m] = tile_value[cell]
				move.events.append({"step": step, "marble": m, "kind": &"paint", "cell": cell,
					"colour": tile_value[cell]})
		Tile.BUMPER:
			heading[m] = deflect(heading[m], tile_value[cell])
			move.events.append({"step": step, "marble": m, "kind": &"bounce", "cell": cell})
		Tile.KEY:
			_unlock(cell, step, move)
	var state: int = (m * cells.size() + cell) * 4 + heading[m]
	if seen.has(state):
		halted[m] = 1
	seen[state] = true

## A key that something rolled onto opens every lock of its colour, and is used up.
func _unlock(cell: int, step: int, move: TiltMove) -> void:
	var colour: int = tile_value[cell]
	tiles[cell] = Tile.NONE
	changes.append(cell * Change.size() + Change.KEY)
	var opened: PackedInt32Array = PackedInt32Array()
	for i: int in range(tiles.size()):
		if tiles[i] == Tile.LOCK and tile_value[i] == colour:
			tiles[i] = Tile.NONE
			opened.append(i)
	move.events.append({"step": step, "marble": -1, "kind": &"key", "cell": cell, "colour": colour, "opened": opened})

## Cracked floor that a marble has rolled off becomes a pit, and stays one.
func _give_way(cell: int, step: int, move: TiltMove) -> void:
	cells[cell] = Cell.PIT
	tiles[cell] = Tile.NONE
	changes.append(cell * Change.size() + Change.CRACK)
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

## Rows are strings: `.` floor, `#` wall, `x` pit, a digit is a hole of that colour. Marbles are [x, y,
## colour], a stone's colour being STONE. An optional "tiles" list holds [x, y, name, value] for each tile
## (TILE_NAMES) and each plug.
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
