@tool
extends EditorPlugin

const ExportPlugin: GDScript = preload("res://addons/intermission/export_plugin.gd")

var _export: EditorExportPlugin

func _enter_tree() -> void:
	var setting: String = ExportPlugin.PROVIDER_SETTING
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, ExportPlugin.DEFAULT_PROVIDER)
	ProjectSettings.set_initial_value(setting, ExportPlugin.DEFAULT_PROVIDER)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(ExportPlugin.PROVIDERS.keys()),
	})
	_export = ExportPlugin.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
