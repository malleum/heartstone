class_name Map
## Where an activity happens, as pure maths: no nodes, so the headless Sim, the
## terrain mesh and foot placement all agree on the same ground and the same walls.
## A map is a corridor running along -Z (enemies come from the far, negative end)
## whose half-width varies with z. Outside it the ground climbs into cliffs.

const MAPS := {
	open = {},
	# Tarwin's Gap: a pass between the Mountains of Dhoom. Wide where the Trollocs
	# gather, pinched at a chokepoint in front of the line the defenders hold.
	tarwins_gap = {length = 95.0, back = 22.0, wide = 30.0, narrow = 11.0, choke_z = -20.0, choke_len = 16.0, cliff = 46.0, breastwork = true},
	# A caravan caught in open hills: wagons drawn into a ring, and the Shadow
	# coming from every side. No pass to hold; the ring is the line.
	wagon_ring = {length = 58.0, back = 58.0, wide = 58.0, narrow = 58.0, choke_z = 0.0, choke_len = 1.0, cliff = 16.0, ring = 9.5, around = true},
}
static var id := "open"
static var m := {}

static var _trees: Array = []
static var _walls: Array = []
static var _grid := {}
static var _next_wid := 1
## Water: ponds, streams and rivers, each a capsule {x1, z1, x2, z2, r, deep, y}
## (a circle when both ends are one point). Shallow water slows and soaks; the
## deep middle (deep ones only) cannot be walked. `y` is the surface.
static var _water: Array = []

static func use(map_id: String, activity := "") -> void:
	id = map_id if MAPS.has(map_id) else "open"
	m = MAPS[id]
	_trees = []
	_walls = []
	_grid = {}
	_next_wid = 1
	_water = []
	_waters(activity)
	var wr := RandomNumberGenerator.new(); wr.seed = 11
	if m.get("breastwork", false):
		# The defenders' line: a drystone breastwork across the pass behind the
		# choke, with gaps a Trolloc can come through and a defender can hold.
		var z0 := line_z()
		var w := half_width(z0)
		var x := -w + 1.0
		while x < w - 1.0:
			var seg := minf(wr.randf_range(3.0, 5.5), w - 1.0 - x)
			if seg > 1.5:
				_walls.append({x = x + seg * 0.5, z = z0 + wr.randf_range(-0.4, 0.4), hx = seg * 0.5, hz = 0.38, h = 0.9, yaw = 0.0, look = "stone"})
			x += seg + wr.randf_range(3.2, 4.4)
	if m.has("ring"):
		# Wagons end to end in a circle, four ways in.
		var n := 12
		for i in n:
			if i % 3 == 0:
				continue
			var a := TAU * (i + 0.5) / n
			var c := Vector3(sin(a), 0, cos(a)) * float(m.ring)
			# Each wagon lies along the circle; the solid is its bounding box.
			var along := absf(cos(a)); var across := absf(sin(a))
			# The solid is the wagon itself, turned as it stands (its bed is 1.5 by
			# 4.2, its wheels a little wider), not a box round it.
			_walls.append({x = c.x, z = c.z, hx = 0.95, hz = 2.2, h = 2.1, yaw = a, rot = a + PI * 0.5, look = "wagon"})
	var rng := RandomNumberGenerator.new(); rng.seed = 23
	for i in 22:
		var z := rng.randf_range(-95.0, 30.0) if not m.is_empty() else rng.randf_range(-60.0, 30.0)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * (half_width(z) + rng.randf_range(-2.5, 2.0)) if not m.is_empty() else side * rng.randf_range(9.0, 45.0)
		var th := rng.randf_range(3.5, 6.5)
		# (No tree in a pond.)
		if water_y(x, z) == -INF and water_y(x + 1.5, z) == -INF and water_y(x - 1.5, z) == -INF:
			_trees.append({x = x, z = z, r = 0.38, h = th})
	_props(activity)
	for w in _walls:
		w.wid = _next_wid; _next_wid += 1

## A wall raised during the fight (rubble from a weave of Earth): it gets an id,
## and the way round walls is worked out again.
static func add_wall(w: Dictionary) -> Dictionary:
	if not w.has("wid"):
		w.wid = _next_wid; _next_wid += 1
	_walls.append(w)
	_grid = {}
	return w

## A wall torn down during the fight.
static func remove_wall(wid: int) -> bool:
	for i in _walls.size():
		if int(_walls[i].get("wid", 0)) == wid:
			_walls.remove_at(i)
			_grid = {}
			return true
	return false

## A solid prop as a circle (r, h). `prop` names what the view draws there; the sim
## only sees a circle, like a tree: it blocks feet, and missiles below its top.
static func _solid(x: float, z: float, r: float, h: float, prop: String, extra := {}) -> void:
	var d := {x = x, z = z, r = r, h = h, prop = prop, yaw = 0.0, k = 1.0}
	d.merge(extra, true)
	_trees.append(d)

## The things that stand about each place, where the view draws them and the sim
## collides with them (they used to be dressing only, walked through).
static func _props(activity: String) -> void:
	var pr := RandomNumberGenerator.new(); pr.seed = 3
	if id == "wagon_ring":
		_solid(2.5, 2.0, 0.6, 0.6, "fire")
		for i in 12:
			var a := pr.randf() * TAU
			var rad := pr.randf_range(3.5, 6.5)
			var x := sin(a) * rad; var z := cos(a) * rad
			match i % 3:
				0: _solid(x, z, 0.45, 0.7, "crate", {yaw = pr.randf() * TAU, k = pr.randf_range(0.85, 1.1)})
				1: _solid(x, z, 0.4 if i % 2 == 0 else 0.33, 0.6 if i % 2 == 0 else 0.85, "barrel", {yaw = pr.randf() * TAU, lying = i % 2 == 0})
				2: _solid(x, z, 0.6, 0.55, "sacks", {count = 2 + i % 2, yaw = pr.randf_range(-0.5, 0.5)})
	elif id == "tarwins_gap":
		var z0 := line_z(); var w := half_width(z0)
		# Sharpened stakes ahead of the breastwork, leaning at whatever comes.
		for i in 26:
			_solid(pr.randf_range(-w + 1.5, w - 1.5), z0 - pr.randf_range(3.0, 6.5) - 0.4, 0.12, 1.1, "stake", {yaw = pr.randf_range(-0.2, 0.2)})
		for sx in [-w * 0.55, w * 0.55]:
			_solid(sx, z0 + 4.0, 0.6, 0.6, "fire")
		for sx in [-w * 0.8, w * 0.8]:
			_solid(sx, z0 + 7.0, 0.12, 5.0, "banner")
		if Rules.activities.get(activity, {}).get("night", false):
			for k in 3:
				for sx in [-w * 0.6, w * 0.6]:
					_solid(sx * (1.0 - k * 0.1), z0 - 16.0 - k * 17.0, 0.6, 0.6, "fire")
			for sx in [-w * 0.9, -w * 0.3, w * 0.3, w * 0.9]:
				_solid(sx, z0 + 1.5, 0.1, 2.2, "torch")
	if activity == "camp_training":
		# The yard (drawn by Scenery.yard): a rail fence with a gate behind you,
		# butts, racks, bales, a water butt and benches.
		var c := Vector3(0, 0, -6.0); var r := 21.0; var n := 30
		for i in range(1, n - 1):
			var a0 := i * TAU / n; var a1 := (i + 1) * TAU / n
			var p0 := Vector2(c.x + sin(a0) * r, c.z + cos(a0) * r); var p1 := Vector2(c.x + sin(a1) * r, c.z + cos(a1) * r)
			var mid := (p0 + p1) * 0.5; var d := p1 - p0
			# The rail lies along d: local z along it, so rot turns +z onto d.
			_walls.append({x = mid.x, z = mid.y, hx = 0.08, hz = d.length() * 0.5 + 0.05, h = 1.0, yaw = 0.0, rot = atan2(d.x, d.y), look = "fence"})
		for i in 3:
			var a := PI + (i - 1) * 0.16
			_solid(c.x + sin(a) * (r - 2.0), c.z + cos(a) * (r - 2.0), 0.6, 1.7, "butt")
		for side: float in [-1.0, 1.0]:
			var a: float = side * 1.35
			var rp := Vector2(c.x + sin(a) * (r - 1.5), c.z + cos(a) * (r - 1.5))
			_walls.append({x = rp.x, z = rp.y, hx = 1.0, hz = 0.2, h = 1.6, yaw = 0.0, rot = a + PI, look = "rack"})
			for k in 3:
				var a2: float = a + side * (0.2 + (k if k < 2 else 0.5) * 0.085)
				if k < 2:
					_solid(c.x + sin(a2) * (r - 1.2), c.z + cos(a2) * (r - 1.2), 0.5, 1.0, "bale_yard")
			_solid(c.x + sin(a - side * 0.14) * (r - 1.2), c.z + cos(a - side * 0.14) * (r - 1.2), 0.36, 0.85, "barrel_yard")
			var bp := Vector2(c.x + sin(a - side * 0.3) * (r - 1.4), c.z + cos(a - side * 0.3) * (r - 1.4))
			_walls.append({x = bp.x, z = bp.y, hx = 0.92, hz = 0.18, h = 0.5, yaw = 0.0, rot = a - side * 0.3 + PI, look = "bench"})
	if activity == "camp":
		# The camp's tents and stores (drawn by Scenery.camp from these).
		# Out beyond the ring of doorways (20 m), so every doorway has a clear way in.
		for t in [[21.0, 17.0], [8.5, 25.0], [-7.6, 25.6], [-21.0, 18.0], [-27.0, 6.0], [27.5, 5.0]]:
			var yaw := atan2(-t[0], -(t[1] - 3.0)) + pr.randf_range(-0.25, 0.25)
			var k := pr.randf_range(0.9, 1.15)
			_walls.append({x = t[0], z = t[1], hx = 1.3 * k, hz = 1.75 * k, h = 1.9 * k, yaw = yaw, rot = yaw, look = "tent", k = k})
		_solid(6.0, 3.0, 0.7, 0.6, "fire_camp")
		for k in 3:
			var a := 0.6 + k * 1.5
			_walls.append({x = 6.0 + sin(a) * 1.9, z = 3.0 + cos(a) * 1.9, hx = 0.18, hz = 0.85, h = 0.35, yaw = 0.0, rot = a, look = "log"})
		for c2 in [[8.6, 5.6], [9.3, 4.9]]:
			_solid(c2[0], c2[1], 0.45, 0.7, "crate", {yaw = pr.randf() * TAU, k = pr.randf_range(0.85, 1.1)})
		_solid(8.2, 6.6, 0.33, 0.85, "barrel", {yaw = pr.randf() * TAU})
		_solid(9.9, 5.9, 0.4, 0.6, "barrel", {yaw = pr.randf() * TAU, lying = true})
		_solid(7.2, 7.2, 0.6, 0.55, "sacks", {count = 3})
		_solid(-8.0, 7.5, 0.55, 0.5, "bale", {yaw = 0.4})
		_solid(-9.0, 8.4, 0.55, 0.5, "bale", {yaw = 1.2})
		_solid(-3.0, 6.5, 0.12, 5.2, "banner_camp")

## Solid things standing on the map, as circles: the sim blocks movement and weaves
## on them and the view draws a tree at each, so the two cannot disagree.
static func trees() -> Array:
	return _trees

## Solid walls, as boxes lying along x or z: {x, z, hx, hz, h, yaw, look}. The sim
## blocks movement, weaves and arrows on them (up to h) and the view builds each
## one from its `look`, so what is seen is what stops you.
static func walls() -> Array:
	return _walls

## A point in a wall's own frame (a wall may be turned: `rot`, as the view turns it).
static func _local(w: Dictionary, x: float, z: float) -> Vector2:
	var dx: float = x - w.x; var dz: float = z - w.z
	var r: float = w.get("rot", 0.0)
	if r == 0.0:
		return Vector2(dx, dz)
	return Vector2(dx * cos(r) - dz * sin(r), dx * sin(r) + dz * cos(r))

static func _world(w: Dictionary, l: Vector2) -> Vector2:
	var r: float = w.get("rot", 0.0)
	if r == 0.0:
		return Vector2(w.x + l.x, w.z + l.y)
	return Vector2(w.x + l.x * cos(r) + l.y * sin(r), w.z - l.x * sin(r) + l.y * cos(r))

## Does the straight line from a to b cross a wall (grown by `pad`)?
static func crosses(a: Vector3, b: Vector3, pad := 0.5, min_h := 0.0) -> bool:
	for w in _walls:
		if float(w.h) < min_h:
			continue
		var t0 := 0.0; var t1 := 1.0
		var hit := true
		var la := _local(w, a.x, a.z); var lb := _local(w, b.x, b.z)
		for ax in [[la.x, lb.x - la.x, 0.0, w.hx + pad], [la.y, lb.y - la.y, 0.0, w.hz + pad]]:
			var o: float = ax[0]; var d: float = ax[1]
			var lo: float = ax[2] - ax[3]; var hi: float = ax[2] + ax[3]
			if absf(d) < 1e-6:
				if o < lo or o > hi:
					hit = false
			else:
				var ta := (lo - o) / d; var tb := (hi - o) / d
				t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
				if t0 > t1:
					hit = false
		if hit:
			return true
	return false

## Is this point inside a wall, below its top?
static func in_wall(p: Vector3) -> bool:
	for w in _walls:
		var l := _local(w, p.x, p.z)
		if absf(l.x) < w.hx and absf(l.y) < w.hz and p.y < Terrain.height(w.x, w.z) + w.h:
			return true
	return false

## The ground as a grid of cells an enemy can or cannot stand in, for finding a
## way round walls: {x0, z0, nx, nz, cell, blocked}. Built once per map.
static func grid() -> Dictionary:
	if not _grid.is_empty() or _walls.is_empty():
		return _grid
	var cell := 1.25
	var wx: float = float(m.wide) + 2.0 if not m.is_empty() else 50.0
	var z0: float = -float(m.length) if not m.is_empty() else -50.0
	var z1: float = float(m.back) if not m.is_empty() else 50.0
	var nx := int(ceil(wx * 2.0 / cell)); var nz := int(ceil((z1 - z0) / cell))
	var blocked := PackedByteArray(); blocked.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var p := Vector3(-wx + (ix + 0.5) * cell, 0, z0 + (iz + 0.5) * cell)
			var bad: bool = absf(p.x) > half_width(p.z) - 0.4
			for w in _walls:
				var l := _local(w, p.x, p.z)
				if absf(l.x) < w.hx + 0.7 and absf(l.y) < w.hz + 0.7:
					bad = true
			# Props too, so a way is found round stakes and stores, not into them.
			for t in _trees:
				if t.has("prop") and Vector2(p.x - t.x, p.z - t.z).length() < float(t.r) + 0.75:
					bad = true
			blocked[iz * nx + ix] = 1 if bad else 0
	_grid = {x0 = -wx, z0 = z0, nx = nx, nz = nz, cell = cell, blocked = blocked}
	return _grid

## A low wall or a wagon just ahead that can be vaulted: how far along `dir` you must
## go to land clear of it (0 if there is none within `reach`).
static func vault_over(p: Vector3, dir: Vector3, reach: float, radius: float) -> float:
	var best := 0.0
	for w in _walls:
		# Only what a person can step over with a hand on it: a waist-high wall, not
		# a wagon (the user found vaulting those too much; hitboxes are to be reworked).
		if float(w.h) > 1.2:
			continue
		var la := _local(w, p.x, p.z); var lb := _local(w, p.x + dir.x * (reach + 6.0), p.z + dir.z * (reach + 6.0))
		var t0 := 0.0; var t1 := 1.0; var hit := true
		for ax in [[la.x, lb.x - la.x, w.hx + radius], [la.y, lb.y - la.y, w.hz + radius]]:
			var o: float = ax[0]; var d: float = ax[1]; var e: float = ax[2]
			if absf(d) < 1e-6:
				if absf(o) > e: hit = false
			else:
				var ta := (-e - o) / d; var tb := (e - o) / d
				t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
				if t0 > t1: hit = false
		var length := reach + 6.0
		if hit and t0 * length <= reach:
			best = maxf(best, t1 * length + 0.3)
	return best

## Slide a position out of any tree trunk or wall it overlaps. walls: false while
## vaulting over one.
static func unblock(p: Vector3, radius: float, walls := true) -> Vector3:
	for w in (_walls if walls else []):
		var l := _local(w, p.x, p.z)
		var px: float = w.hx + radius - absf(l.x); var pz: float = w.hz + radius - absf(l.y)
		if px > 0.0 and pz > 0.0:
			# Out by the shorter way, in the wall's own frame.
			if px < pz:
				l.x = (w.hx + radius) * (1.0 if l.x >= 0.0 else -1.0)
			else:
				l.y = (w.hz + radius) * (1.0 if l.y >= 0.0 else -1.0)
			var out := _world(w, l)
			p.x = out.x; p.z = out.y
	# Deep water is not walked: out by the nearest way.
	for w: Dictionary in _water:
		if not w.deep:
			continue
		var a := Vector2(w.x1, w.z1); var ab := Vector2(w.x2, w.z2) - a
		var q := Vector2(p.x, p.z)
		var u := 0.0 if ab.length_squared() < 1e-6 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var c := a + ab * u
		var core: float = w.r * 0.6 + radius
		if q.distance_to(c) < core:
			var out := (q - c).normalized() if q.distance_to(c) > 0.01 else Vector2(1, 0)
			q = c + out * core
			p.x = q.x; p.z = q.y
	for t in _trees:
		var d := Vector2(p.x - t.x, p.z - t.z)
		var min_d: float = t.r + radius
		if d.length_squared() < min_d * min_d and d.length_squared() > 1e-6:
			d = d.normalized() * min_d
			p.x = t.x + d.x; p.z = t.z + d.y
	return p

static func half_width(z: float) -> float:
	if m.is_empty():
		return 1e6
	var pinch := exp(-pow((z - m.choke_z) / m.choke_len, 2.0))
	return lerpf(m.wide, m.narrow, pinch) + sin(z * 0.11) * 1.5

## Keep a walker inside the pass. Cheap enough to call for every entity every tick.
static func clamp_pos(p: Vector3, margin := 0.6) -> Vector3:
	if m.is_empty():
		return p
	var w := half_width(p.z) - margin
	return Vector3(clampf(p.x, -w, w), p.y, clampf(p.z, -m.length, m.back))

## Extra ground height from the cliffs: zero inside the corridor, steep outside.
static func ridge(x: float, z: float) -> float:
	if m.is_empty():
		return 0.0
	var out := absf(x) - half_width(z)
	var side := smoothstep(-1.5, 14.0, out)
	# The pass is closed behind the defenders by a gentler rise, not a wall.
	var behind := smoothstep(m.back, m.back + 30.0, z) * 0.35
	return (side * side * (3.0 - 2.0 * side) + behind) * m.cliff

## Where a wave appears: spread across the far end of the pass, or, on a map
## with no pass, anywhere around the rim.
static func spawn(rng: RandomNumberGenerator) -> Vector3:
	if m.get("around", false):
		var a := rng.randf() * TAU
		return Vector3(sin(a), 0, cos(a)) * rng.randf_range(44.0, 52.0)
	var z: float = -m.length + rng.randf_range(2.0, 22.0)
	var w := half_width(z) - 2.0
	return Vector3(rng.randf_range(-w, w), 0.0, z)

## The line the defenders stand on, just behind the chokepoint.
static func line_z() -> float:
	return 0.0 if m.is_empty() else m.choke_z + m.choke_len * 0.9

## Everything `use` sets up (and the terrain's height scale), to be put back later.
## A camp doorway builds its fight's world while the camp is still walked in: the
## camp keeps its own copy and asks its heights and walls through it.
static func state() -> Dictionary:
	return {id = id, m = m, trees = _trees, walls = _walls, grid = _grid, amp = Terrain.amp}

static func set_state(s: Dictionary) -> void:
	id = s.id; m = s.m; _trees = s.trees; _walls = s.walls; _grid = s.grid; Terrain.amp = s.amp


## Water on each map (drawn by Scenery.water; the ground is dipped to hold it, see
## Terrain.height). Placed where it is never in the way of the line being held.
static func _waters(activity: String) -> void:
	var list := []
	if activity == "camp_training":
		list = [[31.0, -6.0, 31.0, -6.0, 4.5, true]]      # the horse pond beyond the yard
	elif id == "tarwins_gap":
		list = [[-17.0, 30.0, -15.0, 2.0, 2.4, false], [-17.0, 12.0, -17.0, 12.0, 4.5, true]]   # a stream down the left of the pass, with a pool
	elif id == "wagon_ring":
		list = [[27.0, -14.0, 27.0, -14.0, 6.0, true]]
	elif activity == "wild_hunt":
		list = [[22.0, -44.0, 46.0, -12.0, 3.2, false]]    # a river across one corner
	for w in list:
		var y: float = Terrain.dry((w[0] + w[2]) * 0.5, (w[1] + w[3]) * 0.5) - 0.1
		_water.append({x1 = w[0], z1 = w[1], x2 = w[2], z2 = w[3], r = w[4], deep = w[5], y = y})

static func water() -> Array:
	return _water

## Distance from (x, z) to the middle line of a body of water.
static func _wdist(w: Dictionary, x: float, z: float) -> float:
	var a := Vector2(w.x1, w.z1); var b := Vector2(w.x2, w.z2); var p := Vector2(x, z)
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## 0 dry, 1 shallow (slows, soaks), 2 deep (not to be walked).
static func water_depth(x: float, z: float) -> int:
	for w: Dictionary in _water:
		var d: float = _wdist(w, x, z)
		if d < w.r:
			return 2 if (w.deep and d < w.r * 0.6) else 1
	return 0

## The surface height of the water at (x, z), or -INF where there is none.
static func water_y(x: float, z: float) -> float:
	for w: Dictionary in _water:
		if _wdist(w, x, z) < w.r:
			return w.y
	return -INF

## The nearest water to a point: {dist (from its edge, 0 inside), at (the nearest
## point on its edge, on the ground plane)}; empty when the map has none.
static func water_near(p: Vector3) -> Dictionary:
	var best := {}
	for w: Dictionary in _water:
		var d: float = _wdist(w, p.x, p.z) - w.r
		if best.is_empty() or d < best.dist:
			var a := Vector2(w.x1, w.z1); var b := Vector2(w.x2, w.z2); var q := Vector2(p.x, p.z)
			var ab := b - a
			var t := 0.0 if ab.length_squared() < 1e-6 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var c := a + ab * t
			var out := (q - c).normalized() if q.distance_to(c) > 0.01 else Vector2(1, 0)
			var edge: Vector2 = c + out * w.r
			best = {dist = maxf(d, 0.0), at = Vector3(edge.x, w.y, edge.y), y = w.y}
	return best

## How much the ground is reshaped by water at (x, z): {w: 0..1 how far into the
## basin, bed: the height of the bed}; w 0 means untouched.
static func basin(x: float, z: float) -> Dictionary:
	for wt: Dictionary in _water:
		var d: float = _wdist(wt, x, z)
		if d < wt.r * 1.5:
			var depth: float = 0.9 if wt.deep else 0.3
			var bed: float = wt.y - depth * (1.0 - smoothstep(0.35 * wt.r, wt.r, d))
			return {w = 1.0 - smoothstep(wt.r * 0.9, wt.r * 1.5, d), bed = bed}
	return {}
