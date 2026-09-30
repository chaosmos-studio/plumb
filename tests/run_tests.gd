extends SceneTree

# Headless tests for the pure logic in scripts/ (no framework dependency). Same shape as Faceplant's.
# Run: godot --headless --path . -s res://tests/run_tests.gd
# CI greps the last line for "0 failed", so keep that wording.

const InputMapGen: GDScript = preload("res://tools/make_input_map.gd")
## Google's official test app, which the AdMob plugin also falls back to when the setting is unset.
const ADMOB_SETTINGS: GDScript = preload("res://addons/admob/internal/services/project_settings_service.gd")
const APP_ID_SETTING: String = "admob/general/android/app_id"
## The least contrast each pairing needs, as a WCAG ratio, in both palettes: body text, the quiet
## captions, the primary button's label and the reset warning.
const CONTRAST: Array = [["ink", "bg", 7.0], ["ink", "surface", 7.0], ["muted", "bg", 3.0],
	["muted", "surface", 3.0], ["accent_ink", "accent", 3.0], ["danger", "surface", 3.0]]

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	_test_input_map_is_wired()
	_test_orientation_is_an_int()
	_test_tilt_rules()
	_test_solver()
	_test_difficulty()
	_test_novelty()
	_test_serialisation()
	_test_stars()
	_test_level_pack()
	_test_appearance()
	_test_contrast()
	_test_saved_settings()
	_test_guide_and_ending()
	_test_banner_pacing()
	_test_interstitial_pacing()
	_test_hint_pacing()
	_test_adaptive_banner()
	_test_monetize_ids()
	_test_presets_and_plugins()
	_test_saved_monetization()
	_test_settings_variants()
	_test_about_variants()
	_test_finale_variants()
	_test_support_and_hint_sheets()
	print("\n==== TESTS: %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _check(name: String, cond: bool) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL: ", name)

# An action can exist with zero events, and then every is_action_pressed() silently returns false.
func _test_input_map_is_wired() -> void:
	var table: Dictionary = InputMapGen.bindings()
	for action: String in table:
		_check("action %s exists, re-run tools/make_input_map.gd" % action, InputMap.has_action(action))
		if InputMap.has_action(action):
			_check("action %s has bindings" % action, InputMap.action_get_events(action).size() > 0)

# A string here converts to 0, which is Landscape, whatever the string said.
func _test_orientation_is_an_int() -> void:
	var value: Variant = ProjectSettings.get_setting("display/window/handheld/orientation")
	_check("handheld orientation is stored as an int, re-run tools/configure_project.gd",
		typeof(value) == TYPE_INT)

static func _board(rows: Array, marbles: Array) -> TiltBoard:
	return TiltBoard.from_dict({"rows": rows, "marbles": marbles})

func _test_tilt_rules() -> void:
	var b: TiltBoard = _board(["..."], [[0, 0, 0]])
	var m: TiltMove = b.tilt(TiltBoard.RIGHT)
	_check("a marble rolls to the wall", b.marble_cell[0] == 2 and m.length() == 2)
	_check("a tilt into the wall changes nothing", not b.tilt(TiltBoard.RIGHT).changed())

	b = _board(["...."], [[0, 0, 0], [1, 0, 0]])
	m = b.tilt(TiltBoard.RIGHT)
	_check("a line of marbles rolls as a train", b.marble_cell[1] == 3 and b.marble_cell[0] == 2 and m.length() == 2)

	b = _board(["..0"], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble drops into a hole of its colour", b.marble_cell[0] == TiltBoard.GONE and b.is_won())

	b = _board([".1."], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a marble rolls over a hole of another colour", b.marble_cell[0] == 2 and not b.is_won())

	b = _board([".x."], [[0, 0, 0]])
	b.tilt(TiltBoard.RIGHT)
	_check("a pit swallows the marble and loses", b.lost and not b.is_won())

	b = _board([".#."], [[0, 0, 0]])
	_check("a wall blocks", not b.tilt(TiltBoard.RIGHT).changed())

	b = _board(["0.."], [[1, 0, 0], [2, 0, 0]])
	m = b.tilt(TiltBoard.LEFT)
	_check("the front marble sinks and the one behind rolls through", b.is_won() and m.events.size() == 2)

func _test_solver() -> void:
	var solver: TiltSolver = TiltSolver.new()
	var b: TiltBoard = _board(["..0", "...", "..."], [[0, 2, 0]])
	var path: PackedInt32Array = solver.solve(b)
	_check("the solver finds the two-move solution", path.size() == 2)
	var replay: TiltBoard = b.copy()
	for dir: int in path:
		replay.tilt(dir)
	_check("replaying the solution wins", replay.is_won())

	b = _board(["0#."], [[2, 0, 0]])
	path = solver.solve(b)
	_check("a marble walled off from its hole is unsolvable", path.is_empty() and solver.exhausted())

	b = _board(["x..0"], [[1, 0, 0]])
	path = solver.solve(b)
	_check("the solver never routes through a pit", path.size() == 1 and path[0] == TiltBoard.RIGHT)

func _test_difficulty() -> void:
	var d: TiltDifficulty = TiltDifficulty.of(_board(["..0"], [[0, 0, 0]]))
	_check("a forced win needs no luck", d.par == 1 and d.bits == 0.0)
	d = TiltDifficulty.of(_board(["...", "..0", "..."], [[1, 1, 0]]))
	_check("one winning tilt in four is two bits", d.par == 1 and is_equal_approx(d.bits, 2.0))
	var open: TiltDifficulty = TiltDifficulty.of(_board(["...", "...", "..0"], [[1, 1, 0]]))
	var pit: TiltDifficulty = TiltDifficulty.of(_board(["...", "x..", "..0"], [[1, 1, 0]]))
	_check("a pit in reach is in play", pit.risk > 0.0 and open.risk == 0.0)
	_check("the measure finds the solver's route", open.path == TiltSolver.new().solve(_board(["...", "...", "..0"], [[1, 1, 0]])))

func _test_novelty() -> void:
	var b: TiltBoard = _board(["#.0.", "..x1", "...."], [[0, 2, 1], [3, 2, 0]])
	var recoloured: TiltBoard = _board(["#.1.", "..x0", "...."], [[0, 2, 0], [3, 2, 1]])
	var turned: TiltBoard = TiltNovelty.transform(recoloured, 3)
	_check("a board turned and recoloured is the same level", TiltNovelty.canonical(turned) == TiltNovelty.canonical(b))
	var views: TiltNovelty.Views = TiltNovelty.views(b, TiltDifficulty.of(b).path)
	var mirror: TiltBoard = TiltNovelty.transform(b, 1)
	_check("a mirrored board is a replay", TiltNovelty.clash(views, TiltNovelty.views(mirror, TiltDifficulty.of(mirror).path)) == "layout")
	var bare: TiltBoard = _board(["...0", "....", "....", "...."], [[0, 0, 0]])
	var walled: TiltBoard = _board(["...0", "....", "###.", ".###"], [[0, 0, 0]])
	var other: TiltBoard = _board(["0..#", "#...", ".#..", "..#."], [[3, 3, 0]])
	var bare_views: TiltNovelty.Views = TiltNovelty.views(bare, TiltDifficulty.of(bare).path)
	_check("new walls around the same one-tilt route are a replay",
		TiltNovelty.clash(bare_views, TiltNovelty.views(walled, TiltDifficulty.of(walled).path)) == "route")
	_check("a different board is new", TiltNovelty.clash(bare_views, TiltNovelty.views(other, TiltDifficulty.of(other).path)) == "")

func _test_serialisation() -> void:
	var b: TiltBoard = _board(["#.0", ".x1"], [[1, 0, 0], [0, 1, 1]])
	var again: TiltBoard = TiltBoard.from_dict(b.to_dict())
	_check("a board survives a round trip", again.to_dict() == b.to_dict())
	var swapped: TiltBoard = _board(["#.0", ".x1"], [[0, 1, 1], [1, 0, 0]])
	_check("the solver key ignores marble order", swapped.key() == b.key())

func _test_stars() -> void:
	_check("par or better is three stars", Stars.earned(5, 5) == 3 and Stars.earned(4, 5) == 3)
	_check("a little over par is two", Stars.earned(7, 5) == 2)
	_check("well over par is one", Stars.earned(12, 5) == 1)
	_check("the two-star leeway grows with par", Stars.leeway(12) > Stars.leeway(4))

# Every shipped level is re-solved against the current rules. If a rule change alters a par or makes a
# level unsolvable, this fails before a build can ship it. The same measures the generator uses then
# check the set as a whole: no level repeats another, and none is easier than the one before.
func _test_level_pack() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/levels.json"))
	_check("levels.json parses", typeof(data) == TYPE_DICTIONARY)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var levels: Array = (data as Dictionary)["levels"]
	_check("the pack has every level", levels.size() == TiltGenerator.level_count())
	var solver: TiltSolver = TiltSolver.new()
	var boards: Array[TiltBoard] = []
	var measures: Array[TiltDifficulty] = []
	var views: Array[TiltNovelty.Views] = []
	var wrong: Array[int] = []
	for i: int in range(levels.size()):
		var level: Dictionary = levels[i]
		var board: TiltBoard = TiltBoard.from_dict(level)
		var path: PackedInt32Array = solver.solve(board, 100000)
		if path.size() != int(level["par"]):
			wrong.append(i + 1)
		var measure: TiltDifficulty = TiltDifficulty.of(board)
		boards.append(board)
		measures.append(measure)
		views.append(TiltNovelty.views(board, measure.path))
	_check("every level solves in exactly its par (wrong: %s)" % str(wrong), wrong.is_empty())

	var same: Array[String] = []
	var replays: Array[String] = []
	var seen: Dictionary = {}
	for i: int in range(levels.size()):
		var key: String = TiltNovelty.canonical(boards[i])
		if seen.has(key):
			same.append("%d=%d" % [int(seen[key]) + 1, i + 1])
		seen[key] = i
		for j: int in range(i + 1, levels.size()):
			var why: String = TiltNovelty.clash(views[i], views[j])
			if why != "":
				replays.append("%d-%d %s" % [i + 1, j + 1, why])
	_check("no two levels are the same level (%s)" % ", ".join(same), same.is_empty())
	_check("no level is a near replay of another (%s)" % ", ".join(replays), replays.is_empty())

	var easier: Array[int] = []
	var shorter: Array[int] = []
	var less: Array[int] = []
	var tame: Array[int] = []
	for i: int in range(levels.size()):
		if _pits(boards[i]) > 0 and measures[i].risk <= 0.0:
			tame.append(i + 1)
		if i == 0:
			continue
		if measures[i].easier_than(measures[i - 1]):
			easier.append(i + 1)
		if measures[i].par < measures[i - 1].par:
			shorter.append(i + 1)
		var a: TiltBoard = boards[i - 1]
		var b: TiltBoard = boards[i]
		if (b.cells.size() < a.cells.size() or b.marble_cell.size() < a.marble_cell.size()
				or _colours(b) < _colours(a) or _pits(b) < _pits(a)):
			less.append(i + 1)
	_check("no level is easier than the one before (at: %s)" % str(easier), easier.is_empty())
	_check("par never falls (at: %s)" % str(shorter), shorter.is_empty())
	_check("no level takes away room, a colour, a marble or a pit (at: %s)" % str(less), less.is_empty())
	_check("every pit level has a pit in play (not: %s)" % str(tame), tame.is_empty())

static func _colours(b: TiltBoard) -> int:
	var seen: Dictionary = {}
	for c: int in b.marble_colour:
		seen[c] = true
	return seen.size()

static func _pits(b: TiltBoard) -> int:
	return b.cells.count(TiltBoard.Cell.PIT)

# Kit classes that talk to the autoloads compile only once those exist, which is after this script, so
# they are loaded here rather than named.
func _test_appearance() -> void:
	var appearance: GDScript = load("res://kit/ui/appearance.gd")
	var choice: Dictionary = appearance.get_script_constant_map()["Choice"]
	_check("light and dark are fixed choices", not appearance.call("resolve", choice["LIGHT"]) and appearance.call("resolve", choice["DARK"]))
	_check("a new player starts in plumb's own look", appearance.call("native") == choice["LIGHT"])
	Brand.use(true)
	var dark_ok: bool = Brand.BG == Brand.DARK["bg"] and Palette.TILE == Palette.DARK["tile"] \
		and Palette.marble(0) == (Palette.DARK["marbles"] as Array)[0]
	Brand.use(false)
	_check("dark swaps the kit's palette and the board's", dark_ok)
	_check("light puts them back", Brand.BG == Brand.LIGHT["bg"] and Palette.TILE == Palette.LIGHT["tile"])
	for key: String in Brand.LIGHT:
		_check("the dark palette has %s" % key, Brand.DARK.has(key))
	for key: String in Palette.LIGHT:
		_check("the dark board has %s" % key, Palette.DARK.has(key))

func _test_contrast() -> void:
	for palette: String in ["LIGHT", "DARK"]:
		var p: Dictionary = Brand.LIGHT if palette == "LIGHT" else Brand.DARK
		for pair: Array in CONTRAST:
			var fore: Color = p.get(pair[0], Color.BLACK)
			var back: Color = p.get(pair[1], Color.BLACK)
			var ratio: float = _contrast(fore, back)
			_check("Brand.%s %s on %s has contrast %.1f, needs %.1f" % [palette, pair[0], pair[1], ratio, pair[2]],
				ratio >= float(pair[2]))

static func _contrast(a: Color, b: Color) -> float:
	var la: float = a.srgb_to_linear().get_luminance()
	var lb: float = b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

# The theme and the guide's state live with the other settings, and survive a restart of the app.
func _test_saved_settings() -> void:
	var save: Node = root.get_node("Save")
	var real: String = save.get("path")
	var old_theme: int = save.get("theme")
	var old_seen: bool = save.get("tutorial_seen")
	save.set("path", "user://test_settings.cfg")
	save.set("theme", 2)
	save.set("tutorial_seen", true)
	save.call("store")
	save.set("theme", 0)
	save.set("tutorial_seen", false)
	save.call("restore")
	_check("the theme is saved", int(save.get("theme")) == 2)
	_check("a seen guide stays seen", bool(save.get("tutorial_seen")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	save.set("path", real)
	save.set("theme", old_theme)
	save.set("tutorial_seen", old_seen)

func _test_guide_and_ending() -> void:
	var coach: GDScript = load("res://kit/ui/coach.gd")
	var finale: GDScript = load("res://kit/shell/finale.gd")
	var save: Node = root.get_node("Save")
	var old_seen: bool = save.get("tutorial_seen")
	var old_stars: PackedByteArray = save.get("stars")
	save.set("tutorial_seen", false)
	_check("level 1 opens with the guide", coach.call("due", 0))
	_check("no other level does", not coach.call("due", 1))
	save.set("tutorial_seen", true)
	_check("a seen guide does not come back by itself", not coach.call("due", 0))
	coach.set("requested", true)
	_check("settings can ask for it again", coach.call("due", 0))
	coach.set("enabled", false)
	_check("tools can turn it off", not coach.call("due", 0))
	coach.set("enabled", true)
	coach.set("requested", false)
	var pack: Node = root.get_node("Pack")
	var old_levels: Array[Dictionary] = pack.get("levels")
	var three: Array[Dictionary] = [{}, {}, {}]
	pack.set("levels", three)
	var last: int = 2
	save.set("stars", PackedByteArray())
	_check("solving the last level ends the game", finale.call("due", last))
	_check("no other level does", not finale.call("due", last - 1))
	var some: PackedByteArray = PackedByteArray()
	some.resize(last + 1)
	some[last] = 2
	save.set("stars", some)
	_check("replaying a solved last level does not", not finale.call("due", last))
	save.set("stars", old_stars)
	save.set("tutorial_seen", old_seen)
	pack.set("levels", old_levels)

# --- Monetization -------------------------------------------------------------------------------------

func _test_banner_pacing() -> void:
	_check("no banner before any level is solved", not AdPacing.banner_due(0, false))
	_check("no banner with two levels solved", not AdPacing.banner_due(AdPacing.BANNER_AFTER - 1, false))
	_check("the banner comes with the third solve", AdPacing.banner_due(AdPacing.BANNER_AFTER, false))
	_check("and stays", AdPacing.banner_due(119, false))
	_check("never for a Supporter", not AdPacing.banner_due(119, true))
	_check("the banner waits for 3 solves", AdPacing.BANNER_AFTER == 3)

# The spec's numbers, then each rule on its edge with every other rule satisfied.
func _test_interstitial_pacing() -> void:
	_check("the between-level pacing is 12 solves, every 4, 4 minutes apart, 3 minutes in",
		AdPacing.INTERSTITIAL_AFTER == 12 and AdPacing.INTERSTITIAL_EVERY == 4
		and is_equal_approx(AdPacing.FULLSCREEN_GAP, 240.0) and is_equal_approx(AdPacing.LAUNCH_GAP, 180.0))
	var ok: Callable = func(solved: int, since: int, now: float, last: float) -> bool:
		return AdPacing.interstitial_due(solved, since, now, last, false)
	_check("due once every rule is met", ok.call(12, 4, 180.0, -1.0))
	_check("never before 12 levels are solved", not ok.call(11, 40, 9999.0, -1.0))
	_check("never before 4 solves this session", not ok.call(60, 3, 9999.0, -1.0))
	_check("due on the fourth solve", ok.call(60, 4, 9999.0, -1.0))
	_check("never in the first 3 minutes after launch", not ok.call(60, 9, 179.9, -1.0))
	_check("due at 3 minutes", ok.call(60, 9, 180.0, -1.0))
	_check("never within 4 minutes of a full-screen ad", not ok.call(60, 9, 1000.0, 1000.0 - 239.9))
	_check("due 4 minutes after one", ok.call(60, 9, 1000.0, 1000.0 - 240.0))
	_check("never for a Supporter", not AdPacing.interstitial_due(60, 9, 9999.0, -1.0, true))

func _test_hint_pacing() -> void:
	_check("the first 15 levels have free hints, then 3 a day",
		AdPacing.FREE_HINT_LEVELS == 15 and AdPacing.DAILY_HINTS == 3)
	_check("level 1's hints are free however many are used", AdPacing.hint_cost(0, 99, false) == AdPacing.Hint.FREE)
	_check("level 15's too", AdPacing.hint_cost(14, 99, false) == AdPacing.Hint.FREE)
	_check("level 16 draws on the day's allowance", AdPacing.hint_cost(15, 0, false) == AdPacing.Hint.ALLOWANCE)
	_check("the third free hint of the day is still free", AdPacing.hint_cost(40, 2, false) == AdPacing.Hint.ALLOWANCE)
	_check("the fourth asks for a video", AdPacing.hint_cost(40, 3, false) == AdPacing.Hint.VIDEO)
	_check("a Supporter's hints are all free", AdPacing.hint_cost(40, 50, true) == AdPacing.Hint.FREE)
	_check("hints left count down to none", AdPacing.hints_left(0) == 3 and AdPacing.hints_left(2) == 1
		and AdPacing.hints_left(3) == 0 and AdPacing.hints_left(7) == 0)
	_check("today's hints count today", AdPacing.used_today("2026-09-30", 2, "2026-09-30") == 2)
	_check("yesterday's hints are forgotten at midnight", AdPacing.used_today("2026-09-29", 3, "2026-09-30") == 0)
	_check("a never-saved day counts none", AdPacing.used_today("", 3, "2026-09-30") == 0)

# The stand-in banner the captures draw has the height Google gives a phone's anchored adaptive banner.
func _test_adaptive_banner() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	_check("a 360 dp phone gets a 56 dp banner", is_equal_approx(ads.call("adaptive_height_dp", 360.0, 800.0), 56.0))
	_check("a 412 dp phone gets 64 dp", is_equal_approx(ads.call("adaptive_height_dp", 412.0, 915.0), 64.0))
	_check("never under 50 dp", is_equal_approx(ads.call("adaptive_height_dp", 240.0, 300.0), 50.0))
	_check("never over 90 dp", is_equal_approx(ads.call("adaptive_height_dp", 1000.0, 1400.0), 90.0))
	_check("never over 15% of a short screen", is_equal_approx(ads.call("adaptive_height_dp", 412.0, 400.0), 60.0))

# The plugin writes the project setting into the manifest (falling back to Google's test app when it is
# unset), so the one the game's code names must be the one that ships.
func _test_monetize_ids() -> void:
	var setting: String = ProjectSettings.get_setting(APP_ID_SETTING, ADMOB_SETTINGS.ANDROID_DEFAULT_APP_ID)
	_check("the manifest's AdMob app id is GameMonetize.APP_ID (%s)" % setting, setting == GameMonetize.APP_ID)
	var app: RegEx = RegEx.create_from_string("^ca-app-pub-\\d{16}~\\d{10}$")
	var unit: RegEx = RegEx.create_from_string("^ca-app-pub-\\d{16}/\\d{10}$")
	_check("the app id is an AdMob app id", app.search(GameMonetize.APP_ID) != null)
	for id: String in [GameMonetize.BANNER_ID, GameMonetize.INTERSTITIAL_ID, GameMonetize.REWARDED_ID]:
		_check("%s is an AdMob unit id" % id, unit.search(id) != null)
	var ids: Array[String] = [GameMonetize.BANNER_ID, GameMonetize.INTERSTITIAL_ID, GameMonetize.REWARDED_ID]
	_check("each placement has its own unit", ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	_check("the Supporter pack is the product 'supporter'", GameMonetize.SUPPORTER_ID == "supporter")

# The Android builds carry the plugins and may reach the network; the web build carries neither plugin.
func _test_presets_and_plugins() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	_check("the AdMob plugin is enabled", enabled.has("res://addons/admob/plugin.cfg"))
	_check("the Play billing plugin is enabled", enabled.has("res://addons/GodotGooglePlayBilling/plugin.cfg"))
	_check("the Android binaries are in place, so no build downloads them",
		FileAccess.file_exists("res://addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar")
		and FileAccess.file_exists("res://addons/admob/android/bin/package.gd")
		and FileAccess.file_exists("res://addons/admob/ios/bin/package.gd"))
	var presets: ConfigFile = ConfigFile.new()
	_check("export_presets.cfg reads", presets.load("res://export_presets.cfg") == OK)
	for section: String in presets.get_sections():
		if section.ends_with(".options") or not presets.has_section_key(section, "platform"):
			continue
		var preset_name: String = presets.get_value(section, "name")
		var exclude: String = presets.get_value(section, "exclude_filter", "")
		if presets.get_value(section, "platform") == "Android":
			var options: String = section + ".options"
			_check("%s may use the network" % preset_name, bool(presets.get_value(options, "permissions/internet", false)))
			_check("%s builds with Gradle, which the plugins need" % preset_name,
				bool(presets.get_value(options, "gradle_build/use_gradle_build", false)))
			_check("%s leaves the plugin's samples out" % preset_name, exclude.contains("addons/admob/gdscript/sample/*"))
		elif presets.get_value(section, "platform") == "Web":
			_check("the web build leaves the plugins out", exclude.contains("addons/*")
				and exclude.contains("kit/monetize/android/*"))

func _test_saved_monetization() -> void:
	var save: Node = root.get_node("Save")
	var real: String = save.get("path")
	var old: Array = [save.get("supporter"), save.get("hint_day"), save.get("hints_used"), save.get("stars")]
	save.set("path", "user://test_monetize.cfg")
	save.set("supporter", true)
	save.set("hint_day", "2026-09-30")
	save.set("hints_used", 2)
	save.call("store")
	save.set("supporter", false)
	save.set("hint_day", "")
	save.set("hints_used", 0)
	save.call("restore")
	_check("the Supporter pack is saved", bool(save.get("supporter")))
	_check("today's free hints are saved", String(save.get("hint_day")) == "2026-09-30" and int(save.get("hints_used")) == 2)
	save.call("reset")
	save.call("restore")
	_check("resetting progress keeps the Supporter pack", bool(save.get("supporter")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_monetize.cfg"))
	save.set("path", real)
	save.set("supporter", old[0])
	save.set("hint_day", old[1])
	save.set("hints_used", old[2])
	save.set("stars", old[3])

## The text of every button a kit sheet builds, on a host outside the tree so nothing animates.
func _buttons(opener: GDScript, method: String = "open") -> PackedStringArray:
	var host: Node = Node.new()
	opener.call(method, host)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	return texts

func _test_settings_variants() -> void:
	var ads: GDScript = load("res://kit/monetize/ads.gd")
	var settings: GDScript = load("res://kit/shell/settings.gd")
	var save: Node = root.get_node("Save")
	var old_supporter: bool = save.get("supporter")
	save.set("supporter", false)
	var plain: PackedStringArray = _buttons(settings)
	_check("settings offers Support the game", plain.has("Support the game"))
	_check("and no privacy choices where no consent message asks for them", not plain.has("Privacy choices"))
	var consent: _ConsentAds = _ConsentAds.new()
	ads.call("use", consent)
	_check("privacy choices appear when the consent message requires them", _buttons(settings).has("Privacy choices"))
	save.set("supporter", true)
	var supporter: PackedStringArray = _buttons(settings)
	_check("a Supporter still finds Support the game", supporter.has("Support the game"))
	_check("but no privacy choices, since no ads load for them", not supporter.has("Privacy choices"))
	ads.call("use", null)
	save.set("supporter", old_supporter)

func _test_about_variants() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var about: GDScript = load("res://kit/shell/about.gd")
	var old: bool = supporter.get("on_play")
	supporter.set("on_play", true)
	var play: PackedStringArray = _buttons(about)
	_check("About on Google Play links to Privacy and Support", play.has("Privacy") and play.has("Support"))
	_check("and not to the website, which has sponsor links", not play.has("Website"))
	supporter.set("on_play", false)
	var web: PackedStringArray = _buttons(about)
	_check("About on the web links to the website and Privacy", web.has("Website") and web.has("Privacy") and not web.has("Support"))
	supporter.set("on_play", old)

func _test_finale_variants() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var finale: GDScript = load("res://kit/shell/finale.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), save.get("supporter")]
	save.set("supporter", false)
	supporter.set("on_play", true)
	_check("the Play ending offers the Supporter pack", finale.call("support_line") == GameCredits.SUPPORT_LINE_PLAY
		and finale.call("support_button") == "Supporter pack")
	supporter.set("on_play", false)
	_check("the web ending offers GitHub Sponsors", finale.call("support_line") == GameCredits.SUPPORT_LINE_WEB
		and finale.call("support_button") == "Sponsor on GitHub")
	save.set("supporter", true)
	_check("a Supporter's ending thanks them and asks for nothing", finale.call("support_line") == GameCredits.THANKS_LINE
		and finale.call("support_button") == "")
	_check("the Play line names the pack and the web line does not",
		GameCredits.SUPPORT_LINE_PLAY.contains("Supporter pack") and not GameCredits.SUPPORT_LINE_WEB.contains("Supporter"))
	supporter.set("on_play", old[0])
	save.set("supporter", old[1])

func _test_support_and_hint_sheets() -> void:
	var supporter: GDScript = load("res://kit/monetize/supporter.gd")
	var gate: GDScript = load("res://kit/monetize/hint_gate.gd")
	var save: Node = root.get_node("Save")
	var old: Array = [supporter.get("on_play"), supporter.get("price"), save.get("supporter")]
	save.set("supporter", false)
	supporter.set("on_play", false)
	_check("the web's support sheet is one Sponsor on GitHub button", _buttons(supporter) == PackedStringArray(["Sponsor on GitHub"]))
	supporter.set("on_play", true)
	supporter.set("price", "")
	_check("the Play sheet sells the pack and restores it",
		_buttons(supporter) == PackedStringArray(["Support the game", "Restore purchase"]))
	supporter.set("price", "$2.99")
	_check("with the price once Play gives it", _buttons(supporter).has("Support for $2.99"))
	save.set("supporter", true)
	_check("a Supporter's sheet only thanks them", _buttons(supporter).is_empty())
	var host: Node = Node.new()
	gate.call("ask", host, func() -> void: pass)
	var texts: PackedStringArray = PackedStringArray()
	for b: Node in host.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	host.free()
	_check("the video prompt asks with Watch and Not now", texts == PackedStringArray(["Watch", "Not now"]))
	supporter.set("on_play", old[0])
	supporter.set("price", old[1])
	save.set("supporter", old[2])

## An ad network whose consent message asks for privacy choices.
class _ConsentAds extends AdBackend:
	func privacy_required() -> bool:
		return true
