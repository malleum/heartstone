class_name Sim
extends RefCounted
## The authoritative fight, with no nodes and no rendering: players, enemies and live
## weaves on the ground plane. The host steps it; views and clients only mirror it.
## Running without graphics is what lets tests (and the co-op host) play whole
## holdouts headlessly.
##
## Everything is plain Dictionaries so state can be snapshotted over the network.

var t := 0.0
var ents := {}            # id -> entity
var effects: Array = []
var events: Array = []    # drained each tick by whoever is watching
var tallies := {}         # player id -> what Progression.award needs
var activity_id := ""
var over := false
var success := false
var rng := RandomNumberGenerator.new()
var _next := 1
var _waves: Array = []
var _spar := false

func _init(activity: String, seed_ := 1) -> void:
	Rules.load_data()
	activity_id = activity
	rng.seed = seed_
	var act: Dictionary = Rules.activities[activity]
	_waves = act.get("waves", []).duplicate(true)
	_spar = act.kind == "spar"
	Map.use(act.get("map", "open"))

func add_player(profile: Dictionary, pos := Vector3.ZERO) -> int:
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "player", profile = profile, pos = pos, yaw = PI, hp = 100.0, max_hp = 100.0,
		radius = 0.45, team = id if _spar else 0, alive = true, move = Vector3.ZERO, speed = 5.2,
		stamina = Rules.TUNE.stamina, forming = {}, held = [], barrier = 0.0, severed = 0.0, stagger = 0.0,
		cd = {}, burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, vel = Vector3.ZERO,
		# Arms: what is in hand, the blow in progress, and how it is being defended.
		weapon = "", ammo = {}, swing = {}, queued = {}, chain = 0, chain_t = 0.0, shot_free = 0.0,
		guard = false, guard_since = 0.0, duck = false, safe_until = 0.0, dash = {}, reel_until = 0.0}
	var p: Dictionary = ents[id]
	p.speed = Rules.run_speed(profile)
	p.max_hp = Rules.max_hp(profile); p.hp = p.max_hp
	for w in profile.get("kit", []):
		var row: Dictionary = Rules.weapons[w]
		p.ammo[w] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	# A fighter arrives armed; a channeller's hands are free to weave.
	if profile.get("cls", "channeller") != "channeller" and not profile.get("kit", []).is_empty():
		p.weapon = profile.kit[0]
	tallies[id] = {casts = {}, kills = {}, blows = {}, draw = 0.0, effort = 0.0, seconds = 0.0}
	events.append(_intro(ents[id]))
	return id

## What a view needs to draw someone: who they are and how they chose to look.
func _intro(e: Dictionary) -> Dictionary:
	if e.kind == "enemy":
		return {e = "spawn", id = e.id, type = e.type, pos = e.pos}
	var pr: Dictionary = e.profile
	return {e = "player", id = e.id, name = pr.name, look = pr.get("look", ""), power = pr.power, origin = pr.get("origin", ""), cls = pr.get("cls", "channeller"), weapon = e.weapon, pos = e.pos}

## Introductions for everyone alive, for a player who joins part-way through.
func roster() -> Array:
	var out := []
	for id in ents:
		if ents[id].alive:
			out.append(_intro(ents[id]))
	return out

## What a Trolloc carries, by id, so the view can show the same thing in its hand
## (see the variants in game.gd) and its attacks can follow from it.
const ARMS: Array[String] = ["scythe", "axe", "spear", "club"]

func _add_enemy(type: String, pos: Vector3) -> void:
	var row: Dictionary = Rules.enemies[type]
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "enemy", type = type, row = row, pos = pos, yaw = 0.0, hp = float(row.hp), max_hp = float(row.hp),
		radius = float(row.radius), team = -1, alive = true, atk = 0.0, stagger = 0.0, vel = Vector3.ZERO,
		burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, swung = false, blow = {}, aim_yaw = 0.0, arm = ARMS[id % 4],
		speed = row.speed * rng.randf_range(0.85, 1.15)}
	events.append(_intro(ents[id]))

func set_input(id: int, move: Vector3, yaw: float) -> void:
	var p: Dictionary = ents[id]
	p.move = move.limit_length(1.0); p.yaw = yaw

## Flows not taken up by weaves being held. A weave that has been tied off holds
## itself, and costs none.
func free_slots(p: Dictionary) -> int:
	var used := 0
	for h in p.held:
		if h.tied == 0.0:
			used += Rules.slots_of(Rules.weaves[h.weave], p.profile)
	return Rules.flow_capacity(p.profile) - used

## Who a held weave aimed at `aim` would fasten on: the nearest body the weave can
## take (anyone not on your side; only channellers for a shield) within a few paces.
func _aimed(p: Dictionary, w: Dictionary, aim: Vector3) -> int:
	var best := 0; var best_d := 3.0
	for e in _targets(p):
		if w.kind == "sever" and e.kind != "player":
			continue
		if e.get("row", {}).get("speed", 1.0) == 0.0:
			continue
		var d := Vector2(e.pos.x - aim.x, e.pos.z - aim.z).length()
		if d < best_d and e.pos.distance_to(p.pos) < w.base.get("range", 30.0):
			best_d = d; best = e.id
	return best

## Tie off what you hold of this weave: it stays without you for a while, and the
## flows it took are yours again. A technique, learned and not born with.
func tie(id: int, weave: String) -> String:
	var p: Dictionary = ents[id]
	if not Rules.has_technique(p.profile, "tie_off"):
		return "you have not learned to tie off a weave"
	var any := false
	for h in p.held:
		if h.weave == weave and h.tied == 0.0:
			h.tied = t + Rules.tie_time(p.profile, weave)
			any = true
			events.append({e = "tie", id = id, weave = weave, target = h.target})
	return "" if any else "you are not holding that"

## Start forming a weave at an aim point. Returns "" or the reason it was refused.
func request_cast(id: int, weave: String, aim: Vector3) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or not p.forming.is_empty() or not p.swing.is_empty() or not p.dash.is_empty() or p.reel_until > t:
		return "busy"
	if p.severed > t:
		return "shielded from the Source"
	if p.get("bound_by", 0) != 0:
		return "bound in Air"
	var row: Dictionary = Rules.weaves.get(weave, {})
	var target := 0
	if row.get("hold", false):
		# Weaving a held weave again lets it go. One that fastens on someone is let
		# go by weaving it at them again, or at nobody.
		if row.kind in ["bind", "sever"]:
			target = _aimed(p, row, aim)
			for h in p.held:
				if h.weave == weave and h.tied == 0.0 and (h.target == target or target == 0):
					release(id, weave, h.target)
					return ""
			if target == 0:
				return "no one there to hold"
		else:
			for h in p.held:
				if h.weave == weave and h.tied == 0.0:
					release(id, weave)
					return ""
	if p.cd.get(weave, 0.0) > t:
		return "not ready"
	if row.get("kind", "") == "heal" and _heal_target(p, aim, row.base.range).is_empty():
		return "no one there to Heal (you cannot Heal yourself)"
	var why := Rules.cast_block(p.profile, weave, free_slots(p), p.stamina)
	if why != "":
		return why
	p.forming = {weave = weave, left = Rules.form_time(p.profile, weave), aim = aim, target = target}
	events.append({e = "form", id = id, weave = weave, time = p.forming.left})
	return ""

# --- arms: intent ---------------------------------------------------------------------

## Take a weapon from the kit into the hand ("" empties the hands, to weave).
func equip(id: int, weapon: String) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or not p.swing.is_empty():
		return "busy"
	if weapon != "" and not p.profile.get("kit", []).has(weapon):
		return "not carried"
	if p.weapon != weapon:
		p.weapon = weapon; p.guard = false; p.chain = 0
		events.append({e = "equip", id = id, weapon = weapon})
	return ""

## Begin a blow. kind: light | heavy | low | throw. `charge` (0..1) is how far a bow
## was drawn. Returns "" or why not. A blow asked for mid-swing is kept and thrown
## as soon as the hands are free, which is what makes a chain.
func request_attack(id: int, kind: String, aim: Vector3, charge := 1.0) -> String:
	var p: Dictionary = ents[id]
	if not p.alive:
		return "busy"
	if p.weapon == "":
		return "nothing in hand"
	if p.get("bound_by", 0) != 0:
		return "bound in Air"
	if not p.swing.is_empty():
		p.queued = {kind = kind, aim = aim, charge = charge}
		return ""
	if p.reel_until > t or not p.forming.is_empty() or not p.dash.is_empty():
		return "busy"
	var w: Dictionary = Rules.weapons[p.weapon]
	if kind == "light" and p.duck:
		kind = "low"
	var chain: int = p.chain if t < p.chain_t else 0
	var move_id := Rules.move_for(p.weapon, kind, chain)
	if move_id == "":
		return "that cannot be thrown"
	var m: Dictionary = Rules.moves[move_id]
	if kind.begins_with("form:"):
		var why := Rules.form_block(p.profile, move_id, p.weapon)
		if why != "":
			return why
		if p.cd.get(move_id, 0.0) > t:
			return "not ready"
		p.cd[move_id] = t + float(m.get("cooldown", 0.0))
		# Some forms are paid for in blood.
		if m.has("self"):
			_hurt(p, float(m.self), p.id, "", true)
	var times := Rules.move_times(p.profile, p.weapon, move_id)
	var wind: float = times[0]
	if m.get("missile", false):
		if p.ammo.get(p.weapon, 0) <= 0:
			return "none left"
		if w.has("shot"):
			# The draw happens in the hand before the click is released; the sim only
			# makes sure nobody looses faster than the bow can be drawn.
			charge = clampf(charge, 0.35, 1.0)
			wind = maxf(wind, p.shot_free + Rules.draw_time(p.profile, p.weapon) * charge - t)
	var cost := Rules.move_cost(p.profile, p.weapon, move_id, p.stamina)
	p.stamina = maxf(p.stamina - cost, 0.0)
	var to := aim - _feet(p); to.y = 0.0
	var dir := to.normalized() if to.length() > 0.05 else Vector3(sin(p.yaw), 0, cos(p.yaw))
	p.yaw = atan2(dir.x, dir.z)
	p.guard = false
	p.chain = chain + 1 if kind == "light" else 0
	p.swing = {move = move_id, weapon = p.weapon, left = wind, struck = false, recover = times[1], dir = dir, aim = aim, charge = charge}
	if m.has("lunge"):
		p.dash = {vel = dir * (m.lunge / maxf(wind, 0.05)), left = wind, lunge = true}
	var tl: Dictionary = tallies[id]
	tl.blows[p.weapon] = tl.blows.get(p.weapon, 0) + 1
	tl.effort += cost
	events.append({e = "blow", id = id, weapon = p.weapon, move = move_id, wind = wind, recover = times[1], dir = dir, form = kind.begins_with("form:")})
	return ""

func set_guard(id: int, on: bool) -> void:
	var p: Dictionary = ents[id]
	on = on and p.alive and p.swing.is_empty() and Rules.guard_share(p.profile, p.weapon) > 0.0
	if on and not p.guard:
		p.guard_since = t
	p.guard = on

func set_duck(id: int, on: bool) -> void:
	ents[id].duck = on and ents[id].alive

## Sidestep (or roll) along dir: for a moment nothing can touch you.
func request_dodge(id: int, dir: Vector3, rolling := false) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or (not p.dash.is_empty() and not p.dash.has("lunge")) or p.reel_until > t:
		return "busy"
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else -Vector3(sin(p.yaw), 0, cos(p.yaw))
	var d := Rules.dodge(p.profile, rolling)
	if p.stamina < d.cost * 0.5:
		return "too tired"
	p.stamina = maxf(p.stamina - d.cost, 0.0)
	# Leaving is always possible: it abandons a blow or a weave half made.
	p.swing = {}; p.queued = {}; p.forming = {}; p.guard = false
	p.dash = {vel = dir * (d.dist / d.time), left = d.time}
	p.safe_until = t + d.safe
	events.append({e = "dodge", id = id, roll = rolling, dir = dir, time = d.time})
	return ""

## The friend a Healing aimed here would reach: the most hurt within reach of the
## aim point, never the Healer.
func _heal_target(p: Dictionary, aim: Vector3, reach: float) -> Dictionary:
	var best: Dictionary = {}
	for id in ents:
		var e: Dictionary = ents[id]
		if e.kind == "player" and e.alive and e.id != p.id and e.team == p.team and Vector2(e.pos.x - aim.x, e.pos.z - aim.z).length() < reach:
			if best.is_empty() or e.hp / e.max_hp < best.hp / best.max_hp:
				best = e
	return best

## Let go of a held weave (every hold of it, or only the one on `target`), and
## undo what it was doing.
func release(id: int, weave: String, target := -1) -> void:
	var p: Dictionary = ents[id]
	var kind: String = Rules.weaves[weave].kind
	for h in p.held.duplicate():
		if h.weave != weave or (target >= 0 and h.target != target):
			continue
		p.held.erase(h)
		if ents.has(h.target):
			var e: Dictionary = ents[h.target]
			if kind == "bind" and e.get("bound_by", 0) == id:
				e.bound_by = 0
			elif kind == "sever":
				e.severed = 0.0
		events.append({e = "release", id = id, weave = weave, target = h.target})
	if kind == "barrier":
		p.barrier = 0.0
	if kind == "gate":
		for fx in effects:
			if fx.kind == "gate" and fx.owner == id:
				fx.gone = true

## Held weaves cost breath for as long as they are held, come undone when their
## knot runs out, and are lost with the one they were fastened on.
func _step_holds(p: Dictionary, dt: float) -> void:
	for h in p.held.duplicate():
		var gone: bool = h.target != 0 and not (ents.has(h.target) and ents[h.target].alive)
		if h.tied > 0.0:
			if t >= h.tied or gone:
				release(p.id, h.weave, h.target)
			continue
		if gone or (h.breaks > 0.0 and t >= h.breaks):
			if not gone:
				events.append({e = "broke", id = p.id, weave = h.weave, target = h.target})
			release(p.id, h.weave, h.target)
			continue
		var cost: float = Rules.draw_of(p.profile, h.weave, p.stamina) * Rules.TUNE.hold_upkeep * dt
		p.stamina -= cost
		tallies[p.id].draw += cost
		if p.stamina <= 0.0:
			# Nothing left to hold it with.
			p.stamina = 0.0
			release(p.id, h.weave, h.target)


func step(dt: float) -> void:
	if over:
		return
	t += dt
	while not _waves.is_empty() and _waves[0].t <= t:
		_spawn_wave(_waves.pop_front())
	var players: Array = []; var foes: Array = []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			(players if e.kind == "player" else foes).append(e)
	for p in players:
		_step_player(p, dt)
	for e in players + foes:
		e.charge = maxf(e.get("charge", 0.0) - dt, 0.0)
		e.daze = maxf(e.get("daze", 0.0) - dt, 0.0)
		if e.burn > 0.0:
			e.burn -= dt
			_hurt(e, e.burn_dps * dt, e.burn_by, "", true)
		if e.get("fester", 0.0) > 0.0:
			e.fester -= dt
			_hurt(e, e.fester_dps * dt, 0, "", true)
	_path_field(players)
	_step_enemies(foes, players, dt)
	_step_effects(dt)
	# Outcome.
	if _spar:
		if players.size() <= 1 and tallies.size() > 1:
			_finish(true)
	elif players.is_empty():
		_finish(false)
	elif _waves.is_empty() and foes.is_empty() and t > 1.0:
		_finish(true)

func _finish(ok: bool) -> void:
	over = true; success = ok
	events.append({e = "over", success = ok})

func _spawn_wave(w: Dictionary) -> void:
	var training: bool = Rules.activities[activity_id].kind == "training"
	var first := _next
	for type in w.spawn:
		for i in int(w.spawn[type]):
			var ang := rng.randf_range(-0.7, 0.7)
			var d := rng.randf_range(8.0, 13.0) if training else rng.randf_range(38.0, 52.0)
			_add_enemy(type, Vector3(sin(ang) * d, 0, -cos(ang) * d) if Map.m.is_empty() else Map.spawn(rng))
	# Trollocs brought by a Myrddraal are linked to it, and die when it does.
	var lord := 0
	for id in range(first, _next):
		if ents[id].row.get("links", false):
			lord = id
	if lord != 0:
		for id in range(first, _next):
			if id != lord and ents[id].row.get("tier", 1) <= 2:
				ents[id].lord = lord
	events.append({e = "wave", left = _waves.size()})

var _dist := PackedInt32Array()
var _dist_t := -9.0

## How far (in grid steps) every open cell is from the nearest player, going
## round walls: what an enemy with no clear line follows downhill.
func _path_field(players: Array) -> void:
	var g := Map.grid()
	if g.is_empty() or t - _dist_t < 0.4:
		return
	_dist_t = t
	var n: int = g.nx * g.nz
	_dist.resize(n); _dist.fill(1 << 20)
	var queue := PackedInt32Array()
	for p in players:
		var c := _cell(g, p.pos)
		if c >= 0:
			_dist[c] = 0; queue.append(c)
	var head := 0
	var nx: int = g.nx
	var blocked: PackedByteArray = g.blocked
	while head < queue.size():
		var c := queue[head]; head += 1
		var d := _dist[c] + 1
		var cx := c % nx
		for step in [-nx, nx, -1, 1]:
			var o: int = c + step
			if o < 0 or o >= n or (step == -1 and cx == 0) or (step == 1 and cx == nx - 1):
				continue
			if blocked[o] == 0 and _dist[o] > d:
				_dist[o] = d; queue.append(o)

func _cell(g: Dictionary, p: Vector3) -> int:
	var ix := int(floor((p.x - g.x0) / g.cell)); var iz := int(floor((p.z - g.z0) / g.cell))
	return iz * g.nx + ix if ix >= 0 and iz >= 0 and ix < g.nx and iz < g.nz else -1

## Which way an enemy should walk to reach its target: straight at it when
## nothing is in the way, otherwise along the shortest way round.
func _steer(e: Dictionary, target: Dictionary) -> Vector3:
	var to: Vector3 = target.pos - e.pos
	var g := Map.grid()
	if g.is_empty() or _dist.is_empty() or not Map.crosses(e.pos, target.pos, e.radius):
		return to.normalized()
	var c := _cell(g, e.pos)
	if c < 0:
		return to.normalized()
	var best := _dist[c]; var dir := Vector3.ZERO
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var ix: int = c % g.nx + dx; var iz: int = c / g.nx + dz
			if (dx == 0 and dz == 0) or ix < 0 or iz < 0 or ix >= g.nx or iz >= g.nz:
				continue
			var o: int = iz * g.nx + ix
			if g.blocked[o] == 0 and _dist[o] < best:
				best = _dist[o]
				dir = Vector3(g.x0 + (ix + 0.5) * g.cell, 0, g.z0 + (iz + 0.5) * g.cell) - e.pos
	return dir.normalized() if dir != Vector3.ZERO else to.normalized()

func _step_player(p: Dictionary, dt: float) -> void:
	tallies[p.id].seconds += dt
	# The bond: a Warder and a channeller near each other both recover faster.
	var bonded := 1.0
	for id in ents:
		var o: Dictionary = ents[id]
		if o.kind == "player" and o.alive and o.id != p.id and o.team == p.team and o.pos.distance_to(p.pos) < Rules.TUNE.bond_reach \
				and [p.profile.get("cls", "channeller"), o.profile.get("cls", "channeller")] in [["warder", "channeller"], ["channeller", "warder"]]:
			bonded = Rules.TUNE.bond_regen
	p.stamina = minf(p.stamina + Rules.TUNE.stamina_regen * bonded * dt, Rules.TUNE.stamina)
	p.stagger = maxf(p.stagger - dt, 0.0)
	# Left alone for a while, anyone catches their breath: bruises, not wounds.
	if t - p.get("hurt_t", -99.0) > Rules.TUNE.rest_after and p.burn <= 0.0:
		p.hp = minf(p.hp + p.max_hp * Rules.TUNE.rest_regen * dt, p.max_hp)
	# Forming a weave takes concentration: you move at half speed while doing it.
	var slow := 0.5 if not p.forming.is_empty() else 1.0
	if not p.swing.is_empty() and not p.swing.struck: slow = minf(slow, Rules.TUNE.swing_slow)
	if p.guard: slow = minf(slow, Rules.TUNE.guard_slow)
	if p.duck: slow = minf(slow, Rules.TUNE.duck_slow)
	if p.reel_until > t: slow = 0.0
	var step: Vector3 = p.move * p.speed * slow * dt
	if not p.dash.is_empty():
		# A sidestep, a roll or a lunge carries you; your feet are not your own.
		step = p.dash.vel * dt
		if p.dash.has("lunge"):
			# A lunge stops at the body it is aimed at; it does not run through it.
			for e in _targets(p):
				if (p.pos + step).distance_to(e.pos) < p.radius + e.radius + 0.5:
					step = Vector3.ZERO
		p.dash.left -= dt
		if p.dash.left <= 0.0:
			p.dash = {}
	if p.get("bound_by", 0) != 0:
		step = Vector3.ZERO
	p.pos = Map.clamp_pos(Map.unblock(p.pos + step, p.radius))
	_step_holds(p, dt)
	_step_swing(p, dt)
	if p.forming.is_empty():
		return
	p.forming.left -= dt
	if p.forming.left > 0.0:
		return
	var weave: String = p.forming.weave
	var aim: Vector3 = p.forming.aim
	p.fasten = p.forming.get("target", 0)
	p.forming = {}
	var cost := Rules.draw_of(p.profile, weave, p.stamina)
	p.stamina = maxf(p.stamina - cost, 0.0)
	var tl: Dictionary = tallies[p.id]
	tl.draw += cost
	tl.casts[weave] = tl.casts.get(weave, 0) + 1
	p.cd[weave] = t + Rules.cooldown(p.profile, weave)
	_cast(p, weave, aim)

## A blow in progress: wind-up, the instant it lands, recovery, then whatever was
## asked for meanwhile.
func _step_swing(p: Dictionary, dt: float) -> void:
	if p.swing.is_empty():
		return
	p.swing.left -= dt
	if p.swing.left > 0.0:
		return
	if not p.swing.struck:
		p.swing.struck = true
		p.swing.left += p.swing.recover
		_strike(p)
		p.chain_t = t + p.swing.recover + Rules.TUNE.chain_window
		if p.swing.left > 0.0:
			return
	p.swing = {}
	if not p.queued.is_empty():
		var q: Dictionary = p.queued
		p.queued = {}
		request_attack(p.id, q.kind, q.aim, q.charge)

func _strike(p: Dictionary) -> void:
	var sw: Dictionary = p.swing
	var w: Dictionary = Rules.weapons[sw.weapon]
	var m: Dictionary = Rules.moves[sw.move]
	var dmg := Rules.blow(p.profile, sw.weapon, sw.move, p.stamina)
	var dir: Vector3 = sw.dir
	if m.get("missile", false):
		var shot: Dictionary = w.get("shot", w.get("throw", {}))
		p.ammo[sw.weapon] = p.ammo.get(sw.weapon, 0) - 1
		p.shot_free = t
		var hand := _feet(p) + Vector3(0, 1.45, 0)
		var throw: Vector3 = sw.aim - hand
		throw = throw.normalized() if throw.length() > 0.5 else dir
		var pull: float = sw.charge if w.has("shot") else 1.0
		effects.append({kind = "missile", owner = p.id, weapon = sw.weapon, pos = hand + throw * 0.5, vel = throw * shot.speed * lerpf(0.55, 1.0, pull),
			dmg = dmg * lerpf(0.4, 1.0, pull), radius = 0.5, left = shot.range, gravity = shot.gravity, stagger = shot.get("stagger", 0.0), id = _fx_id()})
		events.append({e = "loose", id = p.id, weapon = sw.weapon, left = p.ammo[sw.weapon]})
		return
	var reach: float = w.reach * m.get("reach", 1.0)
	var found := []
	for e in _targets(p):
		var d: Vector3 = e.pos - p.pos
		var dist := d.length()
		if dist < reach + e.radius and (dist < 0.6 or absf(rad_to_deg(dir.signed_angle_to(d / dist, Vector3.UP))) < m.arc):
			found.append(e)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_squared_to(p.pos) < b.pos.distance_squared_to(p.pos))
	var on: Dictionary = m.get("on_hit", {})
	var n := 0
	for e in found:
		if n >= int(m.get("hits", 1)):
			break
		if e.get("safe_until", 0.0) > t:
			continue
		# A blow straight after a parry, or on one who is down, goes in deeper.
		var open := (1.5 if p.get("riposte_until", 0.0) > t else 1.0) * (1.5 if e.get("down", 0.0) > 0.0 else 1.0)
		_wound(e, dmg * pow(0.7, n) * open, p.id, sw.weapon, on, dir)
		n += 1
	if n > 0:
		p.riposte_until = 0.0
	events.append({e = "strike", id = p.id, weapon = sw.weapon, move = sw.move, hits = n, pos = _feet(p) + dir * reach * 0.7 + Vector3(0, 1.1, 0)})

## Steel (or a fist) reaching a body: guard and parry for a player on the
## receiving end, then the hurt and whatever the blow does besides.
func _wound(e: Dictionary, dmg: float, by: int, weapon: String, on: Dictionary, dir: Vector3) -> void:
	if e.kind == "player":
		dmg = _guarded(e, dmg, ents[by], dir)
		if dmg < 0.0:
			return
		dmg *= 1.0 - Rules.cls(e.profile).armour
	if on.has("stagger"):
		e.stagger = maxf(e.stagger, on.stagger)
		if e.kind == "player":
			e.reel_until = maxf(e.reel_until, t + on.stagger * 0.5)
	if on.has("down") and e.kind == "enemy" and not e.row.get("steady", false):
		e.down = maxf(e.down, on.down)
	if on.has("push"):
		e.vel += dir * on.push
	_hurt(e, dmg, by, weapon)

## What is left of a blow after the target's guard. -1: it never landed (parried).
func _guarded(target: Dictionary, dmg: float, attacker: Dictionary, dir: Vector3) -> float:
	if not target.guard:
		return dmg
	# A guard only covers the front.
	var facing := Vector3(sin(target.yaw), 0, cos(target.yaw))
	if facing.dot(-dir) < 0.35:
		return dmg
	if t - target.guard_since <= Rules.TUNE.parry_window:
		attacker.stagger = maxf(attacker.stagger, Rules.TUNE.parry_stagger)
		if attacker.kind == "player":
			attacker.reel_until = t + Rules.TUNE.parry_stagger * 0.6
		target.riposte_until = t + 1.5
		events.append({e = "parry", id = target.id, from = attacker.id})
		return -1.0
	var stopped := dmg * Rules.guard_share(target.profile, target.weapon)
	var cost: float = stopped * Rules.TUNE.guard_cost
	if cost > target.stamina:
		# The guard gives way: only what the breath paid for is stopped.
		stopped *= target.stamina / maxf(cost, 0.01)
		target.stamina = 0.0
		target.guard = false
		target.reel_until = t + 0.8
		events.append({e = "guard_break", id = target.id})
	else:
		target.stamina -= cost
		events.append({e = "block", id = target.id, from = attacker.id})
	return dmg - stopped

func _cast(p: Dictionary, weave: String, aim: Vector3) -> void:
	var w: Dictionary = Rules.weaves[weave]
	var b: Dictionary = w.base
	var k := Rules.scale(p.profile, weave, p.stamina)
	# The fight is decided on the ground plane, but weaves fly in three dimensions:
	# they leave the hand, can be aimed up or down, and land on real ground.
	var from: Vector3 = _feet(p)
	var hand := from + Vector3(0, 1.4, 0)
	var to := aim - from; to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector3(sin(p.yaw), 0, cos(p.yaw))
	var at := from + dir * minf(dist, b.get("range", 1e9))
	at.y = Terrain.height(at.x, at.z)
	var throw := aim - hand
	throw = throw.normalized() if throw.length() > 0.5 else dir
	# Lofted weaves leave the hand tilted up and then fall, so range is a skill.
	throw = (throw + Vector3.UP * tan(deg_to_rad(b.get("loft", 0.0)))).normalized()
	events.append({e = "cast", id = p.id, weave = weave, kind = w.kind, pos = from, at = at, dir = dir})
	if w.get("hold", false):
		# breaks: when the one held can throw it off (0 = never, while it is held).
		p.held.append({weave = weave, target = p.get("fasten", 0) if w.kind in ["bind", "sever"] else 0, tied = 0.0, breaks = 0.0})
		events.append({e = "hold", id = p.id, weave = weave, target = p.held[-1].target})
	match w.kind:
		"bind":
			# Bonds of Air: wrapped and held where they stand. The strong strain
			# against it and in time break free; lesser things stay until let go.
			var e: Dictionary = ents.get(p.fasten, {})
			if e.is_empty() or not e.alive:
				release(p.id, weave, p.fasten)
			else:
				e.bound_by = p.id
				e.vel = Vector3.ZERO
				if e.kind == "player":
					e.forming = {}; e.swing = {}; e.guard = false
				var tier: float = e.get("row", {}).get("tier", 2.0)
				if tier >= 2.0:
					p.held[-1].breaks = t + b.hold * k / (tier - 1.0)
		"projectile":
			var n: int = b.get("count", 1)
			for i in n:
				var a := deg_to_rad(b.get("spread", 0.0)) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "projectile", owner = p.id, weave = weave, pos = hand + throw * 0.6, vel = throw.rotated(Vector3.UP, a) * b.speed,
					dmg = b.damage * k, radius = b.radius, left = b.range, gravity = b.get("gravity", 0.0), id = _fx_id()})
		"cone":
			for e in _targets(p):
				var d: Vector3 = e.pos - p.pos
				if d.length() < b.range and absf(rad_to_deg(dir.signed_angle_to(d.normalized(), Vector3.UP))) < b.arc:
					e.vel = d.normalized() * b.push
					e.stagger = maxf(e.stagger, 0.3 + b.push * 0.04)
					_hurt(e, b.damage * k, p.id, weave)
		"line", "beam":
			for e in _targets(p):
				var d: Vector3 = e.pos - p.pos
				var along := d.dot(dir)
				if along > 0.0 and along < b.range and (d - dir * along).length() < b.width + e.radius:
					e.stagger = maxf(e.stagger, b.get("stagger", 0.0))
					e.vel += dir * b.get("push", 0.0)
					_hurt(e, b.damage * k, p.id, weave)
		"strike":
			_blast(p.id, weave, at, b.radius, b.damage * k)
		"burst":
			for i in int(b.count):
				var off: Vector3 = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * b.scatter
				effects.append({kind = "blast", owner = p.id, weave = weave, pos = at + (off if i > 0 else Vector3.ZERO), dmg = b.damage * k, radius = b.radius,
					left = b.delay * rng.randf_range(0.5, 1.5), id = _fx_id()})
		"ring":
			effects.append({kind = "ring", owner = p.id, weave = weave, pos = p.pos, r = 0.5, max = b.radius, speed = b.speed, dmg = b.damage * k, id = _fx_id()})
		"mover":
			var n: int = b.count
			for i in n:
				var a := deg_to_rad(b.spread) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "mover", owner = p.id, weave = weave, pos = p.pos + dir * 2.5, vel = dir.rotated(Vector3.UP, a) * b.speed,
					dps = b.dps * k, radius = b.radius, left = b.duration, id = _fx_id()})
		"barrier":
			p.barrier = b.absorb * k
		"gate":
			# A gateway: a hole from here to there, open while it is held (or tied).
			# Anyone who steps into one side steps out of the other: friend or not.
			var near_side: Vector3 = Map.clamp_pos(Map.unblock(p.pos + dir * 1.6, 0.6))
			var far_side: Vector3 = Map.clamp_pos(Map.unblock(Vector3(at.x, 0, at.z), 0.6))
			var gid := _fx_id()
			effects.append({kind = "gate", owner = p.id, weave = weave, pos = near_side, to = far_side, id = gid})
			events.append({e = "gate_open", id = gid, a = near_side, b = far_side, by = p.id})
		"heal":
			# Canon: you cannot Heal yourself.
			var best := _heal_target(p, at, b.range)
			if not best.is_empty():
				best.hp = minf(best.hp + b.heal * k, best.max_hp)
				best.fester = 0.0
				events.append({e = "heal", id = best.id})
		"sever":
			# Held between them and the Source for as long as you hold it, or until
			# they force it.
			var e: Dictionary = ents.get(p.fasten, {})
			if e.is_empty() or not e.alive:
				release(p.id, weave, p.fasten)
			else:
				e.severed = 1e9
				e.forming = {}
				for h in e.held.duplicate():
					release(e.id, h.weave, h.target)
				p.held[-1].breaks = t + b.duration * 4.0 * k

var _fx := 0
func _fx_id() -> int:
	_fx += 1
	return _fx

func _targets(p: Dictionary) -> Array:
	var out := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive and e.team != p.team:
			out.append(e)
	return out

## Where an entity stands in the world: the sim plane lifted onto the terrain.
func _feet(e: Dictionary) -> Vector3:
	return Vector3(e.pos.x, Terrain.height(e.pos.x, e.pos.z), e.pos.z)

## Where to aim a weave to hit an entity: its chest, raised to allow for the fall
## of a lofted weave. Bots use it; people learn it.
func aim_at(from: Dictionary, weave: String, target: Dictionary) -> Vector3:
	var b: Dictionary = Rules.weaves[weave].base
	var c := _feet(target) + Vector3(0, 1.1, 0)
	var d := Vector2(c.x - from.pos.x, c.z - from.pos.z).length()
	var secs: float = d / maxf(b.get("speed", 1e6), 1.0)
	c.y += 0.5 * b.get("gravity", 0.0) * secs * secs - d * tan(deg_to_rad(b.get("loft", 0.0)))
	return c

## Where to aim an arrow or a thrown weapon to hit a moving body: ahead of it, and
## above it by the drop over the flight.
func aim_missile(from: Dictionary, weapon: String, target: Dictionary) -> Vector3:
	var w: Dictionary = Rules.weapons[weapon]
	var s: Dictionary = w.get("shot", w.get("throw", {}))
	var c := _feet(target) + Vector3(0, 1.1, 0)
	var secs: float = Vector2(c.x - from.pos.x, c.z - from.pos.z).length() / maxf(s.get("speed", 30.0), 1.0)
	c += target.get("move", Vector3.ZERO) * secs * 0.8
	c.y += 0.5 * s.get("gravity", 0.0) * secs * secs
	return c

func _blast(owner: int, weave: String, at: Vector3, radius: float, dmg: float) -> void:
	events.append({e = "blast", weave = weave, pos = at, radius = radius})
	for e in _targets(ents[owner]):
		if (_feet(e) + Vector3(0, 1.0, 0)).distance_to(at) < radius + e.radius + 0.5 and e.get("safe_until", 0.0) <= t:
			_hurt(e, dmg, owner, weave)
	# Fire does not know who wove it: stand too close to your own and you burn.
	var me: Dictionary = ents[owner]
	var own: float = Rules.weaves[weave].get("self", 0.0)
	if own > 0.0 and me.alive and (_feet(me) + Vector3(0, 1.0, 0)).distance_to(at) < radius + me.radius:
		_hurt(me, dmg * own, owner, "")
		me.burn = maxf(me.burn, 2.0); me.burn_dps = 3.0; me.burn_by = owner

## quiet: damage over time, which should not flinch, re-ignite or flash every tick.
func _hurt(e: Dictionary, dmg: float, by: int, weave: String, quiet := false) -> void:
	if not e.alive:
		return
	# A Myrddraal is not where the blow lands, half the time, unless something
	# has hold of it.
	# Spirit is not a thing to step aside from: it is woven at what the creature is.
	var of_spirit: bool = Rules.weaves.has(weave) and Rules.weaves[weave].flows.keys() == ["spirit"]
	if not quiet and not of_spirit and e.kind == "enemy" and e.row.has("evades") and e.stagger <= 0.0 and e.get("bound_by", 0) == 0 and rng.randf() < float(e.row.evades):
		events.append({e = "slip", id = e.id})
		return
	if not quiet and Rules.weaves.has(weave):
		var on: Dictionary = Rules.weaves[weave].get("on_hit", {})
		if on.has("burn"):
			e.burn = maxf(e.burn, on.burn); e.burn_dps = on.get("burn_dps", 6.0); e.burn_by = by
		if on.has("stun"):
			e.stagger = maxf(e.stagger, on.stun)
		# Lightning leaves what survives it charged: it runs wild and faster, and the
		# next thing to strike it sends the charge leaping to those nearby.
		if on.has("charge"):
			e.charge = maxf(e.get("charge", 0.0), on.charge); e.charge_dmg = dmg * 0.4; e.charge_new = true
		# Spirit leaves them with no purpose for a moment: no attack, no pursuit.
		if on.has("daze"):
			e.daze = maxf(e.get("daze", 0.0), on.daze)
			if e.kind == "enemy":
				e.atk = 0.0; e.swung = false; e.blow = {}
			else:
				e.forming = {}
		if on.has("down") and e.kind == "enemy" and not e.row.get("steady", false):
			e.down = maxf(e.down, on.down)
	if e.get("barrier", 0.0) > 0.0:
		var soak := minf(e.barrier, dmg)
		e.barrier -= soak; dmg -= soak
		if e.barrier <= 0.0:
			release(e.id, "dome_of_air")
	e.hp -= dmg
	if dmg > 0.0:
		e.hurt_t = t
	if not quiet and dmg > 0.0 and e.get("charge", 0.0) > 0.0 and not e.get("charge_new", false):
		# The charge leaves it for the two nearest of its own kind.
		e.charge = 0.0
		var near := []
		for id in ents:
			var o: Dictionary = ents[id]
			if o.alive and o.id != e.id and o.team == e.team and o.pos.distance_to(e.pos) < 5.0:
				near.append(o)
		near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_squared_to(e.pos) < b.pos.distance_squared_to(e.pos))
		for o in near.slice(0, 2):
			events.append({e = "arc", from = _feet(e) + Vector3(0, 1.2, 0), to = _feet(o) + Vector3(0, 1.2, 0)})
			o.stagger = maxf(o.stagger, 0.5)
			_hurt(o, e.get("charge_dmg", 10.0), by, weave, true)
	e.charge_new = false
	if not quiet:
		events.append({e = "hit", id = e.id, dmg = dmg, by = by})
	if e.hp <= 0.0:
		e.alive = false
		# The dead hold nothing.
		for h in e.get("held", []).duplicate():
			release(e.id, h.weave, h.target)
		# Trollocs linked to a Myrddraal die with it.
		if e.kind == "enemy" and e.row.get("links", false):
			for id in ents:
				var o: Dictionary = ents[id]
				if o.alive and o.get("lord", 0) == e.id:
					o.alive = false
					events.append({e = "die", id = o.id, by = by, linked = true})
		events.append({e = "die", id = e.id, by = by})
		if tallies.has(by) and weave != "":
			var tl: Dictionary = tallies[by]
			tl.kills[weave] = tl.kills.get(weave, 0) + 1

## Advance a projectile one hop; true if it struck an enemy, a tree or the ground.
func _fly(fx: Dictionary, owner: Dictionary, dt: float) -> bool:
	fx.vel.y -= fx.gravity * dt
	var stepv: Vector3 = fx.vel * dt
	fx.pos += stepv; fx.left -= stepv.length()
	for e in _targets(owner):
		var f := _feet(e)
		if Vector2(f.x - fx.pos.x, f.z - fx.pos.z).length() < fx.radius * 0.5 + e.radius and fx.pos.y > f.y - 0.3 and fx.pos.y < f.y + (1.3 if e.get("duck", false) else 2.4) and e.get("safe_until", 0.0) <= t:
			fx.struck = e.id
			return true
	for tr in Map.trees():
		if Vector2(tr.x - fx.pos.x, tr.z - fx.pos.z).length() < tr.r + 0.25 and fx.pos.y < Terrain.height(tr.x, tr.z) + tr.h:
			return true
	# A wall stops what flies below its top: cover from arrows, and from fire.
	if Map.in_wall(fx.pos):
		return true
	var gy := Terrain.height(fx.pos.x, fx.pos.z)
	if fx.pos.y <= gy:
		fx.pos.y = gy
		return true
	return false

func _step_effects(dt: float) -> void:
	var keep: Array = []
	for fx in effects:
		var alive := true
		var owner: Dictionary = ents[fx.owner]
		match fx.kind:
			"projectile":
				# Fast weaves are stepped in short hops so they cannot pass through a target.
				var hops := maxi(int(ceil(fx.vel.length() * dt / 0.6)), 1)
				var hit := false
				for hop in hops:
					if hit or not alive:
						break
					hit = _fly(fx, owner, dt / hops)
					alive = fx.left > 0.0
				if hit or not alive:
					_blast(fx.owner, fx.weave, fx.pos, fx.radius, fx.dmg)
					alive = false
			"missile":
				# An arrow, a knife, a javelin: it wounds the one body it meets.
				var hops := maxi(int(ceil(fx.vel.length() * dt / 0.6)), 1)
				var hit := false
				for hop in hops:
					if hit or not alive:
						break
					hit = _fly(fx, owner, dt / hops)
					alive = fx.left > 0.0
				if hit:
					alive = false
					if fx.has("struck"):
						var flat: Vector3 = fx.vel * Vector3(1, 0, 1)
						_wound(ents[fx.struck], fx.dmg, fx.owner, fx.weapon, {stagger = fx.stagger} if fx.stagger > 0.0 else {}, flat.normalized())
					events.append({e = "stick", pos = fx.pos, weapon = fx.weapon, into = fx.get("struck", 0)})
					# It lies where it fell, to be gathered up: thrown weapons always, an
					# arrow if it did not break.
					if Rules.weapons.has(fx.weapon) and (Rules.weapons[fx.weapon].has("throw") or rng.randf() < 0.6):
						var at: Vector3 = fx.pos
						at.y = Terrain.height(at.x, at.z)
						keep.append({kind = "drop", owner = fx.owner, weapon = fx.weapon, pos = at, left = 90.0, id = _fx_id()})
			"gate":
				alive = not fx.get("gone", false) and owner.alive
				for id in ents:
					var e: Dictionary = ents[id]
					if not alive or not e.alive or e.get("gated", 0.0) > t or e.get("row", {}).get("speed", 1.0) == 0.0:
						continue
					for side in [[fx.pos, fx.to], [fx.to, fx.pos]]:
						if e.pos.distance_to(side[0]) < 1.1:
							# Out the far side, a step clear of it, the way you were going.
							var onward := Vector3(sin(e.yaw), 0, cos(e.yaw)) * 1.3
							e.pos = Map.clamp_pos(Map.unblock(side[1] + onward, e.radius))
							e.gated = t + 2.0
							events.append({e = "gate_pass", id = e.id, pos = e.pos})
							break
			"drop":
				fx.left -= dt
				alive = fx.left > 0.0
				for id in ents:
					var e: Dictionary = ents[id]
					if alive and e.alive and e.kind == "player" and e.ammo.has(fx.weapon) and Vector2(e.pos.x - fx.pos.x, e.pos.z - fx.pos.z).length() < 1.3:
						var row: Dictionary = Rules.weapons[fx.weapon]
						if e.ammo[fx.weapon] < int(row.get("shot", row.get("throw", {})).get("ammo", 0)):
							e.ammo[fx.weapon] += 1
							events.append({e = "pickup", id = e.id, weapon = fx.weapon, left = e.ammo[fx.weapon]})
							alive = false
			"blast":
				fx.left -= dt
				if fx.left <= 0.0:
					fx.pos.y = Terrain.height(fx.pos.x, fx.pos.z)
					_blast(fx.owner, fx.weave, fx.pos, fx.radius, fx.dmg)
					alive = false
			"ring":
				var r0: float = fx.r
				fx.r += fx.speed * dt
				for e in _targets(owner):
					var d: float = e.pos.distance_to(fx.pos)
					if d > r0 - e.radius and d <= fx.r:
						e.stagger = maxf(e.stagger, 0.8)
						_hurt(e, fx.dmg, fx.owner, fx.weave)
				alive = fx.r < fx.max
			"mover":
				fx.pos += fx.vel * dt; fx.left -= dt
				for e in _targets(owner):
					if e.pos.distance_to(fx.pos) < fx.radius + e.radius:
						_hurt(e, fx.dps * dt, fx.owner, fx.weave, true)
				alive = fx.left > 0.0
		if alive:
			keep.append(fx)
		else:
			events.append({e = "fx_end", id = fx.id})
	effects = keep

func _step_enemies(foes: Array, players: Array, dt: float) -> void:
	# Coarse grid so crowd separation stays cheap with hundreds of Trollocs.
	var grid := {}
	for e in foes:
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(e)
	# A crowd cannot all swing at once without hitting each other: only a few
	# press an attack on one person at a time, and the rest hang at arm's length.
	var pressing := {}
	for e in foes:
		if not e.blow.is_empty() and e.get("victim", 0) != 0:
			pressing[e.victim] = pressing.get(e.victim, 0) + 1
	for e in foes:
		e.stagger = maxf(e.stagger - dt, 0.0)
		e.down = maxf(e.down - dt, 0.0)
		e.vel = e.vel.lerp(Vector3.ZERO, minf(4.0 * dt, 1.0))
		var want := Vector3.ZERO
		var target: Dictionary = {}
		var best := 1e9
		for p in players:
			var d: float = p.pos.distance_squared_to(e.pos)
			if d < best:
				best = d; target = p
		if e.get("bound_by", 0) != 0:
			e.vel = Vector3.ZERO
		var free: bool = not target.is_empty() and e.speed > 0.0 and e.stagger <= 0.0 and e.down <= 0.0 and e.get("bound_by", 0) == 0
		if free and e.get("daze", 0.0) > 0.0:
			# Dazed by Spirit: it drifts, and does nothing it meant to.
			free = false
			want = Vector3(sin(e.id * 2.4 + t * 0.7), 0, cos(e.id * 2.4 + t * 0.7)) * e.speed * 0.25
			e.yaw = atan2(want.x, want.z)
		var shot: Dictionary = e.row.get("ranged", {})
		var far: float = target.pos.distance_to(e.pos) if not target.is_empty() else 0.0
		if free and not shot.is_empty() and not e.swung and far > shot.keep * 0.45:
			# An archer: close to bowshot, stand, draw, loose. Pressed close, it
			# falls back on its blade like any other.
			e.yaw = atan2(target.pos.x - e.pos.x, target.pos.z - e.pos.z)
			e.blow = {}
			if far > shot.range or Map.crosses(e.pos, target.pos, 0.0) and far > shot.keep:
				want = _steer(e, target) * e.speed
				e.atk = 0.0
			else:
				e.atk += dt
				if e.atk >= shot.time:
					e.atk = 0.0
					var from: Vector3 = _feet(e) + Vector3(0, 1.9, 0)
					var at: Vector3 = _feet(target) + Vector3(0, 0.65 if target.duck else 1.1, 0)
					var secs: float = Vector2(at.x - from.x, at.z - from.z).length() / shot.speed
					at += target.move * target.speed * secs * 0.7
					at.y += 0.5 * shot.gravity * secs * secs
					# Not every arrow is true.
					at += Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * far * 0.035
					effects.append({kind = "missile", owner = e.id, weapon = "trolloc_arrow", pos = from, vel = (at - from).normalized() * shot.speed,
						dmg = float(shot.dmg), radius = 0.5, left = shot.range * 1.5, gravity = shot.gravity, stagger = 0.0, id = _fx_id()})
					events.append({e = "loose", id = e.id, weapon = "trolloc_arrow", left = 0})
		elif free:
			var to: Vector3 = target.pos - e.pos
			var dist := to.length()
			if e.swung:
				# Committed: it no longer turns, and it carries forward into the blow.
				# Step out of its line and it misses.
				e.atk += dt
				want = Vector3(sin(e.aim_yaw), 0, cos(e.aim_yaw)) * e.speed * 0.6
				if e.atk >= e.blow.time:
					_enemy_blow(e, players)
					e.atk = 0.0; e.swung = false; e.blow = {}
			else:
				e.yaw = atan2(to.x, to.z)
				if dist > e.row.reach * 0.8:
					want = _steer(e, target) * e.speed
					e.atk = 0.0; e.blow = {}
				else:
					if e.blow.is_empty():
						if pressing.get(target.id, 0) >= int(Rules.TUNE.gang):
							e.move = want
							e.pos = Map.clamp_pos(Map.unblock(e.pos + e.vel * dt, e.radius))
							continue
						e.blow = _pick_blow(e)
						e.victim = target.id
						pressing[target.id] = pressing.get(target.id, 0) + 1
					e.atk += dt
					# The swing starts before the blow lands, so it can be seen coming.
					if e.atk >= e.blow.time - 0.4:
						e.swung = true; e.aim_yaw = e.yaw
						events.append({e = "swing", id = e.id, target = target.id, kind = e.blow.kind})
		else:
			e.atk = 0.0; e.swung = false; e.blow = {}
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		var push := Vector3.ZERO
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for o in grid.get(key + Vector2i(dx, dz), []):
					if o.id != e.id:
						var d: Vector3 = e.pos - o.pos
						var len := d.length()
						var min_d: float = e.radius + o.radius
						if len < min_d and len > 0.001:
							push += d / len * (min_d - len)
		# Charged by lightning, it runs half again as fast.
		if e.get("charge", 0.0) > 0.0:
			want *= 1.5
		e.move = want
		e.pos = Map.clamp_pos(Map.unblock(e.pos + (want + e.vel) * dt + push * 0.5, e.radius))

## Which of its attacks an enemy tries next: a chop, a sweep, a thrust. Each has
## its own arc, reach, height and time, so each asks for a different answer.
func _pick_blow(e: Dictionary) -> Dictionary:
	var all: Array = e.row.get("attacks", [{kind = "chop", height = "over", arc = 30.0}])
	# What it can do depends on what it holds: a spear thrusts, a club comes down.
	var list := all.filter(func(x: Dictionary) -> bool: return not x.has("arms") or e.arm in x.arms)
	if list.is_empty():
		list = all
	var a: Dictionary = list[rng.randi() % list.size()]
	return {kind = a.kind, height = a.get("height", "mid"), arc = float(a.get("arc", 30.0)), reach = e.row.reach * a.get("reach", 1.0),
		time = e.row.attack_time * a.get("time", 1.0), dmg = e.row.damage * a.get("dmg", 1.0)}

## The blow lands along the line it was committed to, on whoever is still there.
func _enemy_blow(e: Dictionary, players: Array) -> void:
	var dir := Vector3(sin(e.aim_yaw), 0, cos(e.aim_yaw))
	var b: Dictionary = e.blow
	var target: Dictionary = {}
	for p in players:
		var d: Vector3 = p.pos - e.pos
		var dist := d.length()
		if p.alive and dist < b.reach * 1.1 + p.radius and (dist < 0.8 or absf(rad_to_deg(dir.signed_angle_to(d / dist, Vector3.UP))) < b.arc):
			if target.is_empty() or dist < target.pos.distance_to(e.pos):
				target = p
	if target.is_empty():
		# It cut air, and is open for a moment.
		e.stagger = maxf(e.stagger, 0.45)
		events.append({e = "miss", id = e.id})
		return
	# A Warder with guard raised beside a channeller takes the blow meant for them.
	if target.profile.get("cls", "channeller") == "channeller":
		for p in players:
			if p.id != target.id and p.alive and p.team == target.team and p.guard and p.profile.get("cls", "") == "warder" and p.pos.distance_to(target.pos) < Rules.TUNE.ward_reach:
				events.append({e = "ward", id = p.id, saved = target.id})
				target = p
				# However it came, the Warder's steel is in its way.
				dir = -Vector3(sin(p.yaw), 0, cos(p.yaw))
				break
	if target.safe_until > t or (b.height == "high" and target.duck):
		e.stagger = maxf(e.stagger, 0.3)
		events.append({e = "evade", id = target.id, from = e.id, duck = target.safe_until <= t})
		return
	events.append({e = "attack", id = e.id, target = target.id, kind = b.kind})
	var hp0: float = target.hp
	_wound(target, b.dmg, e.id, "", {}, dir)
	# A Myrddraal's black blade: the wound festers until it is Healed or runs its course.
	if target.hp < hp0 and e.row.has("fester"):
		target.fester = float(e.row.fester.secs); target.fester_dps = float(e.row.fester.dps)
		events.append({e = "fester", id = target.id})
	# A burning Trolloc sets alight what it reaches.
	if e.burn > 0.0 and target.hp < hp0:
		target.burn = maxf(target.burn, 2.0); target.burn_dps = 3.0; target.burn_by = e.id

## Compact state for clients: enough to draw the fight, nothing they could cheat with.
func snapshot() -> Dictionary:
	var es := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			# Status bits: 1 burning, 2 knocked down, 4 stunned, 8 thrown.
			# Then for those who bear arms: 16 guarding, 32 ducking, 64 sidestepping or rolling.
			var st := (1 if e.burn > 0.0 else 0) | (2 if e.down > 0.0 else 0) | (4 if e.stagger > 0.0 else 0) | (8 if e.vel.length() > 2.0 else 0) \
				| (16 if e.get("guard", false) else 0) | (32 if e.get("duck", false) else 0) | (64 if e.get("safe_until", 0.0) > t else 0) \
				| (128 if e.get("bound_by", 0) != 0 else 0) | (256 if e.get("fester", 0.0) > 0.0 else 0) \
				| (512 if e.get("charge", 0.0) > 0.0 else 0) | (1024 if e.get("daze", 0.0) > 0.0 else 0)
			es.append([id, e.pos.x, e.pos.z, e.yaw, e.hp, e.get("stamina", 0.0), st])
	var fx := []
	for f in effects:
		fx.append([f.id, f.kind, f.pos.x, f.pos.z, f.get("r", 0.0), f.pos.y, f.get("weave", f.get("weapon", ""))])
	return {t = t, ents = es, fx = fx}
