class_name GameCredits
extends RefCounted

## Who made the game and what it is built with, for the kit's About and Credits sheets. Kept in step
## with CREDITS.md and the website's credits page.

const WEBSITE: String = "https://shravangoswami.com/plumb/"
const PRIVACY: String = "https://shravangoswami.com/plumb/privacy/"
const SPONSOR: String = "https://github.com/sponsors/shravanngoswamii"
## Google Play has asked apps to remove links like this one (its Payments policy allows only tax-exempt
## donations outside Play billing), so the Android build shows the note without the button.
const SPONSOR_ON_ANDROID: bool = false

## The note on the last screen, after the final level, from the person who made the game.
const NOTE: String = "You rolled every marble home. Thank you for playing all the way to the end. I made Plumb to be a small, quiet puzzle you could pick up for a minute and put down smiling, and it means a lot that you stayed with it this long. More levels are on the way."
const SIGNED: String = "Shravan Goswami"
const SPONSOR_LINE: String = "If Plumb gave you a few calm minutes, you can help me make the next game."

const TEAM: Array[Dictionary] = [
	{"name": "Shravan Goswami", "role": "Game designer and developer"},
	{"name": "Claude Opus 5.5", "role": "AI co-developer, by Anthropic"},
]

const SECTIONS: Array[Dictionary] = [
	{"title": "Engine", "items": [
		{"name": "Godot Engine", "detail": "MIT licence. godotengine.org"},
	]},
	{"title": "Type", "items": [
		{"name": "Outfit", "detail": "By the Outfit Project Authors. SIL Open Font License 1.1. Used as two static weights with overlapping contours merged."},
	]},
	{"title": "Sound and music", "items": [
		{"name": "Synthesised for Plumb", "detail": "Every sound effect and the ambient music loop are made in code for this game."},
	]},
	{"title": "Art and levels", "items": [
		{"name": "Made in code", "detail": "Drawn and generated for this game, and every level proven solvable by its solver."},
	]},
]
