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
var punch := 0.0               # a landed blow pushes the view in for an instant
var me: Node3D                 # my HumanRig
var actors := {}               # sim id -> {node, kind, target: Vector3, yaw}
var fx := {}                   # sim fx id -> Node3D
var variants: Array = []       # generated Trolloc data, shared between enemies
var fade := {}                 # generated Myrddraal data
var hud: Hud
var hurt_t := 0.0              # 1 when just struck, fading: the HUD reddens the edges
var banner: Label
var known: Array = []
var last_refusal := ""
var refusal_t := 0.0
var my_hp := 100.0
var clock := 0.0
var ready_at := {}                # weave -> clock time it can be woven again
var my_stamina: float = Rules.TUNE.stamina
var frame := 0
var ammo := {}                    # weapon -> arrows, knives or spears left
var held_since := -1.0            # clock time the attack button went down, or -1
var flash_t := 0.0                # a parry just rang: the HUD flashes
var flash_text := ""
var holds := {}                   # "caster/weave/target" -> {node, id, weave, target, tied}

func _ready() -> void:
	args = Launch.args if not Launch.args.is_empty() else Launch.cmdline()
	Rules.load_data()
	Terrain.amp = 0.45
	cam = Camera3D.new(); cam.fov = 70.0; add_child(cam)
	_hud()
	var name_: String = args.get("name", "Novice")
	profile = Profile.load_profile(name_)
	if profile.is_empty():
		# --aff=water makes a throwaway character strong in that Power, to try its weaves.
		profile = Profile.create({name = name_, potential_pts = 8, affinity_pts = {args.aff: 6} if args.has("aff") else {fire = 4, earth = 2}})
	# --weaves=a,b adds weaves to a throwaway channeller and --tie teaches tying off.
	if args.has("weaves"):
		for w in args.weaves.split(","):
			if Rules.weaves.has(w):
				profile.weaves[w] = {known = true, xp = 0.0}
	if args.has("tie"):
		profile.techniques = ["tie_off"]
	if args.has("flows"):
		profile.channelled = Rules.TUNE.flow_steps[clampi(int(args.flows), 2, 10)]
	# --class=warder|aiel|hunter makes a throwaway fighter, to try arms in a render.
	if args.has("class") and profile.get("cls", "channeller") != args.class:
		profile = Profile.create({name = name_, cls = args.class, stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = Array(args.kit.split(",")) if args.has("kit") else Rules.CLASSES[args.class].kit})
		# --forms: the throwaway fighter knows every form its weapons allow.
		if args.has("forms"):
			for f in Rules.forms:
				if profile.kit.any(func(w: String) -> bool: return Rules.weapons[w].family == Rules.forms[f].family):
					profile.forms[f] = {known = true}
	# The bar holds what you can do with your hands: weaves, then what you carry.
	known = profile.weaves.keys() + profile.get("kit", []) + profile.get("forms", {}).keys().filter(func(f: String) -> bool: return Rules.forms.has(f))
	for w in profile.get("kit", []):
		var row: Dictionary = Rules.weapons[w]
		ammo[w] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	# Generate the cast before the fight so nothing hitches mid-wave.
	var specs := []
	for i in 8:
		# Sim.ARMS[id % 4] says what each Trolloc carries; with eight variants picked
		# by id % 8, variant i must carry kind i % 4 for the two to agree.
		specs.append(Species.roll(Species.TROLLOC, 20 + i, {lod = 1.7, head = ["boar", "wolf", "ram", "hawk", "bear"][i % 5], weapon_kind = i % 4}))
	var out := []; out.resize(specs.size())
	var id := WorkerThreadPool.add_group_task(func(i: int) -> void: out[i] = Creature.build(specs[i]), specs.size())
	WorkerThreadPool.wait_for_group_task_completion(id)
	variants = out
	# The Eyeless is one shape: they are all alike.
	fade = Creature.build(Species.roll(Species.MYRDDRAAL, 7, {lod = 1.2}))
	# The Session lives at /root/Session on every machine (RPCs go by node path).
	var old := get_tree().root.get_node_or_null("Session")
	if old:
		old.free()
	session = Session.new()
	get_tree().root.add_child(session)
	session.started.connect(_on_started)
	session.snapshot.connect(_on_snapshot)
	session.events.connect(_on_events)
	session.finished.connect(_on_finished)
	session.refused.connect(func(why: String) -> void: last_refusal = why.capitalize(); refusal_t = 1.5)
	session.rejected.connect(func(why: String) -> void:
		_done = true
		banner.text = "Could not join: %s\n\nEnter: back to camp" % why
		print("GAME rejected: ", why))
	if args.has("join"):
		banner.text = "Reaching %s…" % args.join
		session.join(args.join, profile, args.get("activity", ""), args.get("word", ""))
	else:
		session.host(args.get("activity", "tarwins_gap_watch"), profile)
	if not args.has("auto") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	if is_instance_valid(session):
		session.queue_free()

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
			_select(posmod(selected - 1, n_known))
		elif ev.keycode == KEY_E:
			_select(posmod(selected + 1, n_known))
		elif ev.keycode == KEY_SPACE and me:
			# Sidestep the way you are moving (back, if standing); with Shift, roll.
			session.dodge(_move_dir(), Input.is_key_pressed(KEY_SHIFT))
		elif ev.keycode in [KEY_CTRL, KEY_C]:
			session.duck(true)
		elif ev.keycode == KEY_G and selected < known.size() and Rules.weaves.has(known[selected]):
			session.tie(known[selected])
		elif ev.keycode == KEY_F and _armed() and me:
			session.attack("throw", _aim_point())
			_face(_aim_point())
		var n: int = ev.keycode - KEY_1
		if n >= 0 and n < known.size():
			_select(n)
	elif ev is InputEventKey and not ev.pressed and ev.keycode in [KEY_CTRL, KEY_C]:
		session.duck(false)
	elif ev is InputEventMouseButton:
		if not ev.pressed:
			# Letting go of the attack: a tap is a light blow, a hold a heavy one, and
			# with a bow the hold is the draw.
			if ev.button_index == MOUSE_BUTTON_LEFT and held_since >= 0.0 and _armed() and me:
				var held := clock - held_since
				var at := _aim_point()
				if Rules.weapons[hand()].has("shot"):
					session.attack("light", at, clampf(held / Rules.draw_time(profile, hand()), 0.0, 1.0))
				else:
					session.attack("heavy" if held > 0.35 else "light", at)
				_face(at)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				session.guard(false)
			if ev.button_index == MOUSE_BUTTON_LEFT:
				held_since = -1.0
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if _form() != "" and ready_at.get(_form(), 0.0) <= clock and me:
				# A form goes at once; while it rests, the same click is a plain blow.
				session.attack("form:" + _form(), _aim_point())
				_face(_aim_point())
			elif _armed():
				held_since = clock
			else:
				_cast_selected()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and _armed():
			session.guard(true)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(posmod(selected + 1, n_known))
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(posmod(selected - 1, n_known))

## What is in my hand, as the sim last said ("" if nothing).
func hand() -> String:
	var w: String = actors[session.my_id].get("weapon", "") if actors.has(session.my_id) else ""
	return w if Rules.weapons.has(w) else ""

## The form chosen on the bar, or "".
func _form() -> String:
	return known[selected] if selected < known.size() and Rules.forms.has(known[selected]) else ""

## Is the chosen thing on the bar fought with (a weapon or a form), not woven?
func _armed() -> bool:
	return selected < known.size() and hand() != "" and (Rules.weapons.has(known[selected]) or _form() != "")

## Choosing a weapon takes it in hand; choosing a weave empties the hands to weave;
## choosing a form takes up a weapon it can be done with, if the hand holds another.
func _select(i: int) -> void:
	if known.is_empty():
		return
	selected = i
	held_since = -1.0
	if profile.get("kit", []).is_empty():
		return
	if Rules.weapons.has(known[i]):
		session.equip(known[i])
	elif _form() != "":
		if hand() == "" or Rules.weapons[hand()].family != Rules.forms[_form()].family:
			for w in profile.kit:
				if Rules.weapons[w].family == Rules.forms[_form()].family:
					session.equip(w)
					break
	else:
		session.equip("")

func _move_dir() -> Vector3:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	v += Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	return Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)

## Turn to the target at once, so the blow or the weave goes the right way.
func _face(at: Vector3) -> void:
	face_yaw = atan2(at.x - me.position.x, at.z - me.position.z)
	aim_t = 1.2

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
	# Healing is aimed at a friend; everything else at the Shadow.
	var friendly: bool = not known.is_empty() and Rules.weaves[known[selected]].kind == "heal"
	for id in actors:
		var a: Dictionary = actors[id]
		if (a.kind == "player") != friendly or id == session.my_id or a.get("dead", false) or not is_instance_valid(a.node):
			continue
		var c: Vector3 = a.node.position + Vector3(0, 1.2, 0)
		var along := (c - from).dot(dir)
		if along < 2.0 or along > 90.0:
			continue
		var miss := (c - (from + dir * along)).length() - along * 0.012
		if miss < best_miss:
			best_miss = miss; best = c
	if best != Vector3.ZERO:
		return best
	for i in 240:
		var p := from + dir * (i * 0.4)
		if p.y <= Terrain.height(p.x, p.z):
			return p
	# Aiming at the sky is allowed: that is how a lofted weave is thrown far.
	return from + dir * 60.0

func _process(dt: float) -> void:
	frame += 1
	clock += dt
	refusal_t -= dt
	if session.my_id == 0:
		return
	if args.has("auto") and not session.is_host:
		_client_bot()
	elif args.has("auto"):
		# --stand: the bot holds its ground and weaves only now and then, so melee,
		# burning and knockdowns can be watched up close in a render.
		if not args.has("stand") or frame % 150 < 45:
			Bot.drive(session.sim, session.my_id)
		if args.has("stand"):
			session.sim.set_input(session.my_id, Vector3.ZERO, session.sim.ents[session.my_id].yaw)
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
		punch = maxf(punch - dt * 5.0, 0.0)
		cam.fov = 70.0 - 5.0 * punch
		cam.position = want + view * Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.12 * k
		cam.basis = view * Basis.from_euler(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02 * k)
	_draw_hud()

## `--auto --join=...`: a bot that knows only what a client is told, for trying a
## server without hands.
var _bot_t := 0.0
func _client_bot() -> void:
	if me == null or known.is_empty():
		return
	var best := 1e9; var target := Vector3.ZERO
	for id in actors:
		var a: Dictionary = actors[id]
		if a.kind == "enemy" and not a.get("dead", false) and me.position.distance_to(a.target) < best:
			best = me.position.distance_to(a.target); target = a.target
	if best > 1e8:
		return
	var to := (target - me.position) * Vector3(1, 0, 1)
	face_yaw = atan2(to.x, to.z)
	cam_yaw = lerp_angle(cam_yaw, face_yaw + PI, 0.05)
	var reach: float = Rules.weaves[known[0]].base.get("range", 10.0)
	session.send_input(-to.normalized() if best < 5.0 else (to.normalized() if best > reach * 0.7 else Vector3.ZERO), face_yaw)
	_bot_t -= get_process_delta_time()
	if _bot_t <= 0.0:
		_bot_t = 0.4
		session.cast(known[0], _ground(target) + Vector3(0, 1.1 + 0.00446 * best * best - 0.052 * best if known[0] == "fireball" else 1.1, 0))

## `-- --auto --fxdemo`: fire every instant weave effect in turn in front of the
## camera, so effects can be reviewed in a render without waiting for a real cast.
var _demo_t := 1.0
var _demo_i := 0
func _fx_demo(dt: float) -> void:
	_demo_t -= dt
	if _demo_t > 0.0 or me == null:
		return
	_demo_t = 1.0
	var list := ["lightning", "rolling_ring", "balefire", "hammer_of_air", "dome_of_air", "healing", "blossoms_of_fire"]
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
	var ground := Terrain.build_mesh(240.0, 0.75)
	add_child(ground)
	if Map.id == "tarwins_gap":
		# A low sun behind the defenders: it lights the floor of the pass and the
		# faces of whatever comes down it, instead of leaving both in cliff shadow.
		World.build(self, 14.0, -24.0)
		(ground.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("road", 7.0)
		Scenery.tarwins_gap(self)
	elif Map.id == "wagon_ring":
		World.build(self, 60.0, -30.0)
		Scenery.wagon_ring(self)
	else:
		World.build(self)
	Scenery.scatter(self)
	# --spawn=myrddraal:1,trolloc_archer:2 puts enemies a few paces off, to look at
	# them in a render.
	if args.has("spawn") and session.is_host:
		for part in args.spawn.split(","):
			var kv: PackedStringArray = part.split(":")
			if Rules.enemies.has(kv[0]):
				for i in (int(kv[1]) if kv.size() > 1 else 1):
					session.sim._add_enemy(kv[0], Vector3(randf_range(-3, 3), 0, -7.0 - i * 2.0))

# --- mirroring the sim ----------------------------------------------------------------

func _on_events(list: Array) -> void:
	for e in list:
		match e.e:
			"spawn":
				if not actors.has(e.id):
					_spawn_enemy(e.id, e.type, e.pos)
			"player":
				if not actors.has(e.id):
					# Everyone appears as they chose to look, on every machine.
					var rig := Hero.instantiate(Hero.kind_for(e), hash(e.name))
					add_child(rig)
					rig.position = _ground(e.pos)
					actors[e.id] = {node = rig, kind = "player", target = rig.position, busy = 0.0, name = e.name}
					Hero.arm(rig, e.get("weapon", ""))
					actors[e.id].weapon = e.get("weapon", "")
					if e.id == session.my_id:
						me = rig
						banner.text = ""
						if known.has(e.get("weapon", "")):
							selected = known.find(e.weapon)
						if not profile.get("kit", []).is_empty():
							_banner("Left click: attack (hold for a heavy blow, or to draw a bow)   Right click: guard\nSpace: sidestep   Shift+Space: roll   Ctrl: duck   F: throw   1-9: change what is in hand", 9.0)
			"die":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					# Flames, sparks and the rest do not outlast the one they clung to.
					a.dead = true
					_status(a, 0)
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
						# Hit-stop, for the one struck only: it flashes and hangs for a few
						# frames, heavier blows longer. The world keeps moving (co-op).
						if e.dmg >= 4.0:
							Weavefx.flash(self, a.node)
							a.hold = clampf(e.dmg * 0.004, 0.05, 0.14)
							if e.by == session.my_id:
								punch = minf(punch + e.dmg * 0.01, 1.0)
					elif a.kind == "player" and not a.get("dead", false):
						_play(a, "Hit_Chest", true)
			"form":
				if actors.has(e.id):
					_play(actors[e.id], "Spell_Simple_Enter", true)
					if is_instance_valid(actors[e.id].node):
						Weavefx.forming(self, actors[e.id].node, e.weave, e.time)
					Sfx.play(self, "hum", _ground(actors[e.id].target) + Vector3(0, 1.4, 0), -8.0)
			"attack":
				# A lunge at the victim: the gait has no attack clip, so borrow the hit spring.
				if actors.has(e.id) and actors.has(e.target) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					var w: Walker = actors[e.id].node
					w.hit((_ground(actors[e.target].target) - w.position).normalized(), 0.35)
					Sfx.play(self, "thud", w.position + Vector3(0, 1.2, 0), 0.0)
			"swing":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					(actors[e.id].node as Walker).attack(e.get("kind", "chop"))
			"hold":
				var key := "%d/%s/%d" % [e.id, e.weave, e.target]
				if not holds.has(key):
					holds[key] = {node = Weavefx.hold(self, e.weave), id = e.id, weave = e.weave, target = e.target, tied = false}
			"release":
				var key := "%d/%s/%d" % [e.id, e.weave, e.get("target", 0)]
				if holds.has(key):
					holds[key].node.queue_free(); holds.erase(key)
			"tie":
				var key := "%d/%s/%d" % [e.id, e.weave, e.target]
				if holds.has(key) and not holds[key].tied:
					holds[key].tied = true
					Weavefx.knot(holds[key].node, e.weave)
					Sfx.play(self, "chime", holds[key].node.get_node("Body").position + Vector3(0, 1.5, 0), -3.0, 1.4)
			"broke":
				if e.id == session.my_id:
					flash_t = 1.0; flash_text = "It broke free"
			"equip":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Hero.arm(actors[e.id].node, e.weapon)
					actors[e.id].weapon = e.weapon
					# The bar follows the hand (a bot, or the host, may have changed it),
					# unless a form is chosen: that keeps its place.
					if e.id == session.my_id and known.has(e.weapon) and _form() == "":
						selected = known.find(e.weapon)
			"blow":
				# The clip is played at whatever speed makes the blade arrive when the
				# sim lands the blow.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					var m: Dictionary = Rules.moves[e.move]
					var ap: AnimationPlayer = a.node.get_meta("anim")
					var clip: String = m.clip if ap.has_animation(m.clip) else "Sword_Attack"
					var len := ap.get_animation(clip).length
					ap.play(clip, 0.08, clampf(len * m.get("at", 0.4) / maxf(e.wind, 0.05), 0.35, 4.0))
					a.busy = e.wind + e.recover * 0.8
					a.erase("gesture")
					if e.get("form", false) and e.id == session.my_id:
						ready_at[e.move] = clock + float(Rules.forms[e.move].cooldown)
						flash_t = 0.9; flash_text = Rules.forms[e.move].name
					Sfx.play(self, "whoosh", a.node.position + Vector3(0, 1.3, 0), -5.0, 1.3)
			"strike":
				if e.hits > 0:
					Sfx.play(self, "thud", e.pos, 1.0, 1.25)
					if e.id == session.my_id:
						punch = minf(punch + 0.25, 1.0)
			"dodge":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					var ap: AnimationPlayer = a.node.get_meta("anim")
					ap.play("Roll", 0.05, ap.get_animation("Roll").length / maxf(e.time * (1.0 if e.roll else 1.6), 0.1))
					a.busy = e.time
					a.erase("gesture")
					a.node.rotation.y = atan2(e.dir.x, e.dir.z)
					Sfx.play(self, "whoosh", a.node.position + Vector3(0, 0.8, 0), -8.0, 0.8)
			"parry", "block", "guard_break":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var at: Vector3 = actors[e.id].node.position + Vector3(0, 1.3, 0) + Basis(Vector3.UP, actors[e.id].node.rotation.y) * Vector3(0, 0, 0.6)
					Weavefx.sparks(self, at, e.e == "parry")
					Sfx.play(self, "chime" if e.e == "parry" else "thud", at, 2.0 if e.e == "parry" else 0.0, 1.9 if e.e == "parry" else 1.5)
					if e.e == "parry":
						Sfx.play(self, "clang", at, 3.0)
					if e.id == session.my_id:
						flash_t = 1.0
						flash_text = {parry = "Parried", block = "", guard_break = "Your guard is broken"}[e.e]
						if e.e != "block":
							shake = minf(shake + 0.35, 1.0)
			"evade":
				if e.id == session.my_id:
					flash_t = 0.7; flash_text = "Ducked under it" if e.duck else "Missed you"
			"loose":
				if e.id == session.my_id:
					ammo[e.weapon] = e.left
				if actors.has(e.id):
					var bow: bool = not Rules.weapons.has(e.weapon) or Rules.weapons[e.weapon].has("shot")
					Sfx.play(self, "twang" if bow else "whoosh", _ground(actors[e.id].target) + Vector3(0, 1.4, 0), -1.0, 1.0 if bow else 2.2)
					# A Trolloc archer: the arm comes up as it looses.
					if actors[e.id].node is Walker:
						(actors[e.id].node as Walker).attack("thrust")
			"slip":
				# A Myrddraal is not where the blow went.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Sfx.play(self, "whoosh", actors[e.id].node.position + Vector3(0, 1.2, 0), -6.0, 1.8)
					if actors[e.id].node is Walker:
						(actors[e.id].node as Walker).hit(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 0.5)
			"fester":
				if e.id == session.my_id:
					flash_t = 1.0; flash_text = "The wound festers: only Healing will end it"
			"pickup":
				if e.id == session.my_id:
					ammo[e.weapon] = e.left
			"stick":
				Sfx.play(self, "thud", e.pos, -4.0, 2.0)
			"cast":
				if actors.has(e.id):
					# Each channeller has their own gesture for each weave.
					_play(actors[e.id], Hero.cast_clip(actors[e.id].get("name", ""), e.weave), true)
				if e.id == session.my_id:
					ready_at[e.weave] = clock + Rules.cooldown(profile, e.weave)
				Weavefx.cast(self, e)
			"blast":
				Weavefx.blast(self, e.pos, e.radius, e.weave)
			"fx_end":
				if fx.has(e.id):
					fx[e.id].queue_free(); fx.erase(e.id)
			"wave":
				_banner(("They come from every side" if Map.m.get("around", false) else "A wave comes down the pass") if e.left > 0 else "The last of them", 3.0)

func _play(a: Dictionary, clip: String, once := false) -> void:
	var ap: AnimationPlayer = a.node.get_meta("anim")
	if once:
		a.busy = ap.get_animation(clip).length * 0.9
		a.gesture = clip
		# Weaving on the move uses the same gesture over jogging legs.
		if a.get("speed", 0.0) > 0.6 and ap.has_animation(clip + "_Move"):
			clip += "_Move"
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
	elif row.gen == "FADE":
		var w := Creature.instantiate(fade)
		add_child(w)
		w.teleport(pos, 0.0)
		actors[id] = {node = w, kind = "enemy", target = pos, fade = true}
		_banner("An Eyeless is among them", 4.0)
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
			# Snapshots can outrun the event that introduces someone; wait for it.
			continue
		var a: Dictionary = actors[id]
		a.target = Vector3(e[1], 0, e[2]); a.yaw = e[3]
		_status(a, e[6])
		a.hp = e[4]
		if id == session.my_id:
			if e[4] < my_hp - 0.5:
				hurt_t = 1.0
			my_hp = e[4]; my_stamina = e[5]
	for f in s.fx:
		if not fx.has(f[0]):
			fx[f[0]] = Weavefx.live(self, f[1], f[6])
		var n: Node3D = fx[f[0]]
		var was := n.position
		n.position = _ground(Vector3(f[2], 0, f[3])) + Vector3(0, 1.2, 0)
		if f[1] in ["projectile", "missile"]:
			n.position.y = f[5]
		if f[1] == "missile" and n.has_meta("flown") and was.distance_to(n.position) > 0.05:
			# Point along the flight; knives and stones tumble instead.
			n.basis = Basis.looking_at(n.position - was, Vector3.UP if absf((n.position - was).normalized().y) < 0.98 else Vector3.RIGHT)
		n.set_meta("flown", true)
		if f[1] == "ring":
			n.scale = Vector3(f[4], 1.0, f[4]); n.position.y -= 0.9

## Show what the sim says has happened to someone: 1 burning, 2 down, 4 stunned,
## 8 thrown.
func _status(a: Dictionary, bits: int) -> void:
	a.status = bits
	if not is_instance_valid(a.node):
		return
	for pair in [["burn", 1], ["stun", 4], ["fester", 256]]:
		var key: String = "fx_" + pair[0]
		var on: bool = bits & pair[1] and not a.get("dead", false)
		if on and not a.has(key):
			a[key] = Weavefx.status(pair[0]); a.node.add_child(a[key])
		elif not on and a.has(key):
			if is_instance_valid(a[key]):
				a[key].queue_free()
			a.erase(key)

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
				var st: int = a.get("status", 0)
				w.downed = st & 2
				if st & 10:
					# Thrown or flat on the ground: it is carried, it does not walk there,
					# so it keeps facing the way it was and slides.
					w.vel = Vector3.ZERO
					w.pos += to * minf(10.0 * dt, 1.0)
				else:
					w.vel = (to * 3.0).limit_length(5.5) if to.length() > 0.25 else Vector3.ZERO
			walkers.append(w)
		elif a.kind == "player":
			var n: Node3D = a.node
			var tgt := _ground(a.target)
			var speed := n.position.distance_to(tgt) / maxf(dt, 0.001)
			n.position = n.position.lerp(tgt, minf(12.0 * dt, 1.0))
			n.rotation.y = lerp_angle(n.rotation.y, a.yaw, minf(10.0 * dt, 1.0))
			a.busy = a.get("busy", 0.0) - dt
			a.speed = speed
			if a.busy > 0.0 and a.has("gesture"):
				# Starting or stopping mid-weave swaps the legs without restarting the arms.
				var ap: AnimationPlayer = n.get_meta("anim")
				var want: String = a.gesture + ("_Move" if speed > 0.6 and ap.has_animation(a.gesture + "_Move") else "")
				if ap.current_animation != want and ap.current_animation.begins_with(a.gesture):
					var at := ap.current_animation_position
					ap.play(want, 0.15); ap.seek(minf(at, ap.get_animation(want).length), true)
			if a.busy <= 0.0:
				var st: int = a.get("status", 0)
				var fam: String = Rules.weapons[a.weapon].family if Rules.weapons.has(a.get("weapon", "")) else ""
				if st & 32:
					_play(a, "Crouch_Fwd" if speed > 0.4 else "Crouch_Idle")
				elif st & 16:
					_play(a, "Idle_Shield" if Rules.weapons[a.weapon].has("shield") else "Sword_Block")
				elif speed > 0.6:
					_play(a, "Sprint" if speed > 6.5 else "Jog_Fwd")
				else:
					_play(a, "Sword_Idle" if fam in ["sword", "axe", "knife"] else "Idle")
	for id in actors:
		# Struck (for an instant) or wrapped in Air (for as long as it is held): it
		# does not move.
		if actors[id].get("hold", 0.0) > 0.0 or actors[id].get("status", 0) & 128:
			actors[id].hold = actors[id].get("hold", 0.0) - dt
			if is_instance_valid(actors[id].node) and actors[id].node is Walker:
				walkers.erase(actors[id].node)
	_draw_holds(dt)
	for w in walkers:
		w.compute(dt)
		w.apply()

## Held weaves sit on whoever they hold and trail a thread back to the weaver.
func _draw_holds(dt: float) -> void:
	for key in holds:
		var h: Dictionary = holds[key]
		var on: int = h.target if h.target != 0 else h.id
		if not actors.has(on) or not actors.has(h.id) or not is_instance_valid(actors[on].node) or not is_instance_valid(actors[h.id].node):
			h.node.visible = false
			continue
		var body: Node3D = h.node.get_node("Body")
		body.position = actors[on].node.position
		body.rotate_y(dt * 0.8)
		var th: MeshInstance3D = h.node.get_node_or_null("Tether")
		if th and th.visible:
			var a: Vector3 = actors[h.id].node.position + Vector3(0, 1.35, 0)
			var b: Vector3 = body.position + Vector3(0, 1.2, 0)
			var d := b - a
			if d.length() > 0.2:
				var y := d.normalized()
				var x := (Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).cross(y).normalized()
				th.transform = Transform3D(Basis(x, y * d.length(), x.cross(y)), (a + b) * 0.5)

## The flows I am holding weaves with, one colour per flow in use.
func used_flows() -> Array:
	var out := []
	for key in holds:
		var h: Dictionary = holds[key]
		if h.id == session.my_id and not h.tied:
			for e in Glyph.threads(Rules.flows_of(Rules.weaves[h.weave], profile)):
				out.append(Glyph.TINT[e])
	return out

## 0 not held, 1 held, 2 tied off.
func holding(weave: String) -> int:
	var best := 0
	for key in holds:
		var h: Dictionary = holds[key]
		if h.id == session.my_id and h.weave == weave:
			best = maxi(best, 2 if h.tied else 1)
	return best

func _draw_fx(_dt: float) -> void:
	pass

# --- HUD ------------------------------------------------------------------------------

func _hud() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	hud = Hud.new(); hud.g = self; layer.add_child(hud)
	banner = Label.new(); layer.add_child(banner)
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 110; banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_override("font", Glyph.serif())
	banner.add_theme_font_size_override("font_size", 32)
	banner.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	banner.add_theme_color_override("font_outline_color", Color.BLACK); banner.add_theme_constant_override("outline_size", 8)

var _banner_t := 0.0
func _banner(text: String, secs: float) -> void:
	banner.text = text; _banner_t = secs

func _draw_hud() -> void:
	var dt := get_process_delta_time()
	hurt_t = maxf(hurt_t - dt * 2.5, 0.0)
	flash_t = maxf(flash_t - dt * 1.4, 0.0)
	_banner_t -= dt
	if _banner_t <= 0.0 and not _done:
		banner.text = ""

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
