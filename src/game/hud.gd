class_name Hud
extends Control
## The fight's HUD, drawn by hand so it can look like the game and not like a
## debug overlay. It only reads the game view's state; it decides nothing.

var g: Node          # the game view (game.gd)
var t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	if g == null or g.profile.is_empty() or g.session == null:
		return
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

	# Who you are.
	Glyph.text(self, serif, Vector2(30, 46), p.name, 30, Color(0.97, 0.94, 0.88))
	draw_line(Vector2(30, 56), Vector2(290, 56), Color(Glyph.GOLD, 0.6), 1.5, true)
	var cap := Rules.flow_capacity(p)
	var armed: bool = g._armed()
	var in_hand: Dictionary = Rules.weapons[g.hand()] if g.hand() != "" else {}
	if p.get("cls", "channeller") == "channeller":
		# In a round your potential is yours to find out: only where you stand now.
		var line := "strength %s" % Rules.level_name(Rules.level_of(Rules.strength(p))) if p.has("round") else "strength %s   of %s" % [Rules.level_name(Rules.level_of(Rules.strength(p))), Rules.level_name(Rules.level_of(p.potential))]
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
		var lv: int = g.team_meter[0]
		Glyph.text(self, serif, Vector2(300, 46), "Level %d" % lv, 20, Glyph.GOLD)
		Glyph.bar(self, Vector2(300, 52), 110, 5, float(g.team_meter[1]), Glyph.GOLD, Color(1.0, 0.9, 0.6))
		if g.darkfriend:
			Glyph.text(self, sans, Vector2(300, 70), "%s: the Shadow's gateway" % Keys.name(KEY_J), 12, Color(0.85, 0.3, 0.3, 0.8))
		var picks: int = p.get("round", {}).get("picks", 0)
		if picks > 0:
			Glyph.text(self, sans, Vector2(420, 46), "%s: choose (%d)" % [Keys.name(KEY_TAB), picks], 14, Color(1.0, 0.92, 0.6, 0.6 + 0.4 * sin(t * 4.0)))

	# Health and stamina.
	var bx := 30.0; var by := H - 74.0
	Glyph.bar(self, Vector2(bx, by), 330, 16, hp, Color(0.85, 0.16, 0.12), Color(0.55, 0.05, 0.05))
	Glyph.text(self, sans, Vector2(bx + 352, by + 14), "%d" % int(maxf(g.my_hp, 0.0)), 15, Color(1, 0.9, 0.88))
	var st: float = g.my_stamina / Rules.TUNE.stamina
	Glyph.bar(self, Vector2(bx - 6, by + 24), 330, 9, st, Color(0.85, 0.9, 1.0), Color(0.35, 0.5, 0.85))
	var vig := Rules.vigor(g.my_stamina)
	var tired := ("weaves at %d%%  ·  as strength %s" % [int(vig * 100.0), Rules.level_name(Rules.level_of(Rules.strength(p) * vig))]) if p.get("cls", "channeller") == "channeller" else "blows at %d%% strength" % int(vig * 100.0)
	Glyph.text(self, sans, Vector2(bx - 6, by + 54), tired, 13, Color(0.75, 0.8, 0.9) if vig > 0.6 else Color(1.0, 0.7, 0.45))

	if g.dreaming:
		# Will, and what the dream will do for you, each on its key.
		Glyph.bar(self, Vector2(bx - 6, by - 16), 330, 9, g.my_will / 100.0, Color(0.86, 0.82, 1.0), Color(0.5, 0.4, 0.9))
		Glyph.text(self, sans, Vector2(bx + 334, by - 7), "will", 12, Color(0.75, 0.72, 0.95))
		var dy := H - 300.0
		for k in g.dream_keys:
			var mv: Dictionary = Dream.moves[g.dream_keys[k]]
			var can: bool = g.my_will >= float(mv.cost)
			Glyph.text(self, sans, Vector2(W - 250, dy), "%s" % Keys.name(k), 14, Color(0.95, 0.9, 0.7) if can else Color(0.5, 0.5, 0.55))
			Glyph.text(self, sans, Vector2(W - 190, dy), "%s  %d" % [mv.name, int(mv.cost)], 14, Color(0.86, 0.84, 1.0) if can else Color(0.5, 0.5, 0.55))
			dy += 21.0

	# The weaves you know.
	var known: Array = g.known
	var n := known.size()
	if n > 0:
		var gap := minf(78.0, (W - 860.0) / maxf(n, 1.0))
		gap = maxf(gap, 46.0)
		var x0 := W * 0.5 - gap * (n - 1) * 0.5
		var y := H - 62.0
		for i in n:
			var id: String = known[i]
			var sel: bool = i == g.selected
			var r := (30.0 if sel else 22.0) * minf(gap / 60.0, 1.0)
			var c := Vector2(x0 + i * gap, y - (8.0 if sel else 0.0))
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
					Glyph.text(self, sans, c + Vector2(0, -r - 9), str(i + 1), 12, Glyph.GOLD if sel else Color(0.7, 0.7, 0.75), 0)
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
				if hs == 1:
					draw_arc(c, r + 2.0, 0, TAU, 40, Color(1, 1, 1, 0.9), 2.5, true)
					Glyph.text(self, sans, c + Vector2(0, r + 16), "held", 11, Color.WHITE, 0)
				elif hs == 2:
					for q in 4:
						draw_arc(c, r + 2.0, q * PI * 0.5 + 0.3, q * PI * 0.5 + 1.27, 10, Color(Glyph.GOLD, 0.95), 2.5, true)
					Glyph.text(self, sans, c + Vector2(0, r + 16), "tied", 11, Glyph.GOLD, 0)
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
				Glyph.text(self, sans, c + Vector2(0, -r - 9), str(i + 1), 12, Glyph.GOLD if sel else Color(0.7, 0.7, 0.75), 0)
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
		var f: float = clampf((g.clock - g.my_form.since) / maxf(g.my_form.time, 0.05), 0.0, 1.0)
		var col: Color = Weavefx.colour(g.my_form.weave).lerp(Color.WHITE, 0.3)
		draw_arc(cc, 15.0, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Glyph.GOLD if f >= 1.0 else col, 3.0, true)
		if f >= 1.0:
			draw_arc(cc, 20.0 + 2.0 * sin(t * 12.0), 0, TAU, 40, Color(Glyph.GOLD, 0.55), 1.5, true)
			Glyph.text(self, sans, cc + Vector2(0, 44), "let go to loose" if g.weaving else "", 13, Color(Glyph.GOLD, 0.9), 0)
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
		if a.kind != "player" or id == g.session.my_id:
			continue
		var at := Vector2(W - 250.0, 40.0 + row * 44.0)
		Glyph.text(self, serif, at, a.get("name", "?"), 18, Color(0.95, 0.93, 0.88) if not a.get("dead", false) else Color(0.6, 0.5, 0.5))
		Glyph.bar(self, at + Vector2(0, 8), 200, 8, 0.0 if a.get("dead", false) else a.get("hp", 100.0) / 100.0, Color(0.85, 0.16, 0.12), Color(0.55, 0.05, 0.05))
		row += 1

func _vignette(col: Color, depth: float) -> void:
	var W := size.x / (size.y / 720.0); var H := 720.0
	var clear := Color(col, 0.0)
	var o := [Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]
	var i := [Vector2(depth, depth), Vector2(W - depth, depth), Vector2(W - depth, H - depth), Vector2(depth, H - depth)]
	for k in 4:
		var k2 := (k + 1) % 4
		draw_polygon(PackedVector2Array([o[k], o[k2], i[k2], i[k]]), PackedColorArray([col, col, clear, clear]))
