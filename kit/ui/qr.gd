class_name Qr
extends RefCounted

## QR codes, made here so a game can draw one for any link without an image file. `rows(text)` gives the
## module matrix without its quiet zone, one string of 0 and 1 per row, at error correction level H, which
## can lose a third of the code: room for the app icon over the middle. Byte mode, the smallest version
## that holds the text, and of the eight masks the one with the lowest penalty, as ISO/IEC 18004 lays out.
## QrCard draws it.

## Level H's error correction codewords per block, and blocks, by version (index 0 unused).
const ECC_PER_BLOCK: PackedInt32Array = [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28,
	28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
const BLOCKS: PackedInt32Array = [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34,
	30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81]
## Level H in the format bits.
const LEVEL_BITS: int = 2

static var _made: Dictionary = {}

static func rows(text: String) -> PackedStringArray:
	if _made.has(text):
		return _made[text]
	var code: _Code = _Code.new(text.to_utf8_buffer())
	var out: PackedStringArray = PackedStringArray()
	for y: int in range(code.size):
		var row: String = ""
		for x: int in range(code.size):
			row += "1" if code.dark(x, y) else "0"
		out.append(row)
	_made[text] = out
	return out

class _Code extends RefCounted:
	var version: int = 1
	var size: int = 21
	var _dark: PackedByteArray = PackedByteArray()
	var _function: PackedByteArray = PackedByteArray()

	func _init(data: PackedByteArray) -> void:
		var bits: Array[int] = []
		for v: int in range(1, 41):
			version = v
			var count_bits: int = 8 if v < 10 else 16
			if 4 + count_bits + data.size() * 8 <= _data_codewords() * 8:
				break
		size = version * 4 + 17
		_push(bits, 4, 4)
		_push(bits, data.size(), 8 if version < 10 else 16)
		for b: int in data:
			_push(bits, b, 8)
		var capacity: int = _data_codewords() * 8
		_push(bits, 0, mini(4, capacity - bits.size()))
		_push(bits, 0, (8 - bits.size() % 8) % 8)
		var pad: int = 0xEC
		while bits.size() < capacity:
			_push(bits, pad, 8)
			pad = 0x11 if pad == 0xEC else 0xEC
		var codewords: PackedByteArray = PackedByteArray()
		@warning_ignore("integer_division")
		codewords.resize(bits.size() / 8)
		for i: int in range(bits.size()):
			codewords[i >> 3] = codewords[i >> 3] | (bits[i] << (7 - (i & 7)))
		_dark.resize(size * size)
		_function.resize(size * size)
		_draw_function_patterns()
		_draw_codewords(_with_ecc(codewords))
		var best: int = 0
		var least: int = 1 << 30
		for mask: int in range(8):
			_apply_mask(mask)
			_draw_format(mask)
			var penalty: int = _penalty()
			if penalty < least:
				least = penalty
				best = mask
			_apply_mask(mask)
		_apply_mask(best)
		_draw_format(best)

	func dark(x: int, y: int) -> bool:
		return _dark[y * size + x] == 1

	static func _push(bits: Array[int], value: int, length: int) -> void:
		for i: int in range(length - 1, -1, -1):
			bits.append((value >> i) & 1)

	func _raw_modules() -> int:
		var result: int = (16 * version + 128) * version + 64
		if version >= 2:
			@warning_ignore("integer_division")
			var aligns: int = version / 7 + 2
			result -= (25 * aligns - 10) * aligns - 55
			if version >= 7:
				result -= 36
		return result

	func _data_codewords() -> int:
		@warning_ignore("integer_division")
		return _raw_modules() / 8 - Qr.ECC_PER_BLOCK[version] * Qr.BLOCKS[version]

	func _put(x: int, y: int, is_dark: bool) -> void:
		_dark[y * size + x] = 1 if is_dark else 0

	func _set_function(x: int, y: int, is_dark: bool) -> void:
		_put(x, y, is_dark)
		_function[y * size + x] = 1

	func _draw_function_patterns() -> void:
		for i: int in range(size):
			_set_function(6, i, i % 2 == 0)
			_set_function(i, 6, i % 2 == 0)
		for corner: Vector2i in [Vector2i(3, 3), Vector2i(size - 4, 3), Vector2i(3, size - 4)]:
			for dy: int in range(-4, 5):
				for dx: int in range(-4, 5):
					var x: int = corner.x + dx
					var y: int = corner.y + dy
					if x >= 0 and x < size and y >= 0 and y < size:
						var ring: int = maxi(absi(dx), absi(dy))
						_set_function(x, y, ring != 2 and ring != 4)
		var at: PackedInt32Array = _alignment_positions()
		var n: int = at.size()
		for i: int in range(n):
			for j: int in range(n):
				if (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0):
					continue
				for dy: int in range(-2, 3):
					for dx: int in range(-2, 3):
						_set_function(at[i] + dx, at[j] + dy, maxi(absi(dx), absi(dy)) != 1)
		_draw_format(0)
		if version >= 7:
			var rem: int = version
			for k: int in range(12):
				rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
			var bits: int = version << 12 | rem
			for i: int in range(18):
				var bit: bool = ((bits >> i) & 1) == 1
				@warning_ignore("integer_division")
				var b: int = i / 3
				var a: int = size - 11 + i % 3
				_set_function(a, b, bit)
				_set_function(b, a, bit)

	func _alignment_positions() -> PackedInt32Array:
		if version == 1:
			return PackedInt32Array()
		@warning_ignore("integer_division")
		var n: int = version / 7 + 2
		@warning_ignore("integer_division")
		var step: int = (version * 8 + n * 3 + 5) / (n * 4 - 4) * 2
		var out: PackedInt32Array = PackedInt32Array([6])
		for i: int in range(n - 2, -1, -1):
			out.append(size - 7 - i * step)
		return out

	func _draw_format(mask: int) -> void:
		var data: int = Qr.LEVEL_BITS << 3 | mask
		var rem: int = data
		for k: int in range(10):
			rem = (rem << 1) ^ ((rem >> 9) * 0x537)
		var bits: int = (data << 10 | rem) ^ 0x5412
		for i: int in range(6):
			_set_function(8, i, _bit(bits, i))
		_set_function(8, 7, _bit(bits, 6))
		_set_function(8, 8, _bit(bits, 7))
		_set_function(7, 8, _bit(bits, 8))
		for i: int in range(9, 15):
			_set_function(14 - i, 8, _bit(bits, i))
		for i: int in range(8):
			_set_function(size - 1 - i, 8, _bit(bits, i))
		for i: int in range(8, 15):
			_set_function(8, size - 15 + i, _bit(bits, i))
		_set_function(8, size - 8, true)

	static func _bit(value: int, i: int) -> bool:
		return ((value >> i) & 1) == 1

	## The data codewords split into blocks, each followed by its Reed-Solomon codewords, interleaved.
	func _with_ecc(data: PackedByteArray) -> PackedByteArray:
		var blocks: int = Qr.BLOCKS[version]
		var ecc_len: int = Qr.ECC_PER_BLOCK[version]
		@warning_ignore("integer_division")
		var raw: int = _raw_modules() / 8
		var short_blocks: int = blocks - raw % blocks
		@warning_ignore("integer_division")
		var short_len: int = raw / blocks
		var divisor: PackedByteArray = _divisor(ecc_len)
		var made: Array[PackedByteArray] = []
		var k: int = 0
		for i: int in range(blocks):
			var take: int = short_len - ecc_len + (0 if i < short_blocks else 1)
			var block: PackedByteArray = data.slice(k, k + take)
			k += take
			var ecc: PackedByteArray = _remainder(block, divisor)
			if i < short_blocks:
				block.append(0)
			made.append(block + ecc)
		var out: PackedByteArray = PackedByteArray()
		for i: int in range(made[0].size()):
			for j: int in range(made.size()):
				if i != short_len - ecc_len or j >= short_blocks:
					out.append(made[j][i])
		return out

	static func _divisor(degree: int) -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray()
		result.resize(degree)
		result[degree - 1] = 1
		var root: int = 1
		for i: int in range(degree):
			for j: int in range(degree):
				result[j] = _multiply(result[j], root)
				if j + 1 < degree:
					result[j] = result[j] ^ result[j + 1]
			root = _multiply(root, 0x02)
		return result

	static func _remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
		var result: PackedByteArray = PackedByteArray()
		result.resize(divisor.size())
		for b: int in data:
			var factor: int = b ^ result[0]
			result.remove_at(0)
			result.append(0)
			for i: int in range(divisor.size()):
				result[i] = result[i] ^ _multiply(divisor[i], factor)
		return result

	## Multiplication in GF(2^8) modulo the QR polynomial x^8 + x^4 + x^3 + x^2 + 1.
	static func _multiply(x: int, y: int) -> int:
		var z: int = 0
		for i: int in range(7, -1, -1):
			z = (z << 1) ^ ((z >> 7) * 0x11D)
			z ^= ((y >> i) & 1) * x
		return z

	## The codeword bits in the zigzag the standard reads them in: two columns at a time from the right,
	## up and down in turn, skipping the vertical timing column.
	func _draw_codewords(data: PackedByteArray) -> void:
		var i: int = 0
		var right: int = size - 1
		while right >= 1:
			if right == 6:
				right = 5
			for vert: int in range(size):
				for j: int in range(2):
					var x: int = right - j
					var upward: bool = ((right + 1) & 2) == 0
					var y: int = size - 1 - vert if upward else vert
					if _function[y * size + x] == 0 and i < data.size() * 8:
						_put(x, y, _bit(data[i >> 3], 7 - (i & 7)))
						i += 1
			right -= 2

	func _apply_mask(mask: int) -> void:
		for y: int in range(size):
			for x: int in range(size):
				if _function[y * size + x] == 1:
					continue
				var flip: bool = false
				match mask:
					0:
						flip = (x + y) % 2 == 0
					1:
						flip = y % 2 == 0
					2:
						flip = x % 3 == 0
					3:
						flip = (x + y) % 3 == 0
					4:
						@warning_ignore("integer_division")
						flip = (x / 3 + y / 2) % 2 == 0
					5:
						flip = x * y % 2 + x * y % 3 == 0
					6:
						flip = (x * y % 2 + x * y % 3) % 2 == 0
					7:
						flip = ((x + y) % 2 + x * y % 3) % 2 == 0
				if flip:
					_dark[y * size + x] = 1 - _dark[y * size + x]

	## The standard's penalty: runs of five or more in a line, 2 by 2 blocks of one colour, patterns that
	## look like a finder, and a dark share far from half.
	func _penalty() -> int:
		var result: int = 0
		for pass_: int in range(2):
			for a: int in range(size):
				var run_dark: bool = false
				var run: int = 0
				var history: Array[int] = [0, 0, 0, 0, 0, 0, 0]
				for b: int in range(size):
					var here: bool = dark(b, a) if pass_ == 0 else dark(a, b)
					if here == run_dark:
						run += 1
						if run == 5:
							result += 3
						elif run > 5:
							result += 1
					else:
						_add_history(run, history)
						if not run_dark:
							result += _finder_like(history) * 40
						run_dark = here
						run = 1
				if run_dark:
					_add_history(run, history)
					run = 0
				run += size
				_add_history(run, history)
				result += _finder_like(history) * 40
		for y: int in range(size - 1):
			for x: int in range(size - 1):
				var c: bool = dark(x, y)
				if c == dark(x + 1, y) and c == dark(x, y + 1) and c == dark(x + 1, y + 1):
					result += 3
		var darks: int = 0
		for v: int in _dark:
			darks += v
		var total: int = size * size
		@warning_ignore("integer_division")
		var k: int = (absi(darks * 20 - total * 10) + total - 1) / total - 1
		result += k * 10
		return result

	func _add_history(run: int, history: Array[int]) -> void:
		if history[0] == 0:
			run += size
		history.pop_back()
		history.push_front(run)

	static func _finder_like(history: Array[int]) -> int:
		var n: int = history[1]
		var core: bool = n > 0 and history[2] == n and history[3] == n * 3 and history[4] == n and history[5] == n
		return (1 if core and history[0] >= n * 4 and history[6] >= n else 0) \
			+ (1 if core and history[6] >= n * 4 and history[0] >= n else 0)
