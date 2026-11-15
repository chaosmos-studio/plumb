class_name Unlocks
extends RefCounted

## The kit expects from the game: in `Save`, `opened` (the levels opened one by one) and `keys`, with
## `open_level(level)` and `add_keys(n)`. In `GameMonetize`, KEY_IDS and KEY_COUNTS, the consumable
## products that sell keys. A game with a second set of levels (Pack.sections) also gives `Save.was_opened(level)`,
## since each set keeps its own opened levels, and `Pack.first_level()`, the level that set opens on.

## Of a chapter's levels, the share to solve before the next chapter opens, so one stubborn level never
## walls off the rest of the game.
const GATE: float = 0.7

## The level a key is being bought for, or -1.
static var _buying: int = -1

static func is_open(level: int) -> bool:
	return Shop.levels_open() or reached(level)

## Ignores Every level, so the grid rings only the levels next to play.
static func reached(level: int) -> bool:
	if level <= _first() or Save.best(level - 1) > 0 or _opened(level):
		return true
	var chapter: int = Pack.chapter_of(level)
	return chapter > 0 and Pack.chapter_first(chapter) == level and solved_in(chapter - 1) >= gate(chapter - 1)

static func gate(chapter: int) -> int:
	return ceili(GATE * int(Pack.chapters[chapter]["count"]))

static func solved_in(chapter: int) -> int:
	var first: int = Pack.chapter_first(chapter)
	var n: int = 0
	for i: int in range(first, first + int(Pack.chapters[chapter]["count"])):
		n += 1 if Save.best(i) > 0 else 0
	return n

## The chapter whose first level the first solve of `level` has just opened through the gate, or -1.
static func gate_opened_by(level: int) -> int:
	var chapter: int = Pack.chapter_of(level)
	if chapter < 0 or chapter + 1 >= Pack.chapters.size() or Shop.levels_open():
		return -1
	var next_first: int = Pack.chapter_first(chapter + 1)
	if solved_in(chapter) != gate(chapter) or Save.best(next_first - 1) > 0 or _opened(next_first):
		return -1
	return chapter + 1

static func _first() -> int:
	return int(Pack.call("first_level")) if Pack.has_method("first_level") else 0

static func _opened(level: int) -> bool:
	return bool(Save.call("was_opened", level)) if Save.has_method("was_opened") else Save.opened.has(level)

static func how(level: int) -> String:
	var chapter: int = Pack.chapter_of(level)
	if chapter > 0 and Pack.chapter_first(chapter) == level:
		var more: int = gate(chapter - 1) - solved_in(chapter - 1)
		return "Solve %d more %s in chapter %d to open it." % [more, "level" if more == 1 else "levels", chapter]
	return "Solve level %d to open it." % level

static func use_key(level: int) -> bool:
	if Save.keys <= 0:
		return false
	Save.add_keys(-1)
	Save.open_level(level)
	return true

## `level` is -1 for none. It is kept past a cancelled purchase, so keys Play delivers late still open what
## they were bought for.
static func buy_key(id: String, level: int) -> void:
	_buying = level
	Shop.buy(id)

static func delivered(count: int) -> void:
	if _buying >= 0 and use_key(_buying):
		Supporter.say("Level %d is open" % (_buying + 1))
	else:
		Supporter.say("%d %s added" % [count, "key" if count == 1 else "keys"])
	_buying = -1

static func offer(host: Node, level: int) -> Sheet:
	if not Supporter.on_play:
		Toast.say(host, how(level))
		return null
	var sheet: Sheet = Sheet.open(host)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Level %d" % (level + 1), 56))
	var why: Label = UI.label(how(level) + " Or open it now, for good.", 28, Brand.MUTED)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(why)
	c.add_child(UI.spacer(6))
	var lead: bool = true
	# With no video ready the level simply opens: nothing would earn from the ask.
	if Ads.rewards():
		var watch: Button = UI.button("Watch a video to open it" if Ads.video_ready() else "Open it free", UI.Style.PRIMARY)
		watch.pressed.connect(func() -> void:
			sheet.close()
			Ads.rewarded(func() -> void: _play(level)))
		c.add_child(watch)
		lead = false
	var style: UI.Style = UI.Style.PRIMARY if lead else UI.Style.SECONDARY
	if Save.keys > 0:
		var key: Button = UI.button("Use a key (%d left)" % Save.keys, style)
		key.pressed.connect(func() -> void:
			sheet.close()
			if use_key(level):
				_play(level))
		c.add_child(key)
	else:
		var one: String = GameMonetize.KEY_IDS[0]
		var buy: Button = UI.button("Open it for %s" % Shop.price(one) if Shop.price(one) != "" else "Open it with a key", style)
		buy.pressed.connect(func() -> void: buy_key(one, level))
		c.add_child(buy)
	if not Shop.levels_open():
		var every: String = GameMonetize.LEVELS_ID
		var all: Button = UI.button("Every level for %s" % Shop.price(every) if Shop.price(every) != "" else "Open every level",
			UI.Style.GHOST)
		all.pressed.connect(func() -> void:
			sheet.close()
			Shop.offer(host, every))
		c.add_child(all)
	Shop.live(sheet, func() -> void:
		sheet.close()
		if not is_open(level):
			offer(host, level))
	return sheet

static func _play(level: int) -> void:
	Save.open_level(level)
	Pack.current = level
	Screens.go(Brand.GAME_SCENE)
