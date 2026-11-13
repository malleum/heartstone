class_name Sdf
extends RefCounted
## Signed-distance "clay". A body is a smooth union of bone-tagged primitives, meshed
## with surface nets. Skin weights and colours are derived from which primitives sit
## near each vertex, so nothing is ever authored per-vertex.
##
## Everything here is plain data and static maths so creatures can be generated on
## worker threads.

const UNION := 0
const CARVE := 1
## Paint prims add no geometry: they recolour the surface they overlap.
const PAINT := 2

class Prim:
	var inv: Transform3D   # model space -> prim space (includes cross-section squash)
	var ds := 1.0          # prim-space distance -> model-space distance (conservative)
	var is_box := false
	var h := 0.0           # round cone runs along prim +Y from 0 to h
	var r0 := 0.0
	var r1 := 0.0
	var ca := 1.0
	var cb := 0.0
	var ext := Vector3.ZERO
	var k := 0.02          # blend radius
	var op := 0
	var bone := 0
	var bone2 := -1        # if set, weight slides from bone to bone2 along the cone
	var col := Color.WHITE # alpha is the surface kind: 0 hard/glossy, 0.5 skin, 1 fur
	var aabb: AABB

	func dist(p: Vector3) -> float:
		var q := inv * p
		if is_box:
			var e := q.abs() - ext
			return (Vector3(maxf(e.x, 0), maxf(e.y, 0), maxf(e.z, 0)).length() + minf(maxf(e.x, maxf(e.y, e.z)), 0.0) - r0) * ds
		var qx := sqrt(q.x * q.x + q.z * q.z)
		var kk := ca * q.y - cb * qx
		if kk < 0.0:
			return (sqrt(qx * qx + q.y * q.y) - r0) * ds
		if kk > ca * h:
			return (sqrt(qx * qx + (q.y - h) * (q.y - h)) - r1) * ds
		return (ca * qx + cb * q.y - r0) * ds


class Grid:
	var o: Vector3
	var c: float
	var nx: int
	var ny: int
	var nz: int
	var f: PackedFloat32Array

	static func make(box: AABB, cell: float) -> Grid:
		var g := Grid.new()
		g.c = cell
		# Snap to a global lattice so layers built later line up with the body grid.
		g.o = (box.position / cell).floor() * cell
		var n := ((box.end - g.o) / cell).ceil()
		g.nx = int(n.x) + 1; g.ny = int(n.y) + 1; g.nz = int(n.z) + 1
		g.f = PackedFloat32Array(); g.f.resize(g.nx * g.ny * g.nz); g.f.fill(1.0)
		return g

	func box() -> AABB:
		return AABB(o, Vector3(nx - 1, ny - 1, nz - 1) * c)

	func sample(p: Vector3) -> float:
		var q := (p - o) / c
		var x := clampi(int(q.x), 0, nx - 2); var y := clampi(int(q.y), 0, ny - 2); var z := clampi(int(q.z), 0, nz - 2)
		var u := clampf(q.x - x, 0, 1); var v := clampf(q.y - y, 0, 1); var w := clampf(q.z - z, 0, 1)
		var i := x + (y + z * ny) * nx
		var nxy := nx * ny
		var a := lerpf(lerpf(f[i], f[i + 1], u), lerpf(f[i + nx], f[i + nx + 1], u), v)
		var b := lerpf(lerpf(f[i + nxy], f[i + nxy + 1], u), lerpf(f[i + nxy + nx], f[i + nxy + nx + 1], u), v)
		return lerpf(a, b, w)


class MeshData:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var ao := PackedFloat32Array()
	var cols := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()

	func append(m: MeshData) -> void:
		var base := verts.size()
		verts.append_array(m.verts); norms.append_array(m.norms); ao.append_array(m.ao)
		cols.append_array(m.cols); bones.append_array(m.bones); weights.append_array(m.weights)
		for i in m.idx:
			idx.append(i + base)

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = norms
		a[Mesh.ARRAY_COLOR] = cols
		a[Mesh.ARRAY_INDEX] = idx
		a[Mesh.ARRAY_BONES] = bones
		a[Mesh.ARRAY_WEIGHTS] = weights
		# Rest-pose position rides along in the UVs so procedural textures stick to
		# the skin instead of swimming through it when the skeleton moves.
		var uv := PackedVector2Array(); uv.resize(verts.size())
		var uv2 := PackedVector2Array(); uv2.resize(verts.size())
		for i in verts.size():
			uv[i] = Vector2(verts[i].x, verts[i].y)
			uv2[i] = Vector2(verts[i].z, ao[i])
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_TEX_UV2] = uv2
		return a


# ---------------------------------------------------------------------------
# Building: a tiny stateful brush API so creature recipes stay short.

var prims: Array[Prim] = []
var bone := 0
var col := Color.WHITE
var k := 0.02
# Placement frame for the brush: lets a head recipe be written in head-local units.
var xf := Transform3D.IDENTITY
var sc := 1.0

func place(t: Transform3D = Transform3D.IDENTITY, scale := 1.0) -> Sdf:
	xf = Transform3D(t.basis.orthonormalized() * scale, t.origin); sc = scale
	return self

func use(b: int, c: Color = col, blend: float = k) -> Sdf:
	bone = b; col = c; k = blend
	return self

func _add(p: Prim) -> Prim:
	p.bone = bone; p.col = col; p.k = k
	prims.append(p)
	return p

## Tapered capsule from a to b. sq squashes the cross-section: x across, y front-back
## (relative to model axes), both <= 1.
func cone(a: Vector3, b: Vector3, ra: float, rb: float, sq := Vector2.ONE) -> Prim:
	if a.distance_to(b) < absf(ra - rb) + 1e-4:
		return ball(a if ra > rb else b, Vector3.ONE * maxf(ra, rb))
	var p := Prim.new()
	a = xf * a; b = xf * b; ra *= sc; rb *= sc
	var axis := b - a
	var h := axis.length()
	var y := axis / h
	var x: Vector3; var z: Vector3
	if absf(y.x) < 0.9:
		x = (Vector3.RIGHT - y * y.x).normalized(); z = x.cross(y)
	else:
		z = (Vector3.BACK - y * y.z).normalized(); x = y.cross(z)
	p.inv = Transform3D(Basis(x * sq.x, y, z * sq.y), a).affine_inverse()
	p.ds = minf(1.0, minf(sq.x, sq.y))
	p.h = h; p.r0 = ra; p.r1 = rb
	p.cb = (ra - rb) / h; p.ca = sqrt(1.0 - p.cb * p.cb)
	var r := maxf(ra, rb)
	p.aabb = AABB(a, Vector3.ZERO).expand(b).grow(r)
	return _add(p)

func ball(c: Vector3, radii: Vector3, rot := Basis.IDENTITY) -> Prim:
	var p := Prim.new()
	c = xf * c; radii *= sc; rot = xf.basis.orthonormalized() * rot
	var rm := maxf(radii.x, maxf(radii.y, radii.z))
	var s := radii / rm
	p.inv = Transform3D(rot * Basis.from_scale(s), c).affine_inverse()
	p.ds = minf(s.x, minf(s.y, s.z))
	p.r0 = rm; p.r1 = rm
	var e := Vector3(
		(rot.x.x * radii.x) ** 2 + (rot.y.x * radii.y) ** 2 + (rot.z.x * radii.z) ** 2,
		(rot.x.y * radii.x) ** 2 + (rot.y.y * radii.y) ** 2 + (rot.z.y * radii.z) ** 2,
		(rot.x.z * radii.x) ** 2 + (rot.y.z * radii.y) ** 2 + (rot.z.z * radii.z) ** 2)
	e = Vector3(sqrt(e.x), sqrt(e.y), sqrt(e.z))
	p.aabb = AABB(c - e, e * 2.0)
	return _add(p)

func box(c: Vector3, half: Vector3, rnd: float, rot := Basis.IDENTITY) -> Prim:
	var p := Prim.new()
	p.is_box = true
	c = xf * c; half *= sc; rnd *= sc; rot = xf.basis.orthonormalized() * rot
	p.inv = Transform3D(rot, c).affine_inverse()
	p.ext = half - Vector3.ONE * rnd
	p.r0 = rnd
	var e := rot.x.abs() * half.x + rot.y.abs() * half.y + rot.z.abs() * half.z
	p.aabb = AABB(c - e, e * 2.0)
	return _add(p)

## A curved, tapering chain of cones through the given points (horns, tusks, beaks).
func chain(pts: Array, ra: float, rb: float, sq := Vector2.ONE) -> void:
	var n := pts.size() - 1
	for i in n:
		cone(pts[i], pts[i + 1], lerpf(ra, rb, float(i) / n), lerpf(ra, rb, float(i + 1) / n), sq)

func bounds() -> AABB:
	var b := prims[0].aabb
	for p in prims:
		if p.op == UNION:
			b = b.merge(p.aabb)
	return b


# ---------------------------------------------------------------------------
# Field evaluation

static func splat(g: Grid, p: Prim) -> void:
	var c := g.c
	var bb := p.aabb.grow(p.k + c * 1.5)
	var x0 := maxi(0, floori((bb.position.x - g.o.x) / c)); var x1 := mini(g.nx - 1, ceili((bb.end.x - g.o.x) / c))
	var y0 := maxi(0, floori((bb.position.y - g.o.y) / c)); var y1 := mini(g.ny - 1, ceili((bb.end.y - g.o.y) / c))
	var z0 := maxi(0, floori((bb.position.z - g.o.z) / c)); var z1 := mini(g.nz - 1, ceili((bb.end.z - g.o.z) / c))
	if x0 > x1 or y0 > y1 or z0 > z1:
		return
	var f := g.f
	var inv := p.inv
	var dq := inv.basis.x * c
	var k := p.k; var kq := 0.25 / k
	var carve := p.op == CARVE
	var ds := p.ds
	var is_box := p.is_box
	var r0 := p.r0; var r1 := p.r1; var h := p.h; var ca := p.ca; var cb := p.cb; var cah := p.ca * p.h
	var ext := p.ext
	var nx := g.nx; var ny := g.ny
	for z in range(z0, z1 + 1):
		for y in range(y0, y1 + 1):
			var q := inv * (g.o + Vector3(x0, y, z) * c)
			var i := x0 + (y + z * ny) * nx
			for x in range(x0, x1 + 1):
				var d: float
				if is_box:
					var e := q.abs() - ext
					d = Vector3(maxf(e.x, 0), maxf(e.y, 0), maxf(e.z, 0)).length() + minf(maxf(e.x, maxf(e.y, e.z)), 0.0) - r0
				else:
					var qx := sqrt(q.x * q.x + q.z * q.z)
					var kk := ca * q.y - cb * qx
					if kk < 0.0:
						d = sqrt(qx * qx + q.y * q.y) - r0
					elif kk > cah:
						d = sqrt(qx * qx + (q.y - h) * (q.y - h)) - r1
					else:
						d = ca * qx + cb * q.y - r0
				d *= ds
				var e0 := f[i]
				if carve:
					d = -d
					var hh := k - absf(d - e0)
					if hh > 0.0:
						f[i] = maxf(d, e0) + hh * hh * kq
					elif d > e0:
						f[i] = d
				else:
					var hh := k - absf(d - e0)
					if hh > 0.0:
						f[i] = minf(d, e0) - hh * hh * kq
					elif d < e0:
						f[i] = d
				q += dq
				i += 1

func fill(g: Grid) -> void:
	for p in prims:
		if p.op == UNION:
			splat(g, p)
	for p in prims:
		if p.op == CARVE:
			splat(g, p)


# ---------------------------------------------------------------------------
# Surface nets

const _EDGES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7]

## Mesh the zero surface of g. Cells whose vertex falls inside a skip box are left
## out: finer grids own those regions.
static func surface(g: Grid, skip: Array[AABB], ao_reach := 0.07) -> MeshData:
	var m := MeshData.new()
	var f := g.f
	var nx := g.nx; var ny := g.ny; var nz := g.nz; var nxy := nx * ny
	var c := g.c
	var vid := PackedInt32Array(); vid.resize(nxy * nz); vid.fill(-1)
	var cells := PackedInt32Array()
	var cf := PackedFloat32Array(); cf.resize(8)
	var cp: Array[Vector3] = [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
	for z in nz - 1:
		for y in ny - 1:
			var i := (y + z * ny) * nx
			var a0 := f[i]; var a1 := f[i + nx]; var a2 := f[i + nxy]; var a3 := f[i + nx + nxy]
			for x in nx - 1:
				var b0 := f[i + 1]; var b1 := f[i + nx + 1]; var b2 := f[i + nxy + 1]; var b3 := f[i + nx + nxy + 1]
				var neg := int(a0 < 0.0) + int(a1 < 0.0) + int(a2 < 0.0) + int(a3 < 0.0) + int(b0 < 0.0) + int(b1 < 0.0) + int(b2 < 0.0) + int(b3 < 0.0)
				if neg != 0 and neg != 8:
					cf[0] = a0; cf[1] = b0; cf[2] = a1; cf[3] = b1; cf[4] = a2; cf[5] = b2; cf[6] = a3; cf[7] = b3
					var sum := Vector3.ZERO
					var cnt := 0
					for e in 12:
						var ia := _EDGES[e * 2]; var ib := _EDGES[e * 2 + 1]
						var fa := cf[ia]; var fb := cf[ib]
						if (fa < 0.0) != (fb < 0.0):
							sum += cp[ia].lerp(cp[ib], fa / (fa - fb))
							cnt += 1
					var l := sum / cnt
					var pos := g.o + (Vector3(x, y, z) + l) * c
					var skipped := false
					for s in skip:
						if s.has_point(pos):
							skipped = true
							break
					if not skipped:
						# Field gradient, trilinearly interpolated at the vertex.
						var u := l.x; var v := l.y; var w := l.z
						var gx := lerpf(lerpf(b0 - a0, b1 - a1, v), lerpf(b2 - a2, b3 - a3, v), w)
						var gy := lerpf(lerpf(a1 - a0, b1 - b0, u), lerpf(a3 - a2, b3 - b2, u), w)
						var gz := lerpf(lerpf(a2 - a0, b2 - b0, u), lerpf(a3 - a1, b3 - b1, u), v)
						var n := Vector3(gx, gy, gz).normalized()
						vid[i] = m.verts.size()
						cells.append(i)
						m.verts.append(pos)
						m.norms.append(n)
						# Cheap crevice darkening: how much free space is there just above the skin?
						m.ao.append(clampf(g.sample(pos + n * ao_reach) / ao_reach, 0.0, 1.0))
				a0 = b0; a1 = b1; a2 = b2; a3 = b3
				i += 1
	var offs: Array[int] = [1, nx, nxy]
	# For the edge along each axis, the three other cells sharing it.
	var nb: Array[int] = [nx, nx + nxy, nxy, nxy, nxy + 1, 1, 1, 1 + nx, nx]
	for i in cells:
		var x := i % nx; var y := (i / nx) % ny; var z := i / nxy
		var s0 := f[i] < 0.0
		for ax in 3:
			if s0 == (f[i + offs[ax]] < 0.0):
				continue
			if (ax != 0 and x == 0) or (ax != 1 and y == 0) or (ax != 2 and z == 0):
				continue
			var v0 := vid[i]; var v1 := vid[i - nb[ax * 3]]; var v2 := vid[i - nb[ax * 3 + 1]]; var v3 := vid[i - nb[ax * 3 + 2]]
			if v1 < 0 or v2 < 0 or v3 < 0:
				continue
			var gn := (m.verts[v1] - m.verts[v0]).cross(m.verts[v2] - m.verts[v0])
			# Godot front faces wind clockwise.
			if gn.dot(m.norms[v0] + m.norms[v2]) > 0.0:
				m.idx.append_array([v0, v2, v1, v0, v3, v2])
			else:
				m.idx.append_array([v0, v1, v2, v0, v2, v3])
	return m


# ---------------------------------------------------------------------------
# Skinning and colouring

## Weights come from the bone tags of nearby prims in wprims; colours from cprims.
## base_col is used where no colour prim reaches (layers such as armour).
static func skin(m: MeshData, wprims: Array[Prim], cprims: Array[Prim], nbones: int, sw: float, sc: float, base_col: Color, from := 0) -> void:
	var acc := PackedFloat32Array(); acc.resize(nbones)
	var n := m.verts.size()
	m.cols.resize(n); m.bones.resize(n * 4); m.weights.resize(n * 4)
	var wreach: Array[AABB] = []
	for p in wprims:
		wreach.append(p.aabb.grow(sw * 4.0))
	var creach: Array[AABB] = []
	for p in cprims:
		creach.append(p.aabb.grow(sc * 4.0))
	for vi in range(from, n):
		var v := m.verts[vi]
		acc.fill(0.0)
		for pi in wprims.size():
			if not wreach[pi].has_point(v):
				continue
			var p := wprims[pi]
			var d := p.dist(v)
			var w := exp(-maxf(d, 0.0) / sw)
			if p.bone2 >= 0:
				var t := smoothstep(0.0, 1.0, (p.inv * v).y / p.h)
				acc[p.bone] += w * (1.0 - t)
				acc[p.bone2] += w * t
			else:
				acc[p.bone] += w
		var tot := 0.0
		for j in 4:
			var best := 0; var bw := -1.0
			for b in nbones:
				if acc[b] > bw:
					bw = acc[b]; best = b
			acc[best] = -1.0
			# Dropping tiny influences keeps rigid parts rigid.
			if bw < 0.02 and j > 0:
				bw = 0.0
			m.bones[vi * 4 + j] = best
			m.weights[vi * 4 + j] = maxf(bw, 0.0)
			tot += maxf(bw, 0.0)
		if tot <= 0.0:
			m.weights[vi * 4] = 1.0; tot = 1.0
		for j in 4:
			m.weights[vi * 4 + j] /= tot
		var cs := Color(0, 0, 0, 0); var cw := 0.0
		for pi in cprims.size():
			var p := cprims[pi]
			if p.op == PAINT or not creach[pi].has_point(v):
				continue
			var w := exp(-absf(p.dist(v)) / sc) if p.op == CARVE else exp(-maxf(p.dist(v), 0.0) / sc)
			cs += p.col * w; cw += w
		var c := base_col
		if cw > 1e-5:
			c = cs / cw
			# Layers have a base colour that shows wherever no colour prim reaches.
			if base_col.a >= 0.0:
				c = base_col.lerp(c, minf(cw, 1.0))
		for pi in cprims.size():
			var p := cprims[pi]
			if p.op == PAINT and creach[pi].has_point(v):
				c = c.lerp(p.col, smoothstep(p.k, 0.0, p.dist(v)))
		m.cols[vi] = c
