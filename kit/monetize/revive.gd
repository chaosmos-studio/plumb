class_name Revive
extends RefCounted

## Once a try keeps a level a puzzle to read rather than something to watch videos through.
##
## The kit expects from the game: its failure sheet offering `label(what)` through `Result.failed`'s
## `on_more`, that button calling `request`, and the game keeping whether this try has had its one.

static var _waiting: bool = false

static func asks_video() -> bool:
	return Ads.rewards() and not Supporter.active()

static func label(what: String) -> String:
	return ("Watch a video for one more %s" if asks_video() else "One more %s") % what

## A video closed early gives nothing and leaves the failure sheet as it was, so the player can choose again.
static func request(host: Node, what: String, give: Callable) -> void:
	if _waiting:
		return
	if not asks_video():
		give.call()
		return
	_waiting = true
	await Ads.rewarded(give, func() -> void:
		if is_instance_valid(host):
			Toast.say(host, "No video right now, so this %s is free" % what)
		if give.is_valid():
			give.call())
	_waiting = false
