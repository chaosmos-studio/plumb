class_name AppLook
extends RefCounted

## The two looks of one game (REVAMP_PLAN.md section 3.3): Street, the new one, and Classic, today's. A player picks
## once on first launch and can switch in Settings, and their progress is the same in both.

const STREET: String = "street"
const CLASSIC: String = "classic"
const CHOOSER_SCENE: String = "res://scenes/street/chooser.tscn"
const MAP_SCENE: String = "res://scenes/street/map.tscn"

static func valid(look: String) -> bool:
	return look == STREET or look == CLASSIC

## Whether this build can show Street. The web build's slim engine (kit/web) leaves out what Street needs (the
## chooser's live previews in SubViewportContainers, the crypto module, interactive music), so the web build is Classic
## only, as it always was: no chooser, no Street, and no switch to it.
static func street_available() -> bool:
	return not web

## True in the web build. Tests set it to check the web build's way through.
static var web: bool = OS.has_feature("web")

## The look this build opens in: the saved one, or Classic where Street is not available.
static func effective(look: String) -> String:
	return look if street_available() else CLASSIC

## Where the game opens: the chooser until a look has been chosen, then that look's Home.
static func first_scene(look: String, chosen: bool) -> String:
	if not street_available():
		return Brand.TITLE_SCENE
	if not chosen or not valid(look):
		return CHOOSER_SCENE
	return MAP_SCENE if look == STREET else Brand.TITLE_SCENE

## Puts the look's screen rule in place (StreetLayout): Street turns and composes wide screens, Classic keeps its own.
## The chooser counts as Street, since it is drawn in Street's world.
static func use(look: String) -> void:
	# Street is light only for 2.0 (REVAMP_PLAN.md section 15, item 14), so its Settings have no Theme row.
	Settings.hide_theme = look != CLASSIC
	if look == CLASSIC:
		StreetLayout.stop()
	else:
		StreetLayout.start()

## Home in the look being played.
static func home_scene(look: String) -> String:
	return Brand.TITLE_SCENE if effective(look) == CLASSIC else MAP_SCENE
