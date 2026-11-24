class_name Map
## Where an activity happens, as pure maths: no nodes, so the headless Sim, the
## terrain mesh and foot placement all agree on the same ground and the same walls.
## A map is either a corridor running along -Z (enemies come from the far, negative
## end) whose half-width varies with z, closed at both ends; or round (`around`),
## a basin `radius` across. Past the edge the ground climbs into cliffs: what stops
## you is rock you can see, never an invisible wall. `ledges` are raised ground
## (plateaus with steep sides and a ramp up, or low shelves a jump reaches).

const MAPS := {
	open = {},
	# Tarwin's Gap: a pass between the Mountains of Dhoom. Wide where the Trollocs
	# gather, pinched at a chokepoint in front of the line the defenders hold. Shelves
	# of rock along both walls behind the line, a ramp up each: ground to shoot from.
	tarwins_gap = {length = 125.0, back = 40.0, wide = 40.0, narrow = 14.0, choke_z = -26.0, choke_len = 18.0, cliff = 46.0, breastwork = true,
		ledges = [{x = -31.0, z = 6.0, rx = 6.0, rz = 14.0, h = 3.2, ramp = Vector2(0.15, 1)}, {x = 29.0, z = 10.0, rx = 7.0, rz = 12.0, h = 2.6, ramp = Vector2(-1, 0.8)},
			{x = -24.0, z = -62.0, rx = 6.0, rz = 9.0, h = 1.5}, {x = 26.0, z = -80.0, rx = 8.0, rz = 7.0, h = 4.0, ramp = Vector2(-1, 0.2)}]},
	# A caravan caught in open hills: wagons drawn into a ring, and the Shadow
	# coming from every side. No pass to hold; the ring is the line. Low hills round
	# about, a knoll to climb.
	wagon_ring = {around = true, radius = 78.0, cliff = 18.0, ring = 9.5,
		ledges = [{x = -30.0, z = 26.0, rx = 9.0, rz = 7.0, h = 2.2, ramp = Vector2(0.7, -0.7)}, {x = 36.0, z = 30.0, rx = 6.0, rz = 6.0, h = 1.5}, {x = -12.0, z = -40.0, rx = 11.0, rz = 6.0, h = 3.0, ramp = Vector2(0.1, 1)}]},
	# The Watch Hill: a broken height in the Borderland hills. A flat-topped hill in
	# the middle with two ramps up, a ring of lower shelves and knolls round it, and
	# the Shadow coming up from every side.
	highlands = {around = true, radius = 85.0, cliff = 20.0,
		ledges = [{x = 0.0, z = 0.0, rx = 13.0, rz = 11.0, h = 4.0, ramp = Vector2(0, 1)}, {x = 0.0, z = 0.0, rx = 13.0, rz = 11.0, h = 0.0, ramp = Vector2(-1, -0.3)},
			{x = 30.0, z = -18.0, rx = 8.0, rz = 6.0, h = 2.4, ramp = Vector2(-1, 0)}, {x = -32.0, z = -14.0, rx = 7.0, rz = 9.0, h = 1.5},
			{x = -26.0, z = 30.0, rx = 10.0, rz = 7.0, h = 3.0, ramp = Vector2(0.8, -0.6)}, {x = 28.0, z = 32.0, rx = 6.0, rz = 6.0, h = 1.4},
			{x = 4.0, z = -44.0, rx = 12.0, rz = 6.0, h = 2.0, ramp = Vector2(0, 1)}, {x = 50.0, z = 6.0, rx = 6.0, rz = 10.0, h = 3.5, ramp = Vector2(-1, 0.3)}]},
}
## A map with nothing named (the training yard, the open fields of the Wild Hunt and
## the doorway modes): round, this far across before the hills close it in.
const OPEN_RADIUS := 80.0
const OPEN_CLIFF := 14.0
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
	# Every fight's ground is the full-height one. (The camp flattens its own after
	# this; a doorway's fight built inside the camp used to keep the camp's flat
	# ground while the server's sim had the real one: weaves and arrows struck
	# bumps nobody could see.)
	Terrain.amp = 1.0
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
	for i in 30:
		var x := 0.0; var z := 0.0
		if corridor():
			z = rng.randf_range(-float(m.length) + 5.0, float(m.back) - 5.0)
			x = (-1.0 if rng.randf() < 0.5 else 1.0) * (half_width(z) + rng.randf_range(-2.5, 2.0))
		else:
			# Round maps: dead trees scattered out toward the rim, a few nearer.
			var a := rng.randf() * TAU; var rr := radius() * sqrt(rng.randf_range(0.12, 0.9))
			x = sin(a) * rr; z = cos(a) * rr
		var th := rng.randf_range(3.5, 6.5)
		if rise(x, z) > 0.2 or (m.has("ring") and Vector2(x, z).length() < float(m.ring) + 4.0) or (activity == "camp_training" and Vector2(x, z + 6.0).length() < 24.0):
			continue
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
		# Places to walk to (camp.gd STATIONS): the armoury, the tailor, the study.
		for st in STATIONS:
			# Drawn from this entry; what stops you is the boxes below, the shape of
			# what stands there (a single circle let you walk through a rack's ends).
			_solid(st.x, st.z, 0.05, 1.6, st.prop, {yaw = st.yaw})
			for part in STATION_SOLIDS[st.id]:
				var c := Vector2(st.x, st.z) + Vector2(part[0], part[1]).rotated(-float(st.yaw))
				_walls.append({x = c.x, z = c.y, hx = part[2], hz = part[3], h = part[4], yaw = st.yaw, rot = st.yaw, look = "none"})

## The camp's places to walk to: each faces the middle of the camp, a few paces
## off on the open side (the doorways' arc runs round to the right).
const STATIONS := [
	{id = "armoury", prop = "armoury", x = -8.2, z = -0.6, r = 0.9, yaw = PI * 0.5},
	{id = "tailor", prop = "tailor", x = -7.0, z = -5.6, r = 0.9, yaw = PI * 0.5 - 0.6},
	{id = "study", prop = "study", x = -6.6, z = 4.2, r = 0.8, yaw = PI * 0.5 + 0.6},
]

## The solid parts of each station, in its own frame (built facing +z, as Scenery
## builds it): [x, z, half width, half depth, height].
const STATION_SOLIDS := {
	armoury = [[0.0, 0.05, 1.05, 0.2, 2.3], [1.6, 0.2, 0.42, 0.3, 1.7]],
	tailor = [[0.0, 0.05, 1.05, 0.3, 1.8], [1.7, 0.3, 0.4, 0.32, 1.8]],
	study = [[0.0, 0.0, 0.78, 0.43, 1.0], [0.0, 0.7, 0.24, 0.24, 0.5]],
}

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
## way round walls, trees, steep rock and water: {x0, z0, nx, nz, cell, blocked}.
## blocked: 0 open, 1 not to be walked (a wall, a trunk, a cliff edge, deep water,
## past the edge), 2 shallow water (walked, but Trollocs hate it). Built once per map,
## each thing laid into the cells it covers (not every cell asking every thing).
static func grid() -> Dictionary:
	if not _grid.is_empty():
		return _grid
	var cell := 1.25
	var ex := extents()
	var x0: float = ex.position.x; var z0: float = ex.position.y
	var nx := int(ceil(ex.size.x / cell)); var nz := int(ceil(ex.size.y / cell))
	var blocked := PackedByteArray(); blocked.resize(nx * nz)
	# Heights at the cell corners: a cell whose corners differ by more than a steep
	# climb is a cliff edge, walked round (or up a ramp), not up.
	var hilly: bool = not m.get("ledges", []).is_empty()
	var hs := PackedFloat32Array(); hs.resize((nx + 1) * (nz + 1))
	if hilly:
		for iz in nz + 1:
			for ix in nx + 1:
				hs[iz * (nx + 1) + ix] = Terrain.height(x0 + ix * cell, z0 + iz * cell)
	for iz in nz:
		for ix in nx:
			var px := x0 + (ix + 0.5) * cell; var pz := z0 + (iz + 0.5) * cell
			var bad := bound_dist(px, pz) > -0.4
			if not bad and hilly:
				var a := hs[iz * (nx + 1) + ix]; var b := hs[iz * (nx + 1) + ix + 1]
				var c := hs[(iz + 1) * (nx + 1) + ix]; var d := hs[(iz + 1) * (nx + 1) + ix + 1]
				bad = maxf(maxf(a, b), maxf(c, d)) - minf(minf(a, b), minf(c, d)) > cell * STEEP
			var wd := water_depth(px, pz)
			if bad or wd == 2:
				blocked[iz * nx + ix] = 1
			elif wd == 1:
				blocked[iz * nx + ix] = 2
	var mark := func(cx: float, cz: float, reach: float, test: Callable) -> void:
		var i0 := maxi(int(floor((cx - reach - x0) / cell)), 0); var i1 := mini(int(floor((cx + reach - x0) / cell)), nx - 1)
		var k0 := maxi(int(floor((cz - reach - z0) / cell)), 0); var k1 := mini(int(floor((cz + reach - z0) / cell)), nz - 1)
		for kz in range(k0, k1 + 1):
			for kx in range(i0, i1 + 1):
				if test.call(x0 + (kx + 0.5) * cell, z0 + (kz + 0.5) * cell):
					blocked[kz * nx + kx] = 1
	for w in _walls:
		mark.call(float(w.x), float(w.z), maxf(float(w.hx), float(w.hz)) + 1.5, func(px: float, pz: float) -> bool:
			var l := _local(w, px, pz)
			return absf(l.x) < w.hx + 0.7 and absf(l.y) < w.hz + 0.7)
	for t in _trees:
		mark.call(float(t.x), float(t.z), float(t.r) + 1.0, func(px: float, pz: float) -> bool:
			return Vector2(px - t.x, pz - t.z).length() < float(t.r) + 0.75)
	_grid = {x0 = x0, z0 = z0, nx = nx, nz = nz, cell = cell, blocked = blocked}
	return _grid

## A climb steeper than this (rise over run) is a cliff: not walked up.
const STEEP := 1.15

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
	for t in trees_near(p.x, p.z):
		var d := Vector2(p.x - t.x, p.z - t.z)
		var min_d: float = t.r + radius
		if d.length_squared() < min_d * min_d and d.length_squared() > 1e-6:
			d = d.normalized() * min_d
			p.x = t.x + d.x; p.z = t.z + d.y
	return p

## Trees (and props) by 4 m cell, so a walker looks at the few beside it and not every
## one on the map, several times a tick for each of a hundred Trollocs. Rebuilt when the
## map's list is replaced or grows (trees never move).
const TREE_CELL := 4.0
static var _tgrid := {}
static var _tgrid_src: Array = []
static var _tgrid_n := -1

static func trees_near(x: float, z: float) -> Array:
	if not is_same(_tgrid_src, _trees) or _tgrid_n != _trees.size():
		_tgrid = {}
		for t in _trees:
			var k := Vector2i(floori(float(t.x) / TREE_CELL), floori(float(t.z) / TREE_CELL))
			if not _tgrid.has(k):
				_tgrid[k] = []
			_tgrid[k].append(t)
		_tgrid_src = _trees; _tgrid_n = _trees.size()
	var c := Vector2i(floori(x / TREE_CELL), floori(z / TREE_CELL))
	var out := []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l = _tgrid.get(c + Vector2i(dx, dz))
			if l != null:
				out.append_array(l)
	return out

static func half_width(z: float) -> float:
	if not corridor():
		return radius()
	var pinch := exp(-pow((z - m.choke_z) / m.choke_len, 2.0))
	return lerpf(m.wide, m.narrow, pinch) + sin(z * 0.11) * 1.5

## A pass (long, closed at both ends) rather than a round basin.
static func corridor() -> bool:
	return m.has("length") and not m.get("around", false)

## How far a round map reaches from its middle before the hills.
static func radius() -> float:
	return float(m.get("radius", OPEN_RADIUS))

## How far (x, z) is past the edge of the walkable ground: negative inside.
static func bound_dist(x: float, z: float) -> float:
	if corridor():
		# The pass, closed behind the defenders and at the far end by the same rock.
		return maxf(absf(x) - half_width(z), maxf(z - float(m.back), -float(m.length) - z))
	return Vector2(x, z).length() - radius()

## The walkable ground's bounding box, with room for the cliff foot: (x0, z0, w, d).
static func extents() -> Rect2:
	if corridor():
		var wx: float = float(m.wide) + 2.0
		return Rect2(-wx, -float(m.length) - 2.0, wx * 2.0, float(m.length) + float(m.back) + 4.0)
	var r := radius() + 2.0
	return Rect2(-r, -r, r * 2.0, r * 2.0)

## Keep a walker inside the map. Cheap enough to call for every entity every tick.
static func clamp_pos(p: Vector3, margin := 0.6) -> Vector3:
	if corridor():
		var w := half_width(p.z) - margin
		return Vector3(clampf(p.x, -w, w), p.y, clampf(p.z, -float(m.length) + margin, float(m.back) - margin))
	var flat := Vector2(p.x, p.z)
	var most := radius() - margin
	if flat.length() > most:
		flat = flat.normalized() * most
	return Vector3(flat.x, p.y, flat.y)

## Extra ground height from the cliffs: zero inside, rising steeply from the edge.
## The rock starts a little inside the edge, so where walking stops you are already
## at the foot of a slope too steep to go on up. (Raised ground is `rise`, added
## flat by Terrain, so the tops of ledges are level.)
static func ridge(x: float, z: float) -> float:
	var out := bound_dist(x, z)
	var side := smoothstep(-1.5, 14.0, out)
	var cliff: float = float(m.get("cliff", OPEN_CLIFF))
	return side * side * (3.0 - 2.0 * side) * cliff

## Raised ground: each ledge a rounded block `h` high with a steep side a metre wide
## and, if it has a `ramp` (a direction), a slope up to its top on that side. A ledge
## with h 0 adds only a ramp to the ledge it shares a middle with.
static func rise(x: float, z: float) -> float:
	var best := 0.0
	var ls: Array = m.get("ledges", [])
	for L in ls:
		var dx: float = x - float(L.x); var dz: float = z - float(L.z)
		var rx: float = float(L.rx); var rz: float = float(L.rz)
		var h: float = float(L.h)
		var own := h > 0.0
		if not own:
			for L2 in ls:
				if float(L2.h) > 0.0 and float(L2.x) == float(L.x) and float(L2.z) == float(L.z):
					h = float(L2.h)
					break
		var reach := h / 0.42 + 4.0
		if absf(dx) > rx + reach or absf(dz) > rz + reach:
			continue
		var top := 0.0
		if own:
			# Rounded-rectangle distance in metres past the edge (negative inside).
			var q := Vector2(absf(dx) - rx + 3.0, absf(dz) - rz + 3.0)
			var e := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - 3.0
			top = h * (1.0 - smoothstep(-0.45, 0.55, e))
		if L.has("ramp"):
			var d: Vector2 = (L.ramp as Vector2).normalized()
			# Out along the ramp from where it leaves the edge, a gentle slope down.
			var along := dx * d.x + dz * d.y
			var across := absf(-dx * d.y + dz * d.x)
			var edge_at := absf(d.x) * rx + absf(d.y) * rz
			var u := (along - edge_at + 0.6) / (h / 0.42)
			if across < 2.4 and u > -0.3 and u < 1.0:
				top = maxf(top, h * clampf(1.0 - u, 0.0, 1.0) * (1.0 - smoothstep(1.8, 2.4, across)))
		best = maxf(best, top)
	return best

## Can a walker step from a to b? Not up anything steeper than STEEP, unless the top
## is within `lift` (a jump's reach: the height it can land on).
static func step_ok(a: Vector3, b: Vector3, lift := -INF) -> bool:
	var ha := Terrain.height(a.x, a.z); var hb := Terrain.height(b.x, b.z)
	var dh := hb - ha
	if dh <= 0.05:
		return true
	var run := Vector2(b.x - a.x, b.z - a.z).length()
	return dh <= run * STEEP + 0.03 or hb <= lift

## A walker's next place: out of walls and trunks, inside the map, and not up a cliff
## (it slides along the foot of one instead). walls false while vaulting a low wall.
static func walk(from: Vector3, to: Vector3, radius_: float, walls := true, lift := -INF) -> Vector3:
	var p := clamp_pos(unblock(to, radius_, walls))
	if m.get("ledges", []).is_empty() or step_ok(from, p, lift):
		return p
	for q in [Vector3(to.x, to.y, from.z), Vector3(from.x, to.y, to.z)]:
		var p2 := clamp_pos(unblock(q, radius_, walls))
		if step_ok(from, p2, lift):
			return p2
	return from

## Where a wave appears: spread across the far end of the pass, or, on a round map,
## anywhere out toward the rim (not on top of a ledge, not in water).
static func spawn(rng: RandomNumberGenerator) -> Vector3:
	if not corridor():
		for attempt in 12:
			var a := rng.randf() * TAU
			var at := Vector3(sin(a), 0, cos(a)) * rng.randf_range(radius() * 0.62, radius() * 0.8)
			if rise(at.x, at.z) < 0.2 and water_depth(at.x, at.z) == 0:
				return at
		var a2 := rng.randf() * TAU
		return Vector3(sin(a2), 0, cos(a2)) * radius() * 0.7
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
	return {id = id, m = m, trees = _trees, walls = _walls, grid = _grid, amp = Terrain.amp, water = _water}

static func set_state(s: Dictionary) -> void:
	id = s.id; m = s.m; _trees = s.trees; _walls = s.walls; _grid = s.grid; Terrain.amp = s.amp; _water = s.get("water", [])


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
		# (Water lies on the plain ground, never lifted by a ledge or ramp.)
		var y: float = Terrain.dry((w[0] + w[2]) * 0.5, (w[1] + w[3]) * 0.5) - rise((w[0] + w[2]) * 0.5, (w[1] + w[3]) * 0.5) - 0.1
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

## Points round the edge of the walkable ground (for --hitboxes).
static func edge_points() -> Array:
	var out := []
	if not corridor():
		for i in 96:
			var a := TAU * i / 96.0
			var q := Vector3(sin(a), 0, cos(a)) * (radius() - 0.6)
			q.y = Terrain.height(q.x, q.z)
			out.append(q)
		return out
	var z := -float(m.length)
	var left := []
	while z <= float(m.back):
		out.append(Vector3(half_width(z) - 0.6, Terrain.height(half_width(z) - 0.6, z), z))
		left.append(Vector3(-half_width(z) + 0.6, Terrain.height(-half_width(z) + 0.6, z), z))
		z += 2.0
	left.reverse()
	out.append_array(left)
	return out
