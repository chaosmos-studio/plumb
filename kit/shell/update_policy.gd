class_name UpdatePolicy
extends RefCounted

## When and how the game offers its own update card (REVAMP_PLAN.md section 7). Pure, so the rules are tested
## without Play: PlayCore says what Play knows, the level feed's signed manifest may add a line and a picture, and the
## save remembers which version was offered on which day.

## Play's in-app update priority (0 to 5, set with the release) from which an update must go out at once.
const URGENT_PRIORITY: int = 4
## The card's line when the feed says nothing about the version Play offers.
const FALLBACK_LINE: String = "A new version is ready"

## How the offered update installs: "immediate" when it must go out (the running version is below the feed's
## `urgent_below`, or Play's priority is URGENT_PRIORITY or more) and Play allows it, else "flexible" where Play allows
## that, else "immediate" where only that is allowed, and "" with nothing to offer.
static func mode(info: Dictionary, running: int, urgent_below: int) -> String:
	if int(info.get("code", 0)) <= running and running > 0:
		return ""
	var flexible: bool = bool(info.get("flexible", false))
	var immediate: bool = bool(info.get("immediate", false))
	var must: bool = (urgent_below > 0 and running > 0 and running < urgent_below) \
		or int(info.get("priority", 0)) >= URGENT_PRIORITY
	if must and immediate:
		return "immediate"
	if flexible:
		return "flexible"
	return "immediate" if immediate else ""

## Whether the card shows now: an urgent one on every launch, any other once a day for each version offered.
## `shown` maps a version code (as text) to the day it was last shown.
static func due(shown: Dictionary, code: int, today: String, how: String, shown_this_launch: bool) -> bool:
	if how == "" or code <= 0 or shown_this_launch:
		return false
	if how == "immediate":
		return true
	return str(shown.get(str(code), "")) != today

## Whether this launch is the first on an update the player started from the card.
static func installed(running: int, last_running: int, started_for: int) -> bool:
	return started_for > 0 and running >= started_for and running > last_running and last_running > 0

## The line for version `code`: the feed's, when its note is about that version, else FALLBACK_LINE.
static func line(note: Dictionary, code: int) -> String:
	var text: String = str(note.get("line", "")).strip_edges()
	if text == "" or int(note.get("latest", 0)) != code:
		return FALLBACK_LINE
	return text

## How far a download has come, 0 to 1.
static func progress(info: Dictionary) -> float:
	var total: float = float(info.get("bytes", 0))
	if total <= 0.0:
		return 0.0
	return clampf(float(info.get("downloaded", 0)) / total, 0.0, 1.0)
