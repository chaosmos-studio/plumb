@tool
extends EditorExportPlugin

## Adds the plugin's library and LevelPlay with Unity Ads to an Android build. Needs the Gradle build (Use Gradle
## Build in the Android preset).

## Every version pinned. Unity's own POMs ask for adquality-sdk and coherencelib by a version range, so those two are
## held strictly (Gradle's `!!`), and a newer release inside the range never slips into a build. LevelPlay asks for
## the two Play services libraries, which read the advertising and app set ids.
const DEPENDENCIES: PackedStringArray = [
	"com.unity3d.ads-mediation:mediation-sdk:9.8.0",
	"com.unity3d.ads-mediation:adquality-sdk:9.12.1!!",
	"com.unity3d.ads-mediation:unityads-adapter:5.17.0",
	"com.unity3d.ads:unity-ads:4.22.0",
	"com.unity3d.coherence:coherencelib:0.3.0!!",
	"com.google.android.gms:play-services-ads-identifier:18.3.0",
	"com.google.android.gms:play-services-appset:16.1.0",
]

func _get_name() -> String:
	return "Intermission"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray([library(debug)])

func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return DEPENDENCIES

## Relative to res://addons/, as Godot expects.
static func library(debug: bool) -> String:
	var variant: String = "debug" if debug else "release"
	return "intermission/bin/%s/intermission-%s.aar" % [variant, variant]
