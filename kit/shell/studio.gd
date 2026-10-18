class_name Studio
extends RefCounted

## The same list ships in every game, and each leaves itself out by its Brand.NAME.

const NAME: String = "Chaosmos"
## Kept free of sponsor links, so a Google Play build may lead there.
const GAMES_PAGE: String = "https://chaosmos.studio/games/"

const GAMES: Array[Dictionary] = [
	{
		"name": "Plumb",
		"line": "Tilt the board and every marble rolls at once.",
		"icon": "res://kit/shell/studio/plumb.webp",
		"store": "https://play.google.com/store/apps/details?id=com.shravangoswami.plumb",
		"web": "https://chaosmos.studio/plumb/play/",
	},
	{
		"name": "Carillon",
		"line": "One tap, and the whole chain plays a tune.",
		"icon": "res://kit/shell/studio/carillon.webp",
		"store": "https://play.google.com/store/apps/details?id=com.shravangoswami.carillon",
		"web": "https://chaosmos.studio/carillon/play/",
	},
	{
		"name": "Apsis",
		"line": "Send every arrow out of orbit, in the right order.",
		"icon": "res://kit/shell/studio/apsis.webp",
		"store": "https://play.google.com/store/apps/details?id=com.shravangoswami.apsis",
		"web": "https://chaosmos.studio/apsis/play/",
	},
	# Shown once it is out on Google Play: set "live" to true then.
	{
		"name": "Pyxis",
		"line": "Pull the knots apart until no strands cross.",
		"icon": "res://kit/shell/studio/pyxis.webp",
		"store": "https://play.google.com/store/apps/details?id=com.shravangoswami.pyxis",
		"web": "https://chaosmos.studio/pyxis/play/",
		"live": false,
	},
]

## The other games that are out, for More games and the house ads.
static func others() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for game: Dictionary in GAMES:
		if String(game["name"]) != Brand.NAME and bool(game.get("live", true)):
			out.append(game)
	return out

static func link(game: Dictionary) -> String:
	return String(game["store"] if Supporter.on_play else game["web"])
