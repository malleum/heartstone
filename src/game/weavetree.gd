class_name WeaveTree
extends Control
## The weave tree, drawn as a wheel of the Five Powers. Each Power has its place on
## the rim, where its simplest weave sits; a weave that joins Powers sits between
## them and further in; Balefire, which takes all five, is the hub. Lines run from
## each weave to the ones that must be known first.

signal chosen(id: String)
signal bar_changed     # the hotbar was rearranged here (bar_edit)

const ORDER := ["fire", "air", "water", "spirit", "earth"]   # neighbours are the Powers most often woven together
const RADII := [1.0, 0.67, 0.4, 0.2]

var profile := {}
var pickable := false   # in a round: a known weave can be chosen too (to grow it)
## In the camp: the hotbar along the bottom; drag what you know onto it, along it to
## reorder, off it to take it away; a switch for whether new things go on by themselves.
var bar_edit := false
var _drag := ""          # what is being dragged
var _drag_from := -1     # its slot on the bar, or -1 from the tree
var _drag_at := Vector2.ZERO
var _press_at := Vector2.ZERO
var t := 0.0
var hover := ""
var _pos := {}       # weave id -> Vector2
var _for := Vector2.ZERO
var _fam_ang := {}   # forms: weapon family -> angle of the middle of its share
## A fighter has two trees: the weapons (each family a line from plain to fine) and
## the forms. Tabs at the top switch them.
var page := "weapons":
	set(v):
		page = v; _for = Vector2.ZERO; hover = ""
var _tabs := {}      # page -> Rect2 of its tab (in layout units)
var _cols := {}      # weapon tree: family -> x of its column

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
	return Vector2(_sz().x * 0.4, _sz().y * (0.48 if bar_edit and not _forms() else 0.52))

## (A little smaller with the hotbar strip under it, so the two stay apart.)
func _radius() -> float:
	return minf(_sz().x * 0.33, _sz().y * (0.33 if _forms() else 0.37)) * (0.86 if bar_edit and not _forms() else 1.0)

func _dir(e: String) -> Vector2:
	var a := -PI * 0.5 + ORDER.find(e) * TAU / 5.0
	return Vector2(cos(a), sin(a))

## A fighter's tree is of forms, laid out by weapon family; a channeller's is of
## weaves, laid out by Power. Everything else is shared.
func _forms() -> bool:
	return profile.get("cls", "channeller") != "channeller"

func _table() -> Dictionary:
	return Rules.lore(profile)

## A fighter looking at the weapon tree.
func _weapons() -> bool:
	return _forms() and page == "weapons"

func _tier(id: String) -> int:
	var needs: Array = _table()[id].get("needs", [])
	if _weapons():
		# A weapon needs any one of these; it is drawn a step past the furthest, so a
		# line reads downward (the hand-and-a-half sword below both sword-and-somethings).
		var best := 0
		for n in needs:
			if _table().has(n) and Rules.wield_block({cls = profile.get("cls", ""), stats = {might = 9}}, n) == "":
				best = maxi(best, _tier(n) + 1)
		return best
	var d := 0
	for n in needs:
		d = maxi(d, _tier(n) + 1)
	return d

func _shown() -> Array:
	var out := []
	if _weapons():
		# Only what this calling may carry.
		return Rules.tree_weapons().filter(func(w: String) -> bool: return Rules.wield_block({cls = profile.get("cls", ""), stats = {might = 9}}, w) == "")
	if _forms():
		return Rules.forms.keys()
	for id in Rules.weaves:
		# Past the reading limit a weave is not drawn at all, even one owned (only
		# the weave a channeller was born knowing is never hidden).
		if not str(id).begins_with("_") and (Rules.book_of(id, profile) <= profile.book_limit or profile.get("starter", "") == id):
			out.append(id)
	return out

var _step_r := 0.0   # a fighter's tree: the most a circle may be, so a long column still fits

func _node_r() -> float:
	var r := clampf(_radius() * 0.085, 20.0, 34.0)
	return minf(r, _step_r) if _forms() and _step_r > 0.0 else r

func _layout() -> void:
	if _for == size and not _pos.is_empty():
		return
	_for = size; _pos = {}
	var c := _centre(); var R := _radius()
	_cols = {}
	if _forms():
		# A fighter's trees: a column for each kind of weapon, the first step at the top
		# and the finest at the bottom; what branches off sits beside its fellows. A
		# column is as wide as its widest step.
		var ids := _shown()
		var tb := _table()
		var fams := []
		for f in ["sword", "knife", "spear", "staff", "axe", "hand", "bow", "thrown"]:
			if ids.any(func(i: String) -> bool: return tb[i].family == f): fams.append(f)
		var widest := {}
		var deepest := 0
		for f in fams:
			widest[f] = 1
		for i in ids:
			deepest = maxi(deepest, _tier(i))
		for f in fams:
			for tier in deepest + 1:
				widest[f] = maxi(widest[f], ids.filter(func(i: String) -> bool: return tb[i].family == f and _tier(i) == tier).size())
		# The whole width (the card goes on the far side from what it describes). Each
		# column is at least a name wide; steps side by side are staggered up and
		# down, so each one past the first needs less than that, as room allows.
		var left := 50.0; var right := _sz().x - 50.0
		var name_w := 84.0
		var extra := 0
		for f in fams:
			extra += widest[f] - 1
		var sib_k := clampf(((right - left) / name_w - fams.size()) / maxf(extra, 1.0), 0.45, 1.0)
		var total := 0.0
		for f in fams:
			total += 1.0 + sib_k * (widest[f] - 1)
		# (The last step may be staggered down, and has its name under it.)
		var top := 178.0; var step := minf(100.0, (_sz().y - top - 110.0) / maxf(deepest + 0.3, 1.0))
		# However many steps a column grows to, they fit: the circles shrink with the
		# step, leaving room for the name under each (and the staggered sibling).
		_step_r = maxf(step * 0.26, 11.0)
		var unit := (right - left) / maxf(total, 1.0)
		var x0 := left
		for fam in fams:
			var colw: float = unit * (1.0 + sib_k * (widest[fam] - 1))
			var x: float = x0 + colw * 0.5
			x0 += colw
			_cols[fam] = x
			var mine := ids.filter(func(i: String) -> bool: return tb[i].family == fam)
			for tier in deepest + 1:
				var row := mine.filter(func(i: String) -> bool: return _tier(i) == tier)
				# The longest name takes the place not staggered down into the next step.
				if row.size() == 2 and String(tb[row[1]].name).length() > String(tb[row[0]].name).length():
					row.reverse()
				var sib := colw / maxf(row.size(), 1.0)
				for i in row.size():
					# Side by side, staggered, so their names fit.
					_pos[row[i]] = Vector2(x + (i - (row.size() - 1) * 0.5) * sib, top + tier * step + (step * 0.3 if i % 2 == 1 else 0.0))
		return
	if _forms():
		# Each weapon family takes a share of the wheel in proportion to its forms;
		# within it, a form sits further in the more forms it waits on.
		var ids := _shown()
		var tb := _table()
		var fams := []
		for id in ids:
			if not fams.has(tb[id].family):
				fams.append(tb[id].family)
		var start := -PI * 0.5 - PI * float(ids.filter(func(i: String) -> bool: return tb[i].family == fams[0]).size()) / ids.size()
		_fam_ang = {}
		for fam in fams:
			var mine := ids.filter(func(i: String) -> bool: return tb[i].family == fam)
			var sector := TAU * mine.size() / ids.size()
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
		Glyph.weapon(self, at, r, _table()[id].family, bright)
	else:
		Glyph.weave(self, at, r, Rules.flows_of(Rules.weaves[id], profile), bright, spin)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = ""
		for id in _pos:
			if (ev.position / _k()).distance_to(_pos[id]) < _node_r() * 1.25:
				hover = id
		_drag_at = ev.position / _k()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed and _drag != "":
		_drop(ev.position / _k())
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = ev.position / _k()
		for pg in _tabs:
			if (_tabs[pg] as Rect2).has_point(at):
				page = pg
				return
		if bar_edit:
			if _auto_rect().has_point(at):
				profile.bar_auto = not profile.get("bar_auto", true)
				if not profile.bar_auto:
					# From now on only what is dragged: start from the bar as it stands.
					profile.hotbar = Profile.bar(profile)
				Profile.bar(profile)
				bar_changed.emit()
				return
			var slot := _slot_at(at)
			if slot >= 0:
				_drag = Profile.bar(profile)[slot]; _drag_from = slot; _drag_at = at; _press_at = at
				return
			if hover != "" and _state(hover) == "known" and Profile.bar_usable(profile).has(hover):
				_drag = hover; _drag_from = -1; _drag_at = at; _press_at = at
				return
		if hover != "" and (_state(hover) == "open" or (pickable and _state(hover) == "known")):
			chosen.emit(hover)

# --- the hotbar strip (camp) ---------------------------------------------------------

const SLOT := 48.0

func _strip_y() -> float:
	return _sz().y - 44.0

func _slot_x(i: int, n: int) -> float:
	return _sz().x * 0.42 - SLOT * (n - 1) * 0.5 + i * SLOT

func _slot_at(at: Vector2) -> int:
	var bar := Profile.bar(profile)
	for i in bar.size():
		if at.distance_to(Vector2(_slot_x(i, bar.size()), _strip_y())) < SLOT * 0.45:
			return i
	return -1

func _auto_rect() -> Rect2:
	var n := Profile.bar(profile).size()
	return Rect2(_slot_x(n, n) + 10.0, _strip_y() - 14.0, 200.0, 28.0)

## Let go of what was dragged: onto the bar (at the slot under it, or the end), or off
## it (taken away). A press and let-go without moving, on the tree, still picks.
func _drop(at: Vector2) -> void:
	var id := _drag; var from := _drag_from
	_drag = ""; _drag_from = -1
	var bar: Array = Profile.bar(profile).duplicate()
	var on_strip := absf(at.y - _strip_y()) < SLOT * 0.8
	if at.distance_to(_press_at) < 4.0:
		if from < 0 and hover != "" and (_state(hover) == "open" or (pickable and _state(hover) == "known")):
			chosen.emit(hover)
		return
	if from >= 0:
		bar.remove_at(from)
	if on_strip:
		var idx := bar.size()
		for i in bar.size():
			if at.x < _slot_x(i, bar.size() + 1) + SLOT * 0.5:
				idx = i
				break
		bar.erase(id)
		bar.insert(mini(idx, bar.size()), id)
	profile.hotbar = bar
	var seen: Array = profile.get("bar_seen", [])
	if not seen.has(id): seen.append(id)
	profile.bar_seen = seen
	bar_changed.emit()

func _icon(id: String, at: Vector2, r: float, a: float) -> void:
	if Rules.weaves.has(id):
		Glyph.weave(self, at, r, Rules.flows_of(Rules.weaves[id], profile), a)
	elif Rules.forms.has(id):
		Glyph.weapon(self, at, r * 0.8, Rules.forms[id].family, a)
		draw_arc(at, r * 0.95, 0, TAU, 28, Color(Glyph.GOLD, a), 1.6, true)
	elif Rules.weapons.has(id):
		Glyph.weapon(self, at, r, Rules.weapons[id].family, a)

func _draw_strip() -> void:
	var sans := Glyph.sans()
	var bar := Profile.bar(profile)
	var n := bar.size()
	var y := _strip_y()
	var x0 := _slot_x(0, n) - SLOT * 0.6
	var x1 := _slot_x(maxi(n - 1, 0), n) + SLOT * 0.6
	draw_rect(Rect2(x0, y - SLOT * 0.62, maxf(x1 - x0, SLOT), SLOT * 1.24), Color(0.04, 0.04, 0.06, 0.7))
	draw_rect(Rect2(x0, y - SLOT * 0.62, maxf(x1 - x0, SLOT), SLOT * 1.24), Color(Glyph.GOLD, 0.35), false, 1.2)
	Glyph.text(self, sans, Vector2(x0, y - SLOT * 0.62 - 8.0), "Your bar: drag here from the tree, along it to reorder, off it to take away", 12, Color(Glyph.GOLD, 0.8))
	for i in n:
		var c := Vector2(_slot_x(i, n), y)
		draw_circle(c, SLOT * 0.4, Color(0.08, 0.08, 0.1, 0.9))
		if i == _drag_from:
			continue
		_icon(bar[i], c, SLOT * 0.3, 1.0)
		if i < 9:
			Glyph.text(self, sans, c + Vector2(0, -SLOT * 0.45), str(i + 1), 10, Color(0.7, 0.7, 0.75), 0)
	if n == 0:
		Glyph.text(self, sans, Vector2(x0 + 8.0, y + 4.0), "(empty)", 12, Color(0.6, 0.6, 0.65))
	var ar := _auto_rect()
	var auto: bool = profile.get("bar_auto", true)
	draw_rect(ar, Color(0.08, 0.08, 0.1, 0.85))
	draw_rect(ar, Color(Glyph.GOLD, 0.5 if auto else 0.25), false, 1.0)
	Glyph.text(self, sans, ar.position + Vector2(8, 19), "New things go on the bar: %s" % ("on" if auto else "off"), 12, Glyph.GOLD if auto else Color(0.7, 0.7, 0.75))
	if _drag != "":
		_icon(_drag, _drag_at, SLOT * 0.32, 0.85)

func _draw() -> void:
	if profile.is_empty():
		return
	_layout()
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var c := _centre(); var R := _radius(); var nr := _node_r()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_k(), _k()))
	draw_rect(Rect2(Vector2.ZERO, _sz()), Color(0.02, 0.02, 0.05, 0.97))
	# A slow outer ring of marks, turning like the Wheel (not behind the weapon columns).
	for k in (0 if _forms() else 72):
		var a := k * TAU / 72.0 + t * 0.03
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * R * 1.07, c + d * R * (1.11 if k % 6 == 0 else 1.085), Color(Glyph.GOLD, 0.35 if k % 6 == 0 else 0.15), 1.5, true)
	# The wheel: faint rings for each step inward, a spoke and a name for each Power.
	for fam in _cols:
		Glyph.text(self, serif, Vector2(_cols[fam], 142), fam.capitalize(), 24, Color(0.85, 0.87, 0.92), 0)
		draw_line(Vector2(_cols[fam], 160), Vector2(_cols[fam], _sz().y - 60.0), Color(Glyph.GOLD, 0.05), 1.0, true)
	for k in (0 if _forms() else RADII.size()):
		draw_arc(c, R * RADII[k], 0, TAU, 96, Color(Glyph.GOLD, 0.13 if k == 0 else 0.07), 1.5 if k == 0 else 1.0, true)
	for fam in {}:
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
			var mid := (a + b) * 0.5 + ((c - (a + b) * 0.5) * 0.18 if not _forms() else Vector2.ZERO)
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
				# A weapon outgrown (a better one of its line is yours) is dimmer;
				# the one you own has a second ring.
				var outgrown: bool = _weapons() and Rules.weapon_of(profile, _table()[id].family) != id
				draw_circle(p, r + 9.0, Color(Glyph.GOLD, 0.05 if outgrown else 0.12))
				_glyph(id, p, r, 0.6 if outgrown else 1.0, t * 0.15)
				draw_arc(p, r + 4.0, 0, TAU, 40, Color(Glyph.GOLD, 0.45 if outgrown else 0.9), 1.6, true)
				if _weapons() and not outgrown:
					draw_arc(p, r + 8.0, 0, TAU, 40, Color(Glyph.GOLD, 0.6), 1.2, true)
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
		if _forms():
			# Narrow columns: as many short lines as the name needs.
			var lines_w: Array = []
			var cur := ""
			for word in label.split(" "):
				if cur != "" and (cur + " " + word).length() > 12:
					lines_w.append(cur); cur = word
				else:
					cur = (cur + " " + word).strip_edges()
			lines_w.append(cur)
			for li in lines_w.size():
				Glyph.text(self, sans, p + Vector2(0, r + 19.0 + li * 13.0), lines_w[li], 11, name_col, 0)
			continue
		var cut := label.find(" ", label.length() / 2 - 1) if label.length() > 13 else -1
		Glyph.text(self, sans, p + Vector2(0, r + 22.0), label if cut < 0 else label.substr(0, cut), 13, name_col, 0)
		if cut >= 0:
			Glyph.text(self, sans, p + Vector2(0, r + 38.0), label.substr(cut + 1), 13, name_col, 0)
	_tabs = {}
	if _forms():
		# Two trees: a tab for each; the one shown is lit.
		var x := 40.0
		for pg in ["weapons", "forms"]:
			var nm: String = "The Weapons" if pg == "weapons" else "The Forms"
			var on: bool = pg == page
			var px := 34 if on else 24
			var wd := serif.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			Glyph.text(self, serif, Vector2(x, 60), nm, px, Color(0.97, 0.94, 0.88) if on else Color(0.6, 0.62, 0.7))
			if on:
				draw_line(Vector2(x, 68), Vector2(x + wd, 68), Color(Glyph.GOLD, 0.8), 2.0, true)
			_tabs[pg] = Rect2(x - 6, 26, wd + 12, 48)
			x += wd + 28.0
		Glyph.text(self, sans, Vector2(42, 92), "One thing is worked out at a time, weapon or form,", 14, Color(0.65, 0.67, 0.75))
		Glyph.text(self, sans, Vector2(42, 112), "by fighting. Click a tab to switch trees." if page == "forms" else "by fighting. A new weapon replaces your old one of its kind.", 14, Color(0.65, 0.67, 0.75))
	else:
		Glyph.text(self, serif, Vector2(40, 60), "The Weaves", 38, Color(0.97, 0.94, 0.88))
		Glyph.text(self, sans, Vector2(42, 86), "One weave is worked out at a time,", 14, Color(0.65, 0.67, 0.75))
		Glyph.text(self, sans, Vector2(42, 106), "by channelling anything.", 14, Color(0.65, 0.67, 0.75))
	Glyph.text(self, sans, Vector2(42, _sz().y - 30.0), ("%s or Esc: close" % Keys.name(KEY_TAB)) if pickable else ("%s or Esc: back to the camp" % Keys.name(KEY_T)), 14, Color(0.65, 0.67, 0.75))
	# Weaves past the spoiler setting are not drawn, but it should be plain there are more.
	if not _forms():
		var hidden := 0
		for id in Rules.weaves:
			if not str(id).begins_with("_") and Rules.book_of(id, profile) > profile.book_limit and profile.get("starter", "") != id:
				hidden += 1
		# Said only to someone who has opened the later books themselves: to anyone
		# else even the count is a hint.
		if hidden > 0 and Settings.story_open:
			Glyph.text(self, sans, Vector2(42, 126), "%d more from later books, hidden in this fight" % hidden, 13, Color(0.55, 0.57, 0.65))
	_card(hover if hover != "" else profile.get("study", ""))
	if bar_edit:
		_draw_strip()

## The panel on the right: what the weave under the pointer is and what it asks.
func _card(id: String) -> void:
	if id == "" or not _table().has(id):
		return
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var w: Dictionary = _table()[id]
	var x := _sz().x * 0.76; var y := _sz().y * 0.24
	var wd := _sz().x * 0.22
	# A fighter's trees fill the width: the card stands on the other side from the
	# step it is about.
	if _forms() and _pos.has(id) and _pos[id].x > _sz().x * 0.5:
		x = 40.0
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 360), Color(0.06, 0.06, 0.1, 0.85))
	draw_rect(Rect2(x - 20, y - 46, wd + 40, 360), Color(Glyph.GOLD, 0.4), false, 1.2)
	Glyph.text(self, serif, Vector2(x, y), w.name, 24 if w.name.length() < 22 else 17, Color(0.97, 0.94, 0.88))
	var fl := {} if _forms() else Rules.flows_of(w, profile)
	var yy := y + 34.0
	if _weapons():
		Glyph.text(self, sans, Vector2(x, yy), "%s   ·   reach %.1f m   ·   %d a blow" % [w.family.capitalize(), float(w.reach), int(w.dmg)], 15, Color(0.85, 0.87, 0.92))
		yy += 22.0
		Glyph.text(self, sans, Vector2(x, yy), "%s-handed   ·   %s" % ["one" if int(w.get("hands", 1)) == 1 else "two", "quick" if float(w.speed) >= 1.2 else ("slow" if float(w.speed) < 0.9 else "steady")], 13, Color(0.7, 0.72, 0.8))
		yy += 26.0
	elif _forms():
		Glyph.text(self, sans, Vector2(x, yy), "%s form   ·   every %d s" % [w.family.capitalize(), int(w.cooldown)], 15, Color(0.85, 0.87, 0.92))
		yy += 22.0
		# A form is done with the weapon in hand, and hits as hard as that weapon does.
		var with_w := Rules.weapon_of(profile, w.family)
		if with_w != "":
			var hits := int(w.get("repeat", 1)) * int(w.get("count", 1))
			Glyph.text(self, sans, Vector2(x, yy), "With your %s: %d%s" % [Rules.weapons[with_w].name.to_lower(), int(Rules.blow(profile, with_w, id)), (" × %d" % hits) if hits > 1 else " a blow"], 13, Glyph.GOLD)
		else:
			Glyph.text(self, sans, Vector2(x, yy), "Needs a %s in hand (you carry none)" % w.family, 13, Color(1.0, 0.7, 0.45))
		yy += 24.0
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
	var mine := Rules.weapon_of(profile, w.family) if _weapons() else ""
	match _state(id):
		"known":
			if _weapons():
				lines.append(["Yours." if mine == id else ("Outgrown: your %s is better." % Rules.weapons[mine].name.to_lower() if mine != "" else "Known."), Glyph.GOLD])
			else:
				lines.append(["Known." if _forms() else "Known. Mastery %d." % Rules.mastery_level(profile, id), Glyph.GOLD])
		"studying":
			lines.append(["Working it out: %d%%" % int(100.0 * profile.get("study_done", 0.0) / Rules.study_cost(profile, id)), Color.WHITE])
		"open":
			lines.append(["Click to study it.", Color.WHITE])
			if _weapons() and mine != "":
				lines.append(["It will replace your %s." % Rules.weapons[mine].name.to_lower(), Color(0.9, 0.85, 0.6)])
			if profile.get("study", "") != "" and profile.get("study_done", 0.0) > 0.0:
				lines.append(["What you have worked out of", Color(1.0, 0.7, 0.45)])
				lines.append(["%s will be lost." % _table()[profile.study].name, Color(1.0, 0.7, 0.45)])
		"locked":
			lines.append(["First you must know one of:" if _weapons() else "First you must know:", Color(0.75, 0.75, 0.8)])
			for m in Rules.missing_for(profile, id):
				lines.append(["   " + _table()[m].name, Color(0.9, 0.9, 0.95)])
			if _weapons() and w.get("earned", false) and not Rules.earned_ok(profile, id):
				var e: Dictionary = w.get("earn", {})
				if e.has("renown"): lines.append(["   renown %d" % int(e.renown), Color(0.9, 0.9, 0.95)])
				if e.has("skill"): lines.append(["   %s skill %d" % [e.skill[0], int(e.skill[1])], Color(0.9, 0.9, 0.95)])
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
		lines.append(["Wears the one Healed, by what is mended (not with the Talent)", Color(0.7, 0.72, 0.8)])
	if w.get("hold", false):
		lines.append(["Held: it occupies its flows while it lasts", Color(0.7, 0.72, 0.8)])
	for l in lines:
		Glyph.text(self, sans, Vector2(x, yy), l[0], 15, l[1])
		yy += 22.0
