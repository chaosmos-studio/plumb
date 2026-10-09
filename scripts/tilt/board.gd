class_name TiltBoard
extends RefCounted

## Each tile's rule is in CHAPTERS.md, and how a tilt resolves in MATH.md sections 1 and 8 to 10.

enum Cell { FLOOR, WALL, PIT }
enum Tile { NONE, STOP, GATE, DOOR, PAINT, CRACK, PORTAL, BUMPER, SWITCH, HATCH, KEY, LOCK, BLINK, CONVEYOR, SPRING,
	MAGNET, GLASS }
## What a lasting change was, kept as cell * Change.size() + kind.
enum Change { CRACK, PLUG, FILL, KEY, GLASS }

const NO_HOLE: int = -1
const GONE: int = -1
const STONE: int = 9
## Tiles by the name the level file gives them, in Tile order.
const TILE_NAMES: Array[String] = ["", "stop", "gate", "door", "paint", "crack", "portal", "bumper", "switch",
	"hatch", "key", "lock", "blink", "conveyor", "spring", "magnet", "glass"]
const PLUG_NAME: String = "plug"
const ICE_NAME: String = "ice"
const WRAP_X: int = 1
const WRAP_Y: int = 2
## A quarter clockwise from each direction, indexed like DIRS.
const CLOCKWISE: Array[int] = [UP, DOWN, RIGHT, LEFT]
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
var holes: PackedInt32Array = PackedInt32Array()
var tiles: PackedByteArray = PackedByteArray()
## A gate's direction (an index into DIRS), a door's, paint pad's, key's or lock's colour, a portal's pair,
## a bumper's slant, or the pair a switch and its hatch share.
var tile_value: PackedByteArray = PackedByteArray()
var plugs: PackedByteArray = PackedByteArray()
var ice: PackedByteArray = PackedByteArray()
var marble_cell: PackedInt32Array = PackedInt32Array()
var marble_colour: PackedInt32Array = PackedInt32Array()
## A numbered marble's number (they drop in order, lowest first), or 0.
var marble_number: PackedInt32Array = PackedInt32Array()
var lost: bool = false
## Lasting changes play has made (Change), which the solver's key has to tell apart.
var changes: PackedInt32Array = PackedInt32Array()
## WRAP_X and WRAP_Y bits.
var wrap: int = 0
## The direction this board cannot be tilted now, or -1. It turns a quarter clockwise after every tilt
## that changes something.
var locked: int = -1
## Tilts that moved something, counted mod 2: a blinking wall whose value equals it is up.
var beat: int = 0
## Whether the board has a blinking wall, so the solver's key carries `beat` only where it matters.
var blinks: bool = false

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
	board.ice.resize(w * h)
	return board

func index(at: Vector2i) -> int:
	return at.y * width + at.x

func coords(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)

func inside(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < width and at.y < height

func add_marble(at: Vector2i, colour: int, number: int = 0) -> void:
	marble_cell.append(index(at))
	marble_colour.append(colour)
	marble_number.append(number)

func is_stone(m: int) -> bool:
	return marble_colour[m] == STONE

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
	b.ice = ice.duplicate()
	b.marble_cell = marble_cell.duplicate()
	b.marble_colour = marble_colour.duplicate()
	b.marble_number = marble_number.duplicate()
	b.lost = lost
	b.changes = changes.duplicate()
	b.wrap = wrap
	b.locked = locked
	b.beat = beat
	b.blinks = blinks
	return b

func set_tile(at: Vector2i, tile: Tile, value: int = 0) -> void:
	tiles[index(at)] = tile
	tile_value[index(at)] = value
	blinks = blinks or tile == Tile.BLINK

## Leaves aside other marbles. `open` and `up` are this tilt's held_open() and raised().
func enterable(to: int, m: int, dir: int, open: PackedByteArray = PackedByteArray(),
		up: PackedByteArray = PackedByteArray()) -> bool:
	if cells[to] == Cell.WALL:
		return false
	match tiles[to]:
		Tile.GATE:
			return tile_value[to] == dir
		Tile.DOOR:
			return tile_value[to] == marble_colour[m]
		Tile.HATCH:
			return tile_value[to] < open.size() and open[tile_value[to]] == 1
		Tile.LOCK, Tile.MAGNET, Tile.GLASS:
			return false
		Tile.BLINK:
			return up.is_empty() or up[to] == 0
	return true

## A blinking wall never rises under a marble or a stone.
func raised() -> PackedByteArray:
	var up: PackedByteArray = PackedByteArray()
	if not blinks:
		return up
	up.resize(cells.size())
	for i: int in range(tiles.size()):
		if tiles[i] == Tile.BLINK and tile_value[i] == beat:
			up[i] = 1
	for c: int in marble_cell:
		if c != GONE:
			up[c] = 0
	return up

func in_turn(m: int) -> bool:
	var n: int = marble_number[m]
	if n == 0:
		return true
	for k: int in range(marble_cell.size()):
		if marble_cell[k] != GONE and marble_number[k] > 0 and marble_number[k] < n:
			return false
	return true

func cell_along(from: int, h: Vector2i, reach: int) -> int:
	var x: int = from % width + h.x * reach
	var y: int = from / width + h.y * reach
	if wrap & WRAP_X:
		x = posmod(x, width)
	if wrap & WRAP_Y:
		y = posmod(y, height)
	if x < 0 or y < 0 or x >= width or y >= height:
		return -1
	return y * width + x

func _beside_magnet(cell: int) -> bool:
	var at: Vector2i = coords(cell)
	for d: Vector2i in DIRS:
		var next: Vector2i = at + d
		if inside(next) and tiles[index(next)] == Tile.MAGNET:
			return true
	return false

## Switches are read as the tilt starts, not step by step (MATH.md section 9).
func held_open() -> PackedByteArray:
	var open: PackedByteArray = PackedByteArray()
	open.resize(16)
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c != GONE and tiles[c] == Tile.SWITCH:
			open[tile_value[c]] = 1
	return open

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

## "/" sends a marble rolling right up, "\" sends it down.
static func deflect(dir: int, slant: int) -> int:
	var d: Vector2i = DIRS[dir]
	var turned: Vector2i = Vector2i(-d.y, -d.x) if slant == SLASH else Vector2i(d.y, d.x)
	return DIRS.find(turned)

## Changes the board in place (MATH.md sections 1, 9 and 10).
func tilt(dir: int) -> TiltMove:
	var move: TiltMove = TiltMove.new()
	move.dir = dir
	if dir == locked:
		return move
	var count: int = marble_cell.size()
	var occupied: PackedInt32Array = PackedInt32Array()
	occupied.resize(cells.size())
	occupied.fill(-1)
	# Front first, by a stable insertion sort, the fastest for a few marbles (MATH.md section 1).
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
	# Includes a marble back on a cell it crossed heading the same way, so loops end (MATH.md section 9).
	var halted: PackedByteArray = PackedByteArray()
	halted.resize(count)
	var seen: Dictionary = {}
	# Round a wrapping edge a marble can come back to where it began: it stops there.
	if wrap != 0:
		for m: int in order:
			seen[(m * cells.size() + marble_cell[m]) * 4 + dir] = true
	var open: PackedByteArray = held_open()
	var up: PackedByteArray = raised()
	var twin: Dictionary = twins()
	var struck: PackedByteArray = PackedByteArray()
	struck.resize(cells.size())
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
				var reach: int = 2 if tiles[from] == Tile.SPRING else 1
				var to: int = cell_along(from, h, reach)
				if to < 0:
					continue
				if tiles[to] == Tile.GLASS:
					struck[to] = 1
					continue
				if occupied[to] >= 0 or not enterable(to, m, heading[m], open, up):
					continue
				var lands: int = to
				if tiles[to] == Tile.PORTAL:
					lands = int(twin.get(to, -1))
					# A portal whose twin is taken is shut.
					if lands < 0 or occupied[lands] >= 0:
						continue
					move.events.append({"step": step, "marble": m, "kind": &"portal", "cell": to, "to": lands})
				if reach == 2:
					move.events.append({"step": step, "marble": m, "kind": &"jump", "cell": from, "to": to})
				if not inside(coords(from) + h * reach):
					move.events.append({"step": step, "marble": m, "kind": &"wrap", "cell": from, "to": to})
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
			if _carry(heading, halted):
				continue
			break
		move.steps.append(moved)
		move.cells.append(landed)
		step += 1
	_settle(step, move, struck)
	for m: int in order:
		if marble_cell[m] != GONE and rolled[m] == 1:
			move.stopped.append(m)
	if move.changed():
		beat = 1 - beat
		if locked >= 0:
			locked = CLOCKWISE[locked]
	return move

## A turn alone changes nothing: only the rolling it starts does.
func _carry(heading: PackedInt32Array, halted: PackedByteArray) -> bool:
	var turned: bool = false
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c == GONE or halted[m] == 1 or tiles[c] != Tile.CONVEYOR or heading[m] == tile_value[c]:
			continue
		heading[m] = tile_value[c]
		turned = true
	return turned

func _settle(step: int, move: TiltMove, struck: PackedByteArray) -> void:
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c != GONE and holes[c] == marble_colour[m] and (ice[c] == 1 or marble_number[m] > 0) and in_turn(m):
			_sink(m, c, step, move)
			move.settled = true
	for i: int in range(struck.size()):
		if struck[i] == 1:
			tiles[i] = Tile.NONE
			changes.append(i * Change.size() + Change.GLASS)
			move.settled = true
			move.events.append({"step": step, "marble": -1, "kind": &"shatter", "cell": i})

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
	if holes[cell] == marble_colour[m] and ice[cell] == 0 and in_turn(m):
		_sink(m, cell, step, move)
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
	if _beside_magnet(cell):
		halted[m] = 1
	var state: int = (m * cells.size() + cell) * 4 + heading[m]
	if seen.has(state):
		halted[m] = 1
	seen[state] = true

func _sink(m: int, cell: int, step: int, move: TiltMove) -> void:
	marble_cell[m] = GONE
	move.events.append({"step": step, "marble": m, "kind": &"sink", "cell": cell})
	if plugs[cell] == 1:
		holes[cell] = NO_HOLE
		plugs[cell] = 0
		changes.append(cell * Change.size() + Change.PLUG)
		move.events.append({"step": step, "marble": m, "kind": &"plug", "cell": cell})

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

func _give_way(cell: int, step: int, move: TiltMove) -> void:
	cells[cell] = Cell.PIT
	tiles[cell] = Tile.NONE
	changes.append(cell * Change.size() + Change.CRACK)
	move.events.append({"step": step, "marble": -1, "kind": &"crack", "cell": cell})

## Sorted, so identical marbles in swapped places are one state (MATH.md sections 2 and 8).
func key() -> String:
	var parts: PackedInt32Array = PackedInt32Array()
	for m: int in range(marble_cell.size()):
		if marble_cell[m] != GONE:
			parts.append((marble_cell[m] * 16 + marble_colour[m]) * 8 + marble_number[m])
	parts.sort()
	var text: PackedStringArray = PackedStringArray()
	for v: int in parts:
		text.append(str(v))
	var out: String = ",".join(text)
	if not changes.is_empty():
		var lasting: PackedInt32Array = changes.duplicate()
		lasting.sort()
		var tail: PackedStringArray = PackedStringArray()
		for v: int in lasting:
			tail.append(str(v))
		out += "|" + ",".join(tail)
	return out + ("|b%d" % beat if blinks else "") + ("|l%d" % locked if locked >= 0 else "")

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
		var entry: Array = [at.x, at.y, marble_colour[m]]
		if marble_number[m] > 0:
			entry.append(marble_number[m])
		marbles.append(entry)
	var out: Dictionary = {"rows": rows, "marbles": marbles}
	var extra: Array = []
	for i: int in range(cells.size()):
		var at: Vector2i = coords(i)
		if tiles[i] != Tile.NONE:
			extra.append([at.x, at.y, TILE_NAMES[tiles[i]], tile_value[i]])
		if plugs[i] == 1:
			extra.append([at.x, at.y, PLUG_NAME, 0])
		if ice[i] == 1:
			extra.append([at.x, at.y, ICE_NAME, 0])
	if not extra.is_empty():
		out["tiles"] = extra
	if wrap != 0:
		out["wrap"] = wrap
	if locked >= 0:
		out["locked"] = locked
	return out

## Rows are strings: `.` floor, `#` wall, `x` pit, a digit is a hole of that colour. Marbles are [x, y,
## colour] or [x, y, colour, number], a stone's colour being STONE. An optional "tiles" list holds [x, y,
## name, value] for each tile (TILE_NAMES), each plug and each ice hole. "wrap" holds the wrapping edges
## and "locked" the direction the board cannot be tilted.
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
		board.add_marble(Vector2i(int(e[0]), int(e[1])), int(e[2]), int(e[3]) if e.size() > 3 else 0)
	var extra: Array = data.get("tiles", [])
	for entry: Variant in extra:
		var t: Array = entry
		var at: Vector2i = Vector2i(int(t[0]), int(t[1]))
		match String(t[2]):
			PLUG_NAME:
				board.plugs[board.index(at)] = 1
			ICE_NAME:
				board.ice[board.index(at)] = 1
			_:
				board.set_tile(at, TILE_NAMES.find(String(t[2])) as Tile, int(t[3]))
	board.wrap = int(data.get("wrap", 0))
	board.locked = int(data.get("locked", -1))
	return board
