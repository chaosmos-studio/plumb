class_name FrameProbe
extends Node

## Measures frames while a stretch of the game runs: the time between frames, the work the screen notes itself
## (`note`), the renderer's CPU time, the GPU's time where the driver reports it, and draw calls. `begin` starts a
## stretch, `end` closes it with a summary line in the log (STREET_FRAMES ...) and its rows in user://street_frames.csv,
## which `adb exec-out run-as` can read from a debug build.

const CSV: String = "user://street_frames.csv"
## A gap between frames longer than this many refreshes means one was missed.
const MISSED: float = 1.5

var _label: String = ""
var _running: bool = false
var _last_us: int = 0
var _work_ms: float = 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _work: PackedFloat32Array = PackedFloat32Array()
var _render: PackedFloat32Array = PackedFloat32Array()
var _gpu: PackedFloat32Array = PackedFloat32Array()
var _draws: PackedInt32Array = PackedInt32Array()
var _rows: PackedStringArray = PackedStringArray()

func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_rows.append("stretch,frame_ms,work_ms,render_cpu_ms,gpu_ms,draw_calls")

func begin(label: String) -> void:
	_label = label
	_frames.clear()
	_work.clear()
	_render.clear()
	_gpu.clear()
	_draws.clear()
	_last_us = Time.get_ticks_usec()
	_running = true

## The time the screen spent on its own work this frame, in milliseconds.
func note(work_ms: float) -> void:
	_work_ms = work_ms

func end() -> Dictionary:
	_running = false
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	var summary: Dictionary = summarise(_frames, 1000.0 / maxf(refresh, 1.0))
	summary["stretch"] = _label
	summary["work_ms"] = _spread(_work)
	summary["render_cpu_ms"] = _spread(_render)
	summary["gpu_ms"] = _spread(_gpu)
	summary["draws_mean"] = _mean_int(_draws)
	summary["draws_max"] = _max_int(_draws)
	summary["refresh_hz"] = refresh
	summary["vsync"] = DisplayServer.window_get_vsync_mode()
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
	var rid: RID = get_viewport().get_viewport_rid()
	var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(rid) \
		+ RenderingServer.get_frame_setup_time_cpu()
	var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_frames.append(frame_ms)
	_work.append(_work_ms)
	_render.append(render_ms)
	_gpu.append(gpu_ms)
	_draws.append(draws)
	_rows.append("%s,%.3f,%.3f,%.3f,%.3f,%d" % [_label, frame_ms, _work_ms, render_ms, gpu_ms, draws])

## Frame times in milliseconds: their count, the frames a second they came to, percentiles, the worst, and the gaps
## long enough to have missed a refresh of `refresh_ms`.
static func summarise(frames: PackedFloat32Array, refresh_ms: float) -> Dictionary:
	var sorted: PackedFloat32Array = frames.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var missed: int = 0
	var total: float = 0.0
	for ms: float in sorted:
		missed += 1 if ms > refresh_ms * MISSED else 0
		total += ms
	return {
		"frames": n,
		"fps": float(n) * 1000.0 / maxf(total, 0.001),
		"p50_ms": _at(sorted, 0.5),
		"p95_ms": _at(sorted, 0.95),
		"p99_ms": _at(sorted, 0.99),
		"max_ms": sorted[n - 1] if n > 0 else 0.0,
		"missed": missed,
	}

## Mean, 95th percentile and worst.
static func _spread(values: PackedFloat32Array) -> Array[float]:
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	return [snappedf(_mean(values), 0.01), snappedf(_at(sorted, 0.95), 0.01), snappedf(_max(values), 0.01)]

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
