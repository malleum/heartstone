class_name Scenery
## Dressing for maps: view only. Nothing here affects the Sim, so anything a Trolloc
## could walk into has to stay off the fighting ground or be small enough to ignore.

static func _mat(col: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	return m

static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.material_override = mat; mi.position = at; mi.rotation = rot
	parent.add_child(mi)

static func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height(x, z), z)

## A watch-fire: logs, flame, and the only warm light in the pass.
static func fire(g: Node3D, at: Vector3) -> void:
	var wood := _mat(Color(0.12, 0.08, 0.05))
	for i in 5:
		_box(g, Vector3(0.14, 0.14, 1.1), at + Vector3(0, 0.25, 0), wood, Vector3(0.9, i * TAU / 5.0, 0))
	var f := Weavefx._particles(Color(1.0, 0.45, 0.12), 40, 0.9, 0.5, 0.5, 2.4, 25.0)
	g.add_child(f); f.position = at + Vector3(0, 0.4, 0)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.55, 0.25); l.light_energy = 3.5; l.omni_range = 14.0
	l.shadow_enabled = false
	g.add_child(l); l.position = at + Vector3(0, 1.4, 0)

static func tarwins_gap(g: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var stone := _mat(Color(0.2, 0.19, 0.18))
	var wood := _mat(Color(0.16, 0.11, 0.07))
	var z0 := Map.line_z()
	var w := Map.half_width(z0)
	# The defenders' line: a broken drystone breastwork with gaps wide enough that
	# nothing needs to path around it, and sharpened stakes pointing up the pass.
	var x := -w + 1.0
	while x < w - 1.0:
		var seg := rng.randf_range(2.2, 4.0)
		if rng.randf() < 0.7:
			# Three courses of rough stones, each a little shorter than the one below.
			var zc := z0 + rng.randf_range(-0.4, 0.4)
			for course in 3:
				var sx := x + course * 0.25
				while sx < x + seg - course * 0.25:
					var sw := rng.randf_range(0.45, 0.85)
					var p := _ground(sx + sw * 0.5, zc)
					var shade := rng.randf_range(0.8, 1.15)
					_box(g, Vector3(sw, 0.36, rng.randf_range(0.5, 0.75)), p + Vector3(0, 0.15 + course * 0.34, rng.randf_range(-0.06, 0.06)),
						_mat(Color(0.2, 0.19, 0.18) * shade), Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.15, 0.15), rng.randf_range(-0.06, 0.06)))
					sx += sw + 0.03
		x += seg + rng.randf_range(1.6, 2.6)
	for i in 26:
		var sx := rng.randf_range(-w + 1.5, w - 1.5)
		var p := _ground(sx, z0 - rng.randf_range(3.0, 6.5))
		_box(g, Vector3(0.09, 2.0, 0.09), p + Vector3(0, 0.6, -0.4), wood, Vector3(-0.85, rng.randf_range(-0.2, 0.2), 0))
	for sx in [-w * 0.55, w * 0.55]:
		fire(g, _ground(sx, z0 + 4.0))
	# Banner poles behind the line, so the place reads as held ground from a distance.
	var cloth := _mat(Color(0.55, 0.1, 0.08), 0.8)
	for sx in [-w * 0.8, w * 0.8]:
		var p := _ground(sx, z0 + 7.0)
		_box(g, Vector3(0.1, 5.0, 0.1), p + Vector3(0, 2.5, 0), wood)
		_box(g, Vector3(0.04, 1.6, 1.0), p + Vector3(0, 4.0, 0.55), cloth)
	# Boulders shed by the cliffs, kept to the edges of the pass.
	for i in 40:
		var z := rng.randf_range(-Map.m.length, Map.m.back)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var bx := side * (Map.half_width(z) + rng.randf_range(-0.5, 3.0))
		var s := rng.randf_range(0.6, 2.4)
		_box(g, Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.7, 1.3)), _ground(bx, z) + Vector3(0, s * 0.2, 0), stone, Vector3(rng.randf(), rng.randf() * TAU, rng.randf()))

# --- scatter: grass, loose stone, dead trees ---------------------------------------------

static func _tuft_mesh() -> ArrayMesh:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var col := PackedColorArray()
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for b in 11:
		var a := rng.randf() * TAU; var lean := rng.randf_range(0.05, 0.3); var hgt := rng.randf_range(0.16, 0.38)
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.14)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.022
		var tip := base + Vector3(cos(a) * lean, hgt, sin(a) * lean)
		var shade := Color(rng.randf(), 0, 0)
		for p in [[base - side, 0.0], [base + side, 0.0], [tip, 1.0]]:
			v.append(p[0]); uv.append(Vector2(0.5, p[1])); col.append(shade)
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new(); mat.shader = load("res://shaders/grass.gdshader")
	m.surface_set_material(0, mat)
	return m

static func _multi(g: Node3D, mesh: Mesh, xfs: Array, shadows := false) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)

## A leafless tree: this close to the Blight nothing is in leaf.
static func dead_tree(g: Node3D, at: Vector3, rng: RandomNumberGenerator, hgt := 5.0) -> void:
	var bark := _mat(Color(0.12, 0.1, 0.085))
	var root := Node3D.new(); g.add_child(root); root.position = at; root.rotation.y = rng.randf() * TAU
	var limb := func(parent: Node3D, from: Vector3, dir: Vector3, len: float, r: float) -> Node3D:
		var mi := MeshInstance3D.new(); var c := CylinderMesh.new()
		c.top_radius = r * 0.45; c.bottom_radius = r; c.height = len; c.radial_segments = 6; c.rings = 1
		mi.mesh = c; mi.material_override = bark
		var n := Node3D.new(); parent.add_child(n); n.position = from
		n.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
		n.add_child(mi); mi.position.y = len * 0.5
		return n
	var trunk: Node3D = limb.call(root, Vector3.ZERO, Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.15, 0.15)), hgt, 0.3)
	for i in rng.randi_range(4, 7):
		var y := hgt * rng.randf_range(0.4, 0.98)
		var a := rng.randf() * TAU
		var d := Vector3(cos(a), rng.randf_range(0.3, 0.9), sin(a))
		var len := rng.randf_range(1.0, 2.4)
		var br: Node3D = limb.call(trunk, Vector3(0, y, 0), d, len, 0.09)
		for k in 2:
			var a2 := rng.randf() * TAU
			limb.call(br, Vector3(0, len * rng.randf_range(0.5, 0.95), 0), Vector3(cos(a2), 0.8, sin(a2)), len * 0.5, 0.04)

## Dress whatever map is loaded: grass where the ground is flat and off the road,
## stones everywhere, dead trees at the margins.
static func scatter(g: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 23
	var patch := FastNoiseLite.new(); patch.seed = 5; patch.frequency = 0.05
	var gap := not Map.m.is_empty()
	var grass: Array = []; var stones: Array = []
	for i in 60000:
		var x := rng.randf_range(-48.0, 48.0); var z := rng.randf_range(-100.0, 34.0) if gap else rng.randf_range(-70.0, 40.0)
		if gap and (absf(x) > Map.half_width(z) + 1.5 or absf(x) < 3.5):
			continue
		# Keep a clearing where the camp's character stands.
		if not gap and Vector2(x, z).length() < 3.0:
			continue
		if patch.get_noise_2d(x, z) < -0.05 or Terrain.normal(x, z).y < 0.9:
			continue
		var s := rng.randf_range(0.7, 1.5)
		grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.7, 1.3), s)), _ground(x, z)))
	_multi(g, _tuft_mesh(), grass)
	var stone := SphereMesh.new(); stone.radius = 0.5; stone.height = 0.8; stone.radial_segments = 7; stone.rings = 4
	stone.material = _mat(Color(0.23, 0.22, 0.2))
	for i in 900:
		var x := rng.randf_range(-48.0, 48.0); var z := rng.randf_range(-100.0, 34.0)
		if gap and absf(x) > Map.half_width(z) + 4.0:
			continue
		# Bigger stones gather at the foot of the cliffs; the road is kept clear.
		var edge := 0.0 if not gap else smoothstep(Map.half_width(z) - 6.0, Map.half_width(z), absf(x))
		if absf(x) < 4.0 and gap:
			continue
		var s := rng.randf_range(0.12, 0.4) + edge * rng.randf_range(0.2, 1.3)
		var b := Basis.from_euler(Vector3(rng.randf(), rng.randf() * TAU, rng.randf())).scaled(Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.7, 1.3)))
		stones.append(Transform3D(b, _ground(x, z) + Vector3(0, s * 0.12, 0)))
	_multi(g, stone, stones, true)
	# Trees stand where the map says, because the sim collides with them there.
	for t in Map.trees():
		dead_tree(g, _ground(t.x, t.z) - Vector3(0, 0.2, 0), rng, t.h)
