class_name Gear
extends RefCounted
## Armour, clothing and weapons, generated per spec.
## Shells hug the body (see Creature._shell); props are rigid solids on one bone.

const CLOTH := 0.0
const LEATHER := 0.33
const MAIL := 0.66
const PLATE := 1.0
const C := preload("res://src/gen/creature.gd")

static func build(s: Dictionary, J: PackedVector3Array) -> Dictionary:
	var kit := {shells = [], props = []}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s.seed, "gear"])
	match s.gear:
		"trolloc": _trolloc(s, J, rng, kit)
		"clothes": Wardrobe.dress(s, J, rng, kit)
	return kit

static func _band(y0: float, y1: float, half_w: float, z: float) -> Sdf:
	var m := Sdf.new()
	m.k = 0.02
	m.box(Vector3(0, (y0 + y1) * 0.5, z), Vector3(half_w, (y1 - y0) * 0.5, 1.0), 0.02)
	return m

static func _trolloc(s: Dictionary, J: PackedVector3Array, rng: RandomNumberGenerator, kit: Dictionary) -> void:
	var u: float = s.height / 1.8
	var l: float = s.limb
	var hip_y := J[C.THIGH].y; var knee_y := J[C.SHIN].y
	var sh := J[C.UARM]
	var iron := Color(0.012, 0.012, 0.015, MAIL)
	var hide := Color(0.07, 0.045, 0.03, CLOTH).lerp(Color(s.fur, CLOTH), 0.3)
	var leather := Color(0.045, 0.028, 0.018, LEATHER)
	var plate := Color(0.045, 0.042, 0.042, PLATE)
	var has_mail := rng.randf() < 0.75
	if has_mail:
		var hem := lerpf(knee_y, hip_y, rng.randf_range(0.3, 0.75))
		var m := _band(hem, J[C.NECK].y + 0.03 * u, sh.x * 0.9, 0.0)
		if rng.randf() < 0.6:
			for side in 2:
				var o := C.RIGHT * side
				m.cone(J[C.UARM + o], J[C.UARM + o].lerp(J[C.FARM + o], rng.randf_range(0.5, 0.85)), 0.17 * u * l, 0.17 * u * l)
		kit.shells.append({mask = m, thick = 0.018 * u, col = iron, ragged = 0.035 * u})
	if not has_mail or rng.randf() < 0.6:
		# Hide kilt.
		var hem := lerpf(knee_y, hip_y, rng.randf_range(0.05, 0.5))
		kit.shells.append({mask = _band(hem, hip_y + 0.11 * u, sh.x * 0.95, 0.0), thick = 0.034 * u, col = hide, ragged = 0.06 * u})
	var waist := J[C.HIPS].y + 0.07 * u
	kit.shells.append({mask = _band(waist - 0.055 * u, waist + 0.055 * u, sh.x * 0.95, 0.0), thick = 0.03 * u, col = leather})
	if rng.randf() < 0.6:
		# Baldric across the chest.
		var m := Sdf.new()
		var dirn := 1.0 if rng.randf() < 0.5 else -1.0
		m.box(Vector3(0, lerpf(waist, sh.y, 0.55), J[C.CHEST].z), Vector3(sh.x * 0.95, 0.055 * u, 1.0), 0.01, Basis(Vector3.BACK, 0.75 * dirn))
		kit.shells.append({mask = m, thick = 0.028 * u, col = leather})
	for side in 2:
		var o := C.RIGHT * side
		var sx := 1.0 - 2.0 * side
		if rng.randf() < 0.55:
			var m := Sdf.new()
			var el := J[C.FARM + o]; var wr := J[C.HAND + o]
			m.cone(el.lerp(wr, 0.3), el.lerp(wr, 0.6), 0.1 * u * l, 0.1 * u * l)
			kit.shells.append({mask = m, thick = 0.02 * u, col = plate if rng.randf() < 0.5 else leather})
		if not s.digit and rng.randf() < 0.6:
			var m := Sdf.new()
			m.cone(J[C.SHIN + o].lerp(J[C.FOOT + o], 0.15), J[C.SHIN + o].lerp(J[C.FOOT + o], 0.9), 0.14 * u, 0.14 * u)
			kit.shells.append({mask = m, thick = 0.02 * u, col = leather, ragged = 0.02 * u})
		if rng.randf() < 0.65:
			# Spiked shoulder plate, rigid on the chest.
			var p := Sdf.new()
			var c := J[C.UARM + o] + Vector3(0.02 * sx, 0.075 * l, 0.0) * u
			p.use(C.CHEST, plate, 0.015 * u)
			var ps := rng.randf_range(0.65, 0.95)
			p.ball(c, Vector3(0.15, 0.06, 0.14) * l * u * ps, Basis(Vector3.BACK, -0.45 * sx))
			p.ball(c + Vector3(0.06 * sx, -0.05, 0) * l * u, Vector3(0.12, 0.05, 0.13) * l * u * ps, Basis(Vector3.BACK, -0.9 * sx))
			p.use(C.CHEST, plate, 0.006 * u)
			for i in rng.randi_range(1, 3):
				var base := c + Vector3((0.02 + 0.05 * i) * sx, 0.04 - 0.02 * i, (i - 1) * 0.05) * l * u
				p.cone(base, base + Vector3(0.07 * sx * (i + 0.5), 0.16, 0.0) * u * rng.randf_range(0.8, 1.4), 0.03 * u, 0.004 * u)
			kit.props.append(p)
	# weapon_kind in the spec fixes what is carried (the sim decides how a Trolloc
	# attacks from it); without it a few go bare-handed.
	if rng.randf() < 0.92 or s.has("weapon_kind"):
		var side := 1 if rng.randf() < 0.75 else 0
		s.weapon_side = side
		kit.props.append(_weapon(s, J, rng, side))

## Crude Shadow-forged weapons. Built in bind pose so that, with the arm hanging,
## the business end points forward.
static func _weapon(s: Dictionary, J: PackedVector3Array, rng: RandomNumberGenerator, side: int) -> Sdf:
	var u: float = s.height / 1.8
	var hs: float = s.hand * u
	var o := C.RIGHT * side
	var sx := 1.0 - 2.0 * side
	var wr := J[C.HAND + o]
	var d := (J[C.NB + side] - wr).normalized()
	var to_bind := Basis(Vector3.BACK, sx * 0.45)
	var a := to_bind * Vector3(0, -0.05, 1).normalized()
	var lat := to_bind * Vector3.RIGHT
	var up := a.cross(lat)
	var g := wr + d * 0.085 * hs - d.cross(Vector3.BACK) * sx * 0.035 * hs
	var wood := Color(0.05, 0.032, 0.02, LEATHER)
	var steel := Color(0.06, 0.06, 0.065, PLATE)
	var p := Sdf.new()
	var rot := Basis(lat, up, a)
	var kind := rng.randi() % 4
	kind = int(s.get("weapon_kind", kind))
	p.use(C.HAND + o, wood, 0.008 * u)
	match kind:
		0:  # scythe-curved sword
			p.cone(g - a * 0.16 * u, g + a * 0.14 * u, 0.024 * u, 0.024 * u)
			p.use(C.HAND + o, steel, 0.01 * u)
			p.box(g + a * 0.15 * u, Vector3(0.025, 0.07, 0.018) * u, 0.008 * u, rot)
			var pts := []
			for i in 7:
				var t := i / 6.0
				pts.append(g + a * (0.16 + t * 0.85) * u + up * (0.42 * t * t - 0.05 * t) * u)
			p.chain(pts, 0.062 * u, 0.02 * u, Vector2(0.3, 1))
		1:  # bearded axe with a back spike
			p.cone(g - a * 0.3 * u, g + a * 0.8 * u, 0.024 * u, 0.022 * u)
			p.use(C.HAND + o, steel, 0.012 * u)
			var hc := g + a * 0.72 * u
			p.ball(hc + up * 0.13 * u, Vector3(0.022, 0.16, 0.15) * u, rot)
			p.ball(hc + up * 0.21 * u - a * 0.03 * u, Vector3(0.016, 0.07, 0.21) * u, rot)
			p.cone(hc, hc - up * 0.2 * u, 0.03 * u, 0.004 * u)
		2:  # barbed spear / catchpole
			p.cone(g - a * 0.7 * u, g + a * 1.15 * u, 0.022 * u, 0.02 * u)
			p.use(C.HAND + o, steel, 0.01 * u)
			var hc := g + a * 1.15 * u
			p.cone(hc, hc + a * 0.36 * u, 0.05 * u, 0.004 * u, Vector2(0.35, 1))
			p.chain([hc + a * 0.05 * u, hc + a * 0.1 * u + up * 0.12 * u, hc - a * 0.02 * u + up * 0.2 * u, hc - a * 0.12 * u + up * 0.17 * u], 0.024 * u, 0.006 * u)
		5:  # a Trolloc's bow: a thick crude stave of horn and wood, held upright by the
			# limbs run through the fist as a blade would (upright with the arm held
			# out), the tips drawn back toward the archer on the string
			var horn := Color(0.08, 0.06, 0.045, LEATHER)
			p.use(C.HAND + o, horn, 0.01 * u)
			for sy: float in [-1.0, 1.0]:
				var pts := []
				for i in 6:
					var t := i / 5.0
					pts.append(g + a * sy * t * 0.62 * u - d * (0.2 * t * t - 0.02) * u)
				p.chain(pts, 0.032 * u, 0.012 * u)
			p.use(C.HAND + o, Color(0.3, 0.27, 0.2, LEATHER), 0.002 * u)
			p.cone(g + a * 0.62 * u - d * 0.18 * u, g - a * 0.62 * u - d * 0.18 * u, 0.006 * u, 0.006 * u)
		4:  # a Myrddraal's sword: straight, long, and black as the forge it came from
			var black := Color(0.006, 0.006, 0.008, LEATHER)
			p.use(C.HAND + o, black, 0.006 * u)
			p.cone(g - a * 0.13 * u, g + a * 0.1 * u, 0.02 * u, 0.02 * u)
			p.ball(g - a * 0.15 * u, Vector3.ONE * 0.032 * u)
			p.box(g + a * 0.11 * u, Vector3(0.022, 0.13, 0.02) * u, 0.008 * u, rot)
			p.use(C.HAND + o, black, 0.004 * u)
			p.cone(g + a * 0.12 * u, g + a * 1.02 * u, 0.05 * u, 0.03 * u, Vector2(0.22, 1))
			p.cone(g + a * 1.02 * u, g + a * 1.16 * u, 0.03 * u, 0.003 * u, Vector2(0.22, 1))
		3:  # spiked club
			p.cone(g - a * 0.2 * u, g + a * 0.7 * u, 0.022 * u, 0.034 * u)
			var hc := g + a * 0.78 * u
			p.cone(g + a * 0.6 * u, hc, 0.05 * u, 0.075 * u)
			p.use(C.HAND + o, steel, 0.006 * u)
			for i in 9:
				var dir := Vector3(sin(i * 2.4) , cos(i * 2.4), cos(i * 1.7) * 0.8).normalized()
				var b := hc - a * 0.08 * u + a * (i % 3) * 0.05 * u
				p.cone(b, b + (rot * dir) * 0.15 * u, 0.022 * u, 0.003 * u)
	return p
