extends CanvasLayer

# Every scene change happens under the party's red circle (Celebration.cover), so a change never flashes a
# half-built frame.

var _busy: bool = false
## Scenes asked for ahead on a loading thread (`prefetch`), so `go` finds them read and built instead of loading
## them under the cover.
var _fetching: Dictionary = {}

func _ready() -> void:
	layer = 100

## Starts loading the scene at `path` on a thread, for a `go` that is likely soon (Street's map asks for play as a
## door's card drops, and play for the map as a win begins).
func prefetch(path: String) -> void:
	if _fetching.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_fetching[path] = true

func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	await Celebration.cover(self)
	if _fetching.has(path):
		_fetching.erase(path)
		var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
		if packed != null:
			get_tree().change_scene_to_packed(packed)
			await get_tree().process_frame
			await Celebration.uncover()
			_busy = false
			return
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await Celebration.uncover()
	_busy = false

## Android's back button and gesture, which would otherwise close the app.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _busy:
		GoBack.request(get_tree())
