class_name Toast
## Small notices that slide in at the top right and fade, in place of words across
## the middle of the screen. They live under the tree's root, so one raised just
## before a scene change (the server could not be reached) is still read after it.
##   Toast.say("Can't reach the server", "You are playing offline.", "warn")

const KINDS := {info = Color(0.79, 0.64, 0.35), warn = Color(0.95, 0.45, 0.25), good = Color(0.45, 0.8, 0.55), shadow = Color(0.7, 0.25, 0.25)}
const MAX := 4

static func _stack() -> VBoxContainer:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.root.get_node_or_null("Toasts") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new(); layer.name = "Toasts"; layer.layer = 50
		tree.root.add_child(layer)
		var v := VBoxContainer.new(); v.name = "Stack"; layer.add_child(v)
		v.anchor_left = 1.0; v.anchor_right = 1.0
		v.offset_left = -320; v.offset_right = -20; v.offset_top = 20
		v.add_theme_constant_override("separation", 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer.get_node("Stack")

## title: one short line; body: optional detail under it; kind: info|warn|good|shadow.
## The same title shown again while it is still up only renews it.
static func say(title: String, body := "", kind := "info", secs := 4.5) -> void:
	if DisplayServer.get_name() == "headless":
		print("TOAST %s%s" % [title, (": " + body) if body != "" else ""])
		return
	var v := _stack()
	for c in v.get_children():
		if c.get_meta("title", "") == title and not c.is_queued_for_deletion():
			c.set_meta("left", secs)
			return
	while v.get_child_count() >= MAX:
		var old := v.get_child(0); v.remove_child(old); old.queue_free()
	var col: Color = KINDS.get(kind, KINDS.info)
	var card := PanelContainer.new(); card.set_meta("title", title); card.set_meta("left", secs)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.06, 0.06, 0.08, 0.88)
	sb.border_color = col; sb.border_width_left = 3; sb.set_corner_radius_all(4)
	sb.content_margin_left = 11; sb.content_margin_right = 11; sb.content_margin_top = 6; sb.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 2); card.add_child(box)
	var t := Label.new(); t.text = title; box.add_child(t)
	t.add_theme_font_override("font", Glyph.serif()); t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.97, 0.94, 0.88))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if body != "":
		var b := Label.new(); b.text = body; box.add_child(b)
		b.add_theme_font_size_override("font_size", 12); b.add_theme_color_override("font_color", Color(0.74, 0.74, 0.78))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(card)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.18)
	var timer := Timer.new(); card.add_child(timer); timer.wait_time = 0.25; timer.start()
	timer.timeout.connect(func() -> void:
		card.set_meta("left", float(card.get_meta("left")) - 0.25)
		if float(card.get_meta("left")) <= 0.0 and not card.has_meta("going"):
			card.set_meta("going", true)
			var tw := card.create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.35)
			tw.tween_callback(card.queue_free))

## Take everything down (a scene that wants a clean screen, e.g. the end of a fight).
static func clear() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.root.get_node_or_null("Toasts")
	if layer:
		for c in layer.get_node("Stack").get_children():
			c.queue_free()
