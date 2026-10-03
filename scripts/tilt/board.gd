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
## Later chapters add: blinking walls, up on every other tilt that moves something; conveyors, which once
## the board stops carry a marble resting on them their way; springs, which jump a marble leaving them
## over the next cell; magnets, which stop a marble that arrives beside them; glass posts, which stop a
## marble once and shatter; ice holes, which take only a marble resting on them when the board stops;
## numbered marbles, which drop only in order; edges that wrap round; and a lock on one direction the
## board cannot be tilted, which turns a quarter clockwise after every tilt.
##
## Pure logic with no nodes, so the solver, the level generator and the tests all run the exact rules
## the player sees.

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
## `wrap` bits: left and right edges joined, top and bottom joined.
const WRAP_X: int = 1
const WRAP_Y: int = 2
## The direction a quarter clockwise from each of DIRS: left to up, right to down, up to right, down to left.
const CLOCKWISE: Array[int] = [UP, DOWN, RIGHT, LEFT]
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
## 1 where a hole is an ice hole.
var ice: PackedByteArray = PackedByteArray()
## Cell index of each marble, or GONE once it has dropped into a hole or a pit.
var marble_cell: PackedInt32Array = PackedInt32Array()
var marble_colour: PackedInt32Array = PackedInt32Array()
## A numbered marble's number (they drop in order, lowest first), or 0.
var marble_number: PackedInt32Array = PackedInt32Array()
var lost: bool = false
## The lasting changes play has made, which the solver's key has to tell apart (Change): cracked floor
## that gave way, a plug that closed, a pit a stone filled, a key that was used, glass that shattered.
var changes: PackedInt32Array = PackedInt32Array()
## Which edges wrap round (WRAP_X, WRAP_Y).
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

## Whether a marble heading `dir` may roll onto cell `to`, leaving aside other marbles. `open` holds 1 for
## each hatch pair whose switch is held this tilt, `up` 1 on each blinking wall that is up.
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

## The blinking walls that are up for the coming tilt: those whose value is the beat, unless a marble or a
## stone rests on one, since a wall never rises under something.
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

## Whether marble m may drop into its hole now: unnumbered, or every lower number is already in.
func in_turn(m: int) -> bool:
	var n: int = marble_number[m]
	if n == 0:
		return true
	for k: int in range(marble_cell.size()):
		if marble_cell[k] != GONE and marble_number[k] > 0 and marble_number[k] < n:
			return false
	return true

## The cell `reach` cells along `h` from `from`, round any edge that wraps, or -1 off the board.
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
## one to clear. When nothing can move, a marble resting on a conveyor that does not already head its way
## is turned to it and the board rolls on; once nothing turns, ice holes take what rests on them, struck
## glass shatters, and the beat moves on if anything happened. The locked direction does nothing.
func tilt(dir: int) -> TiltMove:
	var move: TiltMove = TiltMove.new()
	move.dir = dir
	if dir == locked:
		return move
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

## Turns every marble resting on a conveyor, and not yet heading its way, to the conveyor's way. Whether
## any turned, so the board rolls on. A turn alone changes nothing: only the rolling it starts does.
func _carry(heading: PackedInt32Array, halted: PackedByteArray) -> bool:
	var turned: bool = false
	for m: int in range(marble_cell.size()):
		var c: int = marble_cell[m]
		if c == GONE or halted[m] == 1 or tiles[c] != Tile.CONVEYOR or heading[m] == tile_value[c]:
			continue
		heading[m] = tile_value[c]
		turned = true
	return turned

## What happens once the board has stopped: marbles resting on their own ice hole drop in, and so does a
## numbered marble waiting on its hole whose turn has come; glass that a marble struck shatters into floor.
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

## Marble m drops into the hole at `cell`, and a plug closes behind it.
func _sink(m: int, cell: int, step: int, move: TiltMove) -> void:
	marble_cell[m] = GONE
	move.events.append({"step": step, "marble": m, "kind": &"sink", "cell": cell})
	if plugs[cell] == 1:
		holes[cell] = NO_HOLE
		plugs[cell] = 0
		changes.append(cell * Change.size() + Change.PLUG)
		move.events.append({"step": step, "marble": m, "kind": &"plug", "cell": cell})

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

## A compact, order-independent key for the solver: the sorted list of (cell, colour, number) of live
## marbles, then the sorted lasting changes, since two boards with the marbles in the same places differ if
## a crack gave way or a plug closed on one of them, and on a board with blinking walls the beat, and with a
## lock the way it faces.
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
## name, value] for each tile (TILE_NAMES), each plug and each ice hole; "wrap" holds the wrapping edges
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
