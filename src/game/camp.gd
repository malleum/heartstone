extends Node3D
## The camp: the hub every activity starts from and returns to. You walk it. Each
## activity is a stone doorway; walking through one begins it, and you come back
## out of the same one. Your character's sheet stays on the left, the weave tree
## opens over everything (T), and the server and friends are behind Esc.

const ORIGINS := {two_rivers = "Two Rivers", aiel = "Aiel", cairhien = "Cairhien", domani = "Arad Doman", borderlands = "Borderlands", tar_valon = "Tar Valon"}
const TALENT_PICKS := ["healing", "travelling", "cloud_dancing", "earth_singing", "delving", "illusion", "dreaming"]
## Doorway light by kind of activity: the yard is daylight, a holdout is fire,
## the World of Dreams is its own colour.
const DOOR_TINT := {training = Color(1.0, 0.85, 0.55), holdout = Color(1.0, 0.38, 0.12), spar = Color(0.5, 0.45, 1.0)}

var profile := {}
var model: Node3D
var side: VBoxContainer       # left column: who you are
var menu: PanelContainer      # Esc: server, friends, quit
var menu_box: VBoxContainer
var tree: WeaveTree
var prompt: Label             # what the doorway in front of you is
var hint: Label               # the controls, along the bottom
var make := {}                # creation form widgets
var creating := false
var online := {}              # the server this machine uses, if any (user://online.json)
var online_note := ""         # what the last exchange with the server said
const ONLINE := "user://online.json"
var cl := {}
var cam: Camera3D
var cam_yaw := deg_to_rad(-8.0)   # arriving, you look a little right of ahead: the sheet hides the left
var cam_pitch := -0.1
var pos := Vector3(0, 0, 3.0)  # where the character stands, on the ground plane
var face := PI - deg_to_rad(8.0)  # and which way they face (PI looks down -z, at the doorways)
var doors: Array = []          # {id, at, open, node, name, sub}
var _placed := false
var _frame := 0

func _ready() -> void:
	Rules.load_data()
	cl = Launch.cmdline()
	if cl.has("tour"):
		# --tour[=N]: straight into the stations (N starts at that one, counting from 1).
		Launch.tour = clampi(int(cl.tour) - 1, 0, Launch.TOUR.size() - 1)
		Launch.args = Launch.station()
		get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
		return
	if (cl.has("auto") or cl.has("activity") or cl.has("join")) and cl.get("ghost", "") != "camp":
		# Bots, renders and scripted sessions skip the camp.
		Launch.args = cl
		get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Map.use("open")
	World.build(self, -32.0, -26.0)
	Terrain.amp = 0.25
	add_child(Terrain.build_mesh(120.0, 1.0))
	Scenery.scatter(self)
	Scenery.fire(self, Vector3(6.0, Terrain.height(6.0, 3.0), 3.0))
	cam = Camera3D.new(); cam.fov = 60.0; add_child(cam)
	_ui()
	if FileAccess.file_exists(ONLINE):
		var o = JSON.parse_string(FileAccess.get_file_as_string(ONLINE))
		if o is Dictionary:
			online = o
	var names := _saved()
	# --who=Name picks a character, --show=tree|menu opens a panel, --stroll=N walks
	# to doorway N: all for looking at the camp in a render.
	if cl.has("new"):
		_creation(cl.new if Rules.CLASSES.has(cl.new) else "channeller")
	elif cl.has("who") and cl.who.to_lower() in names:
		_select(cl.who)
	elif Launch.last_name != "" and Launch.last_name.to_lower() in names:
		_select(Launch.last_name)
	elif names.size() > 0:
		_select(names[0])
	else:
		_creation()
	if cl.get("show", "") == "tree" and not profile.is_empty():
		_show_tree(true)
	elif cl.get("show", "") == "menu":
		_show_menu(true)

func _saved() -> Array:
	var out := []
	# A first run has no characters, and no folder for them yet.
	if not DirAccess.dir_exists_absolute(Profile.dir):
		return out
	for f in DirAccess.get_files_at(Profile.dir):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	return out

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, Terrain.height(p.x, p.z), p.z)

# --- layout ---------------------------------------------------------------------------

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var theme := Theme.new(); theme.default_font_size = 17
	var root := Control.new(); root.theme = theme; layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new(); title.text = "HEARTSTONE"; root.add_child(title)
	title.add_theme_font_override("font", Glyph.serif())
	title.add_theme_font_size_override("font_size", 44); title.position = Vector2(36, 16)
	title.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	title.add_theme_color_override("font_outline_color", Color.BLACK); title.add_theme_constant_override("outline_size", 8)
	side = _column(root, 0.0, 36, 430).get_meta("box")
	# What the nearest doorway is, low in the middle of the screen.
	prompt = Label.new(); root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -150; prompt.offset_bottom = -70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_override("font", Glyph.serif()); prompt.add_theme_font_size_override("font_size", 26)
	prompt.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	prompt.add_theme_color_override("font_outline_color", Color.BLACK); prompt.add_theme_constant_override("outline_size", 8)
	hint = Label.new(); root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -44; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "%s walk   ·   click the world to look around   ·   walk through a doorway to begin   ·   %s weaves or forms   ·   %s hide the sheet   ·   Esc menu" % [Keys.move(), Keys.name(KEY_T), Keys.name(KEY_H)]
	hint.add_theme_font_size_override("font_size", 15); hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	hint.add_theme_color_override("font_outline_color", Color.BLACK); hint.add_theme_constant_override("outline_size", 5)
	tree = WeaveTree.new(); root.add_child(tree); tree.visible = false
	tree.chosen.connect(func(id: String) -> void:
		# Changing your mind loses what was worked out so far.
		profile.study = id; profile.study_done = 0.0
		Profile.save(profile)
		_sheet())
	menu = _column(root, 0.5, -260, 260)
	menu_box = menu.get_meta("box")
	menu.offset_top = 70; menu.offset_bottom = -70
	menu.visible = false

func _column(root: Control, anchor: float, left: float, right: float) -> PanelContainer:
	var panel := PanelContainer.new(); root.add_child(panel)
	panel.anchor_left = anchor; panel.anchor_right = anchor; panel.anchor_top = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left = left; panel.offset_right = right; panel.offset_top = 90; panel.offset_bottom = -60
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.05, 0.08, 0.8); sb.set_corner_radius_all(6); sb.set_content_margin_all(16)
	sb.border_color = Color(Glyph.GOLD, 0.35); sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new(); panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new(); scroll.add_child(v)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	panel.set_meta("box", v)
	return panel

func _clear(v: Control) -> void:
	for c in v.get_children():
		c.queue_free()

func _text(v: Control, text: String, size := 17, col := Color(0.9, 0.9, 0.92)) -> Label:
	var l := Label.new(); l.text = text; v.add_child(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	if size >= 20:
		l.add_theme_font_override("font", Glyph.serif())
	return l

func _button(v: Control, text: String, on: Callable) -> Button:
	var b := Button.new(); b.text = text; v.add_child(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on)
	return b

func _stand(kind: String, style := {}) -> void:
	if model:
		model.queue_free()
	model = Hero.instantiate(kind, hash(profile.get("name", "")), style if not style.is_empty() else profile.get("style", {}))
	add_child(model)
	model.set_meta("kind", kind)
	(model.get_meta("anim") as AnimationPlayer).play("Idle")
	if creating:
		model.rotation.y = 0.35
		model.position = _ground(Vector3.ZERO)

# --- walking the camp -------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if cam == null:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if ev is InputEventMouseMotion and captured:
		cam_yaw -= ev.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.003, -1.1, 0.5)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not creating and not menu.visible and not tree.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode == KEY_ESCAPE:
			if tree.visible: _show_tree(false)
			elif captured: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else: _show_menu(not menu.visible)
		elif ev.physical_keycode == KEY_T and not creating and not profile.is_empty() and not menu.visible:
			_show_tree(not tree.visible)
		elif ev.physical_keycode == KEY_TAB:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif ev.physical_keycode == KEY_H and not creating and not tree.visible:
			# Put the sheet away to see the camp, and bring it back.
			side.get_parent().get_parent().visible = not side.get_parent().get_parent().visible

func _show_tree(on: bool) -> void:
	tree.profile = profile
	tree.visible = on
	side.get_parent().get_parent().visible = not on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_menu(on: bool) -> void:
	menu.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_menu_fill()

func _process(dt: float) -> void:
	if cam == null or model == null:
		return
	_frame += 1
	if cl.get("ghost", "") == "flow":
		_ghost_flow()
	elif cl.get("ghost", "") == "online":
		_ghost_online()
	elif cl.has("ghost"):
		Ghost.step(cl.ghost, _frame)
		if _frame % 30 == 0:
			print("GHOST %d camp tree=%s menu=%s sheet=%s pos=%s" % [_frame, tree.visible, menu.visible, side.get_parent().get_parent().visible, pos.snapped(Vector3.ONE * 0.1)])
	_poll_lobby(dt)
	if creating or profile.is_empty():
		# Making a character: they stand and are looked at.
		cam.position = cam.position.lerp(_ground(Vector3.ZERO) + Vector3(0.0, 1.35, 3.6), minf(6.0 * dt, 1.0))
		cam.look_at(_ground(Vector3.ZERO) + Vector3(0.0, 1.0, 0))
		prompt.text = ""
		hint.visible = false
		model.position = _ground(Vector3.ZERO); model.rotation.y = 0.35
		var idle: AnimationPlayer = model.get_meta("anim")
		if idle.current_animation != "Idle":
			idle.play("Idle", 0.15)
		return
	hint.visible = true
	var move := Vector3.ZERO
	if not tree.visible and not menu.visible and get_viewport().gui_get_focus_owner() == null:
		var v := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		v += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		move = (Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)).limit_length(1.0)
	if cl.has("stroll") and int(cl.stroll) < doors.size():
		var to: Vector3 = doors[int(cl.stroll)].at - pos
		move = to.normalized()
		cam_yaw = lerp_angle(cam_yaw, atan2(-move.x, -move.z), 2.0 * dt)
	var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
	if move.length() > 0.1:
		pos = Map.unblock(pos + move * (7.5 if sprint else 5.0) * dt, 0.45).limit_length(30.0)
		# The doorways' posts are stone: you go between them, not through them.
		for d in doors:
			var across := Vector3(d.at.z, 0, -d.at.x).normalized()
			for side_ in [-1.2, 1.2]:
				var post: Vector3 = d.at + across * side_
				var off := pos - post
				if off.length() < 0.8 and off.length() > 0.001:
					pos = post + off.normalized() * 0.8
		face = atan2(move.x, move.z)
	model.position = _ground(pos)
	model.rotation.y = lerp_angle(model.rotation.y, face, minf(10.0 * dt, 1.0))
	var ap: AnimationPlayer = model.get_meta("anim")
	var clip := ("Sprint" if sprint and ap.has_animation("Sprint") else "Jog_Fwd") if move.length() > 0.1 else "Idle"
	if ap.current_animation != clip:
		ap.play(clip, 0.15)
	# The same orbit camera as in a fight, a little further back to take in the doorways.
	var pivot := model.position + Vector3(0, 1.55, 0)
	var view := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)
	var want := pivot + view * Vector3(-1.1, 0.2, 4.6)   # camera to the left: the character stands clear of the sheet
	want.y = maxf(want.y, Terrain.height(want.x, want.z) + 0.35)
	cam.position = cam.position.lerp(want, minf(14.0 * dt, 1.0))
	cam.basis = view
	# Doorways: say what the nearest one is; step into an open one to go.
	var near := {}
	for d in doors:
		if pos.distance_to(d.at) < 5.5 and (near.is_empty() or pos.distance_to(d.at) < pos.distance_to(near.at)):
			near = d
	prompt.text = "" if near.is_empty() or tree.visible or menu.visible else "%s\n%s" % [near.name, near.sub]
	# On the server, a doorway joins whoever is already fighting in your room.
	if prompt.text != "" and online.get("play", false):
		for f in fights:
			if f.room == online.get("room", "").strip_edges().to_lower():
				prompt.text += "\n%s %s there now: any doorway joins them" % [", ".join(f.players), "is" if f.players.size() == 1 else "are"]
	if not near.is_empty() and near.open and pos.distance_to(near.at) < 0.9:
		_enter(near.id)

func _enter(id: String) -> void:
	set_process(false)
	prompt.text = Rules.activities[id].name + "…"
	# On the server, the first to arrive starts it and friends join the same fight.
	_go({activity = id, join = online.server, word = online.get("word", ""), room = online.get("room", "")} if online.get("play", false) and online.get("server", "") != "" else {activity = id})

## One doorway for every activity, in an arc ahead of where you arrive. Rebuilt
## whenever the character changes, since what is open depends on who you are.
func _doors() -> void:
	for d in doors:
		d.node.queue_free()
	doors = []
	var ids := []
	for id in Rules.activities:
		if not str(id).begins_with("_"):
			ids.append(id)
	var open := Rules.available(profile)
	for i in ids.size():
		var a: Dictionary = Rules.activities[ids[i]]
		# The sheet covers the left of the view, so the arc starts just left of
		# straight ahead and runs round to the right; more doorways carry on round.
		var ang := deg_to_rad(16.0 * i)
		var at := Vector3(sin(ang) * 17.0, 0, -cos(ang) * 17.0)
		var sub: String = a.blurb
		if not ids[i] in open:
			var need := []
			if a.requires.has("renown") and profile.renown < a.requires.renown: need.append("renown %d" % a.requires.renown)
			for dn in a.requires.get("done", []):
				if not profile.done.has(dn): need.append(Rules.activities[dn].name)
			sub = "Closed to you: needs " + ", ".join(need)
		var name_: String = a.name + ("  ✓" if profile.done.has(ids[i]) else "")
		var node := Scenery.doorway(self, _ground(at), -ang, DOOR_TINT.get(a.kind, Color.WHITE), ids[i] in open, name_, "" if ids[i] in open else "(closed)",
			{tarwins_gap = 1, wagon_ring = 2}.get(a.get("map", ""), 4 if a.kind == "spar" else 3))
		# Every other name sits higher, so long names do not run together.
		(node.get_child(node.get_child_count() - 1) as Node3D).position.y += 1.5 * (i % 2)
		doors.append({id = ids[i], at = at, open = ids[i] in open, node = node, name = name_, sub = sub})
		# Home from an activity: you step back out of its doorway, facing the camp.
		if not _placed and Launch.last_activity == ids[i]:
			pos = at * (1.0 - 2.6 / 17.0); face = atan2(-at.x, -at.z); cam_yaw = face
	_placed = true
	if model:
		model.rotation.y = face
	cam.position = _ground(pos) + Basis(Vector3.UP, cam_yaw) * Vector3(-1.1, 1.75, 4.6)

# --- an existing character --------------------------------------------------------------

## Exchange a character with the server's store: it keeps whichever copy has
## channelled longer and sends that back, so one character follows you between
## machines. Needs a server address and a passphrase; silent when neither is set.
func _sync(name_: String, local: Dictionary) -> void:
	if online.get("server", "") == "" or online.get("key", "") == "":
		return
	var old := get_tree().root.get_node_or_null("Session")
	if old:
		old.free()
	var s := Session.new()
	get_tree().root.add_child(s)
	# The lambdas below may run after the Session is gone (the time-out always
	# does), so they hold its id, not the node.
	var sid := s.get_instance_id()
	var finish := func(status: String, kept: Dictionary) -> void:
		var live := instance_from_id(sid) as Session
		if live == null:
			return
		multiplayer.multiplayer_peer = null
		live.queue_free()
		online_note = status if status != "" else "%s is kept on %s" % [kept.name, online.server]
		var newer: bool = not kept.is_empty() and (local.is_empty() or float(kept.seconds) > float(local.seconds))
		if newer:
			Profile.save(kept)
			online_note = "%s came from %s" % [kept.name, online.server]
		if newer or name_.to_lower() == profile.get("name", "").to_lower() or profile.is_empty():
			_select(kept.name if newer else profile.get("name", ""), false)
		_menu_fill()
	s.vaulted.connect(finish)
	get_tree().create_timer(6.0).timeout.connect(func() -> void: finish.call("no answer from " + online.server, {}))
	s.vault_sync(online.server, name_, online.key, local, online.get("word", ""))

func _select(name_: String, sync := true) -> void:
	if name_ == "" or Profile.load_profile(name_).is_empty():
		_creation()
		return
	creating = false
	make = {}
	profile = Profile.load_profile(name_)
	Launch.last_name = profile.name
	if sync:
		_sync(profile.name, profile)
	if model == null or model.get_meta("kind", "") != Hero.kind_for(profile) or model.get_meta("style", "") != str(profile.get("style", {})):
		_stand(Hero.kind_for(profile))
		model.set_meta("style", str(profile.get("style", {})))
	# A fighter stands in the camp with their weapon in hand.
	var held: String = profile.kit[0] if profile.get("cls", "channeller") != "channeller" and not profile.get("kit", []).is_empty() else ""
	Hero.arm(model, held)
	model.set_meta("held", held)
	_doors()
	tree.profile = profile
	_sheet()

## The left column: who you are and how you have grown.
func _sheet() -> void:
	_clear(side)
	_text(side, profile.name, 30)
	_text(side, "%s  ·  %s  ·  %s" % [profile.power.capitalize(), ORIGINS.get(profile.origin, profile.origin), "%d h %02d m channelling" % [int(profile.seconds / 3600.0), int(profile.seconds / 60.0) % 60]], 15, Color(0.7, 0.72, 0.78))
	var channels: bool = profile.get("cls", "channeller") == "channeller"
	if channels:
		_text(side, "Strength %s, potential %s\nFlows held at once: %d\nRenown %d" % [Rules.level_name(Rules.level_of(Rules.strength(profile))), Rules.level_name(Rules.level_of(profile.potential)), Rules.flow_capacity(profile), int(profile.renown)])
		var aff := ""
		for e in Rules.ELEMENTS:
			aff += "%s %d%%   " % [e.capitalize(), int(profile.affinity[e] * 100.0)]
		_text(side, aff, 15)
		if profile.talents.size() > 0:
			_text(side, "Talents: " + ", ".join(profile.talents.map(func(t: String) -> String: return t.capitalize())), 15)
		_text(side, "Weaves", 22)
		for id in profile.weaves:
			if Rules.weaves.has(id):
				_text(side, "%s   mastery %d" % [Rules.weaves[id].name, Rules.mastery_level(profile, id)], 15)
		var studying: String = profile.get("study", "")
		if studying != "" and Rules.weaves.has(studying):
			_text(side, "Working out %s: %d%%" % [Rules.weaves[studying].name, int(100.0 * profile.get("study_done", 0.0) / Rules.study_cost(profile, studying))], 15, Color(0.95, 0.85, 0.55))
		elif not Rules.study_options(profile).is_empty():
			_text(side, "You are not studying a weave. Choose one in the weave tree.", 15, Color(1.0, 0.7, 0.45))
		_button(side, "The weaves: what you know and what to study  (T)", func() -> void: _show_tree(true))
	else:
		_text(side, "%s\nMight %d   Quickness %d   Endurance %d\nHealth %d   Renown %d" % [Rules.cls(profile).name, Rules.stat(profile, "might"), Rules.stat(profile, "quickness"), Rules.stat(profile, "endurance"), int(Rules.max_hp(profile)), int(profile.renown)])
		for id in profile.get("forms", {}):
			if Rules.forms.has(id):
				_text(side, Rules.forms[id].name, 15)
		var learning: String = profile.get("study", "")
		if learning != "" and Rules.forms.has(learning):
			_text(side, "Working out %s: %d%%" % [Rules.forms[learning].name, int(100.0 * profile.get("study_done", 0.0) / Rules.study_cost(profile, learning))], 15, Color(0.95, 0.85, 0.55))
		_button(side, "The forms: what you know and what to study  (T)", func() -> void: _show_tree(true))
	# What is carried, and the skill of the hand that carries it.
	if not profile.get("kit", []).is_empty():
		_text(side, "Arms", 22)
		for w in profile.kit:
			var row: Dictionary = Rules.weapons[w]
			_text(side, "%s   %s skill %d" % [row.name, row.family, Rules.skill_level(profile, row.family)], 15)
	_button(side, "The armoury: change what you carry", _armoury)
	_button(side, "Appearance: dress, hair, build", _appearance)
	if Launch.report.size() > 0:
		_text(side, "Last time out", 22)
		_text(side, "\n".join(Launch.report), 15, Color(0.95, 0.85, 0.55))
	_text(side, "Characters", 22)
	for n in _saved():
		if n != profile.name.to_lower():
			_button(side, n.capitalize(), func() -> void: Launch.report = []; _select(n))
	_button(side, "New character…", _creation)
	_button(side, "Server, friends, quit  (Esc)", func() -> void: _show_menu(true))

## --ghost=flow: go through the camp's screens as a person would, pressing the
## real buttons (found by their text), and say what happened. For tools/ghost.sh.
func _press(box: Control, text: String) -> bool:
	for b in box.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(text) and not (b is OptionButton or b is CheckBox):
			(b as Button).pressed.emit()
			return true
	print("GHOST flow: no button '%s'" % text)
	return false

## --ghost=online: with a server on 127.0.0.1:24699 (word "tinker"), send a
## character to it, ask who is playing, and walk through a doorway into a fight
## hosted there. The settings are held in memory only: the player's own are not touched.
func _ghost_online() -> void:
	match _frame:
		10:
			Profile.dir = "user://ghost_profiles"
			var p := Profile.create({name = "Ghost Net", potential_pts = 8, affinity_pts = {fire = 4}})
			p.seconds = 77.0
			Profile.save(p)
			online = {server = "127.0.0.1:24699", word = "tinker", key = "ghostpass", room = "ghosts", play = true}
			_select("Ghost Net")
		90:
			print("GHOST online sync: %s" % online_note)
			_lobby_t = 0.0
		200:
			print("GHOST online lobby: %s" % _lobby_text().replace("\n", " | "))
			cl.stroll = "0"

func _ghost_flow() -> void:
	match _frame:
		10:
			Profile.dir = "user://ghost_profiles"
			for f in _saved():
				DirAccess.remove_absolute(Profile.dir + "/" + f + ".json")
			_creation("aiel")
		20:
			make.name.text = "Ghost Maiden"
			make.style.skin.select(2); make.style.hair_col.select(6); make.style.height.select(3)
			_creation_changed()
		30:
			_press(side, "Begin")
		40:
			print("GHOST flow created: %s cls=%s kit=%s style=%s doors=%d" % [profile.get("name", "-"), profile.get("cls", "-"), profile.get("kit", []), profile.get("style", {}), doors.size()])
			_press(side, "The armoury")
		50:
			var first: OptionButton = menu_box.find_children("*", "OptionButton", true, false)[0]
			first.select(first.item_count - 1); first.item_selected.emit(first.item_count - 1)
			_press(menu_box, "Take these")
		60:
			print("GHOST flow armoury: kit=%s menu=%s" % [profile.get("kit", []), menu.visible])
			_press(side, "Appearance")
		70:
			var dress: OptionButton = menu_box.find_children("*", "OptionButton", true, false)[0]
			dress.select(1); dress.item_selected.emit(1)
		80:
			_press(menu_box, "Keep this")
		90:
			print("GHOST flow appearance: look=%s style=%s" % [profile.get("look", "-"), profile.get("style", {})])
			_press(side, "The forms")
		100:
			var opts := Rules.study_options(profile)
			print("GHOST flow tree: visible=%s options=%s" % [tree.visible, opts])
			if not opts.is_empty():
				tree.chosen.emit(opts[0])
		110:
			print("GHOST flow study: %s" % profile.get("study", "-"))
			_show_tree(false)
			_show_menu(true)
		120:
			_press(menu_box, "Back to the camp")
		130:
			_creation("channeller", "Ghost Weaver", "saidin")
		140:
			_press(side, "Begin")
		150:
			print("GHOST flow second: %s power=%s starter=%s saved=%s" % [profile.get("name", "-"), profile.get("power", "-"), profile.get("starter", "-"), _saved()])
			# Walk into the first doorway, as feet would.
			cl.stroll = "0"

## Who is on the server now, asked every so often while the camp is open. One
## connection at a time: it waits if a character is being exchanged.
var fights: Array = []
var _lobby_t := 0.0
func _poll_lobby(dt: float) -> void:
	_lobby_t -= dt
	if _lobby_t > 0.0 or online.get("server", "") == "" or get_tree().root.get_node_or_null("Session") != null:
		return
	_lobby_t = 12.0
	var s := Session.new()
	get_tree().root.add_child(s)
	var sid := s.get_instance_id()
	var done := func(list: Array) -> void:
		var live := instance_from_id(sid) as Session
		if live == null:
			return
		multiplayer.multiplayer_peer = null
		live.queue_free()
		fights = list
		if menu.visible and not creating and menu_box.get_child_count() > 0 and (menu_box.get_child(0) as Label).text == "Server":
			_menu_fill()
	s.lobby.connect(done)
	get_tree().create_timer(5.0).timeout.connect(func() -> void: done.call(fights))
	s.ask_lobby(online.server, online.get("word", ""))

func _lobby_text() -> String:
	if online.get("server", "") == "":
		return ""
	if fights.is_empty():
		return "Nobody is fighting on %s just now." % online.server
	var lines := []
	for f in fights:
		lines.append("%s: %s, %d:%02d in%s" % [", ".join(f.players), Rules.activities.get(f.activity, {}).get("name", f.activity), int(f.t) / 60, int(f.t) % 60, "  (room '%s')" % f.room if f.room != "" else ""])
	return "On %s now:\n%s" % [online.server, "\n".join(lines)]

## Esc: the things that are not places. The server (where friends on different
## networks meet, and where characters are kept), joining a friend directly, quitting.
func _menu_fill() -> void:
	_clear(menu_box)
	_text(menu_box, "Server", 24)
	_text(menu_box, "A server lets friends on different networks play together with no VPN, and keeps your character so it follows you to any machine. The passphrase is yours alone and guards your character; the word is the one the server's owner gave everyone.", 14, Color(0.7, 0.72, 0.78))
	var fields := {}
	for f in [["server", "server address, e.g. joshammer.com"], ["word", "the server's word (if it has one)"], ["key", "your passphrase (four letters or more)"], ["room", "room: a name your group agrees on (blank: with everyone)"]]:
		var e := LineEdit.new(); e.placeholder_text = f[1]; e.text = online.get(f[0], ""); menu_box.add_child(e)
		e.secret = f[0] in ["word", "key"]
		fields[f[0]] = e
	var play := CheckBox.new(); play.text = "Doorways lead to the server (friends join the same fight)"; menu_box.add_child(play)
	play.button_pressed = online.get("play", false)
	var keep := func() -> void:
		for f in fields:
			online[f] = fields[f].text.strip_edges()
		online.play = play.button_pressed
		FileAccess.open(ONLINE, FileAccess.WRITE).store_string(JSON.stringify(online))
	play.toggled.connect(func(_on: bool) -> void: keep.call())
	_button(menu_box, "Save, and send this character to the server", func() -> void:
		keep.call(); online_note = "asking %s…" % online.server
		_sync(profile.get("name", ""), profile)
		_menu_fill())
	var want := LineEdit.new(); want.placeholder_text = "name of a character kept on the server"; menu_box.add_child(want)
	_button(menu_box, "Fetch that character", func() -> void:
		keep.call()
		var who: String = want.text.strip_edges()
		if who != "":
			online_note = "asking %s…" % online.server
			_sync(who, Profile.load_profile(who))
			_menu_fill())
	if online_note != "":
		_text(menu_box, online_note, 14, Color(0.95, 0.85, 0.55))
	_text(menu_box, _lobby_text(), 14, Color(0.75, 0.9, 0.8))
	_text(menu_box, "Friends, without a server", 24)
	_text(menu_box, "With the box above unticked, walking through a doorway hosts that activity on this machine: friends join you by address (UDP port 24690, or a VPN such as Tailscale).", 14, Color(0.7, 0.72, 0.78))
	var addr := LineEdit.new(); addr.placeholder_text = "friend's address"; menu_box.add_child(addr)
	_button(menu_box, "Join a friend", func() -> void:
		if addr.text.strip_edges() != "" and not profile.is_empty():
			_go({join = addr.text.strip_edges()}))
	_text(menu_box, "", 8)
	_button(menu_box, "Back to the camp  (Esc)", func() -> void: _show_menu(false))
	_button(menu_box, "Quit", get_tree().quit)

func _go(extra: Dictionary) -> void:
	var s := get_tree().root.get_node_or_null("Session")
	if s:
		multiplayer.multiplayer_peer = null
		s.free()
	Launch.args = extra.merged({name = profile.name})
	Launch.last_activity = extra.get("activity", "")
	Launch.report = []
	get_tree().change_scene_to_file("res://src/game/game.tscn")

# --- creation -----------------------------------------------------------------------------

func _option(v: Control, label: String, items: Dictionary) -> OptionButton:
	var row := HBoxContainer.new(); v.add_child(row)
	var l := _text(row, label); l.custom_minimum_size.x = 150; l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var o := OptionButton.new(); row.add_child(o); o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in items:
		o.add_item(items[k]); o.set_item_metadata(o.item_count - 1, k)
	o.item_selected.connect(func(_i: int) -> void: _creation_changed())
	return o

func _spin(v: Control, label: String, maxv: int, start: int) -> SpinBox:
	var row := HBoxContainer.new(); v.add_child(row)
	var l := _text(row, label); l.custom_minimum_size.x = 150; l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var s := SpinBox.new(); row.add_child(s); s.max_value = maxv; s.value = start
	s.value_changed.connect(func(_x: float) -> void: _creation_changed())
	return s

func _creation(cls_ := "channeller", name_ := "", power_ := "") -> void:
	creating = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	profile = {}
	for d in doors:
		d.node.queue_free()
	doors = []
	_clear(side)
	make = {cls_id = cls_}
	var fighter := cls_ != "channeller"
	_text(side, "A new %s" % Rules.CLASSES[cls_].name.to_lower(), 28)
	make.name = LineEdit.new(); make.name.placeholder_text = "Name"; make.name.text = name_; side.add_child(make.name)
	var classes := {}
	for c in Rules.CLASSES:
		classes[c] = Rules.CLASSES[c].name
	make.cls = _option(side, "Calling", classes)
	make.cls.select(Rules.CLASSES.keys().find(cls_))
	# A different calling is a different form: build it again, keeping the name.
	make.cls.item_selected.connect(func(_i: int) -> void: _creation.call_deferred(make.cls.get_selected_metadata(), make.name.text))
	make.power = _option(side, "The One Power" if not fighter else "Born", {saidar = "Saidar (women)", saidin = "Saidin (men)"} if not fighter else {saidar = "A woman", saidin = "A man"})
	if (cls_ == "warder" and power_ == "") or power_ == "saidin":
		make.power.select(1)
	make.origin = _option(side, "Origin", ORIGINS)
	make.look = _option(side, "Dress", {})
	# Saidar is women's and saidin men's, so the wardrobe follows the choice.
	# The hair, the beard and how much potential can be bought all follow it too,
	# so the form is built again.
	make.power.item_selected.connect(func(_i: int) -> void: _creation.call_deferred(make.cls_id, make.name.text, make.power.get_selected_metadata()))
	_fill_looks()
	make.style = _style_options(side, {}, make.power.get_selected_metadata() == "saidin")
	make.aff = {}; make.talents = {}; make.stats = {}; make.skills = {}; make.kit = []
	if not fighter:
		_text(side, "Twenty points, spent once. Potential is how strong you can ever become, on the Aes Sedai scale: 72 is the weakest, 1 the strongest woman, and ++6 to ++1 the men beyond her. Affinity is how readily each Power answers you. The two Powers of your half of the Source (Air and Water for saidar, Earth and Fire for saidin) cost half for their first three points. You begin with the simplest weave of your strongest Power. A Talent costs four; it does not unlock a weave, it makes you far better at it.", 14, Color(0.7, 0.72, 0.78))
		make.potential = _spin(side, "Potential", Profile.max_potential_pts(make.power.get_selected_metadata()), 8)
		for e in Rules.ELEMENTS:
			make.aff[e] = _spin(side, e.capitalize(), 6, 2 if e in ["air", "water"] else 0)
		_text(side, "Talents", 20)
		for t in TALENT_PICKS:
			var c := CheckBox.new(); c.text = t.capitalize(); side.add_child(c)
			c.toggled.connect(func(_on: bool) -> void: _creation_changed())
			make.talents[t] = c
		_text(side, "A channeller may carry one weapon and train it a little.", 14, Color(0.7, 0.72, 0.78))
		make.kit = [_weapon_option("Carries", "", true)]
	else:
		_text(side, "Twenty points, spent once. Might is how hard you hit, and what a longbow asks of you. Quickness shortens every blow and lengthens every sidestep. Endurance makes everything cost less breath and lets you take more. A point in a weapon is a level of skill with that family to begin with; the rest comes by using it.", 14, Color(0.7, 0.72, 0.78))
		for st in ["might", "quickness", "endurance"]:
			make.stats[st] = _spin(side, st.capitalize(), 8, 3)
		_text(side, "Skill at arms", 20)
		var first: String = Rules.weapons[Rules.CLASSES[cls_].kit[0]].family
		for f in Rules.FAMILIES:
			if f == "sword" and cls_ == "aiel":
				continue
			make.skills[f] = _spin(side, f.capitalize(), 6, 3 if f == first else 0)
		_text(side, "What you carry", 20)
		for i in int(Rules.CLASSES[cls_].carry):
			make.kit.append(_weapon_option(["In hand", "Second", "Third"][i], Rules.CLASSES[cls_].kit[i], false))
	make.left = _text(side, "", 18)
	make.go = _button(side, "Begin", _create)
	if _saved().size() > 0:
		_button(side, "Back", func() -> void: _select(_saved()[0]))
	_text(side, "Nothing resets: every watch, mission and spar pays into this one character. A character kept on a server can be fetched instead (Esc).", 14, Color(0.7, 0.72, 0.78))
	_creation_changed()

## The body's choices, as option rows: hair, its colour, skin, eyes, height, build,
## and a beard for men. Returns the widgets by name; _style_of reads them back.
func _style_options(parent: Control, style: Dictionary, man: bool) -> Dictionary:
	var out := {}
	var hairs := {"": "As the dress wears it"}
	for h in (["Hair_SimpleParted", "Hair_Buzzed"] if man else ["Hair_Long", "Hair_Buns"]):
		hairs[h] = {Hair_SimpleParted = "Parted", Hair_Buzzed = "Cropped", Hair_Long = "Long", Hair_Buns = "Bound up"}[h]
	hairs["none"] = "Shaved"
	out.hair = _option(parent, "Hair", hairs)
	out.hair.select(maxi(hairs.keys().find(style.get("hair", "")), 0))
	for row in [["hair_col", "Hair colour", Hero.HAIR_COLOURS, -1], ["skin", "Skin", Hero.SKINS, 0], ["eyes", "Eyes", Hero.EYES, 0], ["height", "Height", Hero.HEIGHTS, 2], ["build", "Build", Hero.BUILDS, 2]]:
		var items := {}
		if row[3] < 0:
			items[-1] = "By chance"
		for i in row[2].size():
			items[i] = row[2][i][0]
		out[row[0]] = _option(parent, row[1], items)
		out[row[0]].select(maxi(items.keys().find(int(style.get(row[0], row[3]))), 0))
	if man:
		out.beard = _option(parent, "Beard", {0: "Clean-shaven", 1: "Bearded"})
		out.beard.select(1 if style.get("beard", false) else 0)
	return out

func _style_of(w: Dictionary) -> Dictionary:
	var st := {}
	if w.hair.get_selected_metadata() != "":
		st.hair = w.hair.get_selected_metadata()
	if int(w.hair_col.get_selected_metadata()) >= 0:
		st.hair_col = int(w.hair_col.get_selected_metadata())
	for k in ["skin", "eyes", "height", "build"]:
		st[k] = int(w[k].get_selected_metadata())
	if w.has("beard"):
		st.beard = int(w.beard.get_selected_metadata()) == 1
	return st

## Change how an existing character looks. It is only looks: nothing is lost.
func _appearance() -> void:
	menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear(menu_box)
	_text(menu_box, "Appearance", 24)
	var man: bool = profile.power == "saidin"
	var all := Hero.looks()
	var dresses := {}
	for id in all:
		if all[id].sex == ("m" if man else "f"):
			dresses[id] = all[id].label
	var dress := _option(menu_box, "Dress", dresses)
	dress.select(maxi(dresses.keys().find(Hero.kind_for(profile)), 0))
	var w := _style_options(menu_box, profile.get("style", {}), man)
	var show := func(_i := 0) -> void:
		_stand(dress.get_selected_metadata(), _style_of(w))
		var held: String = profile.kit[0] if profile.get("cls", "channeller") != "channeller" and not profile.get("kit", []).is_empty() else ""
		Hero.arm(model, held)
	dress.item_selected.connect(show)
	for k in w:
		w[k].item_selected.connect(show)
	_button(menu_box, "Keep this", func() -> void:
		profile.look = dress.get_selected_metadata()
		profile.style = _style_of(w)
		Profile.save(profile)
		menu.visible = false
		_select(profile.name))
	_button(menu_box, "Back to the camp  (Esc)", func() -> void:
		menu.visible = false
		_select(profile.name, false))

## The weapons this calling may choose from; `none` adds an empty first choice.
func _weapon_option(label: String, start: String, none: bool, parent: Control = null, cls_id := "") -> OptionButton:
	var items := {}
	if none:
		items[""] = "Nothing"
	var probe := {cls = cls_id if cls_id != "" else make.cls_id, stats = {might = 8}}
	for w in Rules.weapons:
		if Rules.wield_block(probe, w) == "" and not Rules.weapons[w].get("earned", false) and w != "hands":
			items[w] = "%s  (%s)" % [Rules.weapons[w].name, Rules.weapons[w].family]
	var o := _option(parent if parent else side, label, items)
	o.select(maxi(items.keys().find(start), 0))
	return o

## The armoury: change what this character carries. Skill stays with the hand,
## so a new weapon of a family you know is not a new start.
func _armoury() -> void:
	menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear(menu_box)
	_text(menu_box, "The armoury", 24)
	var c: String = profile.get("cls", "channeller")
	_text(menu_box, "%s carries %d. Your skill is with a family of weapons, not one of them, so changing costs nothing but habit." % ["A " + Rules.CLASSES[c].name.to_lower(), int(Rules.CLASSES[c].carry)], 14, Color(0.7, 0.72, 0.78))
	var picks := []
	for i in int(Rules.CLASSES[c].carry):
		picks.append(_weapon_option(["In hand", "Second", "Third"][i], profile.kit[i] if i < profile.kit.size() else "", true, menu_box, c))
	var note := _text(menu_box, "", 14, Color(1.0, 0.7, 0.45))
	_button(menu_box, "Take these", func() -> void:
		var kit := []
		for o in picks:
			var w: String = o.get_selected_metadata()
			if w != "" and not kit.has(w):
				var why := Rules.wield_block(profile, w)
				if why != "":
					note.text = "%s: %s" % [Rules.weapons[w].name, why]
					return
				kit.append(w)
		if kit.is_empty() and c != "channeller":
			note.text = "You cannot go unarmed."
			return
		profile.kit = kit
		Profile.save(profile)
		menu.visible = false
		_select(profile.name))
	_button(menu_box, "Back to the camp  (Esc)", func() -> void: _show_menu(false))

func _fill_looks() -> void:
	var sex := "f" if make.power.get_selected_metadata() == "saidar" else "m"
	make.look.clear()
	var all := Hero.looks()
	# The dress that suits the calling comes first.
	var first: String = {warder = "warder", aiel = "aiel_" + sex, hunter = "hunter_f" if sex == "f" else "farmer_cloak"}.get(make.cls_id, "")
	var ids := all.keys()
	if ids.has(first):
		ids.erase(first); ids.push_front(first)
	for id in ids:
		if all[id].sex == sex:
			make.look.add_item(all[id].label); make.look.set_item_metadata(make.look.item_count - 1, id)
	make.look.select(0)

func _points_left() -> float:
	var spent := 0.0
	if make.has("potential"):
		spent += make.potential.value
	for e in make.aff:
		spent += Profile.affinity_cost(make.power.get_selected_metadata(), e, int(make.aff[e].value))
	for t in make.talents:
		if make.talents[t].button_pressed:
			spent += 4.0
	for st in make.stats:
		spent += make.stats[st].value
	for f in make.skills:
		spent += make.skills[f].value
	return Profile.CREATION_POINTS - spent

func _creation_changed() -> void:
	if not make.has("go"):
		return
	var left := _points_left()
	make.left.text = ("Potential %s   ·   " % Rules.level_name(Profile.potential_level(make.power.get_selected_metadata(), int(make.potential.value))) if make.has("potential") else "") + "points left: %s" % String.num(left, 1)
	# A longbow needs might: say so before the character is made without it.
	var might: float = make.stats.might.value if make.stats.has("might") else 0.0
	for o in make.kit:
		var w: String = o.get_selected_metadata()
		if w != "" and might < Rules.weapons[w].get("might", 0):
			make.left.text += "\n%s needs might %d" % [Rules.weapons[w].name, Rules.weapons[w].might]
	make.left.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if left < 0 else Color(0.9, 0.9, 0.92))
	make.go.disabled = left < 0
	var kind: String = make.look.get_selected_metadata()
	var held: String = make.kit[0].get_selected_metadata() if not make.kit.is_empty() else ""
	var st := _style_of(make.style) if make.has("style") else {}
	if model == null or model.get_meta("kind", "") != kind or model.get_meta("style", "") != str(st):
		_stand(kind, st)
		model.set_meta("style", str(st))
		model.set_meta("held", "-")
	if model.get_meta("held", "-") != held:
		Hero.arm(model, held)
		model.set_meta("held", held)

func _create() -> void:
	var name_: String = make.name.text.strip_edges()
	if name_ == "" or _points_left() < 0:
		make.left.text = "A name is needed." if name_ == "" else make.left.text
		return
	var aff := {}
	for e in make.aff:
		aff[e] = int(make.aff[e].value)
	var talents := []
	for t in make.talents:
		if make.talents[t].button_pressed:
			talents.append(t)
	var stats := {}
	for st in make.stats:
		stats[st] = int(make.stats[st].value)
	var skills := {}
	for f in make.skills:
		skills[f] = int(make.skills[f].value)
	var kit := []
	for o in make.kit:
		if o.get_selected_metadata() != "" and not kit.has(o.get_selected_metadata()):
			kit.append(o.get_selected_metadata())
	var power: String = make.power.get_selected_metadata()
	var opts := {name = name_, cls = make.cls_id, power = power, sex = "f" if power == "saidar" else "m", origin = make.origin.get_selected_metadata(),
		look = make.look.get_selected_metadata(), affinity_pts = aff, talents = talents, stat_pts = stats, skill_pts = skills, kit = kit, style = _style_of(make.style)}
	if make.has("potential"):
		opts.potential_pts = int(make.potential.value)
	var p := Profile.create(opts)
	Profile.save(p)
	Launch.report = []
	_select(name_)
