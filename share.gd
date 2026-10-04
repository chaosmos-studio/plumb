class_name GameShare
extends RefCounted

## What Plumb gives the kit's share card and win words: its web address, a level's board as it starts,
## and lines in Plumb's own voice for Cheers, by stars (one, two, three).

const LINK: String = "https://shravangoswami.com/plumb/"
const CHEERS: Array = [
	["Every marble home. Fewer tilts next time?", "Home, the long way round.", "A shorter way is out there."],
	["Every marble home.", "Nearly the shortest roll.", "A tilt or two over, and home.", "Just a little over par."],
	["Rolled to perfection.", "Gravity did exactly as it was told.", "Every marble home, no detours.",
		"Par, exactly.", "Exactly par. Lovely."],
]

static func stage(holder: Node2D, level: int, centre: Vector2, room: Vector2) -> void:
	var view: BoardView = BoardView.new()
	holder.add_child(view)
	view.home = centre
	view.show_board(Pack.board(level), room)
