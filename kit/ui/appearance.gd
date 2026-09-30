class_name Appearance
extends RefCounted

## Light or dark. Each game's Brand holds two palettes and names the one it was designed in; the player
## keeps that, picks the other, or lets the phone decide. Every screen reads Brand while it builds, so a
## change rebuilds the current screen rather than repainting it piece by piece.
##
## The kit expects from the game: `Brand.use(dark)`, `Brand.NATIVE_DARK`, `Save.theme` and
## `Save.set_theme(choice)`, and `EventBus.theme_changed` for anything that outlives a screen.

enum Choice { AUTO, LIGHT, DARK }

const NAMES: PackedStringArray = ["Auto", "Light", "Dark"]

static var dark: bool = false
## Set by a screen that is rebuilding itself, read back by the new copy of it (see `rebuild`).
static var kept: Variant = null
static var _watcher: Node

## The choice a new player starts with: the look the game was designed in.
static func native() -> int:
	return Choice.DARK if Brand.NATIVE_DARK else Choice.LIGHT

## Whether a choice means dark. AUTO follows the system where it can tell, else the game's own look.
static func resolve(choice: int) -> bool:
	match choice:
		Choice.LIGHT:
			return false
		Choice.DARK:
			return true
	if DisplayServer.is_dark_mode_supported():
		return DisplayServer.is_dark_mode()
	return Brand.NATIVE_DARK

## Switches every colour the kit and the game read. Screens built after this use the new palette.
static func apply(choice: int) -> void:
	dark = resolve(choice)
	Brand.use(dark)
	UI.reset_theme()
	RenderingServer.set_default_clear_color(Brand.BG)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if _watcher == null and tree != null and DisplayServer.get_name() != "headless":
		_watcher = _Watcher.new()
		tree.root.add_child.call_deferred(_watcher)
	EventBus.theme_changed.emit()

## The player's pick from Settings: saved, applied, and the screen rebuilt around them.
static func choose(choice: int, tree: SceneTree, reopen: Callable = Callable()) -> void:
	Save.set_theme(choice)
	if resolve(choice) == dark:
		return
	apply(choice)
	await rebuild(tree, reopen)

## Builds the current screen again in the current palette. A screen with state worth keeping, such as a
## level half played, offers it from `keep()` and finds it in `Appearance.take()` when it is rebuilt.
static func rebuild(tree: SceneTree, reopen: Callable = Callable()) -> void:
	var scene: Node = tree.current_scene
	if scene == null or scene.scene_file_path == "":
		return
	kept = scene.call("keep") if scene.has_method("keep") else null
	await Screens.go(scene.scene_file_path)
	if reopen.is_valid() and tree.current_scene != null:
		reopen.call(tree.current_scene)

## What the screen before a rebuild kept, handed over once.
static func take() -> Variant:
	var state: Variant = kept
	kept = null
	return state

static func _on_system_change() -> void:
	if Save.theme != Choice.AUTO or resolve(Choice.AUTO) == dark:
		return
	apply(Choice.AUTO)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		rebuild(tree)

## Holds the system theme callback for as long as the app runs. The callback must be cleared before the
## engine shuts down, or DisplayServer calls into freed script state on quit and the process aborts, so a
## node in the tree owns it and lets go when it leaves.
class _Watcher extends Node:
	func _ready() -> void:
		DisplayServer.set_system_theme_change_callback(_changed)

	func _exit_tree() -> void:
		DisplayServer.set_system_theme_change_callback(Callable())

	func _changed() -> void:
		Appearance._on_system_change.call_deferred()
