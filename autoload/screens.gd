extends CanvasLayer

# Every scene change happens under the party's red circle (Celebration.cover), so a change never flashes a
# half-built frame.

var _busy: bool = false

func _ready() -> void:
	layer = 100

func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	await Celebration.cover(self)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await Celebration.uncover()
	_busy = false

## Android's back button and gesture, which would otherwise close the app.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _busy:
		GoBack.request(get_tree())
