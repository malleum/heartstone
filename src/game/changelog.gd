class_name Changelog
## What changed in the last few versions (data/changelog.json), for the Esc menus: a
## line per version that opens to show its bullet points. The newest starts open.

static func entries() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/changelog.json")) if FileAccess.file_exists("res://data/changelog.json") else null
	return d if d is Array else []

## Fill `box` with the list. `width`: how wide the bullet text may run.
static func build(box: VBoxContainer, width := 380.0) -> void:
	var first := true
	for e in entries():
		if not e is Dictionary:
			continue
		var head := Button.new()
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT; head.focus_mode = Control.FOCUS_NONE
		head.flat = true
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Glyph.GOLD)
		head.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
		box.add_child(head)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 3)
		box.add_child(body)
		for item in e.get("items", []):
			var l := Label.new()
			l.text = "•  " + String(item)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = width
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_color", Color(0.82, 0.83, 0.87))
			body.add_child(l)
		var label := "%s   ·   %s" % [e.get("version", "?"), e.get("date", "")]
		var set_open := func(on: bool) -> void:
			body.visible = on
			head.text = ("▾  " if on else "▸  ") + label
		set_open.call(first)
		head.pressed.connect(func() -> void: set_open.call(not body.visible))
		first = false
