class_name GameCredits
extends RefCounted

## Who made the game and what it is built with, for the kit's About and Credits sheets. Kept in step
## with CREDITS.md and the website's credits page.

const WEBSITE: String = "https://shravangoswami.com/plumb/"
const PRIVACY: String = "https://shravangoswami.com/plumb/privacy/"
## The site's help page. With the privacy policy, the only pages the Google Play build links to: neither
## carries a sponsor link.
const SUPPORT: String = "https://shravangoswami.com/plumb/support/"
## For the web build only. Google Play's Payments policy forbids pointing players at a way to pay outside
## its billing, so the Play build offers the Supporter pack instead.
const SPONSOR: String = "https://github.com/sponsors/shravanngoswamii"

## The note on the last screen, after the final level, from the person who made the game.
const NOTE: String = "You rolled every marble home. Thank you for playing Plumb all the way to the last board. I made it for the quiet minute between other things, a puzzle you can pick up, think through and put down with a smile, and it means a lot to me that you stayed for every level. More levels are on the way."
const SIGNED: String = "Shravan Goswami"
const SUPPORT_LINE_PLAY: String = "If Plumb gave you a few calm minutes, the Supporter pack helps me make the next game, and turns the ads off for good."
const SUPPORT_LINE_WEB: String = "If Plumb gave you a few calm minutes, you can help me make the next game."
const THANKS_LINE: String = "You are a Supporter. Thank you for helping me make the next game."

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
	{"title": "Ads and purchases, on Android", "items": [
		{"name": "Godot AdMob Plugin", "detail": "By Poing Studios. MIT licence."},
		{"name": "Godot Google Play Billing", "detail": "By the Godot Engine contributors. MIT licence."},
		{"name": "Google Mobile Ads SDK, User Messaging Platform and Play Billing Library", "detail": "By Google, under Google's terms."},
	]},
]
