class_name StreetSky
extends Node2D

## The sky over the street: Codex's gradient stretched to the screen, the sun, clouds drifting slowly across, and the
## far hills sitting on the horizon (REVAMP_PLAN.md section 10). The ground is drawn over the hills' foot.

const SKY: String = "res://assets/street/sky.png"
const HILLS: String = "res://assets/street/hills.png"
## The sun's place, as shares of the screen, and its size beside its painting.
const SUN_AT: Vector2 = Vector2(0.84, 0.065)
const SUN_SCALE: float = 0.62
## The sun turns this fast, in radians a second.
const SUN_SPIN: float = 0.12
## Clouds: their height as a share of the space above the horizon, their size, and their drift in pixels a second.
const CLOUDS: Array = [[0.12, 0.62, 7.0, 0.05], [0.42, 0.44, 4.5, 0.55], [0.72, 0.36, 3.0, 0.3]]
## The hills' size beside their painting, and how far below the horizon their foot sits, in design pixels.
const HILLS_SCALE: float = 0.62
const HILLS_SINK: float = 26.0

var horizon_y: float = 400.0
## The area it fills, in its own units, where that is not the screen: the map's world on a wide screen is scaled.
var area: Vector2 = Vector2.ZERO
## The sun first, then each cloud: its tap wobble, and where it was last drawn (middle and reach) for taps.
var _springs: Array[Jiggle] = [Jiggle.new(), Jiggle.new(), Jiggle.new(), Jiggle.new()]
var _spots: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
var _sky: Texture2D
var _hills: Texture2D
var _t: float = 0.0

func _ready() -> void:
	_sky = load(SKY)
	_hills = load(HILLS)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _process(delta: float) -> void:
	if not Save.reduce_motion:
		_t += delta
	for spring: Jiggle in _springs:
		spring.step(delta)
	queue_redraw()

## A tap at `at`, in this node's units: the sun or a cloud under it wobbles. Answers whether one did.
func poke(at: Vector2) -> bool:
	for i: int in range(_spots.size()):
		var spot: Vector3 = _spots[i]
		if at.distance_to(Vector2(spot.x, spot.y)) < spot.z:
			if not Save.reduce_motion:
				_springs[i].kick()
			Audio.buzz(StreetWobbler.BUZZ_MS, StreetWobbler.BUZZ)
			return true
	return false

func _draw() -> void:
	var size: Vector2 = area if area != Vector2.ZERO else get_viewport_rect().size
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, Vector2(size.x, maxf(horizon_y + 40.0, 1.0))), false)
	# The sun turns slowly, and it and each cloud wobble about their middles when tapped.
	var sun_at: Vector2 = Vector2(size.x * SUN_AT.x, size.y * SUN_AT.y + StreetArt.size("sun").y * 0.5 * SUN_SCALE)
	_spots[0] = Vector3(sun_at.x, sun_at.y, StreetArt.size("sun").x * SUN_SCALE * 0.5)
	draw_set_transform(sun_at, _springs[0].tilt() + _t * SUN_SPIN, _springs[0].squash())
	StreetArt.draw(self, "sun", Vector2.ZERO, SUN_SCALE)
	for k: int in range(CLOUDS.size()):
		var c: Array = CLOUDS[k]
		var piece: String = "cloud_%d" % (1 + k)
		var w: float = StreetArt.size(piece).x * float(c[1])
		var span: float = size.x + w
		var x: float = fposmod(float(c[3]) * span + _t * float(c[2]), span) - w * 0.5
		var at: Vector2 = Vector2(x, maxf(horizon_y, 0.0) * float(c[0]) + 30.0)
		_spots[k + 1] = Vector3(at.x, at.y, w * 0.5)
		draw_set_transform(at, _springs[k + 1].tilt(), _springs[k + 1].squash())
		StreetArt.draw(self, piece, Vector2.ZERO, float(c[1]))
	draw_set_transform(Vector2.ZERO)
	var hill_size: Vector2 = Vector2(_hills.get_width(), _hills.get_height()) * StreetArt.DESIGN_PER_PIXEL * HILLS_SCALE
	var top: float = horizon_y + HILLS_SINK - hill_size.y
	draw_texture_rect_region(_hills, Rect2(Vector2(-hill_size.x * 0.2, top), Vector2(size.x + hill_size.x * 0.4,
		hill_size.y)), Rect2(Vector2.ZERO, Vector2(_hills.get_width() * (size.x + hill_size.x * 0.4) / hill_size.x,
		_hills.get_height())))
