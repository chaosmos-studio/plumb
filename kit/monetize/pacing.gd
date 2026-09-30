class_name AdPacing
extends RefCounted

## When an ad may appear and what a hint costs: plain rules over plain numbers, tested headless. The Ads
## facade and the hint gate only feed them the player's counts and the session clock.

## The banner on the level grid waits until this many levels are solved.
const BANNER_AFTER: int = 3
## No ad between levels until this many levels are solved in all.
const INTERSTITIAL_AFTER: int = 12
## Levels solved this session before an ad between levels, counted again after each one.
const INTERSTITIAL_EVERY: int = 4
## Seconds after any full-screen ad, between levels or a video, before the next ad between levels.
const FULLSCREEN_GAP: float = 240.0
## Seconds after the app starts before the first ad between levels.
const LAUNCH_GAP: float = 180.0
## The first levels teach the game, so their hints are free and unlimited.
const FREE_HINT_LEVELS: int = 15
## Free hints a day after those, counted by the phone's own calendar so they come back at local midnight.
const DAILY_HINTS: int = 3

enum Hint { FREE, ALLOWANCE, VIDEO }

static func banner_due(solved: int, supporter: bool) -> bool:
	return not supporter and solved >= BANNER_AFTER

## `solved` is every level solved so far, `since` the levels solved this session since the last ad between
## levels. `now` and `last_fullscreen` are seconds since the app started; `last_fullscreen` is negative
## until a full-screen ad has shown.
static func interstitial_due(solved: int, since: int, now: float, last_fullscreen: float, supporter: bool) -> bool:
	if supporter or solved < INTERSTITIAL_AFTER or since < INTERSTITIAL_EVERY or now < LAUNCH_GAP:
		return false
	return last_fullscreen < 0.0 or now - last_fullscreen >= FULLSCREEN_GAP

## `level` counts from 0; `used` is the free hints already taken today.
static func hint_cost(level: int, used: int, supporter: bool) -> Hint:
	if supporter or level < FREE_HINT_LEVELS:
		return Hint.FREE
	return Hint.ALLOWANCE if used < DAILY_HINTS else Hint.VIDEO

static func hints_left(used: int) -> int:
	return maxi(DAILY_HINTS - used, 0)

## The free hints used today, from the saved day and count: a count kept from another day is none.
static func used_today(saved_day: String, saved_used: int, today: String) -> int:
	return maxi(saved_used, 0) if saved_day == today else 0
