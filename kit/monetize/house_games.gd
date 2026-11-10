class_name HouseGames
extends RefCounted

## How the house banner draws each of the studio's games: its line, and its colours in a light and a dark look,
## taken from that game's own palettes. The banner wears the look this game is in, so a light game never shows a
## dark strip at its foot, and the other way round.

## Each game's line for the banner, and its background, words, accent and pieces in each look.
const STYLES: Dictionary = {
	"Plumb": {
		"tag": "Roll every marble home",
		"light": {"bg": Color("f4efe7"), "ink": Color("2f333d"), "muted": Color("857d6f"), "accent": Color("f05a5a"),
			"pieces": [Color("ff6b6b"), Color("22b5a6"), Color("ffb020")]},
		"dark": {"bg": Color("1b1d22"), "ink": Color("f1ece3"), "muted": Color("a39b8d"), "accent": Color("ff7b7b"),
			"pieces": [Color("ff6b6b"), Color("22b5a6"), Color("ffb020")]},
	},
	"Carillon": {
		"tag": "Every pop is a note",
		"light": {"bg": Color("eef1fb"), "ink": Color("1b2150"), "muted": Color("525b8b"), "accent": Color("1d5cb4"),
			"pieces": [Color("2f80d8"), Color("e09a00"), Color("1fa37a"), Color("e04a63"), Color("7b5cd6")]},
		"dark": {"bg": Color("0d1127"), "ink": Color("e8ebff"), "muted": Color("8a93c6"), "accent": Color("7fd0ff"),
			"pieces": [Color("6ec8ff"), Color("ffc866"), Color("6cf0c2"), Color("ff7b8e"), Color("b89dff")]},
	},
	"Apsis": {
		"tag": "Launch every arrow out",
		"light": {"bg": Color("f5f3fa"), "ink": Color("161a3f"), "muted": Color("5a6190"), "accent": Color("b84c00"),
			"pieces": [Color("d9622b"), Color("3d7fd6"), Color("27a073"), Color("d2508f")]},
		"dark": {"bg": Color("0f1330"), "ink": Color("e9ecff"), "muted": Color("8a93c4"), "accent": Color("ffb35c"),
			"pieces": [Color("ffc4a3"), Color("9cc9ff"), Color("9be7c4"), Color("ffb2d2")]},
	},
	"Pyxis": {
		"tag": "Untangle every strand",
		"light": {"bg": Color("f7f7f2"), "ink": Color("263238"), "muted": Color("59666d"), "accent": Color("236b8e"),
			"pieces": [Color("236b8e"), Color("a34b32"), Color("326c59")]},
		"dark": {"bg": Color("17232a"), "ink": Color("edf2f2"), "muted": Color("a9b8be"), "accent": Color("87c8e6"),
			"pieces": [Color("87c8e6"), Color("e3896c"), Color("7cc3a6")]},
	},
}

## The game's look as the banner draws it, light or dark, with its line as `tag`. A game the table does not know
## is drawn as Pyxis.
static func style(game: String, dark: bool) -> Dictionary:
	var found: Dictionary = STYLES.get(game, STYLES["Pyxis"])
	var chosen: Dictionary = found["dark"] if dark else found["light"]
	var look: Dictionary = chosen.duplicate()
	look["tag"] = found["tag"]
	return look
