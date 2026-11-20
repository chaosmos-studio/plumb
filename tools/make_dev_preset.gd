extends SceneTree

# Adds or refreshes the "Android Dev" export preset: a copy of the Android APK preset under its own package, so a dev
# build installs beside the live Plumb on a phone and never touches its progress. Debug-signed, arm64 only, and with
# the dev_build feature, which keeps Play Games off (no Play Games project knows the dev package).
#
# Run: godot --headless --path . -s res://tools/make_dev_preset.gd

const PRESETS: String = "res://export_presets.cfg"
const SOURCE_NAME: String = "Android APK"
const NAME: String = "Android Dev"
const PACKAGE: String = "com.shravangoswami.plumb.dev"
const LABEL: String = "Plumb Dev"
const FEATURES: String = "dev_build"
const EXPORT_PATH: String = "build/android/plumb-dev.apk"
## Every build opens on the boot scene, which picks the chooser or a look's Home.
const MAIN_SCENE: String = "res://scenes/boot/boot.tscn"

func _initialize() -> void:
	var presets: ConfigFile = ConfigFile.new()
	if presets.load(PRESETS) != OK:
		push_error("make_dev_preset: cannot read %s" % PRESETS)
		quit(1)
		return
	var source: String = _find(presets, SOURCE_NAME)
	if source == "":
		push_error("make_dev_preset: no preset named %s" % SOURCE_NAME)
		quit(1)
		return
	var target: String = _find(presets, NAME)
	if target == "":
		target = "preset.%d" % _count(presets)
	for key: String in presets.get_section_keys(source):
		presets.set_value(target, key, presets.get_value(source, key))
	presets.set_value(target, "name", NAME)
	presets.set_value(target, "runnable", false)
	presets.set_value(target, "custom_features", FEATURES)
	presets.set_value(target, "export_path", EXPORT_PATH)
	var options: String = target + ".options"
	for key: String in presets.get_section_keys(source + ".options"):
		presets.set_value(options, key, presets.get_value(source + ".options", key))
	presets.set_value(options, "package/unique_name", PACKAGE)
	presets.set_value(options, "package/name", LABEL)
	presets.set_value(options, "architectures/armeabi-v7a", false)
	presets.set_value(options, "architectures/arm64-v8a", true)
	var status: int = presets.save(PRESETS)
	ProjectSettings.set_setting("application/run/main_scene.street_spike", null)
	ProjectSettings.set_setting("application/run/main_scene", MAIN_SCENE)
	var settings: int = ProjectSettings.save()
	print("make_dev_preset: %s as [%s], save status %d, main scene %s, settings status %d" % [NAME, target, status,
		MAIN_SCENE, settings])
	quit(0 if status == OK and settings == OK else 1)

func _find(presets: ConfigFile, preset_name: String) -> String:
	for section: String in presets.get_sections():
		if not section.ends_with(".options") and String(presets.get_value(section, "name", "")) == preset_name:
			return section
	return ""

func _count(presets: ConfigFile) -> int:
	var n: int = 0
	while presets.has_section("preset.%d" % n):
		n += 1
	return n
