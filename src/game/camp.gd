extends Node3D
## The camp: the hub every activity starts from and returns to. Pick or create a
## character, read how it has grown, choose what to do next, or join a friend.
## It is deliberately a menu over a 3D backdrop for now; a walkable camp can replace
## the backdrop later without touching the flow (profile -> activity -> game -> back).

const ORIGINS := {two_rivers = "Two Rivers", aiel = "Aiel", cairhien = "Cairhien", domani = "Arad Doman", borderlands = "Borderlands", tar_valon = "Tar Valon"}
const TALENT_PICKS := ["healing", "travelling", "cloud_dancing", "earth_singing", "illusion", "dreaming"]

var profile := {}
var model: Node3D
var side: VBoxContainer       # left column: who you are
var board: VBoxContainer      # right column: what you can do
var make := {}                # creation form widgets

func _ready() -> void:
	Rules.load_data()
	var cl := Launch.cmdline()
	if cl.has("auto") or cl.has("activity") or cl.has("join"):
		# Bots, renders and scripted sessions skip the menu.
		Launch.args = cl
		get_tree().change_scene_to_file.call_deferred("res://src/game/game.tscn")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Map.use("open")
	World.build(self, -32.0, -26.0)
	Terrain.amp = 0.25
	add_child(Terrain.build_mesh(120.0, 1.0))
	Scenery.scatter(self)
	Scenery.fire(self, Vector3(-3.4, Terrain.height(-3.4, -4.5), -4.5))
	var cam := Camera3D.new(); cam.fov = 50.0; add_child(cam)
	cam.position = Vector3(0.0, 1.35, 3.6); cam.look_at(Vector3(0.0, 1.0, 0))
	_ui()
	var names := _saved()
	if cl.has("new"):
		_creation()
	elif Launch.last_name != "" and Launch.last_name.to_lower() in names:
		_select(Launch.last_name)
	elif names.size() > 0:
		_select(names[0])
	else:
		_creation()

func _saved() -> Array:
	var out := []
	for f in DirAccess.get_files_at(Profile.dir):
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	return out

# --- layout ---------------------------------------------------------------------------

func _ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var theme := Theme.new(); theme.default_font_size = 17
	var root := Control.new(); root.theme = theme; layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new(); title.text = "HEARTSTONE"; root.add_child(title)
	title.add_theme_font_size_override("font_size", 40); title.position = Vector2(36, 20)
	side = _column(root, 0.0, 36, 430)
	board = _column(root, 1.0, -500, -36)

func _column(root: Control, anchor: float, left: float, right: float) -> VBoxContainer:
	var panel := PanelContainer.new(); root.add_child(panel)
	panel.anchor_left = anchor; panel.anchor_right = anchor; panel.anchor_top = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left = left; panel.offset_right = right; panel.offset_top = 90; panel.offset_bottom = -36
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.06, 0.06, 0.08, 0.78); sb.set_corner_radius_all(8); sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new(); panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new(); scroll.add_child(v)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	return v

func _clear(v: Control) -> void:
	for c in v.get_children():
		c.queue_free()

func _text(v: Control, text: String, size := 17, col := Color(0.9, 0.9, 0.92)) -> Label:
	var l := Label.new(); l.text = text; v.add_child(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	return l

func _button(v: Control, text: String, on: Callable) -> Button:
	var b := Button.new(); b.text = text; v.add_child(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on)
	return b

func _stand(kind: String) -> void:
	if model:
		model.queue_free()
	model = Hero.instantiate(kind, hash(profile.get("name", "")))
	add_child(model)
	model.rotation.y = 0.35
	model.position.y = Terrain.height(0.0, 0.0)
	(model.get_meta("anim") as AnimationPlayer).play("Idle")

# --- an existing character --------------------------------------------------------------

func _select(name_: String) -> void:
	profile = Profile.load_profile(name_)
	Launch.last_name = profile.name
	_stand(Hero.kind_for(profile))
	_clear(side); _clear(board)
	_text(side, profile.name, 28)
	_text(side, "%s  ·  %s  ·  %s" % [profile.power.capitalize(), ORIGINS.get(profile.origin, profile.origin), "%d h %02d m channelling" % [int(profile.seconds / 3600.0), int(profile.seconds / 60.0) % 60]], 15, Color(0.7, 0.72, 0.78))
	_text(side, "Strength %d of %d\nFlows held at once: %d\nRenown %d" % [int(profile.strength), int(profile.potential), Rules.flow_capacity(profile), int(profile.renown)])
	var aff := ""
	for e in Rules.ELEMENTS:
		aff += "%s %d%%   " % [e.capitalize(), int(profile.affinity[e] * 100.0)]
	_text(side, aff, 15)
	if profile.talents.size() > 0:
		_text(side, "Talents: " + ", ".join(profile.talents.map(func(t: String) -> String: return t.capitalize())), 15)
	_text(side, "Weaves", 20)
	for id in profile.weaves:
		if Rules.weaves.has(id):
			_text(side, "%s   mastery %d" % [Rules.weaves[id].name, Rules.mastery_level(profile, id)], 15)
	if Launch.report.size() > 0:
		_text(side, "Last time out", 20)
		_text(side, "\n".join(Launch.report), 15, Color(0.95, 0.85, 0.55))
	_text(side, "Characters", 20)
	for n in _saved():
		if n != profile.name.to_lower():
			_button(side, n.capitalize(), func() -> void: Launch.report = []; _select(n))
	_button(side, "New character…", _creation)

	_text(board, "From the camp", 24)
	var open := Rules.available(profile)
	for id in Rules.activities:
		if id.begins_with("_"):
			continue
		var a: Dictionary = Rules.activities[id]
		if id in open:
			var done: String = "  ✓" if profile.done.has(id) else ""
			_button(board, a.name + done, _go.bind({activity = id}))
			_text(board, a.blurb, 14, Color(0.7, 0.72, 0.78))
		else:
			var need := []
			if a.requires.has("renown"): need.append("renown %d" % a.requires.renown)
			for d in a.requires.get("done", []):
				if not profile.done.has(d): need.append("clear " + Rules.activities[d].name)
			_text(board, "%s\n   needs %s" % [a.name, ", ".join(need)], 15, Color(0.5, 0.5, 0.55))
	_text(board, "Friends", 24)
	_text(board, "Starting anything above hosts it: friends join you by address (UDP port 24680, or a VPN such as Tailscale).", 14, Color(0.7, 0.72, 0.78))
	var addr := LineEdit.new(); addr.placeholder_text = "friend's address"; board.add_child(addr)
	_button(board, "Join a friend", func() -> void:
		if addr.text.strip_edges() != "":
			_go({join = addr.text.strip_edges()}))
	_button(board, "Quit", get_tree().quit)

func _go(extra: Dictionary) -> void:
	Launch.args = extra.merged({name = profile.name})
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

func _creation() -> void:
	_clear(side); _clear(board)
	make = {}
	_text(side, "A new channeller", 26)
	make.name = LineEdit.new(); make.name.placeholder_text = "Name"; side.add_child(make.name)
	make.power = _option(side, "The One Power", {saidar = "Saidar (women)", saidin = "Saidin (men)"})
	make.origin = _option(side, "Origin", ORIGINS)
	make.look = _option(side, "Dress", {})
	# Saidar is women's and saidin men's, so the wardrobe follows the choice.
	make.power.item_selected.connect(func(_i: int) -> void: _fill_looks(); _creation_changed())
	_fill_looks()
	_text(side, "Twenty points, spent once. Potential is how strong you can ever become. Affinity is how readily each Power answers you. A Talent costs four.", 14, Color(0.7, 0.72, 0.78))
	make.potential = _spin(side, "Potential", 14, 8)
	make.aff = {}
	for e in Rules.ELEMENTS:
		make.aff[e] = _spin(side, e.capitalize(), 6, 2 if e in ["air", "water"] else 0)
	_text(side, "Talents", 18)
	make.talents = {}
	for t in TALENT_PICKS:
		var c := CheckBox.new(); c.text = t.capitalize(); side.add_child(c)
		c.toggled.connect(func(_on: bool) -> void: _creation_changed())
		make.talents[t] = c
	make.left = _text(side, "", 18)
	make.go = _button(side, "Begin", _create)
	if _saved().size() > 0:
		_button(side, "Back", func() -> void: _select(_saved()[0]))
	_text(board, "How a channeller grows", 24)
	_text(board, "Nothing here resets. Every watch, every mission and every spar pays into the same character.\n\nWeaving a weave masters it. Weaving a Power strengthens your hold on it. Strength creeps toward your potential.\n\nThe number of flows you can hold at once grows slowly, over many hours. Few Aes Sedai ever hold more than three.\n\nNew weaves are learned by seeing them woven.", 15)
	_creation_changed()

func _fill_looks() -> void:
	var sex := "f" if make.power.get_selected_metadata() == "saidar" else "m"
	make.look.clear()
	var all := Hero.looks()
	for id in all:
		if all[id].sex == sex:
			make.look.add_item(all[id].label); make.look.set_item_metadata(make.look.item_count - 1, id)
	make.look.select(0)

func _points_left() -> int:
	var spent := int(make.potential.value)
	for e in make.aff:
		spent += int(make.aff[e].value)
	for t in make.talents:
		if make.talents[t].button_pressed:
			spent += 4
	return Profile.CREATION_POINTS - spent

func _creation_changed() -> void:
	if not make.has("go"):
		return
	var left := _points_left()
	make.left.text = "Points left: %d" % left
	make.left.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if left < 0 else Color(0.9, 0.9, 0.92))
	make.go.disabled = left < 0
	var kind: String = make.look.get_selected_metadata()
	if model == null or model.get_meta("kind", "") != kind:
		_stand(kind)
		model.set_meta("kind", kind)

func _create() -> void:
	var name_: String = make.name.text.strip_edges()
	if name_ == "" or _points_left() < 0:
		make.left.text = "Your channeller needs a name." if name_ == "" else make.left.text
		return
	var aff := {}
	for e in make.aff:
		aff[e] = int(make.aff[e].value)
	var talents := []
	for t in make.talents:
		if make.talents[t].button_pressed:
			talents.append(t)
	var p := Profile.create({name = name_, power = make.power.get_selected_metadata(), origin = make.origin.get_selected_metadata(),
		look = make.look.get_selected_metadata(), potential_pts = int(make.potential.value), affinity_pts = aff, talents = talents})
	Profile.save(p)
	Launch.report = []
	_select(name_)
