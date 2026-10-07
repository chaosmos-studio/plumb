class_name Studio
extends RefCounted

## The studio's games, for each game's More from Chaosmos sheet. The same list ships in every game, and
## each leaves itself out by its Brand.NAME. A game on Google Play links to the others' Play pages, and a
## game on the web to their browser versions.

const NAME: String = "Chaosmos"
## Every game on one page of the studio's site, kept free of sponsor links so a Google Play build may lead
## there.
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
]

## Every game but this one, in the studio's order.
static func others() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for game: Dictionary in GAMES:
		if String(game["name"]) != Brand.NAME:
			out.append(game)
	return out

## Where a tap on `game` leads from this build.
static func link(game: Dictionary) -> String:
	return String(game["store"] if Supporter.on_play else game["web"])
