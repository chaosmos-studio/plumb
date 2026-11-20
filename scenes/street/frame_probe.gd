class_name FrameProbe
extends Node

## Measures frames while a stretch of the game runs: the time between frames, the game's own process time, the GPU's
## time where the driver reports it, and draw calls. `begin` starts a stretch, `end` closes it with a summary line in
## the log (STREET_FRAMES ...) and its rows in user://street_frames.csv, which `adb exec-out run-as` can read from a
## debug build.

const CSV: String = "user://street_frames.csv"
## A frame longer than these, in milliseconds, misses a 60 Hz refresh, or two of them.
const LATE_MS: float = 16.7
const VERY_LATE_MS: float = 33.4

var _label: String = ""
var _running: bool = false
var _last_us: int = 0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _cpu: PackedFloat32Array = PackedFloat32Array()
var _gpu: PackedFloat32Array = PackedFloat32Array()
var _draws: PackedInt32Array = PackedInt32Array()
var _rows: PackedStringArray = PackedStringArray()

func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_rows.append("stretch,frame_ms,process_ms,gpu_ms,draw_calls")

func begin(label: String) -> void:
	_label = label
	_frames.clear()
	_cpu.clear()
	_gpu.clear()
	_draws.clear()
	_last_us = Time.get_ticks_usec()
	_running = true

func end() -> Dictionary:
	_running = false
	var summary: Dictionary = summarise(_frames)
	summary["stretch"] = _label
	summary["process_ms_mean"] = _mean(_cpu)
	summary["gpu_ms_mean"] = _mean(_gpu)
	summary["gpu_ms_max"] = _max(_gpu)
	summary["draws_mean"] = _mean_int(_draws)
	summary["draws_max"] = _max_int(_draws)
	summary["refresh_hz"] = DisplayServer.screen_get_refresh_rate()
	summary["static_mb"] = OS.get_static_memory_usage() / 1048576.0
	summary["video_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("STREET_FRAMES %s" % JSON.stringify(summary))
	var file: FileAccess = FileAccess.open(CSV, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_rows) + "\n")
	return summary

func _process(_delta: float) -> void:
	if not _running:
		return
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_frames.append(frame_ms)
	_cpu.append(process_ms)
	_gpu.append(gpu_ms)
	_draws.append(draws)
	_rows.append("%s,%.3f,%.3f,%.3f,%d" % [_label, frame_ms, process_ms, gpu_ms, draws])

## Frame times in milliseconds: their count, percentiles, the worst, and the share late for 60 Hz.
static func summarise(frames: PackedFloat32Array) -> Dictionary:
	var sorted: PackedFloat32Array = frames.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var late: int = 0
	var very_late: int = 0
	for ms: float in sorted:
		late += 1 if ms > LATE_MS else 0
		very_late += 1 if ms > VERY_LATE_MS else 0
	return {
		"frames": n,
		"p50_ms": _at(sorted, 0.5),
		"p95_ms": _at(sorted, 0.95),
		"p99_ms": _at(sorted, 0.99),
		"max_ms": sorted[n - 1] if n > 0 else 0.0,
		"late_share": float(late) / float(maxi(n, 1)),
		"very_late": very_late,
	}

static func _at(sorted: PackedFloat32Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(roundi(q * float(sorted.size() - 1)), 0, sorted.size() - 1)]

static func _mean(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(maxi(values.size(), 1))

static func _max(values: PackedFloat32Array) -> float:
	var top: float = 0.0
	for v: float in values:
		top = maxf(top, v)
	return top

static func _mean_int(values: PackedInt32Array) -> float:
	var total: int = 0
	for v: int in values:
		total += v
	return float(total) / float(maxi(values.size(), 1))

static func _max_int(values: PackedInt32Array) -> int:
	var top: int = 0
	for v: int in values:
		top = maxi(top, v)
	return top
