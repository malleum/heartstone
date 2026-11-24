extends Node3D
## The camp: the hub every activity starts from and returns to. You walk it. Each
## activity is a stone doorway; walking through one begins it, and you come back
## out of the same one. Your character's sheet stays on the left, the weave tree
## opens over everything (T), and the server and friends are behind Esc.

const ORIGINS := {two_rivers = "Two Rivers", aiel = "Aiel", cairhien = "Cairhien", domani = "Arad Doman", borderlands = "Borderlands", tar_valon = "Tar Valon"}
const TALENT_PICKS := ["healing", "travelling", "cloud_dancing", "earth_singing", "delving", "illusion", "dreaming"]
## Doorway light by kind of activity: the yard is daylight, a holdout is fire,
## the World of Dreams is its own colour.
const GAME_SCENE := "res://src/game/game.tscn"
## Each doorway glows its own colour, so they can be told apart from across the
## camp (nothing is written on the world): by id first, then by kind.
const DOOR_TINT := {training = Color(1.0, 0.85, 0.55), holdout = Color(1.0, 0.38, 0.12), spar = Color(0.5, 0.45, 1.0), battle = Color(0.85, 0.2, 0.25),
	darkfriend_door = Color(0.45, 0.85, 0.3), endless_door = Color(0.3, 0.7, 1.0)}

var profile := {}
var model: Node3D
var side: VBoxContainer       # left column: who you are
var mini: PanelContainer      # its faded corner while it is put away
var _vel := Vector3.ZERO      # walking, eased
var yard: CampYard            # the practice posts beside the doorways, with a sim of your own
var yard_slot := 0            # which thing on the bar the yard's clicks use
var _yard_told := false
var mini_name: Label
var mini_ren: Label
var mini_new: Label
var menu: PanelContainer      # Esc: server, friends, quit
var menu_box: VBoxContainer
var tree: WeaveTree
var _near_id := ""            # the doorway last announced, so it is said once per approach
static var _hinted := false   # the walking keys have been shown this run
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
	Perf.setup()
	Rules.load_data()
	cl = Launch.cmdline()
	Launch.use_profile_dir()
	returning = Launch.return_preview
	Launch.return_preview = false
	# A newer release already downloaded: start that instead.
	if not returning and Updater.boot(get_tree()):
		return
	if cl.has("tour") and not returning:
		# --tour[=N]: straight into the stations (N starts at that one, counting from 1).
		Launch.tour = clampi(int(cl.tour) - 1, 0, Launch.TOUR.size() - 1)
		Launch.args = Launch.station()
		get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
		return
	if (cl.has("auto") or cl.has("activity") or cl.has("join")) and cl.get("ghost", "") != "camp" and not returning:
		# Bots, renders and scripted sessions skip the camp.
		Launch.args = cl
		get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
		return
	# Start making the fight's Shadowspawn now, on other threads, so walking
	# through a doorway does not wait for them.
	Cast.begin()
	Settings.load_and_apply()
	# And the fight scene itself, read from disk on another thread.
	if not returning:
		ResourceLoader.load_threaded_request(GAME_SCENE)
	# Look for a newer release; if one downloads while nobody has gone through a
	# doorway yet, restart into it straight away.
	Updater.check(self, func() -> bool: return _pre.is_empty() and get_tree().current_scene == self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Map.use("open", "camp")
	Wind.setup("camp", self)
	Scorch.setup(100.0)
	World.build(self, -32.0, -26.0)
	Terrain.amp = 0.25
	add_child(await Terrain.build_mesh(120.0, 1.0))
	_ctx = Map.state()
	await Scenery.scatter(self)
	Scenery.fire(self, Vector3(6.0, Terrain.height(6.0, 3.0), 3.0))
	Scenery.camp(self)
	if cl.has("hitboxes"):
		Hitboxes.draw(self)
	# --camyaw=deg: look another way in a render (and --show=none hides the sheet).
	if Launch.cmdline().has("camyaw"):
		cam_yaw = deg_to_rad(float(Launch.cmdline().camyaw))
	# --campitch=deg (negative looks down) and --camdist=m: a view from higher up.
	if Launch.cmdline().has("campitch"):
		cam_pitch = deg_to_rad(float(Launch.cmdline().campitch))
	# --campos=x,z: stand there (pictures of a corner of the camp).
	if Launch.cmdline().has("campos"):
		var xz: PackedStringArray = String(Launch.cmdline().campos).split(",")
		pos = Vector3(float(xz[0]), 0, float(xz[1]))
	cam = Camera3D.new(); cam.fov = 60.0; add_child(cam)
	_ui()
	if returning:
		side.get_parent().get_parent().visible = false
	if FileAccess.file_exists(ONLINE):
		var o = JSON.parse_string(FileAccess.get_file_as_string(ONLINE))
		if o is Dictionary:
			online = o
	# --word=: the server's word for this run only (tests against a local server).
	if cl.has("word"):
		online = online.duplicate(); online.word = cl.word
	# Characters from before rounds are cleared (the user asked for a clean start).
	var gone := Profile.purge_old()
	if gone > 0:
		Toast.say("A fresh start", "%d old character%s cleared: make a new one for the rounds." % [gone, "" if gone == 1 else "s"], "info", 8.0)
	var names := _saved()
	# --who=Name for renders: make that character if it is not there (a warder).
	if cl.has("who") and not cl.who.to_lower() in names:
		Profile.save(Profile.create({name = cl.who, cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}}))
		names = _saved()
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
		if cl.has("page"): tree.page = cl.page   # --page=forms|weapons for a fighter's picture
	elif cl.get("show", "") == "menu":
		_show_menu(true)
	elif cl.get("show", "") == "loadout":
		_loadout()
	elif cl.get("show", "") == "none":
		side.get_parent().get_parent().visible = false
	# Home from a fight: the doorway's light is still up; let the camp through
	# once it has been drawn.
	_after(0.15, func() -> void: Veil.lift(0.8))

## Call `fn` in `secs`, unless the camp is gone by then (a scene tree timer would
## still fire, into a freed camp: "call on a null instance").
func _after(secs: float, fn: Callable) -> void:
	var tm := Timer.new(); tm.one_shot = true; tm.wait_time = secs
	add_child(tm)
	tm.timeout.connect(func() -> void:
		tm.queue_free()
		fn.call())
	tm.start()

func _exit_tree() -> void:
	_close_link()
	# Quitting while the cast is still being made: let it finish rather than leave
	# worker threads behind.
	if get_tree().current_scene == null or get_tree().current_scene == self:
		Cast.wait()

func _saved() -> Array:
	var out := []
	# A first run has no characters, and no folder for them yet.
	if not DirAccess.dir_exists_absolute(Profile.dir):
		return out
	for f in DirAccess.get_files_at(Profile.dir):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	return out

var _ctx := {}   # the camp's own ground and walls (Map.state), kept while a doorway's world is built

## The camp's ground and walls, whatever world a doorway is building meanwhile.
func _height(x: float, z: float) -> float:
	if _ctx.is_empty() or _pre.is_empty():
		return Terrain.height(x, z)
	var other := Map.state()
	Map.set_state(_ctx)
	var h := Terrain.height(x, z)
	Map.set_state(other)
	return h

func _unblock(p: Vector3) -> Vector3:
	if _ctx.is_empty() or _pre.is_empty():
		return Map.unblock(p, 0.45)
	var other := Map.state()
	Map.set_state(_ctx)
	var out := Map.unblock(p, 0.45)
	Map.set_state(other)
	return out

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, _height(p.x, p.z), p.z)

# --- layout ---------------------------------------------------------------------------

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var theme := Theme.new(); theme.default_font_size = 16
	var root := Control.new(); root.theme = theme; layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nothing is written across the world itself: who you are is on the left, and
	# anything else arrives as a notice at the top right (Toast).
	var side_panel := _column(root, 0.0, 24, 384)
	side = side_panel.get_meta("box")
	# The sheet is only as tall as what is on it (scrolling once that is more than
	# the screen), so the camp shows below a short one.
	var fit := func() -> void:
		var want: float = side.get_combined_minimum_size().y + side_panel.get_theme_stylebox("panel").get_minimum_size().y
		side_panel.anchor_bottom = 0.0
		side_panel.offset_bottom = side_panel.offset_top + minf(want, root.size.y - side_panel.offset_top - 24.0)
	side.minimum_size_changed.connect(fit)
	root.resized.connect(fit)
	tree = WeaveTree.new(); root.add_child(tree); tree.visible = false
	tree.bar_edit = true
	tree.bar_changed.connect(func() -> void:
		if not Launch.dev():
			Profile.save(profile))
	tree.chosen.connect(func(id: String) -> void:
		# Changing your mind loses what was worked out so far.
		profile.study = id; profile.study_done = 0.0
		Profile.save(profile)
		_sheet())
	# The sheet put away (H): a small faded corner of it stays, with who you are and
	# a mark when something is new since you last looked (click it for the sheet).
	mini = Glyph.card(Color(Glyph.GOLD, 0.2), 0.55); root.add_child(mini)
	mini.anchor_left = 0.0; mini.anchor_top = 0.0; mini.offset_left = 18; mini.offset_top = 18
	mini.modulate.a = 0.78
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	var mv := VBoxContainer.new(); mini.add_child(mv)
	mv.add_theme_constant_override("separation", 0)
	mini_name = _text(mv, "", 20); mini_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	mini_ren = _text(mv, "", 13, Color(0.75, 0.75, 0.78))
	mini_new = _text(mv, "●  New since you last looked", 12, Glyph.GOLD)
	for l in [mini_ren, mini_new]:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	mini.custom_minimum_size.x = 210
	mini.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			side.get_parent().get_parent().visible = true)
	mini.visible = false
	menu = _column(root, 0.5, -240, 240)
	menu_box = menu.get_meta("box")
	menu.offset_top = 70; menu.offset_bottom = -70
	menu.visible = false

func _column(root: Control, anchor: float, left: float, right: float) -> PanelContainer:
	var panel := Glyph.card(Color(Glyph.GOLD, 0.28), 0.84); root.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = anchor; panel.anchor_right = anchor; panel.anchor_top = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left = left; panel.offset_right = right; panel.offset_top = 24; panel.offset_bottom = -24
	var scroll := ScrollContainer.new(); panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new(); scroll.add_child(v)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
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

## A row you press: quiet text with a gold edge that lights on hover.
func _button(v: Control, text: String, on: Callable) -> Button:
	var b := Button.new(); b.text = text; v.add_child(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.03) if st == "normal" else (Color(Glyph.GOLD, 0.12) if st == "hover" else Color(Glyph.GOLD, 0.2))
		sb.border_color = Color(Glyph.GOLD, 0.25 if st == "normal" else 0.7); sb.border_width_left = 2
		sb.content_margin_left = 10; sb.content_margin_right = 8; sb.content_margin_top = 5; sb.content_margin_bottom = 6
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.88, 0.87, 0.84))
	b.add_theme_color_override("font_hover_color", Color(0.98, 0.94, 0.85))
	b.pressed.connect(on)
	return b

## A heading for a part of the sheet: small gold capitals over a hairline.
func _section(v: Control, title: String) -> void:
	var gap := Control.new(); gap.custom_minimum_size.y = 8; v.add_child(gap)
	var l := Label.new(); l.text = title.to_upper(); v.add_child(l)
	l.add_theme_font_size_override("font_size", 12); l.add_theme_color_override("font_color", Color(Glyph.GOLD, 0.85))
	l.add_theme_constant_override("line_spacing", 0)
	var rule := ColorRect.new(); rule.color = Color(Glyph.GOLD, 0.22); rule.custom_minimum_size.y = 1; v.add_child(rule)

## A name and its value on one line, the value to the right.
func _row(v: Control, label: String, value: String, col := Color(0.9, 0.89, 0.86)) -> void:
	var h := HBoxContainer.new(); v.add_child(h)
	var a := Label.new(); a.text = label; h.add_child(a); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 15); a.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	var b := Label.new(); b.text = value; h.add_child(b)
	b.add_theme_font_size_override("font_size", 15); b.add_theme_color_override("font_color", col)

## A row of pips: how many of `of` are filled, in a colour.
func _pips(v: Control, label: String, n: int, of: int, col: Color) -> void:
	var h := HBoxContainer.new(); v.add_child(h)
	var a := Label.new(); a.text = label; h.add_child(a); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.add_theme_font_size_override("font_size", 15); a.add_theme_color_override("font_color", Color(0.72, 0.72, 0.76))
	for k in of:
		var pip := ColorRect.new(); pip.custom_minimum_size = Vector2(14, 8); h.add_child(pip)
		pip.color = col if k < n else Color(1, 1, 1, 0.08)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
	# Waiting for a key to bind (the Keys panel): the next key pressed is it.
	if (_binding != -1 or _binding_dream >= 0) and ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode != KEY_ESCAPE:
			if _binding_dream >= 0:
				# The dream bar's keys are kept with the character (profile.dream_slot_keys).
				var keys: Array = Dream.keys_of(profile)
				keys[_binding_dream] = OS.get_keycode_string(ev.physical_keycode)
				profile.dream_slot_keys = keys
				Profile.save(profile)
			else:
				Keys.bind(_binding as Key, ev.physical_keycode)
		_binding = -1; _binding_dream = -1
		get_viewport().set_input_as_handled()
		_keys_panel()
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if ev is InputEventMouseMotion and captured:
		cam_yaw -= ev.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - ev.relative.y * 0.003, -1.1, 0.5)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and captured and _in_yard():
		_yard_use()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and captured and _in_yard():
		# A parry, as in a fight (only a blow can be parried; the posts strike nothing).
		yard.sim.set_guard(yard.me, ev.pressed)
		if ev.pressed and is_instance_valid(model):
			var apg: AnimationPlayer = model.get_meta("anim")
			for clip in ["Sword_Block", "Block", "Sword_Defend"]:
				if apg.has_animation(clip):
					apg.play(clip, 0.08); set_meta("busy_until", Time.get_ticks_msec() / 1000.0 + 0.5); break
	elif ev is InputEventKey and ev.pressed and not ev.echo and _in_yard() and ev.physical_keycode in [Keys.k(KEY_Z), Keys.k(KEY_X), Keys.k(KEY_R)]:
		_yard_form([Keys.k(KEY_Z), Keys.k(KEY_X), Keys.k(KEY_R)].find(ev.physical_keycode))
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not creating and not menu.visible and not tree.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventKey and ev.pressed and not ev.echo and _in_yard() and ev.physical_keycode == Keys.k(KEY_SPACE):
		var v := Vector2(float(Keys.down(KEY_D)) - float(Keys.down(KEY_A)), float(Keys.down(KEY_S)) - float(Keys.down(KEY_W)))
		var d := Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)
		yard.roll(d.normalized() if d.length() > 0.1 else -Vector3(sin(cam_yaw), 0, cos(cam_yaw)))
	elif ev is InputEventKey and ev.pressed and not ev.echo and _in_yard() and Keys.slot_of(ev.physical_keycode) >= 0:
		var bar := Profile.bar(profile).filter(func(x: String) -> bool: return not Rules.forms.has(x))
		var n: int = Keys.slot_of(ev.physical_keycode)
		if n < bar.size():
			yard_slot = n
			Toast.say(_yard_name(bar[n]), "", "info", 1.2)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode == KEY_ESCAPE:
			if tree.visible: _show_tree(false)
			elif captured: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else: _show_menu(not menu.visible)
		elif ev.physical_keycode == Keys.k(KEY_TAB):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif ev.physical_keycode == Keys.k(KEY_T) and not creating and not menu.visible and not profile.is_empty():
			_show_tree(not tree.visible)
		elif ev.physical_keycode == Keys.k(KEY_E) and _station != "" and not creating and not tree.visible and not menu.visible:
			_use_station(_station)
		elif ev.physical_keycode == Keys.k(KEY_H) and not creating and not tree.visible:
			# Put the sheet away to see the camp, and bring it back.
			side.get_parent().get_parent().visible = not side.get_parent().get_parent().visible

var _station := ""   # the camp station within reach (Map.STATIONS), or ""

## In the yard, ready to strike or weave (not making or menuing).
func _in_yard() -> bool:
	return yard != null and not creating and not menu.visible and not tree.visible and yard.near(pos)

func _yard_name(id: String) -> String:
	return Rules.weaves[id].name if Rules.weaves.has(id) else (Rules.weapons[id].name if Rules.weapons.has(id) else id)

## A click in the yard: the chosen thing on the bar, at what the crosshair is on (or
## the nearest post).
func _yard_use() -> void:
	var bar := Profile.bar(profile).filter(func(x: String) -> bool: return not Rules.forms.has(x))
	if bar.is_empty():
		return
	var id: String = bar[clampi(yard_slot, 0, bar.size() - 1)]
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var aim := yard.nearest_post(pos)
	var best := 2.0
	for pid in yard.posts:
		if yard.sim.ents.has(pid) and yard.sim.ents[pid].alive:
			var c: Vector3 = yard.sim.ents[pid].pos
			c.y = Terrain.height(c.x, c.z) + 1.2
			var along := (c - from).dot(dir)
			if along > 1.0:
				var miss := (c - (from + dir * along)).length()
				if miss < best:
					best = miss; aim = c
	face = atan2(aim.x - pos.x, aim.z - pos.z)
	if Rules.weaves.has(id):
		yard.cast(id, aim)
	elif Rules.weapons.has(id):
		yard.sim.equip(yard.me, id)
		yard.attack(aim, false)

## A form in the yard (Z, X, R): the forms of the weapon chosen on the bar, as in a fight.
func _yard_form(i: int) -> void:
	var bar := Profile.bar(profile)
	var arms := bar.filter(func(x: String) -> bool: return Rules.weapons.has(x))
	var w: String = yard.sim.ents[yard.me].weapon
	if w == "" and not arms.is_empty():
		w = arms[0]
	if w == "":
		return
	var mine := bar.filter(func(x: String) -> bool: return Rules.forms.has(x) and Rules.forms[x].family == Rules.weapons[w].family)
	if i >= mine.size():
		return
	yard.sim.equip(yard.me, w)
	var aim := yard.nearest_post(pos)
	face = atan2(aim.x - pos.x, aim.z - pos.z)
	var why := yard.sim.request_attack(yard.me, "form:" + String(mine[i]), aim)
	if why != "" and why != "busy":
		Toast.say(why.capitalize(), "", "warn", 1.5)

## The yard, made for the character in hand (again when another is chosen).
func _yard_for(p: Dictionary) -> void:
	if yard:
		yard.queue_free()
		yard = null
	if p.is_empty() or (Launch.cmdline().has("ghost") and Launch.cmdline().ghost != "yard"):
		return
	yard = CampYard.new(); add_child(yard)
	yard.setup(self, p.duplicate(true))
	yard.sim.ents[yard.me].profile = p

## What the sheet shows that can be new: weaves, forms and weapons known, techniques,
## a win's unlock waiting, what is being worked out.
func _sheet_mark() -> String:
	var known := []
	for w in profile.get("weaves", {}):
		if profile.weaves[w].get("known", false): known.append(w)
	known.sort()
	var forms: Array = profile.get("forms_owned", profile.get("forms", {}).keys()).duplicate(); forms.sort()
	var arms: Array = profile.get("weapons_owned", profile.get("kit", [])).duplicate(); arms.sort()
	var tech: Array = profile.get("techniques", []).duplicate(); tech.sort()
	return str([known, forms, arms, tech, int(profile.get("unlocks_owed", 0)), profile.get("talents", [])]).md5_text()

## The faded corner: shown while the sheet is away; the sheet seen open marks all as seen.
func _mini_step() -> void:
	if mini == null or profile.is_empty():
		if mini: mini.visible = false
		return
	var sheet_open: bool = side.get_parent().get_parent().visible
	var mark := _sheet_mark()
	if sheet_open:
		if profile.get("sheet_seen", "") != mark:
			profile.sheet_seen = mark
			if not Launch.dev():
				Profile.save(profile)
	mini.visible = not sheet_open and not creating and not tree.visible
	if mini.visible:
		mini_name.text = String(profile.get("name", ""))
		mini_ren.text = "Renown %d" % int(profile.get("renown", 0.0))
		mini_new.visible = profile.get("sheet_seen", "") != mark

## What each station opens.
func _use_station(id: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match id:
		"armoury": _armoury()
		"tailor": _appearance()
		"study": _loadout()

const STATION_SAY := {
	armoury = ["The armoury", "Change what you carry"],
	tailor = ["The tailor", "Dress, hair, build and cloak, in the long mirror"],
	study = ["The study", "Talents, weaves and affinity for the next fight"],
}

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
	if cam == null or model == null or returning:
		return
	Wind.step(dt)
	Perf.frame()
	if cl.has("census") and _frame == 600:
		Perf.census(self)
	if cl.has("timing") and dt > 0.05:
		print("TIMING camp frame %d took %d ms (preloading: %s)" % [_frame, int(dt * 1000.0), not _pre.is_empty()])
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
	_camp_link(dt)
	_walk_others(dt)
	if creating or profile.is_empty():
		# Making a character: they stand and are looked at.
		cam.position = cam.position.lerp(_ground(Vector3.ZERO) + Vector3(0.0, 1.35, 3.6), minf(6.0 * dt, 1.0))
		cam.look_at(_ground(Vector3.ZERO) + Vector3(0.0, 1.0, 0))
		model.position = _ground(Vector3.ZERO); model.rotation.y = 0.35
		var idle: AnimationPlayer = model.get_meta("anim")
		if idle.current_animation != "Idle":
			idle.play("Idle", 0.15)
		return
	_mini_step()
	if not _hinted and not cl.has("ghost") and not returning:
		_hinted = true
		Toast.say("The camp", "%s walk · click to look around · walk through a doorway to begin · %s hide the sheet · Esc menu" % [Keys.move(), Keys.name(KEY_H)], "info", 9.0)
	var move := Vector3.ZERO
	if not tree.visible and not menu.visible and get_viewport().gui_get_focus_owner() == null:
		var v := Vector2(float(Keys.down(KEY_D)) - float(Keys.down(KEY_A)), float(Keys.down(KEY_S)) - float(Keys.down(KEY_W)))
		v += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		move = (Basis(Vector3.UP, cam_yaw) * Vector3(v.x, 0, v.y)).limit_length(1.0)
	if cl.has("stroll") and int(cl.stroll) < doors.size():
		var to: Vector3 = doors[int(cl.stroll)].at * 1.4 - pos   # on through, not to the sill
		move = to.normalized()
		cam_yaw = lerp_angle(cam_yaw, atan2(-move.x, -move.z), 2.0 * dt)
	var sprint := Keys.down(KEY_SHIFT)
	if _phase == 1:
		move = Vector3.ZERO     # the body is over there now, moved by the fight
	# Walking eases in and out, as a body in a fight does (there the figure closes on
	# where the sim has it), and at a fight's pace (5.2 a second, the jog clip's own);
	# starting dead and stopping dead was what made the camp's running look stiff.
	_vel = _vel.lerp(move * (7.5 if sprint else Rules.TUNE.get("walk_speed", 5.2)), minf(12.0 * dt, 1.0))
	if _vel.length() < 0.05:
		_vel = Vector3.ZERO
	if _vel.length() > 0.05:
		# Inside the palisade (Scenery.palisade), never an invisible line in the grass.
		pos = _unblock(pos + _vel * dt).limit_length(Scenery.CAMP_WALL - 1.6)
		# The doorways' posts are stone: you go between them, not through them.
		for d in doors:
			var across := Vector3(d.at.z, 0, -d.at.x).normalized()
			for side_ in [-1.2, 1.2]:
				var post: Vector3 = d.at + across * side_
				var off := pos - post
				if off.length() < 0.8 and off.length() > 0.001:
					pos = post + off.normalized() * 0.8
		if move.length() > 0.1:
			face = atan2(move.x, move.z)
		if not _pre.is_empty():
			var A: Transform3D = _pre.A
			var fwd := -A.basis.z
			var right := A.basis.x
			var depth := (pos - A.origin).dot(fwd)
			var lateral := (pos - A.origin).dot(right)
			# Only in front of this doorway's own opening: walking into it draws you
			# to its middle, so you come out where the body over there stands...
			if absf(lateral) < 1.3 and depth > -2.5 and depth < 0.6 and move.dot(fwd) > 0.2:
				pos -= right * lateral * minf(5.0 * dt, 1.0)
			# ...and if its far side is not made yet, you wait on the sill.
			if absf(lateral) < 1.3 and not _pre.game.portal_ready() and depth > -0.3 and depth < 0.6:
				pos -= fwd * (depth + 0.3)
	if yard:
		pos = yard.step(dt, pos, face)
		if yard.near(pos) and not _yard_told and not cl.has("ghost"):
			_yard_told = true
			Toast.say("The yard", "Click: strike or weave at the posts (%s choose from your bar) · %s roll. Nobody else can be struck here." % ["1-9", Keys.name(KEY_SPACE)], "info", 8.0)
	model.position = _ground(pos)
	model.rotation.y = lerp_angle(model.rotation.y, face, minf(10.0 * dt, 1.0))
	# Eased, so the first step does not throw it back at once.
	_cloak_speed = lerpf(_cloak_speed, minf(_vel.length(), 9.0), minf(3.0 * dt, 1.0))
	Hero.cloak_motion(model, _cloak_speed)
	var ap: AnimationPlayer = model.get_meta("anim")
	# The clip from how fast the body is actually going, as in a fight (not the keys).
	var spd := _vel.length()
	var clip := ("Sprint" if spd > 6.5 and ap.has_animation("Sprint") else "Jog_Fwd") if spd > 0.6 else "Idle"
	# (A blow or a roll in the yard plays out before walking takes the legs back.)
	if Time.get_ticks_msec() / 1000.0 < float(get_meta("busy_until", 0.0)):
		clip = ap.current_animation
	if ap.current_animation != clip:
		ap.play(clip, 0.12)
	# The same orbit camera as in a fight, a little further back to take in the doorways.
	var pivot := model.position + Vector3(0, 1.55, 0)
	var view := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)
	# Camera to the left, so the character stands clear of the sheet; centred
	# behind them near a doorway, so it goes through the opening and not the stone.
	var cx := -1.1
	if not _pre.is_empty():
		var depth := (pos - (_pre.A as Transform3D).origin).dot(-(_pre.A as Transform3D).basis.z)
		cx = lerpf(-1.1, 0.0, clampf((depth + 6.0) / 3.0, 0.0, 1.0))
	cam_x = move_toward(cam_x, cx, dt * 1.5)
	cam_back = move_toward(cam_back, float(cl.get("camdist", 4.6)), dt * (99.0 if cl.has("camdist") else 1.2))
	var want := pivot + view * Vector3(cam_x, 0.2, cam_back)
	want.y = maxf(want.y, _height(want.x, want.z) + 0.35)
	cam.position = cam.position.lerp(want, minf(14.0 * dt, 1.0))
	cam.basis = view
	_portal(dt)
	# The camp's stations: walk up to one and E opens it.
	var st_near := ""
	for st in Map.STATIONS:
		if Vector2(pos.x - st.x, pos.z - st.z).length() < 2.6 and not menu.visible and not tree.visible:
			st_near = st.id
	if st_near != _station:
		_station = st_near
		if st_near != "":
			Toast.say(STATION_SAY[st_near][0], "%s.   %s: open" % [STATION_SAY[st_near][1], Keys.name(KEY_E)], "info", 4.0)
	# Doorways: say what the nearest one is; step into an open one to go.
	var near := {}
	for d in doors:
		if pos.distance_to(d.at) < 5.5 and (near.is_empty() or pos.distance_to(d.at) < pos.distance_to(near.at)):
			near = d
	# Coming up to a doorway, say once what it is (and who is fighting there).
	var nid: String = "" if near.is_empty() or tree.visible or menu.visible else near.id
	if nid != _near_id:
		_near_id = nid
		if nid != "":
			var body: String = near.sub
			for f in fights:
				body += "\n%s %s fighting now: any doorway joins them." % [", ".join(f.players), "is" if f.players.size() == 1 else "are"]
			Toast.say(near.name, body, "info" if near.open else "warn", 5.0)

func _enter(id: String) -> void:
	set_process(false)
	# Every fight is on the server: the first to arrive starts it and friends join
	# the same one. If the server cannot be reached the game says so and plays offline.
	if reachable or cl.has("ghost"):
		Toast.say("Joining the server…", "", "info", 3.0)
		# One fight per doorway on the server (its room is the doorway's mode): the
		# practice yard never shares a room with a wave fight.
		_go({activity = id, join = Launch.server(), word = online.get("word", ""), room = String(id).split("@")[0]})
	else:
		Toast.say("Playing offline", "The server isn't answering, so this fight is on your machine alone.", "warn", 7.0)
		_go({activity = id})

## One doorway for every activity, in an arc ahead of where you arrive. Rebuilt
## whenever the character changes, since what is open depends on who you are.
func _doors() -> void:
	for d in doors:
		d.node.queue_free()
	doors = []
	var ids := []
	for id in Rules.activities:
		if not str(id).begins_with("_") and not Rules.activities[id].get("hidden", false):
			ids.append(id)
	# One doorway per mode, in this order (training first, the duel last).
	# (The training yard is in the camp itself now: CampYard, off to the side.)
	var order := ["holdout", "guard_door", "darkfriend_door", "endless_door", "team_battle", "dream_spar"]
	ids.sort_custom(func(x: String, y: String) -> bool: return (order.find(x) if order.has(x) else 50) < (order.find(y) if order.has(y) else 50))
	var open := Rules.available(profile)
	for i in ids.size():
		var a: Dictionary = Rules.activities[ids[i]]
		# The sheet covers the left of the view, so the arc starts just left of
		# straight ahead and runs round to the right; more doorways carry on round.
		# Spaced so each doorway is its own: about eight paces between them.
		var ang := deg_to_rad(22.0 * i - 10.0)
		var at := Vector3(sin(ang) * 20.0, 0, -cos(ang) * 20.0)
		var sub: String = a.blurb
		if not ids[i] in open:
			var need := []
			if a.requires.has("renown") and profile.renown < a.requires.renown: need.append("renown %d" % a.requires.renown)
			for dn in a.requires.get("done", []):
				if not profile.done.has(dn): need.append(Rules.activities[dn].name)
			sub = "Closed to you: needs " + ", ".join(need)
		# A mode's doorway is done if any of its setups has been won.
		var won_here: bool = profile.done.keys().any(func(x: String) -> bool: return x == ids[i] or x.begins_with(ids[i] + "@"))
		var name_: String = a.name + ("  ✓" if won_here else "")
		var node := Scenery.doorway(self, _ground(at), -ang, DOOR_TINT.get(ids[i], DOOR_TINT.get(a.kind, Color.WHITE)), ids[i] in open, name_, "" if ids[i] in open else "(closed)",
			{tarwins_gap = 1, wagon_ring = 2}.get(a.get("map", ""), 4 if a.kind == "spar" else 3))
		# The place this doorway opens on is chosen now, so its picture is the place
		# you will walk into (a mode's doorway picks one of its setups).
		var setup := Rules.pick_setup(ids[i])
		var card_id: String = setup.get_slice("@", 1) if setup.contains("@") else setup
		var card_path := "res://assets/postcards/%s.jpg" % card_id
		if ids[i] in open and ResourceLoader.exists(card_path):
			var dm := _door_mat({node = node})
			if dm:
				dm.set_shader_parameter("card", load(card_path))
				dm.set_shader_parameter("has_card", 1.0)
		doors.append({id = ids[i], at = at, open = ids[i] in open, node = node, name = name_, sub = sub, setup = setup})
		# Home from an activity: you step back out of its doorway, facing the camp.
		if not _placed and Launch.last_activity == ids[i]:
			pos = at * (1.0 - 2.6 / 20.0); face = atan2(-at.x, -at.z); cam_yaw = face
	_placed = true
	if model:
		model.rotation.y = face
	cam.position = _ground(pos) + Basis(Vector3.UP, cam_yaw) * Vector3(-1.1, 1.75, 4.6)

# --- an existing character --------------------------------------------------------------

## Exchange a character with the server's store: it keeps whichever copy has
## channelled longer and sends that back, so one character follows you between
## machines. Needs a server address and a passphrase; silent when neither is set.
func _sync(name_: String, local: Dictionary) -> void:
	if online.get("key", "") == "":
		return
	# One connection at a time, and never by freeing another's: a doorway's fight
	# loaded just now is left alone, and the character is kept a little later.
	if get_tree().root.get_node_or_null("Session") != null:
		_after(5.0, func() -> void: _sync(name_, local))
		return
	var s := Session.new()
	# (Deferred, and waited for: at start the root may still be setting up its
	# children, and a Session outside the tree has no multiplayer to connect with.)
	get_tree().root.add_child.call_deferred(s)
	await get_tree().process_frame
	# The lambdas below may run after the Session is gone (the time-out always
	# does), so they hold its id, not the node.
	var sid := s.get_instance_id()
	var finish := func(status: String, kept: Dictionary) -> void:
		var live := instance_from_id(sid) as Session
		if live == null:
			return
		multiplayer.multiplayer_peer = null
		live.queue_free()
		online_note = status if status != "" else "%s is kept on the server" % kept.name
		var newer: bool = not kept.is_empty() and Profile.current(kept) and (local.is_empty() or float(kept.seconds) > float(local.seconds))
		if newer:
			Profile.save(kept)
			online_note = "%s came from the server" % kept.name
		if newer or name_.to_lower() == profile.get("name", "").to_lower() or profile.is_empty():
			_select(kept.name if newer else profile.get("name", ""), false)
		_menu_fill()
	s.vaulted.connect(finish)
	_after(6.0, func() -> void: finish.call("no answer from the server", {}))
	s.vault_sync(Launch.server(), name_, online.key, local, online.get("word", ""))

func _select(name_: String, sync := true) -> void:
	if name_ == "" or Profile.load_profile(name_).is_empty():
		_creation()
		return
	creating = false
	make = {}
	_close_gifts()
	profile = Profile.load_profile(name_)
	if not Launch.dev() and not profile.is_empty():
		profile.book_limit = Settings.book_limit()   # how far this player has read
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
	_yard_for(profile)
	_sheet()

## The left column: who you are, what you own, and what you take into a fight.
func _sheet() -> void:
	_clear(side)
	var channels: bool = profile.get("cls", "channeller") == "channeller"
	_text(side, profile.name, 30)
	var who: String = Rules.cls(profile).name if not channels else ("Channels saidin" if profile.power == "saidin" else "Channels saidar")
	_text(side, "%s  ·  %s" % [who, ORIGINS.get(profile.origin, profile.origin)], 14, Color(0.68, 0.69, 0.74))
	_row(side, "Renown", str(int(profile.renown)), Glyph.GOLD)
	if int(profile.get("unlocks_owed", 0)) > 0:
		_button(side, "A win: choose something to keep  (%d)" % int(profile.unlocks_owed), _unlocks)
	if channels:
		_section(side, "Into the next fight")
		for e in Rules.ELEMENTS:
			_pips(side, e.capitalize(), int(profile.get("aff_pts", {}).get(e, 0)), Profile.AFF_OWN_MAX, Glyph.TINT.get(e, Glyph.GOLD))
		_row(side, "Talents", ", ".join(profile.talents.map(func(t: String) -> String: return t.capitalize())) if not profile.talents.is_empty() else "none")
		for id in profile.weaves:
			if Rules.weaves.has(id):
				_row(side, Rules.weaves[id].name, "born knowing" if id == profile.get("starter", "") else "")
		_text(side, "Strength is rolled anew every round.", 13, Color(0.66, 0.67, 0.72))
	else:
		_section(side, "Into the next fight")
		for st in ["might", "quickness", "endurance"]:
			_pips(side, st.capitalize(), int(Rules.stat(profile, st)), 4, Glyph.GOLD)
		for w in profile.kit:
			_row(side, Rules.weapons[w].name, Rules.weapons[w].family)
		for gid in profile.get("gifts", []):
			if Rules.GIFTS.has(gid):
				_row(side, Rules.GIFTS[gid].name, "gift")
		if Rules.SOCIETIES.has(profile.get("society", "")):
			_row(side, Rules.SOCIETIES[profile.society].name, Rules.SOCIETIES[profile.society].sub)
		if Rules.KITS.has(profile.get("hunter_kit", "")):
			_row(side, Rules.KITS[profile.hunter_kit].name, "kit")
		for f in profile.get("forms", {}):
			if Rules.forms.has(f):
				_row(side, Rules.forms[f].name, "form")
		# What is being worked out between rounds, by fighting.
		var st_id: String = profile.get("study", "")
		if Rules.lore(profile).has(st_id):
			_row(side, "Working out", "%s  %d%%" % [Rules.lore(profile)[st_id].name, int(100.0 * float(profile.get("study_done", 0.0)) / Rules.study_cost(profile, st_id))], Color(0.85, 0.87, 0.95))
		_button(side, "The weapon and form trees, and your bar  (%s)" % Keys.name(KEY_T), func() -> void: _show_tree(true))
	if channels:
		_button(side, "The weave tree, and your bar  (%s)" % Keys.name(KEY_T), func() -> void: _show_tree(true))
	_button(side, "Loadout: Talents, weaves, affinity", _loadout)
	_button(side, "Appearance: dress, hair, build", _appearance)
	if Launch.report.size() > 0:
		_section(side, "Last time out")
		_text(side, "\n".join(Launch.report), 14, Color(0.95, 0.85, 0.55))
	_button(side, "Menu: characters, keys, server, quit  (Esc)", func() -> void: _show_menu(true))

var _binding := -1   # the default key being rebound in the Keys panel, or -1
var _binding_dream := -1   # or the dream bar slot being rebound

## Every key that does something, and what it is bound to; press one to change it.
func _keys_panel() -> void:
	_panel("Keys")
	_text(menu_box, "Press a row, then the key you want for it (Esc keeps the old one). Keys go by where they sit on the board, so any layout works.", 13, Color(0.66, 0.67, 0.72))
	for a in Keys.ACTIONS:
		var dk: Key = a[0]
		var label: String = "%s:   %s" % [a[1], "press a key…" if _binding == int(dk) else Keys.name(dk)]
		_button(menu_box, label, func() -> void:
			_binding = int(dk)
			_keys_panel())
	# The dream duel's moves, kept with this character.
	_section(menu_box, "In the World of Dreams")
	Dream.load_data()
	var dkeys: Array = Dream.keys_of(profile)
	var dbar: Array = Dream.bar_of(profile)
	for i in dkeys.size():
		var slot := i
		_button(menu_box, "Dream slot %d (now %s):   %s" % [i + 1, Dream.moves[dbar[i]].name, "press a key…" if _binding_dream == i else dkeys[i]], func() -> void:
			_binding_dream = slot
			_keys_panel())
	_button(menu_box, "Put every key back as it was", func() -> void:
		Keys.reset()
		profile.erase("dream_keys"); profile.erase("dream_slot_keys"); Profile.save(profile)
		_keys_panel())
	_button(menu_box, "Back  (Esc)", func() -> void: _binding = -1; _show_menu(true))

## The bar's order: what sits in slot 1, 2, 3… (saved as profile.hotbar).
func _bar_order(v: Control) -> void:
	_section(v, "The bar, in order")
	var items: Array = profile.weaves.keys() + profile.get("kit", []) + profile.get("forms", {}).keys()
	var order: Array = profile.get("hotbar", []).filter(func(x: String) -> bool: return items.has(x))
	for x in items:
		if not order.has(x): order.append(x)
	profile.hotbar = order
	for i in order.size():
		var id: String = order[i]
		var nm: String = Rules.weaves[id].name if Rules.weaves.has(id) else (Rules.weapons[id].name if Rules.weapons.has(id) else (Rules.forms[id].name if Rules.forms.has(id) else id))
		var row := HBoxContainer.new(); v.add_child(row)
		var l := Label.new(); l.text = "%s   %s" % [Keys.name(KEY_1 + i) if i < 9 else "-", nm]; row.add_child(l)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.add_theme_font_size_override("font_size", 14)
		if i > 0:
			var up := Button.new(); up.text = "↑"; row.add_child(up); up.focus_mode = Control.FOCUS_NONE
			up.pressed.connect(func() -> void:
				var o: Array = profile.hotbar
				var t: String = o[i - 1]; o[i - 1] = o[i]; o[i] = t
				Profile.save(profile)
				_loadout())

func _panel(title: String) -> void:
	menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear(menu_box)
	_text(menu_box, title, 26)

func _check(v: Control, text: String, on: bool) -> CheckBox:
	var c := CheckBox.new(); c.text = text; c.button_pressed = on; v.add_child(c)
	c.add_theme_font_size_override("font_size", 14)
	return c

## Before a fight: what of what you own you take in. Channellers: at most two
## Talents and three weaves beyond the one they were born with, and five affinity
## points plus two for each Talent slot left empty. Fighters: three weapons, three forms.
func _loadout() -> void:
	_panel("Loadout")
	var note := _text(menu_box, "", 14, Color(1.0, 0.7, 0.45))
	if profile.get("cls", "channeller") == "channeller":
		_section(menu_box, "Talents (up to %d)" % Profile.TALENT_SLOTS)
		var tal := {}
		for t in profile.get("talents_owned", []):
			if Rules.talent_book(t) > int(profile.get("book_limit", 14)):
				continue   # from a later book than this player has read
			tal[t] = _check(menu_box, t.capitalize(), profile.talents.has(t))
		if tal.is_empty():
			_text(menu_box, "None yet: a win can bring one.", 13, Color(0.66, 0.67, 0.72))
		_section(menu_box, "Weaves (up to %d besides %s)" % [Profile.WEAVE_SLOTS, Rules.weaves[profile.starter].name])
		var wv := {}
		for w in profile.get("weaves_owned", []).filter(func(x: String) -> bool: return Rules.weaves.has(x) and Rules.book_of(x, profile) <= int(profile.get("book_limit", 14))):
			wv[w] = _check(menu_box, Rules.weaves[w].name, profile.weaves.has(w))
		if wv.is_empty():
			_text(menu_box, "None yet: a win can bring one.", 13, Color(0.66, 0.67, 0.72))
		_section(menu_box, "Affinity")
		_text(menu_box, "All of it goes into every fight. Room: 9 points with no Talent selected, 7 with one, 5 with two (now %d of %d). Points can be moved between Powers (and into your body), two out for each one in; points let go are gone." % [Profile.aff_total(profile), Profile.aff_cap(profile)], 13, Color(0.66, 0.67, 0.72))
		var before := {}
		for e in Rules.ELEMENTS: before[e] = int(profile.aff_owned.get(e, 0))
		for st in ["might", "quickness", "endurance"]: before[st] = int(Rules.stat(profile, st))
		var own := {}
		for k in before:
			var row := HBoxContainer.new(); menu_box.add_child(row)
			var l := Label.new(); l.text = k.capitalize(); row.add_child(l); l.custom_minimum_size.x = 96
			l.add_theme_color_override("font_color", Glyph.TINT.get(k, Glyph.GOLD).lerp(Color.WHITE, 0.35))
			var os := SpinBox.new(); os.max_value = Profile.AFF_OWN_MAX; os.value = before[k]; row.add_child(os)
			own[k] = os
		_button(menu_box, "Take these", func() -> void:
			var after := {}
			for k in own: after[k] = int(own[k].value)
			var asum := 0
			for e in Rules.ELEMENTS: asum += after[e]
			for st in ["might", "quickness", "endurance"]: asum += after[st]
			if Profile.trade_left(before, after) < 0: note.text = "Too many points added: every point costs two taken from elsewhere."; return
			if asum > Profile.AFF_OWN_MAX: note.text = "You can own at most %d points in all." % Profile.AFF_OWN_MAX; return
			var t := tal.keys().filter(func(k: String) -> bool: return tal[k].button_pressed)
			var esum := 0
			for e in Rules.ELEMENTS: esum += after[e]
			var room := Profile.aff_cap(profile, t.size())
			if esum > room: note.text = "With %d Talent%s selected there is room for %d affinity points; you have %d. Lower %d first, or select fewer Talents." % [t.size(), "" if t.size() == 1 else "s", room, esum, esum - room]; return
			var w := wv.keys().filter(func(k: String) -> bool: return wv[k].button_pressed)
			if t.size() > Profile.TALENT_SLOTS: note.text = "At most %d Talents." % Profile.TALENT_SLOTS; return
			if w.size() > Profile.WEAVE_SLOTS: note.text = "At most %d weaves besides your own." % Profile.WEAVE_SLOTS; return
			profile.talents = t
			profile.weaves = {profile.starter: {known = true, xp = 0.0}}
			for k in w: profile.weaves[k] = {known = true, xp = 0.0}
			for e in Rules.ELEMENTS: profile.aff_owned[e] = after[e]
			for st in ["might", "quickness", "endurance"]: profile.stats[st] = after[st]
			Profile.apply_affinity(profile)
			Profile.save(profile)
			menu.visible = false
			_select(profile.name))
	else:
		_section(menu_box, "Weapons (1 to %d)" % Profile.WEAPON_SLOTS)
		var wp := {}
		for w in profile.get("weapons_owned", profile.kit):
			wp[w] = _check(menu_box, Rules.weapons[w].name, profile.kit.has(w))
		_section(menu_box, "Forms (up to %d)" % Profile.FORM_SLOTS)
		var fm := {}
		for f in profile.get("forms_owned", []):
			fm[f] = _check(menu_box, Rules.forms[f].name, profile.forms.has(f))
		_button(menu_box, "Take these", func() -> void:
			var k := wp.keys().filter(func(x: String) -> bool: return wp[x].button_pressed)
			var f := fm.keys().filter(func(x: String) -> bool: return fm[x].button_pressed)
			if k.is_empty() or k.size() > Profile.WEAPON_SLOTS: note.text = "Take one to %d weapons." % Profile.WEAPON_SLOTS; return
			if f.size() > Profile.FORM_SLOTS: note.text = "At most %d forms." % Profile.FORM_SLOTS; return
			profile.kit = k
			profile.forms = {}
			for x in f: profile.forms[x] = {known = true}
			Profile.save(profile)
			menu.visible = false
			_select(profile.name))
	_bar_order(menu_box)
	_button(menu_box, "Back to the camp  (Esc)", func() -> void: _show_menu(false))

## After a win: three things to choose from, one to keep for good.
func _unlocks() -> void:
	_panel("Something to keep")
	var rng := RandomNumberGenerator.new(); rng.seed = hash(profile.name) + int(profile.renown) + int(profile.get("unlocks_owed", 0))
	for u in Profile.unlock_offers(profile, 3, rng):
		var o: Dictionary = u
		_button(menu_box, o.name, func() -> void:
			Profile.take_unlock(profile, o)
			Profile.save(profile)
			Toast.say("Kept: %s" % o.name, "Take it into a fight from the loadout.", "good")
			menu.visible = false
			_select(profile.name))
	_button(menu_box, "Later  (Esc)", func() -> void: _show_menu(false))

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
			online = {word = "tinker", key = "ghostpass"}
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
			_press(gifts, "Begin")
		40:
			print("GHOST flow created: %s cls=%s kit=%s style=%s doors=%d" % [profile.get("name", "-"), profile.get("cls", "-"), profile.get("kit", []), profile.get("style", {}), doors.size()])
			_press(side, "Loadout")
		50:
			_press(menu_box, "Take these")
		60:
			print("GHOST flow loadout: kit=%s menu=%s" % [profile.get("kit", []), menu.visible])
			_press(side, "Appearance")
		70:
			var dress: OptionButton = menu_box.find_children("*", "OptionButton", true, false)[0]
			dress.select(1); dress.item_selected.emit(1)
		80:
			_press(menu_box, "Keep this")
		90:
			print("GHOST flow appearance: look=%s style=%s" % [profile.get("look", "-"), profile.get("style", {})])
			profile.unlocks_owed = 1
			_sheet()
			_press(side, "A win")
		100:
			var offers := menu_box.find_children("*", "Button", true, false)
			if offers.size() > 1:
				(offers[1] as Button).pressed.emit()
		110:
			print("GHOST flow unlock: weapons=%s forms=%s owed=%d" % [profile.get("weapons_owned", []), profile.get("forms_owned", []), int(profile.get("unlocks_owed", 0))])
			_show_menu(true)
		120:
			_press(menu_box, "Back to the camp")
		130:
			_creation("channeller", "Ghost Weaver", "saidin")
		140:
			_press(gifts, "Begin")
		150:
			print("GHOST flow second: %s power=%s starter=%s saved=%s" % [profile.get("name", "-"), profile.get("power", "-"), profile.get("starter", "-"), _saved()])
			# Walk into the first doorway, as feet would.
			cl.stroll = "0"

## Who is on the server now, asked every so often while the camp is open. One
## connection at a time: it waits if a character is being exchanged.
var fights: Array = []
static var reachable := true   # the server answered the last time it was asked
static var server_stamp := {}  # the server's build stamp (commit, date), from its lobby answer
static var in_camp: Array = []   # others in their camps just now (names), from the server
static var server_version := ""
var _lobby_t := 0.0
func _poll_lobby(dt: float) -> void:
	_lobby_t -= dt
	if _lobby_t > 0.0:
		return
	# Quick while a friend is about, so they are seen walking, not jumping; slow
	# otherwise, just to notice someone arriving.
	# Over the camp link when it is up (no new connection at all); a connection of
	# its own only when it is down, and rarely: one built and thrown away every few
	# seconds is what crashed the camp after a few minutes.
	_lobby_t = 4.0 if _linked() else 12.0
	var where := {v = Updater.release()}
	if model and not creating:
		where = {x = pos.x, z = pos.z, yaw = face, kind = String(model.get_meta("kind", "")), style = profile.get("style", {}), v = Updater.release()}
	var word: String = online.get("word", "")
	if _linked():
		if _link.ask_here(word, profile.get("name", ""), where):
			if not _link.lobby.is_connected(_heard_link):
				_link.lobby.connect(_heard_link)
		return
	var busy := get_tree().root.get_node_or_null("Session") as Session
	if busy != null:
		# A doorway's fight is loaded. Joined to the server, it asks over that
		# connection (one at a time: a second would take over the first); played
		# here, there is nobody to ask.
		if busy.ask_here(word, profile.get("name", ""), where):
			busy.lobby.connect(func(list: Array) -> void: _heard(list, true), CONNECT_ONE_SHOT)
		return
	var s := Session.new()
	get_tree().root.add_child(s)
	var sid := s.get_instance_id()
	var done := func(list: Array, answered: bool) -> void:
		var live := instance_from_id(sid) as Session
		if live == null:
			return
		if live.multiplayer.multiplayer_peer:
			live.multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		live.queue_free()
		_heard(list, answered)
	s.lobby.connect(func(list: Array) -> void: done.call(list, true))
	_after(5.0, func() -> void: done.call(fights, false))
	s.ask_lobby(Launch.server(), word, profile.get("name", ""), where)

func _heard_link(list: Array) -> void:
	_heard(list, true)

## The server's answer: who it is, who is fighting what, who is in their camp and
## where they stand.
func _heard(list: Array, answered: bool) -> void:
	# The server says who it is in an entry of its own; the rest are fights.
	fights = []
	for f in list:
		if f.get("room", "") == "_server":
			server_stamp = f.get("stamp", {}); server_version = f.get("version", "")
			if f.has("release"): server_stamp.release = f.release
		elif f.get("room", "") == "_camp":
			# A friend just come to their camp: say so, once.
			for n in f.get("players", []):
				if not in_camp.has(n) and not cl.has("ghost"):
					Toast.say("%s is in their camp" % n, "A doorway you both walk through puts you in the same fight.", "good", 6.0)
			in_camp = f.get("players", [])
			camp_versions = f.get("versions", {})
			if not _linked():
				_place_others(f.get("walkers", []))
			# Someone to watch walk: ask again soon (the wait was chosen before
			# this answer came).
			if not others.is_empty():
				_lobby_t = minf(_lobby_t, 1.5)
		else:
			fights.append(f)
	# Say once when the server stops (or starts) answering.
	if answered != reachable and not cl.has("ghost"):
		if answered:
			Toast.say("Connected", "The server is answering. Friends can join your fights.", "good")
		else:
			Toast.say("Can't reach the server", "Fights will be played offline until it answers.", "warn", 8.0)
	reachable = answered
	# (Not while something is being typed into the menu: rebuilding it would take
	# the box away from under the keys.)
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if menu.visible and not creating and not typing and menu_box.get_child_count() > 0 and (menu_box.get_child(0) as Label).text == "Heartstone":
		_menu_fill()

## The camp link: a connection of its own to the server for as long as the camp is
## open, in a branch with its own multiplayer (so a doorway's fight can be joined
## beside it). It says where we stand ten times a second and hears the same of
## everyone else (Session "the camp link").
var _link: Session
var _link_branch: Node
var _link_retry := 0.0
var _link_send := 0.0
var _looks := {}         # name -> {kind, style}, from the link

func _linked() -> bool:
	if _link == null or not is_instance_valid(_link):
		return false
	var peer := _link.multiplayer.multiplayer_peer
	return peer != null and not peer is OfflineMultiplayerPeer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _camp_link(dt: float) -> void:
	if cl.has("offline") or creating or model == null or Launch.server() == "":
		return
	if _link == null or not is_instance_valid(_link):
		_link_retry -= dt
		if _link_retry > 0.0:
			return
		_link_retry = 6.0
		_link_branch = Node.new(); _link_branch.name = "CampLink"; add_child(_link_branch)
		_link_mp = SceneMultiplayer.new()
		get_tree().set_multiplayer(_link_mp, _link_branch.get_path())
		# Named Session, so its calls find the server's Session (paths are relative
		# to each side's multiplayer root).
		_link = Session.new(); _link.name = "Session"; _link_branch.add_child(_link)
		_link.camp_walkers.connect(_heard_walkers)
		_link.camp_act.connect(_heard_act)
		_link.camp_looks.connect(func(looks: Dictionary) -> void: _looks = looks)
		var drop := func(_why := "") -> void:
			# Gone (or never there): close it and try again in a while.
			_close_link()
		_link.rejected.connect(drop)
		_link.multiplayer.server_disconnected.connect(drop)
		_link.camp_join(Launch.server(), online.get("word", ""), profile.get("name", ""),
			{x = pos.x, z = pos.z, yaw = face, kind = String(model.get_meta("kind", "")), style = profile.get("style", {})})
		return
	_link_send -= dt
	if _link_send <= 0.0 and _linked():
		_link_send = Session.CAMP_EVERY
		_link.camp_at(pos.x, pos.z, face)

## Hang up the camp link: close its connection first (so nothing more arrives for a
## branch that is going), then free the branch. Its SceneMultiplayer stays
## registered at that path with no peer, which costs nothing; Godot will not take
## null there ("p_multiplayer is null"), and the next link replaces it.
var _link_closing := false
var _link_mp: SceneMultiplayer
func _close_link() -> void:
	if _link_closing:
		return
	_link_closing = true
	# (Through _link_mp, not _link.multiplayer: when the camp leaves the tree its
	# children have already left, and a node out of the tree has no multiplayer.)
	if _link_mp != null:
		var mp := _link_mp
		if mp.multiplayer_peer and not (mp.multiplayer_peer is OfflineMultiplayerPeer):
			for c in mp.server_disconnected.get_connections():
				mp.server_disconnected.disconnect(c.callable)
			mp.multiplayer_peer.close()
			mp.multiplayer_peer = null
	if is_instance_valid(_link_branch):
		_link_branch.queue_free()
	_link = null; _link_branch = null; _link_mp = null
	_link_closing = false

## My yard's practice, for the others in the camp to see.
func yard_share(e: Dictionary) -> void:
	if not _linked():
		return
	var act := {}
	for k in ["e", "move", "wind", "recover", "weapon", "weave", "kind", "pos", "at", "dir", "dir3", "reach", "k", "radius"]:
		if e.has(k):
			act[k] = e[k]
	_link.camp_act_send(act)

## A friend's practice in their yard, played on their figure here.
func _heard_act(name: String, act: Dictionary) -> void:
	if not others.has(name) or not is_instance_valid(others[name].node):
		return
	var node: Node3D = others[name].node
	var ap: AnimationPlayer = node.get_meta("anim")
	others[name].busy = Time.get_ticks_msec() / 1000.0 + 0.9
	match String(act.get("e", "")):
		"blow":
			var m: Dictionary = Rules.moves.get(String(act.get("move", "")), {})
			var clip: String = m.get("clip", "Sword_Attack")
			if ap.has_animation(clip): ap.play(clip, 0.08)
			Hero.stroke(node, String(act.get("move", "")), float(act.get("wind", 0.3)), float(act.get("recover", 0.3)) * 0.8, String(act.get("weapon", "")))
		"cast":
			var cc := Hero.cast_clip(name, String(act.get("weave", "")))
			if ap.has_animation(cc): ap.play(cc, 0.1)
			if Rules.weaves.has(String(act.get("weave", ""))) and act.has("pos") and act.has("dir"):
				var e := act.duplicate(); e.id = -1; e.power = ""
				Weavefx.cast(self, e)
		"blast":
			if act.has("pos"):
				Weavefx.blast(self, act.pos, float(act.get("radius", 1.5)), String(act.get("weave", "fireball")))
		"dodge":
			if ap.has_animation("Roll"): ap.play("Roll", 0.05, 1.6)

## Ten times a second from the link: where everyone else is.
func _heard_walkers(list: Array) -> void:
	var walkers := []
	for w in list:
		var look: Dictionary = _looks.get(w[0], {})
		walkers.append({name = w[0], x = w[1], z = w[2], yaw = w[3], kind = look.get("kind", ""), style = look.get("style", {})})
	_place_others(walkers, true)

## Friends in their own camps, drawn walking about in this one: name ->
## {node, to (where the server last said), yaw}. They walk to each new spot rather
## than jump, since the answers come a second and a half apart.
var others := {}
func _place_others(walkers: Array, quick := false) -> void:
	var seen := {}
	for w in walkers:
		var n: String = w.get("name", "")
		if n == "" or n == profile.get("name", ""):
			continue
		seen[n] = true
		var to := _ground(Vector3(float(w.x), 0, float(w.z)))
		if not others.has(n):
			var kind: String = w.get("kind", "")
			if kind == "" or not Hero.looks().has(kind):
				continue
			var node := Hero.instantiate(kind, hash(n), w.get("style", {}))
			add_child(node)
			node.position = to
			(node.get_meta("anim") as AnimationPlayer).play("Idle")
			others[n] = {node = node, to = to, yaw = float(w.yaw)}
		others[n].to = to; others[n].yaw = float(w.yaw)
	# Gone from two answers running (one can miss them while their camp is busy
	# opening a doorway): they have left, or gone through one.
	for n in others.keys():
		if seen.has(n):
			others[n].miss = 0
			continue
		others[n].miss = int(others[n].get("miss", 0)) + 1
		# (Over the link the lists come ten a second: half a second's absence.)
		if others[n].miss >= (5 if quick else 2):
			if is_instance_valid(others[n].node):
				others[n].node.queue_free()
			others.erase(n)

func _walk_others(dt: float) -> void:
	for n in others:
		var o: Dictionary = others[n]
		var node: Node3D = o.node
		if not is_instance_valid(node):
			continue
		var off: Vector3 = o.to - node.position
		off.y = 0.0
		var moving := off.length() > 0.06
		# Close behind where they were last heard of: at whatever pace closes the
		# gap by the next word (a tenth of a second over the link, longer without).
		var speed := clampf(off.length() / (0.15 if _linked() else 1.5), 1.0, 12.0)
		if moving:
			node.position = _ground(node.position + off.limit_length(speed * dt))
			node.rotation.y = lerp_angle(node.rotation.y, atan2(off.x, off.z), minf(dt * 8.0, 1.0))
		else:
			node.rotation.y = lerp_angle(node.rotation.y, float(o.yaw), minf(dt * 4.0, 1.0))
		var ap: AnimationPlayer = node.get_meta("anim")
		var clip := ("Sprint" if speed > 4.5 and ap.has_animation("Sprint") else "Jog_Fwd") if moving else "Idle"
		if Time.get_ticks_msec() / 1000.0 < float(o.get("busy", 0.0)) and not moving:
			clip = ap.current_animation
		if ap.current_animation != clip:
			ap.play(clip, 0.2)
		Hero.cloak_motion(node, speed if moving else 0.0)

var camp_versions := {}   # friend in their camp -> their game's version

## "Josh (v0.2.11), Sam (older)": who, and which version each runs.
static func _with_versions(names: Array, versions: Dictionary) -> String:
	var out := []
	for n in names:
		var v := String(versions.get(n, ""))
		out.append("%s (%s)" % [n, v if v != "" else "before v0.2.11"])
	return ", ".join(out)

func _lobby_text() -> String:
	if not reachable:
		return "The server isn't answering. Fights are played offline."
	if fights.is_empty():
		return "Nobody is fighting just now."
	var lines := []
	for f in fights:
		lines.append("%s: %s, %d:%02d in" % [_with_versions(f.players, f.get("versions", {})), Rules.activities.get(f.activity, {}).get("name", f.activity), int(f.t) / 60, int(f.t) % 60])
	return "\n".join(lines)

## Esc: the things that are not places. The server (where friends on different
## networks meet, and where characters are kept), joining a friend directly, quitting.
var _title_clicks := 0
func _menu_fill() -> void:
	_clear(menu_box)
	var title := _text(menu_box, "Heartstone", 28)
	# Ten clicks on the title open the choice of reading past book 6 (so nobody
	# who has not read further even learns it is there).
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not Settings.story_open:
			_title_clicks += 1
			if _title_clicks >= 10:
				Settings.story_open = true; Settings.save()
				Toast.say("Later books opened", "Story so far can now be set past book 6, below.", "info", 5.0)
				_menu_fill())
	_button(menu_box, "Picture quality: %s" % Settings.QUALITY_NAMES[Settings.quality], func() -> void:
		Settings.quality = (Settings.quality + 1) % 3
		Settings.save(); Settings.apply(); _menu_fill())
	if Settings.story_open:
		_button(menu_box, "Story so far: %s" % ("all books" if Settings.story >= 14 else "through book 6"), func() -> void:
			Settings.story = 6 if Settings.story >= 14 else 99
			Settings.save()
			if not Launch.dev() and not profile.is_empty():
				profile.book_limit = Settings.book_limit(); Profile.save(profile)
			_menu_fill())
	_section(menu_box, "What's new")
	var news := VBoxContainer.new(); menu_box.add_child(news)
	Changelog.build(news, 340.0)
	if not profile.is_empty():
		_section(menu_box, "Characters")
		for n in _saved():
			if n != profile.name.to_lower():
				_button(menu_box, n.capitalize(), func() -> void: Launch.report = []; menu.visible = false; _select(n))
		_button(menu_box, "New character…", func() -> void: menu.visible = false; _creation())
	_section(menu_box, "Playing now")
	_text(menu_box, _lobby_text(), 14, Color(0.75, 0.9, 0.8) if reachable else Color(1.0, 0.7, 0.45))
	if not in_camp.is_empty():
		_text(menu_box, "In their camps: " + _with_versions(in_camp, camp_versions), 14, Color(0.75, 0.9, 0.8))
	# Which build each side is, and whether they can play together.
	var mine := Updater.label(Updater.stamp())
	_row(menu_box, "This game", mine)
	if server_version != "":
		_row(menu_box, "The server", Updater.label(server_stamp))
		if server_version != Session.version():
			var who := Updater.behind(Updater.stamp(), server_stamp) if not server_stamp.is_empty() else "the server"
			var same: bool = String(server_stamp.get("commit", "")) != "" and server_stamp.get("commit", "") == Updater.stamp().get("commit", "")
			_text(menu_box, "They do not match, so fights are played offline. %s" % ("Same build, different game data: the server's copy is stale and needs restarting." if same else "%s is out of date." % who.capitalize() if who != "" else "Update both."), 13, Color(1.0, 0.6, 0.45))
	_section(menu_box, "Your place on the server")
	_text(menu_box, "Every fight is held on the server, so friends anywhere can join. Your character is kept there too, guarded by your passphrase.", 13, Color(0.66, 0.67, 0.72))
	var fields := {}
	for f in [["word", "the server's word"], ["key", "your passphrase (four letters or more)"]]:
		var e := LineEdit.new(); e.placeholder_text = f[1]; e.text = online.get(f[0], ""); menu_box.add_child(e)
		e.secret = f[0] in ["word", "key"]
		fields[f[0]] = e
		# Kept as it is typed: the menu is rebuilt whenever the server answers, and
		# a box that only saved on the button lost what was typed into it.
		var ff: String = f[0]
		e.text_changed.connect(func(t: String) -> void:
			online[ff] = t.strip_edges()
			FileAccess.open(ONLINE, FileAccess.WRITE).store_string(JSON.stringify(online)))
	var keep := func() -> void:
		for f in fields:
			online[f] = fields[f].text.strip_edges()
		FileAccess.open(ONLINE, FileAccess.WRITE).store_string(JSON.stringify(online))
	_button(menu_box, "Save, and keep this character on the server", func() -> void:
		keep.call(); online_note = "asking the server…"
		_sync(profile.get("name", ""), profile)
		_menu_fill())
	var want := LineEdit.new(); want.placeholder_text = "name of a character kept on the server"; menu_box.add_child(want)
	_button(menu_box, "Fetch that character", func() -> void:
		keep.call()
		var who: String = want.text.strip_edges()
		if who != "":
			online_note = "asking the server…"
			_sync(who, Profile.load_profile(who))
			_menu_fill())
	if online_note != "":
		_text(menu_box, online_note, 13, Color(0.95, 0.85, 0.55))
	_section(menu_box, "")
	_button(menu_box, "Keys: change what each key does", _keys_panel)
	_button(menu_box, "Back to the camp  (Esc)", func() -> void: _show_menu(false))
	_button(menu_box, "Quit", get_tree().quit)

func _go(extra: Dictionary) -> void:
	Launch.left_camp = Time.get_ticks_msec()
	var s := get_tree().root.get_node_or_null("Session")
	if s:
		multiplayer.multiplayer_peer = null
		s.free()
	Launch.args = extra.merged({name = profile.name})
	Launch.last_activity = Rules.activities.get(extra.get("activity", ""), {}).get("door", extra.get("activity", ""))
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

## Where you are from sets how you are first drawn: the dress of the place and the
## look of its people (you can change any of it). [f dress, m dress, style].
const ORIGIN_LOOKS := {
	two_rivers = ["two_rivers_f", "two_rivers_m", {skin = 2, hair_col = 1, eyes = 0, height = 2, build = 3}],
	aiel = ["aiel_f", "aiel_m", {skin = 2, hair_col = 5, eyes = 2, height = 4, build = 2}],
	cairhien = ["cairhien_f", "cairhien_m", {skin = 1, hair_col = 0, eyes = 4, height = 0, build = 1}],
	domani = ["domani_f", "merchant", {skin = 3, hair_col = 4, eyes = 0, height = 2, build = 2}],
	borderlands = ["armswoman", "shienaran", {skin = 0, hair_col = 0, eyes = 2, height = 3, build = 3}],
	tar_valon = ["novice", "dedicated", {skin = 0, hair_col = 3, eyes = 1, height = 2, build = 2}],
}
const CALLING_NOTES := {channeller = "Weaves the One Power. Strength is rolled each round.", warder = "Sword and bond. Tough, quick, hard to kill.",
	aiel = "Spear and knife. Fastest on their feet.", hunter = "Bow and staff. Strikes from afar."}

## A small drawn icon: a weave's threads, a weapon, or a Power's colour.
class Icon extends Control:
	var kind := ""
	var arg: Variant = null
	func _init(k: String, a: Variant) -> void:
		kind = k; arg = a
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"weave": Glyph.weave(self, c, 17.0, arg)
			"weapon": Glyph.weapon(self, c, 17.0, arg)
			"element":
				draw_circle(c, 15.0, Color(Glyph.INK, 0.9))
				draw_circle(c, 9.0, arg)
			"text":
				draw_circle(c, 17.0, Color(Glyph.INK, 0.9))
				draw_arc(c, 17.0, 0.0, TAU, 32, Color(Glyph.GOLD, 0.7), 1.5, true)
				Glyph.text(self, Glyph.serif(), c + Vector2(0, 7), arg, 20, Glyph.GOLD, 0)

## A choice as a card: an icon, a name, a line under it; gold-edged when chosen.
func _card(v: Control, title: String, sub: String, icon: Icon, on: bool, pressed: Callable, enabled := true) -> Button:
	var b := Button.new(); v.add_child(b)
	b.toggle_mode = false; b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		sb.bg_color = Color(Glyph.GOLD, 0.16) if on else (Color(1, 1, 1, 0.07) if st == "hover" else Color(1, 1, 1, 0.03))
		sb.border_color = Color(Glyph.GOLD, 0.9) if on else Color(1, 1, 1, 0.12 if st != "hover" else 0.3)
		sb.set_border_width_all(2 if on else 1)
		if st == "disabled":
			sb.bg_color = Color(0, 0, 0, 0.2); sb.border_color = Color(1, 1, 1, 0.05)
		b.add_theme_stylebox_override(st, sb)
	var h := HBoxContainer.new(); b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8; h.offset_right = -8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	if icon:
		h.add_child(icon)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tv := VBoxContainer.new(); h.add_child(tv)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_theme_constant_override("separation", 0)
	var t := Label.new(); t.text = title; tv.add_child(t)
	t.add_theme_font_override("font", Glyph.serif()); t.add_theme_font_size_override("font_size", 16)
	# Long names are cut to the card, not let run into the next one.
	t.clip_text = true; t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.clip_contents = true
	b.tooltip_text = title
	t.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85) if enabled else Color(0.5, 0.5, 0.52))
	if sub != "":
		var s := Label.new(); s.text = sub; tv.add_child(s)
		s.add_theme_font_size_override("font_size", 12); s.add_theme_color_override("font_color", Color(0.66, 0.66, 0.7))
		s.clip_text = true; s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(pressed)
	return b

func _grid(v: Control, cols := 2) -> GridContainer:
	var g := GridContainer.new(); g.columns = cols; v.add_child(g)
	g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6)
	return g

## A value with − and + buttons and a pip bar.
func _stepper(v: Control, label: String, col: Color, value: int, of: int, change: Callable) -> void:
	var h := HBoxContainer.new(); v.add_child(h)
	h.add_theme_constant_override("separation", 6)
	var l := Label.new(); l.text = label; h.add_child(l); l.custom_minimum_size.x = 92
	l.add_theme_font_size_override("font_size", 15); l.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.35))
	for k in of:
		var pip := ColorRect.new(); pip.custom_minimum_size = Vector2(13, 10); h.add_child(pip)
		pip.color = col if k < value else Color(1, 1, 1, 0.08)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	for d in [-1, 1]:
		var b := Button.new(); b.text = "−" if d < 0 else "+"; h.add_child(b)
		b.custom_minimum_size = Vector2(28, 26); b.focus_mode = Control.FOCUS_NONE
		var dd: int = d
		b.pressed.connect(func() -> void: change.call(dd))

var gifts: VBoxContainer          # the right-hand panel while making a character

func _gifts_panel() -> VBoxContainer:
	if gifts == null or not is_instance_valid(gifts):
		var root: Control = side.get_parent().get_parent().get_parent()
		gifts = _column(root, 1.0, -444, -24).get_meta("box")
	_clear(gifts)
	gifts.get_parent().get_parent().visible = true
	return gifts

func _close_gifts() -> void:
	if gifts != null and is_instance_valid(gifts):
		gifts.get_parent().get_parent().queue_free()
	gifts = null

## Making a character: who you are and how you look on the left, your gifts on the
## right, the character standing between them.
func _creation(cls_ := "channeller", name_ := "", power_ := "", origin_ := "") -> void:
	creating = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	profile = {}
	for d in doors:
		d.node.queue_free()
	doors = []
	_clear(side)
	var fighter := cls_ != "channeller"
	var power: String = power_ if power_ != "" else ("saidin" if cls_ == "warder" else "saidar")
	var origin: String = origin_ if origin_ != "" else ("aiel" if cls_ == "aiel" else "two_rivers")
	var keep_aff: Dictionary = make.get("aff_vals", {}) if make.get("cls_id", "") == cls_ and make.get("power_id", "") == power else {}
	make = {cls_id = cls_, power_id = power, origin_id = origin, aff_vals = {}, weapons = {}, forms = {}, stats = {}, talent = "", trade = false}
	_text(side, "A new character", 28)
	make.name = LineEdit.new(); make.name.placeholder_text = "Name"; make.name.text = name_; side.add_child(make.name)
	make.name.add_theme_font_size_override("font_size", 18)
	_section(side, "Calling")
	var g := _grid(side, 2)
	for c in Rules.CLASSES:
		var cc: String = c
		var icon := Icon.new("weave", {fire = 1, air = 1, water = 1}) if c == "channeller" else Icon.new("weapon", Rules.weapons[Rules.CLASSES[c].kit[0]].family)
		_card(g, Rules.CLASSES[c].name, "", icon, c == cls_, func() -> void: _creation.call_deferred(cc, make.name.text, "", ""))
	_text(side, CALLING_NOTES.get(cls_, ""), 13, Color(0.66, 0.67, 0.72))
	_section(side, "The One Power" if not fighter else "Born")
	var pg := _grid(side, 2)
	for pw in ["saidar", "saidin"]:
		var pp: String = pw
		var label: String = ("Saidar" if pw == "saidar" else "Saidin") if not fighter else ("A woman" if pw == "saidar" else "A man")
		var sub: String = ("women · Air, Water" if pw == "saidar" else "men · Earth, Fire") if not fighter else ""
		_card(pg, label, sub, Icon.new("element", Glyph.TINT.water if pw == "saidar" else Glyph.TINT.fire) if not fighter else null, pw == power, func() -> void: _creation.call_deferred(make.cls_id, make.name.text, pp, make.origin_id))
	_section(side, "Origin")
	var og := _grid(side, 2)
	for o in ORIGINS:
		var oo: String = o
		_card(og, ORIGINS[o], "", null, o == origin, func() -> void: _creation.call_deferred(make.cls_id, make.name.text, make.power_id, oo))
	# Appearance, folded away until wanted.
	_section(side, "Appearance")
	var preset: Array = ORIGIN_LOOKS.get(origin, ORIGIN_LOOKS.two_rivers)
	make.look = _option(side, "Dress", {})
	make.power = _PowerShim.new(power)
	_fill_looks()
	var want_look: String = ({warder = "warder", aiel = "aiel_" + ("f" if power == "saidar" else "m")}.get(cls_, preset[0] if power == "saidar" else preset[1]))
	for i in make.look.item_count:
		if make.look.get_item_metadata(i) == want_look:
			make.look.select(i)
	make.style = _style_options(side, preset[2], power == "saidin")
	if _saved().size() > 0:
		_button(side, "Back", func() -> void: _select(_saved()[0]))
	# The gifts.
	var gv := _gifts_panel()
	_text(gv, "Gifts", 28)
	if not fighter:
		_section(gv, "Affinity")
		_text(gv, "How readily each Power answers. Moving a point costs two taken from elsewhere.", 13, Color(0.66, 0.67, 0.72))
		var base := Profile.default_aff(power)
		for e in Rules.ELEMENTS:
			make.aff_vals[e] = int(keep_aff.get(e, base[e]))
		make.aff_box = VBoxContainer.new(); gv.add_child(make.aff_box)
		_section(gv, "Or be born with a Talent")
		_text(gv, "Give up all five points, once and only now, to keep a Talent for good.", 13, Color(0.66, 0.67, 0.72))
		make.talent_box = _grid(gv, 2)
	else:
		if cls_ == "aiel":
			_section(gv, "Society  (free)")
			_text(gv, "The warrior society you belong to. Women who take the spear are Maidens; men join any other.", 13, Color(0.66, 0.67, 0.72))
			make.soc_box = _grid(gv, 1)
		elif cls_ == "hunter":
			_section(gv, "Kit  (sets out the weapons; whole, a start in each)")
			_text(gv, "Where your arms come from. Taken whole, you begin a level up in each of them.", 13, Color(0.66, 0.67, 0.72))
			make.kit_box = _grid(gv, 1)
		_section(gv, "Weapons  (1 point each)")
		make.weapon_box = _grid(gv, 2)
		var probe := {cls = cls_}
		# You set out with the plain weapon that begins each line of the tree (or what
		# your calling or a Hunter's kit carries); better ones are worked out on the
		# tree. Earned weapons are won, not chosen.
		var starts: Array = Rules.CLASSES[cls_].kit.duplicate()
		if cls_ == "hunter":
			for k in Rules.KITS: starts.append_array(Rules.KITS[k].weapons)
		for w in Rules.weapons:
			if w.begins_with("_") or w == "practice_sword": continue
			var root: bool = Rules.weapons[w].get("needs", []).is_empty()
			if Rules.wield_block(probe, w) == "" and not Rules.weapons[w].get("earned", false) and (root or starts.has(w)):
				make.weapons[w] = Rules.CLASSES[cls_].kit.slice(0, 2).has(w)
		_section(gv, "Forms  (2 points each; the first of each tree)")
		make.form_box = _grid(gv, 1)
		for f in Rules.forms:
			if Rules.forms[f].get("needs", []).is_empty():
				make.forms[f] = false
		_section(gv, "Body  (1 point each, 2 at most)")
		make.stat_box = VBoxContainer.new(); gv.add_child(make.stat_box)
		for st in ["might", "quickness", "endurance"]:
			make.stats[st] = 0
		_section(gv, "A gift  (free: one, or none)")
		_text(gv, "What a fighter is born with, as a channeller is born with a Talent.", 13, Color(0.66, 0.67, 0.72))
		make.gift_box = _grid(gv, 1)
	make.left = _text(gv, "", 16)
	make.go = _button(gv, "Begin", _create)
	make.go.custom_minimum_size.y = 40
	make.go.add_theme_font_size_override("font_size", 18)
	_refresh_gifts()
	_creation_changed()

## Something for code that asks make.power which half of the Source this is.
class _PowerShim:
	var id := ""
	func _init(p: String) -> void: id = p
	func get_selected_metadata() -> String: return id

func _refresh_gifts() -> void:
	if make.cls_id == "channeller":
		_clear(make.aff_box)
		for e in Rules.ELEMENTS:
			var ee: String = e
			_stepper(make.aff_box, e.capitalize(), Glyph.TINT.get(e, Glyph.GOLD), int(make.aff_vals[e]) if not make.trade else 0, Profile.AFF_OWN_MAX, func(d: int) -> void:
				if make.trade: return
				make.aff_vals[ee] = clampi(int(make.aff_vals[ee]) + d, 0, Profile.AFF_OWN_MAX)
				_refresh_gifts(); _creation_changed())
		_clear(make.talent_box)
		for t in Profile.TALENTS:
			if Rules.talent_book(t) > Settings.book_limit():
				continue   # from a later book than this player has read
			var tt: String = t
			_card(make.talent_box, t.capitalize(), "", null, make.trade and make.talent == t, func() -> void:
				if make.trade and make.talent == tt:
					make.trade = false; make.talent = ""
				else:
					make.trade = true; make.talent = tt
				_refresh_gifts(); _creation_changed())
	else:
		_clear(make.gift_box)
		for gid in Rules.GIFTS:
			var gg: String = gid
			_card(make.gift_box, Rules.GIFTS[gid].name, "chosen" if make.get("gift", "") == gid else "", null, make.get("gift", "") == gid, func() -> void:
				make.gift = "" if make.get("gift", "") == gg else gg
				_refresh_gifts(); _creation_changed())
			var gl := _text(make.gift_box, Rules.GIFTS[gid].blurb, 13, Color(0.7, 0.72, 0.78))
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if make.has("soc_box"):
			_clear(make.soc_box)
			var sex := "f" if make.power_id == "saidar" else "m"
			for sid in Rules.SOCIETIES:
				var sd: Dictionary = Rules.SOCIETIES[sid]
				if sd.sex != sex:
					continue
				var ss: String = sid
				_card(make.soc_box, sd.name, sd.sub, null, make.get("society", "") == sid, func() -> void:
					make.society = "" if make.get("society", "") == ss else ss
					_refresh_gifts(); _creation_changed())
				var sl := _text(make.soc_box, sd.blurb, 13, Color(0.7, 0.72, 0.78))
				sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if make.has("kit_box"):
			_clear(make.kit_box)
			for kid in Rules.KITS:
				var kd: Dictionary = Rules.KITS[kid]
				var kk: String = kid
				var whole: bool = kd.weapons.all(func(w: String) -> bool: return make.weapons.get(w, false))
				_card(make.kit_box, kd.name, ", ".join(kd.weapons.map(func(w: String) -> String: return Rules.weapons[w].name)), null, whole, func() -> void:
					# One kit at a time: its weapons in, any others out.
					for w in make.weapons:
						make.weapons[w] = kd.weapons.has(w)
					make.hunter_kit = kk
					_refresh_gifts(); _creation_changed())
				var kl := _text(make.kit_box, kd.blurb, 13, Color(0.7, 0.72, 0.78))
				kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_clear(make.weapon_box)
		var fams := {}
		for w in make.weapons:
			var ww: String = w
			if make.weapons[w]: fams[Rules.weapons[w].family] = true
			_card(make.weapon_box, Rules.weapons[w].name, Rules.weapons[w].family, Icon.new("weapon", Rules.weapons[w].family), make.weapons[w], func() -> void:
				make.weapons[ww] = not make.weapons[ww]
				# One weapon of a kind: choosing one puts down the other.
				if make.weapons[ww]:
					for o in make.weapons:
						if o != ww and Rules.weapons[o].family == Rules.weapons[ww].family: make.weapons[o] = false
				_refresh_gifts(); _creation_changed())
		_clear(make.form_box)
		for f in make.forms:
			var ff: String = f
			var ok: bool = fams.has(Rules.forms[f].family)
			if not ok: make.forms[f] = false
			_card(make.form_box, Rules.forms[f].name, Rules.forms[f].family, null, make.forms[f], func() -> void:
				make.forms[ff] = not make.forms[ff]
				_refresh_gifts(); _creation_changed(), ok)
		_clear(make.stat_box)
		for st in ["might", "quickness", "endurance"]:
			var s2: String = st
			_stepper(make.stat_box, st.capitalize(), Glyph.GOLD, int(make.stats[st]), 2, func(d: int) -> void:
				make.stats[s2] = clampi(int(make.stats[s2]) + d, 0, 2)
				_refresh_gifts(); _creation_changed())

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
	for f in Hero.FACE:
		var items := {}
		for i in 5:
			items[i - 2] = f[2][i]
		out[f[0]] = _option(parent, f[1], items)
		out[f[0]].select(clampi(int(style.get(f[0], 0)) + 2, 0, 4))
	var cloaks := {"": "As the dress wears it"}
	for id in Hero.CLOAKS:
		cloaks[id] = Hero.CLOAKS[id][0]
	out.cloak = _option(parent, "Cloak", cloaks)
	out.cloak.select(maxi(cloaks.keys().find(str(style.get("cloak", ""))), 0))
	var lens := {}
	for i in Hero.CLOAK_LENGTHS.size():
		lens[i] = Hero.CLOAK_LENGTHS[i][0]
	out.cloak_len = _option(parent, "Cloak length", lens)
	out.cloak_len.select(clampi(int(style.get("cloak_len", 0)), 0, lens.size() - 1))
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
	for f in Hero.FACE:
		if int(w[f[0]].get_selected_metadata()) != 0:
			st[f[0]] = int(w[f[0]].get_selected_metadata())
	if w.cloak.get_selected_metadata() != "":
		st.cloak = w.cloak.get_selected_metadata()
	if int(w.cloak_len.get_selected_metadata()) > 0:
		st.cloak_len = int(w.cloak_len.get_selected_metadata())
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
func _weapon_option(label: String, start: String, none: bool, parent: Control = null, cls_id := "", owned_only := false) -> OptionButton:
	var items := {}
	if none:
		items[""] = "Nothing"
	var probe := {cls = cls_id if cls_id != "" else make.cls_id, stats = {might = 8}}
	for w in Rules.weapons:
		if w.begins_with("_"): continue
		# Earned weapons only once they are this character's own; in the armoury only
		# what is yours (better ones are worked out on the weapon tree).
		var mine: bool = profile.get("weapons_owned", profile.get("kit", [])).has(w) or profile.get("kit", []).has(w)
		if owned_only and not mine:
			continue
		if Rules.wield_block(probe, w) == "" and (not Rules.weapons[w].get("earned", false) or mine) and w != "hands":
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
	_text(menu_box, "%s carries %d. These are the weapons you own, one of each kind; better ones are worked out on the weapon tree (T)." % ["A " + Rules.CLASSES[c].name.to_lower(), int(Rules.CLASSES[c].carry)], 14, Color(0.7, 0.72, 0.78))
	var picks := []
	for i in int(Rules.CLASSES[c].carry):
		picks.append(_weapon_option(["In hand", "Second", "Third"][i], profile.kit[i] if i < profile.kit.size() else "", true, menu_box, c, true))
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

## What is left to place: for a channeller, trade points (removed less twice added);
## for a fighter, of the six points.
func _points_left() -> float:
	if make.cls_id == "channeller":
		if make.trade:
			return 0.0
		return float(Profile.trade_left(Profile.default_aff(make.power_id), make.aff_vals))
	var spent := 0.0
	for w in make.weapons:
		if make.weapons[w]: spent += 1.0
	for f in make.forms:
		if make.forms[f]: spent += 2.0
	var st := 0.0
	for k in make.stats:
		st += make.stats[k]
	if st > 2.0:
		return -1.0
	return float(Profile.FIGHTER_POINTS) - spent - st

func _creation_changed() -> void:
	if not make.has("go"):
		return
	var left := _points_left()
	var nweap := 0
	for w in make.weapons:
		if make.weapons[w]: nweap += 1
	if make.cls_id == "channeller":
		make.left.text = ("Born with the Talent for %s: no affinity" % make.talent.capitalize().to_lower()) if make.trade else ("Points to place: %d" % int(left) if left >= 0 else "Too many points added: each costs two taken elsewhere")
	else:
		make.left.text = "Points left: %d of %d" % [int(left), Profile.FIGHTER_POINTS] if left >= 0 else "Too many points (and at most two in the body)"
		if nweap == 0:
			make.left.text += "\nChoose at least one weapon"; left = -1.0
		elif nweap > Profile.WEAPON_SLOTS:
			make.left.text += "\nAt most %d weapons" % Profile.WEAPON_SLOTS; left = -1.0
	make.left.add_theme_color_override("font_color", Color(1, 0.45, 0.35) if left < 0 else Glyph.GOLD)
	make.go.disabled = left < 0
	var kind: String = make.look.get_selected_metadata()
	var held := ""
	for w in make.weapons:
		if make.weapons[w]:
			held = w; break
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
	if name_ == "" or _points_left() < 0 or make.go.disabled:
		make.left.text = "A name is needed." if name_ == "" else make.left.text
		return
	var power: String = make.power_id
	var opts := {name = name_, cls = make.cls_id, power = power, sex = "f" if power == "saidar" else "m", origin = make.origin_id,
		look = make.look.get_selected_metadata(), style = _style_of(make.style)}
	if make.cls_id == "channeller":
		opts.aff_pts = make.aff_vals.duplicate()
		if make.trade:
			opts.talent = make.talent
	else:
		var kit := []; var forms := []
		for w in make.weapons:
			if make.weapons[w]: kit.append(w)
		for f in make.forms:
			if make.forms[f]: forms.append(f)
		opts.kit = kit; opts.forms = forms; opts.stats = make.stats.duplicate()
		opts.gift = make.get("gift", "")
		opts.society = make.get("society", "")
		# The kit counts only if its weapons are all still chosen (create_fighter checks).
		for kid in Rules.KITS:
			if Rules.KITS[kid].weapons.all(func(w: String) -> bool: return kit.has(w)):
				opts.hunter_kit = kid
	var p := Profile.make(opts)
	Profile.save(p)
	Launch.report = []
	_close_gifts()
	_select(name_)

# --- doorways you can see through --------------------------------------------------
# Coming up to an open doorway, its fight is built in a world of its own (a
# SubViewport) and shown on the doorway from where the camera would stand over
# there. Your feet crossing hands your body to that fight; your camera crossing
# makes that world the one you are in. Nothing loads at the threshold.
var _pre := {}       # {door, vp, game, A (this side's frame), mat, live}
var _phase := 0      # 0 looking through, 1 your feet are through
var cam_x := -1.1    # the camera's sideways offset (eases to 0 near a doorway)
var _cloak_speed := 0.0
var cam_back := 4.6  # and how far behind (eases back after coming home through a gateway)
var returning := false   # built as the far side of a fight's gateway home (driven from there)
var _came_from := ""     # the doorway just come home through: not opened again till you walk off

func _door_by_id(id: String) -> Dictionary:
	for d in doors:
		if d.id == id:
			return d
	return {}

## The far side of a gateway home: the doorway you left by, facing into the camp.
func home_frame() -> Transform3D:
	var d := _door_by_id(Launch.last_activity)
	if d.is_empty():
		return Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), _ground(Vector3(0, 0, -14)))
	var f: Vector3 = -(d.at as Vector3).normalized()
	return Transform3D(Basis.looking_at(f, Vector3.UP), _ground(d.at))

func drive_camera(xf: Transform3D, fov: float, near: float) -> void:
	cam.global_transform = xf
	cam.fov = fov
	cam.near = near

## The body coming home, as the fight sees it, mapped through.
func place_body(xf: Transform3D, clip: String, at: float) -> void:
	model.global_transform = xf
	var ap: AnimationPlayer = model.get_meta("anim")
	if ap.has_animation(clip):
		if ap.current_animation != clip:
			ap.play(clip)
		ap.seek(at, true)

## The camera is through: the camp is the world now, the camera where it was.
func enter_from_fight(yaw: float, pitch: float, body: Transform3D, offset_x: float, back: float) -> void:
	returning = false
	side.get_parent().get_parent().visible = true
	cam_yaw = yaw; cam_pitch = pitch
	cam_x = offset_x; cam_back = back
	pos = Vector3(body.origin.x, 0, body.origin.z)
	face = body.basis.get_euler().y
	cam.near = 0.05; cam.current = true
	_came_from = Launch.last_activity
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(true)

## This side of a doorway: at its sill, -Z the way through (away from the camp).
func _door_frame(d: Dictionary) -> Transform3D:
	var f: Vector3 = (d.at as Vector3).normalized()
	return Transform3D(Basis.looking_at(f, Vector3.UP), _ground(d.at))

func _door_mat(d: Dictionary) -> ShaderMaterial:
	for c in (d.node as Node).find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).material_override is ShaderMaterial:
			return (c as MeshInstance3D).material_override
	return null

## The doorway view is drawn smaller than the screen (it is only a window).
func _portal_scale() -> float:
	return [0.5, 0.65, 0.8][clampi(Settings.quality, 0, 2)]

func _open_way(d: Dictionary) -> void:
	_close_way()
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.use_hdr_2d = true
	vp.size = Vector2i(get_viewport().get_visible_rect().size * _portal_scale())
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# One game at a time on the server, everyone in it: whichever doorway you take
	# joins the fight already running, if there is one. Offline if it won't answer.
	# A mode's doorway opens onto a setup chosen now: a different place and foes
	# each time you walk up to it.
	var act: String = d.get("setup", Rules.pick_setup(d.id))
	# A fight already running behind this doorway is the one it opens onto (the
	# server ignores our pick then); the fight says which setup it is when it starts.
	for f in fights:
		if String(f.get("room", "")) == d.id and Rules.activities.has(String(f.get("activity", ""))):
			act = f.activity
	var a := {activity = act, name = profile.name, preview = "1"}
	if (reachable or cl.has("ghost")) and not cl.has("offline"):
		a.join = Launch.server(); a.word = online.get("word", ""); a.room = d.id
	if cl.has("stroll"):
		a.walk_in = "1"
	Launch.args = a
	Launch.last_activity = d.id    # the doorway, so you step back out of it
	Launch.report = []
	Launch.left_camp = Time.get_ticks_msec()
	var t0 := Time.get_ticks_msec()
	var scene: PackedScene = ResourceLoader.load_threaded_get(GAME_SCENE) if ResourceLoader.load_threaded_get_status(GAME_SCENE) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(GAME_SCENE)
	var g: Node3D = scene.instantiate()
	if cl.has("timing"): print("TIMING camp: game scene instantiated in %d ms" % (Time.get_ticks_msec() - t0))
	vp.add_child(g)
	if cl.has("timing"): print("TIMING camp: game scene ready in %d ms" % (Time.get_ticks_msec() - t0))
	_pre = {door = d, vp = vp, game = g, A = _door_frame(d), mat = _door_mat(d), live = 0.0}
	if _pre.mat:
		_pre.mat.set_shader_parameter("view", vp.get_texture())
		_pre.mat.set_shader_parameter("live", 0.0)

func _close_way() -> void:
	if _pre.is_empty():
		return
	if _pre.mat:
		_pre.mat.set_shader_parameter("live", 0.0)
	multiplayer.multiplayer_peer = null
	_pre.vp.queue_free()
	_pre = {}
	# Its world set the shared ground and walls to its own: put the camp's back.
	Map.set_state(_ctx)

func _dyaw() -> float:
	return (_pre.game.gate_frame as Transform3D).basis.get_euler().y - (_pre.A as Transform3D).basis.get_euler().y

## Each frame, after the camp's camera has moved.
func _portal(dt: float) -> void:
	if _phase == 0:
		var best := {}
		for d in doors:
			if d.id == _came_from and pos.distance_to(d.at) < 11.0:
				continue
			if d.open and pos.distance_to(d.at) < 10.0 and (best.is_empty() or pos.distance_to(d.at) < pos.distance_to(best.at)):
				best = d
		if _came_from != "" and pos.distance_to(_door_by_id(_came_from).get("at", Vector3(999, 0, 999))) >= 11.0:
			_came_from = ""
		# Heading for another doorway: build that one behind instead.
		if not _pre.is_empty() and (pos.distance_to(_pre.door.at) > 13.0 or (not best.is_empty() and best.id != _pre.door.id and pos.distance_to(best.at) < 7.0 and pos.distance_to(best.at) + 1.5 < pos.distance_to(_pre.door.at))):
			_close_way()
		if _pre.is_empty() and not best.is_empty():
			_open_way(best)
	if _pre.is_empty():
		return
	var g: Node3D = _pre.game
	_pre.vp.size = Vector2i(get_viewport().get_visible_rect().size * _portal_scale())
	# Seen from afar the view is small and slow to notice: refresh it every other frame.
	_pre.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if (Engine.get_process_frames() % 2 == 0 or pos.distance_to(_pre.door.at) < 6.0) else SubViewport.UPDATE_DISABLED
	if not g.portal_ready():
		return
	_pre.live = move_toward(_pre.live, 1.0, dt * 2.5)
	if _pre.mat:
		_pre.mat.set_shader_parameter("live", _pre.live)
	var A: Transform3D = _pre.A
	var M: Transform3D = g.gate_frame * A.affine_inverse()
	var fwd := -A.basis.z
	var cam_in := (cam.global_position - A.origin).dot(fwd)
	g.drive_camera(M * cam.global_transform, cam.fov, absf(cam_in))
	var feet_in := (pos - A.origin).dot(fwd)
	if _phase == 0:
		# The body over there is the camp's, mapped through: the half of you past
		# the threshold is seen through the doorway, in step.
		var ap: AnimationPlayer = model.get_meta("anim")
		g.stand_in = {xf = M * model.global_transform, clip = ap.current_animation, at = ap.current_animation_position}
		# Only once you reach the threshold: further back it would stand between the
		# far camera and the doorway's view.
		g.me.visible = feet_in > -0.6
		if feet_in > 0.6:
			# Your feet are through: the body over there is yours now.
			_phase = 1
			g.me.visible = true
			model.visible = false
			side.get_parent().get_parent().visible = false
			g.take_control(cam_yaw + _dyaw(), cam_pitch)
	else:
		# The camera follows the body over there, mapped back to this side; mouse
		# look stays here until the camera is through too.
		var back: Vector3 = M.affine_inverse() * (g.me.position as Vector3)
		pos = Vector3(back.x, 0, back.z)
		g.cam_yaw = cam_yaw + _dyaw(); g.cam_pitch = cam_pitch
		# Swapped a hair before the camera reaches the threshold: one frame drawn past
		# it would show the camp's own far side.
		if cam_in > -0.3:
			set_process(false)
			_swap.call_deferred()

## The camera is through: the far world becomes the one you are in, the camera
## exactly where it was, and the camp goes.
func _swap() -> void:
	var g: Node3D = _pre.game
	var A: Transform3D = _pre.A
	var M: Transform3D = g.gate_frame * A.affine_inverse()
	g.drive_camera(M * cam.global_transform, cam.fov, 0.1)
	var yaw := cam_yaw + _dyaw()
	g.moving_worlds = true
	_pre.vp.remove_child(g)
	var tree := get_tree()
	var root := tree.root
	root.remove_child(self)    # the camp's sky and sun leave with it
	root.add_child(g)
	tree.current_scene = g
	g.moving_worlds = false
	g.enter_world(yaw, cam_pitch, Vector3(cam_x, 0.2, 4.6), cam.fov)
	queue_free()
