extends Node

# Sounds and haptics. Every clip is optional: a missing file plays nothing, so the game runs the same
# whether or not tools/make_sfx.py has been run.

const SFX_DIR: String = "res://assets/audio/sfx/"
const VOICES: int = 12

const CLIPS: Array[StringName] = [&"tap", &"roll", &"clack", &"pit", &"win", &"star", &"undo", &"hint"]
const SINK_NOTES: int = 4

var _clips: Dictionary = {}
var _sinks: Array[AudioStream] = []
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0

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

## Round-robins the voices, so a sink during a clack does not cut the clack off.
func play(key: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _clips.get(key, null)
	_play(stream, volume_db, pitch)

## Each marble colour sinks on its own note of a pentatonic scale.
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
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()

# Web is included on purpose: a phone running the web build reports mobile=false. Keep buzzes short; a
# long one on every move irritates fast.
func buzz(milliseconds: int) -> void:
	if not Save.haptics_on:
		return
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Input.vibrate_handheld(milliseconds)
