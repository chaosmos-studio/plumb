class_name Stat
extends VBoxContainer

## A number with a small spaced caption over it: MOVES 3, PAR 5. The quiet way to show a count.

var value: Label

func _init(caption_text: String, initial: String = "", size_px: int = 40) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UI.caption(caption_text, 18))
	value = UI.title(initial, size_px)
	add_child(value)

func set_value(text: String) -> void:
	value.text = text
