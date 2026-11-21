extends Node

## Opens the game in the look the player chose (REVAMP_PLAN.md section 3.3): the chooser on a first launch, then
## Street's map or Classic's title. The studio's beat plays over whichever screen comes first.

func _ready() -> void:
	AppLook.use(AppLook.effective(Save.app_look if Save.look_chosen else AppLook.STREET))
	get_tree().change_scene_to_file.call_deferred(AppLook.first_scene(Save.app_look, Save.look_chosen))
