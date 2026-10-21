class_name GameShare
extends RefCounted

const LINK: String = "https://chaosmos.studio/plumb/"
## Sends each phone to the best place it has: Google Play on Android, the game's page anywhere else.
const GET: String = "https://chaosmos.studio/plumb/get/"
const STORE: String = "https://play.google.com/store/apps/details?id=com.shravangoswami.plumb"
## By stars: one, two, three.
const CHEERS: Array = [
	["Every marble home. Fewer tilts next time?", "Home, the long way round.", "A shorter way is out there."],
	["Every marble home.", "Nearly the shortest roll.", "A tilt or two over, and home.", "Just a little over the goal."],
	["Rolled to perfection.", "Gravity did exactly as it was told.", "Every marble home, no detours.",
		"Right on the goal.", "The goal, exactly. Lovely."],
]

static func stage(holder: Node2D, data: Dictionary, centre: Vector2, room: Vector2) -> void:
	var view: BoardView = BoardView.new()
	holder.add_child(view)
	view.home = centre
	view.show_board(TiltBoard.from_dict(data), room)
