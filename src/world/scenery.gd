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

## A standing stone doorway for the camp: two posts, a lintel, and a surface of
## folding light in the colour of where it leads (dark when it may not be passed).
## The node faces +z; the caller turns it toward the camp.
static func doorway(g: Node3D, at: Vector3, yaw: float, tint: Color, lit: bool, title: String, sub: String) -> Node3D:
	var n := Node3D.new(); g.add_child(n)
	n.position = at; n.rotation.y = yaw
	var stone := _mat(Color(0.2, 0.2, 0.21))
	for sx in [-1.0, 1.0]:
		_box(n, Vector3(0.55, 3.5, 0.6), Vector3(sx * 1.2, 1.6, 0), stone, Vector3(0, 0, sx * -0.03))
		_box(n, Vector3(0.75, 0.3, 0.8), Vector3(sx * 1.2, 0.05, 0), stone)
	_box(n, Vector3(3.5, 0.5, 0.75), Vector3(0, 3.5, 0), stone, Vector3(0, 0, 0.02))
	_box(n, Vector3(1.0, 0.3, 0.8), Vector3(0, 3.85, 0), stone)
	var q := QuadMesh.new(); q.size = Vector2(1.9, 3.3)
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.position = Vector3(0, 1.65, 0)
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/portal.gdshader")
	sm.set_shader_parameter("tint", tint); sm.set_shader_parameter("lit", 1.0 if lit else 0.0)
	mi.material_override = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	if lit:
		var l := OmniLight3D.new(); l.light_color = tint; l.light_energy = 2.5; l.omni_range = 9.0
		n.add_child(l); l.position = Vector3(0, 1.8, 1.2)
		var motes := Weavefx._particles(tint, 26, 1.6, 0.1, 0.5, 0.5, 180.0)
		n.add_child(motes); motes.position = Vector3(0, 1.6, 0.2)
		(motes.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		(motes.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(0.9, 1.5, 0.1)
	# The name is cut on two lines above the lintel so neighbouring doorways do
	# not run into each other; `sub` (why it is closed) sits small beneath it.
	var t := Label3D.new(); t.text = title.replace(": ", "\n") + ("\n" + sub if sub != "" else ""); t.font = Glyph.serif()
	t.font_size = 72; t.pixel_size = 0.0075; t.outline_size = 14; t.line_spacing = -8.0
	t.modulate = Color(0.97, 0.94, 0.88) if lit else Color(0.6, 0.6, 0.66)
	t.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	t.position = Vector3(0, 4.15, 0.1)
	t.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	n.add_child(t)
	return n

## Build every wall the map says is there (Map.walls), each by its look, so that
## what is drawn is exactly what the sim blocks on.
static func walls(g: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var wood := _mat(Color(0.2, 0.14, 0.09))
	var dark := _mat(Color(0.1, 0.08, 0.06))
	for w in Map.walls():
		if w.look == "stone":
			# Courses of rough stones, each a little shorter than the one below.
			var courses := int(round(w.h / 0.32))
			for course in courses:
				var sx: float = w.x - w.hx + course * 0.2
				while sx < w.x + w.hx - course * 0.2:
					var sw := rng.randf_range(0.45, 0.85)
					var p := _ground(sx + sw * 0.5, w.z)
					var shade := rng.randf_range(0.8, 1.15)
					_box(g, Vector3(sw, 0.34, rng.randf_range(0.55, 0.76)), p + Vector3(0, 0.15 + course * 0.31, rng.randf_range(-0.05, 0.05)),
						_mat(Color(0.2, 0.19, 0.18) * shade), Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.05, 0.05)))
					sx += sw + 0.03
		elif w.look == "wagon":
			# A merchant's wagon, end-on to its neighbours: bed, tilt, four wheels.
			var n := Node3D.new(); g.add_child(n)
			n.position = _ground(w.x, w.z); n.rotation.y = w.yaw + PI * 0.5
			_box(n, Vector3(1.5, 0.75, 4.2), Vector3(0, 1.05, 0), wood)
			_box(n, Vector3(1.4, 0.12, 4.0), Vector3(0, 0.66, 0), dark)
			var tilt := _mat(Color(0.62, 0.58, 0.5) * rng.randf_range(0.8, 1.05), 1.0)
			for k in 5:
				var a := lerpf(-1.1, 1.1, k / 4.0)
				_box(n, Vector3(0.52, 0.05, 4.0), Vector3(sin(a) * 0.72, 1.45 + cos(a) * 0.62, 0), tilt, Vector3(0, 0, -a))
			for wx in [-0.85, 0.85]:
				for wz in [-1.4, 1.4]:
					var wheel := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.6; c.bottom_radius = 0.6; c.height = 0.1
					wheel.mesh = c; wheel.material_override = dark; wheel.position = Vector3(wx, 0.6, wz); wheel.rotation.z = PI * 0.5
					n.add_child(wheel)
			_box(n, Vector3(0.08, 0.08, 2.4), Vector3(0, 0.7, 3.2), wood, Vector3(0.18, 0, 0))

## The caravan's ground: a fire in the middle of the ring and a few bales and casks.
static func wagon_ring(g: Node3D) -> void:
	walls(g)
	fire(g, _ground(0.0, 0.0) + Vector3(2.5, 0, 2.0))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var sack := _mat(Color(0.5, 0.42, 0.3)); var cask := _mat(Color(0.25, 0.16, 0.09))
	for i in 10:
		var a := rng.randf() * TAU
		var p := _ground(sin(a) * rng.randf_range(3.5, 6.5), cos(a) * rng.randf_range(3.5, 6.5))
		if i % 2 == 0:
			_box(g, Vector3(0.9, 0.5, 0.6), p + Vector3(0, 0.25, 0), sack, Vector3(0, rng.randf() * TAU, 0))
		else:
			var b := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.3; c.bottom_radius = 0.3; c.height = 0.8
			b.mesh = c; b.material_override = cask; b.position = p + Vector3(0, 0.4, 0); g.add_child(b)

static func tarwins_gap(g: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var stone := _mat(Color(0.2, 0.19, 0.18))
	var wood := _mat(Color(0.16, 0.11, 0.07))
	var z0 := Map.line_z()
	var w := Map.half_width(z0)
	walls(g)
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
