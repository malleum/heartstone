class_name Bot
extends RefCounted

## Someone who bears arms: shoot or throw while they are far, then close, cut,
## and raise a guard (or step back, with a weapon that cannot guard) when a blow
## is about to land.
static func _fight(sim: Sim, id: int, me: Dictionary, near: Dictionary, best: float, to: Vector3) -> void:
	var ranged := ""; var melee := ""
	for w in me.profile.kit:
		var missile: bool = Rules.moves[Rules.weapons[w].light[0]].get("missile", false)
		if missile and me.ammo.get(w, 0) > 0 and ranged == "": ranged = w
		if not missile and melee == "": melee = w
	var want: String = ranged if ranged != "" and (best > 7.0 or melee == "") else melee
	if want == "":
		want = me.profile.kit[0]
	# Something at arm's length while a bow is drawn: drop the draw and take up
	# the blade (the draw kept the swing busy, so it never changed).
	if me.weapon == ranged and want != ranged and best < 2.5 and not me.swing.is_empty() and not me.swing.get("struck", false):
		me.swing = {}; me.drawing = false
	if me.weapon != want and me.swing.is_empty():
		sim.equip(id, want)
	if me.weapon == "":
		return
	var yaw := atan2(to.x, to.z)
	# Badly hurt and pressed by several, break off and outrun them, as a person would;
	# back to it once half mended, or when only one or two are left to deal with
	# (healing on your own is slow: a long chase only ends one way).
	var pressing := 0
	for k in sim.ents:
		var o: Dictionary = sim.ents[k]
		if o.alive and o.team != me.team and o.pos.distance_to(me.pos) < 9.0:
			pressing += 1
	if me.hp < me.max_hp * 0.35 and pressing >= 3:
		me.bot_flee = true
	elif me.hp > me.max_hp * 0.5 or pressing <= 2:
		me.bot_flee = false
	if me.get("bot_flee", false) and near.speed > 0.0:
		sim.set_guard(id, false)
		# One roll to get clear; after that, legs.
		if best < 2.5 and me.stamina > 200.0:
			sim.request_dodge(id, -to)
		# Run from them, but round the field's edge and not into a corner.
		var away := -to
		if me.pos.length() > 30.0:
			away = (away - me.pos.normalized() * 1.5).normalized()
		# Turned to run, as a person does (backing away is slow).
		sim.set_input(id, away if best < 14.0 else Vector3.ZERO, atan2(away.x, away.z) if best < 14.0 else yaw)
		return
	if me.weapon == ranged:
		sim.set_guard(id, false)
		sim.set_input(id, -to if best < 6.0 and near.speed > 0.0 else Vector3.ZERO, yaw)
		sim.request_attack(id, "light", sim.aim_missile(me, me.weapon, near))
		return
	var threats := 0
	var danger := to
	var low := false
	for eid in sim.ents:
		var e: Dictionary = sim.ents[eid]
		if e.alive and e.kind == "enemy" and e.swung and e.atk >= e.blow.time - 0.25 and e.pos.distance_to(me.pos) < e.blow.reach * 1.2 + 1.0:
			threats += 1
			danger = e.pos - me.pos
			low = low or e.blow.get("height", "") == "low"
	# A trip coming: over it.
	if low and me.swing.is_empty() and sim.request_jump(id) == "":
		return
	var reach: float = Rules.weapons[me.weapon].reach + near.radius
	# One blow coming can be met on the steel. Several at once cannot: when hurt,
	# roll out from among them; otherwise keep cutting, which is the best defence.
	if threats > 0 and me.swing.is_empty():
		if Rules.guard_share(me.profile, me.weapon) > 0.3 and (threats == 1 or me.hp > me.max_hp * 0.5):
			# Turn the guard to the blow that is coming.
			sim.set_input(id, Vector3.ZERO, atan2(danger.x, danger.z))
			sim.set_guard(id, true)
			return
		if me.hp < me.max_hp * 0.5 and sim.request_dodge(id, -to) == "":
			return
	sim.set_guard(id, false)
	# Hold your ground and let them come; only close the last stretch. Where there
	# is a line to hold (the breastwork, its stakes in front), do not leave it.
	var go := to if best > reach * 0.75 and best < 16.0 else Vector3.ZERO
	if Map.m.get("breastwork", false) and me.pos.z + go.normalized().z * 0.5 < Map.line_z() - 1.0:
		go = Vector3.ZERO
	sim.set_input(id, go, yaw)
	if best < reach * 0.95:
		# Pressed by several, clear room: a wide heavy blow, or take their legs.
		var close := 0
		for eid in sim.ents:
			var e: Dictionary = sim.ents[eid]
			if e.alive and e.team != me.team and e.pos.distance_to(me.pos) < reach + 0.8:
				close += 1
		var row: Dictionary = Rules.weapons[me.weapon]
		var kind := "light"
		# A form, whenever one is ready and suits what is in hand.
		for f in me.profile.get("forms", {}):
			if me.swing.is_empty() and me.cd.get(f, 0.0) <= sim.t and Rules.form_block(me.profile, f, me.weapon) == "" and (close >= 2 or Rules.forms[f].get("hits", 1) == 1):
				if sim.request_attack(id, "form:" + f, near.pos + Vector3(0, 1.0, 0)) == "":
					return
		if close >= 3 and me.swing.is_empty():
			kind = "heavy" if Rules.moves[row.heavy].arc >= 100 else ("low" if Rules.moves[row.low].get("hits", 1) >= 3 else "light")
		# A bandleader standing guard: break it with a heavy blow.
		if near.get("row", {}).has("guards") and near.stagger <= 0.0:
			kind = "heavy"
		sim.request_attack(id, kind, near.pos + Vector3(0, 1.0, 0))
## A stand-in player for tests and soak runs: kites and casts the hardest-hitting
## weave it can. Not an AI opponent, just enough to exercise the rules.

static func drive(sim: Sim, id: int) -> void:
	var me: Dictionary = sim.ents[id]
	if not me.alive:
		return
	if me.get("downed", false):
		return
	# Seized: twist free at once.
	if me.get("grabbed_by", 0) != 0:
		sim.request_dodge(id, Vector3.ZERO, true)
		return
	# Knocked down: roll up and away at once.
	if me.get("lying", false):
		sim.request_dodge(id, Vector3.ZERO, true)
		return
	# A friend down nearby comes first: stand over them until they are up.
	for k in sim.ents:
		var o: Dictionary = sim.ents[k]
		if o.kind == "player" and o.alive and o.get("downed", false) and k != id and o.team == me.team and o.pos.distance_to(me.pos) < 30.0:
			var to: Vector3 = (o.pos - me.pos) * Vector3(1, 0, 1)
			sim.set_input(id, to.normalized() if to.length() > 1.0 else Vector3.ZERO, atan2(to.x, to.z))
			return
	# A bot spends its level-ups at once, on whatever its tree offers first.
	if me.profile.get("round", {}).get("picks", 0) > 0:
		var ch := Round.choices(me.profile)
		if not ch.is_empty():
			var c: Dictionary = ch[sim.rng.randi() % ch.size()]
			sim.request_pick(id, c.kind, c.id)
		else:
			me.profile.round.picks = 0
	var near: Dictionary = {}
	var best := 1e9
	var crowd := 0
	for eid in sim.ents:
		var e: Dictionary = sim.ents[eid]
		if e.alive and e.team != me.team:
			var d: float = e.pos.distance_to(me.pos)
			if d < 9.0: crowd += 1
			if d < best:
				best = d; near = e
	if near.is_empty():
		sim.set_input(id, Vector3.ZERO, me.yaw)
		return
	var to: Vector3 = (near.pos - me.pos).normalized()
	if not me.profile.get("kit", []).is_empty() and (me.profile.get("cls", "channeller") != "channeller" or me.profile.weaves.is_empty()):
		_fight(sim, id, me, near, best, to)
		return
	# Held weaves, when there are flows to spare for them: a dome when they are
	# near, bonds on the nearest, and both tied off if that has been learned.
	var free := sim.free_slots(me)
	if me.forming.is_empty() and best < 14.0:
		for h in me.held:
			if h.tied == 0.0 and Rules.has_technique(me.profile, "tie_off"):
				sim.tie(id, h.weave)
		var mine: Array = me.held.map(func(h: Dictionary) -> String: return h.weave)
		if free >= 2 and me.profile.weaves.has("dome_of_air") and not mine.has("dome_of_air") and me.cd.get("dome_of_air", 0.0) <= sim.t:
			if sim.request_cast(id, "dome_of_air", me.pos) == "":
				return
		elif free >= 2 and best < 10.0 and me.profile.weaves.has("bonds_of_air") and near.get("bound_by", 0) == 0 and near.speed > 0.0 and me.cd.get("bonds_of_air", 0.0) <= sim.t and mine.count("bonds_of_air") < 2:
			if sim.request_cast(id, "bonds_of_air", near.pos) == "":
				return
	var pick := ""; var score := 0.0
	var reach := 0.0
	for w in me.profile.weaves:
		var row: Dictionary = Rules.weaves[w]
		if row.kind in ["barrier", "heal", "sever", "utility", "bind", "gate", "curtain", "airwall"]:
			continue
		var rng: float = row.base.get("range", row.base.get("radius", 99.0))
		reach = maxf(reach, rng)
		# Do not weave fire at your own feet.
		if rng < best or (row.get("self", 0.0) > 0.0 and best < row.base.radius + 2.5) or (row.kind == "blossom" and best < row.base.radius_max + 2.0):
			continue
		if me.cd.get(w, 0.0) > sim.t or Rules.cast_block(me.profile, w, sim.free_slots(me), me.stamina) != "":
			continue
		var s: float = row.base.get("damage", row.base.get("dps", 0.0)) * row.base.get("count", 1) * (1.5 if crowd > 3 and row.kind in ["ring", "burst", "cone"] else 1.0)
		if s > score:
			score = s; pick = w
	# Close to weaving distance, back off when they get near, otherwise hold ground.
	var move := Vector3.ZERO
	if best < 6.0 and near.speed > 0.0:
		# Fall back toward the middle and the rear, not into the cliff beside you.
		move = (-to + Vector3(-signf(me.pos.x) * 0.5 if absf(me.pos.x) > 4.0 else 0.0, 0, 0.6 if not Map.m.is_empty() else 0.0)).normalized()
	elif best > reach * 0.8 and (not Map.m.get("breastwork", false) or me.pos.z > Map.line_z() + 3.0):
		# Where there is a line to hold, hold it: do not walk out in front of it.
		move = to
	sim.set_input(id, move, atan2(to.x, to.z))
	if not me.forming.is_empty():
		# A weave takes time to make: aim it where they are when it leaves.
		sim.aim_cast(id, sim.aim_at(me, me.forming.weave, near), false)
	elif pick != "":
		sim.request_cast(id, pick, sim.aim_at(me, pick, near))

## A dreamer's part of a bot, in Tel'aran'rhiod: unmake or be gone from what is
## coming, and use the dream against whoever is nearest. It thinks a few times a
## second and is wrong some of the time, as a person is.
static func dream(sim: Sim, id: int) -> void:
	var me: Dictionary = sim.ents[id]
	if not sim.dream or not me.alive or sim.t < me.get("bot_dream_t", 0.0):
		return
	me.bot_dream_t = sim.t + 0.18 + sim.rng.randf() * 0.2
	var near: Dictionary = {}
	var best := 1e9
	for e in sim._targets(me):
		var d: float = e.pos.distance_to(me.pos)
		if d < best:
			best = d; near = e
	if near.is_empty():
		return
	Dream.load_data()
	# What it can do: its own dream bar, as a player's (a shade fights with yours).
	var bar: Array = Dream.bar_of(me.profile)
	var by_kind := {}
	for mv in bar:
		if Dream.moves.has(mv):
			var k: String = Dream.moves[mv].kind
			if k == "shift":
				k = "shift_" + String(Dream.moves[mv].where)
			if not by_kind.has(k): by_kind[k] = []
			by_kind[k].append(mv)
	var pick := func(kind: String) -> String:
		var l: Array = by_kind.get(kind, [])
		return "" if l.is_empty() else l[sim.rng.randi() % l.size()]
	var r := sim.rng.randf()
	# What is coming at me?
	for fx in sim.effects:
		if not sim.ents.has(fx.owner) or sim.ents[fx.owner].team == me.team:
			continue
		var threat := false
		match fx.kind:
			"dream_bolt": threat = fx.wait <= 0.0 and fx.pos.distance_to(me.pos) < 12.0 and fx.dir.dot((me.pos - fx.pos).normalized()) > 0.9
			"dream_chain": threat = fx.on == id and fx.left < 0.3
			"dream_pit": threat = fx.pos.distance_to(sim._feet(me)) < fx.rad + 0.5 and fx.wait < 0.35
		if threat:
			var answer := ""
			if (r < 0.45 and fx.kind != "dream_pit") or me.will < 16.0:
				answer = pick.call("deny")
			if answer == "" and r < 0.6:
				answer = pick.call("fade")
			if answer == "" and fx.kind == "dream_bolt" and r > 0.8:
				answer = pick.call("wall")
			var aim: Vector3 = fx.pos
			if answer == "":
				answer = pick.call("shift_side") if r < 0.7 else pick.call("shift_aim")
				var side := Vector3(cos(me.yaw), 0, -sin(me.yaw)) * (6.0 if sim.rng.randf() < 0.5 else -6.0)
				aim = me.pos + side
			if answer != "":
				sim.request_dream(id, answer, aim)
			return
	if me.chained > sim.t:
		var out: String = pick.call("shift_back")
		if out != "" and r < 0.7:
			sim.request_dream(id, out, me.pos)
		return
	# Hurt: mend, or be somewhere else.
	if me.hp < me.max_hp * 0.5 and r < 0.3 and me.will > 40.0:
		var mend: String = pick.call("mend")
		if mend != "":
			sim.request_dream(id, mend, me.pos)
			return
	if me.hp < me.max_hp * 0.4 and best < 4.0 and r < 0.6:
		var away: String = pick.call("shift_back")
		if away != "":
			sim.request_dream(id, away, me.pos)
			return
	if me.will < 50.0:
		return
	var chest: Vector3 = sim._feet(near) + Vector3(0, 1.2, 0)
	var melee: bool = me.profile.get("cls", "channeller") != "channeller"
	var mv := ""
	var aim2: Vector3 = chest
	if r < 0.18 and best > (5.0 if melee else 99.0):
		mv = pick.call("shift_behind")
		if mv == "": mv = pick.call("shift_swap")
		aim2 = near.pos
	elif r < 0.42:
		mv = pick.call("bolt")
		if mv != "":
			aim2 = chest + near.move * near.speed * best / float(Dream.moves[mv].speed)
	elif r < 0.54 and near.get("chained", 0.0) <= sim.t:
		mv = pick.call("chain"); aim2 = near.pos
	elif r < 0.64:
		mv = pick.call("pit")
		aim2 = near.pos + near.move * near.speed * 0.5
	elif r < 0.68 and melee and best > 6.0:
		mv = pick.call("haste")
	elif r < 0.72 and not melee and best < 6.0:
		mv = pick.call("shift_back"); aim2 = me.pos
	if mv != "":
		sim.request_dream(id, mv, aim2)
