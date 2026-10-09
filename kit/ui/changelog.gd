class_name Changelog
extends RefCounted

## The release workflow applies these same rules to name the build, derive Play's version code and fill
## Play's "What's new". The newest section comes first as `## x.y.z` (a ` - YYYY-MM-DD` after it is
## ignored), and every line under it is one `- ` note. HTML comments are skipped. Minor and patch run 0 to
## 99, so the code major * 10000 + minor * 100 + patch grows with every version.

const PATH: String = "res://CHANGELOG.md"
## Play's limit for one language's "What's new".
const PLAY_LIMIT: int = 500
## The highest version code Play accepts.
const MAX_CODE: int = 2100000000
const HEADING: String = "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)( - [0-9]{4}-[0-9]{2}-[0-9]{2})?$"

class Entry:
	var version: String = ""
	var code: int = 0
	var notes: PackedStringArray = PackedStringArray()
	var error: String = ""

	func play_text() -> String:
		var lines: PackedStringArray = PackedStringArray()
		for note: String in notes:
			lines.append("- " + note)
		return "\n".join(lines)

static func version() -> String:
	if FileAccess.file_exists(PATH):
		var top: Entry = parse(FileAccess.get_file_as_string(PATH))
		if top.version != "":
			return top.version
	return str(ProjectSettings.get_setting("application/config/version", ""))

static func parse(text: String) -> Entry:
	var entry: Entry = Entry.new()
	var bare: String = RegEx.create_from_string("(?s)<!--.*?-->").sub(text, "", true)
	var lines: PackedStringArray = bare.split("\n")
	var start: int = -1
	for i: int in range(lines.size()):
		lines[i] = lines[i].strip_edges(false, true)
		if start < 0 and lines[i].begins_with("## "):
			start = i
	if start < 0:
		entry.error = "no \"## x.y.z\" section"
		return entry
	var heading: String = lines[start].substr(3).strip_edges()
	var parts: RegExMatch = RegEx.create_from_string(HEADING).search(heading)
	if parts == null or parts.get_string(1).length() > 6:
		entry.error = "the newest heading \"## %s\" is not a plain x.y.z" % heading
		return entry
	var minor: int = parts.get_string(2).to_int()
	var patch: int = parts.get_string(3).to_int()
	var code: int = parts.get_string(1).to_int() * 10000 + minor * 100 + patch
	if minor > 99 or patch > 99:
		entry.error = "%s: minor and patch run 0 to 99" % heading
		return entry
	if code < 1 or code > MAX_CODE:
		entry.error = "%s gives version code %d, outside Play's 1 to %d" % [heading, code, MAX_CODE]
		return entry
	entry.version = "%s.%d.%d" % [parts.get_string(1), minor, patch]
	entry.code = code
	for i: int in range(start + 1, lines.size()):
		var line: String = lines[i]
		if line.begins_with("## "):
			break
		if line == "":
			continue
		if not line.begins_with("- ") or line.substr(2).strip_edges() == "":
			entry.error = "every line under \"## %s\" must be one \"- \" note, not \"%s\"" % [heading, line]
			return entry
		entry.notes.append(line.substr(2).strip_edges())
	if entry.notes.is_empty():
		entry.error = "the %s section has no \"- \" notes" % entry.version
	elif entry.play_text().length() > PLAY_LIMIT:
		entry.error = "the %s notes are %d characters, over Play's %d" % [entry.version, entry.play_text().length(), PLAY_LIMIT]
	return entry
