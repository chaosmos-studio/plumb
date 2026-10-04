class_name ReelVideo
extends RefCounted

## A reel written to an MP4 on Android by the phone's own encoder, with no plugin: a MediaRecorder fed
## through a Surface that each frame of the game is drawn onto. Handing a frame over costs more than
## drawing it, so the reel plays slower than life while it records, `rate` frames a second, each one 1/FPS
## of the reel's own time. The recorder's time lapse then lays the frames down FPS to the second, so the
## film runs at its true speed. It only does that while frames come at under half of FPS, which is why
## `rate` stays below FPS / 2.
##
## The film waits in the app's own folder and `keep` copies it into Movies and deletes it either way, so
## nothing stays on the phone that the player did not ask for.

const FPS: int = 30
const MOST_RATE: float = 14.0
const LEAST_RATE: float = 4.0
const WIDTH: int = 720
const BITRATE: int = 8000000
const PATH: String = "user://reel.mp4"
## MediaRecorder's numbers: VideoSource.SURFACE, OutputFormat.MPEG_4 and VideoEncoder.H264.
const SURFACE: int = 2
const MPEG_4: int = 2
const H264: int = 2

var size: Vector2i = Vector2i.ZERO
var rate: float = 10.0
var frames: int = 0
var _recorder: Object
var _surface: Object
var _bitmap: Object
var _buffers: Object
var _started: bool = false

static func available() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("AndroidRuntime")

## Frames a second the game can hand over, from what one frame took in milliseconds: kept under FPS / 2
## for the time lapse, with room for the game's own drawing.
static func rate_for(cost_ms: float) -> float:
	return clampf(floorf(1000.0 / (cost_ms * 1.25 + 30.0)), LEAST_RATE, MOST_RATE)

## A frame of `view`'s size in the film's size: WIDTH across, the height to match, a multiple of 16.
static func size_for(view: Vector2i) -> Vector2i:
	return Vector2i(WIDTH, maxi(16, int(round(float(WIDTH) * view.y / view.x / 16.0)) * 16))

## Starts a film of frames shaped like `view`, handed over `frames_a_second` times a second. False when
## the phone refuses anything, with nothing left behind.
func begin(view: Vector2i, frames_a_second: float) -> bool:
	if not available():
		return false
	rate = frames_a_second
	size = size_for(view)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_recorder = JavaClassWrapper.wrap("android.media.MediaRecorder").call("MediaRecorder")
	if _recorder == null or Gallery.failed("make a MediaRecorder"):
		return false
	_recorder.call("setVideoSource", SURFACE)
	_recorder.call("setOutputFormat", MPEG_4)
	_recorder.call("setOutputFile", ProjectSettings.globalize_path(PATH))
	_recorder.call("setVideoEncoder", H264)
	_recorder.call("setVideoSize", size.x, size.y)
	_recorder.call("setVideoFrameRate", FPS)
	_recorder.call("setVideoEncodingBitRate", BITRATE)
	_recorder.call("setCaptureRate", rate)
	_recorder.call("prepare")
	if Gallery.failed("prepare the recorder at %s and %.0f frames a second" % [size, rate]):
		_recorder.call("release")
		_recorder = null
		return false
	_surface = _recorder.call("getSurface")
	_recorder.call("start")
	if _surface == null or Gallery.failed("start the recorder"):
		cancel()
		return false
	# The wrapper only reads static fields that hold numbers or text, so the bitmap's config comes from
	# valueOf rather than Bitmap.Config.ARGB_8888.
	var argb: Object = JavaClassWrapper.wrap("android.graphics.Bitmap$Config").call("valueOf", "ARGB_8888")
	_bitmap = JavaClassWrapper.wrap("android.graphics.Bitmap").call("createBitmap", size.x, size.y, argb)
	_buffers = JavaClassWrapper.wrap("java.nio.ByteBuffer")
	_started = true
	if _bitmap == null or Gallery.failed("make the frame's bitmap"):
		cancel()
		return false
	print("%s: filming the reel at %s, %.0f frames a second" % [Brand.NAME, size, rate])
	return true

## One frame: the game's picture, brought to the film's size and drawn onto the recorder's surface.
func add(frame: Image) -> void:
	if not _started:
		return
	if frame.get_format() != Image.FORMAT_RGBA8:
		frame.convert(Image.FORMAT_RGBA8)
	if frame.get_size() != size:
		frame.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
	_bitmap.call("copyPixelsFromBuffer", _buffers.call("wrap", frame.get_data()))
	var canvas: Object = _surface.call("lockHardwareCanvas")
	if canvas == null or Gallery.failed("draw frame %d" % frames):
		return
	canvas.call("drawBitmap", _bitmap, 0.0, 0.0, null)
	_surface.call("unlockCanvasAndPost", canvas)
	if not Gallery.failed("hand over frame %d" % frames):
		frames += 1

## Ends the film. True when the file was written.
func finish() -> bool:
	if not _started:
		return false
	_started = false
	_recorder.call("stop")
	var ok: bool = not Gallery.failed("stop the recorder after %d frames" % frames)
	_close()
	return ok and frames > 0 and FileAccess.file_exists(PATH)

## Copies the finished film into Movies as `file_name`, then deletes it. True when it is there.
func keep(file_name: String) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Gallery.keep(bytes, file_name, "video/mp4")

## Stops without keeping anything.
func cancel() -> void:
	if _started:
		_started = false
		_recorder.call("stop")
		JavaClassWrapper.get_exception()
	_close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func _close() -> void:
	if _recorder != null:
		_recorder.call("release")
	if _bitmap != null:
		_bitmap.call("recycle")
	_recorder = null
	_bitmap = null
	_surface = null
