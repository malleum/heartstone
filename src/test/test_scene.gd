extends Node3D
## Test bench for the procedural character spike. Pick a view with `-- --mode=<name>`.

var args := {}
var cam: Camera3D
var sun: DirectionalLight3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_world()
	call("_mode_" + args.get("mode", "lineup"))

func _world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.22, 0.26, 0.34); sky.sky_horizon_color = Color(0.55, 0.5, 0.45)
	sky.ground_bottom_color = Color(0.08, 0.07, 0.06); sky.ground_horizon_color = Color(0.5, 0.45, 0.4)
	env.sky = Sky.new(); env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true; env.fog_light_color = Color(0.5, 0.46, 0.42); env.fog_density = 0.006
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_color = Color(1.0, 0.9, 0.78); sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	Terrain.amp = float(args.get("amp", "1"))
	add_child(Terrain.build_mesh(160.0, 0.5))
	cam = Camera3D.new(); cam.fov = 50.0; add_child(cam)

func _look(from: Vector3, at: Vector3) -> void:
	cam.position = from
	cam.look_at(at)

## Build specs on worker threads; returns generated data in order.
func _generate(specs: Array) -> Array:
	var out := []; out.resize(specs.size())
	var t0 := Time.get_ticks_msec()
	var id := WorkerThreadPool.add_group_task(func(i: int) -> void: out[i] = Creature.build(specs[i]), specs.size())
	WorkerThreadPool.wait_for_group_task_completion(id)
	var tris := 0; var ms := 0
	for d in out:
		tris += d.tris; ms += d.ms
	print("generated %d creatures in %d ms wall (%d ms avg each, %d tris avg)" % [specs.size(), Time.get_ticks_msec() - t0, ms / specs.size(), tris / specs.size()])
	return out

var walkers: Array[Walker] = []
var follow: Walker
var follow_off := Vector3.ZERO
var frame := 0
var events := {}     # frame -> Callable

func _spawn(data: Dictionary, x: float, z: float, yaw := 0.0) -> Walker:
	var w := Creature.instantiate(data)
	add_child(w)
	w.teleport(Vector3(x, 0, z), yaw)
	walkers.append(w)
	return w

func _process(dt: float) -> void:
	frame += 1
	if events.has(frame):
		events[frame].call()
	for w in walkers:
		w.compute(dt)
		w.apply()
	if slide_check and not walkers.is_empty():
		_audit()
	if follow:
		var c := Vector3(follow.pos.x, follow.root_y + follow.L, follow.pos.z)
		_look(c + follow_off, c)

func _f(key: String, def: float) -> float:
	return float(args.get(key, str(def)))

func _trollocs(n: int, extra := {}) -> Array:
	var heads := ["boar", "wolf", "ram", "hawk", "bear"]
	var seed0 := int(_f("seed", 1))
	var specs := []
	for i in n:
		var o := {head = heads[(i + seed0) % heads.size()]}
		o.merge(extra)
		if args.has("head"): o.head = args.head
		specs.append(Species.roll(Species.TROLLOC, seed0 + i, o))
	return _generate(specs)

## Idle line-up, seen from roughly where a third-person player camera would sit.
func _mode_lineup() -> void:
	var n := int(_f("n", 8))
	var data := _trollocs(n)
	var gap := _f("gap", 1.9)
	for i in n:
		_spawn(data[i], (i - (n - 1) * 0.5) * gap, 0.0)
	var d := _f("dist", 9); var ang := deg_to_rad(_f("yaw", 0)); var cx := _f("cx", 0)
	var y0 := Terrain.height(cx, 0)
	_look(Vector3(cx + sin(ang) * d, y0 + _f("camy", 2.0), cos(ang) * d), Vector3(cx, y0 + _f("aty", 1.5), 0))

## A few creatures crossing uneven ground, camera tracking from the side.
func _mode_walk() -> void:
	var n := int(_f("n", 1))
	var data := _trollocs(n)
	var speed := _f("speed", 1.6)
	for i in n:
		var w := _spawn(data[i], -3.0, -i * 2.2, PI * 0.5)
		w.vel = Vector3(speed, 0, 0)
	follow = walkers[0]
	var ang := deg_to_rad(_f("yaw", 0)); var d := _f("dist", 5.5)
	follow_off = Vector3(sin(ang) * d, _f("camy", 0.3), cos(ang) * d)
	if args.has("hit"):
		events[int(args.hit)] = func() -> void: walkers[0].hit(Vector3(-1, 0, 0.3), _f("force", 1.0))
	if args.has("die"):
		events[int(args.die)] = func() -> void: walkers[0].die(Vector3(-1, 0, 0))
	if args.has("stop"):
		events[int(args.stop)] = func() -> void: walkers[0].vel = Vector3.ZERO
	slide_check = true

# Foot-slide audit: how far does each skinned toe joint drift while planted?
var slide_check := false
var _plant: Array = [null, null]
var _worst := 0.0
func _audit() -> void:
	var w := walkers[0]
	for i in 2:
		if w.ft_swing[i] or w.dead >= 0.0:
			_plant[i] = null
			continue
		var p: Vector3 = w.transform * w.sk.get_bone_global_pose(Creature.TOE + Creature.RIGHT * i).origin
		if _plant[i] == null:
			_plant[i] = p
		_worst = maxf(_worst, p.distance_to(_plant[i]))
		if args.has("trace") and i == 0:
			print(frame, " L planted ", p, " want ", w.ft_pos[i])

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and slide_check:
		print("max planted-foot drift: %.1f mm" % (_worst * 1000.0))
