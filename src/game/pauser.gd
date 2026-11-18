extends Node
## Escape: the pause menu. Offline the world stops while it is open; online the
## fight goes on for the others. One of its rows hides it (and everything else on
## the screen) with the game still paused, for a clean screenshot; Escape brings it
## back. It keeps listening while the tree is paused; the fight does not.
var g: Node
var layer: CanvasLayer
var card: PanelContainer
var box: VBoxContainer
var hidden_shot := false
var binding := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new(); layer.layer = 30; add_child(layer)
	card = Glyph.card(Color(Glyph.GOLD, 0.45), 0.9); layer.add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -190; card.offset_right = 190; card.offset_top = -230; card.offset_bottom = 230
	var scroll := ScrollContainer.new(); card.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box = VBoxContainer.new(); scroll.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	card.visible = false

func is_open() -> bool:
	return card.visible or hidden_shot

func _unhandled_input(ev: InputEvent) -> void:
	if binding != -1 and ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.physical_keycode != KEY_ESCAPE:
			Keys.bind(binding as Key, ev.physical_keycode)
		binding = -1
		get_viewport().set_input_as_handled()
		_keys()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if hidden_shot:
			hidden_shot = false
			_show_all(true)
			_main()
		elif card.visible:
			close()
		else:
			open()

func open() -> void:
	if g.can_pause():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	card.visible = true
	_main()

func close() -> void:
	card.visible = false
	hidden_shot = false
	_show_all(true)
	get_tree().paused = false
	if not g.args.has("auto") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_all(on: bool) -> void:
	if g.hud_layer: g.hud_layer.visible = on
	var t := get_tree().root.get_node_or_null("Toasts") as CanvasLayer
	if t: t.visible = on

func _clear() -> void:
	for c in box.get_children():
		c.queue_free()

func _title(text: String) -> void:
	var l := Label.new(); l.text = text; box.add_child(l)
	l.add_theme_font_override("font", Glyph.serif()); l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))

func _note(text: String) -> void:
	var l := Label.new(); l.text = text; box.add_child(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 13); l.add_theme_color_override("font_color", Color(0.66, 0.67, 0.72))

func _row(text: String, on: Callable) -> Button:
	var b := Button.new(); b.text = text; box.add_child(b)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 34
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(on)
	return b

func _main() -> void:
	_clear()
	_title("Paused" if get_tree().paused else "Menu")
	if not get_tree().paused:
		_note("Online: the fight goes on while this is open.")
	_row("Resume  (Esc)", close)
	_row("Hide everything (for a screenshot)", func() -> void:
		card.visible = false
		hidden_shot = true
		_show_all(false))
	_row("Keys", _keys)
	_row("Sound", _sound)
	_row("Back to the camp", func() -> void:
		close()
		g._to_camp())
	_row("Quit the game", func() -> void: get_tree().quit())

func _keys() -> void:
	_clear()
	_title("Keys")
	_note("Press a row, then the key you want (Esc keeps the old one).")
	for a in Keys.ACTIONS:
		var dk: Key = a[0]
		_row("%s:   %s" % [a[1], "press a key…" if binding == int(dk) else Keys.name(dk)], func() -> void:
			binding = int(dk)
			_keys())
	_row("Put every key back", func() -> void:
		Keys.reset()
		_keys())
	_row("Back", _main)

func _sound() -> void:
	_clear()
	_title("Sound")
	var h := HBoxContainer.new(); box.add_child(h)
	var l := Label.new(); l.text = "Volume"; h.add_child(l); l.custom_minimum_size.x = 80
	var s := HSlider.new(); h.add_child(s); s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.min_value = 0.0; s.max_value = 1.0; s.step = 0.05; s.value = Settings.volume
	s.value_changed.connect(func(v: float) -> void:
		Settings.volume = v
		Settings.apply()
		Settings.save())
	_row("Back", _main)
