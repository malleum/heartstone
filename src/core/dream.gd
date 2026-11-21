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

## The eight on a character's dream bar: their own choice if it is whole, else the default.
static func bar_of(p: Dictionary) -> Array:
	load_data()
	var b: Array = p.get("dream_bar", [])
	if b.size() == tune.bar.size() and b.all(func(m: Variant) -> bool: return m is String and moves.has(m)):
		return b.duplicate()
	return (tune.bar as Array).duplicate()

## The keys of the dream bar's slots (QWERTY positions, as text).
static func keys_of(p: Dictionary) -> Array:
	load_data()
	var k: Variant = p.get("dream_slot_keys", [])
	if k is Array and (k as Array).size() == tune.bar_keys.size():
		return (k as Array).duplicate()
	return (tune.bar_keys as Array).duplicate()

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
	if p.get("caged", 0.0) > t and m.kind == "shift":
		return "caged"
	if p.get("faded", 0.0) > t and not m.kind in ["shift", "deny", "fade"]:
		return "not quite here"
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
				"side":
					# Toward whichever side of your facing you are looking.
					var right := Vector3(-cos(p.yaw), 0, sin(p.yaw))
					var s := signf(((aim - p.pos) * Vector3(1, 0, 1)).dot(right))
					to = p.pos + right * (s if s != 0.0 else 1.0) * float(m.dist)
				"swap":
					var e := _looked_at(sim, p, aim, float(m.reach))
					if e.is_empty():
						return "no one there to change places with"
					to = e.pos
					var was: Vector3 = p.pos
					e.pos = Map.clamp_pos(Map.unblock(was, e.radius))
					e.forming = {}; e.swing = {}; e.queued = {}
					sim.events.append({e = "shift", id = e.id, from = to, pos = e.pos, yaw = e.yaw, how = "swapped"})
					yaw = atan2(e.pos.x - to.x, e.pos.z - to.z)
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
			# Several at once are fanned across the aim.
			var n: int = int(m.get("count", 1))
			for i in n:
				var a: float = deg_to_rad(float(m.get("spread", 0.0))) * ((i + 0.5) / n - 0.5) if n > 1 else 0.0
				var di: Vector3 = dir.rotated(Vector3.UP, a)
				sim.effects.append({kind = "dream_bolt", owner = id, move = move, pos = sim._feet(p) + Vector3(0, 1.4, 0) + di * 0.6, dir = di, wait = float(m.wind), left = float(m.range), weave = move, id = sim._fx_id(), cost = cost})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind)})
		"mend":
			p.hp = minf(p.hp + float(m.heal), p.max_hp)
			sim.events.append({e = "dream", id = id, move = move, time = 0.0})
			sim.events.append({e = "heal", id = id})
		"fade":
			p.faded = t + float(m.secs)
			p.safe_until = maxf(p.safe_until, t + float(m.secs))
			p.forming = {}; p.swing = {}; p.queued = {}
			sim.events.append({e = "dream", id = id, move = move, time = float(m.secs)})
		"haste":
			p.haste = t + float(m.secs); p.haste_k = float(m.mult)
			sim.events.append({e = "dream", id = id, move = move, time = float(m.secs)})
		"chain":
			var e := _looked_at(sim, p, aim, float(m.range), float(m.near))
			if e.is_empty():
				return "no one there to reach"
			sim.effects.append({kind = "dream_chain", owner = id, move = move, pos = sim._feet(e), on = e.id, left = float(m.wind), weave = move, id = sim._fx_id(), cost = cost, rad = float(m.slip)})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind), on = e.id})
		"pit":
			var d: Vector3 = (aim - p.pos) * Vector3(1, 0, 1)
			var at: Vector3 = p.pos + d.limit_length(float(m.range))
			at.y = Terrain.height(at.x, at.z)
			sim.effects.append({kind = "dream_pit", owner = id, move = move, pos = at, wait = float(m.wind), left = float(m.secs), rad = float(m.radius), weave = move, id = sim._fx_id(), cost = cost})
			sim.events.append({e = "dream", id = id, move = move, time = float(m.wind), pos = at, radius = float(m.radius)})
		"wall":
			if m.get("ring", false):
				# Six walls round you, a hexagon with you in the middle.
				var r: float = float(m.radius)
				for i in 6:
					var yw: float = p.yaw + i * TAU / 6.0
					var c: Vector3 = p.pos + Vector3(sin(yw), 0, cos(yw)) * r * 0.87
					c.y = Terrain.height(c.x, c.z)
					sim.effects.append({kind = "dream_wall", owner = id, move = move, pos = c, yaw = yw, half = r * 0.5 + 0.12, left = float(m.secs), weave = move, id = sim._fx_id(), rad = r + 0.24})
			else:
				var f := _face(p)
				var c: Vector3 = p.pos + f * float(m.ahead)
				c.y = Terrain.height(c.x, c.z)
				sim.effects.append({kind = "dream_wall", owner = id, move = move, pos = c, yaw = p.yaw, half = float(m.width) * 0.5, left = float(m.secs), weave = move, id = sim._fx_id(), rad = float(m.width), reflect = m.get("reflect", false)})
			sim.events.append({e = "dream", id = id, move = move, time = 0.0, pos = p.pos, yaw = p.yaw})
	p.will -= cost
	p.will_t = t
	sim.tallies[id].dreams = sim.tallies[id].get("dreams", 0) + 1
	return ""

## Moved about this far: players by their shove (it dies away at 7 a second), others
## by their velocity.
static func _push(e: Dictionary, by: Vector3) -> void:
	if e.kind == "player":
		e.shove = by * 7.0
	else:
		e.vel += by * 3.0

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
	return not wall_between(sim, a, b).is_empty()

## The dream wall between a and b, if any.
static func wall_between(sim: Sim, a: Vector3, b: Vector3) -> Dictionary:
	for fx in sim.effects:
		if fx.kind != "dream_wall":
			continue
		var side := Vector3(cos(fx.yaw), 0, -sin(fx.yaw))
		var w0: Vector3 = fx.pos - side * fx.half
		var w1: Vector3 = fx.pos + side * fx.half
		if Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(w0.x, w0.z), Vector2(w1.x, w1.z)) != null:
			return fx
	return {}

## One tick of a dream effect. False when it is over.
static func step_effect(sim: Sim, fx: Dictionary, owner: Dictionary, dt: float) -> bool:
	var m: Dictionary = moves[fx.move]
	match fx.kind:
		"dream_bolt":
			if fx.wait > 0.0:
				fx.wait -= dt
				return owner.alive
			if m.has("home"):
				# Ravens: turn after the nearest foe, a little each moment.
				var best := {}; var bd := 1e9
				for e in sim._targets(owner):
					var d: float = e.pos.distance_to(fx.pos)
					if d < bd:
						bd = d; best = e
				if not best.is_empty():
					var want: Vector3 = (sim._feet(best) + Vector3(0, 1.2, 0) - fx.pos).normalized()
					var ang: float = fx.dir.angle_to(want)
					if ang > 0.001:
						fx.dir = fx.dir.slerp(want, minf(float(m.home) * dt / ang, 1.0)).normalized()
			var hops := maxi(int(ceil(float(m.speed) * dt / 0.6)), 1)
			for hop in hops:
				var before: Vector3 = fx.pos
				var stepv: Vector3 = fx.dir * float(m.speed) * dt / hops
				fx.pos += stepv; fx.left -= stepv.length()
				var wall := wall_between(sim, before, fx.pos)
				if not wall.is_empty() and wall.get("reflect", false) and wall.owner != fx.owner and sim.ents.has(wall.owner):
					# A mirror: back the way it came, and now it is the mirror-maker's.
					var nrm := Vector3(sin(wall.yaw), 0, cos(wall.yaw))
					fx.dir = fx.dir - 2.0 * fx.dir.dot(nrm) * nrm
					fx.owner = wall.owner; owner = sim.ents[wall.owner]
					fx.pos = before
					sim.events.append({e = "dream_end", move = fx.move, pos = fx.pos})
					continue
				if not wall.is_empty() or Map.in_wall(fx.pos) or fx.pos.y <= Terrain.height(fx.pos.x, fx.pos.z):
					sim.events.append({e = "dream_end", move = fx.move, pos = fx.pos})
					return false
				for e in sim._targets(owner):
					var f := sim._feet(e)
					if Vector2(f.x - fx.pos.x, f.z - fx.pos.z).length() < float(m.get("hit", 0.35)) + e.radius and fx.pos.y > f.y - 0.3 and fx.pos.y < f.y + 2.4 and e.get("safe_until", 0.0) <= sim.t:
						if not _denied(sim, e, fx):
							sim._hurt(e, float(m.dmg), fx.owner, "dream")
							if m.has("knock"):
								e.down = maxf(e.down, float(m.knock))
								_push(e, (fx.dir * Vector3(1, 0, 1)).normalized() * 2.0)
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
				if float(m.get("secs", 0.0)) > 0.0:
					if e.kind == "player":
						e.chained = sim.t + float(m.secs)
						if m.get("cage", false):
							e.caged = sim.t + float(m.secs)
						e.swing = {}; e.queued = {}; e.forming = {}; e.dash = {}
					else:
						e.stagger = maxf(e.stagger, float(m.secs))
					sim.events.append({e = "chained", id = e.id, by = fx.owner, time = float(m.secs), cage = m.get("cage", false)})
				if m.has("drain"):
					e.will = maxf(e.get("will", 0.0) - float(m.drain), 0.0)
					e.will_t = sim.t
					sim.events.append({e = "drained", id = e.id, by = fx.owner, pos = sim._feet(e)})
				if m.has("shove"):
					# Away from the one who made it (or, drawn in, toward them).
					var away: Vector3 = (e.pos - owner.pos) * Vector3(1, 0, 1)
					var gap: float = away.length()
					away = away.normalized() if gap > 0.1 else _face(owner)
					# `shove` is how far, in paces; drawn in stops short at their feet.
					var far: float = float(m.shove) if float(m.shove) > 0.0 else -minf(-float(m.shove), maxf(gap - 1.6, 0.0))
					_push(e, away * far)
					e.stagger = maxf(e.stagger, 0.5)
					sim.events.append({e = "dream_hit", move = fx.move, id = e.id, pos = sim._feet(e) + Vector3(0, 1.2, 0)})
			return false
		"dream_pit":
			if fx.wait > 0.0:
				fx.wait -= dt
				if fx.wait <= 0.0:
					for e in sim._targets(owner):
						if sim._feet(e).distance_to(fx.pos) < fx.rad and _denied(sim, e, fx):
							return false
					sim.events.append({e = "pit_open", pos = fx.pos, radius = fx.rad, time = fx.left, move = fx.move})
					if m.has("burst"):
						# Lightning: struck once, there and then.
						for e in sim._targets(owner):
							if sim._feet(e).distance_to(fx.pos) < fx.rad + e.radius * 0.5:
								sim._hurt(e, float(m.burst), fx.owner, "dream")
								e.stagger = maxf(e.stagger, 0.6)
				return owner.alive
			fx.left -= dt
			for e in sim._targets(owner):
				if sim._feet(e).distance_to(fx.pos) < fx.rad + e.radius * 0.5:
					if float(m.slow) < 1.0:
						e.mired = sim.t + 0.15
						e.mire = float(m.slow)
					if float(m.dps) > 0.0:
						sim._hurt(e, float(m.dps) * dt, fx.owner, "dream", true)
			return fx.left > 0.0
		"dream_wall":
			fx.left -= dt
			return fx.left > 0.0
	return false
