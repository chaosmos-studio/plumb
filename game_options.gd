extends RefCounted

static func rows() -> Array[Control]:
	var lines: Array[Control] = []
	if not PhoneTilt.can_feel():
		return lines
	var tip: Switch = Switch.new(Save.phone_tilt)
	tip.toggled.connect(func(on: bool) -> void: Save.set_phone_tilt(on))
	lines.append(Settings.setting_row(&"tilt", "Tilt your phone", tip))
	return lines
