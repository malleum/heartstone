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
	sky.sky_top_color = Color(0.28, 0.33, 0.42); sky.sky_horizon_color = Color(0.62, 0.62, 0.64)
	sky.ground_bottom_color = Color(0.08, 0.07, 0.06); sky.ground_horizon_color = Color(0.5, 0.45, 0.4)
	env.sky = Sky.new(); env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true; env.fog_light_color = Color(0.5, 0.52, 0.56); env.fog_density = 0.006
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 42, 0)
	sun.light_color = Color(1.0, 0.9, 0.78); sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	# Cool rim from behind so dark creatures separate from the ground.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, -150, 0)
	rim.light_color = Color(0.6, 0.72, 1.0); rim.light_energy = 0.55
	add_child(rim)
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
	var t0 := Time.get_ticks_usec()
	if walkers.size() > 16 and not args.has("nothreads"):
		# Gait maths is pure per-creature state, so a horde spreads across cores.
		var id := WorkerThreadPool.add_group_task(func(i: int) -> void: walkers[i].compute(dt), walkers.size())
		WorkerThreadPool.wait_for_group_task_completion(id)
	else:
		for w in walkers:
			w.compute(dt)
	var t1 := Time.get_ticks_usec()
	for w in walkers:
		w.apply()
	_bench(t0, t1)
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
		# --weapon=0..3: scythe-sword, axe, spear, club (and always armed).
		if args.has("weapon"): o.weapon_kind = int(args.weapon)
		# --species=myrddraal: the Eyeless on the bench instead.
		if args.get("species", "") == "myrddraal":
			specs.append(Species.roll(Species.MYRDDRAAL, 7 + i, {lod = 1.2}))
		else:
			specs.append(Species.roll(Species.TROLLOC, seed0 + i, o))
	return _generate(specs)

# --- fps bench: frame times over a window, after a warm-up --------------------
var _bt := 0; var _bn := 0; var _b_anim := 0; var _b_apply := 0; var _b_last := 0; var _b_worst := 0
func _bench(t0: int, t1: int) -> void:
	if not args.has("bench"):
		return
	var now := Time.get_ticks_usec()
	if frame > 120:
		var dt := now - _b_last
		_bt += dt; _bn += 1; _b_anim += t1 - t0; _b_apply += now - t1; _b_worst = maxi(_b_worst, dt)
	_b_last = now
	if frame == 120:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if frame == 120 + int(args.bench):
		var vp := get_viewport().get_viewport_rid()
		print("BENCH n=%d  avg %.2f ms (%.0f fps)  worst %.1f ms | gait compute %.2f ms, pose apply %.2f ms | render cpu %.2f ms, gpu %.2f ms | tris/frame %d, draw calls %d" % [
			walkers.size(), _bt / 1000.0 / _bn, 1e6 * _bn / _bt, _b_worst / 1000.0, _b_anim / 1000.0 / _bn, _b_apply / 1000.0 / _bn,
			RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(vp),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		get_tree().quit()

## The stress test: a horde lumbering at the camera. A few generated variants are
## shared between many skeletons, as a real wave spawner would do.
func _mode_horde() -> void:
	var n := int(_f("n", 200))
	var variants := int(_f("variants", 16))
	var data := _trollocs(variants, {lod = _f("lod", 1.7)})
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var cols := int(_f("cols", 14))
	for i in n:
		var x := (i % cols - (cols - 1) * 0.5) * 2.3 + rng.randf_range(-0.7, 0.7)
		var z := -8.0 - (i / cols) * 2.6 + rng.randf_range(-0.8, 0.8)
		var w := _spawn(data[i % variants], x, z, 0.0)
		w.vel = Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(1.15, 1.75)) * _f("speed", 1.0)
		w.phase = rng.randf()
	var y0 := Terrain.height(0, 6)
	_look(Vector3(_f("cx", 0.6), y0 + _f("camy", 2.6), 6), Vector3(0, y0 + 1.2, -12))

func _humans(n: int) -> Array:
	var seed0 := int(_f("seed", 1))
	var outfits: Array = Species.HUMAN.outfit
	var specs := []
	for i in n:
		var o := {outfit = outfits[(i + seed0) % outfits.size()]}
		o.fem = 1.0 if o.outfit in ["aes_sedai", "domani"] or (i % 3 == 1) else 0.0
		if o.fem > 0.5: o.hair = ["long", "bun", "braid", "tail"][i % 4]
		if o.outfit == "aiel": o.hair = "short"
		specs.append(Species.roll(Species.HUMAN, seed0 + i, o))
	return _generate(specs)

## The human test: origin outfits and rolled faces. --mode=humans --dist=1.4 for faces.
func _mode_humans() -> void:
	var n := int(_f("n", 6))
	var data := _humans(n)
	var gap := _f("gap", 1.0)
	Terrain.amp = 0.0
	for i in n:
		var w := _spawn(data[i], (i - (n - 1) * 0.5) * gap, 0.0)
		if args.has("walk"):
			w.vel = Vector3(0, 0, _f("walk", 1.3))
	var d := _f("dist", 4.6); var ang := deg_to_rad(_f("yaw", 0)); var cx := _f("cx", 0)
	_look(Vector3(cx + sin(ang) * d, _f("camy", 1.3), cos(ang) * d), Vector3(cx, _f("aty", 1.0), 0))
	if args.has("walk"):
		follow = walkers[n / 2]; follow_off = Vector3(sin(ang) * d, 0.2, cos(ang) * d)

## Hybrid humans: generated body and clothes on the sourced rig, playing a clip.
## --mode=rig --clip=Walk [--n=3] [--then=Spell_Simple_Shoot --at=30]
func _mode_rig() -> void:
	var n := int(_f("n", 3))
	var outfits: Array = Species.HUMAN.outfit
	var seed0 := int(_f("seed", 1))
	var specs := []
	for i in n:
		var o := {outfit = outfits[(i + seed0) % outfits.size()]}
		o.fem = 1.0 if o.outfit in ["aes_sedai", "domani"] else 0.0
		if o.fem > 0.5: o.hair = "long"
		var s := Species.roll(Species.HUMAN, seed0 + i, o)
		HumanRig.fit(s)
		specs.append(s)
	var data := _generate(specs)
	Terrain.amp = 0.0
	var rigs := []
	for i in n:
		var r := HumanRig.instantiate(data[i])
		r.position = Vector3((i - (n - 1) * 0.5) * 1.3, 0, 0)
		add_child(r)
		rigs.append(r)
		(r.get_meta("anim") as AnimationPlayer).play(args.get("clip", "Walk"))
	if args.has("then"):
		events[int(_f("at", 30))] = func() -> void:
			for r in rigs: (r.get_meta("anim") as AnimationPlayer).play(args.then, 0.2)
	var d := _f("dist", 4.2); var ang := deg_to_rad(_f("yaw", 25))
	_look(Vector3(sin(ang) * d, _f("camy", 1.3), cos(ang) * d), Vector3(0, _f("aty", 1.0), 0))

func _mode_heroes() -> void:
	Terrain.amp = 0.0
	var rigs := []
	var ids: Array = Hero.looks().keys()
	if args.has("looks"):
		ids = Array(args.looks.split(","))
	for i in ids.size():
		var r := Hero.instantiate(ids[i], int(_f("seed", 1)) + i)
		r.position = Vector3((i - (ids.size() - 1) * 0.5) * 1.0, 0, 0)
		add_child(r); rigs.append(r)
		var ap: AnimationPlayer = r.get_meta("anim")
		if i == 0 and not args.has("quiet"): print("HERO clips ", ap.get_animation_list())
		ap.play(args.get("clip", "Idle"))
	if args.has("then"):
		events[int(_f("at", 30))] = func() -> void:
			for r in rigs: (r.get_meta("anim") as AnimationPlayer).play(args.then, 0.2)
	var d := _f("dist", 4.4); var ang := deg_to_rad(_f("yaw", 20))
	_look(Vector3(sin(ang) * d, _f("camy", 1.3), cos(ang) * d), Vector3(0, _f("aty", 1.0), 0))

## Idle line-up, seen from roughly where a third-person player camera would sit.
func _mode_lineup() -> void:
	var n := int(_f("n", 8))
	var data := _trollocs(n)
	var gap := _f("gap", 2.2)
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
	# --attack=chop|sweep|thrust --at=<frame>: one weapon swing, to look at.
	if args.has("attack"):
		events[int(_f("at", 20))] = func() -> void:
			for w in walkers: w.attack(args.attack)
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
