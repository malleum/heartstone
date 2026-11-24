class_name Perf
## --perf: every two seconds, one line of where the frame goes: fps, the engine's own
## process and render numbers, and the game's parts timed by hand (`Perf.time`).
## Costs nothing without the flag.

static var on := false
static var _acc := {}      # part -> usec this window
static var _n := 0         # frames this window
static var _t0 := 0

static func setup() -> void:
	on = "--perf" in OS.get_cmdline_user_args() or Launch.cmdline().has("perf")
	_t0 = Time.get_ticks_msec()

## Add `usec` to a part (call with Time.get_ticks_usec() - start).
static func add(part: String, usec: int) -> void:
	if on:
		_acc[part] = int(_acc.get(part, 0)) + usec

## Once per frame, from whoever owns the frame.
static func frame() -> void:
	if not on:
		return
	_n += 1
	var now := Time.get_ticks_msec()
	if now - _t0 < 2000:
		return
	var parts := []
	for k in _acc:
		parts.append("%s=%.2f" % [k, float(_acc[k]) / 1000.0 / maxf(_n, 1)])
	print("PERF fps=%d process=%.2fms physics=%.2fms draws=%d prims=%dk nodes=%d objs=%d vram=%dMB | %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576),
		" ".join(parts)])
	_acc = {}; _n = 0; _t0 = now
