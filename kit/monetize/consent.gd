class_name Consent
extends RefCounted

## Our own consent sheet, asked only where the law needs it (the EEA, the UK and Switzerland), and the answer it
## keeps. Ads pass it to LevelPlay, and Analytics counts only where no consent is needed or the player said yes.
## The region is a guess from the phone's own settings: a clock on Europe's time zones, with a locale that names a
## European country, no country, or the US English many phones keep. So a European phone set to US English is
## asked, and an Indian phone set to UK English is not.

enum Status { NOT_REQUIRED, UNKNOWN, GRANTED, DENIED }

const FILE: String = "user://consent.cfg"
## The EEA (the EU, Iceland, Liechtenstein and Norway), the UK and Switzerland, as ISO 3166 codes.
const REGIONS: PackedStringArray = [
	"AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT",
	"NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE", "IS", "LI", "NO", "GB", "CH",
]
## Europe's UTC offsets through the year, in minutes: the Azores in winter to Finland in summer.
const EUROPE_BIAS: Vector2i = Vector2i(-60, 180)

## Tests point it elsewhere.
static var path: String = FILE

## True where the sheet is asked, whatever the answer. A debug build can be made to ask on any phone (forced).
static func required() -> bool:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return forced() or needs(OS.get_locale(), bias)

static func needs(locale: String, bias_minutes: int) -> bool:
	if bias_minutes < EUROPE_BIAS.x or bias_minutes > EUROPE_BIAS.y:
		return false
	var region: String = country(locale)
	return region == "" or region == "US" or REGIONS.has(region)

## The region of a locale such as "en_GB" or "sr_Latn_RS", or "" when it names none.
static func country(locale: String) -> String:
	var parts: PackedStringArray = locale.split("_")
	for i: int in range(parts.size() - 1, 0, -1):
		if parts[i].length() == 2:
			return parts[i].to_upper()
	return ""

static func status() -> Status:
	if not required():
		return Status.NOT_REQUIRED
	match String(_file().get_value("consent", "answer", "")):
		"granted":
			return Status.GRANTED
		"denied":
			return Status.DENIED
	return Status.UNKNOWN

## Analytics' rule: counted where no consent is needed, or where the player said yes.
static func counts(state: Status) -> bool:
	return state == Status.NOT_REQUIRED or state == Status.GRANTED

static func answer(granted: bool) -> void:
	var file: ConfigFile = _file()
	file.set_value("consent", "answer", "granted" if granted else "denied")
	file.save(path)

## Debug builds only: set `force=true` under [debug] in user://consent.cfg (PUBLISHING.md) to see the sheet on a
## phone outside Europe.
static func forced() -> bool:
	return OS.is_debug_build() and bool(_file().get_value("debug", "force", false))

## At launch: the sheet where an answer is needed and none was given yet, and `on_done` once there is one. Hosted
## on the root, so a screen changing underneath never takes it away.
static func ask_if_needed(node: Node, on_done: Callable) -> void:
	if status() != Status.UNKNOWN:
		on_done.call()
		return
	ask(node.get_tree().root, on_done, false)

## The sheet itself, also behind Settings' "Privacy choices", where it may be closed without a new answer.
static func ask(host: Node, on_done: Callable, dismissable: bool) -> Sheet:
	var sheet: Sheet = Sheet.open(host, dismissable)
	var c: VBoxContainer = sheet.content
	c.add_child(UI.title("Ads and stats", 52))
	var body: Label = UI.label("%s is free, with ads from Unity. May Unity use data from this phone to choose ads for you, and may we count how the game is played?" % Brand.NAME, 28)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(body)
	var note: Label = UI.caption("You can change this in Settings, under Privacy choices.", 22)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(note)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	# Equal weight for both answers, as the law asks.
	for choice: bool in [true, false]:
		var button: Button = UI.button("Allow" if choice else "Don't allow", UI.Style.SECONDARY)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			answer(choice)
			sheet.close()
			if on_done.is_valid():
				on_done.call())
		row.add_child(button)
	c.add_child(row)
	var policy: Button = UI.button("Privacy policy", UI.Style.GHOST)
	policy.pressed.connect(func() -> void: OS.shell_open(GameCredits.PRIVACY))
	c.add_child(policy)
	return sheet

static func _file() -> ConfigFile:
	var file: ConfigFile = ConfigFile.new()
	file.load(path)
	return file
