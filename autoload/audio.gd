extends Node

# Every clip is optional: a missing file plays nothing, so the game runs the same whether or not
# tools/make_sfx.py has been run.

const SFX_DIR: String = "res://assets/audio/sfx/"
const VOICES: int = 12

const CLIPS: Array[StringName] = [&"tap", &"roll", &"clack", &"pit", &"win", &"star", &"undo", &"hint"]
const SINK_NOTES: int = 4
## About 11 LU under the sink bells (music measures -22 LUFS, a sink -17): a bed, not a tune.
const MUSIC_DB: float = -6.0
const MUSIC_FADE: float = 1.2

var _clips: Dictionary = {}
var _sinks: Array[AudioStream] = []
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _fade: Tween

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
	EventBus.settings_changed.connect(_apply_music)
	_apply_music()

## Starting the music before any input is fine on the web: the browser holds it until the first tap.
func _apply_music() -> void:
	if _music.stream == null:
		return
	var want: bool = Save.music_on
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
	_play(stream, volume_db, pitch)

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
func buzz(milliseconds: int) -> void:
	if not Save.haptics_on:
		return
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(milliseconds)
