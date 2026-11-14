extends Node3D
## The playable view of a Session: third-person camera, creatures, weave effects, HUD.
## It never decides anything. It sends intent to the Session and draws what the
## Sim reports, which is why single-player, host and client all share this file.
##
##   godot -- [--activity=tarwins_gap_watch] [--name=Egwene] [--join=host] [--auto]
## Controls: WASD run (camera-relative), mouse look, left click weaves the selected
## weave at the crosshair, 1-9 / wheel / Q,E select, Esc frees the mouse.

var args := {}
var session: Session
var profile: Dictionary
var cam: Camera3D
var cam_yaw := PI
var cam_pitch := -0.18
var cam_dist := 3.6
var face_yaw := 0.0            # my character faces its travel direction, or the aim while weaving
var aim_t := 0.0               # seconds left facing the aim after a cast
var selected := 0
var shake := 0.0               # camera trauma, 0..1, decays every frame
var me: Node3D                 # my HumanRig
var actors := {}               # sim id -> {node, kind, target: Vector3, yaw}
var fx := {}                   # sim fx id -> Node3D
var variants: Array = []       # generated Trolloc data, shared between enemies
var hud: Label
var banner: Label
var known: Array = []
var last_refusal := ""
var refusal_t := 0.0
var my_hp := 100.0
var frame := 0

func _ready() -> void:
	args = Launch.args if not Launch.args.is_empty() else Launch.cmdline()
	Rules.load_data()
	World.build(self)
	Terrain.amp = 0.45
	cam = Camera3D.new(); cam.fov = 70.0; add_child(cam)
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
	var out := []; out.resize(specs.size())
	var id := WorkerThreadPool.add_group_task(func(i: int) -> void: out[i] = Creature.build(specs[i]), specs.size())
	WorkerThreadPool.wait_for_group_task_completion(id)
	variants = out
	session = Session.new()
	add_child(session)
	session.started.connect(_on_started)
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
	var n_known := maxi(known.size(), 1)
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= ev.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.003, -1.2, 0.7)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif (ev.keycode == KEY_ENTER and _done) or ev.keycode == KEY_F10:
			_to_camp()
		elif ev.keycode == KEY_Q:
			selected = posmod(selected - 1, n_known)
		elif ev.keycode == KEY_E:
			selected = posmod(selected + 1, n_known)
		var n: int = ev.keycode - KEY_1
		if n >= 0 and n < known.size():
			selected = n
	elif ev is InputEventMouseButton and ev.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_cast_selected()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected = posmod(selected + 1, n_known)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected = posmod(selected - 1, n_known)

func _cast_selected() -> void:
	if known.is_empty() or me == null:
		return
	var at := _aim_point()
	session.cast(known[selected], at)
	# Turn to the target at once so the cast animation throws the right way.
	face_yaw = atan2(at.x - me.position.x, at.z - me.position.z)
	aim_t = 1.2

## What the crosshair means: the enemy nearest the view ray if one is close to it,
## otherwise the ground the ray lands on. Players aim at Trollocs, not at dirt.
func _aim_point() -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var best := Vector3.ZERO
	var best_miss := 1.4
	for id in actors:
		var a: Dictionary = actors[id]
		if a.kind == "player" or a.get("dead", false) or not is_instance_valid(a.node):
			continue
		var c: Vector3 = a.node.position + Vector3(0, 1.2, 0)
		var along := (c - from).dot(dir)
		if along < 2.0 or along > 90.0:
			continue
		var miss := (c - (from + dir * along)).length() - along * 0.012
		if miss < best_miss:
			best_miss = miss; best = a.node.position
	if best != Vector3.ZERO:
		return best
	for i in 240:
		var p := from + dir * (i * 0.4)
		if p.y <= Terrain.height(p.x, p.z):
			return p
	return _ground(from + dir * 45.0)

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
		aim_t -= dt
		if aim_t <= 0.0 and move.length() > 0.1:
			face_yaw = atan2(move.x, move.z)
		session.send_input(move, face_yaw)
	if args.has("fxdemo"):
		_fx_demo(dt)
	_draw_actors(dt)
	_draw_fx(dt)
	if me:
		# Orbit camera: the view direction itself pitches, so looking up shows the sky and
		# looking down the ground at your feet. The shoulder offset keeps the character
		# off the crosshair.
		var pivot := me.position + Vector3(0, 1.55, 0)
		var view := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)
		var want := pivot + view * Vector3(0.6, 0.15, cam_dist)
		want.y = maxf(want.y, Terrain.height(want.x, want.z) + 0.35)
		# Trauma-squared shake: small hits barely register, big ones kick.
		shake = maxf(shake - dt * 1.8, 0.0)
		var k := shake * shake
		cam.position = want + view * Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.12 * k
		cam.basis = view * Basis.from_euler(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02 * k)
	_draw_hud()

## `-- --auto --fxdemo`: fire every instant weave effect in turn in front of the
## camera, so effects can be reviewed in a render without waiting for a real cast.
var _demo_t := 1.0
var _demo_i := 0
func _fx_demo(dt: float) -> void:
	_demo_t -= dt
	if _demo_t > 0.0 or me == null:
		return
	_demo_t = 1.0
	var list := ["lightning", "riven_earth", "balefire", "hammer_of_air", "shield_of_air", "healing", "blossoms_of_fire"]
	var id: String = list[_demo_i % list.size()]; _demo_i += 1
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(0.25, 0, -1).normalized()
	var at := _ground(me.position + dir * 12.0)
	if id == "blossoms_of_fire":
		Weavefx.blast(self, at, 3.2, id)
	else:
		Weavefx.cast(self, {weave = id, kind = Rules.weaves[id].kind, pos = me.position, at = at, dir = dir})
	print("FXDEMO ", frame, " ", id)

## Leaving mid-activity (F10) abandons it: nothing is awarded, nothing is lost.
func _to_camp() -> void:
	multiplayer.multiplayer_peer = null
	Launch.args = {}
	get_tree().change_scene_to_file("res://src/game/camp.tscn")

## Blasts shake the camera by size and nearness.
func shake_at(at: Vector3, radius: float) -> void:
	if me:
		shake = minf(1.0, shake + clampf(radius * 2.2 / maxf(at.distance_to(me.position), 3.0), 0.0, 0.8))

## The ground can only be built once we know which activity (and so which map) this
## is: a joining client learns that from the host.
func _on_started(_my_id: int, activity: String) -> void:
	Map.use(Rules.activities[activity].get("map", "open"))
	add_child(Terrain.build_mesh(240.0, 0.75))
	if Map.id == "tarwins_gap":
		Scenery.tarwins_gap(self)

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
					Sfx.play(self, "hum", _ground(actors[e.id].target) + Vector3(0, 1.4, 0), -8.0)
			"attack":
				# A lunge at the victim: the gait has no attack clip, so borrow the hit spring.
				if actors.has(e.id) and actors.has(e.target) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					var w: Walker = actors[e.id].node
					w.hit((_ground(actors[e.target].target) - w.position).normalized(), 0.75)
					Sfx.play(self, "thud", w.position + Vector3(0, 1.2, 0), 0.0)
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
			var rig := Hero.instantiate(Hero.kind_for(profile) if id == session.my_id else Hero.LOOKS.keys()[id % Hero.LOOKS.size()], id)
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
				_play(a, ("Sprint" if speed > 6.5 else "Jog_Fwd") if speed > 0.6 else "Idle")
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
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.add_theme_font_size_override("font_size", 22)
	cross.add_theme_color_override("font_outline_color", Color.BLACK); cross.add_theme_constant_override("outline_size", 4)

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
		lines.append("%s %d  %s  (mastery %d)" % [">" if i == selected else "  ", i + 1, w.name, Rules.mastery_level(profile, known[i])])
	if refusal_t > 0.0:
		lines.append(""); lines.append("Cannot weave: " + last_refusal)
	hud.text = "\n".join(lines)

var _done := false
func _on_finished(success: bool, report: Array) -> void:
	_done = true
	banner.text = ("The line held.\n\n" if success else "You fell. In the camp you wake, and remember.\n\n") + "\n".join(report)
	Launch.report = report
	Launch.last_name = profile.name
	if not args.has("auto"):
		banner.text += "\n\nEnter: back to camp"
	if args.has("auto"):
		print("GAME over success=%s %s" % [success, report])
