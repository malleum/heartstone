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

func add_player(profile: Dictionary, pos := Vector3.ZERO) -> int:
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "player", profile = profile, pos = pos, yaw = PI, hp = 100.0, max_hp = 100.0,
		radius = 0.45, team = id if _spar else 0, alive = true, move = Vector3.ZERO, speed = 5.2,
		endurance = Rules.TUNE.endurance, forming = {}, held = [], barrier = 0.0, severed = 0.0, stagger = 0.0}
	tallies[id] = {casts = {}, kills = {}, draw = 0.0, seconds = 0.0}
	return id

func _add_enemy(type: String, pos: Vector3) -> void:
	var row: Dictionary = Rules.enemies[type]
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "enemy", type = type, row = row, pos = pos, yaw = 0.0, hp = float(row.hp), max_hp = float(row.hp),
		radius = float(row.radius), team = -1, alive = true, atk = 0.0, stagger = 0.0, vel = Vector3.ZERO,
		speed = row.speed * rng.randf_range(0.85, 1.15)}
	events.append({e = "spawn", id = id, type = type, pos = pos})

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
	var why := Rules.cast_block(p.profile, weave, free_slots(p), p.endurance)
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
			_add_enemy(type, Vector3(sin(ang) * d, 0, -cos(ang) * d))
	events.append({e = "wave", left = _waves.size()})

func _step_player(p: Dictionary, dt: float) -> void:
	tallies[p.id].seconds += dt
	p.endurance = minf(p.endurance + Rules.TUNE.endurance_regen * dt, Rules.TUNE.endurance)
	# Forming a weave takes concentration: you move at half speed while doing it.
	var slow := 0.5 if not p.forming.is_empty() else 1.0
	p.pos += p.move * p.speed * slow * dt
	if p.forming.is_empty():
		return
	p.forming.left -= dt
	if p.forming.left > 0.0:
		return
	var weave: String = p.forming.weave
	var aim: Vector3 = p.forming.aim
	p.forming = {}
	var cost := Rules.draw_of(p.profile, weave)
	p.endurance -= cost
	var tl: Dictionary = tallies[p.id]
	tl.draw += cost
	tl.casts[weave] = tl.casts.get(weave, 0) + 1
	_cast(p, weave, aim)

func _cast(p: Dictionary, weave: String, aim: Vector3) -> void:
	var w: Dictionary = Rules.weaves[weave]
	var b: Dictionary = w.base
	var k := Rules.scale(p.profile, weave)
	var from: Vector3 = p.pos
	var to := aim - from; to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector3(sin(p.yaw), 0, cos(p.yaw))
	var at := from + dir * minf(dist, b.get("range", 1e9))
	events.append({e = "cast", id = p.id, weave = weave, kind = w.kind, pos = from, at = at, dir = dir})
	if w.get("hold", false):
		p.held.append(weave)
	match w.kind:
		"projectile":
			var n: int = b.get("count", 1)
			for i in n:
				var a := deg_to_rad(b.get("spread", 0.0)) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "projectile", owner = p.id, weave = weave, pos = from + dir * 0.8, vel = dir.rotated(Vector3.UP, a) * b.speed,
					dmg = b.damage * k, radius = b.radius, left = b.range, id = _fx_id()})
		"cone":
			for e in _targets(p):
				var d: Vector3 = e.pos - from
				if d.length() < b.range and absf(rad_to_deg(dir.signed_angle_to(d.normalized(), Vector3.UP))) < b.arc:
					e.vel = d.normalized() * b.push
					e.stagger = 0.6
					_hurt(e, b.damage * k, p.id, weave)
		"line", "beam":
			for e in _targets(p):
				var d: Vector3 = e.pos - from
				var along := d.dot(dir)
				if along > 0.0 and along < b.range and (d - dir * along).length() < b.width + e.radius:
					e.stagger = maxf(e.stagger, b.get("stagger", 0.0))
					_hurt(e, b.damage * k, p.id, weave)
		"strike":
			_blast(p.id, weave, at, b.radius, b.damage * k)
		"burst":
			for i in int(b.count):
				var off: Vector3 = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * b.scatter
				effects.append({kind = "blast", owner = p.id, weave = weave, pos = at + (off if i > 0 else Vector3.ZERO), dmg = b.damage * k, radius = b.radius,
					left = b.delay * rng.randf_range(0.5, 1.5), id = _fx_id()})
		"ring":
			effects.append({kind = "ring", owner = p.id, weave = weave, pos = from, r = 0.5, max = b.radius, speed = b.speed, dmg = b.damage * k, id = _fx_id()})
		"mover":
			var n: int = b.count
			for i in n:
				var a := deg_to_rad(b.spread) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "mover", owner = p.id, weave = weave, pos = from + dir * 2.5, vel = dir.rotated(Vector3.UP, a) * b.speed,
					dps = b.dps * k, radius = b.radius, left = b.duration, id = _fx_id()})
		"barrier":
			p.barrier = b.absorb * k
		"heal":
			# Canon: you cannot Heal yourself.
			var best: Dictionary = {}
			for id in ents:
				var e: Dictionary = ents[id]
				if e.kind == "player" and e.alive and e.id != p.id and e.team == p.team and e.pos.distance_to(at) < b.range:
					if best.is_empty() or e.hp < best.hp:
						best = e
			if not best.is_empty():
				best.hp = minf(best.hp + b.heal * k, best.max_hp)
				events.append({e = "heal", id = best.id})
		"sever":
			for e in _targets(p):
				if e.kind == "player" and e.pos.distance_to(at) < 3.0:
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

func _blast(owner: int, weave: String, at: Vector3, radius: float, dmg: float) -> void:
	events.append({e = "blast", weave = weave, pos = at, radius = radius})
	for e in _targets(ents[owner]):
		if e.pos.distance_to(at) < radius + e.radius:
			_hurt(e, dmg, owner, weave)

func _hurt(e: Dictionary, dmg: float, by: int, weave: String) -> void:
	if not e.alive:
		return
	if e.get("barrier", 0.0) > 0.0:
		var soak := minf(e.barrier, dmg)
		e.barrier -= soak; dmg -= soak
		if e.barrier <= 0.0:
			release(e.id, "shield_of_air")
	e.hp -= dmg
	events.append({e = "hit", id = e.id, dmg = dmg, by = by})
	if e.hp <= 0.0:
		e.alive = false
		events.append({e = "die", id = e.id, by = by})
		if tallies.has(by) and weave != "":
			var tl: Dictionary = tallies[by]
			tl.kills[weave] = tl.kills.get(weave, 0) + 1

func _step_effects(dt: float) -> void:
	var keep: Array = []
	for fx in effects:
		var alive := true
		var owner: Dictionary = ents[fx.owner]
		match fx.kind:
			"projectile":
				var stepv: Vector3 = fx.vel * dt
				fx.pos += stepv; fx.left -= stepv.length()
				alive = fx.left > 0.0
				for e in _targets(owner):
					if e.pos.distance_to(fx.pos) < fx.radius * 0.5 + e.radius:
						_blast(fx.owner, fx.weave, fx.pos, fx.radius, fx.dmg)
						alive = false
						break
			"blast":
				fx.left -= dt
				if fx.left <= 0.0:
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
						_hurt(e, fx.dps * dt, fx.owner, fx.weave)
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
		e.vel = e.vel.lerp(Vector3.ZERO, minf(4.0 * dt, 1.0))
		var want := Vector3.ZERO
		var target: Dictionary = {}
		var best := 1e9
		for p in players:
			var d: float = p.pos.distance_squared_to(e.pos)
			if d < best:
				best = d; target = p
		if not target.is_empty() and e.speed > 0.0 and e.stagger <= 0.0:
			var to: Vector3 = target.pos - e.pos
			var dist := to.length()
			e.yaw = atan2(to.x, to.z)
			if dist > e.row.reach * 0.8:
				want = to / dist * e.speed
				e.atk = 0.0
			else:
				e.atk += dt
				if e.atk >= e.row.attack_time:
					e.atk = 0.0
					events.append({e = "attack", id = e.id, target = target.id})
					_hurt(target, e.row.damage, e.id, "")
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
		e.pos += (want + e.vel) * dt + push * 0.5

## Compact state for clients: enough to draw the fight, nothing they could cheat with.
func snapshot() -> Dictionary:
	var es := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			es.append([id, e.pos.x, e.pos.z, e.yaw, e.hp])
	var fx := []
	for f in effects:
		fx.append([f.id, f.kind, f.pos.x, f.pos.z, f.get("r", 0.0)])
	return {t = t, ents = es, fx = fx}
