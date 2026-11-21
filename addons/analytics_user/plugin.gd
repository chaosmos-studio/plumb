@tool
extends EditorPlugin

## The kit's Analytics sets Firebase user properties through AnalyticsUser.java, which this puts into the Android
## build. Firebase Analytics itself comes with the godotx_firebase plugin.

var _export: _AnalyticsUserBuild

func _enter_tree() -> void:
	_export = _AnalyticsUserBuild.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class _AnalyticsUserBuild extends EditorExportPlugin:
	const SOURCE: String = "res://addons/analytics_user/AnalyticsUser.java"
	const TEMPLATE: String = "res://android/build/build.gradle"
	## The template compiles every Java file under src/main/java, beside its own GodotApp.
	const TARGET: String = "res://android/build/src/main/java/studio/chaosmos/kit/AnalyticsUser.java"

	func _get_name() -> String:
		return "AnalyticsUserBuild"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	# Runs after --install-android-build-template has unpacked the template and before Gradle starts.
	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if not features.has("android") or not FileAccess.file_exists(TEMPLATE):
			return
		var source: String = FileAccess.get_file_as_string(SOURCE)
		if FileAccess.file_exists(TARGET) and FileAccess.get_file_as_string(TARGET) == source:
			return
		DirAccess.make_dir_recursive_absolute(TARGET.get_base_dir())
		var file: FileAccess = FileAccess.open(TARGET, FileAccess.WRITE)
		if file == null:
			push_error("AnalyticsUserBuild: cannot write %s" % TARGET)
			return
		file.store_string(source)
		print("AnalyticsUserBuild: added %s to the Android build template" % TARGET.get_file())
