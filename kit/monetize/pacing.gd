class_name AdPacing
extends RefCounted

## The banner on the level grid waits until this many levels are solved.
const BANNER_AFTER: int = 3
## No ad between levels until this many levels are solved in all.
const INTERSTITIAL_AFTER: int = 12
## Levels solved this session before an ad between levels, counted again after each one.
const INTERSTITIAL_EVERY: int = 4
## Seconds after any full-screen ad, between levels or a video, or a purchase sheet, before the next ad between
## levels.
const FULLSCREEN_GAP: float = 240.0
## Seconds after the app starts before the first ad between levels.
const LAUNCH_GAP: float = 180.0
## Hours without ads between levels after one left the app by itself or never ended.
const TROUBLE_PAUSE_HOURS: int = 24
## The first levels teach the game, so their hints are free and unlimited.
const FREE_HINT_LEVELS: int = 15
## Free hints a day after those, counted by the phone's own calendar so they come back at local midnight.
const DAILY_HINTS: int = 3
## Hints one video gives: the one asked for now, and the rest given back as today's free hints.
const VIDEO_HINTS: int = 3

enum Hint { FREE, ALLOWANCE, VIDEO }

static func banner_due(solved: int, supporter: bool) -> bool:
	return not supporter and solved >= BANNER_AFTER

## `since` counts levels solved since the last ad between levels. `now` and `last_fullscreen` are seconds
## since the app started, and `last_fullscreen` is negative until a full-screen ad has shown. Only right after a
## win, never in the player's first launch, and never while a misbehaving ad has paused them.
static func interstitial_due(solved: int, since: int, now: float, last_fullscreen: float, supporter: bool,
		first_session: bool = false, after_win: bool = true, paused: bool = false) -> bool:
	if supporter or first_session or not after_win or paused:
		return false
	if solved < INTERSTITIAL_AFTER or since < INTERSTITIAL_EVERY or now < LAUNCH_GAP:
		return false
	return last_fullscreen < 0.0 or now - last_fullscreen >= FULLSCREEN_GAP

## `level` counts from 0.
static func hint_cost(level: int, used: int, supporter: bool) -> Hint:
	if supporter or level < FREE_HINT_LEVELS:
		return Hint.FREE
	return Hint.ALLOWANCE if used < DAILY_HINTS else Hint.VIDEO

static func hints_left(used: int) -> int:
	return maxi(DAILY_HINTS - used, 0)

## Today's used count once a video has paid for a hint: the video's other hints wait as free ones for today.
static func used_after_video(used: int) -> int:
	return maxi(mini(used, DAILY_HINTS) - (VIDEO_HINTS - 1), 0)

static func used_today(saved_day: String, saved_used: int, today: String) -> int:
	return maxi(saved_used, 0) if saved_day == today else 0
