class_name TiltNovelty
extends RefCounted

## When two levels are the same level to a player. A board seen rotated or mirrored is the same board,
## and so is one with its colours swapped, so every comparison is taken over the eight symmetries of the
## grid and ignores colour. Two boards of one size are too close when they differ in too few cells, or
## when they differ in a few more but one route of tilts solves both.

## Symmetries are numbered by three bits: 1 mirrors x, 2 mirrors y, 4 swaps the axes first.
const SYMMETRIES: int = 8
## Boards closer than this share of their cells are one layout, whatever their solutions.
const LAYOUT_SHARE: float = 0.3
## Boards closer than this share that one route solves are the same level played twice.
const ROUTE_SHARE: float = 0.5

enum Kind { FLOOR, WALL, PIT, HOLE, MARBLE, MARBLE_ON_HOLE, PLUG, STOP, GATE, DOOR, PAINT, CRACK, PORTAL, BUMPER,
	SWITCH, HATCH, KEY, LOCK, STONE }
## The layout kind of each TiltBoard.Tile, colour and direction aside.
const TILE_KINDS: Array[int] = [Kind.FLOOR, Kind.STOP, Kind.GATE, Kind.DOOR, Kind.PAINT, Kind.CRACK, Kind.PORTAL,
	Kind.BUMPER, Kind.SWITCH, Kind.HATCH, Kind.KEY, Kind.LOCK]

## A board's eight views, each as the colour-blind kind of every cell, ready for fast comparison.
class Views:
	var board: TiltBoard
	var path: PackedInt32Array
	var widths: PackedInt32Array = PackedInt32Array()
	var layouts: Array[PackedByteArray] = []

	func _init(b: TiltBoard, solution: PackedInt32Array) -> void:
		board = b
		path = solution
		for s: int in range(SYMMETRIES):
			var t: TiltBoard = TiltNovelty.transform(b, s)
			widths.append(t.width)
			layouts.append(TiltNovelty.layout(t))

static func views(board: TiltBoard, solution: PackedInt32Array) -> Views:
	return Views.new(board, solution)

static func layout_limit(cells: int) -> int:
	return int(ceil(cells * LAYOUT_SHARE))

static func route_limit(cells: int) -> int:
	return int(ceil(cells * ROUTE_SHARE))

## Whether `b` would feel like a replay of `a`: the reason as a short word, or "" if it is new.
static func clash(a: Views, b: Views) -> String:
	var cells: int = a.layouts[0].size()
	if b.layouts[0].size() != cells:
		return ""
	var near: int = layout_limit(cells)
	var route: int = route_limit(cells)
	for s: int in range(SYMMETRIES):
		if b.widths[s] != a.widths[0]:
			continue
		var d: int = hamming(a.layouts[0], b.layouts[s])
		if d < near:
			return "layout"
		if d < route and a.path.size() == b.path.size() and _shares_route(a, b, s):
			return "route"
	return ""

## One board's solution, turned into the other's frame, clears the other too.
static func _shares_route(a: Views, b: Views, s: int) -> bool:
	var turned: TiltBoard = transform(b.board, s)
	var b_path: PackedInt32Array = PackedInt32Array()
	for dir: int in b.path:
		b_path.append(transform_dir(dir, s))
	return _clears(turned, a.path) or _clears(a.board, b_path)

static func _clears(start: TiltBoard, path: PackedInt32Array) -> bool:
	var board: TiltBoard = start.copy()
	for dir: int in path:
		board.tilt(dir)
		if board.lost:
			return false
	return board.is_won()

static func hamming(a: PackedByteArray, b: PackedByteArray) -> int:
	var d: int = 0
	for i: int in range(a.size()):
		if a[i] != b[i]:
			d += 1
	return d

static func layout(board: TiltBoard) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(board.cells.size())
	for i: int in range(board.cells.size()):
		match board.cells[i]:
			TiltBoard.Cell.WALL:
				out[i] = Kind.WALL
			TiltBoard.Cell.PIT:
				out[i] = Kind.PIT
			_:
				if board.holes[i] != TiltBoard.NO_HOLE:
					out[i] = Kind.PLUG if board.plugs[i] == 1 else Kind.HOLE
				else:
					out[i] = TILE_KINDS[board.tiles[i]]
	for m: int in range(board.marble_cell.size()):
		var c: int = board.marble_cell[m]
		if c == TiltBoard.GONE:
			continue
		if board.is_stone(m):
			out[c] = Kind.STONE
		else:
			out[c] = Kind.MARBLE_ON_HOLE if out[c] == Kind.HOLE or out[c] == Kind.PLUG else Kind.MARBLE
	return out

## The board under symmetry `s`, marbles and all.
static func transform(board: TiltBoard, s: int) -> TiltBoard:
	var swap: bool = s & 4 != 0
	var w: int = board.height if swap else board.width
	var h: int = board.width if swap else board.height
	var out: TiltBoard = TiltBoard.create(w, h)
	for i: int in range(board.cells.size()):
		var j: int = out.index(_map(board.coords(i), s, w, h))
		out.cells[j] = board.cells[i]
		out.holes[j] = board.holes[i]
		out.plugs[j] = board.plugs[i]
		out.tiles[j] = board.tiles[i]
		match board.tiles[i]:
			TiltBoard.Tile.GATE:
				out.tile_value[j] = transform_dir(board.tile_value[i], s)
			TiltBoard.Tile.BUMPER:
				# Mirroring one axis turns "/" into "\"; swapping the axes keeps each slant.
				var flips: bool = (s & 1 != 0) != (s & 2 != 0)
				out.tile_value[j] = 1 - board.tile_value[i] if flips else board.tile_value[i]
			_:
				out.tile_value[j] = board.tile_value[i]
	for m: int in range(board.marble_cell.size()):
		if board.marble_cell[m] != TiltBoard.GONE:
			out.add_marble(_map(board.coords(board.marble_cell[m]), s, w, h), board.marble_colour[m])
	return out

static func transform_dir(dir: int, s: int) -> int:
	var d: Vector2i = TiltBoard.DIRS[dir]
	if s & 4:
		d = Vector2i(d.y, d.x)
	if s & 1:
		d.x = -d.x
	if s & 2:
		d.y = -d.y
	return TiltBoard.DIRS.find(d)

static func _map(at: Vector2i, s: int, w: int, h: int) -> Vector2i:
	var p: Vector2i = Vector2i(at.y, at.x) if s & 4 else at
	if s & 1:
		p.x = w - 1 - p.x
	if s & 2:
		p.y = h - 1 - p.y
	return p

## A key that two boards share exactly when one is the other turned, mirrored or recoloured.
static func canonical(board: TiltBoard) -> String:
	var best: String = ""
	for s: int in range(SYMMETRIES):
		var t: TiltBoard = transform(board, s)
		var marble_at: Dictionary = {}
		for m: int in range(t.marble_cell.size()):
			marble_at[t.marble_cell[m]] = t.marble_colour[m]
		var relabel: Dictionary = {}
		var text: String = "%dx%d:" % [t.width, t.height]
		for i: int in range(t.cells.size()):
			match t.cells[i]:
				TiltBoard.Cell.WALL:
					text += "#"
				TiltBoard.Cell.PIT:
					text += "x"
				_:
					text += "." if t.holes[i] == TiltBoard.NO_HOLE else _label(relabel, t.holes[i])
			if t.plugs[i] == 1:
				text += "u"
			match t.tiles[i]:
				TiltBoard.Tile.STOP:
					text += "s"
				TiltBoard.Tile.GATE:
					text += "g" + str(t.tile_value[i])
				TiltBoard.Tile.DOOR:
					text += "d" + _label(relabel, t.tile_value[i])
				TiltBoard.Tile.PAINT:
					text += "p" + _label(relabel, t.tile_value[i])
				TiltBoard.Tile.CRACK:
					text += "k"
				TiltBoard.Tile.PORTAL:
					text += "w"
				TiltBoard.Tile.BUMPER:
					text += "b" + str(t.tile_value[i])
				TiltBoard.Tile.SWITCH:
					text += "z"
				TiltBoard.Tile.HATCH:
					text += "h"
				TiltBoard.Tile.KEY:
					text += "y" + _label(relabel, t.tile_value[i])
				TiltBoard.Tile.LOCK:
					text += "l" + _label(relabel, t.tile_value[i])
			if marble_at.has(i):
				var colour: int = int(marble_at[i])
				text += "r" if colour == TiltBoard.STONE else "o" + _label(relabel, colour)
		if best == "" or text < best:
			best = text
	return best

static func _label(relabel: Dictionary, colour: int) -> String:
	if not relabel.has(colour):
		relabel[colour] = relabel.size()
	return str(relabel[colour])
