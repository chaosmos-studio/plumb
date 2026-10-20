class_name GameCredits
extends RefCounted

## Keep in step with CREDITS.md and the website's credits page.

const WEBSITE: String = "https://chaosmos.studio/plumb/"
const PRIVACY: String = "https://chaosmos.studio/plumb/privacy/"
## With PRIVACY, the only pages the Google Play build links to: neither carries a sponsor link.
const SUPPORT: String = "https://chaosmos.studio/plumb/support/"
## Web build only: Play's Payments policy forbids pointing players at a way to pay outside its billing.
const SPONSOR: String = "https://github.com/sponsors/shravanngoswamii"

## The ending's one line, under the motif, once every level is solved.
const ENDING: String = "Every marble home."
const NOTE: String = "You rolled every marble home. Thank you for playing Plumb all the way to the last board. I made it for the quiet minute between other things, a puzzle you can pick up, think through and put down with a smile, and it means a lot to me that you stayed for every level. More levels are on the way."
const SIGNED: String = "Shravan Goswami"
const SUPPORT_LINE_PLAY: String = "If Plumb gave you a few calm minutes, the Supporter pack helps me make the next game, and turns the ads off for good."
const SUPPORT_LINE_WEB: String = "If Plumb gave you a few calm minutes, you can help me make the next game."
const THANKS_LINE: String = "You are a Supporter. Thank you for helping me make the next game."

const TEAM: Array[Dictionary] = [
	{"name": "Shravan Goswami", "role": "Game designer and developer", "site": "https://shravangoswami.com/",
		"site_on_play": "https://shravangoswami.com/projects/studio/"},
]
## It names no AI tool or model, since more than one is used and they change.
const HELP: String = "Made with the help of AI tools."

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
	{"title": "In the Android app", "items": [
		{"name": "Godot AdMob Plugin", "detail": "By Poing Studios. MIT licence."},
		{"name": "Godot Google Play Billing", "detail": "By the Godot Engine contributors. MIT licence."},
		{"name": "Godotx Firebase", "detail": "By Paulo Coutinho. MIT licence."},
		{"name": "Google Mobile Ads SDK, User Messaging Platform, Play Billing Library, Play In-App Review, Play In-App Updates and Google Analytics for Firebase", "detail": "By Google, under Google's terms."},
	]},
]
