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
		cd = {}, burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, vel = Vector3.ZERO}
	tallies[id] = {casts = {}, kills = {}, draw = 0.0, seconds = 0.0}
	events.append(_intro(ents[id]))
	return id

## What a view needs to draw someone: who they are and how they chose to look.
func _intro(e: Dictionary) -> Dictionary:
	if e.kind == "enemy":
		return {e = "spawn", id = e.id, type = e.type, pos = e.pos}
	var pr: Dictionary = e.profile
	return {e = "player", id = e.id, name = pr.name, look = pr.get("look", ""), power = pr.power, origin = pr.get("origin", ""), pos = e.pos}

## Introductions for everyone alive, for a player who joins part-way through.
func roster() -> Array:
	var out := []
	for id in ents:
		if ents[id].alive:
			out.append(_intro(ents[id]))
	return out

func _add_enemy(type: String, pos: Vector3) -> void:
	var row: Dictionary = Rules.enemies[type]
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "enemy", type = type, row = row, pos = pos, yaw = 0.0, hp = float(row.hp), max_hp = float(row.hp),
		radius = float(row.radius), team = -1, alive = true, atk = 0.0, stagger = 0.0, vel = Vector3.ZERO,
		burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, swung = false,
		speed = row.speed * rng.randf_range(0.85, 1.15)}
	events.append(_intro(ents[id]))

func set_input(id: int, move: Vector3, yaw: float) -> void:
	var p: Dictionary = ents[id]
	p.move = move.limit_length(1.0); p.yaw = yaw

func free_slots(p: Dictionary) -> int:
	var used := 0
	for w in p.held:
		used += Rules.slots_of(Rules.weaves[w], p.profile)
	return Rules.flow_capacity(p.profile) - used

## Start forming a weave at an aim point. Returns "" or the reason it was refused.
func request_cast(id: int, weave: String, aim: Vector3) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or not p.forming.is_empty():
		return "busy"
	if p.severed > t:
		return "shielded from the Source"
	if p.held.has(weave):
		release(id, weave)
		return ""
	if p.cd.get(weave, 0.0) > t:
		return "not ready"
	var why := Rules.cast_block(p.profile, weave, free_slots(p), p.stamina)
	if why != "":
		return why
	p.forming = {weave = weave, left = Rules.form_time(p.profile, weave), aim = aim}
	events.append({e = "form", id = id, weave = weave, time = p.forming.left})
	return ""

func release(id: int, weave: String) -> void:
	var p: Dictionary = ents[id]
	p.held.erase(weave)
	if Rules.weaves[weave].kind == "barrier":
		p.barrier = 0.0
	events.append({e = "release", id = id, weave = weave})


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
		if e.burn > 0.0:
			e.burn -= dt
			_hurt(e, e.burn_dps * dt, e.burn_by, "", true)
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
	for type in w.spawn:
		for i in int(w.spawn[type]):
			var ang := rng.randf_range(-0.7, 0.7)
			var d := rng.randf_range(8.0, 13.0) if training else rng.randf_range(38.0, 52.0)
			_add_enemy(type, Vector3(sin(ang) * d, 0, -cos(ang) * d) if Map.m.is_empty() else Map.spawn(rng))
	events.append({e = "wave", left = _waves.size()})

func _step_player(p: Dictionary, dt: float) -> void:
	tallies[p.id].seconds += dt
	p.stamina = minf(p.stamina + Rules.TUNE.stamina_regen * dt, Rules.TUNE.stamina)
	# Forming a weave takes concentration: you move at half speed while doing it.
	var slow := 0.5 if not p.forming.is_empty() else 1.0
	p.pos = Map.clamp_pos(Map.unblock(p.pos + p.move * p.speed * slow * dt, p.radius))
	if p.forming.is_empty():
		return
	p.forming.left -= dt
	if p.forming.left > 0.0:
		return
	var weave: String = p.forming.weave
	var aim: Vector3 = p.forming.aim
	p.forming = {}
	var cost := Rules.draw_of(p.profile, weave, p.stamina)
	p.stamina = maxf(p.stamina - cost, 0.0)
	var tl: Dictionary = tallies[p.id]
	tl.draw += cost
	tl.casts[weave] = tl.casts.get(weave, 0) + 1
	p.cd[weave] = t + Rules.cooldown(p.profile, weave)
	_cast(p, weave, aim)

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
		p.held.append(weave)
	match w.kind:
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
		"heal":
			# Canon: you cannot Heal yourself.
			var best: Dictionary = {}
			for id in ents:
				var e: Dictionary = ents[id]
				if e.kind == "player" and e.alive and e.id != p.id and e.team == p.team and e.pos.distance_to(Vector3(at.x, 0, at.z)) < b.range:
					if best.is_empty() or e.hp < best.hp:
						best = e
			if not best.is_empty():
				best.hp = minf(best.hp + b.heal * k, best.max_hp)
				events.append({e = "heal", id = best.id})
		"sever":
			for e in _targets(p):
				if e.kind == "player" and e.pos.distance_to(Vector3(at.x, 0, at.z)) < 3.0:
					e.severed = t + b.duration
					e.forming = {}

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

func _blast(owner: int, weave: String, at: Vector3, radius: float, dmg: float) -> void:
	events.append({e = "blast", weave = weave, pos = at, radius = radius})
	for e in _targets(ents[owner]):
		if (_feet(e) + Vector3(0, 1.0, 0)).distance_to(at) < radius + e.radius + 0.5:
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
	if not quiet and weave != "":
		var on: Dictionary = Rules.weaves[weave].get("on_hit", {})
		if on.has("burn"):
			e.burn = maxf(e.burn, on.burn); e.burn_dps = on.get("burn_dps", 6.0); e.burn_by = by
		if on.has("stun"):
			e.stagger = maxf(e.stagger, on.stun)
		if on.has("down") and e.kind == "enemy":
			e.down = maxf(e.down, on.down)
	if e.get("barrier", 0.0) > 0.0:
		var soak := minf(e.barrier, dmg)
		e.barrier -= soak; dmg -= soak
		if e.barrier <= 0.0:
			release(e.id, "dome_of_air")
	e.hp -= dmg
	if not quiet:
		events.append({e = "hit", id = e.id, dmg = dmg, by = by})
	if e.hp <= 0.0:
		e.alive = false
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
		if Vector2(f.x - fx.pos.x, f.z - fx.pos.z).length() < fx.radius * 0.5 + e.radius and fx.pos.y > f.y - 0.3 and fx.pos.y < f.y + 2.4:
			return true
	for tr in Map.trees():
		if Vector2(tr.x - fx.pos.x, tr.z - fx.pos.z).length() < tr.r + 0.25 and fx.pos.y < Terrain.height(tr.x, tr.z) + tr.h:
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
		if not target.is_empty() and e.speed > 0.0 and e.stagger <= 0.0 and e.down <= 0.0:
			var to: Vector3 = target.pos - e.pos
			var dist := to.length()
			e.yaw = atan2(to.x, to.z)
			if dist > e.row.reach * 0.8:
				want = to / dist * e.speed
				e.atk = 0.0; e.swung = false
			else:
				e.atk += dt
				# The swing starts before the blow lands, so it can be seen coming.
				if not e.swung and e.atk >= e.row.attack_time - 0.4:
					e.swung = true
					events.append({e = "swing", id = e.id, target = target.id})
				if e.atk >= e.row.attack_time:
					e.atk = 0.0; e.swung = false
					events.append({e = "attack", id = e.id, target = target.id})
					_hurt(target, e.row.damage, e.id, "")
					# A burning Trolloc sets alight what it grapples.
					if e.burn > 0.0:
						target.burn = maxf(target.burn, 2.0); target.burn_dps = 3.0; target.burn_by = e.id
		else:
			e.atk = 0.0; e.swung = false
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
		e.move = want
		e.pos = Map.clamp_pos(Map.unblock(e.pos + (want + e.vel) * dt + push * 0.5, e.radius))

## Compact state for clients: enough to draw the fight, nothing they could cheat with.
func snapshot() -> Dictionary:
	var es := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			# Status bits: 1 burning, 2 knocked down, 4 stunned, 8 thrown.
			var st := (1 if e.burn > 0.0 else 0) | (2 if e.down > 0.0 else 0) | (4 if e.stagger > 0.0 else 0) | (8 if e.vel.length() > 2.0 else 0)
			es.append([id, e.pos.x, e.pos.z, e.yaw, e.hp, e.get("stamina", 0.0), st])
	var fx := []
	for f in effects:
		fx.append([f.id, f.kind, f.pos.x, f.pos.z, f.get("r", 0.0), f.pos.y, f.get("weave", "")])
	return {t = t, ents = es, fx = fx}
