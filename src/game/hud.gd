class_name Hud
extends Control
## The fight's HUD, drawn by hand so it can look like the game and not like a
## debug overlay. It only reads the game view's state; it decides nothing.

var g: Node          # the game view (game.gd)
var t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var _slots: Array = []     # the bar's slot centres on screen, as last drawn
var _slot_r := 24.0

## A dream ability's mark: what it does, in a few strokes.
func _dream_icon(c: Vector2, r: float, mv: String, col: Color) -> void:
	var m: Dictionary = Dream.moves[mv]
	var w := 2.0
	match m.kind:
		"shift":
			var d := Vector2(0, -1)
			match m.get("where", ""):
				"back": d = Vector2(0, 1)
				"side": d = Vector2(1, 0)
				"behind":
					draw_arc(c, r * 0.6, PI * 0.2, PI * 1.6, 16, col, w, true)
					d = Vector2(1, -0.3).normalized()
				"swap":
					draw_line(c + Vector2(-r, -r * 0.35), c + Vector2(r, -r * 0.35), col, w, true)
					draw_line(c + Vector2(r, r * 0.35), c + Vector2(-r, r * 0.35), col, w, true)
					draw_line(c + Vector2(r, -r * 0.35), c + Vector2(r * 0.6, -r * 0.7), col, w, true)
					draw_line(c + Vector2(-r, r * 0.35), c + Vector2(-r * 0.6, r * 0.7), col, w, true)
					return
			draw_line(c - d * r, c + d * r, col, w, true)
			draw_line(c + d * r, c + d * r * 0.4 + d.orthogonal() * r * 0.5, col, w, true)
			draw_line(c + d * r, c + d * r * 0.4 - d.orthogonal() * r * 0.5, col, w, true)
		"deny":
			draw_arc(c, r * 0.85, PI * 1.1, PI * 1.9, 16, col, w * 1.3, true)
			draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.6, -r * 0.2), col, w, true)
		"bolt":
			if mv == "dream_boulder":
				draw_circle(c, r * 0.65, col)
			elif m.has("home"):
				for k in 3:
					var o := c + Vector2((k - 1) * r * 0.6, (k % 2) * r * 0.4 - r * 0.2)
					draw_line(o + Vector2(-r * 0.35, -r * 0.2), o, col, w, true)
					draw_line(o, o + Vector2(r * 0.35, -r * 0.2), col, w, true)
			else:
				var lines := 3 if int(m.get("count", 1)) > 1 else 1
				for k in lines:
					var o := Vector2((k - (lines - 1) * 0.5) * r * 0.45, 0)
					draw_line(c + o + Vector2(-r, r), c + o + Vector2(r, -r), col, w, true)
				draw_line(c + Vector2(r, -r), c + Vector2(r * 0.3, -r), col, w, true)
				draw_line(c + Vector2(r, -r), c + Vector2(r, -r * 0.3), col, w, true)
		"chain":
			if m.get("cage", false):
				for k in 4:
					var x := c.x + (k - 1.5) * r * 0.5
					draw_line(Vector2(x, c.y - r), Vector2(x, c.y + r), col, w, true)
			elif m.has("drain"):
				for k in 3:
					draw_circle(c + Vector2((k - 1) * r * 0.6, -k * r * 0.35 + r * 0.3), r * (0.28 - k * 0.06), col)
			elif m.has("shove"):
				var s: float = signf(float(m.shove))
				draw_circle(c, r * 0.22, col)
				for d in [Vector2(1, 0), Vector2(-1, 0)]:
					var a: Vector2 = c + d * r * (0.45 if s > 0.0 else 1.0)
					var b: Vector2 = c + d * r * (1.0 if s > 0.0 else 0.45)
					draw_line(a, b, col, w, true)
					draw_line(b, b - d * r * 0.3 * s + Vector2(0, r * 0.3), col, w, true)
					draw_line(b, b - d * r * 0.3 * s - Vector2(0, r * 0.3), col, w, true)
			else:
				draw_arc(c + Vector2(-r * 0.35, 0), r * 0.5, 0, TAU, 16, col, w, true)
				draw_arc(c + Vector2(r * 0.35, 0), r * 0.5, 0, TAU, 16, col, w, true)
		"pit":
			if m.has("burst"):
				var pts := PackedVector2Array([c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.25, 0), c + Vector2(-r * 0.2, r)])
				draw_polyline(pts, col, w, true)
			elif float(m.get("dps", 0.0)) > 12.0:
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, r * 0.7), c + Vector2(-r * 0.6, r * 0.7)]), col)
			else:
				draw_arc(c, r * 0.9, 0, TAU, 20, col, w, true)
				draw_arc(c, r * 0.45, 0, TAU, 14, col, w, true)
		"wall":
			if m.get("ring", false):
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(c + Vector2.from_angle(k * TAU / 6.0) * r * 0.9)
				draw_polyline(pts, col, w, true)
			elif m.get("reflect", false):
				draw_rect(Rect2(c - Vector2(r * 0.5, r), Vector2(r, r * 2.0)), col, false, w)
				draw_line(c + Vector2(-r * 0.3, r * 0.3), c + Vector2(r * 0.3, -r * 0.4), col, w, true)
			else:
				draw_rect(Rect2(c - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2)), col, false, w)
				draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, 1.5, true)
				draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, 0), col, 1.5, true)
		"mend":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, w * 1.5, true)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, w * 1.5, true)
		"fade":
			for k in 8:
				draw_arc(c, r * 0.85, k * TAU / 8.0, k * TAU / 8.0 + 0.45, 4, col, w, true)
		"haste":
			for k in 2:
				var o := c + Vector2(k * r * 0.6 - r * 0.3, 0)
				draw_line(o + Vector2(-r * 0.4, -r * 0.7), o + Vector2(r * 0.3, 0), col, w, true)
				draw_line(o + Vector2(r * 0.3, 0), o + Vector2(-r * 0.4, r * 0.7), col, w, true)

# --- damage numbers ---------------------------------------------------------------
# A number springs off whoever is struck. The harder the blow, the bigger, warmer and
# livelier it is: small white ticks, then gold, orange, red, and past 400 a white-hot
# number that bursts in a ring and shimmers. Blows that land within a moment of each
# other on the same body add up into one number (a beam, a flurry).
var _pops: Array = []
const POP_LIFE := 1.1

func pop(id: int, at: Vector3, dmg: float, mine: bool) -> void:
	for q in _pops:
		if q.id == id and q.mine == mine and t - q.t0 < 0.3:
			q.dmg += dmg; q.t0 = t - 0.05; q.at = at
			return
	_pops.append({id = id, at = at, dmg = dmg, mine = mine, t0 = t, seed = randf_range(-1.0, 1.0)})
	if _pops.size() > 40:
		_pops.pop_front()

## Colour, size and liveliness by how much it was.
static func _pop_style(d: float) -> Dictionary:
	if d < 20.0: return {col = Color(0.95, 0.95, 0.95), px = 19, pop = 0.25, shake = 0.0, ring = false}
	if d < 60.0: return {col = Color(1.0, 0.88, 0.35), px = 25, pop = 0.45, shake = 0.0, ring = false}
	if d < 150.0: return {col = Color(1.0, 0.6, 0.15), px = 31, pop = 0.7, shake = 1.5, ring = false}
	if d < 400.0: return {col = Color(1.0, 0.25, 0.12), px = 38, pop = 1.0, shake = 3.0, ring = true}
	return {col = Color(1.0, 0.95, 0.75), px = 50, pop = 1.4, shake = 5.0, ring = true}

func _draw_pops(sc: float) -> void:
	if g.cam == null:
		return
	_pops = _pops.filter(func(q: Dictionary) -> bool: return t - q.t0 < POP_LIFE)
	for q in _pops:
		var at: Vector3 = q.at + Vector3(0, 2.2, 0)
		if g.cam.is_position_behind(at):
			continue
		var age: float = t - q.t0
		var f: float = age / POP_LIFE
		var st := _pop_style(q.dmg)
		var px: int = st.px if q.mine else int(st.px * 0.75)
		var col: Color = st.col if q.mine else Color(1.0, 0.35, 0.3)
		# Springs up big, settles, drifts up and sideways, fades in its last third.
		var punch: float = 1.0 + float(st.pop) * exp(-age * 9.0) * (1.0 + 0.6 * sin(age * 30.0) * exp(-age * 6.0))
		var sp: Vector2 = g.cam.unproject_position(at) / sc
		sp += Vector2(q.seed * 30.0 * f, -46.0 * (1.0 - pow(1.0 - f, 2.0)))
		if st.shake > 0.0 and age < 0.25:
			sp += Vector2(sin(age * 90.0 + q.seed * 9.0), cos(age * 77.0)) * float(st.shake) * (1.0 - age / 0.25)
		var a := clampf((1.0 - f) * 3.0, 0.0, 1.0)
		if st.ring and q.mine and age < 0.4:
			var rr := 10.0 + age * 160.0
			draw_arc(sp + Vector2(0, -px * 0.35), rr, 0, TAU, 32, Color(col, (1.0 - age / 0.4) * 0.7), 2.5, true)
		if q.dmg >= 400.0 and q.mine:
			# White-hot: it shimmers between gold and white, sparks round it.
			col = Color(1.0, 0.95, 0.75).lerp(Color(1.0, 0.75, 0.25), 0.5 + 0.5 * sin(age * 25.0))
			for k in 6:
				var ang := k * TAU / 6.0 + age * 4.0
				draw_circle(sp + Vector2(0, -px * 0.35) + Vector2(cos(ang), sin(ang)) * (px * 0.9 + age * 30.0), 2.2, Color(1.0, 0.9, 0.5, a))
		draw_set_transform(sp * sc, q.seed * 0.12 * (1.0 - f), Vector2.ONE * sc * punch)
		Glyph.text(self, Glyph.serif(), Vector2(0, 0), "%d" % maxi(int(round(q.dmg)), 1), px, Color(col, a), 0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))

## Which bar slot is under this point on screen (-1 if none).
func slot_at(at: Vector2) -> int:
	for i in _slots.size():
		if (at - (_slots[i] as Vector2)).length() < _slot_r + 6.0:
			return i
	return -1

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	if g == null or g.profile.is_empty() or g.session == null:
		return
	var pus := Time.get_ticks_usec()
	_draw_all()
	Perf.add("hud", Time.get_ticks_usec() - pus)

func _draw_all() -> void:
	# Laid out for a 720-line screen and scaled to whatever it is shown on.
	var sc := size.y / 720.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	var W := size.x / sc; var H := 720.0
	var p: Dictionary = g.view_profile()
	var serif := Glyph.serif(); var sans := Glyph.sans()
	var hp := clampf(g.my_hp / Rules.max_hp(p), 0.0, 1.0)
	# Blood at the edges: a throb when badly hurt, a flash when struck.
	var danger: float = clampf((0.4 - hp) / 0.4, 0.0, 1.0) * (0.5 + 0.2 * sin(t * 5.0)) + g.hurt_t * 0.5
	if danger > 0.01:
		_vignette(Color(0.75, 0.04, 0.02, minf(danger, 0.85)), minf(W, H) * 0.3)

	_fade_dark(p, W, H)
	_draw_pops(sc)

	# Who you are.
	Glyph.text(self, serif, Vector2(30, 46), p.name, 30, Color(0.97, 0.94, 0.88))
	draw_line(Vector2(30, 56), Vector2(290, 56), Color(Glyph.GOLD, 0.6), 1.5, true)
	var cap := Rules.flow_capacity(p)
	var armed: bool = g._armed()
	var in_hand: Dictionary = Rules.weapons[g.hand()] if g.hand() != "" else {}
	if p.get("cls", "channeller") == "channeller":
		# In a round your potential is yours to find out: only where you stand now.
		var line := "strength %s" % Rules.level_name(Rules.level_of(Rules.strength(p))) if p.has("round") else "strength %s   of %s" % [Rules.level_name(Rules.level_of(Rules.strength(p))), Rules.level_name(Rules.level_of(p.potential))]
		# Tired, you weave below your strength: both, so neither is mistaken for the other.
		var eff := Rules.level_of(Rules.strength(p) * Rules.vigor(g.my_stamina))
		if eff > Rules.level_of(Rules.strength(p)):
			line = "strength %s   ·   tired, weaving as %s" % [Rules.level_name(Rules.level_of(Rules.strength(p))), Rules.level_name(eff)]
		Glyph.text(self, sans, Vector2(30, 78), line, 15, Color(0.85, 0.85, 0.9))
		# Flows: gold is free, a Power's colour is a flow holding a weave.
		var used: Array = g.used_flows()
		for i in 5:
			var c := Vector2(38 + i * 20, 96)
			if i < used.size():
				draw_circle(c, 6.0, used[i])
			elif i < cap:
				draw_circle(c, 6.0, Glyph.GOLD)
			draw_arc(c, 6.0, 0, TAU, 20, Color(Glyph.GOLD, 0.8 if i < cap else 0.25), 1.5, true)
		Glyph.text(self, sans, Vector2(38 + 5 * 20, 101), "flows      renown %d" % int(p.renown), 13, Color(0.7, 0.72, 0.78))
	else:
		# A fighter: their calling, and their skill with what is in hand as pips.
		Glyph.text(self, sans, Vector2(30, 78), "%s   might %d  quickness %d  endurance %d" % [Rules.cls(p).name, Rules.stat(p, "might"), Rules.stat(p, "quickness"), Rules.stat(p, "endurance")], 15, Color(0.85, 0.85, 0.9))
		var fam: String = in_hand.get("family", "hand")
		var lvl := Rules.skill_level(p, fam)
		for i in 10:
			var c := Vector2(36 + i * 14, 96)
			if i < lvl:
				draw_circle(c, 4.5, Glyph.GOLD)
			draw_arc(c, 4.5, 0, TAU, 16, Color(Glyph.GOLD, 0.8 if i < lvl else 0.25), 1.2, true)
		Glyph.text(self, sans, Vector2(36 + 10 * 14 + 6, 101), "%s skill      renown %d" % [fam, int(p.renown)], 13, Color(0.7, 0.72, 0.78))

	# The round: the team's level, how far to the next, and choices waiting.
	if not g.team_meter.is_empty():
		var tm: Array = g.team_meter
		var side: int = g.my_team if tm.size() >= 7 else 0
		var lv: int = tm[2] if side == 2 else tm[0]
		Glyph.text(self, serif, Vector2(300, 46), "Level %d" % lv, 20, Glyph.GOLD)
		Glyph.bar(self, Vector2(300, 52), 110, 5, float(tm[3] if side == 2 else tm[1]), Glyph.GOLD, Color(1.0, 0.9, 0.6))
		if tm.size() >= 7:
			# A battle: the score, ours first in our colour, and the time left.
			var ours: int = tm[4] if side != 2 else tm[5]
			var theirs: int = tm[5] if side != 2 else tm[4]
			var left := int(tm[6])
			var line := "%d" % ours
			Glyph.text(self, serif, Vector2(W * 0.5 - 60, 46), line, 30, Color(0.45, 0.68, 1.0))
			Glyph.text(self, serif, Vector2(W * 0.5 - 14, 44), "%d:%02d" % [left / 60, left % 60], 16, Color(0.85, 0.85, 0.85))
			Glyph.text(self, serif, Vector2(W * 0.5 + 44, 46), "%d" % theirs, 30, Color(1.0, 0.4, 0.35))
		if g.darkfriend:
			Glyph.text(self, sans, Vector2(300, 70), "%s: the Shadow's gateway" % Keys.name(KEY_J), 12, Color(0.85, 0.3, 0.3, 0.8))
		var picks: int = p.get("round", {}).get("picks", 0)
		if picks > 0:
			Glyph.text(self, sans, Vector2(420, 46), "%s: choose (%d)" % [Keys.name(KEY_TAB), picks], 14, Color(1.0, 0.92, 0.6, 0.6 + 0.4 * sin(t * 4.0)))

	_bond_sense(W, H, sc)
	_ward_sense(W, H, sc)

	# Health and stamina.
	var bx := 30.0; var by := H - 74.0
	Glyph.bar(self, Vector2(bx, by), 330, 16, hp, Color(0.85, 0.16, 0.12), Color(0.55, 0.05, 0.05))
	var me_a: Dictionary = g.actors.get(g.session.my_id, {}) if g.session else {}
	if me_a.get("downed", false):
		# Down: no number to watch; what gets you up is what matters.
		Glyph.text(self, sans, Vector2(bx + 352, by + 14), "DOWN", 15, Color(1.0, 0.35, 0.3, 0.7 + 0.3 * sin(t * 5.0)))
		var how := "a friend must stand over you, or one more blow ends it" if g.in_battle else "up when the wave ends if a friend is beside you, or when Healed; alone, you die"
		Glyph.text(self, sans, Vector2(bx, by - 10), how, 13, Color(1.0, 0.75, 0.7))
	else:
		Glyph.text(self, sans, Vector2(bx + 352, by + 14), "%d" % int(maxf(g.my_hp, 0.0)), 15, Color(1, 0.9, 0.88))
	var st: float = g.my_stamina / Rules.TUNE.stamina
	Glyph.bar(self, Vector2(bx - 6, by + 24), 330, 9, st, Color(0.85, 0.9, 1.0), Color(0.35, 0.5, 0.85))
	var vig := Rules.vigor(g.my_stamina)
	var tired := ("tired: weaves at %d%%" % int(vig * 100.0) if vig < 0.995 else "") if p.get("cls", "channeller") == "channeller" else ("tired: blows at %d%%" % int(vig * 100.0) if vig < 0.995 else "")
	Glyph.text(self, sans, Vector2(bx - 6, by + 54), tired, 13, Color(0.75, 0.8, 0.9) if vig > 0.6 else Color(1.0, 0.7, 0.45))

	if g.dreaming:
		# Will, and what the dream will do for you, each on its key.
		Glyph.bar(self, Vector2(bx - 6, by - 16), 330, 9, g.my_will / 100.0, Color(0.86, 0.82, 1.0), Color(0.5, 0.4, 0.9))
		Glyph.text(self, sans, Vector2(bx + 334, by - 7), "will", 12, Color(0.75, 0.72, 0.95))
		# The dream bar, bottom right: eight slots, each on its key, drawn by what
		# the ability does; grey when the Will is not there for it.
		var keyof := {}
		for k in g.dream_keys:
			keyof[g.dream_keys[k]] = k
		var n_d: int = g.dream_bar.size()
		var dgap := 50.0
		var dx0 := W - 34.0 - dgap * (n_d - 1)
		var dyy := H - 62.0
		Glyph.text(self, sans, Vector2(dx0 + dgap * (n_d - 1) * 0.5, dyy - 48.0), "Dream   ·   %s: all of them" % Keys.name(KEY_I), 12, Color(0.8, 0.78, 1.0, 0.85), 0)
		for i in n_d:
			var mid: String = g.dream_bar[i]
			var mv: Dictionary = Dream.moves[mid]
			var can: bool = g.my_will >= float(mv.cost)
			var c := Vector2(dx0 + i * dgap, dyy)
			draw_circle(c, 21.0, Color(0.05, 0.04, 0.09, 0.6))
			draw_arc(c, 21.0, 0, TAU, 32, Color(Dreamfx.PALE, 0.8 if can else 0.25), 1.5, true)
			_dream_icon(c, 13.0, mid, Color(0.9, 0.88, 1.0) if can else Color(0.45, 0.45, 0.5))
			if keyof.has(i):
				Glyph.text(self, sans, c + Vector2(0, -27), Keys.name(keyof[i]), 12, Color(0.95, 0.9, 0.7) if can else Color(0.55, 0.55, 0.6), 0)
			Glyph.text(self, sans, c + Vector2(0, 34), "%d" % int(mv.cost), 11, Color(0.8, 0.78, 1.0) if can else Color(0.5, 0.5, 0.55), 0)

	# The weaves you know.
	var known: Array = g.known
	var n := known.size()
	if n > 0:
		var gap := minf(78.0, (W - 860.0) / maxf(n, 1.0))
		gap = maxf(gap, 46.0)
		var x0 := W * 0.5 - gap * (n - 1) * 0.5
		var y := H - 62.0
		_slots = []
		for i in n:
			_slots.append(Vector2(x0 + i * gap, y) * sc)
		_slot_r = 26.0 * minf(gap / 60.0, 1.0) * sc
		for i in n:
			var id: String = known[i]
			var sel: bool = i == g.selected
			var r := (30.0 if sel else 22.0) * minf(gap / 60.0, 1.0)
			var c := Vector2(x0 + i * gap, y - (8.0 if sel else 0.0))
			if g.drag_slot == i:
				c = g.drag_at / sc
			# Every slot sits on its own dark disc, so the bar reads as slots.
			draw_circle(c, r + 2.0, Color(0.03, 0.03, 0.05, 0.45))
			if sel:
				draw_circle(c, r + 7.0, Color(Glyph.GOLD, 0.16 + 0.05 * sin(t * 3.0)))
				draw_arc(c, r + 4.0, 0, TAU, 40, Glyph.GOLD, 2.0, true)
			if Rules.weapons.has(id):
				# A weapon: its outline, and what is left to shoot or throw.
				var left: int = g.ammo.get(id, 0)
				var uses: bool = Rules.weapons[id].has("shot") or Rules.weapons[id].has("throw")
				Glyph.weapon(self, c, r, Rules.weapons[id].family, 1.0 if not uses or left > 0 or not Rules.moves[Rules.weapons[id].light[0]].get("missile", false) else 0.35)
				if uses:
					Glyph.text(self, sans, c + Vector2(r * 0.75, r * 0.95), str(left), 13, Color.WHITE if left > 0 else Color(1.0, 0.5, 0.4), 0)
				if i < 9:
					Glyph.text(self, sans, c + Vector2(0, -r - 9), Keys.name(KEY_1 + i), 12, Glyph.GOLD if sel else Color(0.7, 0.7, 0.75), 0)
				continue
			var is_form: bool = Rules.forms.has(id)
			var total: float = float(Rules.forms[id].cooldown) if is_form else Rules.cooldown(p, id)
			var wait: float = g.ready_at.get(id, 0.0) - g.clock
			if is_form:
				# A form: its weapon's outline inside a second, golden ring.
				Glyph.weapon(self, c, r, Rules.forms[id].family, 1.0 if wait <= 0.0 else 0.45)
				draw_arc(c, r * 0.72, 0, TAU, 32, Color(Glyph.GOLD, 0.9 if wait <= 0.0 else 0.3), r * 0.06, true)
			else:
				Glyph.weave(self, c, r, Rules.flows_of(Rules.weaves[id], p), 1.0 if wait <= 0.0 else 0.45, t * 0.25 if sel else 0.0)
				# Held: a bright ring. Tied off: the ring broken into a knot's four marks.
				var hs: int = g.holding(id)
				# In the hands or kept aside: a ring that fills as it is made, gold and
				# beating when whole. "kept" under a weave put aside for later.
				var inh: Dictionary = g.my_form if not g.my_form.is_empty() and g.my_form.weave == id else (g.my_kept if not g.my_kept.is_empty() and g.my_kept.weave == id else {})
				if not inh.is_empty():
					var whole: bool = inh.get("ready", false)
					var ff: float = 1.0 if whole else clampf(inh.get("done", 0.0) / maxf(inh.get("time", 1.0), 0.05), 0.0, 1.0)
					var col: Color = Glyph.GOLD if whole else Weavefx.colour(id).lerp(Color.WHITE, 0.35)
					draw_arc(c, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * ff, 40, col, 3.0, true)
					if whole:
						draw_arc(c, r + 9.0 + 1.5 * sin(t * 8.0), 0, TAU, 40, Color(Glyph.GOLD, 0.45), 1.5, true)
					var word := ("ready" if whole else "weaving") if inh == g.my_form else ("kept · ready" if whole else "kept")
					Glyph.text(self, sans, c + Vector2(0, r + 16), word, 11, Glyph.GOLD if whole else Color(0.9, 0.9, 1.0), 0)
				elif hs == 1:
					draw_arc(c, r + 2.0, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.5, true)
					Glyph.text(self, sans, c + Vector2(0, r + 16), "held", 11, Color.WHITE, 0)
				elif hs == 2:
					for q in 4:
						draw_arc(c, r + 2.0, q * PI * 0.5 + 0.3, q * PI * 0.5 + 1.27, 10, Color(Glyph.GOLD, 0.95), 2.5, true)
					Glyph.text(self, sans, c + Vector2(0, r + 16), "tied", 11, Glyph.GOLD, 0)
				elif g.autos.has(id):
					Glyph.text(self, sans, c + Vector2(0, r + 16), "by itself", 11, Glyph.GOLD, 0)
			if wait > 0.0 and total > 0.0:
				# The cooldown drains like a clock face.
				var f := clampf(wait / total, 0.0, 1.0)
				var pts := PackedVector2Array([c])
				for k in 25:
					var a := -PI * 0.5 - TAU * f * k / 24.0
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				if pts.size() > 3 and f > 0.02:
					draw_colored_polygon(pts, Color(0, 0, 0, 0.62))
				Glyph.text(self, sans, c + Vector2(0, 5), "%.1f" % wait, 14, Color.WHITE, 0)
			if i < 9:
				Glyph.text(self, sans, c + Vector2(0, -r - 9), Keys.name(KEY_1 + i), 12, Glyph.GOLD if sel else Color(0.7, 0.7, 0.75), 0)
		# The forms of the weapon in hand: a row of their own beside the bar, not things
		# to hold. Each is drawn as the path it cuts, in its colour; Z, X, R, then Shift
		# and a number.
		var hf: Array = g._hand_forms()
		if not hf.is_empty():
			var fx0 := x0 + gap * (n - 1) + maxf(gap, 60.0) + 24.0
			var fgap := 62.0
			var fy := y
			var fam: String = Rules.forms[hf[0]].family
			draw_line(Vector2(fx0 - 34.0, fy - 26.0), Vector2(fx0 - 34.0, fy + 26.0), Color(Glyph.GOLD, 0.35), 1.2)
			Glyph.text(self, sans, Vector2(fx0 - 26.0, fy - 46.0), "Forms · %s" % fam.capitalize(), 11, Color(Glyph.GOLD, 0.75), -1)
			for i in hf.size():
				var fid: String = hf[i]
				var fr: Dictionary = Rules.forms[fid]
				var c := Vector2(fx0 + i * fgap, fy)
				var wait: float = g.ready_at.get(fid, 0.0) - g.clock
				var ok := wait <= 0.0
				var tint: Color = Color(fr.tint[0], fr.tint[1], fr.tint[2]) if fr.has("tint") else Glyph.GOLD
				draw_circle(c, 23.0, Color(0.05, 0.04, 0.03, 0.55))
				draw_arc(c, 23.0, 0, TAU, 36, Color(tint, 0.85 if ok else 0.3), 1.6, true)
				_form_icon(c, 15.0, fr, Color(tint.lerp(Color.WHITE, 0.25), 1.0 if ok else 0.35))
				if not ok:
					var total := maxf(float(fr.cooldown), 0.01)
					var pts := PackedVector2Array([c])
					var frac := clampf(wait / total, 0.0, 1.0)
					for k in 25:
						pts.append(c + Vector2(0, -23.0).rotated(TAU * frac * k / 24.0))
					if frac > 0.02:
						draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
					Glyph.text(self, sans, c + Vector2(0, 5), "%.0f" % ceilf(wait), 13, Color.WHITE, 0)
				var key := ""
				if i < g.FORM_KEYS.size():
					key = Keys.name(g.FORM_KEYS[i])
				elif i < 9:
					key = "⇧" + Keys.name(KEY_1 + i)
				Glyph.text(self, sans, c + Vector2(0, -30), key, 12, Color(0.95, 0.9, 0.7) if ok else Color(0.55, 0.55, 0.6), 0)
				var nm: String = fr.name
				if nm.begins_with("The "):
					nm = nm.substr(4)
				if nm.length() > 16:
					nm = nm.left(15) + "…"
				# Every other name a line lower, so neighbours' names do not run together.
				Glyph.text(self, sans, c + Vector2(0, 37 + (12 if i % 2 == 1 else 0)), nm, 10, Color(0.85, 0.85, 0.9, 0.9 if ok else 0.45), 0)
		if not g.my_kept.is_empty():
			# What is kept, and how to have it.
			var kw: Dictionary = Rules.weaves.get(g.my_kept.weave, {})
			Glyph.text(self, sans, Vector2(W * 0.5, H - 150.0), "%s kept%s   ·   %s: take it up   ·   right click with empty hands: let it go" % [kw.get("name", ""), " and ready" if g.my_kept.get("ready", false) else "", g._slot_key(g.my_kept.weave)], 12, Color(Glyph.GOLD, 0.85), 0)
		var sel_id: String = known[g.selected]
		var sw: Dictionary = Rules.forms[sel_id] if Rules.forms.has(sel_id) else (Rules.weapons[sel_id] if Rules.weapons.has(sel_id) else Rules.weaves[sel_id])
		Glyph.text(self, serif, Vector2(W * 0.5, H - 132.0), sw.name, 22, Color(0.97, 0.94, 0.88), 0)
		if Rules.weaves.has(sel_id):
			# What the chosen weave costs in time: there is nothing else to wait for.
			Glyph.text(self, sans, Vector2(W * 0.5, H - 114.0), "%.1f s to weave" % Rules.form_time(p, sel_id), 12, Color(0.75, 0.78, 0.86), 0)

	# Crosshair: a ring that fills as the chosen weave comes ready.
	var cc := Vector2(W, H) * 0.5
	draw_arc(cc, 9.0, 0, TAU, 28, Color(0, 0, 0, 0.5), 3.5, true)
	draw_arc(cc, 9.0, 0, TAU, 28, Color(1, 1, 1, 0.85), 1.5, true)
	draw_circle(cc, 1.6, Color(1, 1, 1, 0.9))
	if not g.my_form.is_empty():
		# A weave in the making: the ring fills as it is woven, and turns gold and
		# beats when it is whole and waiting to be let go.
		var f: float = 1.0 if g.my_form.get("ready", false) else clampf(g.my_form.get("done", 0.0) / maxf(g.my_form.time, 0.05), 0.0, 1.0)
		var col: Color = Weavefx.colour(g.my_form.weave).lerp(Color.WHITE, 0.3)
		draw_arc(cc, 15.0, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Glyph.GOLD if f >= 1.0 else col, 3.0, true)
		if f >= 1.0:
			draw_arc(cc, 20.0 + 2.0 * sin(t * 12.0), 0, TAU, 40, Color(Glyph.GOLD, 0.55), 1.5, true)
			var say := "let go to loose" if g.weaving else ""
			if g.my_form.get("marked", false):
				say = "click for the far end"
			elif g.weaving and Rules.weaves[g.my_form.weave].kind == "gate":
				say = "let go: the near end"
			Glyph.text(self, sans, cc + Vector2(0, 44), say, 13, Color(Glyph.GOLD, 0.9), 0)
		if g._placing():
			# A wall or a gateway end: how it will stand, and the keys that change it.
			Glyph.text(self, sans, cc + Vector2(0, 62), "%s   ·   %s: shape   ·   wheel: turn" % [g._shape_name(), Keys.name(KEY_T)], 12, Color(1, 1, 1, 0.75), 0)
	elif n > 0 and Rules.forms.has(known[g.selected]) and g.held_since < 0.0:
		var id: String = known[g.selected]
		var total: float = float(Rules.forms[id].cooldown)
		var wait: float = g.ready_at.get(id, 0.0) - g.clock
		if wait > 0.0 and total > 0.0:
			draw_arc(cc, 15.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - wait / total), 32, Glyph.GOLD, 2.5, true)
	elif armed and in_hand.get("shot", {}).get("crank", false):
		# A crossbow: the ring is the crank. Full and gold, it is spanned.
		var need: float = Rules.draw_time(p, g.hand())
		var f: float = clampf(1.0 - (g.spanned.get(g.hand(), 0.0) - g.clock) / need, 0.0, 1.0)
		draw_arc(cc, 15.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Glyph.GOLD if f >= 1.0 else Color(1, 1, 1, 0.6), 2.5, true)
		if f < 1.0:
			Glyph.text(self, sans, cc + Vector2(0, 44), "spanning", 13, Color(1, 1, 1, 0.7), 0)
	elif armed and g.held_since >= 0.0:
		# Holding the attack: the ring fills as a bow is drawn, or to the point a
		# blow becomes a heavy one.
		var need: float = Rules.draw_time(p, g.hand()) if in_hand.has("shot") else 0.35
		var f: float = clampf((g.clock - g.held_since) / need, 0.0, 1.0)
		draw_arc(cc, 15.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Glyph.GOLD if f >= 1.0 else Color(1, 1, 1, 0.8), 2.5, true)
	if g.refusal_t > 0.0:
		Glyph.text(self, sans, cc + Vector2(0, 58), g.last_refusal, 17, Color(1.0, 0.6, 0.5, clampf(g.refusal_t * 2.0, 0.0, 1.0)), 0)
	if g.flash_t > 0.0 and g.flash_text != "":
		Glyph.text(self, serif, cc + Vector2(0, -46), g.flash_text, 22, Color(Glyph.GOLD, clampf(g.flash_t * 2.0, 0.0, 1.0)), 0)
	if g.flash_t > 0.6:
		draw_arc(cc, 20.0 + (1.0 - g.flash_t) * 40.0, 0, TAU, 40, Color(Glyph.GOLD, (g.flash_t - 0.6) * 2.0), 2.0, true)

	# The others with you.
	var row := 0
	for id in g.actors:
		var a: Dictionary = g.actors[id]
		if a.kind != "player" or id == g.session.my_id or int(a.get("status", 0)) & 1048576:
			continue
		# On the left under your own name: the top right is where notices arrive,
		# and "X is down" landed on top of X's own bar. In a battle, named in their
		# side's colour.
		var at := Vector2(30.0, 132.0 + row * 40.0)
		var col := Color(0.95, 0.93, 0.88)
		if g.in_battle:
			col = Color(0.55, 0.75, 1.0) if int(a.get("team", 0)) == g.my_team else Color(1.0, 0.5, 0.45)
		Glyph.text(self, serif, at, a.get("name", "?"), 17, col if not a.get("dead", false) else Color(0.6, 0.5, 0.5))
		Glyph.bar(self, at + Vector2(0, 8), 200, 8, 0.0 if a.get("dead", false) else a.get("hp", 100.0) / a.get("max_hp", 100.0), Color(0.85, 0.16, 0.12), Color(0.55, 0.05, 0.05))
		row += 1

## A Myrddraal near: the dark creeps in from the edges, closer and deeper the nearer it
## is, throbbing slowly, felt by those it most wants (channellers, and the Warders sworn
## to them). Eased, so it creeps rather than snaps. Deepest when it is beside you.
var _dark := 0.0
func _fade_dark(p: Dictionary, W: float, H: float) -> void:
	var want := 0.0
	if p.get("cls", "channeller") in ["channeller", "warder"] and g.me != null and is_instance_valid(g.me):
		var near := 1e9
		for id in g.actors:
			var a: Dictionary = g.actors[id]
			if a.get("fade", false) and not a.get("dead", false) and is_instance_valid(a.node):
				near = minf(near, (a.node as Node3D).global_position.distance_to(g.me.global_position))
		# Felt from 16 m, fully at arm's length.
		want = pow(clampf((16.0 - near) / (16.0 - 1.8), 0.0, 1.0), 1.6)
	_dark = move_toward(_dark, want, get_process_delta_time() * (0.7 if want > _dark else 0.4))
	if _dark < 0.01:
		return
	var beat := 0.8 + 0.2 * sin(t * 2.4)
	var k := _dark * beat
	# The whole view dims a little; the edges close in a lot.
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.02, 0.55 * k))
	var m := minf(W, H)
	for layer in 3:
		var depth := m * (0.18 + 0.16 * layer) * (0.45 + 0.55 * k)
		_vignette(Color(0.0, 0.0, 0.02, (0.72 - 0.16 * layer) * k), depth)

func _vignette(col: Color, depth: float) -> void:
	var W := size.x / (size.y / 720.0); var H := 720.0
	var clear := Color(col, 0.0)
	var o := [Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]
	var i := [Vector2(depth, depth), Vector2(W - depth, depth), Vector2(W - depth, H - depth), Vector2(depth, H - depth)]
	for k in 4:
		var k2 := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[k2], i[k2], i[k]]), PackedColorArray([col, col, clear, clear]))

## The bond: a Warder always knows where his channeller is, and she where he is, through
## walls and behind them. A knot over them (an arrow at the edge when out of sight), gold
## when whole, redder as they are hurt, throbbing when a blow lands, the distance beside.
func _bond_sense(W: float, H: float, sc: float) -> void:
	if g.cam == null or not g.has_method("bonded_ids"):
		return
	for id in g.bonded_ids():
		var a: Dictionary = g.actors[id]
		if a.get("dead", false):
			continue
		var at: Vector3 = (a.node as Node3D).global_position + Vector3(0, 2.3, 0)
		var f := clampf(float(a.get("hp", 1.0)) / maxf(float(a.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
		var throb := clampf(1.0 - (g.clock - float(a.get("hurt_at", -9.0))) / 0.6, 0.0, 1.0)
		var down: bool = a.get("downed", false)
		var col := Glyph.GOLD.lerp(Color(1.0, 0.2, 0.15), 1.0 - f)
		if down:
			col = Color(1.0, 0.15, 0.1, 0.6 + 0.4 * sin(t * 8.0))
		var behind: bool = g.cam.is_position_behind(at)
		var sp: Vector2 = g.cam.unproject_position(at) / sc
		var m := 46.0
		var dist: float = g.cam.global_position.distance_to(at)
		var r := 6.0 + 4.0 * throb
		if not behind and sp.x > m and sp.x < W - m and sp.y > m and sp.y < H - m:
			# In sight: a small knot over them, fainter close by where they are plain to see.
			var fade := clampf((dist - 5.0) / 6.0, 0.35, 1.0)
			_knot(sp, r, Color(col, col.a * fade))
			if dist > 12.0:
				Glyph.text(self, Glyph.sans(), sp + Vector2(r + 4, 4), "%d m" % int(dist), 11, Color(col, 0.7 * fade))
		else:
			# Out of sight: at the edge of the screen, pointing the way to them.
			var c := Vector2(W, H) * 0.5
			var d := (sp - c)
			if behind:
				d = -d
			if d.length() < 1.0:
				d = Vector2(0, 1)
			d = d.normalized()
			var k := minf((W * 0.5 - m) / maxf(absf(d.x), 0.001), (H * 0.5 - m) / maxf(absf(d.y), 0.001))
			var e := c + d * k
			_knot(e, r, col)
			var tip := e + d * (r + 12.0)
			var sd := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([tip, e + d * (r + 3.0) + sd * 5.0, e + d * (r + 3.0) - sd * 5.0]), col)
			Glyph.text(self, Glyph.sans(), e - d * (r + 16.0) + Vector2(-10, 4), "%d m" % int(dist), 11, Color(col, 0.8))

func _knot(c: Vector2, r: float, col: Color) -> void:
	# Two loops crossed: the mark of a bond, not of a target.
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
	draw_polyline(pts, col, 2.0, true)
	draw_arc(c, r * 0.45, 0, TAU, 14, col, 1.5, true)

## Guard the Aes Sedai: how long until the Waygate is sealed, her health, and where she is
## (a mark over her, or at the edge pointing the way).
func _ward_sense(W: float, H: float, sc: float) -> void:
	if g.ward.is_empty() or not g.actors.has(g.ward.id) or g.cam == null:
		return
	var a: Dictionary = g.actors[g.ward.id]
	var left := maxf(float(g.ward.until) - g.sim_now, 0.0)
	var f := clampf(float(a.get("hp", 1.0)) / maxf(float(a.get("max_hp", 1.0)), 1.0), 0.0, 1.0)
	var serif := Glyph.serif()
	var line := "The Waygate is sealed in %d:%02d" % [int(left) / 60, int(left) % 60]
	Glyph.text(self, serif, Vector2(W * 0.5 - 120, 92), line, 18, Color(0.85, 0.9, 1.0))
	Glyph.bar(self, Vector2(W * 0.5 - 120, 100), 240, 6, f, Color(0.85, 0.16, 0.12), Color(0.55, 0.05, 0.05))
	var throb := clampf(1.0 - (g.clock - float(a.get("hurt_at", -9.0))) / 0.6, 0.0, 1.0)
	var col := Color(0.8, 0.88, 1.0).lerp(Color(1.0, 0.25, 0.2), maxf(1.0 - f, throb * 0.8))
	if is_instance_valid(a.node):
		_point_at((a.node as Node3D).global_position + Vector3(0, 2.4, 0), col, 7.0 + 4.0 * throb, W, H, sc)

## A mark over a place in the world, or at the screen's edge pointing to it when it is out
## of sight, with the distance beside it.
func _point_at(at: Vector3, col: Color, r: float, W: float, H: float, sc: float) -> void:
	var behind: bool = g.cam.is_position_behind(at)
	var sp: Vector2 = g.cam.unproject_position(at) / sc
	var m := 46.0
	var dist: float = g.cam.global_position.distance_to(at)
	if not behind and sp.x > m and sp.x < W - m and sp.y > m and sp.y < H - m:
		draw_arc(sp, r, 0, TAU, 20, col, 2.0, true)
		draw_line(sp + Vector2(0, -r * 0.5), sp + Vector2(0, r * 0.5), col, 2.0, true)
		draw_line(sp + Vector2(-r * 0.5, 0), sp + Vector2(r * 0.5, 0), col, 2.0, true)
		return
	var c := Vector2(W, H) * 0.5
	var d := sp - c
	if behind:
		d = -d
	d = d.normalized() if d.length() > 1.0 else Vector2(0, 1)
	var k := minf((W * 0.5 - m) / maxf(absf(d.x), 0.001), (H * 0.5 - m) / maxf(absf(d.y), 0.001))
	var e := c + d * k
	draw_arc(e, r, 0, TAU, 20, col, 2.0, true)
	var tip := e + d * (r + 12.0)
	var sd := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([tip, e + d * (r + 3.0) + sd * 5.0, e + d * (r + 3.0) - sd * 5.0]), col)
	Glyph.text(self, Glyph.sans(), e - d * (r + 16.0) + Vector2(-10, 4), "%d m" % int(dist), 11, Color(col, 0.8))

## A form's mark: the path it cuts (its trail), or for a missile form the shots it
## looses (a fan, one through a rank, a fire arrow); dots under it for each blow of a
## flurry.
func _form_icon(c: Vector2, r: float, f: Dictionary, col: Color) -> void:
	var w := maxf(r * 0.16, 1.6)
	var arrow := func(a: Vector2, b: Vector2) -> void:
		draw_line(a, b, col, w, true)
		var d := (b - a).normalized()
		draw_line(b, b - d.rotated(0.5) * r * 0.38, col, w, true)
		draw_line(b, b - d.rotated(-0.5) * r * 0.38, col, w, true)
	if f.get("missile", false):
		var n := int(f.get("count", 1))
		var spread := deg_to_rad(float(f.get("spread", 0.0))) * 1.6 + (0.5 if n > 1 else 0.0)
		for i in n:
			var a := -PI * 0.25 + (spread * ((i + 0.5) / n - 0.5) if n > 1 else 0.0)
			var dir := Vector2(cos(a), sin(a))
			arrow.call(c - dir * r * 0.85, c + dir * r * 0.85)
		if int(f.get("pierce", 0)) > 0:
			for k in mini(int(f.pierce), 3):
				var at := c + Vector2(r * 0.15 + k * r * 0.3, -r * 0.15 - k * r * 0.3)
				draw_line(at + Vector2(-r * 0.25, -r * 0.25), at + Vector2(r * 0.25, r * 0.25), col, w * 0.8, true)
		if f.get("lit", false):
			var tip := c + Vector2(r * 0.6, -r * 0.6)
			draw_circle(tip, r * 0.3, Color(1.0, 0.55, 0.15, col.a))
			draw_circle(tip + Vector2(0, -r * 0.12), r * 0.16, Color(1.0, 0.9, 0.5, col.a))
	else:
		match String(f.get("trail", "arc")):
			"lance":
				arrow.call(c + Vector2(-r, r) * 0.7, c + Vector2(r, -r) * 0.75)
			"down":
				arrow.call(c + Vector2(0.15, -1.0) * r, c + Vector2(-0.1, 0.9) * r)
			"low":
				draw_arc(c + Vector2(0, -r * 0.35), r * 0.95, 0.35, PI - 0.35, 20, col, w, true)
			"wide":
				draw_arc(c + Vector2(0, r * 0.7), r * 1.25, -PI + 0.55, -0.55, 24, col, w, true)
			"ring":
				draw_arc(c, r * 0.75, 0.4, TAU - 0.2, 28, col, w, true)
				arrow.call(c + Vector2(r * 0.75, 0).rotated(TAU - 0.6), c + Vector2(r * 0.75, 0).rotated(TAU - 0.15))
			"cross":
				draw_line(c + Vector2(-r, -r) * 0.7, c + Vector2(r, r) * 0.7, col, w, true)
				draw_line(c + Vector2(r, -r) * 0.7, c + Vector2(-r, r) * 0.7, col, w, true)
			"fan":
				for k in 3:
					var a := -PI * 0.5 + (k - 1) * 0.55
					draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, r * 0.8) + Vector2(cos(a), sin(a)) * r * 1.5, col, w, true)
			_:
				draw_arc(c, r * 0.8, -PI + 0.5, -0.4, 22, col, w, true)
				var tip := c + Vector2(r * 0.8, 0).rotated(-0.4)
				draw_line(tip, tip + Vector2(-r * 0.35, -r * 0.1), col, w, true)
	var reps := int(f.get("repeat", 1))
	if reps > 1:
		for k in mini(reps, 6):
			draw_circle(c + Vector2((k - (mini(reps, 6) - 1) * 0.5) * r * 0.32, r * 1.05), r * 0.08, col)
	if float(f.get("spin", 0.0)) > 0.0 and String(f.get("trail", "")) != "ring":
		draw_arc(c, r * 1.1, -0.3, 1.4, 12, Color(col, col.a * 0.6), w * 0.6, true)
