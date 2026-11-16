class_name Dream
extends RefCounted
## Tel'aran'rhiod: what a dreamer can do where imagining a thing makes it so. The
## rows are in data/dream.json; this is what they mean. It works on a Sim's own
## state (players are its Dictionaries), and the Sim calls in at four places: a
## request, each player's step, each dream effect's step, and anything that flies.

static var tune := {}
static var moves := {}

static func load_data() -> void:
	if not moves.is_empty():
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dream.json"))
	tune = d.tune; moves = d.moves

static func _face(e: Dictionary) -> Vector3:
	return Vector3(sin(e.yaw), 0, cos(e.yaw))

## The hostile one nearest to where `p` is looking, within `reach` of `p`.
static func _looked_at(sim: Sim, p: Dictionary, aim: Vector3, reach: float, near := 1e9) -> Dictionary:
	var best := {}; var bd := near
	for e in sim._targets(p):
		var d := Vector2(e.pos.x - aim.x, e.pos.z - aim.z).length()
		if d < bd and e.pos.distance_to(p.pos) <= reach:
			bd = d; best = e
	return best

## Ask for a dream move. Returns "" or why not.
static func request(sim: Sim, id: int, move: String, aim: Vector3) -> String:
	load_data()
	var p: Dictionary = sim.ents.get(id, {})
	if not sim.dream:
		return "only in the World of Dreams"
	if p.is_empty() or not p.alive or not moves.has(move):
		return "busy"
	var m: Dictionary = moves[move]
	var t: float = sim.t
	if p.get("shaken", 0.0) > t:
		return "your will is shaken"
	if p.get("entranced", 0.0) > t or p.down > 0.0:
		return "busy"
	var chained: bool = p.get("chained", 0.0) > t
	if chained and m.kind != "shift" and m.kind != "deny":
		return "chained"
	var cost: float = float(m.cost) * (float(tune.chained_cost) if chained and m.kind == "shift" else 1.0)
	if p.will < cost:
		return "your will is spent"
	match m.kind:
		"shift":
			var to: Vector3 = p.pos
			var yaw: float = p.yaw
			match m.where:
				"behind":
					var e := _looked_at(sim, p, aim, float(m.reach))
					if e.is_empty():
						return "no one there to step behind"
					to = e.pos - _face(e) * (float(m.gap) + e.radius)
					yaw = atan2(e.pos.x - to.x, e.pos.z - to.z)
				"back":
					to = p.pos - _face(p) * float(m.dist)
				"aim":
					var d: Vector3 = (aim - p.pos) * Vector3(1, 0, 1)
					to = p.pos + d.limit_length(float(m.dist))
					if d.length() > 0.5:
						yaw = atan2(d.x, d.z)
			to = Map.clamp_pos(Map.unblock(to, p.radius))
			var from: Vector3 = p.pos
			p.pos = to; p.yaw = yaw
			# Being elsewhere abandons whatever the hands were at, and whatever held you.
			p.swing = {}; p.queued = {}; p.forming = {}; p.dash = {}; p.guard = false; p.drawing = false
			p.chained = 0.0; p.shove = Vector3.ZERO
			p.safe_until = maxf(p.safe_until, t + float(tune.arrive))
			sim.events.append({e = "shift", id = id, from = from, pos = to, yaw = yaw, how = m.where})
		"deny":
			if p.get("deny_free", 0.0) > t:
				return "busy"
			p.deny_until = t + float(m.window); p.deny_free = t + float(m.again)
			sim.events.append({e = "deny", id = id, time = float(m.window)})
		"bolt":
			var dir: Vector3 = aim - (p.pos + Vector3(0, 1.4, 0))
			dir = dir.normalized() if dir.length() > 0.3 else _face(p)
			sim.effects.append({kind = "dream_bolt", owner = id, move = move, pos = sim._feet(p) + Vector3(0, 1.4, 0) + dir * 0.6, dir = dir, wait = float(m.wind), left = float(m.range), weave = move, id = sim._fx_id(), cost = cost})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind)})
		"chain":
			var e := _looked_at(sim, p, aim, float(m.range), float(m.near))
			if e.is_empty():
				return "no one there to hold"
			sim.effects.append({kind = "dream_chain", owner = id, move = move, pos = sim._feet(e), on = e.id, left = float(m.wind), weave = move, id = sim._fx_id(), cost = cost, rad = float(m.slip)})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind), on = e.id})
		"pit":
			var d: Vector3 = (aim - p.pos) * Vector3(1, 0, 1)
			var at: Vector3 = p.pos + d.limit_length(float(m.range))
			at.y = Terrain.height(at.x, at.z)
			sim.effects.append({kind = "dream_pit", owner = id, move = move, pos = at, wait = float(m.wind), left = float(m.secs), rad = float(m.radius), weave = move, id = sim._fx_id(), cost = cost})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind), pos = at, radius = float(m.radius)})
		"wall":
			var f := _face(p)
			var c: Vector3 = p.pos + f * float(m.ahead)
			c.y = Terrain.height(c.x, c.z)
			sim.effects.append({kind = "dream_wall", owner = id, move = move, pos = c, yaw = p.yaw, half = float(m.width) * 0.5, left = float(m.secs), weave = move, id = sim._fx_id(), rad = float(m.width)})
			sim.events.append({e = "dream", id = id, move = move, time = 0.0, pos = c, yaw = p.yaw})
	p.will -= cost
	p.will_t = t
	sim.tallies[id].dreams = sim.tallies[id].get("dreams", 0) + 1
	return ""

## Will comes back when the mind is quiet, faster when the body is too.
static func step_player(sim: Sim, p: Dictionary, dt: float) -> void:
	load_data()
	if sim.t - p.get("will_t", -99.0) > float(tune.rest):
		var k: float = float(tune.still) if p.move.length() < 0.1 else 1.0
		p.will = minf(p.will + float(tune.regen) * k * dt, float(tune.will))

## A dream-thing has reached `e`. True if they Denied it: it is unmade, and the
## will that made it breaks on theirs.
static func _denied(sim: Sim, e: Dictionary, fx: Dictionary) -> bool:
	if e.kind != "player" or e.get("deny_until", 0.0) < sim.t:
		return false
	e.will = minf(e.will + float(tune.regain), float(tune.will))
	e.deny_until = 0.0
	var o: Dictionary = sim.ents.get(fx.owner, {})
	if not o.is_empty() and o.kind == "player":
		o.shaken = sim.t + float(tune.shaken)
		o.will = maxf(o.will - float(tune.rebuke), 0.0)
	sim.events.append({e = "denied", id = e.id, by = fx.owner, move = fx.move, pos = fx.pos})
	return true

## Does a dream wall stand between a and b (on the ground plane)?
static func walled(sim: Sim, a: Vector3, b: Vector3) -> bool:
	for fx in sim.effects:
		if fx.kind != "dream_wall":
			continue
		var side := Vector3(cos(fx.yaw), 0, -sin(fx.yaw))
		var w0: Vector3 = fx.pos - side * fx.half
		var w1: Vector3 = fx.pos + side * fx.half
		if Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(w0.x, w0.z), Vector2(w1.x, w1.z)) != null:
			return true
	return false

## One tick of a dream effect. False when it is over.
static func step_effect(sim: Sim, fx: Dictionary, owner: Dictionary, dt: float) -> bool:
	var m: Dictionary = moves[fx.move]
	match fx.kind:
		"dream_bolt":
			if fx.wait > 0.0:
				fx.wait -= dt
				return owner.alive
			var hops := maxi(int(ceil(float(m.speed) * dt / 0.6)), 1)
			for hop in hops:
				var before: Vector3 = fx.pos
				var stepv: Vector3 = fx.dir * float(m.speed) * dt / hops
				fx.pos += stepv; fx.left -= stepv.length()
				if walled(sim, before, fx.pos) or Map.in_wall(fx.pos) or fx.pos.y <= Terrain.height(fx.pos.x, fx.pos.z):
					sim.events.append({e = "dream_end", move = fx.move, pos = fx.pos})
					return false
				for e in sim._targets(owner):
					var f := sim._feet(e)
					if Vector2(f.x - fx.pos.x, f.z - fx.pos.z).length() < 0.35 + e.radius and fx.pos.y > f.y - 0.3 and fx.pos.y < f.y + 2.4 and e.get("safe_until", 0.0) <= sim.t:
						if not _denied(sim, e, fx):
							sim._hurt(e, float(m.dmg), fx.owner, "dream")
							sim.events.append({e = "dream_hit", move = fx.move, id = e.id, pos = fx.pos})
						return false
			return fx.left > 0.0
		"dream_chain":
			fx.left -= dt
			if fx.left > 0.0:
				return owner.alive
			var e: Dictionary = sim.ents.get(fx.on, {})
			# Gone from the spot, or behind a wall, and there is nothing there to hold.
			if e.is_empty() or not e.alive or sim._feet(e).distance_to(fx.pos) > fx.rad or walled(sim, owner.pos, e.pos):
				sim.events.append({e = "dream_end", move = fx.move, pos = fx.pos})
			elif not _denied(sim, e, fx):
				if e.kind == "player":
					e.chained = sim.t + float(m.secs)
					e.swing = {}; e.queued = {}; e.forming = {}; e.dash = {}
				else:
					e.stagger = maxf(e.stagger, float(m.secs))
				sim.events.append({e = "chained", id = e.id, by = fx.owner, time = float(m.secs)})
			return false
		"dream_pit":
			if fx.wait > 0.0:
				fx.wait -= dt
				if fx.wait <= 0.0:
					for e in sim._targets(owner):
						if sim._feet(e).distance_to(fx.pos) < fx.rad and _denied(sim, e, fx):
							return false
					sim.events.append({e = "pit_open", pos = fx.pos, radius = fx.rad, time = fx.left})
				return owner.alive
			fx.left -= dt
			for e in sim._targets(owner):
				if sim._feet(e).distance_to(fx.pos) < fx.rad + e.radius * 0.5:
					e.mired = sim.t + 0.15
					e.mire = float(m.slow)
					sim._hurt(e, float(m.dps) * dt, fx.owner, "dream", true)
			return fx.left > 0.0
		"dream_wall":
			fx.left -= dt
			return fx.left > 0.0
	return false
