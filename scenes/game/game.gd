extends Node2D

# Starter 2D scene. Stickman Climber's layout: world in Node2D, UI in a CanvasLayer so it ignores the
# camera. A Control directly under a CanvasLayer is not fitted to the viewport for you, so the HUD root is
# sized explicitly, or anchored children (a pause button) land off screen.

func _ready() -> void:
	var camera: Camera2D = Camera2D.new()
	add_child(camera)
	camera.make_current()

	var ui: CanvasLayer = CanvasLayer.new()
	add_child(ui)
	var hud: Control = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hud.size = get_viewport().get_visible_rect().size
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	EventBus.game_started.emit()
