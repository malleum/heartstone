class_name Armoury
extends RefCounted
## What is carried in the hand: every weapon in data/weapons.json as a small
## generated model. A weapon is built along +Y from the grip at the origin, with
## its flat (or its bow's belly) facing +X; Hero.arm turns that into the hand.

const STEEL := Color(0.62, 0.64, 0.68)
const DARK := Color(0.07, 0.07, 0.08)
const WOOD := Color(0.32, 0.2, 0.1)
const PALE := Color(0.62, 0.5, 0.3)
const LEATHER := Color(0.2, 0.12, 0.07)
const HORN := Color(0.75, 0.68, 0.5)

static func _mat(col: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col; m.metallic = metal; m.roughness = 0.35 if metal > 0.0 else 0.85
	return m

static func _box(n: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.material_override = mat; mi.position = at; mi.rotation = rot
	n.add_child(mi)

## A round bar from a to b, tapering from r0 to r1.
static func _rod(n: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var mi := MeshInstance3D.new(); var c := CylinderMesh.new()
	c.bottom_radius = r0; c.top_radius = r1; c.height = a.distance_to(b); c.radial_segments = 8; c.rings = 1
	mi.mesh = c; mi.material_override = mat; mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	if absf(d.y) < 0.999:
		var x := Vector3.UP.cross(d).normalized()
		mi.basis = Basis(x, d, x.cross(d))
	elif d.y < 0.0:
		mi.basis = Basis(Vector3.RIGHT, PI)
	n.add_child(mi)

static func _blade(n: Node3D, from: float, length: float, width: float, mat: Material) -> void:
	_box(n, Vector3(0.012, length, width), Vector3(0, from + length * 0.5, 0), mat)
	# The point.
	_box(n, Vector3(0.012, width * 0.7, width * 0.7), Vector3(0, from + length, 0), mat, Vector3(PI * 0.25, 0, 0))

static func _hilt(n: Node3D, grip: float, guard: float) -> void:
	_rod(n, Vector3(0, -grip * 0.5, 0), Vector3(0, grip * 0.5, 0), 0.017, 0.017, _mat(LEATHER))
	_box(n, Vector3(0.03, 0.025, guard), Vector3(0, grip * 0.5 + 0.01, 0), _mat(STEEL, 0.8))
	_box(n, Vector3(0.035, 0.035, 0.035), Vector3(0, -grip * 0.5 - 0.01, 0), _mat(STEEL, 0.8))

static func _spear(n: Node3D, below: float, above: float, head: float, shaft: Color) -> void:
	_rod(n, Vector3(0, -below, 0), Vector3(0, above, 0), 0.017, 0.015, _mat(shaft))
	_rod(n, Vector3(0, above, 0), Vector3(0, above + head, 0), 0.032, 0.002, _mat(STEEL, 0.8))

## A strung bow held at its middle: limbs bend back toward the archer (-X).
static func _bow(n: Node3D, height: float, bend: float, col: Color) -> void:
	var m := _mat(col)
	var prev := Vector3.ZERO
	for side in [-1.0, 1.0]:
		prev = Vector3.ZERO
		for i in range(1, 7):
			var f := i / 6.0
			var p := Vector3(-bend * f * f, side * height * 0.5 * f, 0)
			_rod(n, prev, p, 0.016 * (1.0 - 0.6 * (f - 1.0 / 6.0)), 0.016 * (1.0 - 0.6 * f), m)
			prev = p
	# The string is two halves meeting at the nock, so it can be drawn (see string()).
	for name in ["StringA", "StringB"]:
		var mi := MeshInstance3D.new(); var c := CylinderMesh.new()
		c.top_radius = 0.003; c.bottom_radius = 0.003; c.height = 1.0; c.radial_segments = 5; c.rings = 1
		mi.mesh = c; mi.material_override = _mat(Color(0.85, 0.82, 0.75)); mi.name = name
		n.add_child(mi)
	# The arrow on the string, seen only while drawing.
	var nock := Node3D.new(); nock.name = "Nock"; nock.visible = false
	_rod(nock, Vector3(0, 0, 0), Vector3(0.78, 0, 0), 0.005, 0.005, _mat(PALE))
	_rod(nock, Vector3(0.78, 0, 0), Vector3(0.85, 0, 0), 0.013, 0.001, _mat(STEEL, 0.85))
	_box(nock, Vector3(0.1, 0.045, 0.002), Vector3(0.06, 0, 0), _mat(Color(0.85, 0.85, 0.8)))
	n.add_child(nock)
	n.set_meta("bow", {height = height, bend = bend})
	string(n, 0.0, false)

## Draw the string of a bow built by _bow: pull 0 is at rest, 1 a full draw (the
## nock comes back most of an arm's length). With `nocked`, an arrow rides it.
static func string(bow: Node3D, pull: float, nocked: bool) -> void:
	if not bow.has_meta("bow"):
		return
	var m: Dictionary = bow.get_meta("bow")
	string_to(bow, Vector3(-m.bend - pull * 0.5, 0, 0), nocked)

## The string drawn to a given point (the bow's own space): where the string
## hand's fingers are while drawing (ArmPose.nock).
static func string_to(bow: Node3D, nock: Vector3, nocked: bool) -> void:
	if not bow.has_meta("bow"):
		return
	var m: Dictionary = bow.get_meta("bow")
	for pair in [["StringA", 1.0], ["StringB", -1.0]]:
		var mi: MeshInstance3D = bow.get_node(pair[0])
		var tip := Vector3(-m.bend, pair[1] * m.height * 0.5, 0)
		var d := tip - nock
		mi.position = (tip + nock) * 0.5
		var y := d.normalized()
		var x := y.cross(Vector3(0, 0, 1)).normalized()
		mi.basis = Basis(x, y, x.cross(y)).scaled(Vector3(1, d.length(), 1))
	var arrow: Node3D = bow.get_node("Nock")
	arrow.visible = nocked
	arrow.position = nock
	# Along the line from the nock to the grip, where the arrow rests on the bow.
	if nock.length() > 0.05:
		arrow.basis = Basis(Quaternion(Vector3.RIGHT, -nock.normalized()))

## {main, off, off_bone}: main goes in the right hand; off (a bow, a buckler) on
## the named left-arm bone. Either may be null.
static func build(weapon_id: String) -> Dictionary:
	var out := {main = null, off = null, off_bone = "hand_l"}
	if not Rules.weapons.has(weapon_id):
		return out
	var w: Dictionary = Rules.weapons[weapon_id]
	var n := Node3D.new()
	var steel := _mat(STEEL, 0.85)
	match weapon_id:
		"sword": _hilt(n, 0.16, 0.2); _blade(n, 0.09, 0.82, 0.05, steel)
		"bastard_sword": _hilt(n, 0.26, 0.24); _blade(n, 0.14, 1.0, 0.055, steel)
		"heron_blade": _hilt(n, 0.28, 0.12); _blade(n, 0.15, 0.95, 0.04, steel)
		"short_sword": _hilt(n, 0.14, 0.14); _blade(n, 0.08, 0.55, 0.055, steel)
		"sabre": _hilt(n, 0.15, 0.16); _blade(n, 0.085, 0.86, 0.04, steel)
		"practice_sword":
			_rod(n, Vector3(0, -0.14, 0), Vector3(0, 0.14, 0), 0.02, 0.02, _mat(LEATHER))
			_rod(n, Vector3(0, 0.14, 0), Vector3(0, 1.05, 0), 0.024, 0.02, _mat(PALE))
		"belt_knife": _hilt(n, 0.11, 0.07); _blade(n, 0.06, 0.2, 0.03, steel)
		"aiel_knife": _hilt(n, 0.13, 0.06); _blade(n, 0.07, 0.36, 0.045, steel)
		"throwing_knives": _blade(n, -0.04, 0.2, 0.025, steel)
		"throwing_axes":
			_rod(n, Vector3(0, -0.12, 0), Vector3(0, 0.3, 0), 0.014, 0.013, _mat(WOOD))
			_box(n, Vector3(0.022, 0.09, 0.11), Vector3(0, 0.27, 0.05), steel)
		"daggers":
			_hilt(n, 0.11, 0.09); _blade(n, 0.06, 0.26, 0.03, steel)
			var o := Node3D.new(); _hilt(o, 0.11, 0.09); _blade(o, 0.06, 0.26, 0.03, steel)
			out.off = o
		"aiel_spear":
			_spear(n, 0.55, 0.75, 0.32, WOOD)
			# The hide buckler rides the forearm, with spare spears behind it.
			var b := Node3D.new()
			var disc := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.26; c.bottom_radius = 0.28; c.height = 0.035
			disc.mesh = c; disc.material_override = _mat(Color(0.42, 0.33, 0.2)); b.add_child(disc)
			var boss := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.06; s.height = 0.07
			boss.mesh = s; boss.material_override = _mat(LEATHER); boss.position.y = 0.02; b.add_child(boss)
			out.off = b; out.off_bone = "lowerarm_l"
		"javelins": _spear(n, 0.6, 0.7, 0.2, PALE)
		"boar_spear":
			_spear(n, 0.9, 1.0, 0.36, WOOD)
			_box(n, Vector3(0.02, 0.025, 0.24), Vector3(0, 0.98, 0), steel)
		"pike": _spear(n, 1.5, 2.2, 0.3, PALE)
		"halberd":
			_spear(n, 0.9, 1.25, 0.3, WOOD)
			_box(n, Vector3(0.015, 0.3, 0.2), Vector3(0, 1.12, 0.11), steel)
			_rod(n, Vector3(0, 1.14, -0.02), Vector3(0, 1.14, -0.16), 0.02, 0.002, steel)
		"ashandarei":
			_rod(n, Vector3(0, -0.8, 0), Vector3(0, 0.95, 0), 0.018, 0.017, _mat(DARK))
			_blade(n, 0.95, 0.55, 0.05, steel)
		"quarterstaff": _rod(n, Vector3(0, -0.95, 0), Vector3(0, 0.95, 0), 0.02, 0.02, _mat(PALE))
		"iron_staff":
			_rod(n, Vector3(0, -0.95, 0), Vector3(0, 0.95, 0), 0.021, 0.021, _mat(WOOD))
			for y in [-0.88, 0.88]:
				_rod(n, Vector3(0, y - 0.07, 0), Vector3(0, y + 0.07, 0), 0.026, 0.026, _mat(DARK, 0.7))
		"halfmoon_axe":
			_rod(n, Vector3(0, -0.3, 0), Vector3(0, 0.75, 0), 0.019, 0.018, _mat(WOOD))
			# A half-moon blade, balanced by a wicked spike.
			for i in 5:
				var a := lerpf(-0.9, 0.9, i / 4.0)
				_box(n, Vector3(0.014, 0.1, 0.09), Vector3(0, 0.66 + sin(a) * 0.16, 0.1 + cos(a) * 0.1), steel, Vector3(-a, 0, 0))
			_rod(n, Vector3(0, 0.66, -0.01), Vector3(0, 0.66, -0.2), 0.022, 0.002, steel)
		"wood_axe":
			_rod(n, Vector3(0, -0.3, 0), Vector3(0, 0.6, 0), 0.019, 0.018, _mat(WOOD))
			_box(n, Vector3(0.03, 0.14, 0.2), Vector3(0, 0.54, 0.09), steel)
		"hammer":
			_rod(n, Vector3(0, -0.15, 0), Vector3(0, 0.5, 0), 0.018, 0.018, _mat(WOOD))
			_box(n, Vector3(0.08, 0.09, 0.2), Vector3(0, 0.5, 0), _mat(DARK, 0.7))
		"cudgel": _rod(n, Vector3(0, -0.12, 0), Vector3(0, 0.62, 0), 0.018, 0.04, _mat(WOOD))
		"sling":
			# Two cords to a pouch with a stone in it.
			_rod(n, Vector3(0, 0, 0), Vector3(0, -0.5, 0.03), 0.005, 0.005, _mat(LEATHER))
			_rod(n, Vector3(0, 0, 0), Vector3(0, -0.5, -0.03), 0.005, 0.005, _mat(LEATHER))
			var stone := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.04; sp.height = 0.08
			stone.mesh = sp; stone.material_override = _mat(Color(0.42, 0.42, 0.44)); stone.position = Vector3(0, -0.52, 0)
			n.add_child(stone)
		"longbow", "horn_bow", "horse_bow":
			var b := Node3D.new()
			_bow(b, 1.85 if weapon_id == "longbow" else 1.15, 0.2 if weapon_id == "longbow" else 0.24, PALE if weapon_id == "longbow" else HORN)
			out.off = b
			# An arrow in the string hand.
			_rod(n, Vector3(0, -0.35, 0), Vector3(0, 0.4, 0), 0.005, 0.005, _mat(PALE))
			_rod(n, Vector3(0, 0.4, 0), Vector3(0, 0.46, 0), 0.012, 0.001, steel)
		"crossbow":
			_box(n, Vector3(0.05, 0.7, 0.06), Vector3(0, 0.25, 0), _mat(WOOD))
			_box(n, Vector3(0.03, 0.03, 0.75), Vector3(0, 0.56, 0), _mat(DARK, 0.6))
	if n.get_child_count() > 0 or w.family == "hand":
		out.main = n
	else:
		n.free()
	for part in [out.main, out.off]:
		if part:
			for mi: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
				mi.extra_cull_margin = 1.0
	return out

## What an arrow, a knife, a javelin or a stone looks like in the air, built
## pointing along -Z so it can be aimed with look_at.
static func missile(weapon_id: String) -> Node3D:
	var n := Node3D.new()
	var steel := _mat(STEEL, 0.85)
	if not Rules.weapons.has(weapon_id):
		# A Trolloc's arrow: black, thick, crudely fletched.
		_rod(n, Vector3(0, 0, 0.45), Vector3(0, 0, -0.4), 0.009, 0.009, _mat(DARK))
		_rod(n, Vector3(0, 0, -0.4), Vector3(0, 0, -0.52), 0.02, 0.001, _mat(DARK, 0.6))
		_box(n, Vector3(0.07, 0.003, 0.12), Vector3(0, 0, 0.4), _mat(Color(0.15, 0.1, 0.08)))
		return n
	match Rules.weapons[weapon_id].family if not weapon_id in ["javelins", "aiel_spear", "sling", "throwing_knives", "belt_knife", "throwing_axes"] else weapon_id:
		"bow":
			_rod(n, Vector3(0, 0, 0.4), Vector3(0, 0, -0.38), 0.006, 0.006, _mat(PALE))
			_rod(n, Vector3(0, 0, -0.38), Vector3(0, 0, -0.46), 0.014, 0.001, steel)
			_box(n, Vector3(0.05, 0.002, 0.1), Vector3(0, 0, 0.36), _mat(Color(0.85, 0.85, 0.8)))
			_box(n, Vector3(0.002, 0.05, 0.1), Vector3(0, 0, 0.36), _mat(Color(0.85, 0.85, 0.8)))
		"javelins", "aiel_spear":
			_rod(n, Vector3(0, 0, 0.7), Vector3(0, 0, -0.6), 0.015, 0.013, _mat(WOOD))
			_rod(n, Vector3(0, 0, -0.6), Vector3(0, 0, -0.9), 0.03, 0.002, steel)
		"throwing_axes":
			# Turned so it reads as an axe in flight, head forward.
			_rod(n, Vector3(0, 0, 0.18), Vector3(0, 0, -0.18), 0.013, 0.012, _mat(WOOD))
			_box(n, Vector3(0.022, 0.11, 0.09), Vector3(0, 0.05, -0.16), steel)
		"sling":
			var mi := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.035; s.height = 0.07
			mi.mesh = s; mi.material_override = _mat(Color(0.4, 0.4, 0.42)); n.add_child(mi)
		_:
			_box(n, Vector3(0.012, 0.03, 0.24), Vector3.ZERO, steel)
	return n
