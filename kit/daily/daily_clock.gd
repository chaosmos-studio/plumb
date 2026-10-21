class_name DailyClock
extends Label

## Counts from the moment the board is on screen. It stops while the app is in the background, and the time
## spent on a day not solved yet is saved now and then, so closing the game never resets it.

const SAVE_EVERY: float = 10.0
const SIZE: int = 40

var _day: int
var _base: int
var _from: int = -1
var _stopped: bool = false
var _since_save: float = 0.0

func _init(d: int, already: int) -> void:
	_day = d
	_base = already
	add_theme_font_override("font", UI.display_font())
	add_theme_font_size_override("font_size", SIZE)
	add_theme_color_override("font_color", Brand.INK)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = DailyDays.clock(_base)

func _ready() -> void:
	_from = Time.get_ticks_msec()

func ms() -> int:
	return _base + (Time.get_ticks_msec() - _from if _from >= 0 and not _stopped else 0)

func stop() -> int:
	if not _stopped:
		_base = ms()
		_stopped = true
	text = DailyDays.clock(_base)
	return _base

func _process(delta: float) -> void:
	if _stopped:
		return
	text = DailyDays.clock(ms())
	_since_save += delta
	if _since_save >= SAVE_EVERY:
		_since_save = 0.0
		Daily.keep_time(_day, ms())

func _notification(what: int) -> void:
	if _stopped:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _from >= 0:
			_base = ms()
			_from = -1
			Daily.keep_time(_day, _base)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if _from < 0 and is_inside_tree():
			_from = Time.get_ticks_msec()
	elif what == NOTIFICATION_EXIT_TREE:
		Daily.keep_time(_day, ms())
