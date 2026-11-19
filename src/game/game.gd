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
var cam_off := Vector3(0.6, 0.15, 0.0)   # the shoulder offset (cam_dist is added to z)
var fov_base := 70.0
var _guard_pull := 0.0
var cam_swing := 0.0          # arriving: the camera starts out in front of you, looking back at the gateway
var face_yaw := 0.0            # my character faces its travel direction, or the aim while weaving
var aim_t := 0.0               # seconds left facing the aim after a cast
var selected := 0
var shake := 0.0               # camera trauma, 0..1, decays every frame
var my_trance := false         # a Draghkar has me
var punch := 0.0               # a landed blow pushes the view in for an instant
var me: Node3D                 # my HumanRig
var actors := {}               # sim id -> {node, kind, target: Vector3, yaw}
var fx := {}                   # sim fx id -> Node3D
var variants: Array = []       # generated Trolloc data, shared between enemies
var archers: Array = []        # the same, carrying bows
var fade := {}                 # generated Myrddraal data
var made := {}                 # other generated creatures, by gen name, built when first met
var told := {}                 # warnings given once
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
var my_will := 100.0
var dreaming := false        # this fight is in Tel'aran'rhiod: dream moves are on their keys
var dream_keys := {}        # physical key -> dream move
var _hinted := false       # the controls line has been shown
var _foe := 0               # a bot opponent in a duel
var _foe_profile := {}      # who it will be, if nobody real turns up
var frame := 0
var ammo := {}                    # weapon -> arrows, knives or spears left
var held_since := -1.0            # clock time the attack button went down, or -1
var flash_t := 0.0                # a parry just rang: the HUD flashes
var flash_text := ""
var _ghost_st := 0
var holds := {}                   # "caster/weave/target" -> {node, id, weave, target, tied}

func _ready() -> void:
	args = Launch.args if not Launch.args.is_empty() else Launch.cmdline()
	Launch.use_profile_dir()
	_t0 = Time.get_ticks_msec()
	previewing = args.has("preview")
	controlled = not previewing
	_stamp("scene ready begins")
	Rules.load_data()
	Terrain.amp = 0.45
	cam = Camera3D.new(); cam.fov = 70.0; add_child(cam)
	_stamp("before hud")
	_hud()
	_stamp("hud made")
	pause_menu = preload("res://src/game/pauser.gd").new(); pause_menu.g = self; add_child(pause_menu)
	Settings.load_and_apply()
	var name_: String = args.get("name", "Novice")
	profile = {} if args.has("tour") else Profile.load_profile(name_)
	if profile.is_empty():
		# --aff=water makes a throwaway character strong in that Power, to try its weaves.
		profile = Profile.create({name = name_, potential_pts = 8, affinity_pts = {args.aff: 6} if args.has("aff") else {fire = 4, earth = 2}})
	# How far this player has read (Settings): a real player's own choice; a test
	# or a render keeps the character's (all books for throwaways).
	if not Launch.dev():
		profile.book_limit = Settings.book_limit()
	# --cloak=<id> (Hero.CLOAKS): put a cloak on for this run, for pictures.
	if args.has("cloak"):
		profile.style = profile.get("style", {}).duplicate()
		profile.style.cloak = args.cloak; profile.style.cloak_len = 0
	# --weaves=a,b adds weaves to a throwaway channeller and --tie teaches tying off.
	if args.has("weaves"):
		for w in args.weaves.split(","):
			if Rules.weaves.has(w):
				profile.weaves[w] = {known = true, xp = 0.0}
	# --only=a,b: a throwaway channeller who knows these weaves and no others, so a
	# bot can be made to show one weave in a render.
	if args.has("only"):
		profile.weaves = {}
		profile.hotbar = []     # the order given here, not one saved earlier
		for w in args.only.split(","):
			if Rules.weaves.has(w):
				profile.weaves[w] = {known = true, xp = 0.0}
	# --strength=N: a throwaway channeller of that Companion level (1 is the
	# strongest woman), fully grown into it, who has read every book: nothing is
	# out of reach for lack of strength or by the spoiler setting.
	if args.has("strength"):
		profile.potential = Rules.strength_of(float(args.strength))
		profile.strength = profile.potential
		profile.no_roll = true
		profile.book_limit = 99
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
	known = profile.weaves.keys().filter(func(w: String) -> bool: return not Rules.weaves.has(w) or Rules.weaves[w].book <= int(profile.get("book_limit", 14)) or profile.get("starter", "") == w) + profile.get("kit", []) + profile.get("forms", {}).keys().filter(func(f: String) -> bool: return Rules.forms.has(f))
	# The order the player chose in the camp's loadout, if any.
	var order: Array = profile.get("hotbar", [])
	if not order.is_empty():
		# Stable: what the order does not name keeps its own place after what it does.
		var first := known.duplicate()
		known.sort_custom(func(x: String, y: String) -> bool:
			var a := (order.find(x) if order.has(x) else 99) * 1000 + first.find(x)
			var b := (order.find(y) if order.has(y) else 99) * 1000 + first.find(y)
			return a < b)
	for w in profile.get("kit", []):
		var row: Dictionary = Rules.weapons[w]
		ammo[w] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	# The cast is made in the background from the camp (Cast). Straight in from the
	# command line it was never started: make it now. Through a doorway, wait for
	# it without stopping the frame, so the doorway's light keeps moving.
	# Never leave anyone staring into a doorway's light if the fight fails to appear.
	get_tree().create_timer(15.0).timeout.connect(func() -> void: Veil.lift(0.5))
	if Cast.ready_now() or not (Veil.up() or previewing):
		_begin()
	else:
		_awaiting_cast = true

var _awaiting_cast := false

## Everything that needs the cast: the session, and through it the world.
func _begin() -> void:
	Cast.wait()
	_stamp("cast in hand")
	variants = Cast.trollocs
	archers = Cast.archers
	fade = Cast.by_gen.FADE
	made = Cast.by_gen
	# The Session lives at /root/Session on every machine (RPCs go by node path).
	var old := get_tree().root.get_node_or_null("Session")
	if old:
		old.free()
	_stamp("before session")
	session = Session.new()
	get_tree().root.add_child(session)
	session.started.connect(_on_started)
	session.snapshot.connect(_on_snapshot)
	session.events.connect(_on_events)
	session.finished.connect(_on_finished)
	session.refused.connect(func(why: String) -> void:
		last_refusal = why.capitalize(); refusal_t = 1.5
		if args.has("ghost"): print("GHOST %d refused %s" % [frame, why]))
	session.rejected.connect(_offline)
	session.lost.connect(_on_lost)
	# --activity=holdout (a mode's doorway): pick its setup here, as the camp does.
	if args.has("activity") and Rules.activities.get(args.activity, {}).has("pool"):
		args.activity = Rules.pick_setup(args.activity)
	if args.has("join"):
		session.join(args.join, profile, args.get("activity", ""), args.get("word", ""), args.get("room", ""), previewing)
		# ENet can take half a minute to give up on a server that is not there.
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if not _started and not _done:
				_offline("no answer from the server"))
	else:
		session.host(args.get("activity", "tarwins_gap_watch"), profile, Session.PORT, previewing, false)
	if not args.has("auto") and not previewing and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The server went away mid-fight. It keeps our place for a while (Session
## AWAY_SECS), so keep knocking: the same join, every few seconds. If it never
## answers, say so and let Enter take us home instead of leaving a frozen field.
var _rejoin_until := 0.0
func _on_lost() -> void:
	if not _started or _done:
		return
	if not args.has("join"):
		_done = true
		Toast.say("Lost the server", "The fight cannot go on without it. Enter: back to the camp.", "warn", 15.0)
		return
	if _rejoin_until <= 0.0:
		_rejoin_until = clock + Session.AWAY_SECS - 5.0
		Toast.say("Lost the server", "Trying to get back in: your place is kept for a minute and a half.", "warn", 8.0)
	if clock > _rejoin_until:
		_done = true; _rejoin_until = 0.0
		Toast.say("Could not get back in", "The fight went on without you. Enter: back to the camp.", "warn", 15.0)
		return
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if _done or not is_instance_valid(session):
			return
		session.rejoin_failed = _on_lost
		session.join(args.join, profile, "_rejoin", args.get("word", ""), args.get("room", ""), false))

var weaving := false              # the mouse is held on a weave being made
var my_form := {}                 # {weave, since, time, ready}: my weave in the making, for the HUD
var spanned := {}                 # crossbow -> clock time it will be spanned again

func _exit_tree() -> void:
	# Carried out of a camp doorway's world into the main one: not an ending.
	if moving_worlds:
		return
	get_tree().paused = false
	if is_instance_valid(session):
		session.queue_free()

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height(p.x, p.z), p.z)

# --- input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if session == null:
		return
	var n_known := maxi(known.size(), 1)
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= ev.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.003, -1.2, 0.7)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if args.has("ghost"):
			print("GHOST %d key %s selected=%s" % [frame, OS.get_keycode_string(ev.physical_keycode), known[selected] if selected < known.size() else "-"])
		if ev.physical_keycode == KEY_ESCAPE:
			pass    # the pause menu (pauser.gd) has it
		elif (ev.physical_keycode == KEY_ENTER and _done) or ev.physical_keycode == KEY_F10:
			_to_camp()
		elif args.has("tour") and ev.physical_keycode in [KEY_N, KEY_B, KEY_R]:
			_tour_go(1 if ev.physical_keycode == KEY_N else (-1 if ev.physical_keycode == KEY_B else 0))
		elif ev.physical_keycode == Keys.k(KEY_L):
			session.link()
		elif ev.physical_keycode == Keys.k(KEY_K):
			session.tie_rope(true)
		elif ev.physical_keycode == Keys.k(KEY_J) and darkfriend:
			session.df_gate()
		elif ev.physical_keycode == Keys.k(KEY_TAB):
			if profile.get("cls", "channeller") == "channeller":
				_show_tree(tree_view == null or not tree_view.visible)
			elif not team_meter.is_empty():
				_show_picks(pick_card == null or not pick_card.visible)
		elif dreaming and dream_keys.has(ev.physical_keycode) and me:
			session.dream(dream_keys[ev.physical_keycode], _aim_point())
		elif ev.physical_keycode == Keys.k(KEY_V) and not dreaming and me:
			session.jump()   # a low sweep (the yellow wedge) passes under
		elif ev.physical_keycode == Keys.k(KEY_Q):
			_select(posmod(selected - 1, n_known))
		elif ev.physical_keycode == Keys.k(KEY_E):
			_select(posmod(selected + 1, n_known))
		elif ev.physical_keycode == Keys.k(KEY_SPACE) and me:
			# Roll the way you are moving; standing still, step back.
			session.dodge(_move_dir(), false)
		elif ev.physical_keycode in [Keys.k(KEY_CTRL), KEY_C]:
			session.duck(true)
		elif ev.physical_keycode == Keys.k(KEY_G) and selected < known.size() and Rules.weaves.has(known[selected]):
			session.tie(known[selected])
		elif ev.physical_keycode == Keys.k(KEY_F) and _armed() and me:
			session.attack("throw", _aim_point())
			_face(_aim_point())
		var n: int = Keys.slot_of(ev.physical_keycode)
		if n >= 0 and n < known.size():
			_select(n)
	elif ev is InputEventKey and not ev.pressed and ev.physical_keycode == Keys.k(KEY_K):
		session.tie_rope(false)
	elif ev is InputEventKey and not ev.pressed and ev.physical_keycode in [Keys.k(KEY_CTRL), KEY_C]:
		session.duck(false)
	elif ev is InputEventMouseButton:
		if not ev.pressed:
			# Letting go of the attack: a tap is a light blow, a hold a heavy one, and
			# with a bow the hold is the draw.
			if ev.button_index == MOUSE_BUTTON_LEFT and held_since >= 0.0 and _armed() and me:
				var held := clock - held_since
				var at := _aim_point()
				if Rules.weapons[hand()].has("shot"):
					if not Rules.weapons[hand()].shot.get("crank", false):
						session.attack("light", at, clampf(held / Rules.draw_time(profile, hand()), 0.0, 1.0))
				else:
					session.attack("heavy" if held > 0.35 else "light", at)
				_face(at)
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if held_since >= 0.0 and hand() != "" and Rules.weapons[hand()].has("shot"):
					session.draw(false)
				held_since = -1.0
				if weaving and me:
					# Let it go: it leaves as soon as it is whole, where the crosshair is then.
					weaving = false
					session.aim(_aim_point(), false)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if _form() != "" and ready_at.get(_form(), 0.0) <= clock and me:
				# A form goes at once; while it rests, the same click is a plain blow.
				session.attack("form:" + _form(), _aim_point())
				_face(_aim_point())
			elif _armed() and Rules.weapons[hand()].get("shot", {}).get("crank", false) and me:
				# A crossbow is spanned or it is not: the click looses it.
				session.attack("light", _aim_point(), 1.0)
				_face(_aim_point())
			elif _armed():
				held_since = clock
				if Rules.weapons[hand()].has("shot"):
					session.draw(true)
			else:
				_cast_selected()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and (weaving or not my_form.is_empty()) and me:
			# Right click while weaving: let it go, unloosed.
			weaving = false
			session.cancel_weave()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and hand() != "" and me:
			# A parry is the press, not the hold.
			if Rules.guard_share(profile, hand()) <= 0.0:
				last_refusal = "Nothing to parry with: roll instead"; refusal_t = 1.5
			else:
				_face(_aim_point())
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
	v += Vector2(float(Keys.down(KEY_D)) - float(Keys.down(KEY_A)), float(Keys.down(KEY_S)) - float(Keys.down(KEY_W)))
	return Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)

## Turn to the target at once, so the blow or the weave goes the right way.
func _face(at: Vector3) -> void:
	face_yaw = atan2(at.x - me.position.x, at.z - me.position.z)
	aim_t = 1.2

func _cast_selected() -> void:
	if known.is_empty() or me == null:
		return
	var at := _aim_point()
	# The weave is begun now and held back for as long as the button is: it goes
	# where the crosshair is when it is let go, not where it was when it was begun.
	session.cast(known[selected], at, true)
	weaving = true
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
	var friendly: bool = not known.is_empty() and Rules.weaves.has(known[selected]) and Rules.weaves[known[selected]].kind == "heal"
	# Shielding and Bonds may be fastened on anyone, players too.
	var any_body: bool = not known.is_empty() and Rules.weaves.has(known[selected]) and Rules.weaves[known[selected]].kind in ["sever", "bind"]
	for id in actors:
		var a: Dictionary = actors[id]
		if ((a.kind == "player") != friendly and not any_body) or id == session.my_id or a.get("dead", false) or not is_instance_valid(a.node):
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

## The ground a weave will touch, drawn at the aim while it is being made: a disc
## for what bursts, a strip for a line or lash, a wedge for a cone or a ring. Only
## for my own weave, and not in pictures taken with --clean.
var _area: MeshInstance3D
var _area_key := ""
func _area_preview() -> void:
	var w: Dictionary = Rules.weaves.get(my_form.get("weave", ""), {}) if not my_form.is_empty() and me else {}
	if w.is_empty() or args.has("clean"):
		if _area: _area.visible = false
		return
	var b: Dictionary = w.base
	var at := _aim_point()
	var to := Vector2(at.x - me.position.x, at.z - me.position.z)
	var yaw := atan2(to.x, to.y)
	var mesh: Mesh = null
	var origin := _ground(at)
	var key := "%s" % w.get("name", "")
	match w.kind:
		"projectile", "strike", "blossom":
			if not (b.has("radius") and float(b.radius) > 0.6):
				if _area: _area.visible = false
				return
			mesh = Armsfx._band(-PI, PI, 0.0, float(b.radius), false, 32)
		"line", "lash":
			var span := minf(to.length(), float(b.range))
			var pm := PlaneMesh.new(); pm.size = Vector2(float(b.width), span)
			pm.center_offset = Vector3(0, 0, span * 0.5)
			mesh = pm; origin = _ground(me.position); key += "%d" % int(span)
		"cone":
			mesh = Armsfx._band(-deg_to_rad(float(b.arc)), deg_to_rad(float(b.arc)), 0.5, float(b.range), false, 24)
			origin = _ground(me.position)
		"ring":
			mesh = Armsfx._band(-deg_to_rad(float(b.arc)), deg_to_rad(float(b.arc)), 0.5, float(b.radius), false, 24)
			origin = _ground(me.position)
		_:
			if _area: _area.visible = false
			return
	if _area == null:
		_area = MeshInstance3D.new()
		var sm := ShaderMaterial.new(); sm.shader = Armsfx.WARN
		sm.set_shader_parameter("tint", Color(0.45, 0.75, 1.0)); sm.set_shader_parameter("fill", 1.0)
		_area.material_override = sm
		_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_area)
	if key != _area_key or w.kind == "line" or w.kind == "lash":
		_area.mesh = mesh; _area_key = key
	_area.visible = true
	_area.transform = Transform3D(Basis(Vector3.UP, yaw), origin + Vector3(0, 0.12, 0))

func _process(dt: float) -> void:
	_area_preview()
	if controlled:
		Wind.step(dt)
		Debris.step(dt)
	# --clean: nothing over the picture (tools/poses.sh).
	if args.has("clean"):
		if hud_layer: hud_layer.visible = false
		var toasts := get_tree().root.get_node_or_null("Toasts") as CanvasLayer
		if toasts: toasts.visible = false
	if _awaiting_cast:
		if Cast.ready_now():
			_awaiting_cast = false
			_begin()
		return
	if session == null:
		return
	if frame < 4 or (frame < 400 and dt > 0.1):
		_stamp("frame %d drawn (dt %.2f s)" % [frame, dt])
	frame += 1
	if args.has("ghost"):
		Ghost.step(args.ghost, frame)
	clock += dt
	refusal_t -= dt
	if session.my_id == 0:
		return
	if _ally != 0 and session.sim.ents.has(_ally):
		Bot.dream(session.sim, _ally)
		Bot.drive(session.sim, _ally)
	if _foe == 0 and not _foe_profile.is_empty() and session.is_host and session.sim.t > (0.5 if args.has("foe") else 4.0):
		# Nobody else came: the dream supplies someone.
		if session.sim.tallies.size() <= 1:
			var mine: Dictionary = session.sim.ents[session.my_id]
			_foe = session.sim.add_player(_foe_profile, mine.pos + Vector3(sin(mine.yaw), 0, cos(mine.yaw)) * 14.0)
			session.sim.ents[_foe].yaw = mine.yaw + PI
		_foe_profile = {}
	if _foe != 0 and session.sim.ents.has(_foe):
		Bot.dream(session.sim, _foe)
		Bot.drive(session.sim, _foe)
	# --at=x,z: put the bot there once (pictures of one place).
	if args.has("at") and frame == 3 and session.is_host:
		var xz: PackedStringArray = String(args.at).split(",")
		session.sim.ents[session.my_id].pos = Vector3(float(xz[0]), 0, float(xz[1]))
	if args.has("auto") and not session.is_host:
		_client_bot()
	elif args.has("auto"):
		# --stand: the bot holds its ground and weaves only now and then, so melee,
		# burning and knockdowns can be watched up close in a render.
		if not args.has("stand") or frame % 150 < 45:
			Bot.dream(session.sim, session.my_id)
			Bot.drive(session.sim, session.my_id)
		if args.has("stand"):
			session.sim.set_input(session.my_id, Vector3.ZERO, session.sim.ents[session.my_id].yaw)
		# --walkgate: once a gateway is open, walk straight through it (for a render).
		if args.has("walkgate") and session.is_host:
			for g in session.sim.effects:
				if g.kind == "gate" and g.age > 0.8:
					var mep: Dictionary = session.sim.ents[session.my_id]
					var n: Vector3 = session.sim._gate_normal(g)
					session.sim.set_input(session.my_id, n, atan2(n.x, n.z))
					cam_yaw = lerp_angle(cam_yaw, atan2(n.x, n.z) + PI, 0.2)
		# --camyaw=deg swings the bot's camera round it, to look at it from the side.
		cam_yaw = lerp_angle(cam_yaw, session.sim.ents[session.my_id].yaw + PI + deg_to_rad(float(args.get("camyaw", "0"))), 2.0 * dt)
		if args.has("camdist"):
			cam_dist = float(args.camdist)
		if args.has("campitch"):
			cam_pitch = deg_to_rad(float(args.campitch))
	else:
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		v += Vector2(float(Keys.down(KEY_D)) - float(Keys.down(KEY_A)), float(Keys.down(KEY_S)) - float(Keys.down(KEY_W)))
		# walk_in (a render walking through a camp doorway): keep walking for a
		# moment after crossing, as a held key would.
		if args.has("walk_in") and controlled and _walk_t < 2.0:
			_walk_t += dt; v = Vector2(0, -1)
		var move := Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)
		aim_t -= dt
		if aim_t <= 0.0 and move.length() > 0.1:
			face_yaw = atan2(move.x, move.z)
		if held_since >= 0.0 and me and _armed() and Rules.weapons[hand()].has("shot"):
			# Drawing a bow: turn to where the arrow will go, the bow along the aim.
			var bat := _aim_point()
			face_yaw = atan2(bat.x - me.position.x, bat.z - me.position.z)
			aim_t = 0.3
		if not my_form.is_empty() and me:
			# Face where the weave will go, and keep the host told (a few times a second).
			var at := _aim_point()
			face_yaw = atan2(at.x - me.position.x, at.z - me.position.z)
			aim_t = 0.3
			if frame % 4 == 0:
				session.aim(at, weaving)
		if not controlled:
			move = Vector3.ZERO
		session.send_input(move, face_yaw)
		_predict(move, dt)
	if args.has("fxdemo"):
		_fx_demo(dt)
	# --gate: open a gateway ahead early on, whatever the character's strength, so
	# it can be looked at in a render.
	if args.has("gate") and frame == 150 and session.is_host and me:
		var p: Dictionary = session.sim.ents[session.my_id]
		session.sim._cast(p, "gateway", p.pos + Vector3(sin(p.yaw), 0, cos(p.yaw)) * 14.0 + Vector3(6, 0, 0))
	# --demo=weave[:metres]: weave it ahead again and again, whoever the character is,
	# so one weave can be looked at in a render.
	# Several places, --demo=weave:12@-30,22@25 (metres@degrees off ahead), are woven
	# in turn every four seconds, so their effects overlap.
	var dspots: PackedStringArray = (args.demo.split(":")[1] if args.has("demo") and args.demo.contains(":") else "13").split(",")
	var dgap := 240 if dspots.size() == 1 else 120
	if args.has("demo") and frame % dgap == 100 % dgap and session.is_host and me:
		var dp: Dictionary = session.sim.ents[session.my_id]
		var dweave: String = args.demo.split(":")[0]
		var spot: PackedStringArray = dspots[(frame / dgap) % dspots.size()].split("@")
		var dyaw: float = dp.yaw + deg_to_rad(float(spot[1]) if spot.size() > 1 else 0.0)
		if Rules.weaves.has(dweave):
			session.sim._cast(dp, dweave, dp.pos + Vector3(sin(dyaw), 0, cos(dyaw)) * float(spot[0]) + Vector3(0, 1.0, 0))
	# --dreamdemo: the player works through the dream moves one after another at
	# whoever is nearest, so each can be looked at in a render.
	if args.has("dreamdemo") and frame % 75 == 40 and session.is_host and me and session.sim.dream:
		var dp: Dictionary = session.sim.ents[session.my_id]
		var order := ["dream_spear", "dream_wall", "dream_chains", "dream_pit", "shift_aim", "shift_behind", "shift_back", "deny"]
		if args.dreamdemo != "":
			order = Array(args.dreamdemo.split(","))
		var at: Vector3 = dp.pos + Vector3(sin(dp.yaw), 0, cos(dp.yaw)) * 8.0
		for o in session.sim._targets(dp):
			at = o.pos
		dp.will = 100.0; dp.shaken = 0.0
		session.sim.request_dream(session.my_id, order[(frame / 75) % order.size()], at + Vector3(0, 1.2, 0))
	_draw_actors(dt)
	if not stand_in.is_empty() and me:
		# Before the hand-over, the body over here stands exactly where the camp's
		# is, mapped through the doorway, in the same step of the same stride.
		me.global_transform = stand_in.xf
		var ap: AnimationPlayer = me.get_meta("anim") if me.has_meta("anim") else null
		if ap and ap.has_animation(stand_in.clip):
			if ap.current_animation != stand_in.clip:
				ap.play(stand_in.clip)
			ap.seek(stand_in.at, true)
	_draw_fx(dt)
	if me and not previewing:
		# Orbit camera: the view direction itself pitches, so looking up shows the sky and
		# looking down the ground at your feet. The shoulder offset keeps the character
		# off the crosshair.
		var pivot := me.position - cam_shift + Vector3(0, 1.55, 0)
		var view := Basis(Vector3.UP, cam_yaw + cam_swing) * Basis(Vector3.RIGHT, cam_pitch)
		# Guarding, the camera draws in a little: the fight narrows to the blade.
		var guarding: bool = actors.has(session.my_id) and int(actors[session.my_id].get("status", 0)) & 16 != 0
		_guard_pull = lerpf(_guard_pull, 0.8 if guarding else 0.0, minf(6.0 * dt, 1.0))
		var want := pivot + view * (cam_off + Vector3(0, 0, cam_dist - _guard_pull + cam_swing * 0.6))
		if cam_shift != Vector3.ZERO and not cam_gate.is_empty():
			# The camera reaching the gateway's plane: now it goes through as well.
			if signf((want - (cam_gate.origin as Vector3)).dot(cam_gate.n)) != float(cam_gate.s):
				want += cam_shift
				cam_shift = Vector3.ZERO; cam_gate = {}
		want.y = maxf(want.y, Terrain.height(want.x, want.z) + 0.35)
		# Trauma-squared shake: small hits barely register, big ones kick.
		shake = maxf(shake - dt * 1.8, 0.0)
		var k := shake * shake
		punch = maxf(punch - dt * 5.0, 0.0)
		cam.fov = fov_base - 5.0 * punch
		if smooth_cam > 0.0:
			# Just through a camp doorway: keep the camp camera's easing (it trails a
			# running body a little) and let it go, so there is no jump.
			smooth_cam -= dt
			want = cam.position.lerp(want, minf((14.0 if smooth_cam > 0.5 else 30.0) * dt, 1.0))
		cam.position = want + view * Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.12 * k
		cam.basis = view * Basis.from_euler(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02 * k)
	_draw_hud()
	_update_windows()
	_step_home(dt)

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

## --tour: on to the next station (or back, or the same again); past the last, to camp.
func _tour_go(step: int) -> void:
	Launch.tour += step
	if Launch.tour < 0 or Launch.tour >= Launch.TOUR.size():
		Launch.tour = 0
		_to_camp()
		return
	multiplayer.multiplayer_peer = null
	Launch.args = Launch.station()
	get_tree().change_scene_to_file("res://src/game/game.tscn")

## Leaving mid-activity (F10) abandons it: nothing is awarded, nothing is lost.
func _to_camp() -> void:
	if _leaving:
		return
	_leaving = true
	multiplayer.multiplayer_peer = null
	Launch.args = {}
	# Back the way you came: a gateway's light closes over the fight, and the camp
	# is made behind it (the camp lifts it).
	Veil.cover(Color(1.0, 0.85, 0.6), 0.5, func() -> void: get_tree().change_scene_to_file("res://src/game/camp.tscn"))

var _leaving := false

## Blasts shake the camera by size and nearness.
func shake_at(at: Vector3, radius: float) -> void:
	if me:
		shake = minf(1.0, shake + clampf(radius * 2.2 / maxf(at.distance_to(me.position), 3.0), 0.0, 0.8))

## The ground can only be built once we know which activity (and so which map) this
## is: a joining client learns that from the host.
func _on_started(_my_id: int, activity: String) -> void:
	if _started:
		# Taken back in after a dropped connection: the world is already built.
		_rejoin_until = 0.0
		session.rejoin_failed = Callable()
		Toast.say("Back in the fight", "", "good", 4.0)
		return
	_started = true
	in_battle = Rules.activities[activity].has("battle")
	_stamp("session started")
	if Launch.cmdline().get("ghost", "") in ["flow", "online"]:
		print("GHOST flow entered %s as %s (%s)" % [activity, profile.name, "joined a host" if not session.is_host else "hosting"])
	Map.use(Rules.activities[activity].get("map", "open"), activity)
	if not previewing:
		Wind.setup(Map.id, self)
		RenderingServer.global_shader_parameter_set("near_fade", 1.5)
		Scorch.setup(100.0)
		Debris.setup(self, hash(Map.id))
	# Behind a camp doorway the world is built a little each frame, so walking up to
	# it never stalls the camp.
	var spread: SceneTree = get_tree() if previewing else null
	var ground: MeshInstance3D = await Terrain.build_mesh(240.0, 0.75, spread)
	add_child(ground)
	if Map.id == "tarwins_gap":
		# A low sun behind the defenders: it lights the floor of the pass and the
		# faces of whatever comes down it, instead of leaving both in cliff shadow.
		var night: bool = Rules.activities[activity].get("night", false)
		World.build(self, 14.0, -24.0, night)
		(ground.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("road", 7.0)
		Scenery.tarwins_gap(self, night)
	elif Map.id == "wagon_ring":
		World.build(self, 60.0, -30.0)
		Scenery.wagon_ring(self)
	else:
		World.build(self)
		if activity == "camp_training":
			Scenery.yard(self)
	Scenery.water(self)
	_stamp("terrain, sky, map scenery")
	await Scenery.scatter(self, spread)
	_stamp("grass and stones")
	_world_ready = true
	if _pending_gate != null and is_instance_valid(_pending_gate):
		_portal_side(_pending_gate)
	dreaming = Rules.activities[activity].get("dream", false)
	if dreaming:
		# Tel'aran'rhiod: the same place, with the colour gone out of it and a light
		# that comes from nowhere.
		for c in get_children():
			if c is WorldEnvironment:
				var env: Environment = c.environment
				env.adjustment_enabled = true; env.adjustment_saturation = 0.45; env.adjustment_contrast = 1.08
				env.ambient_light_energy *= 1.5
				env.fog_enabled = true; env.fog_light_color = Color(0.5, 0.5, 0.62); env.fog_density = 0.012
			elif c is DirectionalLight3D:
				(c as DirectionalLight3D).light_energy *= 0.55
				(c as DirectionalLight3D).light_color = Color(0.82, 0.84, 1.0)
		Dream.load_data()
		for mv in Dream.moves:
			var k: String = profile.get("dream_keys", {}).get(mv, Dream.moves[mv].key)
			dream_keys[OS.find_keycode_from_string(k)] = mv
		# --foe=mirror|warder|aiel|hunter|channeller: someone to duel when no friend
		# is here. Entering a duel alone meets your own shade.
		if session.is_host and (args.has("foe") or Rules.activities[activity].kind == "spar"):
			var kind: String = args.get("foe", "mirror")
			var fp: Dictionary
			if kind == "mirror":
				fp = profile.duplicate(true); fp.name = "Your shade"
			elif kind == "channeller":
				fp = Profile.create({name = "A dreamwalker", potential_pts = 8, affinity_pts = {fire = 4, air = 2}})
				for w in ["fireball", "hammer_of_air", "lightning"]:
					fp.weaves[w] = {known = true, xp = 0.0}
			else:
				fp = Profile.create({name = "A dreamwalker", cls = kind, stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = Rules.CLASSES[kind].kit})
			_foe_profile = fp
	# --spawn=myrddraal:1,trolloc_archer:2 puts enemies a few paces off, to look at
	# them in a render.
	if args.has("spawn") and session.is_host:
		for part in args.spawn.split(","):
			# type:count, or type:count@metres for things that fight from a distance.
			var far := 7.0
			if part.contains("@"):
				far = float(part.get_slice("@", 1)); part = part.get_slice("@", 0)
			var kv: PackedStringArray = part.split(":")
			if Rules.enemies.has(kv[0]):
				for i in (int(kv[1]) if kv.size() > 1 else 1):
					session.sim._add_enemy(kv[0], Vector3(randf_range(-3, 3), 0, -far - i * 2.0))

	# --ally=warder|channeller: a bot friend at your side (--ally_hp=45 starts them hurt),
	# for the things that need someone else: Healing, a Warder's ward, the bond.
	if args.has("ally") and session.is_host:
		var ap: Dictionary = Profile.create({name = "Friend", potential_pts = 8, affinity_pts = {fire = 4, earth = 2}}) if args.ally == "channeller" \
			else Profile.create({name = "Friend", cls = args.ally, stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = Rules.CLASSES[args.ally].kit})
		_ally = session.sim.add_player(ap, Vector3(2.5, 0, 1.0))
		if args.has("ally_hp"):
			session.sim.ents[_ally].hp = float(args.ally_hp)
	# --levels=N: the team starts N levels up, choices waiting (a quick look at
	# levelling). --fast: the waves come four times as fast.
	if session.is_host and session.sim.round_mode:
		var lside: int = session.sim.ents.get(session.my_id, {}).get("team", 0)
		for i in int(args.get("levels", "0")):
			session.sim._gain(Round.xp_for(session.sim.levels.get(lside, 1) if not session.sim.battle.is_empty() else session.sim.team_level), lside)
		if args.has("fast"):
			for w in session.sim._waves:
				w.t = 3.0 + (w.t - 3.0) * 0.25
	if args.has("tour"):
		var st: Dictionary = Launch.TOUR[Launch.tour]
		print("TOUR station %d %s" % [Launch.tour + 1, st.title])
		tour_label.text = "%d / %d   %s\n\n%s\n\n%s next   ·   %s back   ·   %s again   ·   F10 camp" % [Launch.tour + 1, Launch.TOUR.size(), st.title.to_upper(), st.feel, Keys.name(KEY_N), Keys.name(KEY_B), Keys.name(KEY_R)]
		tour_card.visible = true

var _ally := 0

# --- the gateway home ------------------------------------------------------------
# When a round ends, a gateway opens ahead with the camp behind it (built in a world
# of its own, from the doorway you left by). Walk through and, as the camera crosses,
# the camp is simply the world you are in: no load, no cut.
var _home := {}

func _open_home() -> void:
	if me == null or not is_instance_valid(me) or _leaving or DisplayServer.get_name() == "headless":
		return
	if actors.get(session.my_id, {}).get("dead", false):
		return     # the dead are carried home (Enter)
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.use_hdr_2d = true
	vp.size = get_viewport().get_visible_rect().size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	Launch.return_preview = true
	var camp: Node3D = load("res://src/game/camp.tscn").instantiate()
	vp.add_child(camp)
	var fwd := Vector3(sin(me.rotation.y), 0, cos(me.rotation.y))
	var at := me.position + fwd * 3.5
	var G := Transform3D(Basis.looking_at(fwd, Vector3.UP), _ground(at))
	var n := Node3D.new(); add_child(n); n.transform = G
	var q := QuadMesh.new(); q.size = Vector2(1.9, 3.3)
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.position = Vector3(0, 1.65, 0)
	# The quad's front faces +Z; turn it to face back toward the player.
	mi.rotation.y = PI
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/portal.gdshader")
	sm.set_shader_parameter("tint", Color(1.0, 0.85, 0.6)); sm.set_shader_parameter("lit", 1.0)
	sm.set_shader_parameter("view", vp.get_texture()); sm.set_shader_parameter("live", 1.0)
	mi.material_override = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	mi.scale = Vector3(0.02, 1, 1)
	create_tween().tween_property(mi, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(self, "chime", n.position + Vector3(0, 1.5, 0), 0.0, 0.6)
	_home = {vp = vp, camp = camp, G = G, node = n}
	Toast.say("A gateway home", "Walk through it to the camp (Enter: straight back).", "good", 8.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _step_home(dt: float) -> void:
	if _home.is_empty() or me == null:
		return
	var camp: Node3D = _home.camp
	var G: Transform3D = _home.G
	var M: Transform3D = camp.home_frame() * G.affine_inverse()
	# The round is over and the sim stopped: the body walks here, in the view.
	var v := Vector2(float(Keys.down(KEY_D)) - float(Keys.down(KEY_A)), float(Keys.down(KEY_S)) - float(Keys.down(KEY_W)))
	if args.has("homewalk"):
		# A render walking home: straight at the gateway.
		var to: Vector3 = (G.origin - me.position) * Vector3(1, 0, 1)
		cam_yaw = lerp_angle(cam_yaw, atan2(-G.basis.z.x, -G.basis.z.z) + PI, 0.1)
		v = Vector2(0, -1)
	var move := Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)
	var ap: AnimationPlayer = me.get_meta("anim") if me.has_meta("anim") else null
	if move.length() > 0.1:
		me.position = _ground(me.position + move.normalized() * 5.0 * dt)
		me.rotation.y = lerp_angle(me.rotation.y, atan2(move.x, move.z), minf(10.0 * dt, 1.0))
		if ap and ap.has_animation("Jog_Fwd") and ap.current_animation != "Jog_Fwd": ap.play("Jog_Fwd", 0.15)
	elif ap and ap.current_animation != "Idle":
		ap.play("Idle", 0.2)
	camp.place_body(M * me.global_transform, ap.current_animation if ap else "Idle", ap.current_animation_position if ap else 0.0)
	var fwd := -G.basis.z
	var cam_in := (cam.global_position - G.origin).dot(fwd)
	camp.drive_camera(M * cam.global_transform, cam.fov, maxf(0.05, absf(cam_in) * 0.6))
	if cam_in > -0.3:
		_go_home.call_deferred(M)

func _go_home(M: Transform3D) -> void:
	if _home.is_empty():
		return
	var camp: Node3D = _home.camp
	var dyaw: float = camp.home_frame().basis.get_euler().y - (_home.G as Transform3D).basis.get_euler().y
	camp.drive_camera(M * cam.global_transform, cam.fov, 0.05)
	var body: Transform3D = M * me.global_transform
	_home.vp.remove_child(camp)
	_home = {}
	var tree := get_tree()
	moving_worlds = false
	multiplayer.multiplayer_peer = null
	Launch.args = {}
	tree.root.remove_child(self)
	tree.root.add_child(camp)
	tree.current_scene = camp
	camp.enter_from_fight(cam_yaw + dyaw, cam_pitch, body, cam_off.x, cam_dist + cam_off.z)
	queue_free()

# --- gateways as windows -----------------------------------------------------------
# Each face of a gateway shows the world from where the camera would be at the other
# end (the same world, moved by the offset between the ends), so it reads as a hole
# onto that place; crossing it moves you by that same offset, and nothing jumps.
var windows: Array = []           # {node, views: [{mesh, vp, cam, off, dest}]}
var cam_shift := Vector3.ZERO     # my body went through; the camera has not yet
var cam_gate := {}                # {origin, n, s}: the plane it must cross to follow
var _window_env: Environment

func _open_window(g: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var meshes := []
	for c in g.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
	if meshes.size() != 2:
		return
	if _window_env == null:
		for c in get_children():
			if c is WorldEnvironment:
				# Untoned and unglowing: the main view tones the window once, as it does
				# the rest of the screen.
				_window_env = (c.environment as Environment).duplicate()
				_window_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
				_window_env.glow_enabled = false
	var w := {node = g, views = []}
	for i in 2:
		var mesh: MeshInstance3D = meshes[i]
		var dest: MeshInstance3D = meshes[1 - i]
		mesh.layers = 2; dest.layers = 2
		var vp := SubViewport.new(); vp.world_3d = get_world_3d(); vp.use_hdr_2d = true
		vp.size = get_viewport().get_visible_rect().size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		g.add_child(vp)
		var c := Camera3D.new(); vp.add_child(c)
		c.cull_mask = 0xFFFFF & ~2    # never the gateway's own faces
		c.environment = _window_env
		(mesh.material_override as ShaderMaterial).set_shader_parameter("view", vp.get_texture())
		(mesh.material_override as ShaderMaterial).set_shader_parameter("live", 1.0)
		w.views.append({mesh = mesh, vp = vp, cam = c, dest = dest})
	windows.append(w)

func _update_windows() -> void:
	windows = windows.filter(func(w: Dictionary) -> bool: return is_instance_valid(w.node))
	for w in windows:
		for v in w.views:
			var off: Vector3 = (v.dest as Node3D).global_position - (v.mesh as Node3D).global_position
			var c: Camera3D = v.cam
			c.global_transform = Transform3D(cam.global_transform.basis, cam.global_position + off)
			c.fov = cam.fov
			# Nothing between that camera and the far face may get in the picture.
			var face: Node3D = v.dest
			var n: Vector3 = face.global_transform.basis.z
			c.near = maxf(0.05, absf((c.global_position - face.global_position).dot(n)) * 0.6)
			(v.vp as SubViewport).size = get_viewport().get_visible_rect().size

# --- the round, as this player sees it -------------------------------------------
var autos := {}                    # weaves left going by themselves (G on a weave that strikes)
var darkfriend := false          # told in secret: this player serves the Shadow
var team_meter: Array = []        # [team level, share of the way to the next]
var mirror := {}                  # my round copy as far as I can know it (no potential)
var patches := {}                 # burning grass and puddles, by id
var pick_card: PanelContainer

## Who the HUD and the choice panel describe: the round copy in a round. On the
## host it is the sim's own; a client keeps a mirror from what it is told.
func view_profile() -> Dictionary:
	if session != null and session.is_host and session.sim != null and session.sim.ents.has(session.my_id) and session.sim.ents[session.my_id].profile.has("round"):
		return session.sim.ents[session.my_id].profile
	return mirror if not mirror.is_empty() else profile

func _round_intro(e: Dictionary) -> void:
	mirror = profile.duplicate(true)
	mirror.round = e.round.duplicate()
	if mirror.get("cls", "channeller") == "channeller":
		for w in mirror.weaves:
			mirror.weaves[w].xp = 0.0
		mirror.strength = Rules.strength_of(float(e.round.strength)); mirror.potential = mirror.strength
		mirror.channelled = float(Rules.TUNE.flow_steps[3])
		if e.round.get("warder", false):
			_banner("A Warder rides with you\nHe is no blademaster, but he will stand at your side.", 6.0, "good")
	else:
		mirror.skills = {}

func _round_level(e: Dictionary) -> void:
	if mirror.is_empty():
		return
	mirror.round.level = e.level; mirror.round.picks = e.picks
	var body := ""
	if e.has("strength"):
		var before := Rules.level_of(Rules.strength(mirror))
		mirror.strength = Rules.strength_of(float(e.strength)); mirror.potential = mirror.strength
		mirror.channelled = float(Rules.TUNE.flow_steps[int(e.get("flows", 3))])
		if e.has("leap"):
			body = "Your strength leaps: %s. " % Rules.level_name(int(e.strength))
		elif int(e.strength) < before:
			body = "Your strength grows: %s. " % Rules.level_name(int(e.strength))
		body += e.get("hint", "") + "."
	elif e.has("stat"):
		mirror.stats[e.stat] = int(mirror.stats.get(e.stat, 0)) + 1
		body = "%s +1." % String(e.stat).capitalize()
	_banner("Level %d\n%s  %s: choose what to grow." % [e.level, body, Keys.name(KEY_TAB)], 4.0, "good")

func _round_picked(e: Dictionary) -> void:
	if not mirror.is_empty() and not (session.is_host and session.sim != null):
		mirror.round.picks += 1
		Round.pick(mirror, e.kind, e.choice)
	if not mirror.is_empty():
		mirror.round.picks = e.picks
	# New arms and forms go on the bar.
	if e.kind in ["weapon", "form", "learn"] and not known.has(e.choice):
		known.append(e.choice)
		if e.kind == "weapon":
			var row: Dictionary = Rules.weapons[e.choice]
			ammo[e.choice] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	if pick_card and pick_card.visible:
		_show_picks(true)
	if tree_view and tree_view.visible:
		_show_tree(true)

var tree_view: WeaveTree
var tree_note: Label

## Tab for a channeller: the weave chart, any time. With a level-up to spend, click a
## weave you know to grow it or an open one to learn it.
func _show_tree(on: bool) -> void:
	if tree_view == null:
		tree_view = WeaveTree.new(); hud_layer.add_child(tree_view)
		tree_view.pickable = true
		tree_view.chosen.connect(func(id: String) -> void:
			var vp := view_profile()
			if vp.get("round", {}).get("picks", 0) <= 0:
				return
			session.pick("weave" if Rules.knows(vp, id) else "learn", id))
		tree_note = Label.new(); hud_layer.add_child(tree_note)
		tree_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		tree_note.offset_top = 18; tree_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tree_note.add_theme_font_override("font", Glyph.serif()); tree_note.add_theme_font_size_override("font_size", 22)
		tree_note.add_theme_color_override("font_color", Glyph.GOLD)
	tree_view.visible = on
	tree_note.visible = on
	if on:
		tree_view.profile = view_profile()
		var left: int = view_profile().get("round", {}).get("picks", 0)
		tree_note.text = ("%d to choose: a weave you know grows, an open one is learned   ·   Tab closes" % left) if left > 0 else "The weave chart   ·   Tab closes"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not args.has("auto") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Tab: what this level-up can grow, from your tree (Round.choices).
func _show_picks(on: bool) -> void:
	if pick_card == null:
		pick_card = Glyph.card(Color(Glyph.GOLD, 0.45)); hud_layer.add_child(pick_card)
		pick_card.mouse_filter = Control.MOUSE_FILTER_STOP
		pick_card.anchor_left = 0.5; pick_card.anchor_right = 0.5; pick_card.anchor_top = 0.2
		pick_card.offset_left = -220; pick_card.offset_right = 220
		pick_card.add_child(VBoxContainer.new())
	var box: VBoxContainer = pick_card.get_child(0)
	for c in box.get_children():
		c.queue_free()
	var vp := view_profile()
	var left: int = vp.get("round", {}).get("picks", 0)
	if not on or left <= 0:
		pick_card.visible = false
		if not args.has("auto") and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	pick_card.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title := Label.new(); title.text = "Grow (%d to choose)" % left; box.add_child(title)
	title.add_theme_font_override("font", Glyph.serif()); title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	for ch in Round.choices(vp):
		var b := Button.new(); box.add_child(b)
		var now := ""
		match ch.kind:
			"weave": now = "mastery %d → %d" % [Rules.mastery_level(vp, ch.id), Rules.mastery_level(vp, ch.id) + 1]
			"skill": now = "%d → %d" % [Rules.skill_level(vp, ch.id), Rules.skill_level(vp, ch.id) + 1]
			"form": now = "new form"
			"learn": now = "new weave"
			"weapon": now = "new weapon"
		b.text = "%s   ·   %s" % [ch.name, now]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var k: String = ch.kind; var id: String = ch.id
		b.pressed.connect(func() -> void: session.pick(k, id))

## Only a game on this machine alone can stop: a shared one runs on for the others.
func can_pause() -> bool:
	return not previewing and session != null and session.is_host and not args.has("join") and not _done

# --- the far side of a camp doorway ------------------------------------------------
# Built in a world of its own while you walk up to the doorway (the camp shows it
# through the doorway, from where your camera would be on this side), then made
# the world you are in when your camera passes through: no load, no cut.
var _walk_t := 0.0
var smooth_cam := 0.0              # seconds left of the camp's camera easing, carried through a doorway
var _world_ready := false
var _pending_gate: Node3D = null
var moving_worlds := false        # being taken from the doorway's world into the main one
var stand_in := {}                 # {xf, clip, at}: the camp's body, shown here until the hand-over
var previewing := false            # the camp is looking at this world through a doorway
var controlled := true             # the player's keys move them here
var hud_layer: CanvasLayer
var gate_frame := Transform3D()    # this side's doorway: at the ground, -Z the way out
var _gate: Node3D
var _env: Environment
var _look := {}                    # the environment's own tone and glow, put back on arrival

func portal_ready() -> bool:
	return me != null and _gate != null

## Stand an open gateway at the player's back, clear the ground behind it (the
## camp's camera looks through from there), and render untoned so the camp's
## own tone mapping is the only one applied to the view.
func _portal_side(rig: Node3D) -> void:
	var fwd := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	var at := rig.position - fwd * 0.6
	gate_frame = Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3(at.x, Terrain.height(at.x, at.z), at.z))
	_gate = Node3D.new(); add_child(_gate); _gate.transform = gate_frame
	var light := StandardMaterial3D.new(); light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.albedo_color = Color(1.0, 0.95, 0.85)
	# A gateway is a slit in the air turned open: only its edges show, a line of light.
	for bar in [[Vector3(-0.95, 1.65, 0), Vector3(0.03, 3.3, 0.03)], [Vector3(0.95, 1.65, 0), Vector3(0.03, 3.3, 0.03)], [Vector3(0, 3.3, 0), Vector3(1.93, 0.03, 0.03)], [Vector3(0, 0.0, 0), Vector3(1.93, 0.03, 0.03)]]:
		var b := BoxMesh.new(); b.size = bar[1]
		var mi := MeshInstance3D.new(); mi.mesh = b; mi.material_override = light; mi.position = bar[0]
		_gate.add_child(mi)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.9, 0.75); l.light_energy = 1.5; l.omni_range = 6.0; l.position = Vector3(0, 1.6, -0.5)
	_gate.add_child(l)
	# Grass and stones behind the gateway would stand between the camp's camera and
	# the doorway's view: put them away.
	var inv := gate_frame.affine_inverse()
	for c in get_children():
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = c.multimesh
			for i in mm.instance_count:
				var lp: Vector3 = inv * mm.get_instance_transform(i).origin
				if absf(lp.x) < 3.0 and lp.z > -0.2 and lp.z < 7.0:
					mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
	for c in get_children():
		if c is WorldEnvironment:
			_env = c.environment
			_look = {tone = _env.tonemap_mode, glow = _env.glow_enabled}
			_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			_env.glow_enabled = false

## The camp's camera, carried through: placed here as it stands relative to the
## camp's doorway. The near plane is pushed up to just short of the doorway so
## nothing on the near side of it gets in the picture.
func drive_camera(xf: Transform3D, fov: float, to_door: float) -> void:
	cam.global_transform = xf
	cam.fov = fov
	cam.near = maxf(0.05, to_door * 0.6)

## The player's feet have crossed: their keys move them here now, looking the way
## the camp's camera looks.
func take_control(yaw: float, pitch: float) -> void:
	controlled = true
	Wind.setup(Map.id, self)
	RenderingServer.global_shader_parameter_set("near_fade", 1.5)
	Scorch.setup(100.0)
	Debris.setup(self, hash(Map.id))
	stand_in = {}
	session.begin()     # the fight starts now, not when the doorway was first looked through
	cam_yaw = yaw; cam_pitch = pitch
	face_yaw = yaw + PI

## The camera has crossed: this is the world now. The camera starts exactly where
## the camp left it and eases to this game's own framing.
func enter_world(yaw: float, pitch: float, off: Vector3, fov: float) -> void:
	smooth_cam = 1.5
	previewing = false; controlled = true
	cam_yaw = yaw; cam_pitch = pitch
	cam.near = 0.05; cam.current = true
	cam_off = Vector3(off.x, off.y, off.z - cam_dist)
	fov_base = fov
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "cam_off", Vector3(0.6, 0.15, 0.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "fov_base", 70.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _env:
		_env.tonemap_mode = _look.tone
		_env.glow_enabled = _look.glow
	if hud_layer:
		hud_layer.visible = true
		hud.modulate.a = 0.0
		create_tween().tween_property(hud, "modulate:a", 1.0, 0.8)
	if not args.has("auto") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The gateway draws shut behind you once you are clear of it.
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if not is_instance_valid(_gate):
			return
		var t2 := create_tween()
		t2.tween_property(_gate, "scale", Vector3(0.02, 1.0, 1.0), 0.45).set_ease(Tween.EASE_IN)
		t2.tween_callback(_gate.queue_free))

## Stepping out into the fight: a gateway stands open at your back, the doorway's
## light lifts off the screen, and the gateway draws shut behind you.
func _arrive(rig: Node3D) -> void:
	_stamp("stepping out (preview %s, veil %s)" % [previewing, Veil.up()])
	if previewing:
		if _gate == null:
			if _world_ready:
				_portal_side(rig)
			else:
				_pending_gate = rig   # its grass is not down yet: wait for it
		return
	if not Veil.up():
		return
	var back := Vector3(-sin(rig.rotation.y), 0, -cos(rig.rotation.y))
	var g := Weavefx.gate(self, rig.position + back * 0.9, rig.position + back * 0.9 + back)
	# Seen from the front first, you with the gateway at your back, then the
	# camera comes round behind you as it closes.
	cam_swing = PI * 0.9
	var sw := create_tween()
	sw.tween_interval(0.9)
	sw.tween_property(self, "cam_swing", 0.0, 1.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Only the side facing the player matters; the light fades a moment after.
	get_tree().create_timer(0.25).timeout.connect(func() -> void: Veil.lift(0.9))
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if not is_instance_valid(g):
			return
		var tw := create_tween().set_parallel()
		for c in g.get_children():
			if c is MeshInstance3D:
				tw.tween_property(c, "scale", Vector3(0.02, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN)
			elif c is OmniLight3D:
				tw.tween_property(c, "light_energy", 0.0, 0.4)
		tw.chain().tween_callback(g.queue_free))
var _started := false
var _t0 := 0
## --timing: when each part of opening a fight happens, to hunt pauses.
func _stamp(what: String) -> void:
	if Launch.cmdline().has("timing"):
		print("TIMING %6d ms  %s  (since camp: %d)" % [Time.get_ticks_msec() - _t0, what, Time.get_ticks_msec() - Launch.left_camp])

## The server could not be reached, or turned us away: say so, and play the same
## thing here alone instead of leaving the player at a dead end. Bots and tests
## (which join on purpose) stop, so a broken server shows up as a failure.
func _offline(why: String) -> void:
	if _rejoin_until > 0.0 and not _done:
		# Knocking to be let back in, and the server said no.
		_done = true; _rejoin_until = 0.0
		Toast.say("Could not get back in", "%s. Enter: back to the camp." % why.capitalize(), "warn", 15.0)
		return
	if _started or _done:
		return
	print("GAME rejected: ", why)
	if args.has("auto") or args.has("ghost"):
		_done = true
		return
	if why.contains("different version"):
		# Out of date, or the server is: say which, with both builds, and what to do.
		var theirs := {}
		var i := why.find("[build ")
		if i >= 0:
			var d = JSON.parse_string(why.substr(i + 7, why.length() - i - 8))
			if d is Dictionary: theirs = d
		# A server too old to send its build at all is the one behind.
		var who := Updater.behind(Updater.stamp(), theirs) if not theirs.is_empty() else "the server"
		var newer := Updater.newest != "" and Updater.newest != Updater.tag()
		var body := "This game: %s\nThe server: %s\n" % [Updater.label(Updater.stamp()), Updater.label(theirs) if not theirs.is_empty() else "an older build"]
		if who == "your game":
			body += "Your game is out of date: %s" % ("restart and it updates itself." if newer else "get the latest build.")
		elif who == "the server":
			body += "The server is out of date: it needs updating."
		else:
			body += "They differ: update whichever is older."
		Toast.say("Versions differ: playing offline", body, "warn", 14.0)
	elif why.contains("turned you away") and String(args.get("word", "")) == "":
		# The usual reason: this machine has never been given the server's word.
		Toast.say("Playing offline: no server word", "The server wants its word. Esc, then type it into \"the server's word\" (asked once; kept on this machine). Friends can't join until then.", "warn", 14.0)
	elif why.contains("turned you away"):
		Toast.say("Playing offline: wrong word?", "The server turned you away. Check the server's word under Esc (it must match the one on the server exactly).", "warn", 12.0)
	else:
		Toast.say("Playing offline", "Couldn't reach the server (%s). Friends can't join this game." % why, "warn", 8.0)
	multiplayer.multiplayer_peer = null
	args.erase("join")
	session.host(args.get("activity", "tarwins_gap_watch"), profile, Session.PORT, previewing, false)

# --- mirroring the sim ----------------------------------------------------------------

func _on_events(list: Array) -> void:
	for e in list:
		# --ghost: say what the sim made of the scripted hands, for a test to read.
		if args.has("ghost") and e.get("id", 0) == session.my_id and e.e in ["blow", "dodge", "equip", "form", "ready", "cast", "hold", "release", "tie", "loose", "strike", "dream", "shift", "deny"]:
			print("GHOST %d %s %s" % [frame, e.e, e.get("move", e.get("weave", e.get("weapon", "roll" if e.get("roll", false) else "")))])
		# --log: say when my weaves form, fly and land, so a render's frames can be picked.
		if args.has("log") and e.e in ["form", "ready", "cast", "loose", "blast", "hold", "gate_open", "jump", "knocked_down", "rise"] and e.get("id", session.my_id) == session.my_id:
			print("EV %d %s %s" % [frame, e.e, e.get("weave", "")])
		match e.e:
			"spawn":
				if not actors.has(e.id):
					_spawn_enemy(e.id, e.type, e.pos)
			"downed":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].kind == "player":
					(actors[e.id].node.get_meta("anim") as AnimationPlayer).play("Death01", 0.2)
					actors[e.id].downed = true
				if e.id == session.my_id:
					_banner("You are down\nA friend must stand over you within %d seconds. Half a body more and you are dead." % int(e.secs), 6.0, "warn")
				elif actors.has(e.id) and in_battle and int(actors[e.id].get("team", 0)) != my_team:
					_banner("%s is down\nFinish them before their side brings them back." % actors[e.id].get("name", "One of theirs"), 4.0, "good")
				elif actors.has(e.id):
					_banner("%s is down\nStand over them to bring them back." % actors[e.id].get("name", "A friend"), 5.0, "warn")
			"revived":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].kind == "player":
					(actors[e.id].node.get_meta("anim") as AnimationPlayer).play("Idle", 0.3)
					actors[e.id].downed = false
				if e.id == session.my_id:
					_banner("Back on your feet\nHurt and winded: get healed, or rest.", 4.0, "good")
			"returned":
				if actors.has(e.id):
					actors[e.id].dead = false; actors[e.id].downed = false
					if is_instance_valid(actors[e.id].node):
						actors[e.id].node.visible = true
						(actors[e.id].node.get_meta("anim") as AnimationPlayer).play("Idle", 0.2)
				if e.id == session.my_id:
					if not mirror.is_empty() and mirror.get("cls", "channeller") == "channeller":
						mirror.strength = Rules.strength_of(float(e.strength)); mirror.potential = mirror.strength
					_banner("You return with the wave\nWeaker for dying: %d level%s of strength lost." % [e.lost, "" if e.lost == 1 else "s"], 6.0, "warn")
			"knocked_down":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].kind == "player":
					var ka: Dictionary = actors[e.id]
					# The fall: the death clip run quickly, held on the ground until they rise.
					(ka.node.get_meta("anim") as AnimationPlayer).play("Death01", 0.08, 1.8)
					ka.lying = true; ka.erase("gesture"); ka.forming = false
					if e.id == session.my_id:
						_banner("Swept off your feet\n%s: roll up and away   ·   %s: rise behind your guard" % [Keys.name(KEY_SPACE), "Right click"], 3.0, "warn")
			"rise":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var ra: Dictionary = actors[e.id]
					ra.lying = false
					if e.how != "roll":
						# Getting up: the fall played backwards (the pack has no get-up).
						(ra.node.get_meta("anim") as AnimationPlayer).play("Death01", 0.05, -2.4 if e.how == "guard" else -1.6, true)
						ra.busy = 0.45 if e.how == "guard" else 0.65
			"jump":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].kind == "player":
					var ja: Dictionary = actors[e.id]
					var jap: AnimationPlayer = ja.node.get_meta("anim")
					if jap.has_animation("Jump"):
						jap.play("Jump", 0.08, 1.7)
						ja.busy = 0.55
			"story":
				# The fight's reading limit (the least-read player's): what is past it
				# is neither usable nor drawn.
				profile.book_limit = mini(int(profile.get("book_limit", 14)), int(e.limit))
				# Off the bar too: a weave past the limit is not there to choose.
				known = known.filter(func(w: String) -> bool: return not Rules.weaves.has(w) or Rules.weaves[w].book <= profile.book_limit or profile.get("starter", "") == w)
				selected = mini(selected, maxi(known.size() - 1, 0))
				if not mirror.is_empty():
					mirror.book_limit = mini(int(mirror.get("book_limit", 14)), int(e.limit))
				if tree_view != null and tree_view.visible:
					tree_view.profile = view_profile(); tree_view.queue_redraw()
			"away":
				if e.id != session.my_id:
					Toast.say("%s lost the connection" % e.name, "Their place is kept for %d seconds." % int(e.secs), "info", 6.0)
			"back":
				if e.id != session.my_id:
					Toast.say("%s is back" % e.name, "", "good", 4.0)
			"level":
				if e.id == session.my_id:
					_round_level(e)
			"role":
				darkfriend = e.darkfriend
				if e.darkfriend:
					_banner("You serve the Shadow\nNo one else knows. Let the loyal fall; do not be caught. %s: once, open a gateway for the Shadow's own (when you are strong enough to weave one)." % Keys.name(KEY_J), 12.0, "shadow")
				else:
					_banner("You are loyal\nThere may be a Darkfriend among you. Shield or bind a traitor, or kill them, and live to the end.", 9.0, "info")
			"df_gate":
				var g := Weavefx.gate(self, _ground(e.pos), _ground(e.pos) + Vector3(sin(e.yaw), 0, cos(e.yaw)))
				get_tree().create_timer(4.0).timeout.connect(func() -> void: if is_instance_valid(g): g.queue_free())
				_banner("A gateway opens\nDarkfriends pour through. Someone opened it for them…", 6.0, "shadow")
			"link_open":
				if e.id == session.my_id:
					_banner("You offer to link\nA woman who channels must lead: when she links (%s) near you, you join her circle." % Keys.name(KEY_L), 5.0)
			"linked":
				var mine: bool = e.id == session.my_id or (e.members as Array).has(session.my_id)
				if mine:
					_banner("Linked: a circle of %d\n%s" % [(e.members as Array).size() + 1, "You lead: you weave with all of it. %s lets them go." % Keys.name(KEY_L) if e.id == session.my_id else "Your leader weaves with your strength. You cannot channel, or leave, unless she lets you go."], 6.0, "good")
			"unlinked", "link_lost":
				if e.id == session.my_id or (e.get("members", []) as Array).has(session.my_id):
					_banner("Out of the circle", 3.0)
			"unmade":
				# Burnt out of the Pattern: what it did never happened. The dead are
				# drawn afresh by the introduction that follows.
				if e.dead and actors.has(e.id):
					if is_instance_valid(actors[e.id].node):
						actors[e.id].node.queue_free()
					actors.erase(e.id)
				elif actors.has(e.id):
					actors[e.id].downed = false
			"balefire_unmade":
				if e.n > 0:
					_banner("Balefire\nWhat it did these last moments never happened: %d stand%s again." % [e.n, "s" if e.n == 1 else ""], 5.0, "good")
			"auto":
				if e.id == session.my_id:
					if e.on: autos[e.weave] = true
					else: autos.erase(e.weave)
					_banner("%s %s" % [Rules.weaves[e.weave].name, "goes on by itself\nIt keeps its flows and weaves itself at the nearest foe. %s again stops it." % Keys.name(KEY_G) if e.on else "stops"], 3.0, "info")
			"cancel":
				if e.id == session.my_id:
					my_form = {}
				if actors.has(e.id):
					_end_form(actors[e.id])
			"tied", "untied":
				var who: String = "You are" if e.id == session.my_id else "%s is" % (actors[e.id].get("name", "Someone") if actors.has(e.id) else "Someone")
				if e.e == "tied":
					_banner("%s tied with rope\nNo walking, no blows. Rope does not stop the Power: Shield a channeller too." % who, 5.0, "warn")
				else:
					_banner("%s free of the rope%s" % [who, " (burnt off)" if e.get("burnt", false) else ""], 3.0, "info")
			"endless_won":
				_banner("Thirty minutes held\nThe win is yours. They keep coming: hold as long as you like.", 7.0, "good")
			"picked":
				if e.id == session.my_id:
					_round_picked(e)
			"player":
				if e.id == session.my_id and not e.get("round", {}).is_empty() and mirror.is_empty():
					_round_intro(e)
				if not actors.has(e.id):
					# Everyone appears as they chose to look, on every machine.
					_stamp("hero model begins")
					var rig := Hero.instantiate(Hero.kind_for(e), hash(e.name), e.get("style", {}))
					_stamp("hero model made")
					add_child(rig)
					rig.position = _ground(e.pos)
					actors[e.id] = {node = rig, kind = "player", target = rig.position, busy = 0.0, name = e.name, yaw = PI, team = int(e.get("team", 0))}
					# In a battle, a ring of your banner's colour at everyone's feet:
					# blue for your side, red for theirs, so a glance tells friend from foe.
					if in_battle:
						_team_ring(rig, int(e.get("team", 0)))
					Hero.arm(rig, e.get("weapon", ""))
					actors[e.id].weapon = e.get("weapon", "")
					# Aiel veil themselves to fight.
					if e.get("cls", "") == "aiel":
						Hero.veil(rig, true)
					if e.id == session.my_id:
						me = rig
						banner.text = ""
						my_team = int(e.get("team", 0))
						_paint_rings()
						_arrive(rig)
						if known.has(e.get("weapon", "")):
							selected = known.find(e.weapon)
						# Once, and not over a tour station's own instructions.
						if _hinted or args.has("tour"):
							pass
						elif not profile.get("kit", []).is_empty():
							_banner("Left click: attack (hold for a heavy blow, or to draw a bow)   Right click: parry, just before the blow lands\nSpace: roll (standing: step back)   Ctrl: duck   %s: jump   %s: throw   1-9: change what is in hand" % [Keys.name(KEY_V), Keys.name(KEY_F)], 9.0)
						elif not known.is_empty():
							_banner("Hold left click to weave; let go to loose it where you are looking\n1-9 or %s / %s: choose the weave   %s: tie off a held weave   Space: roll" % [Keys.name(KEY_Q), Keys.name(KEY_E), Keys.name(KEY_G)], 9.0)
						_hinted = true
			"die":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					# Flames, sparks and the rest do not outlast the one they clung to.
					a.dead = true
					_status(a, 0)
					if a.node is Walker:
						(a.node as Walker).vel = Vector3.ZERO
						# It falls away from whatever struck it last, harder for a heavy blow.
						var from: Vector3 = a.get("last_from", me.position if me else Vector3.ZERO)
						(a.node as Walker).die(a.node.position - from, a.get("last_force", 1.0))
						get_tree().create_timer(6.0).timeout.connect(a.node.queue_free)
					elif a.node is Hound:
						(a.node as Hound).vel = Vector3.ZERO
						(a.node as Hound).die(a.node.position - (me.position if me else Vector3.ZERO))
						get_tree().create_timer(6.0).timeout.connect(a.node.queue_free)
					elif a.kind == "player":
						# The pack has one death: vary its pace and turn the body as it
						# goes, so two players do not fall the same.
						var ap := a.node.get_meta("anim") as AnimationPlayer
						var dr := RandomNumberGenerator.new(); dr.seed = int(e.id) * 7919 + frame
						ap.play("Death01", 0.15, dr.randf_range(0.8, 1.25))
						var tw: Tween = a.node.create_tween()
						tw.tween_property(a.node, "rotation:y", a.node.rotation.y + dr.randf_range(-0.9, 0.9), 0.7).set_ease(Tween.EASE_OUT)
					else:
						a.node.queue_free()
					a.dead = true
			"hit":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					if a.node is Walker and not a.get("dead", false):
						# The body answers the blow: a knife barely moves it, a hammer or a
						# shoving spear throws it back on its heels and it hangs longer.
						var knock: float = e.get("knock", 0.0)
						var from: Vector3 = actors[e.by].node.position if actors.has(e.by) and is_instance_valid(actors[e.by].node) else (me.position if me else Vector3.ZERO)
						(a.node as Walker).hit(a.node.position - from, clampf(0.55 + knock * 0.14, 0.55, 2.4))
						a.last_from = from; a.last_force = clampf(0.55 + knock * 0.14, 0.55, 2.4)
						# Hit-stop, for the one struck only: it flashes and hangs for a few
						# frames, heavier blows longer. The world keeps moving (co-op).
						if e.dmg >= 4.0:
							_flash(a.node)
							a.hold = clampf(e.dmg * 0.004 + knock * 0.008, 0.05, 0.2)
							if e.by == session.my_id:
								punch = minf(punch + e.dmg * 0.01, 1.0)
					elif a.node is Hound and not a.get("dead", false):
						var from2: Vector3 = actors[e.by].node.position if actors.has(e.by) and is_instance_valid(actors[e.by].node) else (me.position if me else Vector3.ZERO)
						(a.node as Hound).hit(a.node.position - from2, clampf(0.55 + float(e.get("knock", 0.0)) * 0.14, 0.55, 2.0))
						if e.dmg >= 4.0:
							_flash(a.node)
					elif a.kind == "player" and not a.get("dead", false):
						# An overhead blow drives the head down, a shove throws them back.
						_play(a, a.get("struck_by", "Hit_Chest"), true)
						a.erase("struck_by")
			"form":
				if actors.has(e.id):
					var a: Dictionary = actors[e.id]
					_play(a, "Spell_Simple_Enter", true)
					# The hands stay raised for as long as the weave is in them.
					a.busy = 0.0; a.erase("gesture"); a.forming = true
					if is_instance_valid(a.node):
						_end_form(a)
						a.form_fx = Weavefx.forming(self, a.node, e.weave, e.time)
						a.form_since = clock
					Sfx.play(self, "hum", _ground(a.target) + Vector3(0, 1.4, 0), -8.0, clampf(1.6 / maxf(e.time, 0.4), 0.5, 1.6))
					if e.id == session.my_id:
						my_form = {weave = e.weave, since = clock, time = e.time, ready = false}
			"ready":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Sfx.play(self, "chime", actors[e.id].node.position + Vector3(0, 1.4, 0), -4.0, 1.5)
				if e.id == session.my_id:
					my_form.ready = true
			"fizzle":
				if actors.has(e.id):
					_end_form(actors[e.id])
				if e.id == session.my_id:
					my_form = {}
					last_refusal = "No one there to hold"; refusal_t = 1.5
			"attack":
				# How the one struck takes it depends on what struck them (see "hit").
				if actors.has(e.target):
					actors[e.target].struck_by = "Hit_Knockback" if e.get("push", 0.0) >= 4.0 else ("Hit_Head" if e.get("kind", "") == "chop" else "Hit_Chest")
				# A lunge at the victim: the gait has no attack clip, so borrow the hit spring.
				if actors.has(e.id) and actors.has(e.target) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					var w: Walker = actors[e.id].node
					w.hit((_ground(actors[e.target].target) - w.position).normalized(), 0.35)
					Sfx.play(self, "thud", w.position + Vector3(0, 1.2, 0), 0.0)
			"swing":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Hound:
					var h: Hound = actors[e.id].node
					h.attack("bite")
					Armsfx.telegraph(self, _ground(Vector3(h.pos.x, 0, h.pos.z)), e.yaw, e.reach + 0.45, e.arc, e.time, e.height)
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					var w: Walker = actors[e.id].node
					w.attack(e.get("kind", "chop"))
					# Exactly where this blow will fall, on the ground, for as long as
					# there is to get out of it or meet it.
					Armsfx.telegraph(self, _ground(Vector3(w.pos.x, 0, w.pos.z)), e.yaw, e.reach + 0.45, e.arc, e.time, e.height)
					Sfx.play(self, "whoosh", w.position + Vector3(0, 1.6, 0), -9.0, 0.6)
			"lunge":
				# A Myrddraal has chosen its line: a streak of shadow along the ground.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var n: Node3D = actors[e.id].node
					Armsfx.lunge_line(self, _ground(Vector3(n.position.x, 0, n.position.z)), e.yaw, e.dist, e.wind)
					if n is Walker:
						(n as Walker).attack("thrust")
					elif n is Hound:
						(n as Hound).attack("thrust")
					Sfx.play(self, "hum", n.position + Vector3(0, 1.2, 0), 2.0, 0.45)
			"aloft", "land":
				if actors.has(e.id):
					actors[e.id].aloft = e.e == "aloft"
			"song":
				# The tell: rings of sound going out from it for as long as it has to sing.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Weavefx.song(actors[e.id].node, e.time)
					Sfx.play(self, "hum", actors[e.id].node.position + Vector3(0, 1.6, 0), 4.0, 1.9)
					if e.target == session.my_id:
						_banner("It is singing to you: strike it, or get out of its sight", e.time)
			"entranced":
				if e.id == session.my_id:
					_banner("The song has you", 3.0)
				elif actors.has(e.id):
					_banner("The song has %s: hurt the Draghkar" % actors[e.id].get("name", "a friend"), 3.0)
			"kiss":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					(actors[e.id].node as Walker).attack("thrust")
			"song_end":
				if e.target == session.my_id and my_trance:
					_banner("The song breaks", 1.5)
			"channel":
				# A Dreadlord gathering the Power: it shows in its hands, as it does in yours.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					_end_form(a)
					a.form_fx = Weavefx.forming(self, a.node, "fireball", e.time)
					a.form_since = clock + e.time
					if a.node is Walker:
						(a.node as Walker).attack("chop")
			"doom":
				# Marked ground: a full circle, for as long as there is to leave it.
				Armsfx.telegraph(self, _ground(e.pos), 0.0, e.radius, 180.0, e.time, "mid")
				Sfx.play(self, "hum", _ground(e.pos), 3.0, 0.7)
			"doom_hit":
				Weavefx.doom(self, _ground(e.pos), e.radius)
				Sfx.play(self, "boom", _ground(e.pos), 4.0, 0.8)
				shake_at(_ground(e.pos), e.radius)
			"fade_out":
				Weavefx.smoke(self, _ground(e.pos), false)
			"fade_in":
				Weavefx.smoke(self, _ground(e.pos), true)
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].node is Walker:
					actors[e.id].target = e.pos
					(actors[e.id].node as Walker).teleport(e.pos, (actors[e.id].node as Walker).heading)
				_banner("Behind you", 1.2)
			"parry_try":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					var ap: AnimationPlayer = a.node.get_meta("anim")
					# The block clip from its middle, where the blade is already across.
					ap.play("Sword_Block", 0.06, 1.6)
					ap.seek(0.25, true)
					a.busy = Rules.TUNE.parry_window; a.erase("gesture")
					Sfx.play(self, "whoosh", a.node.position + Vector3(0, 1.3, 0), -10.0, 1.9)
			"pierce":
				Weavefx.spit(self, e.pos, Weavefx.colour(e.weave))
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
				# (--log: say when each of my blows begins, to find its frames in a render.)
				if args.has("log") and e.id == session.my_id:
					print("BLOW %d %s wind=%.2f" % [frame, e.move, e.wind])
				# The clip is played at whatever speed makes the blade arrive when the
				# sim lands the blow.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					var m: Dictionary = Rules.moves[e.move]
					var ap: AnimationPlayer = a.node.get_meta("anim")
					var clip: String = m.clip if ap.has_animation(m.clip) else "Sword_Attack"
					var len := ap.get_animation(clip).length
					ap.play(clip, 0.08, clampf(len * m.get("at", 0.4) / maxf(e.wind, 0.05), 0.35, 4.0))
					var whole: float = e.wind + e.recover * 0.8 + (int(m.get("repeat", 1)) - 1) * float(m.get("gap", 0.12))
					a.busy = whole
					a.erase("gesture")
					a.reps = 0
					if e.move == "sling":
						a.whirl_until = clock + e.wind + 0.1
					# A thrust is made with the point forward along the arm.
					Hero.grip(a.node, m.get("grip", ""))
					a.grip_until = clock + whole if m.has("grip") else 0.0
					# A form with a stroke of its own: the arm and blade follow it,
					# whatever the clip does with the legs.
					# (An ordinary blow ends any stroke still running.)
					Hero.stroke(a.node, e.move, e.wind, e.recover * 0.8)
					# What makes a form its own: a turn of the whole body, a leap.
					if m.has("spin") or m.has("leap"):
						a.flourish = {t = 0.0, time = e.wind + e.recover * 0.5, spin = float(m.get("spin", 0.0)), leap = float(m.get("leap", 0.0)), land = e.wind}
					if e.get("form", false) and e.id == session.my_id:
						ready_at[e.move] = clock + float(Rules.forms[e.move].cooldown)
						flash_t = 0.9; flash_text = Rules.forms[e.move].name
					Sfx.play(self, "whoosh", a.node.position + Vector3(0, 1.3, 0), -5.0, 1.3)
			"strike":
				if e.hits > 0:
					Sfx.play(self, "thud", e.pos, 1.0, 1.25)
					if e.id == session.my_id:
						punch = minf(punch + 0.25, 1.0)
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and e.has("dir"):
					var a: Dictionary = actors[e.id]
					var m: Dictionary = Rules.moves[e.move]
					# The path of the blow, drawn where it cuts: what is inside it was hit.
					a.reps = a.get("reps", 0) + 1
					Armsfx.trail(self, a.node.position, e.dir, e.reach, m, a.reps, e.hits > 0)
					if int(m.get("repeat", 1)) > 1 and a.reps > 1:
						# A flurry: each wound is its own quick blow, hand after hand.
						var ap: AnimationPlayer = a.node.get_meta("anim")
						var clip: String = "Punch_Cross" if a.reps % 2 == 0 else "Punch_Jab"
						ap.stop(); ap.play(clip, 0.02, ap.get_animation(clip).length * 0.35 / maxf(float(m.get("gap", 0.12)), 0.05))
						Sfx.play(self, "whoosh", a.node.position + Vector3(0, 1.3, 0), -6.0, 1.7 + 0.1 * a.reps)
			"dodge":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					var ap: AnimationPlayer = a.node.get_meta("anim")
					_end_form(a)
					Hero.stroke(a.node, "", 0.1, 0.1)
					if e.get("back", false):
						# A step back, still facing them: the jog run backwards, leaning away.
						ap.play("Jog_Fwd", 0.04, -2.6, true)
						a.lean = {t = 0.0, time = e.time}
					elif e.get("vault", false):
						# Over a wall or a wagon: a jump, carried up and over (see _draw_actors).
						ap.play("Jump" if ap.has_animation("Jump") else "Roll", 0.05, ap.get_animation("Jump").length / maxf(e.time, 0.1) if ap.has_animation("Jump") else 1.0)
						a.roll_yaw = atan2(e.dir.x, e.dir.z)
						a.roll_until = clock + e.time
						a.vault = {t = 0.0, time = e.time}
						a.node.rotation.y = a.roll_yaw
					else:
						# A roll goes head first the way you are travelling, so the body
						# turns that way for as long as it lasts.
						ap.play("Roll", 0.05, ap.get_animation("Roll").length * 0.62 / maxf(e.time, 0.1))
						a.roll_yaw = atan2(e.dir.x, e.dir.z)
						a.roll_until = clock + e.time
						a.node.rotation.y = a.roll_yaw
					a.busy = e.time
					a.erase("gesture")
					Sfx.play(self, "whoosh", a.node.position + Vector3(0, 0.8, 0), -8.0, 0.8)
			"parry", "block", "guard_break":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var at: Vector3 = actors[e.id].node.position + Vector3(0, 1.3, 0) + Basis(Vector3.UP, actors[e.id].node.rotation.y) * Vector3(0, 0, 0.6)
					Weavefx.sparks(self, at, e.e == "parry")
					Sfx.play(self, "clang", at, 3.0 if e.e == "parry" else -3.0, 1.0 if e.e == "parry" else 0.8)
					if e.e == "parry":
						# Perfect: a ring of light off the steel, and the one who struck
						# is thrown back on its heels.
						Sfx.play(self, "chime", at, 4.0, 1.9)
						Armsfx.ring_flash(self, at)
						if actors.has(e.from) and is_instance_valid(actors[e.from].node) and actors[e.from].node is Walker:
							var fw: Walker = actors[e.from].node
							fw.hit((fw.position - actors[e.id].node.position).normalized(), 2.2)
							_flash(fw, 0.16)
					if e.id == session.my_id:
						flash_t = 1.0
						flash_text = {parry = "Perfect parry", block = "Parried", guard_break = "Your guard is broken"}[e.e]
						if e.e != "block":
							shake = minf(shake + 0.35, 1.0)
						if e.e == "parry":
							punch = 1.0
			"deflect":
				# An arrow off a shield: a spark and a knock of wood.
				Weavefx.sparks(self, e.pos, false)
				Sfx.play(self, "clang", e.pos, -4.0, 0.6)
				if e.id == session.my_id:
					flash_t = 0.6; flash_text = "Turned on the shield"
			"evade":
				if e.id == session.my_id:
					flash_t = 0.7; flash_text = "Ducked under it" if e.duck else "Missed you"
			"loose":
				if e.id == session.my_id:
					ammo[e.weapon] = e.left
					if Rules.weapons.has(e.weapon) and Rules.weapons[e.weapon].get("shot", {}).get("crank", false):
						spanned[e.weapon] = clock + Rules.draw_time(profile, e.weapon)
				if actors.has(e.id) and Rules.weapons.has(e.weapon) and Rules.weapons[e.weapon].get("shot", {}).get("crank", false):
					actors[e.id].span_until = clock + Rules.draw_time(profile, e.weapon)
				# What was thrown has left the hand: the last one leaves it empty, and
				# the next comes to hand a moment later.
				if actors.has(e.id) and actors[e.id].kind == "player" and is_instance_valid(actors[e.id].node) and Rules.weapons.has(e.weapon) and Rules.weapons[e.weapon].has("throw"):
					Hero.show_held(actors[e.id].node, false)
					actors[e.id].rearm = clock + 0.3 if e.left > 0 else -1.0
				if actors.has(e.id):
					var bow: bool = not Rules.weapons.has(e.weapon) or Rules.weapons[e.weapon].has("shot")
					Sfx.play(self, "twang" if bow else "whoosh", _ground(actors[e.id].target) + Vector3(0, 1.4, 0), -1.0, 1.0 if bow else 2.2)
					# A Trolloc archer: the arm comes up as it looses.
					if actors[e.id].node is Walker:
						(actors[e.id].node as Walker).attack("thrust")
			"arc":
				Weavefx.arc(self, e.from, e.to)
			"gate_kill":
				if not told.has("gate_kill"):
					told.gate_kill = true
					_banner("A gateway kills the Shadow's creatures\nShove them through it.", 4.0, "good")
			"surge":
				Weavefx.surge(self, e)
			"curtain":
				fx[e.fx] = Weavefx.curtain(self, e.pts, e.height)
			"curtain_end":
				if fx.has(e.fx):
					Weavefx.curtain_end(fx[e.fx]); fx.erase(e.fx)
			"drowned":
				Weavefx._once(Weavefx._particles(Color(0.7, 0.85, 1.0), 40, 0.7, 0.2, 3.0, -4.0, 120.0, false), self, e.pos)
			"gate_open":
				fx[e.id] = Weavefx.gate(self, e.a, e.b, e.get("flat_a", false), e.get("sky", 0.0))
				_open_window(fx[e.id])
			"shift":
				# Tel'aran'rhiod: simply somewhere else.
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					Dreamfx.shift(self, _ground(a.node.position), _ground(e.pos))
					a.target = e.pos
					if a.has("pred"): a.pred = e.pos; a.srv = e.pos
					if a.node is Walker:
						(a.node as Walker).teleport(e.pos, e.yaw)
					else:
						a.node.position = _ground(e.pos)
					var ch: Node = a.node.get_node_or_null("Chains")
					if ch: ch.queue_free()
					if e.id == session.my_id:
						# The eye goes with you: look the way you now face.
						face_yaw = e.yaw; cam_yaw = e.yaw + PI
			"deny":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Dreamfx.deny(self, actors[e.id].node, e.time)
			"denied":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Dreamfx.deny(self, actors[e.id].node, 0.3, true)
				if e.id == session.my_id:
					flash_t = 1.0; flash_text = "Denied"
				elif e.by == session.my_id:
					flash_t = 1.2; flash_text = "Your will broke on theirs"
					shake = maxf(shake, 0.5)
			"dream":
				if e.move == "dream_chains" and actors.has(e.on) and is_instance_valid(actors[e.on].node):
					Dreamfx.chain_wind(self, _ground(actors[e.on].node.position), e.time)
					if e.on == session.my_id:
						flash_t = 0.8; flash_text = "Chains: be gone, or Deny"
				elif e.move == "dream_pit":
					Dreamfx.pit_warn(self, _ground(e.pos), e.radius, e.time)
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Sfx.play(self, "hum", actors[e.id].node.position + Vector3(0, 1.4, 0), -6.0, 2.0)
			"chained":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Dreamfx.chains(actors[e.id].node, e.time)
					Sfx.play(self, "thud", actors[e.id].node.position + Vector3(0, 1.2, 0), 0.0, 1.6)
				if e.id == session.my_id:
					flash_t = 1.2; flash_text = "Chained: step away to be free"
			"dream_hit", "dream_end":
				Weavefx.spit(self, e.pos, Dreamfx.PALE)
			"pit_open":
				Sfx.play(self, "rumble", _ground(e.pos), 0.0, 1.3)
			"gate_pass":
				# Through the gateway: there, not walked there. My camera stays where it
				# was (seeing me through the window) until it crosses the plane too.
				if e.id == session.my_id and float(e.get("s", 0.0)) != 0.0:
					var to := _ground(e.pos)
					cam_shift = to - _ground(e.pos - (e.by as Vector3))
					cam_gate = {origin = _ground(e.origin), n = e.n, s = e.s}
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].has("pred"):
					actors[e.id].pred = e.pos; actors[e.id].srv = e.pos
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					var a: Dictionary = actors[e.id]
					a.target = e.pos
					if a.node is Walker:
						(a.node as Walker).teleport(e.pos, (a.node as Walker).heading)
					else:
						a.node.position = _ground(e.pos)
					Sfx.play(self, "whoosh", _ground(e.pos) + Vector3(0, 1.2, 0), -2.0, 0.7)
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
					flash_t = 0.6; flash_text = "+1"
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and actors[e.id].get("weapon", "") == e.weapon:
					Hero.show_held(actors[e.id].node, true)
				if actors.has(e.id):
					Sfx.play(self, "chime", _ground(actors[e.id].target) + Vector3(0, 1.0, 0), -8.0, 2.2)
			"stick":
				Sfx.play(self, "thud", e.pos, -4.0, 2.0)
				# It stands in what it struck: a body carries it, the ground shows
				# where it fell.
				if e.into != 0 and actors.has(e.into) and is_instance_valid(actors[e.into].node) and actors[e.into].kind == "enemy":
					Armsfx.stuck(actors[e.into].node, e.pos, e.get("dir", Vector3.FORWARD), e.weapon)
				else:
					Armsfx.puff(self, e.pos)
			"cast":
				if actors.has(e.id):
					# Each channeller has their own gesture for each weave.
					_end_form(actors[e.id])
					_play(actors[e.id], Hero.cast_clip(actors[e.id].get("name", ""), e.weave), true)
				if e.id == session.my_id:
					my_form = {}
				Weavefx.cast(self, e)
				# A weave mostly of Air blows outward from the one who made it.
				var wflows: Dictionary = Rules.weaves.get(e.weave, {}).get("flows", {})
				if actors.has(e.id) and is_instance_valid(actors[e.id].node) and int(wflows.get("air", 0)) * 2 >= wflows.values().reduce(func(x, y): return x + y, 0):
					Wind.gust(actors[e.id].node.position, 1.2)
			"blast":
				Weavefx.blast(self, e.pos, e.radius, e.weave)
				# Any blast shoves the air: grass, cloaks and banners lean away from it.
				Wind.gust(e.pos, clampf(float(e.radius) / 4.0, 0.5, 2.0))
			"gaze":
				# The first time in a while: say what it is doing to you.
				if e.id == session.my_id and frame - _gaze_said > 900:
					_gaze_said = frame
					_banner("The Eyeless gaze\nFear grips you while you meet its stare: weaving comes slowly. Look away.", 4.0, "shadow")
			"grabbed":
				if e.id == session.my_id:
					_banner("Seized!\n%s: twist free." % Keys.name(KEY_SPACE), 2.0, "warn")
			"broke_free":
				if e.id == session.my_id:
					banner.text = ""
			"blocked":
				# Steel on steel: the bandleader's guard turned it.
				Weavefx._once(Weavefx._particles(Color(1.0, 0.85, 0.5), 14, 0.3, 0.12, 4.0, 2.0, 70.0), self, e.pos)
				Sfx.play(self, "clang", e.pos, -6.0, 0.9)
			"guard_broken":
				if actors.has(e.id) and is_instance_valid(actors[e.id].node):
					Sfx.play(self, "clang", actors[e.id].node.position + Vector3(0, 1.3, 0), 0.0, 0.7)
			"wound":
				if e.id == session.my_id:
					my_wound = float(e.w)
			"prop_out":
				if not session.is_host and e.index < Map.trees().size():
					Map.trees()[e.index].out = true
				var pf := get_node_or_null("propfire_%d" % int(e.index))
				if pf:
					for c in pf.get_children():
						if c is GPUParticles3D or c is OmniLight3D:
							c.queue_free()
					Weavefx._once(Weavefx._particles(Color(0.45, 0.45, 0.45), 30, 2.0, 0.6, 1.2, 0.8, 40.0, false), self, pf.get_child(0).global_position + Vector3(0, 0.5, 0))
			"patch":
				_patch(e)
			"patch_end":
				if patches.has(e.id):
					var pn: Node3D = patches[e.id]
					patches.erase(e.id)
					if is_instance_valid(pn):
						var tw: Tween = pn.create_tween()
						tw.tween_property(pn, "scale", Vector3(1, 0.01, 1), 0.6)
						tw.tween_callback(pn.queue_free)
					if e.get("doused", false) or e.get("blown", false):
						Sfx.play(self, "whoosh", e.get("pos", pn.position if is_instance_valid(pn) else Vector3.ZERO), -10.0, 0.7)
			"wall_gone":
				if not session.is_host:
					Map.remove_wall(int(e.wid))
				var wn := get_node_or_null("wall_%d" % int(e.wid))
				if wn:
					# Thrown down: the stones scatter and sink.
					Weavefx.blast(self, wn.get_child(0).global_position if wn.get_child_count() > 0 else wn.position, 1.5, "heave_the_ground")
					wn.queue_free()
			"wall_up":
				if not session.is_host:
					Map.add_wall(e.wall)
				var wg := Node3D.new(); wg.name = "wall_%d" % int(e.wall.wid); add_child(wg)
				var sts := []
				for k in 5: sts.append(Scenery._mat(Color(0.25, 0.22, 0.19) * (0.65 + k * 0.17)))
				var rr := RandomNumberGenerator.new(); rr.seed = int(e.wall.wid)
				Scenery._wall(wg, e.wall, rr, sts, null, null)
				wg.scale.y = 0.05
				wg.create_tween().tween_property(wg, "scale:y", 1.0, 0.35)
			"fx_end":
				if fx.has(e.id):
					fx[e.id].queue_free(); fx.erase(e.id)
			"wave":
				_banner(("They come from every side" if Map.m.get("around", false) else "A wave comes down the pass") if e.left > 0 else "The last of them", 3.0)

var my_team := 0
var my_wound := 0.0            # share of my health held back by wounds until Healed
var _gaze_said := -9999
var in_battle := false

func _team_ring(rig: Node3D, team: int) -> void:
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new()
	tm.inner_radius = 0.48; tm.outer_radius = 0.56; tm.rings = 24; tm.ring_segments = 6
	ring.mesh = tm; ring.name = "TeamRing"
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.scale = Vector3(1, 0.15, 1); ring.position.y = 0.04
	rig.add_child(ring)
	ring.set_meta("team", team)
	_paint_rings()

## Friend or foe is judged from my side, which is known only once I am introduced.
func _paint_rings() -> void:
	for id in actors:
		var a: Dictionary = actors[id]
		if a.kind != "player" or not is_instance_valid(a.node):
			continue
		var r := a.node.get_node_or_null("TeamRing") as MeshInstance3D
		if r:
			var mine: bool = int(r.get_meta("team")) == my_team
			(r.material_override as StandardMaterial3D).albedo_color = Color(0.35, 0.6, 1.0, 1.0) if mine else Color(1.0, 0.3, 0.25, 1.0)

## Burning grass or a puddle on the ground (Sim._ignite, Sim._puddle).
## The struck body's flash (Weavefx.flash), left out of --clean pose shots: forms
## land several hits close together and nearly every frame caught one.
func _flash(who: Node3D, secs := 0.09) -> void:
	if not args.has("clean"):
		Weavefx.flash(self, who, secs)

func _patch(e: Dictionary) -> void:
	if e.kind == "fire":
		Scorch.burn(e.pos, float(e.r))
	if patches.has(e.id) and is_instance_valid(patches[e.id]):
		# A fire fed again: it spreads to the new size.
		var old: Node3D = patches[e.id]
		old.scale = Vector3.ONE * float(e.r) / float(old.get_meta("r", e.r))
		return
	var n := Node3D.new(); add_child(n); n.position = e.pos + Vector3(0, 0.03, 0)
	n.set_meta("r", float(e.r))
	var r: float = e.r
	if e.kind == "fire":
		# Low flames across the patch, a scorched disc under them, and some light.
		# Soot that thins out to nothing at the edge (a solid disc read as a black
		# hole cut in the ground); the burnt grass itself is Scorch's.
		var scorch := MeshInstance3D.new(); var pl := PlaneMesh.new(); pl.size = Vector2(r * 2.3, r * 2.3)
		scorch.mesh = pl
		var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.04, 0.03, 0.025); sm.roughness = 1.0
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 0.8)); gr.set_color(1, Color(1, 1, 1, 0.0)); gr.add_point(0.55, Color(1, 1, 1, 0.6))
		var gt := GradientTexture2D.new(); gt.gradient = gr; gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 64; gt.height = 64
		sm.albedo_texture = gt
		scorch.material_override = sm; n.add_child(scorch); scorch.rotation.y = randf() * TAU
		# Many small tongues, unevenly sized, so a patch reads as a sheet of fire and
		# not rows of candle flames.
		var f := Weavefx.flame(int(18 * r), 0.65, 1.2, Vector3(r * 0.65, 0.05, r * 0.65))
		var fpm := f.process_material as ParticleProcessMaterial
		fpm.scale_min = 0.35; fpm.scale_max = 1.6; fpm.spread = 22.0
		f.randomness = 0.6
		n.add_child(f); f.position.y = 0.1
		var smoke := Weavefx.smoke_column(int(4 * r) + 2, 1.5, e.pos, Vector3(r * 0.6, 0.1, r * 0.6))
		n.add_child(smoke); smoke.position.y = 0.9
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.45, 0.15); l.light_energy = 1.0 + r * 0.3; l.omni_range = r * 3.0 + 4.0
		n.add_child(l); l.position.y = 1.0
		Sfx.play(self, "rumble", n.position, -14.0, 1.6)
	else:
		# A puddle: dark, still and shining, a little wider than its wet edge.
		var disc := MeshInstance3D.new(); var c := CylinderMesh.new()
		c.top_radius = r; c.bottom_radius = r; c.height = 0.02; c.radial_segments = 24
		disc.mesh = c
		var pm2 := StandardMaterial3D.new(); pm2.albedo_color = Color(0.36, 0.43, 0.5, 0.5); pm2.roughness = 0.03; pm2.metallic = 0.25; pm2.metallic_specular = 1.0
		pm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = pm2; n.add_child(disc)
		disc.scale = Vector3(1.0, 1.0, randf_range(0.7, 1.0))
		disc.rotation.y = randf() * TAU
	patches[e.id] = n

## The weave someone was making has left their hands (or come to nothing).
func _end_form(a: Dictionary) -> void:
	a.forming = false
	if a.has("form_fx"):
		if is_instance_valid(a.form_fx):
			a.form_fx.queue_free()
		a.erase("form_fx")

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
		var w := Creature.instantiate(archers[id % archers.size()] if row.has("ranged") else variants[id % variants.size()])
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
	elif row.gen == "HOUND":
		var h := Hound.instantiate()
		add_child(h)
		h.teleport(pos, 0.0)
		actors[id] = {node = h, kind = "enemy", target = pos}
		if not told.has("hound"):
			told.hound = true
			_banner("Darkhounds: steel barely slows them. Burn them", 5.0)
	elif row.gen in ["DRAGHKAR", "DREADLORD"]:
		var w := Creature.instantiate(made[row.gen])
		add_child(w)
		w.teleport(pos, 0.0)
		actors[id] = {node = w, kind = "enemy", target = pos}
		if row.gen == "DRAGHKAR":
			var u: float = made[row.gen].spec.height / 1.8
			var wings := Wings.build(u)
			var at := BoneAttachment3D.new(); at.bone_name = "chest"
			w.sk.add_child(at)
			wings.position = Vector3(0, 0.2, -0.13) * u
			at.add_child(wings)
			actors[id].wings = wings
			actors[id].lift = 0.0
			_banner("A Draghkar: do not let it finish its song", 5.0)
		elif row.get("darkfriend", false):
			if not told.has("darkfriends"):
				told.darkfriends = true
		else:
			_banner("A Dreadlord: it channels. Shield it, or stay out of the marked ground", 5.0)
	else:
		var post := Scenery.practice_post(id)
		post.position = _ground(pos); post.rotation.y = PI + sin(id * 2.3) * 0.4
		add_child(post)
		actors[id] = {node = post, kind = "post", target = pos}

func _on_snapshot(s: Dictionary) -> void:
	team_meter = s.get("round", [])
	for e in s.ents:
		var id: int = e[0]
		if not actors.has(id):
			# Snapshots can outrun the event that introduces someone; wait for it.
			continue
		var a: Dictionary = actors[id]
		# My own body on a client is drawn where my keys have taken it (see
		# _predict), not where the host last said: the host's word only corrects it.
		a.srv = Vector3(e[1], 0, e[2])
		if id != session.my_id or session.is_host or not a.has("pred"):
			a.target = a.srv
			a.pred = a.srv
		a.yaw = e[3]
		_status(a, e[6])
		if args.has("ghost") and id == session.my_id and int(e[6]) & (16 | 32) != _ghost_st:
			_ghost_st = int(e[6]) & (16 | 32)
			print("GHOST %d status guard=%s duck=%s" % [frame, _ghost_st & 16 != 0, _ghost_st & 32 != 0])
		a.hp = e[4]
		if e.size() > 8: a.max_hp = e[8]
		if id == session.my_id:
			if e[4] < my_hp - 0.5:
				hurt_t = 1.0
			my_hp = e[4]; my_stamina = e[5]
			if e.size() > 7: my_will = e[7]
	for f in s.fx:
		# A gateway is drawn from its own event, which carries both its ends.
		if f[1] in ["gate", "surge", "curtain"]:
			continue
		if not fx.has(f[0]):
			fx[f[0]] = Weavefx.live(self, f[1], f[6])
		var n: Node3D = fx[f[0]]
		var was := n.position
		n.position = _ground(Vector3(f[2], 0, f[3])) + Vector3(0, 1.2, 0)
		if f[1] in ["projectile", "missile"]:
			n.position.y = f[5]
		if (f[1] == "missile" or n.has_meta("aimed")) and n.has_meta("flown") and was.distance_to(n.position) > 0.05:
			# Point along the flight; knives and stones tumble instead.
			n.basis = Basis.looking_at(n.position - was, Vector3.UP if absf((n.position - was).normalized().y) < 0.98 else Vector3.RIGHT)
		n.set_meta("flown", true)
		if n.has_method("set_r"):
			n.call("set_r", f[4], f[7] if f.size() > 7 else 0.0)

## Show what the sim says has happened to someone: 1 burning, 2 down, 4 stunned,
## 8 thrown.
func _status(a: Dictionary, bits: int) -> void:
	a.status = bits
	if not is_instance_valid(a.node):
		return
	# Away (only looking in through a doorway, or dropped): not in the fight, not
	# shown to the others.
	if a.kind == "player" and a.get("id", -1) != session.my_id:
		a.node.visible = not (bits & 1048576)
	# Gone into shadow: not there to be seen.
	# (A Draghkar out of reach is on the wing, and very much to be seen.)
	if a.kind == "enemy" and not a.get("dead", false) and not a.has("wings"):
		a.node.visible = not (bits & 8192)
	if a.get("node") == me:
		my_trance = bits & 32768 != 0
	# A weave abandoned (a roll, a blow taken) leaves the hands without a word.
	if a.has("form_fx") and not (bits & 2048) and clock - a.get("form_since", 0.0) > 0.3:
		_end_form(a)
		if a.get("node") == me:
			my_form = {}
	for pair in [["burn", 1], ["stun", 4], ["fester", 256], ["charge", 512], ["daze", 1024], ["wet", 4096]]:
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
				if a.has("wings"):
					# Up when it flies, face down along its flight with the wings out;
					# down and upright, wings trailing, when it lands.
					a.lift = move_toward(a.lift, 1.0 if a.get("aloft", false) else 0.0, dt * 1.6)
					var k: float = a.lift * a.lift * (3.0 - 2.0 * a.lift)
					w.sk.position.y = 5.0 * k
					w.sk.rotation.x = 1.15 * k
					(a.wings as Wings).spread = k
				if a.get("aloft", false):
					# On the wing it is carried where the sim has it; it does not walk there.
					w.vel = Vector3.ZERO
					w.pos += to * minf(8.0 * dt, 1.0)
					w.heading = lerp_angle(w.heading, a.yaw, minf(6.0 * dt, 1.0))
				elif st & 10:
					# Thrown or flat on the ground: it is carried, it does not walk there,
					# so it keeps facing the way it was and slides.
					w.vel = Vector3.ZERO
					w.pos += to * minf(10.0 * dt, 1.0)
				else:
					w.vel = (to * 3.0).limit_length(6.5) if to.length() > 0.25 else Vector3.ZERO
					# Catching up backwards (after being thrown): step back still facing the
					# way the sim says, rather than turning round to walk there.
					w.face_yaw = a.yaw if to.dot(Vector3(sin(a.yaw), 0, cos(a.yaw))) < -0.1 else 999.0
					# Standing still (an archer drawing, a blow coming): it faces where
					# the sim says, at you.
					if to.length() <= 0.25:
						w.heading = lerp_angle(w.heading, a.yaw, minf(8.0 * dt, 1.0))
			walkers.append(w)
		elif a.node is Hound:
			var h: Hound = a.node
			if not a.get("dead", false):
				var to: Vector3 = a.target - h.pos; to.y = 0.0
				var st: int = a.get("status", 0)
				h.downed = st & 2
				if st & 10:
					h.vel = Vector3.ZERO
					h.pos += to * minf(10.0 * dt, 1.0)
				else:
					# Fast enough to keep up with a spring, and it faces where the sim
					# says when it is not going anywhere.
					h.vel = (to * 5.0).limit_length(22.0) if to.length() > 0.2 else Vector3.ZERO
					if to.length() <= 0.2:
						h.heading = lerp_angle(h.heading, a.yaw, minf(8.0 * dt, 1.0))
		elif a.kind == "player":
			var n: Node3D = a.node
			if id == session.my_id and not _home.is_empty():
				continue     # walking home: the view moves this body now
			var tgt := _ground(a.target)
			var speed := n.position.distance_to(tgt) / maxf(dt, 0.001)
			n.position = n.position.lerp(tgt, minf(12.0 * dt, 1.0))
			if a.has("vault"):
				# Up and over: an arc on top of the ground.
				a.vault.t += dt
				var k: float = clampf(a.vault.t / maxf(a.vault.time, 0.01), 0.0, 1.0)
				n.position.y += sin(k * PI) * 0.6
				if k >= 1.0:
					a.erase("vault")
			if a.get("roll_until", 0.0) > clock:
				n.rotation.y = a.roll_yaw
			else:
				n.rotation.y = lerp_angle(n.rotation.y, a.yaw, minf(10.0 * dt, 1.0))
			a.busy = a.get("busy", 0.0) - dt
			a.speed = speed
			a.cloak_speed = lerpf(a.get("cloak_speed", 0.0), minf(speed, 9.0), minf(3.0 * dt, 1.0))
			Hero.cloak_motion(n, a.cloak_speed)
			if a.get("downed", false) or a.get("dead", false) or a.get("lying", false):
				continue     # lying where they fell (Death01 holds its last frame)
			_flourish(a, n, dt)
			if a.get("rearm", -1.0) > 0.0 and clock >= a.rearm:
				a.rearm = -1.0
				Hero.show_held(n, true)
			# A sling is whirled for as long as the throw takes.
			if a.get("weapon", "") == "sling":
				Hero.whirl(n, dt * 34.0 if clock < a.get("whirl_until", 0.0) else -1.0)
			if a.get("grip_until", 0.0) > 0.0 and clock >= a.grip_until:
				a.grip_until = 0.0
				Hero.grip(n, "")
			_bow_pose(a, n, id == session.my_id, dt)
			if a.get("forming", false) and a.busy <= 0.0:
				# Hands raised and working for as long as the weave is in them.
				_play(a, "Spell_Simple_Idle_Move" if speed > 0.6 else "Spell_Simple_Idle")
				continue
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
	_draw_heal_mark()
	for w in walkers:
		w.compute(dt)
		w.apply()

## A bow being drawn, or a crossbow levelled: the arms are posed for it over
## whatever the legs are doing, the string comes back, and an arrow is on it.
func _bow_pose(a: Dictionary, n: Node3D, mine: bool, dt: float) -> void:
	if not n.has_meta("pose"):
		return
	var pose: ArmPose = n.get_meta("pose")
	var w: Dictionary = Rules.weapons.get(a.get("weapon", ""), {})
	var shot: Dictionary = w.get("shot", {})
	var drawing: bool = a.get("status", 0) & 16384 and not shot.is_empty() and not shot.get("crank", false)
	if drawing:
		a.draw_t = a.get("draw_t", 0.0) + dt
	else:
		a.draw_t = 0.0
	var want := 0.0
	if drawing:
		pose.mode = "bow"
		pose.pull = clampf(a.draw_t / maxf(Rules.draw_time(profile, a.weapon), 0.1), 0.0, 1.0)
		want = 1.0
	elif shot.get("crank", false) and a.get("busy", 0.0) <= 0.0 and not (a.get("status", 0) & 64):
		# A crossbow is carried levelled; while it is being spanned it points at the ground.
		pose.mode = "crossbow"
		want = 1.0
		pose.pitch = lerpf(pose.pitch, -0.9 if a.get("span_until", 0.0) > clock else (cam_pitch * 0.6 if mine else 0.0), minf(dt * 8.0, 1.0))
	if drawing:
		pose.pitch = lerpf(pose.pitch, cam_pitch * 0.7 + 0.08 if mine else 0.08, minf(dt * 10.0, 1.0))
	pose.weight = move_toward(pose.weight, want, dt * (7.0 if want > 0.0 else 9.0))
	if pose.weight <= 0.01:
		pose.mode = ""
	if w.get("family", "") == "bow" and not shot.get("crank", false):
		Hero.bow(n, "draw" if pose.weight > 0.4 and pose.mode == "bow" else "", pose.pull if drawing else 0.0, drawing)
		if a.get("was_drawing", false) != drawing:
			a.was_drawing = drawing
			# The arrow is on the string, not in the hand, for as long as it is drawn.
			Hero.show_held(n, not drawing)
			if drawing:
				Sfx.play(self, "hum", n.position + Vector3(0, 1.4, 0), -12.0, 2.2)

## What makes a form look like itself: the whole body turns, or leaves the
## ground, on top of whatever clip the arms are playing; and a step back leans.
func _flourish(a: Dictionary, n: Node3D, dt: float) -> void:
	var body: Node3D = n.get_child(0) if n.get_child_count() > 0 else null
	if body == null:
		return
	if a.has("flourish"):
		var fl: Dictionary = a.flourish
		fl.t += dt
		var u := clampf(fl.t / maxf(fl.time, 0.05), 0.0, 1.0)
		body.rotation.y = fl.spin * TAU * (u * u * (3.0 - 2.0 * u))
		# Up, and down onto the blow as it lands.
		var up := clampf(fl.t / maxf(fl.land, 0.05), 0.0, 1.0)
		body.position.y = fl.leap * sin(up * PI) if fl.t < fl.land else 0.0
		if u >= 1.0:
			body.rotation.y = 0.0; body.position.y = 0.0
			a.erase("flourish")
	if a.has("lean"):
		a.lean.t += dt
		var u := clampf(a.lean.t / maxf(a.lean.time, 0.05), 0.0, 1.0)
		body.rotation.x = -0.3 * sin(u * PI)
		body.position.y = 0.12 * sin(u * PI)
		if u >= 1.0:
			body.rotation.x = 0.0; body.position.y = 0.0
			a.erase("lean")

## Who a Healing thrown now would reach: a ring at their feet, so it is never a guess.
var _heal_ring: MeshInstance3D
func _draw_heal_mark() -> void:
	var healing: bool = selected < known.size() and Rules.weaves.has(known[selected]) and Rules.weaves[known[selected]].kind == "heal" and me != null
	var who := 0
	if healing:
		var at := _aim_point()
		var reach: float = Rules.weaves[known[selected]].base.range
		var worst := 2.0
		for id in actors:
			var a: Dictionary = actors[id]
			if a.kind == "player" and id != session.my_id and not a.get("dead", false) and is_instance_valid(a.node) and Vector2(a.node.position.x - at.x, a.node.position.z - at.z).length() < reach:
				var share: float = a.get("hp", 100.0) / a.get("max_hp", 100.0)
				if share < worst:
					worst = share; who = id
	if who == 0:
		if _heal_ring: _heal_ring.visible = false
		return
	if _heal_ring == null:
		var t := TorusMesh.new(); t.inner_radius = 0.7; t.outer_radius = 0.82
		_heal_ring = Weavefx._mesh(t, Color(0.5, 1.0, 0.7, 0.9), 4.0)
		add_child(_heal_ring)
	_heal_ring.visible = true
	_heal_ring.position = actors[who].node.position + Vector3(0, 0.12 + 0.05 * sin(clock * 4.0), 0)

## Over the internet the host's answer to a key press is a round trip late. So a
## client moves its own body at once, by the same rule the host will apply, and
## leans back toward the host's position as it arrives: gently while moving, firmly
## when still, and all at once if the two disagree badly (a sidestep, a gateway, a
## throw).
func _predict(move: Vector3, dt: float) -> void:
	if session.is_host or not actors.has(session.my_id):
		return
	var a: Dictionary = actors[session.my_id]
	if not a.has("pred") or a.get("dead", false):
		return
	var st: int = a.get("status", 0)
	var slow := 1.0
	if a.get("busy", 0.0) > 0.0: slow = 0.5
	if st & 16: slow = minf(slow, Rules.TUNE.guard_slow)
	if st & 32: slow = minf(slow, Rules.TUNE.duck_slow)
	if st & (4 | 128): slow = 0.0
	elif st & 2: slow = minf(slow, 0.25)
	# As the host does: backing away is slower, more so while weaving or guarding.
	var back := -move.limit_length(1.0).dot(Vector3(sin(face_yaw), 0, cos(face_yaw)))
	if back > 0.3:
		slow *= lerpf(1.0, 0.55 if (st & (16 | 2048 | 16384)) else 0.7, clampf((back - 0.3) / 0.5, 0.0, 1.0))
	var pred: Vector3 = a.pred
	pred = Map.clamp_pos(Map.unblock(pred + move.limit_length(1.0) * Rules.run_speed(profile) * slow * dt, 0.45))
	var err: Vector3 = a.srv - pred
	if err.length() > 3.0 or st & (8 | 64):
		pred = a.srv
	else:
		pred += err * minf(dt * (1.5 if move.length() > 0.1 else 6.0), 1.0)
	a.pred = pred
	a.target = pred

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
	hud_layer = layer
	layer.visible = not previewing
	hud = Hud.new(); hud.g = self; layer.add_child(hud)
	# The end of a fight: a card in the middle, shown only then.
	result_card = Glyph.card(Color(Glyph.GOLD, 0.5)); layer.add_child(result_card)
	result_card.anchor_left = 0.5; result_card.anchor_right = 0.5; result_card.anchor_top = 0.42
	result_card.offset_left = -300; result_card.offset_right = 300
	result_card.visible = false
	banner = Label.new(); result_card.add_child(banner)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_theme_font_override("font", Glyph.serif())
	banner.add_theme_font_size_override("font_size", 22)
	banner.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	# --tour: what this station is for, on a card under the name at the top left.
	tour_card = Glyph.card(Color(Glyph.GOLD, 0.35)); layer.add_child(tour_card)
	tour_card.offset_left = 24; tour_card.offset_top = 118; tour_card.offset_right = 24 + 460
	tour_card.visible = false
	tour_label = Label.new(); tour_card.add_child(tour_label)
	tour_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tour_label.custom_minimum_size = Vector2(430, 0)
	tour_label.add_theme_font_size_override("font_size", 14)
	tour_label.add_theme_color_override("font_color", Color(0.86, 0.85, 0.82))

var result_card: PanelContainer
var pause_menu: Node
var tour_card: PanelContainer
var tour_label: Label
## A notice at the top right: the first line is its title, the rest its detail.
func _banner(text: String, secs: float, kind := "info") -> void:
	if previewing:
		return     # nothing to say about a fight not yet stepped into
	var lines := text.split("\n", false, 1)
	Toast.say(lines[0], lines[1] if lines.size() > 1 else "", kind, maxf(secs, 2.5))

func _draw_hud() -> void:
	var dt := get_process_delta_time()
	hurt_t = maxf(hurt_t - dt * 2.5, 0.0)
	flash_t = maxf(flash_t - dt * 1.4, 0.0)

## What the end of this kind of fight is called ("The line held" was said of the
## training yard and the duels too).
func _ending(success: bool) -> String:
	match Rules.activities.get(session.activity, {}).get("kind", ""):
		"training": return "The exercises are done" if success else "You fell"
		"spar": return "You won the duel" if success else "You lost the duel"
		"battle": return "Your side won" if success else "Their side won"
	if darkfriend:
		return "The Shadow is served" if success else "You were found out"
	return "The line held" if success else "You fell"

var _done := false
func _on_finished(success: bool, report: Array) -> void:
	_done = true
	Launch.report = report
	Launch.last_name = profile.name
	# A notice, not words across the screen; and the world does not stop: you walk on.
	if args.has("tour"):
		Toast.say("Done" if success else "You fell", "%s next   ·   %s again" % [Keys.name(KEY_N), Keys.name(KEY_R)], "good" if success else "warn", 12.0)
	else:
		Toast.say(_ending(success), "\n".join(report), "good" if success else "warn", 12.0)
	if not args.has("auto") or args.has("homewalk"):
		get_tree().create_timer(1.5).timeout.connect(_open_home)
	if args.has("auto"):
		print("GAME over success=%s %s" % [success, report])
