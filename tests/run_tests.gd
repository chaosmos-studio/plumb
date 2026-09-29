extends SceneTree

# Headless tests for the pure logic in scripts/ (no framework dependency). Same shape as Faceplant's.
# Run: godot --headless --path . -s res://tests/run_tests.gd
# CI greps the last line for "0 failed", so keep that wording.

const InputMapGen: GDScript = preload("res://tools/make_input_map.gd")

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	_test_input_map_is_wired()
	_test_orientation_is_an_int()
	print("\n==== TESTS: %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL: ", name)

# An action can exist with zero events, and then every is_action_pressed() silently returns false.
func _test_input_map_is_wired() -> void:
	var table: Dictionary = InputMapGen.bindings()
	for action: String in table:
		_check("action %s exists, re-run tools/make_input_map.gd" % action, InputMap.has_action(action))
		if InputMap.has_action(action):
			_check("action %s has bindings" % action, InputMap.action_get_events(action).size() > 0)

# A string here converts to 0, which is Landscape, whatever the string said.
func _test_orientation_is_an_int() -> void:
	var value: Variant = ProjectSettings.get_setting("display/window/handheld/orientation")
	_check("handheld orientation is stored as an int, re-run tools/configure_project.gd",
		typeof(value) == TYPE_INT)
