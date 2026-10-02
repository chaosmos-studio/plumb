class_name Revive
extends RefCounted

## One more heart, or one more tap, for a level that has run out of them: once a try, after a short
## video on Google Play, and free for a Supporter or in any build that cannot play one. Once a try keeps
## a level a puzzle to read rather than something to watch videos through.
##
## The kit expects from the game: its failure sheet offering `label(what)` through `Result.failed`'s
## `on_more`, that button calling `request`, and the game keeping whether this try has had its one.

static var _waiting: bool = false

## Whether the one more will cost a video.
static func asks_video() -> bool:
	return Ads.rewards() and not Supporter.active()

## The failure sheet's button: "Watch a video for one more heart", or "One more heart" when it is free.
static func label(what: String) -> String:
	return ("Watch a video for one more %s" if asks_video() else "One more %s") % what

## Runs `give` once the video is watched through, or at once when it is free or no video can play. A
## video closed early gives nothing and leaves the failure sheet as it was, so the player can choose
## again. A second press while a video is up does nothing.
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
