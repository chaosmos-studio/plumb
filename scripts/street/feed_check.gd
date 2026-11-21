class_name FeedCheck
extends RefCounted

## Checks what the level feed sends (REVAMP_PLAN.md section 6): bytes in, a verdict out, so every rule is tested
## without a network. Feed (autoload/feed.gd) fetches and stores. Nothing from the feed is trusted until it passes
## here: the manifest's signature against a key built into the game, its format and game, a serial never lower than
## the last one taken (no rollback), each file's size and SHA-256 as the signed manifest says, and every board's
## fields and ranges. A manifest's signature covers its exact bytes, and the files are tied to it by their hashes.

const FORMAT: int = 1
const GAME: String = "plumb"
## The rules this build knows. An episode that needs more is skipped, and a newer build will take it.
const RULES: int = 1
## The most a file may weigh, a board's largest size, its most marbles, its highest par and its highest difficulty.
const MAX_BYTES: int = 512 * 1024
const MAX_SIDE: int = 10
const MAX_MARBLES: int = 8
const MAX_PAR: int = 30
const MAX_BITS: float = 60.0
## Where a listed file may live in the bucket: one folder deep, plain names, so a stored copy can never land outside
## user://feed/.
const FILE_PATTERN: String = "^(episodes|rescore)/[a-z0-9-]{1,64}\\.json$"
const EPISODE_ID: String = "^ep[0-9]{4}$"
const BOARD_ID: String = "^ep[0-9]{4}-[0-9]{2,3}$"

## The manifest's verdict: {"ok": true, "manifest": {...}} or {"ok": false, "why": a feed_sync value}. `why` is
## "same" for a manifest whose serial is the one already taken, which is fine and needs nothing fetched.
static func manifest(bytes: PackedByteArray, signature_b64: String, keys: PackedStringArray, serial: int) -> Dictionary:
	if bytes.size() > MAX_BYTES:
		return _no("error")
	if not signed(bytes, signature_b64, keys):
		return _no("bad_signature")
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (data is Dictionary):
		return _no("error")
	var m: Dictionary = data
	if int(m.get("format", 0)) != FORMAT or str(m.get("game", "")) != GAME:
		return _no("error")
	var got: int = int(m.get("serial", -1))
	if got < serial:
		return _no("rollback")
	for entry: Variant in m.get("episodes", []):
		if not _listed(entry) or not RegEx.create_from_string(EPISODE_ID).search(str((entry as Dictionary).get("id", ""))):
			return _no("error")
	if m.has("rescore") and not _listed(m["rescore"]):
		return _no("error")
	if m.has("ads") and not ads_note(m["ads"]):
		return _no("error")
	if not (m.get("retired", []) is Array):
		return _no("error")
	if got == serial:
		return {"ok": true, "why": "same", "manifest": m}
	return {"ok": true, "why": "ok", "manifest": m}

## Whether `signature_b64` (base64 DER, ECDSA P-256 over SHA-256) signs `bytes` under any of `keys` (PEM).
static func signed(bytes: PackedByteArray, signature_b64: String, keys: PackedStringArray) -> bool:
	var signature: PackedByteArray = Marshalls.base64_to_raw(signature_b64.strip_edges())
	if signature.is_empty():
		return false
	var digest: PackedByteArray = sha256(bytes)
	var crypto: Crypto = Crypto.new()
	for pem: String in keys:
		var key: CryptoKey = CryptoKey.new()
		if key.load_from_string(pem, true) != OK:
			continue
		if crypto.verify(HashingContext.HASH_SHA256, digest, signature, key):
			return true
	return false

static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()

## A listed file's bytes against what the signed manifest says of it: "" when they match, else why not.
static func file(bytes: PackedByteArray, entry: Dictionary) -> String:
	if bytes.size() > MAX_BYTES or bytes.size() != int(entry.get("bytes", -1)):
		return "bad_hash"
	return "" if sha256(bytes).hex_encode() == str(entry.get("sha256", "")).to_lower() else "bad_hash"

## An episode's boards, checked: {"ok": true, "boards": [...]} or {"ok": false, "why": "bad_board"}. An episode for
## rules this build does not know is {"ok": false, "why": "rules"}, skipped and not an error.
static func episode(bytes: PackedByteArray, entry: Dictionary) -> Dictionary:
	if int(entry.get("rules", 1)) > RULES:
		return _no("rules")
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (data is Dictionary) or int((data as Dictionary).get("format", 0)) != FORMAT \
			or str((data as Dictionary).get("id", "")) != str(entry.get("id", "")):
		return _no("bad_board")
	var boards: Variant = (data as Dictionary).get("boards", [])
	if not (boards is Array) or (boards as Array).is_empty():
		return _no("bad_board")
	var ids: Dictionary = {}
	for b: Variant in boards:
		if board(b) != "" or ids.has(str((b as Dictionary)["id"])):
			return _no("bad_board")
		ids[str((b as Dictionary)["id"])] = true
	return {"ok": true, "boards": boards}

## The rescore file: board ids to difficulties in bits, each in range. {} when anything is off.
static func rescores(bytes: PackedByteArray) -> Dictionary:
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not (data is Dictionary) or not ((data as Dictionary).get("boards", null) is Dictionary):
		return {}
	var out: Dictionary = {}
	var boards: Dictionary = (data as Dictionary)["boards"]
	for id: Variant in boards:
		var v: Variant = boards[id]
		var d: float = float((v as Dictionary).get("d", -1.0)) if v is Dictionary else -1.0
		if not (id is String) or d < 0.0 or d > MAX_BITS:
			return {}
		out[id] = d
	return out

## A board's fields and ranges: "" when it is sound, else what is wrong.
static func board(b: Variant) -> String:
	if not (b is Dictionary):
		return "not a board"
	var d: Dictionary = b
	if not RegEx.create_from_string(BOARD_ID).search(str(d.get("id", ""))) or int(d.get("rev", 0)) < 1:
		return "id"
	var rows: Variant = d.get("rows", null)
	if not (rows is Array) or (rows as Array).is_empty() or (rows as Array).size() > MAX_SIDE:
		return "rows"
	var w: int = str((rows as Array)[0]).length()
	var h: int = (rows as Array).size()
	if w < 1 or w > MAX_SIDE or int(d.get("w", w)) != w or int(d.get("h", h)) != h:
		return "size"
	var walls: Dictionary = {}
	for y: int in range(h):
		var row: Variant = (rows as Array)[y]
		if not (row is String) or (row as String).length() != w:
			return "rows"
		for x: int in range(w):
			var ch: String = (row as String)[x]
			if not (ch in [".", "#", "x"] or (ch.is_valid_int() and int(ch) < TiltBoard.STONE)):
				return "cell"
			if ch == "#":
				walls[Vector2i(x, y)] = true
	var marbles: Variant = d.get("marbles", null)
	if not (marbles is Array) or (marbles as Array).is_empty() or (marbles as Array).size() > MAX_MARBLES:
		return "marbles"
	var taken: Dictionary = {}
	for m: Variant in marbles:
		if not (m is Array) or (m as Array).size() < 3 or (m as Array).size() > 4:
			return "marble"
		var at: Vector2i = Vector2i(int((m as Array)[0]), int((m as Array)[1]))
		var colour: int = int((m as Array)[2])
		if at.x < 0 or at.y < 0 or at.x >= w or at.y >= h or walls.has(at) or taken.has(at) or colour < 0 \
				or colour > TiltBoard.STONE:
			return "marble"
		taken[at] = true
	if int(d.get("marble_count", (marbles as Array).size())) != (marbles as Array).size():
		return "marbles"
	for t: Variant in d.get("tiles", []):
		if not (t is Array) or (t as Array).size() != 4:
			return "tile"
		var name: String = str((t as Array)[2])
		var x: int = int((t as Array)[0])
		var y: int = int((t as Array)[1])
		if x < 0 or y < 0 or x >= w or y >= h or not (name in [TiltBoard.PLUG_NAME, TiltBoard.ICE_NAME]
				or (name != "" and TiltBoard.TILE_NAMES.has(name))):
			return "tile"
	var par: int = int(d.get("par", 0))
	if par < 1 or par > MAX_PAR:
		return "par"
	var bits: float = float(d.get("d", -1.0))
	if bits < 0.0 or bits > MAX_BITS:
		return "d"
	if int(d.get("wrap", 0)) < 0 or int(d.get("wrap", 0)) > 3 or int(d.get("locked", -1)) < -1 \
			or int(d.get("locked", -1)) > 3:
		return "edges"
	for rule: Variant in d.get("set", []):
		if not (str(rule) in OTHER_RULES or (str(rule) != "" and TiltBoard.TILE_NAMES.has(str(rule)))):
			return "set"
	return ""

## The rules a board's `set` may name beside its tiles (TiltGenerator.rules_on).
const OTHER_RULES: PackedStringArray = ["plug", "ice", "locked", "number", "stone", "wrap"]

## Puts checked boards into `pool` (each episode {"boards": [...], "listed": bool}): a board joins, or replaces one
## of a lower revision, unless the solver dropped it. An episode no longer listed was kept only for boards on the
## street, so its boards stay playable but leave future picks, as the retired ids do. Then the rescores apply, for
## future picks only. Answers how many boards joined.
static func merge(pool: StreetPool, episodes: Array, retired: Variant, rescore: Dictionary, dropped: Array) -> int:
	var added: int = 0
	var gone: Array = []
	for ep: Variant in episodes:
		var listed: bool = bool((ep as Dictionary).get("listed", true))
		for b: Variant in (ep as Dictionary)["boards"]:
			var d: Dictionary = b
			var id: String = str(d["id"])
			if dropped.has(id):
				continue
			if pool.add(id, d, d, int(d.get("rev", 1))):
				added += 1
			if not listed:
				gone.append(id)
	if retired is Array:
		gone.append_array(retired as Array)
	pool.retire(gone)
	pool.rescore(rescore)
	return added

## Whether a kept episode file ("ep0001-3f2a9c1e.json") holds a board on the street.
static func holds_street_board(file: String, street: PackedStringArray) -> bool:
	var episode_id: String = file.get_slice("-", 0)
	for id: String in street:
		if StreetPool.base_of(id).begins_with(episode_id + "-"):
			return true
	return false

## The manifest's switches for ads: {"interstitials": bool}, so ads between levels can be turned on or off again
## without an update. Anything but a plain true leaves them off.
static func ads_note(ads: Variant) -> bool:
	if not (ads is Dictionary):
		return false
	return not (ads as Dictionary).has("interstitials") or (ads as Dictionary)["interstitials"] is bool

static func _listed(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var e: Dictionary = entry
	return RegEx.create_from_string(FILE_PATTERN).search(str(e.get("file", ""))) != null \
		and int(e.get("bytes", -1)) > 0 and int(e.get("bytes", -1)) <= MAX_BYTES \
		and RegEx.create_from_string("^[0-9a-f]{64}$").search(str(e.get("sha256", ""))) != null

static func _no(why: String) -> Dictionary:
	return {"ok": false, "why": why}
