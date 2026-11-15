extends RefCounted

## Stages Plumb for stills and films: the kit's capture tool and promo recorder ask for an action by
## name and get the real game, driven through its own code paths, in the viewport they pass.
##
## Actions: title, levels, settings, about, credits, play:N, moves:N:K (after K solver moves), hint:N:K, rolling:N:K,
## won:N, failed:N (the shortest fall into a pit), hero:N (the board with the HUD hidden), and for the website board:N[:LRUD], boardsolve:N:K and
## boardhint:N:K, which also hide the HUD, guide:K (level 1's guide at step K, counting from 0) and ending
## (the note after the last level). Levels are 1-based here, as a player counts them. Any action takes a
## "dark/" prefix to stage it in the dark theme. Without one it is in the game's own look. A "hard/" prefix stages
## it in the Hard section, its levels and pages counted as Hard counts them (hard/levels, hard/board:N). Also looks[:owned]
## (the marble sets sheet), colours (the colour themes sheet), themed:ID:K[:SET] (level K in colour theme
## ID, with marble set SET), sets (one marble of every set, named) and tiles[::K] (every mark from chapter 16 on, after K tilts). levels:K shows page K of the grid,
## unlock:N the sheet a locked level N opens on Google Play, replay:N:K level N's solve watched back K
## tenths of a second in, card:N the share card for level N, snapshot:N that card caught over the win
## sheet, and reel:N:K level N's reel K tenths of a second in (kit/tools/reel.tscn records one whole).
## daily is the daily puzzle's screen and daily:won a daily puzzle just solved, both for a player some
## weeks in and signed in to Play Games (DailyStage).
##
## The ads and the Supporter pack, as the Google Play build shows them unless the variant says web:
## levelsad (the grid with a stand-in banner of the real size), supporter[:web|:owned] (the support
## sheet), hintvideo:N (the video prompt on level N), hintbadge:N:K (level N's hint button after K of the
## day's free hints), settings:privacy (Settings where the consent message asks for privacy choices),
## about:play and ending:play|web|owned|pack (pack: the Play ending with its Supporter sheet open). Store
## shots never use these.
##
## Films also call perform(game, verb, arg) on a staged game: solve (arg = most moves), hint, tilt
## (arg = L, R, U or D), fail (tilts into a pit), undo, wait (arg = seconds).

const SETTLE: float = 0.9
const TILES: Dictionary = {
	"rows": ["0.....", "......", "..#...", "....1.", "......", ".x...2"],
	"marbles": [[1, 1, 0, 1], [3, 0, 1, 2], [5, 4, 2], [2, 4, 9]],
	"tiles": [[2, 0, "blink", 0], [3, 1, "blink", 1], [4, 0, "conveyor", 3], [0, 3, "spring", 0],
		[3, 4, "magnet", 0], [1, 2, "glass", 0], [4, 3, "ice", 0], [0, 5, "conveyor", 1]],
	"wrap": 1, "locked": 2}

var _settle: float = SETTLE
## Set by the film runner, which draws the finger for each move. Null for stills.
var film: Object = null

## `settle` waits for the level's opening animation, which stills want and films do not.
func stage(action: String, host: Node, settle: bool = true) -> void:
	_settle = SETTLE if settle else 0.02
	var dark: bool = action.begins_with("dark/")
	action = action.trim_prefix("dark/")
	# "hard/" comes after any "dark/".
	var hard: bool = action.begins_with("hard/")
	action = action.trim_prefix("hard/")
	Pack.use(Pack.Section.HARD if hard else Pack.Section.MAIN)
	# Saved as well as applied, so a staged Settings sheet shows the theme the shot is in.
	Save.theme = Appearance.Choice.DARK if dark else Appearance.native()
	Save.palette = ""
	Save.look = action.get_slice(":", 3) if action.begins_with("themed:") else ""
	GameLooks.use(Looks.current())
	Appearance.apply(Save.theme)
	Ads.preview = false
	Ads.use(null)
	Supporter.on_play = OS.has_feature("android")
	Supporter.price = ""
	Save.supporter = false
	# Store art and promos show the game as a new player meets it: faces on, plain walls.
	Save.faces = true
	Save.pets = false
	DailyStage.reset()
	var parts: PackedStringArray = action.split(":")
	var variant: String = parts[1] if parts.size() > 1 else ""
	var verb: String = parts[0]
	var n: int = int(parts[1]) - 1 if parts.size() > 1 else 0
	if hard:
		n += Pack.hard_from
	var k: int = int(parts[2]) if parts.size() > 2 else 0
	_seed_progress()
	match verb:
		"title":
			var cover: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(cover)
			_hide_tally(cover)
			await _wait(host, 1.2)
		"looks":
			Save.owned = PackedStringArray([GameMonetize.LOOKS_ID]) if variant == "owned" else PackedStringArray()
			Supporter.on_play = true
			var home: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(home)
			await _wait(host, 0.3)
			Looks.open(home)
			await _wait(host, 0.7)
		"sets":
			var shelf: ColorRect = ColorRect.new()
			shelf.color = Brand.BG
			shelf.set_anchors_preset(Control.PRESET_FULL_RECT)
			host.add_child(shelf)
			var room: Vector2 = host.get_viewport().get_visible_rect().size
			var ids: PackedStringArray = Looks.ids()
			var step: float = room.x / ids.size()
			var radius: float = minf(step * 0.28, room.y * 0.27)
			for i: int in range(ids.size()):
				var colours: Array = GameLooks.swatch(ids[i])
				var marble: Node2D = GameLooks.sample(ids[i], colours[i % colours.size()], radius)
				marble.position = Vector2(step * (i + 0.5), room.y * 0.4)
				shelf.add_child(marble)
				var named: Label = UI.label(Looks.name_of(ids[i]), int(radius * 0.5), Brand.MUTED)
				named.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				named.position = Vector2(step * i, room.y * 0.4 + radius * 1.25)
				named.size = Vector2(step, radius)
				shelf.add_child(named)
			await _wait(host, 0.3)
		"colours":
			Supporter.on_play = true
			var front: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(front)
			await _wait(host, 0.3)
			Themes.open(front)
			await _wait(host, 0.7)
		"themed":
			Save.palette = variant
			Appearance.apply(Save.theme)
			await _game(host, k - 1)
		"tiles":
			# The `k` tilts alternate left and right, so blinking walls show both ways.
			var holder: Node2D = Node2D.new()
			host.add_child(holder)
			var view: BoardView = BoardView.new()
			holder.add_child(view)
			var size: Vector2 = (host as Node).get_viewport().get_visible_rect().size
			view.home = size * 0.5
			var board: TiltBoard = TiltBoard.from_dict(TILES)
			view.show_board(board, Vector2(size.x * 0.9, size.x * 0.9))
			for t: int in range(k):
				var move: TiltMove = board.tilt(TiltBoard.LEFT if t % 2 == 0 else TiltBoard.RIGHT)
				await view.play(move)
			await _wait(host, 0.6)
		"levels":
			# levels:K:S also has the first S levels solved.
			if parts.size() > 2:
				_seed_progress(k)
			var grid: Node = load(Brand.LEVELS_SCENE).instantiate()
			host.add_child(grid)
			if parts.size() > 1:
				await _wait(host, 0.1)
				var page: int = int(parts[1]) - 1 + (Pack.chapter_of(Pack.hard_from) if hard else 0)
				grid.call("_show", page, 0)
			await _wait(host, 0.5)
		"unlock":
			Supporter.on_play = true
			Ads.use(_PreviewAds.new())
			Shop.prices[GameMonetize.KEY_IDS[0]] = "$0.49"
			Shop.prices[GameMonetize.LEVELS_ID] = "$1.99"
			var shut: Node = load(Brand.LEVELS_SCENE).instantiate()
			host.add_child(shut)
			await _wait(host, 0.1)
			shut.call("_show", Pack.chapter_of(n), 0)
			await _wait(host, 0.3)
			Unlocks.offer(shut, n)
			await _wait(host, 0.6)
		"replay":
			var watched: Node = await _game(host, n)
			await _solve(watched, 999)
			await _wait(host, _after_win(1.9))
			watched.call("_watch")
			await _wait(host, 0.1 * k)
		"snapshot":
			var caught: Node = await _game(host, n)
			await _solve(caught, 999)
			await _wait(host, _after_win(2.8))
		"reel":
			var reeled: Node = await _game(host, n)
			await _solve(reeled, 999)
			await _wait(host, _after_win(1.9))
			reeled.call("_watch", true)
			await _wait(host, 0.1 * k)
		"card":
			var shared: Node = await _game(host, n)
			await _solve(shared, 999)
			await _wait(host, _after_win(1.9))
			var moment: Result.Moment = shared.get("_won")
			var image: Image = await ShareCard.render(host, moment, int(shared.get("_earned")), moment.words[0])
			var layer: CanvasLayer = CanvasLayer.new()
			layer.layer = 100
			host.add_child(layer)
			var shown: TextureRect = TextureRect.new()
			shown.texture = ImageTexture.create_from_image(image)
			shown.set_anchors_preset(Control.PRESET_FULL_RECT)
			shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			layer.add_child(shown)
			await _wait(host, 0.2)
		"offer", "shop", "keys":
			# offer:ID[:K] opens product ID's sheet, and K minutes left on a pass for it shows it lent.
			Supporter.on_play = true
			Ads.use(_PreviewAds.new())
			for id: String in Shop.one_time_ids() + GameMonetize.KEY_IDS:
				Shop.prices[id] = "$1.99"
			Save.passes = {}
			if k > 0:
				Save.passes[variant] = [Passes.now() - 60, Passes.now() + k * 60]
			var front: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(front)
			await _wait(host, 0.3)
			if verb == "offer":
				Shop.offer(front, variant)
			elif verb == "shop":
				Shop.open(front)
			else:
				Shop.keys(front)
			await _wait(host, 0.6)
		"levelsad":
			Ads.preview = true
			host.add_child(load(Brand.LEVELS_SCENE).instantiate())
			await _wait(host, 0.5)
		"settings":
			if variant == "privacy":
				Supporter.on_play = true
				Ads.use(_PreviewAds.new())
			var title: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(title)
			await _wait(host, 0.3)
			Settings.open(title)
			await _wait(host, 0.6)
		"about", "credits":
			Supporter.on_play = variant == "play" or (variant == "" and Supporter.on_play)
			var home: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(home)
			await _wait(host, 0.3)
			if verb == "about":
				About.open(home)
			else:
				Credits.open(home)
			await _wait(host, 0.6)
		"supporter":
			Supporter.on_play = variant != "web"
			Supporter.price = "$2.99"
			Save.supporter = variant == "owned"
			var front: Node = load(Brand.TITLE_SCENE).instantiate()
			host.add_child(front)
			await _wait(host, 0.3)
			Supporter.open(front)
			await _wait(host, 0.6)
		"hintbadge":
			Ads.use(_PreviewAds.new())
			Save.set_hints(HintGate.today(), k)
			await _game(host, n)
		"hintvideo":
			var asked: Node = await _game(host, n)
			HintGate.ask(asked, func() -> void: pass)
			await _wait(host, 0.6)
		"play":
			await _game(host, n)
		"moves":
			var game: Node = await _game(host, n)
			await _solve(game, k)
		"hint":
			var game2: Node = await _game(host, n)
			await _solve(game2, k)
			game2.call("_on_hint")
			await _wait(host, 1.0)
		"rolling":
			var game3: Node = await _game(host, n)
			await _solve(game3, k)
			var path: PackedInt32Array = TiltSolver.new().solve(game3.get("board"))
			game3.call("_tilt", path[0])
			await _wait(host, 0.09)
		"won":
			# won:N:K stops K tenths of a second after the last tilt, to catch the snapshot on its way.
			var game4: Node = await _game(host, n)
			await _solve(game4, 999)
			await _wait(host, 0.1 * k if parts.size() > 2 else _after_win(1.9))
		"daily":
			DailyStage.seed(variant != "won")
			if variant == "won":
				Daily.day = Daily.today()
				var solved: Node = await _game(host, 0)
				await _solve(solved, 999)
				await _wait(host, 1.9)
			else:
				host.add_child(load(Daily.SCENE).instantiate())
				await _wait(host, 0.6)
		"board":
			var game6: Node = await _game(host, n)
			if parts.size() > 2:
				for letter: String in parts[2].split(""):
					await _tilt_now(game6, letter)
			_hide_hud(game6)
			await _wait(host, 0.3)
		"boardsolve":
			var game7: Node = await _game(host, n)
			await _solve(game7, k)
			# A finished level raises its result sheet a moment later. Wait for it so it is hidden too.
			await _wait(host, 1.4 if bool(game7.get("finished")) else 0.3)
			_hide_hud(game7)
			await _wait(host, 0.1)
		"boardhint":
			var game8: Node = await _game(host, n)
			await _solve(game8, k)
			_hide_hud(game8)
			game8.call("_on_hint")
			await _wait(host, 1.0)
		"failed":
			var game9: Node = await _game(host, n)
			for dir: int in _losing_line(game9.get("board"), 4):
				game9.call("_tilt", dir)
				while game9.get("_view").busy:
					await host.get_tree().process_frame
			await _wait(host, 1.6)
		"guide":
			Coach.enabled = true
			Save.tutorial_seen = false
			var guided: Node = await _game(host, 0)
			await _wait(host, 0.9)
			var coach: Coach = guided.get("_coach")
			for step: int in range(int(parts[1]) if parts.size() > 1 else 0):
				coach.advanced.emit()
				await _wait(host, 0.6)
			await _wait(host, 0.8)
			Coach.enabled = false
		"ending":
			if variant != "":
				Supporter.on_play = variant != "web"
				Save.supporter = variant == "owned"
				Supporter.price = "$2.99"
			var last: Node = await _game(host, Pack.count() - 1)
			var finale: Finale = Finale.open(last, func() -> void: pass)
			await _wait(host, 1.2)
			if variant == "pack":
				Supporter.open(finale)
				await _wait(host, 0.6)
		"hero":
			var game5: Node = await _game(host, n)
			for child: Node in game5.get_children():
				if child is CanvasLayer:
					(child as CanvasLayer).visible = false
			await _wait(host, 0.2)
		_:
			push_error("director: unknown action %s" % action)

func perform(game: Node, verb: String, arg: Variant) -> void:
	match verb:
		"solve":
			var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
			var most: int = int(arg) if int(arg) > 0 else path.size()
			for i: int in range(mini(most, path.size())):
				_swipe(game, path[i])
				while game.get("_view").busy:
					await game.get_tree().process_frame
				await game.get_tree().create_timer(0.42).timeout
		"hint":
			game.call("_on_hint")
			await game.get_tree().create_timer(1.2).timeout
		"tilt":
			var dirs: Dictionary = {"L": TiltBoard.LEFT, "R": TiltBoard.RIGHT, "U": TiltBoard.UP, "D": TiltBoard.DOWN}
			_swipe(game, int(dirs.get(String(arg), TiltBoard.DOWN)))
		"fail":
			for dir: int in _losing_line(game.get("board"), 4):
				_swipe(game, dir)
				while game.get("_view").busy:
					await game.get_tree().process_frame
				await game.get_tree().create_timer(0.3).timeout
		"undo":
			game.call("_on_undo")
		"wait":
			await game.get_tree().create_timer(float(arg)).timeout

func _swipe(game: Node, dir: int) -> void:
	if film != null:
		var view: Node2D = game.get("_view")
		var centre: Vector2 = view.get_global_transform_with_canvas().origin
		var reach: float = float(view.get("cell")) * 1.6
		var d: Vector2 = Vector2(TiltBoard.DIRS[dir])
		film.call("touch", "swipe", centre - d * reach, centre + d * reach)
	game.call("_tilt", dir)

func _losing_line(start: TiltBoard, depth: int) -> PackedInt32Array:
	var frontier: Array[TiltBoard] = [start]
	var paths: Array[PackedInt32Array] = [PackedInt32Array()]
	for d: int in range(depth):
		var next_frontier: Array[TiltBoard] = []
		var next_paths: Array[PackedInt32Array] = []
		for k: int in range(frontier.size()):
			for dir: int in range(4):
				var b: TiltBoard = frontier[k].copy()
				if not b.tilt(dir).changed():
					continue
				var p: PackedInt32Array = paths[k].duplicate()
				p.append(dir)
				if b.lost:
					return p
				next_frontier.append(b)
				next_paths.append(p)
		frontier = next_frontier
		paths = next_paths
	return PackedInt32Array()

## Shots hide the star tally: it gives away the level count, which goes stale as levels are added.
func _hide_tally(title: Node) -> void:
	var tally: CanvasItem = title.find_child("Tally", true, false)
	if tally != null:
		tally.visible = false

func _hide_hud(game: Node) -> void:
	for child: Node in game.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false

func _tilt_now(game: Node, letter: String) -> void:
	var dirs: Dictionary = {"L": TiltBoard.LEFT, "R": TiltBoard.RIGHT, "U": TiltBoard.UP, "D": TiltBoard.DOWN}
	if not dirs.has(letter):
		return
	game.call("_tilt", int(dirs[letter]))
	while game.get("_view").busy:
		await game.get_tree().process_frame
	await game.get_tree().create_timer(0.05).timeout

func _game(host: Node, level: int) -> Node:
	Pack.current = level
	var game: Node = load(Brand.GAME_SCENE).instantiate()
	host.add_child(game)
	await _wait(host, _settle)
	return game

func _solve(game: Node, count: int) -> void:
	var path: PackedInt32Array = TiltSolver.new().solve(game.get("board"))
	for i: int in range(mini(count, path.size())):
		game.call("_tilt", path[i])
		while game.get("_view").busy:
			await game.get_tree().process_frame
		await game.get_tree().create_timer(0.05).timeout

## Some progress, so the title and level grid look like a game someone is playing. In the Hard section the same
## number of Hard levels are solved too.
func _seed_progress(solved: int = 14) -> void:
	var stars: PackedByteArray = PackedByteArray()
	for i: int in range(solved):
		stars.append(3 if i % 5 != 3 else 2)
	Save.stars = stars
	var hard_stars: PackedByteArray = PackedByteArray()
	if Pack.section == Pack.Section.HARD:
		hard_stars.resize(Pack.hard_from)
		hard_stars.append_array(stars)
	Save.hard_stars = hard_stars

## A solved level's sheet rises after the last marble's slow drop and the board's party (game.gd WIN_PAUSE,
## Celebration.BOARD_TIME). The waits after a solve were set when it rose 0.3 s after the last tilt. A solve that
## finishes a chapter adds the chapter's moment as well.
func _after_win(seconds: float) -> float:
	var game: Dictionary = (load("res://scenes/game/game.gd") as GDScript).get_script_constant_map()
	return seconds + float(game["WIN_PAUSE"]) - 0.3 + Celebration.BOARD_TIME

func _wait(host: Node, seconds: float) -> void:
	await host.get_tree().create_timer(seconds).timeout

## Nothing to show, but ads count as possible and the consent message asks for privacy choices.
class _PreviewAds extends AdBackend:
	func privacy_required() -> bool:
		return true
