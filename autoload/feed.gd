extends Node

## The level feed's client (REVAMP_PLAN.md section 6.3): new boards for Street, fetched a few seconds after the first
## screen shows, at most once every 12 hours, never during a level and never blocking anything. Every byte is checked
## by FeedCheck before it is kept, files are written to a ".part" and renamed so a killed app never leaves half a file,
## and the boards join the pool (StreetPool) only after the solver agrees with each one's par. Nothing depends on it:
## offline, the bundled pool and recycling never run out. The web build leaves it off.
##
## A debug build looks only when told to, so tests and robots never reach the network: with
## `-- --feed=http://127.0.0.1:8765/plumb/v1/` (a local server) and `--feed-key=res://tests/fixtures/feed/test_key.pub.pem`
## to trust the test key as well, or on a phone with a file at user://feed_on holding the address.

const BASE: String = "https://levels.chaosmos.studio/plumb/v1/"
## The keys a manifest may be signed with: the one in use and the next, for rotation. Their private halves are in
## studio/release-keys (plumb-feed-1.pem and plumb-feed-2.pem), never in a repo.
const KEYS: PackedStringArray = [
	"-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEOhrPx95ZsTwnRTx0IYUgDuFVsesr\n1QgbNvXdlt1bnj+0c7WiIT9+oks2gS/Qg2KxvViInr+vGV2q48Jq3+pyQg==\n-----END PUBLIC KEY-----\n",
	"-----BEGIN PUBLIC KEY-----\nMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE1vwoqPLdV3f1hxz6FRoVSeuzPOKA\nGRzVNT93MKU36SC/xNqR42wWcNBLVY07QLbzcioOedi15kFxEctlulgFHg==\n-----END PUBLIC KEY-----\n",
]
const DIR: String = "user://feed/"
const INTERVAL: int = 12 * 3600
## Seconds after launch before it looks, and how long one request may take.
const DELAY: float = 4.0
const TIMEOUT: float = 10.0
## The solver's search limit for the par check: a board it cannot confirm within it is dropped.
const CHECK_LIMIT: int = 400000

var base: String = BASE
var keys: PackedStringArray = KEYS
var dir: String = DIR
var _http: HTTPRequest
var _busy: bool = false
var _told: bool = false

signal updated(added: int)

func _ready() -> void:
	if OS.has_feature("web"):
		return
	if OS.is_debug_build():
		var told: bool = FileAccess.file_exists("user://feed_on")
		if told:
			base = FileAccess.get_file_as_string("user://feed_on").strip_edges()
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--feed="):
				base = arg.trim_prefix("--feed=")
				told = true
			elif arg.begins_with("--feed-key="):
				keys.append(FileAccess.get_file_as_string(arg.trim_prefix("--feed-key=")))
		if not told:
			return
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = TIMEOUT
	_http.body_size_limit = FeedCheck.MAX_BYTES
	add_child(_http)
	await get_tree().create_timer(DELAY).timeout
	merge_stored()
	sync()

## Looks for new boards, if it is time and no level is being played. A level in play waits for the next screen.
func sync(force: bool = false) -> void:
	if _busy or _http == null:
		return
	if not force and int(Time.get_unix_time_from_system()) - Save.feed_checked_at < INTERVAL:
		return
	if _in_level():
		if not get_tree().scene_changed.is_connected(sync):
			get_tree().scene_changed.connect(sync.bind(force), CONNECT_ONE_SHOT)
		return
	if not base.begins_with("https://") and not OS.is_debug_build():
		return
	_busy = true
	var outcome: Dictionary = await _fetch()
	_busy = false
	_tell(str(outcome["feed"]), int(outcome.get("serial", Save.feed_serial)), int(outcome.get("added", 0)))

func _in_level() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and (scene.scene_file_path == StreetPlay.SCENE or scene.scene_file_path == Brand.GAME_SCENE)

## One look at the feed: the manifest and its signature, then each file not kept yet, every one checked before
## anything is kept, then the boards merged. Answers {"feed": a feed_sync value, "serial", "added"}.
func _fetch() -> Dictionary:
	var got: Array = await _download("manifest.json")
	if int(got[0]) != OK:
		return {"feed": "offline"}
	var signature: Array = await _download("manifest.json.sig")
	if int(signature[0]) != OK:
		return {"feed": "offline"}
	var manifest_bytes: PackedByteArray = got[1]
	var verdict: Dictionary = FeedCheck.manifest(manifest_bytes, (signature[1] as PackedByteArray).get_string_from_utf8(),
		keys, Save.feed_serial)
	if not bool(verdict["ok"]):
		return {"feed": verdict["why"]}
	var manifest: Dictionary = verdict["manifest"]
	Save.set_feed(Save.feed_serial, int(Time.get_unix_time_from_system()))
	if str(verdict["why"]) == "same":
		return {"feed": "same", "serial": int(manifest["serial"])}
	# Every listed file, fetched unless kept already, and checked against the signed manifest.
	var fresh: Dictionary = {}
	var listed: Array = (manifest.get("episodes", []) as Array).duplicate()
	if manifest.has("rescore"):
		listed.append(manifest["rescore"])
	for entry: Variant in listed:
		var e: Dictionary = entry
		if int(e.get("rules", 1)) > FeedCheck.RULES:
			continue
		var path: String = dir + str(e["file"])
		if FileAccess.file_exists(path) and FeedCheck.file(FileAccess.get_file_as_bytes(path), e) == "":
			continue
		var fetched: Array = await _download(str(e["file"]))
		if int(fetched[0]) != OK:
			return {"feed": "offline"}
		var bytes: PackedByteArray = fetched[1]
		if FeedCheck.file(bytes, e) != "":
			return {"feed": "bad_hash"}
		if e.has("id") and not bool(FeedCheck.episode(bytes, e)["ok"]):
			return {"feed": "bad_board"}
		fresh[path] = bytes
	# The solver checks each new board's par on a worker thread, and a board it cannot confirm is dropped.
	var boards: Array = []
	for path: Variant in fresh:
		if str(path).contains("/episodes/"):
			boards.append_array(FeedCheck.episode(fresh[path], {"id": _episode_id(fresh[path])})["boards"])
	var dropped: PackedStringArray = await _check_pars(boards)
	for path: Variant in fresh:
		write_atomic(str(path), fresh[path])
	write_atomic(dir + "manifest.json", manifest_bytes)
	write_atomic(dir + "manifest.json.sig", signature[1])
	write_atomic(dir + "dropped.json", JSON.stringify(_dropped().duplicate() + Array(dropped)).to_utf8_buffer())
	prune(manifest, PackedStringArray(Save.street["doors"]))
	Save.set_feed(int(manifest["serial"]), int(Time.get_unix_time_from_system()))
	var added: int = merge_stored()
	updated.emit(added)
	if not dropped.is_empty():
		return {"feed": "bad_board", "serial": int(manifest["serial"]), "added": added}
	return {"feed": "ok", "serial": int(manifest["serial"]), "added": added}

## [OK and the body] or [FAILED and nothing], for one file of the feed.
func _download(file: String) -> Array:
	if _http.request(base + file) != OK:
		return [FAILED, PackedByteArray()]
	var reply: Array = await _http.request_completed
	if int(reply[0]) != HTTPRequest.RESULT_SUCCESS or int(reply[1]) != 200:
		return [FAILED, PackedByteArray()]
	return [OK, reply[3]]

static func _episode_id(bytes: PackedByteArray) -> String:
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return str((data as Dictionary).get("id", "")) if data is Dictionary else ""

## The ids of `boards` whose par the solver does not confirm, found on a worker thread.
func _check_pars(boards: Array) -> PackedStringArray:
	# An Array, which the thread's function shares, where a packed array would be copied into it.
	var bad: Array = []
	var work: Callable = func() -> void:
		for b: Variant in boards:
			var d: Dictionary = b
			if TiltSolver.new().solve(TiltBoard.from_dict(d), CHECK_LIMIT).size() != int(d["par"]):
				bad.append(str(d["id"]))
	var task: int = WorkerThreadPool.add_task(work, false, "feed par check")
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return PackedStringArray(bad)

## Puts the kept feed into the pool: every episode the stored manifest lists, checked again against it, its boards
## but those the solver dropped, then the retired ids and the rescores. An episode no longer listed but kept for a
## board on the street stays playable and leaves future picks. Answers how many boards joined. `into` is the game's
## pool unless a test brings its own.
func merge_stored(into: StreetPool = null) -> int:
	_clear_parts()
	var manifest_bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + "manifest.json")
	if manifest_bytes.is_empty():
		return 0
	var verdict: Dictionary = FeedCheck.manifest(manifest_bytes,
		FileAccess.get_file_as_string(dir + "manifest.json.sig"), keys, 0)
	if not bool(verdict["ok"]):
		return 0
	var manifest: Dictionary = verdict["manifest"]
	var episodes: Array = []
	var listed: Dictionary = {}
	for entry: Variant in manifest.get("episodes", []):
		var e: Dictionary = entry
		listed[str(e["file"]).get_file()] = true
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + str(e["file"]))
		if FeedCheck.file(bytes, e) != "":
			continue
		var checked: Dictionary = FeedCheck.episode(bytes, e)
		if bool(checked["ok"]):
			episodes.append({"boards": checked["boards"], "listed": true})
	for file: String in _files(dir + "episodes"):
		if listed.has(file):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + "episodes/" + file)
		var id: String = _episode_id(bytes)
		var checked: Dictionary = FeedCheck.episode(bytes, {"id": id})
		if bool(checked["ok"]):
			episodes.append({"boards": checked["boards"], "listed": false})
	var rescore: Dictionary = {}
	if manifest.has("rescore"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + str((manifest["rescore"] as Dictionary)["file"]))
		if FeedCheck.file(bytes, manifest["rescore"]) == "":
			rescore = FeedCheck.rescores(bytes)
	return FeedCheck.merge(into if into != null else StreetPool.shared(), episodes, manifest.get("retired", []), rescore,
		_dropped())

func _dropped() -> Array:
	if not FileAccess.file_exists(dir + "dropped.json"):
		return []
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "dropped.json"))
	return data if data is Array else []

## Deletes every kept file the manifest no longer lists, except an episode holding a board on the street.
func prune(manifest: Dictionary, street: PackedStringArray) -> void:
	var keep: Dictionary = {}
	for entry: Variant in manifest.get("episodes", []):
		keep[str((entry as Dictionary)["file"])] = true
	if manifest.has("rescore"):
		keep[str((manifest["rescore"] as Dictionary)["file"])] = true
	for folder: String in ["episodes", "rescore"]:
		for file: String in _files(dir + folder):
			var at: String = folder + "/" + file
			if keep.has(at):
				continue
			if folder == "episodes" and FeedCheck.holds_street_board(file, street):
				continue
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + at))

## Writes `bytes` to a ".part" beside `path` and renames it over, so a killed app never leaves half a file.
func write_atomic(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var part: String = path + ".part"
	var file: FileAccess = FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(part), ProjectSettings.globalize_path(path)) == OK

## A ".part" left by an app killed mid-write is never read, and goes.
func _clear_parts() -> void:
	for folder: String in ["", "episodes", "rescore"]:
		for file: String in _files(dir + folder):
			if file.ends_with(".part"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + folder.path_join(file)))

## The files in `folder`, none when it is not there yet.
static func _files(folder: String) -> PackedStringArray:
	return DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray()

## feed_sync once a launch, and the feed's serial as a user property.
func _tell(feed: String, serial: int, added: int) -> void:
	if OS.is_debug_build():
		print("FEED_SYNC %s" % JSON.stringify({"feed": feed, "serial": serial, "added": added}))
	if _told:
		return
	_told = true
	Analytics.event(&"feed_sync", {"feed": feed, "serial": serial, "added": added})
	if serial > 0:
		Analytics.user_property("feed_serial", str(serial))
