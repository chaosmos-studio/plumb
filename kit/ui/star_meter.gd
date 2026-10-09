class_name StarMeter
extends HBoxContainer

## The most this attempt can still earn. A star that goes out shrinks back into its outline, so the moment
## it is lost is felt rather than read.

const STAR: float = 30.0
## The height of a Stat's number, so the meter sits level with a count beside it.
const HEIGHT: float = 50.0

var _stars: Array[StarIcon] = []

func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: int in range(3):
		var star: StarIcon = StarIcon.new(STAR, true)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(star)
		_stars.append(star)

func lit() -> int:
	var n: int = 0
	for star: StarIcon in _stars:
		n += 1 if star.filled else 0
	return n

func set_stars(n: int) -> void:
	for k: int in range(_stars.size()):
		var star: StarIcon = _stars[k]
		var on: bool = k < n
		if star.filled == on:
			continue
		star.filled = on
		star.pivot_offset = Vector2(STAR, STAR) * 0.5
		star.scale = Vector2(1.35, 1.35) if not on else Vector2(0.6, 0.6)
		star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
