class_name Mood
extends RefCounted

## What a marble's face shows, decided from what the board does to it (MATH.md section 17). The board reports
## events and speed. The face reads the eased values below and draws them.

enum Feel { IDLE, ROLL, BUMP, WORRY, FALL, HOME, PARTY, SURPRISE }

## Seconds between blinks, drawn evenly from this range, and how long one lasts. Now and then a blink comes
## twice.
const BLINK_GAP: Vector2 = Vector2(2.2, 5.6)
const BLINK_TIME: float = 0.13
const DOUBLE_BLINK: float = 0.22
## How long a squint on a bump lasts, and the startled look after a bouncy block sends a marble back.
const SQUINT_TIME: float = 0.26
const SURPRISE_TIME: float = 0.55
## Speed, in marble radii a second, above which a marble counts as rolling, and the speed it is smoothed
## over, so the gap between two steps of a roll never flickers the face back to rest.
const ROLL_SPEED: float = 4.0
const SPEED_EASE: float = 10.0
## How fast the drawn values follow their targets, per second. Lids are quicker than the rest of the face.
const EASE: float = 14.0
const LID_EASE: float = 40.0
## A glance toward the tilt, or toward home, lasts about this long.
const GLANCE_TIME: float = 0.7
## Idle glances toward home come every so often, in seconds.
const HOME_GLANCE_GAP: Vector2 = Vector2(4.0, 9.0)
## The memorial after a fall: its full length, the short one it becomes, and how many a session sees in full.
const MEMORIAL_FULL: float = 1.15
const MEMORIAL_SHORT: float = 0.55
const MEMORIAL_FULL_COUNT: int = 3

## The character's resting face: lids (1 open), smile (-1 to 1) and brows (-1 bold to 1 worried).
var rest_open: float = 1.0
var rest_smile: float = 0.5
var rest_brow: float = 0.0

## Drawn values: lids open (0 shut, 1 open), eye size (1 at rest), pupil size, brows, smile, how open the mouth
## is (0 shut, 1 a scream), happy closed eyes (0 to 1) and where the eyes look.
var open: float = 1.0
var wide: float = 1.0
var pupil: float = 1.0
var brow: float = 0.0
var smile: float = 0.5
var gape: float = 0.0
var happy: float = 0.0
var look: Vector2 = Vector2.ZERO

var feel: Feel = Feel.IDLE
var _speed: float = 0.0
var _heading: Vector2 = Vector2.ZERO
var _squint: float = 0.0
var _surprised: float = 0.0
var _worried: bool = false
var _lasting: Feel = Feel.IDLE
var _blink_in: float = 0.0
var _blinking: float = 0.0
var _twice: bool = false
var _glance: Vector2 = Vector2.ZERO
var _glance_left: float = 0.0
var _home: Vector2 = Vector2.ZERO
var _home_in: float = 0.0
var _gaze: Gaze = Gaze.new()
var _dice: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(dice_seed: int = 0) -> void:
	_dice.seed = dice_seed
	_blink_in = _dice.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	_home_in = _dice.randf_range(HOME_GLANCE_GAP.x, HOME_GLANCE_GAP.y)

func set_rest(lids: float, mouth: float, brows: float) -> void:
	rest_open = lids
	rest_smile = mouth
	rest_brow = brows
	open = lids
	smile = mouth
	brow = brows

## Clears every event, as an undo or a restart puts the marble back.
func reset() -> void:
	_lasting = Feel.IDLE
	_worried = false
	_squint = 0.0
	_surprised = 0.0
	_glance_left = 0.0
	_speed = 0.0
	feel = Feel.IDLE
	open = rest_open
	wide = 1.0
	pupil = 1.0
	brow = rest_brow
	smile = rest_smile
	gape = 0.0
	happy = 0.0

## `velocity` in marble radii a second.
func moving(velocity: Vector2, dt: float) -> void:
	_speed = lerpf(_speed, velocity.length(), 1.0 - exp(-SPEED_EASE * dt))
	if velocity.length() > ROLL_SPEED:
		_heading = velocity.normalized()

func bump() -> void:
	_squint = SQUINT_TIME

func surprise() -> void:
	_surprised = SURPRISE_TIME

func worry(on: bool) -> void:
	_worried = on

func fall() -> void:
	_lasting = Feel.FALL

func home() -> void:
	_lasting = Feel.HOME

func party() -> void:
	_lasting = Feel.PARTY

## Looks toward `toward` (a direction with a reach up to 1) for `seconds`.
func glance(toward: Vector2, seconds: float = GLANCE_TIME) -> void:
	_glance = toward.limit_length(1.0)
	_glance_left = seconds

## Where home is from the marble, in radii, for an idle look now and then. Zero for none.
func home_at(d: Vector2) -> void:
	_home = d

func rolling() -> bool:
	return _speed > ROLL_SPEED

## The strongest feeling wins: a fall over going home over a party over worry over surprise over a bump over
## rolling.
func resolve() -> Feel:
	if _lasting != Feel.IDLE:
		return _lasting
	if _worried:
		return Feel.WORRY
	if _surprised > 0.0:
		return Feel.SURPRISE
	if _squint > 0.0:
		return Feel.BUMP
	if rolling():
		return Feel.ROLL
	return Feel.IDLE

func step(dt: float) -> void:
	_squint = maxf(_squint - dt, 0.0)
	_surprised = maxf(_surprised - dt, 0.0)
	_glance_left = maxf(_glance_left - dt, 0.0)
	feel = resolve()
	var t_open: float = rest_open
	var t_wide: float = 1.0
	var t_pupil: float = 1.0
	var t_brow: float = rest_brow
	var t_smile: float = rest_smile
	var t_gape: float = 0.0
	var t_happy: float = 0.0
	var t_look: Vector2 = Vector2.ZERO
	match feel:
		Feel.ROLL:
			t_open = 1.0
			t_wide = 1.18
			t_pupil = 0.85
			t_brow = maxf(rest_brow, 0.2)
			t_smile = 0.15
			t_gape = 0.35
			t_look = _heading * 0.9
		Feel.BUMP:
			t_open = 0.12
			t_brow = -0.4
			t_smile = -0.25
		Feel.SURPRISE:
			# Eyes wide with small pupils, brows up and a round "o": startled, not scared.
			t_open = 1.0
			t_wide = 1.32
			t_pupil = 0.55
			t_brow = 0.75
			t_smile = 0.0
			t_gape = 0.6
			t_look = _heading * 0.6
		Feel.WORRY:
			t_open = 1.0
			t_wide = 1.25
			t_pupil = 0.6
			t_brow = 1.0
			t_smile = -0.7
			t_gape = 0.2
			t_look = _heading * 0.9
		Feel.FALL:
			t_open = 1.0
			t_wide = 1.38
			t_pupil = 0.45
			t_brow = 1.0
			t_smile = 0.0
			t_gape = 1.0
			t_look = Vector2(0.0, -0.8)
		Feel.HOME:
			t_happy = 1.0
			t_smile = 1.0
			t_gape = 0.35
			t_brow = 0.0
		Feel.PARTY:
			t_happy = 1.0
			t_smile = 1.0
			t_gape = 0.55
			t_brow = 0.0
	if feel == Feel.IDLE or feel == Feel.ROLL:
		t_open *= _blink(dt)
		if _glance_left > 0.0:
			t_look = _glance
		elif feel == Feel.IDLE:
			t_look = _idle_look(dt)
	var k: float = 1.0 - exp(-EASE * dt)
	var lid: float = 1.0 - exp(-LID_EASE * dt)
	open = lerpf(open, t_open, lid)
	wide = lerpf(wide, t_wide, k)
	pupil = lerpf(pupil, t_pupil, k)
	brow = lerpf(brow, t_brow, k)
	smile = lerpf(smile, t_smile, k)
	gape = lerpf(gape, t_gape, k)
	happy = lerpf(happy, t_happy, lid)
	_gaze.step(t_look, dt)
	look = _gaze.at

## 1 while the eyes are open and 0 through a blink.
func _blink(dt: float) -> float:
	if _blinking > 0.0:
		_blinking -= dt
		if _blinking <= 0.0:
			if _twice:
				_twice = false
				_blink_in = BLINK_TIME
			else:
				_blink_in = _dice.randf_range(BLINK_GAP.x, BLINK_GAP.y)
		return 0.0
	_blink_in -= dt
	if _blink_in <= 0.0:
		_blinking = BLINK_TIME
		_twice = not _twice and _dice.randf() < DOUBLE_BLINK
		return 0.0
	return 1.0

func _idle_look(dt: float) -> Vector2:
	if _home == Vector2.ZERO:
		return Vector2.ZERO
	_home_in -= dt
	if _home_in <= 0.0:
		_home_in = _dice.randf_range(HOME_GLANCE_GAP.x, HOME_GLANCE_GAP.y)
		glance(Gaze.toward(_home), GLANCE_TIME * 1.4)
	return Vector2.ZERO

## How long the memorial after a fall stays, given how many this session has shown: in full for the first
## few, then short, so a player trying a level again and again is never held up.
static func memorial_length(shown: int) -> float:
	return MEMORIAL_FULL if shown < MEMORIAL_FULL_COUNT else MEMORIAL_SHORT
