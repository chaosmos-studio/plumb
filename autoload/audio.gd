extends Node

# Every clip is optional: a missing file plays nothing, so the game runs the same whether or not
# tools/make_sfx.py has been run.

const SFX_DIR: String = "res://assets/audio/sfx/"
const VOICES: int = 12

const CLIPS: Array[StringName] = [&"tap", &"roll", &"clack", &"pit", &"win", &"star", &"undo", &"hint", &"plop", &"knock",
	&"clink", &"chord", &"nooo", &"mrrp", &"huff", &"boing", &"pop", &"cannon", &"fanfare"]
const SINK_NOTES: int = 4
## About 11 LU under the sink bells (music measures -22 LUFS, a sink -17): a bed, not a tune.
const MUSIC_DB: float = -6.0
const MUSIC_FADE: float = 1.2
## The rolling bed (MATH.md section 19): its level at full speed, and how fast it follows the board, rising
## quicker than it falls so a roll starts on the beat and dies away softly. A faster roll also sounds a little
## higher, as a real one does.
const ROLLING_DB: float = -13.0
const ROLLING_RISE: float = 30.0
const ROLLING_FALL: float = 9.0
const ROLLING_PITCH: Vector2 = Vector2(0.86, 1.08)
## The kit sounds each star a little higher than the last (kit/shell/result.gd, 0.08 a star). Here they climb
## the win chord instead: E, G and C above the star's own G.
const STAR_STEP: float = 0.08
const STAR_NOTES: PackedFloat32Array = [0.8409, 1.0, 1.3348]

var _clips: Dictionary = {}
var _sinks: Array[AudioStream] = []
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _fade: Tween
## The studio's beat at launch plays alone: the music waits for it (kit/ui/intro.gd).
var _held: bool = false
var _rolling: AudioStreamPlayer
var _roll_want: float = 0.0
var _roll_level: float = 0.0

func _ready() -> void:
	for key: StringName in CLIPS:
		var path: String = SFX_DIR + String(key) + ".ogg"
		if ResourceLoader.exists(path):
			_clips[key] = load(path)
	for k: int in range(SINK_NOTES):
		var path: String = SFX_DIR + "sink_%d.ogg" % k
		if ResourceLoader.exists(path):
			_sinks.append(load(path))
	for i: int in range(VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	var track: String = SFX_DIR + "music.ogg"
	if ResourceLoader.exists(track):
		var stream: AudioStreamOggVorbis = load(track)
		stream.loop = true
		_music.stream = stream
	_rolling = AudioStreamPlayer.new()
	add_child(_rolling)
	var bed: String = SFX_DIR + "rolling.ogg"
	if ResourceLoader.exists(bed):
		var stream: AudioStreamOggVorbis = load(bed)
		stream.loop = true
		_rolling.stream = stream
	EventBus.settings_changed.connect(_apply_music)
	_apply_music()

## How much is rolling, from 0 for nothing to about 1 for a few marbles at full speed. The board sets it every
## frame, and the bed follows.
func rolling(amount: float) -> void:
	_roll_want = clampf(amount, 0.0, 1.5)

func _process(delta: float) -> void:
	if _rolling.stream == null:
		return
	var rate: float = ROLLING_RISE if _roll_want > _roll_level else ROLLING_FALL
	_roll_level = lerpf(_roll_level, _roll_want if Save.sound_on else 0.0, 1.0 - exp(-rate * delta))
	if _roll_level < 0.01:
		if _rolling.playing:
			_rolling.stop()
		return
	if not _rolling.playing:
		# Each roll starts somewhere new in the loop, so no two sound alike.
		_rolling.play(randf() * _rolling.stream.get_length())
	_rolling.volume_db = ROLLING_DB + linear_to_db(_roll_level) + Save.volume_db(Save.sound_volume)
	_rolling.pitch_scale = lerpf(ROLLING_PITCH.x, ROLLING_PITCH.y, clampf(_roll_level, 0.0, 1.0))

func hold_music(on: bool) -> void:
	_held = on
	_apply_music()

## Starting the music before any input is fine on the web: the browser holds it until the first tap.
func _apply_music() -> void:
	if _music.stream == null:
		return
	var want: bool = Save.music_on and not _held
	if want and not _music.playing:
		_music.volume_db = -40.0
		_music.play()
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", _music_db() if want else -40.0, MUSIC_FADE)
	if not want:
		_fade.tween_callback(_music.stop)

## Called while a volume slider moves: the music follows at once, without the fade.
func hear() -> void:
	if _music.stream == null:
		return
	if _fade != null:
		_fade.kill()
	if Save.music_on and not _music.playing:
		_music.play()
	elif not Save.music_on:
		_music.stop()
	_music.volume_db = _music_db()

func _music_db() -> float:
	return MUSIC_DB + Save.volume_db(Save.music_volume)

## Round-robins the voices, so a sink during a clack does not cut the clack off.
func play(key: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _clips.get(key, null)
	if key == &"star":
		pitch = star_pitch(pitch)
	_play(stream, volume_db, pitch)

## The kit's pitch for the k-th star, 1 + 0.08 k, as the k-th note of the chord. Any other pitch is kept.
static func star_pitch(pitch: float) -> float:
	var k: int = roundi((pitch - 1.0) / STAR_STEP)
	if k < 0 or k >= STAR_NOTES.size() or absf(1.0 + k * STAR_STEP - pitch) > 0.001:
		return pitch
	return STAR_NOTES[k]

func sink(colour: int) -> void:
	if _sinks.is_empty():
		return
	_play(_sinks[colour % _sinks.size()], -2.0, 1.0)

func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null or not Save.sound_on:
		return
	var voice: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db + Save.volume_db(Save.sound_volume)
	voice.pitch_scale = pitch
	voice.play()

# Web is included on purpose: a phone running the web build reports mobile=false.
## `strength` runs 0 to 1 on phones that can vary it, and -1 leaves it to the phone.
func buzz(milliseconds: int, strength: float = -1.0) -> void:
	if not Save.haptics_on:
		return
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(milliseconds, strength)
