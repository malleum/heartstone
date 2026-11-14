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
var t := 0.0
var hover := ""
var _pos := {}       # weave id -> Vector2
var _for := Vector2.ZERO

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
	return minf(_sz().x * 0.33, _sz().y * 0.37)

func _dir(e: String) -> Vector2:
	var a := -PI * 0.5 + ORDER.find(e) * TAU / 5.0
	return Vector2(cos(a), sin(a))

func _tier(id: String) -> int:
	var d := 0
	for n in Rules.weaves[id].get("needs", []):
		d = maxi(d, _tier(n) + 1)
	return d

func _shown() -> Array:
	var out := []
	for id in Rules.weaves:
		if not str(id).begins_with("_") and (Rules.weaves[id].book <= profile.book_limit or profile.weaves.has(id)):
			out.append(id)
	return out

func _node_r() -> float:
	return clampf(_radius() * 0.085, 20.0, 34.0)

func _layout() -> void:
	if _for == size and not _pos.is_empty():
		return
	_for = size; _pos = {}
	var c := _centre(); var R := _radius()
	for id in _shown():
		var fl := Rules.flows_of(Rules.weaves[id], profile)
		var v := Vector2.ZERO; var n := 0.0
		for e in fl:
			v += _dir(e) * float(fl[e]); n += fl[e]
		v /= maxf(n, 1.0)
		_pos[id] = c + (v.normalized() * R * RADII[mini(_tier(id), 3)] if v.length() > 0.05 else Vector2.ZERO)
	# Ease apart anything that landed on top of something else.
	var min_d := _node_r() * 3.9
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
	if profile.weaves.get(id, {}).get("known", false):
		return "known"
	if profile.get("study", "") == id:
		return "studying"
	return "open" if Rules.missing_for(profile, id).is_empty() else "locked"

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = ""
		for id in _pos:
			if (ev.position / _k()).distance_to(_pos[id]) < _node_r() * 1.25:
				hover = id
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if hover != "" and _state(hover) == "open":
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
	for e in ORDER:
		var d := _dir(e)
		var col: Color = Glyph.TINT[e]
		draw_line(c + d * R * 0.08, c + d * R, Color(col, 0.16), 1.5, true)
		# A soft bloom behind each Power's place on the rim.
		for k in 5:
			draw_circle(c + d * R, nr * (2.6 - k * 0.4), Color(col, 0.035))
		Glyph.text(self, serif, c + d * (R + nr * 2.9) + Vector2(d.x * 26.0, 8.0 + (22.0 if d.y > 0.3 else 0.0)), e.capitalize(), 26, Color(col, 0.95), 0)
	# What leads to what.
	for id in _pos:
		for need in Rules.weaves[id].get("needs", []):
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
		var fl := Rules.flows_of(Rules.weaves[id], profile)
		var r := nr * (1.15 if hover == id else 1.0)
		match st:
			"known":
				draw_circle(p, r + 9.0, Color(Glyph.GOLD, 0.12))
				Glyph.weave(self, p, r, fl, 1.0, t * 0.15)
				draw_arc(p, r + 4.0, 0, TAU, 40, Color(Glyph.GOLD, 0.9), 1.6, true)
				var m := Rules.mastery_level(profile, id)
				for k in m:
					var a := PI * 0.5 + (k - (m - 1) * 0.5) * 0.3
					draw_circle(p + Vector2(cos(a), sin(a)) * (r + 4.0), 3.2, Glyph.GOLD)
			"studying":
				Glyph.weave(self, p, r, fl, 0.8, t * 0.5)
				var f: float = clampf(profile.get("study_done", 0.0) / Rules.study_cost(profile, id), 0.0, 1.0)
				draw_arc(p, r + 5.0, 0, TAU, 40, Color(1, 1, 1, 0.18), 3.0, true)
				draw_arc(p, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * maxf(f, 0.01), 40, Color(1, 1, 1, 0.95), 3.0, true)
			"open":
				Glyph.weave(self, p, r, fl, 0.5)
				draw_arc(p, r + 4.0 + 2.0 * sin(t * 3.0), 0, TAU, 40, Color(1, 1, 1, 0.45 + 0.25 * sin(t * 3.0)), 1.5, true)
			"locked":
				Glyph.weave(self, p, r, fl, 0.3)
		var name_col := Color(0.97, 0.94, 0.88) if st == "known" else (Color(0.9, 0.9, 0.95) if st != "locked" else Color(0.5, 0.5, 0.56))
		Glyph.text(self, sans, p + Vector2(0, r + 22.0), Rules.weaves[id].name, 13, name_col, 0)
	Glyph.text(self, serif, Vector2(40, 60), "The Weaves", 38, Color(0.97, 0.94, 0.88))
	Glyph.text(self, sans, Vector2(42, 86), "One weave is worked out at a time,", 14, Color(0.65, 0.67, 0.75))
	Glyph.text(self, sans, Vector2(42, 106), "by channelling anything.", 14, Color(0.65, 0.67, 0.75))
	Glyph.text(self, sans, Vector2(42, _sz().y - 30.0), "T or Esc: back to the camp", 14, Color(0.65, 0.67, 0.75))
	_card(hover if hover != "" else profile.get("study", ""))

## The panel on the right: what the weave under the pointer is and what it asks.
func _card(id: String) -> void:
	if id == "" or not Rules.weaves.has(id):
		return
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var w: Dictionary = Rules.weaves[id]
	var x := _sz().x * 0.76; var y := _sz().y * 0.24
	var wd := _sz().x * 0.22
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 330), Color(0.06, 0.06, 0.1, 0.85))
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 330), Color(Glyph.GOLD, 0.4), false, 1.2)
	Glyph.text(self, serif, Vector2(x, y), w.name, 24, Color(0.97, 0.94, 0.88))
	var fl := Rules.flows_of(w, profile)
	var yy := y + 34.0
	for e in ORDER:
		if fl.has(e):
			for k in int(fl[e]):
				draw_circle(Vector2(x + 8 + k * 18, yy - 5), 6.0, Glyph.TINT[e])
			Glyph.text(self, sans, Vector2(x + 14 + int(fl[e]) * 18, yy), e.capitalize(), 15, Glyph.TINT[e])
			yy += 24.0
	yy += 10.0
	var lines := []
	match _state(id):
		"known":
			lines.append(["Known. Mastery %d." % Rules.mastery_level(profile, id), Glyph.GOLD])
		"studying":
			lines.append(["Working it out: %d%%" % int(100.0 * profile.get("study_done", 0.0) / Rules.study_cost(profile, id)), Color.WHITE])
		"open":
			lines.append(["Click to study it.", Color.WHITE])
			if profile.get("study", "") != "" and profile.get("study_done", 0.0) > 0.0:
				lines.append(["What you have worked out of", Color(1.0, 0.7, 0.45)])
				lines.append(["%s will be lost." % Rules.weaves[profile.study].name, Color(1.0, 0.7, 0.45)])
		"locked":
			lines.append(["First you must know:", Color(0.75, 0.75, 0.8)])
			for m in Rules.missing_for(profile, id):
				lines.append(["   " + Rules.weaves[m].name, Color(0.9, 0.9, 0.95)])
	if _state(id) != "known":
		# Channelling comes at roughly 200 a minute of steady weaving.
		var mins := Rules.study_cost(profile, id) / 205.0
		lines.append(["About %s of weaving" % ("%d minutes" % int(mins) if mins < 90.0 else "%.0f hours" % (mins / 60.0)), Color(0.7, 0.72, 0.8)])
		if profile.get("seen", []).has(id):
			lines.append(["You have seen it woven: half the work.", Color(0.7, 0.9, 0.75)])
	if w.has("level"):
		lines.append(["Needs strength %s, or the Talent" % Rules.level_name(int(w.level)), Color(0.7, 0.72, 0.8)])
	if w.get("hold", false):
		lines.append(["Held: it occupies its flows while it lasts", Color(0.7, 0.72, 0.8)])
	for l in lines:
		Glyph.text(self, sans, Vector2(x, yy), l[0], 15, l[1])
		yy += 22.0
