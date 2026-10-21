class_name DailyStage
extends RefCounted

## The daily puzzle as a player some weeks in sees it, signed in to Play Games, for the store shots, the
## website's pictures and the films: three weeks of days solved, one missed too long ago to keep and one
## played late, so the calendar shows every kind of day and no offer to keep a day covers it. Each game's
## Director calls `seed()` for a daily action and `reset()` before every action.

## How far after the bank's first day the staged today falls: far enough for the history, and fixed, so a
## shot shows the same days whenever it is taken.
const DAYS_IN: int = 40
const HISTORY: int = 20
const MISSED: int = 11
const LATE: int = 13
## Today's time when it is staged solved, and the time already on the clock when the Director solves it,
## since a robot's solve takes a second or two and no player's does.
const TODAY_MS: int = 47000
const SPENT_MS: int = 41000

static func seed(today_solved: bool = false) -> void:
	var stars: PackedByteArray = PackedByteArray()
	for i: int in range(Daily.opens_after() + 12):
		stars.append(3 if i % 5 != 3 else 2)
	Save.stars = stars
	Daily.skew = (Daily.first() + DAYS_IN - DailyDays.index(int(Time.get_unix_time_from_system()))) * DailyDays.DAY
	var today: int = Daily.today()
	var times: Dictionary = {}
	for k: int in range(1, HISTORY + 1):
		if k != MISSED:
			times[today - k] = 40000 + 9000 * (k % 5)
	var record: Dictionary = {"times": times, "late": [today - LATE]}
	if today_solved:
		times[today] = TODAY_MS
	else:
		record["clock"] = {today: SPENT_MS}
	Save.daily = record
	PlayGames.use(_SignedIn.new())

static func reset() -> void:
	Daily.skew = 0
	Daily.day = -1
	PlayGames.use(null)


class _SignedIn extends Node:
	var signed_in: bool = true

	func submit(_id: String, _score: int) -> void:
		pass

	func show_board(_id: String, _span: int) -> void:
		pass

	func show_boards() -> void:
		pass

	func show_achievements() -> void:
		pass

	func record_event(_name: String, _properties: Dictionary) -> void:
		pass

	func progressed() -> void:
		pass
