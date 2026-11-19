class_name WeaveTree
extends Control
## The weave tree, drawn as a wheel of the Five Powers. Each Power has its place on
## the rim, where its simplest weave sits; a weave that joins Powers sits between
## them and further in; Balefire, which takes all five, is the hub. Lines run from
## each weave to the ones that must be known first.

signal chosen(id: String)

const ORDER := ["fire", "air", "water", "spirit", "earth"]   # neighbours are the Powers most often woven together
const RADII := [1.0, 0.67, 0.4, 0.2]

var profile := {}
var pickable := false   # in a round: a known weave can be chosen too (to grow it)
var t := 0.0
var hover := ""
var _pos := {}       # weave id -> Vector2
var _for := Vector2.ZERO
var _fam_ang := {}   # forms: weapon family -> angle of the middle of its share

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(dt: float) -> void:
	t += dt
	if visible:
		queue_redraw()

## Laid out for a 720-line screen and scaled to whatever it is shown on.
func _k() -> float:
	return size.y / 720.0

func _sz() -> Vector2:
	return size / _k()

func _centre() -> Vector2:
	return Vector2(_sz().x * 0.4, _sz().y * 0.52)

func _radius() -> float:
	return minf(_sz().x * 0.33, _sz().y * (0.33 if _forms() else 0.37))

func _dir(e: String) -> Vector2:
	var a := -PI * 0.5 + ORDER.find(e) * TAU / 5.0
	return Vector2(cos(a), sin(a))

## A fighter's tree is of forms, laid out by weapon family; a channeller's is of
## weaves, laid out by Power. Everything else is shared.
func _forms() -> bool:
	return profile.get("cls", "channeller") != "channeller"

func _table() -> Dictionary:
	return Rules.lore(profile)

func _tier(id: String) -> int:
	var d := 0
	for n in _table()[id].get("needs", []):
		d = maxi(d, _tier(n) + 1)
	return d

func _shown() -> Array:
	var out := []
	if _forms():
		return Rules.forms.keys()
	for id in Rules.weaves:
		# Past the reading limit a weave is not drawn at all, even one owned (only
		# the weave a channeller was born knowing is never hidden).
		if not str(id).begins_with("_") and (Rules.weaves[id].book <= profile.book_limit or profile.get("starter", "") == id):
			out.append(id)
	return out

func _node_r() -> float:
	return clampf(_radius() * 0.085, 20.0, 34.0)

func _layout() -> void:
	if _for == size and not _pos.is_empty():
		return
	_for = size; _pos = {}
	var c := _centre(); var R := _radius()
	if _forms():
		# Each weapon family takes a share of the wheel in proportion to its forms;
		# within it, a form sits further in the more forms it waits on.
		var fams := []
		for id in Rules.forms:
			if not fams.has(Rules.forms[id].family):
				fams.append(Rules.forms[id].family)
		var start := -PI * 0.5 - PI * float(Rules.forms.values().filter(func(f: Dictionary) -> bool: return f.family == fams[0]).size()) / Rules.forms.size()
		_fam_ang = {}
		for fam in fams:
			var mine := Rules.forms.keys().filter(func(id: String) -> bool: return Rules.forms[id].family == fam)
			var sector := TAU * mine.size() / Rules.forms.size()
			_fam_ang[fam] = start + sector * 0.5
			for tier in 4:
				var row := mine.filter(func(id: String) -> bool: return mini(_tier(id), 3) == tier)
				for i in row.size():
					var ang := start + sector * (i + 0.5) / row.size()
					_pos[row[i]] = c + Vector2(cos(ang), sin(ang)) * R * [1.0, 0.7, 0.42, 0.14][tier]
			start += sector
	for id in ([] if _forms() else _shown()):
		var fl := Rules.flows_of(Rules.weaves[id], profile)
		var v := Vector2.ZERO; var n := 0.0
		for e in fl:
			v += _dir(e) * float(fl[e]); n += fl[e]
		v /= maxf(n, 1.0)
		_pos[id] = c + (v.normalized() * R * RADII[mini(_tier(id), 3)] if v.length() > 0.05 else Vector2.ZERO)
	# Ease apart anything that landed on top of something else.
	var min_d := _node_r() * (4.6 if _forms() else 3.9)
	for it in 40:
		for a in _pos:
			for b in _pos:
				if a < b:
					var d: Vector2 = _pos[b] - _pos[a]
					if d.length() < min_d:
						var push: Vector2 = (d.normalized() if d.length() > 0.5 else Vector2(1, 0).rotated(hash(a) % 7)) * (min_d - d.length()) * 0.5
						# Root weaves stay on their Power's point of the rim.
						if _tier(a) > 0: _pos[a] -= push
						if _tier(b) > 0: _pos[b] += push

func _state(id: String) -> String:
	if Rules.knows(profile, id):
		return "known"
	if profile.get("study", "") == id:
		return "studying"
	return "open" if Rules.study_options(profile).has(id) else "locked"

func _glyph(id: String, at: Vector2, r: float, bright: float, spin := 0.0) -> void:
	if _forms():
		Glyph.weapon(self, at, r, Rules.forms[id].family, bright)
	else:
		Glyph.weave(self, at, r, Rules.flows_of(Rules.weaves[id], profile), bright, spin)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = ""
		for id in _pos:
			if (ev.position / _k()).distance_to(_pos[id]) < _node_r() * 1.25:
				hover = id
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if hover != "" and (_state(hover) == "open" or (pickable and _state(hover) == "known")):
			chosen.emit(hover)

func _draw() -> void:
	if profile.is_empty():
		return
	_layout()
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var c := _centre(); var R := _radius(); var nr := _node_r()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
	draw_rect(Rect2(Vector2.ZERO, _sz()), Color(0.02, 0.02, 0.05, 0.97))
	# A slow outer ring of marks, turning like the Wheel.
	for k in 72:
		var a := k * TAU / 72.0 + t * 0.03
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * R * 1.07, c + d * R * (1.11 if k % 6 == 0 else 1.085), Color(Glyph.GOLD, 0.35 if k % 6 == 0 else 0.15), 1.5, true)
	# The wheel: faint rings for each step inward, a spoke and a name for each Power.
	for k in RADII.size():
		draw_arc(c, R * RADII[k], 0, TAU, 96, Color(Glyph.GOLD, 0.13 if k == 0 else 0.07), 1.5 if k == 0 else 1.0, true)
	for fam in (_fam_ang if _forms() else {}):
		var d := Vector2(cos(_fam_ang[fam]), sin(_fam_ang[fam]))
		Glyph.text(self, serif, c + d * (R + nr * 2.9) + Vector2(d.x * 26.0, 8.0 + (22.0 if d.y > 0.3 else 0.0)), fam.capitalize(), 26, Color(0.85, 0.87, 0.92), 0)
	for e in ([] if _forms() else ORDER):
		var d := _dir(e)
		var col: Color = Glyph.TINT[e]
		draw_line(c + d * R * 0.08, c + d * R, Color(col, 0.16), 1.5, true)
		# A soft bloom behind each Power's place on the rim.
		for k in 5:
			draw_circle(c + d * R, nr * (2.6 - k * 0.4), Color(col, 0.035))
		Glyph.text(self, serif, c + d * (R + nr * 2.9) + Vector2(d.x * 26.0, 8.0 + (22.0 if d.y > 0.3 else 0.0)), e.capitalize(), 26, Color(col, 0.95), 0)
	# What leads to what.
	for id in _pos:
		for need in _table()[id].get("needs", []):
			if not _pos.has(need):
				continue
			var a: Vector2 = _pos[need]; var b: Vector2 = _pos[id]
			var lit: bool = _state(need) == "known"
			var mid := (a + b) * 0.5 + (c - (a + b) * 0.5) * 0.18
			var pts := PackedVector2Array()
			for k in 21:
				var f := k / 20.0
				pts.append(a.lerp(mid, f).lerp(mid.lerp(b, f), f))
			var hot: bool = hover == id or hover == need
			draw_polyline(pts, Color(Glyph.GOLD, 0.85 if hot else 0.5) if lit else Color(0.6, 0.6, 0.7, 0.5 if hot else 0.16), 2.4 if hot else 1.6, true)
			if lit and _state(id) != "known":
				# Something travels along a path you could take.
				var f := fposmod(t * 0.35 + (hash(id + need) % 100) * 0.01, 1.0)
				draw_circle(a.lerp(mid, f).lerp(mid.lerp(b, f), f), 3.0, Color(1.0, 0.95, 0.8, 0.9))
	# The weaves.
	for id in _pos:
		var p: Vector2 = _pos[id]
		var st := _state(id)
		var r := nr * (1.15 if hover == id else 1.0)
		match st:
			"known":
				draw_circle(p, r + 9.0, Color(Glyph.GOLD, 0.12))
				_glyph(id, p, r, 1.0, t * 0.15)
				draw_arc(p, r + 4.0, 0, TAU, 40, Color(Glyph.GOLD, 0.9), 1.6, true)
				var m := 0 if _forms() else Rules.mastery_level(profile, id)
				for k in m:
					var a := PI * 0.5 + (k - (m - 1) * 0.5) * 0.3
					draw_circle(p + Vector2(cos(a), sin(a)) * (r + 4.0), 3.2, Glyph.GOLD)
			"studying":
				_glyph(id, p, r, 0.8, t * 0.5)
				var f: float = clampf(profile.get("study_done", 0.0) / Rules.study_cost(profile, id), 0.0, 1.0)
				draw_arc(p, r + 5.0, 0, TAU, 40, Color(1, 1, 1, 0.18), 3.0, true)
				draw_arc(p, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(f, 0.01), 40, Color(1, 1, 1, 0.95), 3.0, true)
			"open":
				_glyph(id, p, r, 0.5)
				draw_arc(p, r + 4.0 + 2.0 * sin(t * 3.0), 0, TAU, 40, Color(1, 1, 1, 0.45 + 0.25 * sin(t * 3.0)), 1.5, true)
			"locked":
				_glyph(id, p, r, 0.3)
		var name_col := Color(0.97, 0.94, 0.88) if st == "known" else (Color(0.9, 0.9, 0.95) if st != "locked" else Color(0.5, 0.5, 0.56))
		# Long names (the sword forms) go on two lines.
		var label: String = _table()[id].name
		var cut := label.find(" ", label.length() / 2 - 1) if label.length() > 13 else -1
		Glyph.text(self, sans, p + Vector2(0, r + 22.0), label if cut < 0 else label.substr(0, cut), 13, name_col, 0)
		if cut >= 0:
			Glyph.text(self, sans, p + Vector2(0, r + 38.0), label.substr(cut + 1), 13, name_col, 0)
	Glyph.text(self, serif, Vector2(40, 60), "The Forms" if _forms() else "The Weaves", 38, Color(0.97, 0.94, 0.88))
	Glyph.text(self, sans, Vector2(42, 86), "One form is worked out at a time," if _forms() else "One weave is worked out at a time,", 14, Color(0.65, 0.67, 0.75))
	Glyph.text(self, sans, Vector2(42, 106), "by fighting with anything." if _forms() else "by channelling anything.", 14, Color(0.65, 0.67, 0.75))
	Glyph.text(self, sans, Vector2(42, _sz().y - 30.0), ("%s or Esc: close" % Keys.name(KEY_TAB)) if pickable else ("%s or Esc: back to the camp" % Keys.name(KEY_T)), 14, Color(0.65, 0.67, 0.75))
	# Weaves past the spoiler setting are not drawn, but it should be plain there are more.
	if not _forms():
		var hidden := 0
		for id in Rules.weaves:
			if not str(id).begins_with("_") and Rules.weaves[id].book > profile.book_limit and profile.get("starter", "") != id:
				hidden += 1
		# Said only to someone who has opened the later books themselves: to anyone
		# else even the count is a hint.
		if hidden > 0 and Settings.story_open:
			Glyph.text(self, sans, Vector2(42, 126), "%d more from later books, hidden in this fight" % hidden, 13, Color(0.55, 0.57, 0.65))
	_card(hover if hover != "" else profile.get("study", ""))

## The panel on the right: what the weave under the pointer is and what it asks.
func _card(id: String) -> void:
	if id == "" or not _table().has(id):
		return
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var w: Dictionary = _table()[id]
	var x := _sz().x * 0.76; var y := _sz().y * 0.24
	var wd := _sz().x * 0.22
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 360), Color(0.06, 0.06, 0.1, 0.85))
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 360), Color(Glyph.GOLD, 0.4), false, 1.2)
	Glyph.text(self, serif, Vector2(x, y), w.name, 24 if w.name.length() < 22 else 17, Color(0.97, 0.94, 0.88))
	var fl := {} if _forms() else Rules.flows_of(w, profile)
	var yy := y + 34.0
	if _forms():
		Glyph.text(self, sans, Vector2(x, yy), "%s form   ·   every %d s" % [w.family.capitalize(), int(w.cooldown)], 15, Color(0.85, 0.87, 0.92))
		yy += 26.0
		# The note, wrapped by hand to the card's width.
		var line := ""
		for word in (w.get("note", "") as String).split(" "):
			if (line + " " + word).length() > 34:
				Glyph.text(self, sans, Vector2(x, yy), line, 13, Color(0.7, 0.72, 0.8)); yy += 18.0
				line = word
			else:
				line = (line + " " + word).strip_edges()
		Glyph.text(self, sans, Vector2(x, yy), line, 13, Color(0.7, 0.72, 0.8)); yy += 22.0
	for e in ORDER:
		if fl.has(e):
			for k in int(fl[e]):
				draw_circle(Vector2(x + 8 + k * 18, yy - 5), 6.0, Glyph.TINT[e])
			Glyph.text(self, sans, Vector2(x + 14 + int(fl[e]) * 18, yy), e.capitalize(), 15, Glyph.TINT[e])
			yy += 24.0
	yy += 10.0
	var lines := []
	if not _forms():
		# There are no cooldowns: what a weave costs in time is the making of it.
		lines.append(["Takes %.1f s to weave" % Rules.form_time(profile, id), Color(0.8, 0.82, 0.9)])
	match _state(id):
		"known":
			lines.append(["Known." if _forms() else "Known. Mastery %d." % Rules.mastery_level(profile, id), Glyph.GOLD])
		"studying":
			lines.append(["Working it out: %d%%" % int(100.0 * profile.get("study_done", 0.0) / Rules.study_cost(profile, id)), Color.WHITE])
		"open":
			lines.append(["Click to study it.", Color.WHITE])
			if profile.get("study", "") != "" and profile.get("study_done", 0.0) > 0.0:
				lines.append(["What you have worked out of", Color(1.0, 0.7, 0.45)])
				lines.append(["%s will be lost." % _table()[profile.study].name, Color(1.0, 0.7, 0.45)])
		"locked":
			lines.append(["First you must know:", Color(0.75, 0.75, 0.8)])
			for m in Rules.missing_for(profile, id):
				lines.append(["   " + _table()[m].name, Color(0.9, 0.9, 0.95)])
			if _forms() and Rules.skill_level(profile, w.family) < int(w.get("skill", 0)):
				lines.append(["   %s skill %d (you have %d)" % [w.family, int(w.skill), Rules.skill_level(profile, w.family)], Color(0.9, 0.9, 0.95)])
	if _state(id) != "known":
		# Channelling comes at roughly 200 a minute of steady weaving.
		# A fighter spends roughly 250 stamina a minute in a hard fight.
		var mins := Rules.study_cost(profile, id) / (250.0 if _forms() else 205.0)
		lines.append(["About %s of %s" % ["%d minutes" % maxi(int(mins), 1) if mins < 90.0 else "%.0f hours" % (mins / 60.0), "fighting" if _forms() else "weaving"], Color(0.7, 0.72, 0.8)])
		if profile.get("seen", []).has(id):
			lines.append(["You have seen it woven: half the work.", Color(0.7, 0.9, 0.75)])
	if w.has("level"):
		lines.append(["Needs strength %s, or the Talent" % Rules.level_name(int(w.level)), Color(0.7, 0.72, 0.8)])
	if w.get("base", {}).has("drain"):
		lines.append(["Drains the one Healed of stamina", Color(0.7, 0.72, 0.8)])
	if w.get("hold", false):
		lines.append(["Held: it occupies its flows while it lasts", Color(0.7, 0.72, 0.8)])
	for l in lines:
		Glyph.text(self, sans, Vector2(x, yy), l[0], 15, l[1])
		yy += 22.0
