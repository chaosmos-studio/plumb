@tool
extends EditorPlugin

const ExportPlugin: GDScript = preload("res://addons/intermission/export_plugin.gd")

var _export: EditorExportPlugin

func _enter_tree() -> void:
	_export = ExportPlugin.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
