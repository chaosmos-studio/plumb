class_name GameShare
extends RefCounted

## What Plumb gives the kit's share card, rating prompt and win words: its web address, its get link for
## the card's QR code and the shared message, its Google Play listing for the rating prompt, a level's
## board as it starts, and lines in Plumb's own voice for Cheers, by stars (one, two, three).

const LINK: String = "https://chaosmos.studio/plumb/"
## Sends each phone to the best place it has: Google Play on Android, the game's page anywhere else.
const GET: String = "https://chaosmos.studio/plumb/get/"
const STORE: String = "https://play.google.com/store/apps/details?id=com.shravangoswami.plumb"
const CHEERS: Array = [
	["Every marble home. Fewer tilts next time?", "Home, the long way round.", "A shorter way is out there."],
	["Every marble home.", "Nearly the shortest roll.", "A tilt or two over, and home.", "Just a little over the goal."],
	["Rolled to perfection.", "Gravity did exactly as it was told.", "Every marble home, no detours.",
		"Right on the goal.", "The goal, exactly. Lovely."],
]

static func stage(holder: Node2D, level: int, centre: Vector2, room: Vector2) -> void:
	var view: BoardView = BoardView.new()
	holder.add_child(view)
	view.home = centre
	view.show_board(Pack.board(level), room)
