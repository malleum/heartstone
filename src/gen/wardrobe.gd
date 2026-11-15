class_name Wardrobe
extends RefCounted
## Human clothing by origin. An outfit is a row of garments; a garment is a shell
## (see Creature._shell) described by where it starts and stops on the body.
## Colours are sRGB here and converted on use.

const C := preload("res://src/gen/creature.gd")

# Each garment: [kind, colour, params...]. Kinds are handled in dress().
const OUTFITS := {
	two_rivers = [["trousers", Color(0.2, 0.17, 0.14)], ["boots", Color(0.13, 0.09, 0.06), 0.55], ["coat", Color(0.3, 0.33, 0.2), 0.25, 1.0], ["belt", Color(0.15, 0.1, 0.06)]],
	aiel = [["trousers", Color(0.42, 0.38, 0.3)], ["boots", Color(0.3, 0.24, 0.17), 0.8], ["coat", Color(0.45, 0.41, 0.32), 0.12, 1.0], ["belt", Color(0.25, 0.2, 0.14)], ["shoufa", Color(0.4, 0.36, 0.28)]],
	aes_sedai = [["boots", Color(0.2, 0.15, 0.1), 0.3], ["dress", Color(0.1, 0.25, 0.5), Color(0.8, 0.8, 0.85)], ["shawl", Color(0.85, 0.85, 0.82), Color(0.1, 0.25, 0.5)]],
	cairhien = [["trousers", Color(0.08, 0.08, 0.09)], ["boots", Color(0.06, 0.05, 0.05), 0.6], ["coat", Color(0.09, 0.09, 0.11), 0.5, 1.0, [Color(0.6, 0.1, 0.1), Color(0.75, 0.6, 0.15), Color(0.15, 0.3, 0.6)]], ["belt", Color(0.05, 0.05, 0.05)]],
	warder = [["trousers", Color(0.16, 0.19, 0.15)], ["boots", Color(0.1, 0.08, 0.06), 0.7], ["coat", Color(0.17, 0.22, 0.16), 0.3, 1.0], ["belt", Color(0.12, 0.08, 0.05)], ["sword"]],
	# Black armour of overlapping plates like a serpent's scales, a deep hood, and
	# a cloak that hangs still whatever the wind does.
	myrddraal = [["trousers", Color(0.012, 0.012, 0.014)], ["boots", Color(0.008, 0.008, 0.01), 0.85], ["scales", Color(0.03, 0.03, 0.036), Color(0.16, 0.16, 0.19)], ["belt", Color(0.02, 0.02, 0.02)],
		["cloak", Color(0.006, 0.006, 0.008)], ["hood", Color(0.006, 0.006, 0.008)], ["blade"]],
	draghkar = [["trousers", Color(0.02, 0.018, 0.02)], ["belt", Color(0.03, 0.02, 0.02)]],
	dreadlord = [["trousers", Color(0.015, 0.015, 0.018)], ["boots", Color(0.01, 0.01, 0.012), 0.7], ["coat", Color(0.02, 0.018, 0.02), 0.75, 1.0, [Color(0.5, 0.03, 0.03), Color(0.5, 0.03, 0.03)]],
		["belt", Color(0.45, 0.03, 0.03)], ["hood", Color(0.1, 0.012, 0.014)]],
	domani = [["boots", Color(0.3, 0.2, 0.12), 0.3], ["dress", Color(0.55, 0.2, 0.22), Color(0.8, 0.65, 0.3)], ["belt", Color(0.7, 0.55, 0.2)]],
}

static func _c(c: Color, kind: float) -> Color:
	return Color(c.srgb_to_linear(), kind)

## Torso garments use a full-width band (no gaps under the arms) with the bind-pose
## hands cut back out of it.
static func _torso(y0: float, y1: float, J: PackedVector3Array, u: float) -> Sdf:
	var m := Gear._band(y0, y1, 3.0, 0.0)
	for side in 2:
		var o := C.RIGHT * side
		var c := m.cone(J[C.HAND + o].lerp(J[C.NB + side], 0.25), J[C.NB + side], 0.1 * u, 0.12 * u)
		c.op = Sdf.CARVE; c.k = 0.01
	return m

static func dress(s: Dictionary, J: PackedVector3Array, _rng: RandomNumberGenerator, kit: Dictionary) -> void:
	var u: float = s.height / 1.8
	var hip_y := J[C.THIGH].y; var sh := J[C.UARM]
	var waist := J[C.HIPS].y + 0.085 * u
	var half := sh.x * 1.02       # keeps bind-pose hands out of torso garments
	for g in OUTFITS[s.outfit]:
		match g[0]:
			"trousers":
				kit.shells.append({mask = Gear._band(J[C.FOOT].y + 0.02 * u, waist, half, 0.0), thick = 0.011 * u, col = _c(g[1], Gear.CLOTH)})
			"boots":
				var top := lerpf(J[C.FOOT].y, J[C.SHIN].y, g[2])
				kit.shells.append({mask = Gear._band(-0.1, top, half, 0.0), thick = 0.017 * u, col = _c(g[1], Gear.LEATHER)})
			"coat":
				var hem := lerpf(hip_y, J[C.SHIN].y, g[2])
				var m := _torso(hem, J[C.NECK].y + 0.045 * u, J, u)
				for side in 2:
					var o := C.RIGHT * side
					m.cone(J[C.UARM + o], J[C.UARM + o].lerp(J[C.HAND + o], 0.93 * g[3]), 0.085 * u, 0.06 * u)
				var sh_ := {mask = m, thick = 0.022 * u, col = _c(g[1], Gear.CLOTH)}
				if g.size() > 4:
					# Cairhienin slashes of House colour across the chest.
					var p := Sdf.new()
					var stripes: Array = g[4]
					for i in stripes.size():
						var y := lerpf(J[C.CHEST].y, sh.y, 0.25 + 0.3 * i)
						p.use(0, _c(stripes[i], Gear.CLOTH), 0.004)
						p.box(Vector3(0, y, 0.1 * u), Vector3(half * 0.8, 0.014 * u, 0.2 * u), 0.002).op = Sdf.PAINT
					sh_.paint = p
				kit.shells.append(sh_)
			"belt":
				kit.shells.append({mask = Gear._band(waist - 0.022 * u, waist + 0.022 * u, half * 0.93, 0.0), thick = 0.03 * u, col = _c(g[1], Gear.LEATHER)})
			"scales":
				# Black plate in overlapping strips (lames): a close under-layer, and
				# over it every strip standing proud of the one below, round the trunk
				# and in rings down the arms, each with a dull edge.
				var hem := lerpf(hip_y, J[C.SHIN].y, 0.3)
				var top := J[C.NECK].y + 0.05 * u
				var build := func() -> Sdf:
					var mm := _torso(hem, top, J, u)
					for side in 2:
						var o := C.RIGHT * side
						mm.cone(J[C.UARM + o], J[C.UARM + o].lerp(J[C.HAND + o], 0.95), 0.085 * u, 0.06 * u)
					return mm
				kit.shells.append({mask = build.call(), thick = 0.016 * u, col = _c(g[1].darkened(0.3), Gear.LEATHER)})
				var m: Sdf = build.call()
				var p := Sdf.new()
				p.use(0, _c(g[2], Gear.LEATHER), 0.003)
				var pitch := 0.062 * u; var gap := 0.016 * u
				var y := hem + pitch
				while y < top:
					# The gap between two strips (cut out of the proud layer) and the
					# worn edge just above it.
					m.box(Vector3(0, y, 0), Vector3(half * 0.99, gap * 0.5, 1.0), 0.002).op = Sdf.CARVE
					p.box(Vector3(0, y + gap * 0.5 + 0.004 * u, 0), Vector3(half * 0.99, 0.004 * u, 1.0), 0.001).op = Sdf.PAINT
					y += pitch
				for side in [-1.0, 1.0]:
					var x := half * 1.02
					while x < absf(J[C.HAND].x):
						m.box(Vector3(x * side, sh.y, 0), Vector3(gap * 0.5, 0.4 * u, 1.0), 0.002).op = Sdf.CARVE
						p.box(Vector3((x - gap * 0.5 - 0.004 * u) * side, sh.y, 0), Vector3(0.004 * u, 0.4 * u, 1.0), 0.001).op = Sdf.PAINT
						x += pitch
				# Lacquered, not iron: the plate material rusts, and nothing of a
				# Myrddraal's does.
				kit.shells.append({mask = m, thick = 0.034 * u, col = _c(g[1], Gear.LEATHER), paint = p})
				# Pauldrons: two more strips over each shoulder.
				var pa := Sdf.new()
				for side in 2:
					var o := C.RIGHT * side
					pa.ball(J[C.UARM + o] + Vector3(0, 0.02 * u, 0), Vector3(0.11, 0.075, 0.11) * u)
				kit.shells.append({mask = pa, thick = 0.05 * u, col = _c(g[1], Gear.LEATHER)})
			"cloak":
				# From the shoulders to the heels, open down the front, and still: it
				# is hung from the chest alone, so no stride or wind stirs it.
				var top := sh.y + 0.02 * u
				var neck := J[C.NECK].y + 0.03 * u
				var cl := Sdf.new()
				cl.k = 0.035 * u
				var back := -0.03 * u
				# A yoke closed over the shoulders and up to the cowl, then the fall.
				cl.cone(Vector3(0, neck, back), Vector3(0, top, back), 0.13 * u, 0.31 * u, Vector2(1, 0.72))
				cl.cone(Vector3(0, top, back), Vector3(0, 0.09 * u, back - 0.06 * u), 0.31 * u, 0.47 * u, Vector2(1, 0.8))
				cl.k = 0.015 * u
				cl.cone(Vector3(0, neck - 0.045 * u, back), Vector3(0, top - 0.04 * u, back), 0.09 * u, 0.27 * u, Vector2(1, 0.7)).op = Sdf.CARVE
				cl.cone(Vector3(0, top - 0.04 * u, back), Vector3(0, -0.1 * u, back - 0.06 * u), 0.27 * u, 0.43 * u, Vector2(1, 0.78)).op = Sdf.CARVE
				# The front is open: the armour and the sword arm show.
				cl.box(Vector3(0, top * 0.5, 0.62 * u), Vector3(0.2 * u, top, 0.5 * u), 0.02, Basis.IDENTITY).op = Sdf.CARVE
				for side in [-1.0, 1.0]:
					cl.box(Vector3(0.42 * u * side, top * 0.5, 0.5 * u), Vector3(0.3 * u, top, 0.36 * u), 0.02, Basis(Vector3.UP, 0.55 * side)).op = Sdf.CARVE
				cl.box(Vector3(0, -0.5, 0), Vector3(3, 0.5 + 0.07 * u, 3), 0.0).op = Sdf.CARVE
				kit.shells.append({mask = cl, solid = cl, cell = 0.017 * u, bone = C.CHEST, thick = 0.0, col = _c(g[1], Gear.CLOTH)})
			"hood":
				# A cowl, not a cap: its own hollow shape standing off the skull, the
				# rim thrown forward so the face sits back in its shadow, falling in
				# one piece onto the shoulders, with the point hanging behind.
				var hc := J[C.HEAD] + Vector3(0, 0.1, -0.02) * u
				var m := Sdf.new()
				m.ball(J[C.NECK] + Vector3(0, -0.01, -0.01) * u, Vector3(0.2, 0.075, 0.15) * u)
				var cowl := Sdf.new()
				cowl.k = 0.04 * u
				cowl.ball(hc + Vector3(0, 0.02, 0.03) * u, Vector3(0.11, 0.135, 0.135) * u)
				cowl.ball(hc + Vector3(0, 0.025, 0.115) * u, Vector3(0.113, 0.13, 0.125) * u)
				cowl.cone(hc + Vector3(0, -0.06, -0.02) * u, J[C.NECK] + Vector3(0, -0.035, -0.015) * u, 0.105 * u, 0.185 * u, Vector2(1, 0.74))
				cowl.chain([hc + Vector3(0, 0.09, -0.06) * u, hc + Vector3(0, 0.0, -0.13) * u, hc + Vector3(0, -0.12, -0.135) * u], 0.05 * u, 0.014 * u)
				# The opening: a tall narrow oval, run down to the throat.
				cowl.k = 0.012 * u
				cowl.cone(hc + Vector3(0, -0.012, 0.03) * u, hc + Vector3(0, -0.035, 0.36) * u, 0.086 * u, 0.094 * u, Vector2(0.9, 1)).op = Sdf.CARVE
				cowl.cone(hc + Vector3(0, -0.07, 0.06) * u, hc + Vector3(0, -0.13, 0.33) * u, 0.066 * u, 0.08 * u, Vector2(0.8, 1)).op = Sdf.CARVE
				kit.shells.append({mask = m, thick = 0.018 * u, col = _c(g[1], Gear.CLOTH), solid = cowl, free = true})
			"shoufa":
				var m := Sdf.new()
				var hc := J[C.HEAD] + Vector3(0, 0.1, -0.02) * u
				m.ball(hc, Vector3(0.13, 0.115, 0.115) * u)
				m.ball(J[C.NECK] + Vector3(0, 0.01, 0) * u, Vector3(0.12, 0.07, 0.1) * u)
				kit.shells.append({mask = m, thick = 0.012 * u, col = _c(g[1], Gear.CLOTH)})
			"shawl":
				var m := Sdf.new()
				m.box(Vector3(0, sh.y - 0.07 * u, J[C.CHEST].z - 0.3 * u), Vector3(1.0, 0.16 * u, 0.33 * u), 0.02, Basis(Vector3.RIGHT, 0.5))
				m.box(Vector3(0, sh.y + 0.0 * u, 0), Vector3(1.0, 0.07 * u, 0.5 * u), 0.02)
				for side in 2:
					var o := C.RIGHT * side
					m.cone(J[C.UARM + o], J[C.FARM + o], 0.09 * u, 0.09 * u)
				var p := Sdf.new()
				p.use(0, _c(g[2], Gear.CLOTH), 0.01)
				p.box(Vector3(0, sh.y - 0.2 * u, 0), Vector3(1.0, 0.03 * u, 1.0), 0.002).op = Sdf.PAINT
				kit.shells.append({mask = m, thick = 0.034 * u, col = _c(g[1], Gear.CLOTH), paint = p, coarse_only = true})
			"dress":
				# Bodice hugs the body; the skirt is its own bell that rides on both legs.
				var m := _torso(J[C.SHIN].y, J[C.NECK].y + 0.03 * u, J, u)
				for side in 2:
					var o := C.RIGHT * side
					m.cone(J[C.UARM + o], J[C.UARM + o].lerp(J[C.HAND + o], 0.9), 0.08 * u, 0.055 * u)
				var skirt := Sdf.new()
				skirt.k = 0.03 * u
				skirt.cone(Vector3(0, waist - 0.05 * u, 0), Vector3(0, 0.27 * u, 0), 0.15 * u, 0.3 * u, Vector2(1, 0.85))
				var p := Sdf.new()
				p.use(0, _c(g[2], Gear.CLOTH), 0.008)
				p.box(Vector3(0, 0.06 * u, 0), Vector3(1.0, 0.035 * u, 1.0), 0.002).op = Sdf.PAINT
				p.box(Vector3(0, J[C.NECK].y - 0.015 * u, 0), Vector3(1.0, 0.02 * u, 1.0), 0.002).op = Sdf.PAINT
				kit.shells.append({mask = m, thick = 0.014 * u, col = _c(g[1], Gear.CLOTH), solid = skirt, paint = p, wide = true})
			"blade":
				# A black blade carried bare in the hand (the Myrddraal's), built by
				# the same code as the Trollocs' weapons so the swing arm knows it.
				s.weapon_side = 1
				s.weapon_kind = 4
				kit.props.append(Gear._weapon(s, J, _rng, 1))
			"sword":
				var p := Sdf.new()
				var steel := Color(0.3, 0.3, 0.32, Gear.PLATE)
				var a := J[C.HIPS] + Vector3(0.19, 0.06, 0.02) * u
				var dir := Vector3(0.12, -0.9, -0.42).normalized()
				p.use(C.HIPS, _c(Color(0.12, 0.08, 0.05), Gear.LEATHER), 0.006)
				p.cone(a, a + dir * 0.85 * u, 0.026 * u, 0.016 * u, Vector2(0.5, 1))
				p.use(C.HIPS, steel, 0.006)
				p.box(a - dir * 0.01 * u, Vector3(0.012, 0.012, 0.07) * u, 0.006 * u)
				p.cone(a - dir * 0.02 * u, a - dir * 0.2 * u, 0.014 * u, 0.014 * u)
				p.ball(a - dir * 0.21 * u, Vector3.ONE * 0.022 * u)
				kit.props.append(p)
