class_name Creature
extends RefCounted
## Turns a spec (see species.gd) into a skinned mesh on a humanoid skeleton.
## build() is pure and thread-safe; instantiate() makes the nodes on the main thread.

const BONES: Array[String] = ["hips", "spine", "chest", "neck", "head",
	"clav_l", "uarm_l", "farm_l", "hand_l", "thigh_l", "shin_l", "foot_l", "toe_l",
	"clav_r", "uarm_r", "farm_r", "hand_r", "thigh_r", "shin_r", "foot_r", "toe_r"]
const PARENT: Array[int] = [-1, 0, 1, 2, 3, 2, 5, 6, 7, 0, 9, 10, 11, 2, 13, 14, 15, 0, 17, 18, 19]
# Left-side indices; add RIGHT for the other side.
const HIPS := 0
const SPINE := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const CLAV := 5
const UARM := 6
const FARM := 7
const HAND := 8
const THIGH := 9
const SHIN := 10
const FOOT := 11
const TOE := 12
const RIGHT := 8
const NB := 21

## Two-bone IK: where the middle joint goes so a chain a->mid->c has lengths l1, l2.
static func ik2(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var ac := c - a
	var d := clampf(ac.length(), absf(l1 - l2) + 1e-4, l1 + l2 - 1e-4)
	var dir := ac.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var side := (pole - dir * pole.dot(dir)).normalized()
	return a + dir * x + side * sqrt(maxf(l1 * l1 - x * x, 0.0))

## Rest-pose joint positions in model space: feet on y=0, facing +Z, +X is its left.
## Returns 21 joints followed by tips: hand_l, hand_r, toe_l, toe_r, head top.
static func joints(s: Dictionary) -> PackedVector3Array:
	var H: float = s.height
	var J := PackedVector3Array(); J.resize(NB + 5)
	var hip_y: float = s.leg * H
	var sh_y: float = s.shoulder_y * H
	var hz: float = s.hunch * 0.1 * H
	J[HIPS] = Vector3(0, hip_y + 0.03 * H, 0)
	J[SPINE] = Vector3(0, hip_y + 0.1 * H, hz * 0.1)
	J[CHEST] = Vector3(0, lerpf(hip_y, sh_y, 0.55), hz * 0.45)
	J[NECK] = Vector3(0, sh_y + 0.035 * H, hz)
	var na: float = s.hunch * 0.9
	J[HEAD] = J[NECK] + Vector3(0, cos(na), sin(na)) * s.neck_len * H
	J[NB + 4] = J[HEAD] + Vector3(0, 0.12 * s.head_size * H / 1.8 * 1.8, 0)
	var arm_dir := Vector3(sin(0.7), -cos(0.7), 0)
	for side in 2:
		var m := Vector3(-1 if side else 1, 1, 1)
		var o := RIGHT * side
		J[CLAV + o] = Vector3(0.02 * H, sh_y - 0.02 * H, hz * 0.9) * m
		J[UARM + o] = Vector3(s.shoulder_w * H, sh_y, hz * 0.9) * m
		J[FARM + o] = J[UARM + o] + arm_dir * m * s.arm * H * 0.53
		J[HAND + o] = J[FARM + o] + arm_dir * m * s.arm * H * 0.47
		J[NB + side] = J[HAND + o] + arm_dir * m * 0.1 * s.hand * H / 1.8
		var hip := Vector3(s.hip_w * H, hip_y, 0) * m
		var ankle: Vector3; var ball: Vector3; var tip: Vector3; var slack: float; var tf: float
		if s.digit:
			# Digitigrade: the "ankle" is a raised hock; the creature stands on its toes.
			ankle = Vector3(hip.x * 1.15, 0.17 * H, -0.065 * H)
			ball = ankle + Vector3(0, -0.14 * H, 0.06 * H)
			tip = ball + Vector3(0, -0.03 * H, 0.04 * H)
			slack = 1.08 + s.crouch * 0.9; tf = 0.56
		else:
			ankle = Vector3(hip.x * 1.2, 0.05 * H, -0.02 * H)
			ball = ankle + Vector3(0, -0.035 * H, 0.085 * H)
			tip = ball + Vector3(0, -0.005 * H, 0.045 * H)
			slack = 1.02 + s.crouch * 0.8; tf = 0.52
		var total := hip.distance_to(ankle) * slack
		J[THIGH + o] = hip
		J[SHIN + o] = ik2(hip, ankle, total * tf, total * (1.0 - tf), Vector3.BACK)
		J[FOOT + o] = ankle
		J[TOE + o] = ball
		J[NB + 2 + side] = tip
	return J


static func build(s: Dictionary) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var J := joints(s)
	var H: float = s.height
	var u := H / 1.8
	# Gear first: it decides which hand grips a weapon.
	var kit := Gear.build(s, J)
	var sd := Sdf.new()
	_body(sd, s, J)
	var body_end := sd.prims.size()
	# Fine regions: thin features (faces, horns, fingers) need smaller cells.
	var fine: Array = []
	var hands: Array[AABB] = []
	for side in 2:
		var bb := AABB(J[HAND + RIGHT * side], Vector3.ZERO)
		for p in sd.prims:
			if p.bone == HAND + RIGHT * side:
				bb = bb.merge(p.aabb)
		hands.append(bb.grow(0.02 * u))
	var head_xf := Transform3D(Basis.from_euler(Vector3(s.hunch * 0.25, 0, 0)), J[HEAD])
	sd.place(head_xf, s.head_size * u)
	var eyes: Array = Heads.build(sd, s)
	sd.place()
	var head_bb := sd.prims[body_end].aabb
	for i in range(body_end, sd.prims.size()):
		if sd.prims[i].op == Sdf.UNION:
			head_bb = head_bb.merge(sd.prims[i].aabb)
	# The ground plane slices everything flat at y=0: clean soles for free.
	sd.use(0, Color.BLACK, 0.004).box(Vector3(0, -0.5, 0), Vector3(3, 0.5, 3), 0.0).op = Sdf.CARVE

	var cell: float = s.cell * maxf(u, 1.0) * s.get("lod", 1.0)
	var hcell: float = s.head_cell * s.head_size * maxf(u, 1.0) * s.get("lod", 1.0)
	var regions: Array = [[sd.bounds().grow(cell * 2.0), cell], [head_bb.grow(hcell * 2.0), hcell]]
	for bb in hands:
		regions.append([bb, hcell * 1.3])
	var grids: Array[Sdf.Grid] = []
	var body := Sdf.MeshData.new()
	for ri in regions.size():
		var g := Sdf.Grid.make(regions[ri][0], regions[ri][1])
		sd.fill(g)
		grids.append(g)
		var skip: Array[AABB] = []
		if ri == 0:
			for rj in range(1, regions.size()):
				skip.append((regions[rj][0] as AABB).grow(-cell))
		body.append(Sdf.surface(g, skip, 0.045 * u if ri == 0 else 0.02 * u))
	Sdf.skin(body, sd.prims, sd.prims, NB, 0.03 * u, 0.012 * u, Color(0, 0, 0, -1))
	var gear := Sdf.MeshData.new()
	var shells: Array = []
	for sh in kit.shells:
		_shell(sh, grids, regions, sd.prims, gear, shells, u)
	_cull_covered(body, shells)
	for pr: Sdf in kit.props:
		var pg := Sdf.Grid.make(pr.bounds().grow(hcell * 3.0), hcell)
		pr.fill(pg)
		var pm := Sdf.surface(pg, [], 0.03)
		Sdf.skin(pm, pr.prims, pr.prims, NB, 0.02, 0.01, Color(0, 0, 0, -1))
		gear.append(pm)
	for e in eyes:
		_eye(body, head_xf * (e.pos * s.head_size * u), e.r * s.head_size * u, head_xf.basis * e.dir, e.iris)
	var out := {spec = s, joints = J, body = body.arrays(), tris = (body.idx.size() + gear.idx.size()) / 3}
	if gear.verts.size() > 0:
		out.gear = gear.arrays()
	out.ms = Time.get_ticks_msec() - t0
	return out


static var _rag: FastNoiseLite

## A shell is the body surface pushed out by a thickness and kept only inside a mask:
## mail, hide, cloth. It inherits the body's skin weights, so it deforms with it.
static func _shell(sh: Dictionary, grids: Array[Sdf.Grid], regions: Array, body_prims: Array[Sdf.Prim], out: Sdf.MeshData, shells: Array, u: float) -> void:
	if _rag == null:
		_rag = FastNoiseLite.new(); _rag.frequency = 9.0
	var mask: Sdf = sh.mask
	var thick: float = sh.thick
	var rag: float = sh.get("ragged", 0.0)
	var mb := mask.bounds().grow(0.03)
	var paint: Array[Sdf.Prim] = []
	if sh.has("paint"):
		paint = (sh.paint as Sdf).prims
	for gi in grids.size():
		var g := grids[gi]
		var box := g.box().intersection(mb)
		if box.size.x <= g.c * 2.0 or box.size.y <= g.c * 2.0 or box.size.z <= g.c * 2.0:
			continue
		var lg := Sdf.Grid.make(box, g.c)
		mask.fill(lg)
		var ox := roundi((lg.o.x - g.o.x) / g.c); var oy := roundi((lg.o.y - g.o.y) / g.c); var oz := roundi((lg.o.z - g.o.z) / g.c)
		for z in lg.nz:
			for y in lg.ny:
				var i := (y + z * lg.ny) * lg.nx
				var gz := z + oz; var gy := y + oy
				var row_ok := gz >= 0 and gz < g.nz and gy >= 0 and gy < g.ny
				var gi0 := (gy + gz * g.ny) * g.nx + ox
				for x in lg.nx:
					var bf := 1.0
					if row_ok and x + ox >= 0 and x + ox < g.nx:
						bf = g.f[gi0 + x]
					var mf := lg.f[i]
					if rag > 0.0 and absf(mf) < rag * 2.0:
						mf += _rag.get_noise_3d(lg.o.x + x * g.c, lg.o.y + y * g.c, lg.o.z + z * g.c) * rag
					lg.f[i] = maxf(bf - thick, mf)
					i += 1
		var skip: Array[AABB] = []
		if gi == 0:
			for rj in range(1, regions.size()):
				skip.append((regions[rj][0] as AABB).grow(-g.c))
		var m := Sdf.surface(lg, skip, 0.045 * u)
		Sdf.skin(m, body_prims, paint, NB, 0.03 * u, 0.012 * u, sh.col)
		out.append(m)
		shells.append([lg, thick])

## Drop body triangles that are safely under a shell: saves fill and stops poke-through.
static func _cull_covered(body: Sdf.MeshData, shells: Array) -> void:
	if shells.is_empty():
		return
	var n := body.verts.size()
	var cov := PackedByteArray(); cov.resize(n)
	for sh in shells:
		var lg: Sdf.Grid = sh[0]
		var bb := lg.box().grow(-lg.c)
		for i in n:
			if cov[i] == 0 and bb.has_point(body.verts[i]) and lg.sample(body.verts[i]) < -0.5 * sh[1]:
				cov[i] = 1
	var idx := PackedInt32Array()
	for t in body.idx.size() / 3:
		var a := body.idx[t * 3]; var b := body.idx[t * 3 + 1]; var c := body.idx[t * 3 + 2]
		if cov[a] + cov[b] + cov[c] < 3:
			idx.append_array([a, b, c])
	body.idx = idx


static func _body(sd: Sdf, s: Dictionary, J: PackedVector3Array) -> void:
	var u: float = s.height / 1.8
	var t: float = s.bulk
	var l: float = s.limb
	var mu: float = s.muscle
	var skin: Color = s.skin; skin.a = 0.5
	var fur: Color = s.fur; fur.a = 1.0
	var horn: Color = s.horn; horn.a = 0.0
	var furry: float = s.furry
	var back := fur if furry > 0.45 else skin
	var hz := J[NECK].z

	# Torso: one continuous trunk (wide blends) rather than stacked balls.
	var gut: float = s.gut
	var rib := J[CHEST].lerp(J[NECK], 0.42)
	var lean := Basis.from_euler(Vector3(s.hunch * 0.5, 0, 0))
	var belly := J[SPINE] + Vector3(0, 0.02, 0.01 + gut * 0.05) * u
	var waist := (0.138 * t + gut * 0.03) * u
	sd.use(HIPS, skin, 0.07 * u)
	sd.ball(J[HIPS], Vector3(0.165 * t, 0.12, 0.118 * t) * u)
	sd.cone(J[HIPS], belly, 0.15 * t * u, waist, Vector2(1, 0.74)).bone2 = SPINE
	sd.use(SPINE)
	sd.ball(belly, Vector3(0.138 * t + gut * 0.03, 0.12, 0.1 * t + gut * 0.08) * u)
	sd.cone(belly, rib, waist, 0.165 * t * u, Vector2(1, 0.74)).bone2 = CHEST
	sd.use(CHEST)
	sd.ball(rib, Vector3(0.172 * t, 0.19, 0.128 * t) * u * (1.0 + 0.1 * s.hunch), lean)
	# Shoulder yoke and the hump of a hunched back.
	sd.use(CHEST, back)
	sd.cone(J[UARM] * Vector3(0.75, 1, 1), J[UARM + RIGHT] * Vector3(0.75, 1, 1), 0.085 * t * u, 0.085 * t * u, Vector2(1, 0.9))
	sd.ball(Vector3(0, J[UARM].y - 0.02 * u, hz - 0.07 * t * u), Vector3(0.2 * t, 0.16, 0.1 * t) * u * (0.8 + 0.25 * mu + 0.2 * s.hunch), lean)
	for side in 2:
		var m := Vector3(-1 if side else 1, 1, 1)
		var o := RIGHT * side
		var sh := J[UARM + o]; var el := J[FARM + o]; var wr := J[HAND + o]; var tip := J[NB + side]
		var ad := (el - sh).normalized()
		# Traps and pecs.
		sd.use(CHEST, back, 0.04 * u)
		sd.cone(J[NECK] + Vector3(0.03 * u * m.x, 0.02 * u, -0.02 * u), sh + Vector3(-0.03 * u * m.x, 0.03 * u, -0.02 * u), 0.06 * t * u * (0.7 + 0.5 * mu), 0.05 * t * u)
		sd.use(CHEST, skin, 0.06 * u)
		sd.ball(Vector3(sh.x * 0.5, sh.y - 0.1 * u * t, hz * 0.8 + 0.105 * t * u), Vector3(0.095, 0.065, 0.03) * t * u * (0.75 + 0.3 * mu), lean)
		# Arm.
		sd.use(UARM + o, back, 0.035 * u)
		sd.ball(sh + Vector3(0.01 * m.x, 0.0, 0) * u, Vector3(0.07, 0.075, 0.07) * l * u * (0.9 + 0.2 * mu))
		sd.use(UARM + o, skin, 0.03 * u)
		sd.cone(sh, el, 0.064 * l * u, 0.05 * l * u)
		sd.ball(sh.lerp(el, 0.5) + Vector3(0, 0, 0.018 * l * u), Vector3(0.048, 0.09, 0.05) * l * u * (0.8 + 0.25 * mu), Basis(Vector3.BACK, 0.7 * m.x))
		sd.use(FARM + o, fur if furry > 0.7 else skin)
		sd.cone(el, wr, 0.056 * l * u, 0.038 * l * u)
		sd.ball(el.lerp(wr, 0.3), Vector3(0.046, 0.08, 0.05) * l * u, Basis(Vector3.BACK, 0.7 * m.x))
		_hand(sd, s, HAND + o, wr, tip, m.x, skin, horn, s.get("weapon_side", -1) == side)
		# Leg.
		var hip := J[THIGH + o]; var kn := J[SHIN + o]; var an := J[FOOT + o]; var ball := J[TOE + o]; var toe := J[NB + 2 + side]
		sd.use(HIPS, skin, 0.05 * u)
		sd.ball(hip + Vector3(0.01 * m.x, 0.0, -0.05 * t) * u, Vector3(0.1, 0.11, 0.1) * t * u)
		var legc := fur if (s.digit and furry > 0.25) or furry > 0.8 else skin
		sd.use(THIGH + o, legc, 0.04 * u)
		sd.cone(hip + Vector3(0.012 * m.x * u, -0.01 * u, 0), kn, 0.105 * l * u, 0.066 * l * u)
		sd.ball(hip.lerp(kn, 0.45) + Vector3(0.01 * m.x, 0, 0.025) * l * u, Vector3(0.085, 0.17, 0.09) * l * u)
		sd.use(SHIN + o, legc, 0.03 * u)
		if s.digit:
			sd.cone(kn, an, 0.062 * l * u, 0.036 * l * u)
			sd.ball(kn.lerp(an, 0.3) + Vector3(0, 0, -0.02) * l * u, Vector3(0.06, 0.12, 0.07) * l * u, Basis(Vector3.RIGHT, -0.5))
			sd.use(FOOT + o, legc, 0.025 * u)
			sd.cone(an, ball, 0.036 * l * u, 0.04 * l * u)
			_hoof_or_paw(sd, s, TOE + o, ball, toe, m.x, legc, horn)
		else:
			sd.cone(kn, an, 0.058 * l * u, 0.04 * l * u)
			sd.ball(kn.lerp(an, 0.3) + Vector3(0, 0, -0.025) * l * u, Vector3(0.055, 0.12, 0.06) * l * u)
			sd.use(FOOT + o, skin, 0.02 * u)
			sd.ball(an + Vector3(0, -0.01, -0.02) * l * u, Vector3(0.04, 0.05, 0.05) * l * u)
			sd.cone(an + Vector3(0, -0.01 * u, 0.01 * u), ball, 0.042 * l * u, 0.04 * l * u, Vector2(1, 0.8))
			sd.use(TOE + o, skin, 0.015 * u)
			sd.cone(ball, toe, 0.042 * l * u, 0.03 * l * u, Vector2(1, 0.7))
	# Neck.
	sd.use(NECK, back if furry > 0.6 else skin, 0.04 * u)
	var nk := sd.cone(J[NECK] + Vector3(0, -0.03 * u, -0.01 * u), J[HEAD] + Vector3(0, 0.03, 0) * u, 0.082 * t * u, 0.068 * t * u * lerpf(1.0, 1.15, s.hunch))
	nk.bone2 = HEAD


static func _hand(sd: Sdf, s: Dictionary, bone: int, wr: Vector3, tip: Vector3, mx: float, skin: Color, horn: Color, grip: bool) -> void:
	var hs: float = s.hand * s.height / 1.8
	var d := (tip - wr).normalized()
	var fwd := Vector3.BACK
	var inward := d.cross(fwd) * mx      # palm side, towards the body
	sd.use(bone, skin, 0.012 * hs)
	var rot := Basis(d.cross(fwd).normalized(), d, fwd)
	sd.box(wr + d * 0.05 * hs, Vector3(0.017, 0.05, 0.043) * hs, 0.014 * hs, rot)
	var claws: bool = s.species != "human"
	for f in 4:
		var z := (f - 1.5) * 0.023 * hs
		var flen := (0.075 - absf(f - 1.4) * 0.008) * hs
		var a := wr + d * 0.095 * hs + fwd * z
		var curl := 1.6 if grip else 0.25
		var mid := a + (d - inward * curl).normalized() * flen * 0.55
		var end := mid + (d * (-0.6 if grip else 1.0) - inward * 0.8).normalized() * flen * 0.45
		sd.use(bone, skin, 0.006 * hs)
		sd.cone(a, mid, 0.0115 * hs, 0.0105 * hs)
		sd.cone(mid, end, 0.0105 * hs, 0.009 * hs)
		if claws:
			sd.use(bone, horn, 0.004 * hs)
			sd.cone(end, end + (d - inward * 1.3).normalized() * 0.03 * hs, 0.008 * hs, 0.002 * hs)
	var ta := wr + d * 0.035 * hs + fwd * 0.04 * hs
	var tb := ta + (d + fwd * 0.9 - inward * 0.3).normalized() * 0.045 * hs
	sd.use(bone, skin, 0.008 * hs)
	sd.cone(ta, tb, 0.014 * hs, 0.012 * hs)
	sd.cone(tb, tb + (d * 1.2 + fwd * 0.2 - inward * 0.4).normalized() * 0.035 * hs, 0.012 * hs, 0.01 * hs)


static func _hoof_or_paw(sd: Sdf, s: Dictionary, bone: int, ball: Vector3, toe: Vector3, mx: float, legc: Color, horn: Color) -> void:
	var u: float = s.height / 1.8 * s.limb
	if s.head in ["wolf", "bear", "hawk"]:
		# Paw or talon: splayed toes with claws.
		sd.use(bone, legc, 0.015 * u)
		sd.ball(ball + Vector3(0, -0.01, 0.01) * u, Vector3(0.05, 0.035, 0.055) * u)
		for i in 3:
			var ang := (i - 1) * 0.45 * mx
			var dir := Vector3(sin(ang), 0, cos(ang))
			var a := ball + dir * 0.04 * u
			var b := Vector3(a.x, 0.018 * u, a.z) + dir * 0.06 * u
			sd.use(bone, legc, 0.01 * u)
			sd.cone(a, b, 0.024 * u, 0.02 * u)
			sd.use(bone, horn, 0.005 * u)
			sd.cone(b, b + dir * 0.05 * u + Vector3(0, -0.012 * u, 0), 0.014 * u, 0.003 * u)
	else:
		# Cloven hoof: two dark toes flaring to the ground.
		sd.use(bone, horn, 0.008 * u)
		for i in 2:
			var x := (i - 0.5) * 0.045 * u
			sd.cone(ball + Vector3(x * 0.7, 0, 0), Vector3(toe.x + x * 1.1, 0.02 * u, toe.z), 0.028 * u, 0.04 * u, Vector2(0.75, 1))
		# Fetlock tuft hides the join.
		sd.use(bone - 1, legc, 0.02 * u)
		sd.ball(ball + Vector3(0, 0.03, -0.02) * u, Vector3(0.045, 0.05, 0.055) * u)


## Eyes are rigid spheres added after meshing: far too small for the clay grid.
static func _eye(m: Sdf.MeshData, c: Vector3, r: float, dir: Vector3, iris: Color) -> void:
	var base := m.verts.size()
	var rings := 7; var segs := 10
	dir = dir.normalized()
	for i in rings + 1:
		var th := PI * i / rings
		for j in segs:
			var ph := TAU * j / segs
			var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var f := n.dot(dir)
			var col := Color(0.55, 0.52, 0.48, 0.0)
			if f > 0.93: col = Color(0.005, 0.005, 0.005, 0.0)
			elif f > 0.72: col = Color(iris, 0.0)
			m.verts.append(c + n * r); m.norms.append(n); m.ao.append(1.0); m.cols.append(col)
			m.bones.append_array([HEAD, 0, 0, 0]); m.weights.append_array([1.0, 0.0, 0.0, 0.0])
	for i in rings:
		for j in segs:
			var a := base + i * segs + j; var b := base + i * segs + (j + 1) % segs
			m.idx.append_array([a, b, a + segs, b, b + segs, a + segs])


# ---------------------------------------------------------------------------

static var _mat: ShaderMaterial
static var _gear_mat: ShaderMaterial

static func instantiate(data: Dictionary) -> Walker:
	var root := Walker.new()
	var sk := Skeleton3D.new()
	sk.name = "Skeleton"
	var J: PackedVector3Array = data.joints
	var skin := Skin.new()
	for i in NB:
		sk.add_bone(BONES[i])
		sk.set_bone_parent(i, PARENT[i])
		# Bones are pure offsets with identity rotation: posing maths stays in model axes.
		var local := J[i] - (J[PARENT[i]] if PARENT[i] >= 0 else Vector3.ZERO)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		sk.set_bone_pose_position(i, local)
		skin.add_bind(i, Transform3D(Basis.IDENTITY, -J[i]))
	root.add_child(sk)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.body)
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/body.gdshader")
	mesh.surface_set_material(0, _mat)
	if data.has("gear"):
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.gear)
		if _gear_mat == null:
			_gear_mat = ShaderMaterial.new()
			_gear_mat.shader = load("res://shaders/gear.gdshader")
		mesh.surface_set_material(1, _gear_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	# Skinned bounds are unknown to the engine; pad so nothing is culled mid-stride.
	mi.extra_cull_margin = 1.0
	root.setup(data, sk)
	return root
