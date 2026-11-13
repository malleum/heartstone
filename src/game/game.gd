extends Node3D
## The playable view of a Session: third-person camera, creatures, weave effects, HUD.
## It never decides anything. It sends intent to the Session and draws what the
## Sim reports, which is why single-player, host and client all share this file.
##
##   godot -- [--activity=tarwins_gap_watch] [--name=Egwene] [--join=host] [--auto]
## Controls: WASD move, mouse look, 1-9 weave at the crosshair, Esc release mouse.

var args := {}
var session: Session
var profile: Dictionary
var cam: Camera3D
var cam_yaw := PI
var cam_pitch := -0.28
var me: Node3D                 # my HumanRig
var actors := {}               # sim id -> {node, kind, target: Vector3, yaw}
var fx := {}                   # sim fx id -> Node3D
var variants: Array = []       # generated Trolloc data, shared between enemies
var human_data: Dictionary
var hud: Label
var banner: Label
var known: Array = []
var last_refusal := ""
var refusal_t := 0.0
var my_hp := 100.0
var frame := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Rules.load_data()
	World.build(self)
	Terrain.amp = 0.45
	add_child(Terrain.build_mesh(220.0, 0.75))
	cam = Camera3D.new(); cam.fov = 62.0; add_child(cam)
	_hud()
	var name_: String = args.get("name", "Novice")
	profile = Profile.load_profile(name_)
	if profile.is_empty():
		profile = Profile.create({name = name_, potential_pts = 8, affinity_pts = {fire = 4, earth = 2}})
	known = profile.weaves.keys()
	# Generate the cast before the fight so nothing hitches mid-wave.
	var specs := []
	for i in 8:
		specs.append(Species.roll(Species.TROLLOC, 20 + i, {lod = 1.7, head = ["boar", "wolf", "ram", "hawk", "bear"][i % 5]}))
	var hs := Species.roll(Species.HUMAN, hash(name_), {outfit = profile.origin, fem = 1.0 if profile.power == "saidar" else 0.0, hair = "long" if profile.power == "saidar" else "short"})
	HumanRig.fit(hs)
	specs.append(hs)
	var out := []; out.resize(specs.size())
	var id := WorkerThreadPool.add_group_task(func(i: int) -> void: out[i] = Creature.build(specs[i]), specs.size())
	WorkerThreadPool.wait_for_group_task_completion(id)
	human_data = out.pop_back()
	variants = out
	session = Session.new()
	add_child(session)
	session.snapshot.connect(_on_snapshot)
	session.events.connect(_on_events)
	session.finished.connect(_on_finished)
	session.refused.connect(func(why: String) -> void: last_refusal = why; refusal_t = 1.5)
	if args.has("join"):
		session.join(args.join, profile)
	else:
		session.host(args.get("activity", "tarwins_gap_watch"), profile)
	if not args.has("auto") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height(p.x, p.z), p.z)

# --- input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= ev.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.003, -1.1, 0.3)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var n: int = ev.keycode - KEY_1
		if n >= 0 and n < known.size():
			session.cast(known[n], _aim_point())
	elif ev is InputEventMouseButton and ev.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Where the crosshair meets the ground (marched along the view ray).
func _aim_point() -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	for i in 160:
		var p := from + dir * (i * 0.5)
		if p.y <= Terrain.height(p.x, p.z):
			return p
	return from + dir * 60.0

func _process(dt: float) -> void:
	frame += 1
	refusal_t -= dt
	if session.my_id == 0:
		return
	if args.has("auto") and session.is_host:
		Bot.drive(session.sim, session.my_id)
		cam_yaw = lerp_angle(cam_yaw, session.sim.ents[session.my_id].yaw + PI, 2.0 * dt)
	else:
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		v += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		var move := Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)
		session.send_input(move, cam_yaw + PI)
	_draw_actors(dt)
	_draw_fx(dt)
	if me:
		var pivot := me.position + Vector3(0, 1.65, 0)
		var back := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch) * Vector3(0.55, 0.25, 4.2)
		cam.position = pivot + back
		cam.look_at(pivot + Basis(Vector3.UP, cam_yaw) * Vector3(0.55, 0, -6))
	_draw_hud()

# --- mirroring the sim ----------------------------------------------------------------

func _on_events(list: Array) -> void:
	for e in list:
		match e.e:
			"spawn":
				_spawn_enemy(e.id, e.type, e.pos)
			"die":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					if a.node is Walker:
						(a.node as Walker).vel = Vector3.ZERO
						(a.node as Walker).die(a.node.position - (me.position if me else Vector3.ZERO))
						get_tree().create_timer(6.0).timeout.connect(a.node.queue_free)
					elif a.kind == "player":
						(a.node.get_meta("anim") as AnimationPlayer).play("Death01", 0.15)
					else:
						a.node.queue_free()
					a.dead = true
			"hit":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					if a.node is Walker and not a.get("dead", false):
						(a.node as Walker).hit(a.node.position - (me.position if me else Vector3.ZERO), 0.9)
					elif a.kind == "player" and not a.get("dead", false):
						_play(a, "Hit_Chest", true)
			"form":
				if actors.has(e.id):
					_play(actors[e.id], "Spell_Simple_Enter", true)
			"cast":
				if actors.has(e.id):
					_play(actors[e.id], "Spell_Simple_Shoot", true)
				Weavefx.cast(self, e)
			"blast":
				Weavefx.blast(self, _ground(e.pos), e.radius, e.weave)
			"fx_end":
				if fx.has(e.id):
					fx[e.id].queue_free(); fx.erase(e.id)
			"wave":
				_banner("A wave comes down the pass" if e.left > 0 else "The last of them", 3.0)

func _play(a: Dictionary, clip: String, once := false) -> void:
	var ap: AnimationPlayer = a.node.get_meta("anim")
	if once:
		a.busy = ap.get_animation(clip).length * 0.9
	if ap.current_animation != clip:
		ap.play(clip, 0.12)

func _spawn_enemy(id: int, type: String, pos: Vector3) -> void:
	var row: Dictionary = Rules.enemies[type]
	if row.gen == "TROLLOC":
		var w := Creature.instantiate(variants[id % variants.size()])
		add_child(w)
		w.teleport(pos, 0.0)
		if row.tier > 1:
			w.scale = Vector3.ONE * 1.25
		actors[id] = {node = w, kind = "enemy", target = pos}
	else:
		var post := MeshInstance3D.new()
		var m := CylinderMesh.new(); m.top_radius = 0.22; m.bottom_radius = 0.28; m.height = 2.0
		post.mesh = m; post.position = _ground(pos) + Vector3(0, 1, 0)
		add_child(post)
		actors[id] = {node = post, kind = "post", target = pos}

func _on_snapshot(s: Dictionary) -> void:
	for e in s.ents:
		var id: int = e[0]
		if not actors.has(id):
			# Anything we were not told about by a spawn event is a player.
			var rig := HumanRig.instantiate(human_data)
			add_child(rig)
			rig.position = _ground(Vector3(e[1], 0, e[2]))
			actors[id] = {node = rig, kind = "player", target = rig.position, busy = 0.0}
			if id == session.my_id:
				me = rig
		var a: Dictionary = actors[id]
		a.target = Vector3(e[1], 0, e[2]); a.yaw = e[3]
		if id == session.my_id:
			my_hp = e[4]
	for f in s.fx:
		if not fx.has(f[0]):
			fx[f[0]] = Weavefx.live(self, f[1])
		var n: Node3D = fx[f[0]]
		n.position = _ground(Vector3(f[2], 0, f[3])) + Vector3(0, 1.2, 0)
		if f[1] == "ring":
			n.scale = Vector3(f[4], 1.0, f[4]); n.position.y -= 0.9

func _draw_actors(dt: float) -> void:
	var walkers: Array[Walker] = []
	for id in actors:
		var a: Dictionary = actors[id]
		if not is_instance_valid(a.node) or (a.get("dead", false) and a.kind != "enemy"):
			continue
		if a.node is Walker:
			var w: Walker = a.node
			if not a.get("dead", false):
				# The Walker keeps its own planted-foot gait and simply chases the sim position.
				var to: Vector3 = a.target - w.pos; to.y = 0.0
				w.vel = (to * 3.0).limit_length(5.5) if to.length() > 0.25 else Vector3.ZERO
			walkers.append(w)
		elif a.kind == "player":
			var n: Node3D = a.node
			var tgt := _ground(a.target)
			var speed := n.position.distance_to(tgt) / maxf(dt, 0.001)
			n.position = n.position.lerp(tgt, minf(12.0 * dt, 1.0))
			n.rotation.y = lerp_angle(n.rotation.y, a.yaw, minf(10.0 * dt, 1.0))
			a.busy = a.get("busy", 0.0) - dt
			if a.busy <= 0.0:
				_play(a, "Jog_Fwd" if speed > 0.6 else "Idle")
	for w in walkers:
		w.compute(dt)
		w.apply()

func _draw_fx(_dt: float) -> void:
	pass

# --- HUD ------------------------------------------------------------------------------

func _hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	hud = Label.new(); hud.position = Vector2(18, 14); layer.add_child(hud)
	hud.add_theme_font_size_override("font_size", 17)
	hud.add_theme_color_override("font_outline_color", Color.BLACK); hud.add_theme_constant_override("outline_size", 5)
	banner = Label.new(); layer.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 90; banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_outline_color", Color.BLACK); banner.add_theme_constant_override("outline_size", 6)
	var cross := Label.new(); cross.text = "+"; layer.add_child(cross)
	cross.set_anchors_preset(Control.PRESET_CENTER)

var _banner_t := 0.0
func _banner(text: String, secs: float) -> void:
	banner.text = text; _banner_t = secs

func _draw_hud() -> void:
	_banner_t -= get_process_delta_time()
	if _banner_t <= 0.0 and not _done:
		banner.text = ""
	var lines := ["%s   strength %d/%d   flows %d   renown %d" % [profile.name, int(profile.strength), int(profile.potential), Rules.flow_capacity(profile), int(profile.renown)],
		"Health %d" % int(maxf(my_hp, 0.0)), ""]
	for i in known.size():
		var w: Dictionary = Rules.weaves[known[i]]
		lines.append("%d  %s  (mastery %d)" % [i + 1, w.name, Rules.mastery_level(profile, known[i])])
	if refusal_t > 0.0:
		lines.append(""); lines.append("Cannot weave: " + last_refusal)
	hud.text = "\n".join(lines)

var _done := false
func _on_finished(success: bool, report: Array) -> void:
	_done = true
	banner.text = ("The line held.\n\n" if success else "You fell. In the camp you wake, and remember.\n\n") + "\n".join(report)
	if args.has("auto"):
		print("GAME over success=%s %s" % [success, report])
