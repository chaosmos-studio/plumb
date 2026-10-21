class_name DailyDays
extends RefCounted

## The daily puzzle's calendar and streak, with no state of its own, so tests drive it with any clock.

## Play Games turns its daily leaderboards over at midnight UTC-7 all year, so the puzzle turns over then
## too, or one day's board would mix two puzzles' times. In India that is 12:30 in the afternoon.
const OFFSET: int = -7 * 3600
const DAY: int = 86400
const MONTHS: PackedStringArray = ["January", "February", "March", "April", "May", "June", "July", "August",
	"September", "October", "November", "December"]
const WEEKDAYS: PackedStringArray = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

## The puzzle's day number at a Unix time: whole days since 1 January 1970 on the UTC-7 clock.
static func index(unix: int) -> int:
	return floori(float(unix + OFFSET) / DAY)

## Seconds until the next puzzle.
static func left(unix: int) -> int:
	return DAY - posmod(unix + OFFSET, DAY)

## A "YYYY-MM-DD" date as its day number.
static func from_date(text: String) -> int:
	return floori(float(Time.get_unix_time_from_datetime_string(text + "T00:00:00")) / DAY)

## {year, month, day, weekday}, month from 1 and weekday from 0 for Sunday.
static func date(d: int) -> Dictionary:
	return Time.get_date_dict_from_unix_time(d * DAY)

## "21 October".
static func short(d: int) -> String:
	var at: Dictionary = date(d)
	return "%d %s" % [int(at["day"]), MONTHS[int(at["month"]) - 1]]

## "Tuesday, 21 October".
static func long(d: int) -> String:
	return "%s, %s" % [WEEKDAYS[int(date(d)["weekday"])], short(d)]

## The first day of the month `d` falls in.
static func month_start(d: int) -> int:
	return d - int(date(d)["day"]) + 1

static func month_length(d: int) -> int:
	var first: int = month_start(d)
	var next: int = month_start(first + 31)
	return next - first

static func month_name(d: int) -> String:
	var at: Dictionary = date(d)
	return "%s %d" % [MONTHS[int(at["month"]) - 1], int(at["year"])]

## 1:23, or 1:02:03 past an hour.
static func clock(ms: int) -> String:
	var s: int = floori(ms / 1000.0)
	if s >= 3600:
		return "%d:%02d:%02d" % [floori(s / 3600.0), floori(s / 60.0) % 60, s % 60]
	return "%d:%02d" % [floori(s / 60.0), s % 60]

## "3 h 12 min", "12 min".
static func wait(seconds: int) -> String:
	var minutes: int = maxi(1, ceili(seconds / 60.0))
	var hours: int = floori(minutes / 60.0)
	if hours == 0:
		return "%d min" % minutes
	return "%d h %d min" % [hours, minutes % 60] if minutes % 60 > 0 else "%d h" % hours

## The run of counted days that ends today, or ends yesterday while today's puzzle is still open, since a
## streak only breaks once a day has gone by unsolved.
static func streak(counted: Dictionary, today: int) -> int:
	var d: int = today if counted.has(today) else today - 1
	var n: int = 0
	while counted.has(d):
		n += 1
		d -= 1
	return n

static func longest(counted: Dictionary) -> int:
	var best: int = 0
	for d: Variant in counted:
		if counted.has(int(d) - 1):
			continue
		var n: int = 0
		while counted.has(int(d) + n):
			n += 1
		best = maxi(best, n)
	return best
