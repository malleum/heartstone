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

## A torch on a pole driven into the ground.
static func torch(g: Node3D, at: Vector3) -> void:
	_box(g, Vector3(0.07, 2.2, 0.07), at + Vector3(0, 1.1, 0), _mat(Color(0.14, 0.1, 0.06)), Vector3(0.05, 0, 0.04))
	var f := Weavefx._particles(Color(1.0, 0.5, 0.15), 18, 0.5, 0.18, 0.2, 1.4, 12.0)
	g.add_child(f); f.position = at + Vector3(0, 2.25, 0)
	var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.58, 0.28); l.light_energy = 2.4; l.omni_range = 10.0
	g.add_child(l); l.position = at + Vector3(0, 2.4, 0)

## A standing stone doorway for the camp: two posts, a lintel, and a surface of
## folding light in the colour of where it leads (dark when it may not be passed).
## The node faces +z; the caller turns it toward the camp.
## scene: what shows through it (1 a mountain pass, 2 a ring of wagons, 3 a yard
## of posts, 4 stars).
static func doorway(g: Node3D, at: Vector3, yaw: float, tint: Color, lit: bool, title: String, sub: String, scene := 0) -> Node3D:
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
	sm.set_shader_parameter("scene", scene)
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

# --- props ---------------------------------------------------------------------------

static func _cyl(parent: Node3D, r0: float, r1: float, h: float, at: Vector3, mat: Material, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.bottom_radius = r0; c.top_radius = r1; c.height = h; c.radial_segments = seg; c.rings = 1
	var mi := MeshInstance3D.new(); mi.mesh = c; mi.material_override = mat; mi.position = at; mi.rotation = rot
	parent.add_child(mi)
	return mi

## A cask: staves bulging at the middle, two iron hoops.
static func barrel(g: Node3D, at: Vector3, rng: RandomNumberGenerator, lying := false) -> void:
	var n := Node3D.new(); g.add_child(n); n.position = at; n.rotation.y = rng.randf() * TAU
	var k := rng.randf_range(0.85, 1.1)
	var wood := _mat(Color(0.3, 0.2, 0.11) * rng.randf_range(0.8, 1.1)); var iron := _mat(Color(0.09, 0.09, 0.1), 0.6)
	var b := Node3D.new(); n.add_child(b)
	if lying:
		b.rotation.z = PI * 0.5; b.position.y = 0.33 * k
	_cyl(b, 0.27 * k, 0.33 * k, 0.42 * k, Vector3(0, 0.21 * k, 0), wood)
	_cyl(b, 0.33 * k, 0.27 * k, 0.42 * k, Vector3(0, 0.63 * k, 0), wood)
	_cyl(b, 0.25 * k, 0.25 * k, 0.02, Vector3(0, 0.83 * k, 0), _mat(Color(0.2, 0.13, 0.07)))
	for y in [0.2, 0.64]:
		_cyl(b, 0.325 * k, 0.325 * k, 0.05, Vector3(0, y * k, 0), iron)

## A packing crate: boards with a frame of battens and one across each face.
static func crate(g: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var n := Node3D.new(); g.add_child(n); n.position = at; n.rotation.y = rng.randf() * TAU
	var w := rng.randf_range(0.6, 0.95); var h := rng.randf_range(0.5, 0.75); var d := rng.randf_range(0.55, 0.8)
	var board := _mat(Color(0.42, 0.31, 0.19) * rng.randf_range(0.8, 1.1)); var batten := _mat(Color(0.24, 0.17, 0.1))
	_box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), board)
	var t := 0.06
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(n, Vector3(t, h + 0.02, t), Vector3(sx * (w - t) * 0.5, h * 0.5, sz * (d - t) * 0.5) * Vector3(1.03, 1, 1.03), batten)
	for sy in [0.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(n, Vector3(w + 0.03, t, t), Vector3(0, sy * (h - t) + t * 0.5, sz * (d - t) * 0.515), batten)
		for sx in [-1.0, 1.0]:
			_box(n, Vector3(t, t, d + 0.03), Vector3(sx * (w - t) * 0.515, sy * (h - t) + t * 0.5, 0), batten)
	for sz in [-1.0, 1.0]:
		_box(n, Vector3(t, sqrt(w * w + h * h) - 0.1, 0.03), Vector3(0, h * 0.5, sz * d * 0.51), batten, Vector3(0, 0, atan2(w, h)))

## Sacks of grain slumped on one another.
static func sacks(g: Node3D, at: Vector3, rng: RandomNumberGenerator, count := 3) -> void:
	var cloth := _mat(Color(0.52, 0.45, 0.32) * rng.randf_range(0.85, 1.05), 1.0)
	for i in count:
		var s := SphereMesh.new(); s.radius = 0.5; s.height = 1.0; s.radial_segments = 10; s.rings = 6
		var mi := MeshInstance3D.new(); mi.mesh = s; mi.material_override = cloth
		var top := i == count - 1 and count > 2
		mi.position = at + (Vector3(0, 0.42, 0) if top else Vector3((i - (count - 2) * 0.5) * 0.62, 0.17, rng.randf_range(-0.1, 0.1)))
		mi.scale = Vector3(rng.randf_range(0.75, 0.9), 0.36, rng.randf_range(0.5, 0.6))
		mi.rotation = Vector3(0, rng.randf_range(-0.5, 0.5), rng.randf_range(-0.12, 0.12))
		g.add_child(mi)

## A bale of hay.
static func bale(g: Node3D, at: Vector3, yaw: float) -> void:
	var n := Node3D.new(); g.add_child(n); n.position = at; n.rotation.y = yaw
	_box(n, Vector3(1.1, 0.5, 0.6), Vector3(0, 0.25, 0), _mat(Color(0.62, 0.5, 0.22), 1.0))
	for sx in [-0.3, 0.3]:
		_box(n, Vector3(0.03, 0.52, 0.62), Vector3(sx, 0.25, 0), _mat(Color(0.3, 0.22, 0.1)))

## A practice post: a man-high pell, hacked about, bound in rope where blows
## land, a crossbar for arms and a straw-stuffed sack for a head.
static func practice_post(seed: int) -> Node3D:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var n := Node3D.new()
	var wood := _mat(Color(0.3, 0.21, 0.13) * rng.randf_range(0.85, 1.1)); var rope := _mat(Color(0.55, 0.47, 0.3), 1.0)
	_cyl(n, 0.13, 0.11, 1.9, Vector3(0, 0.95, 0), wood, Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03)), 8)
	_cyl(n, 0.2, 0.15, 0.25, Vector3(0, 0.12, 0), _mat(Color(0.2, 0.19, 0.18)), Vector3.ZERO, 7)
	_cyl(n, 0.145, 0.14, 0.5, Vector3(0, 1.2, 0), rope, Vector3.ZERO, 10)
	_cyl(n, 0.05, 0.045, 1.2, Vector3(0, 1.5, 0), wood, Vector3(0, rng.randf_range(-0.3, 0.3), PI * 0.5 + rng.randf_range(-0.08, 0.08)), 6)
	var s := SphereMesh.new(); s.radius = 0.17; s.height = 0.4; s.radial_segments = 10; s.rings = 6
	var head := MeshInstance3D.new(); head.mesh = s; head.material_override = _mat(Color(0.5, 0.43, 0.3), 1.0); head.position = Vector3(0, 2.02, 0)
	n.add_child(head)
	_cyl(n, 0.1, 0.12, 0.05, Vector3(0, 1.84, 0), rope, Vector3.ZERO, 8)
	return n

## The training yard: a rail fence round the ground, with what a yard has at its
## edges. Nothing here is solid, so it is all kept out of the way of the fighting.
static func yard(g: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 19
	var wood := _mat(Color(0.27, 0.19, 0.11))
	var c := Vector3(0, 0, -6.0); var r := 21.0; var n := 30
	for i in n:
		var a0 := i * TAU / n; var a1 := (i + 1) * TAU / n
		var p0 := _ground(c.x + sin(a0) * r, c.z + cos(a0) * r); var p1 := _ground(c.x + sin(a1) * r, c.z + cos(a1) * r)
		_box(g, Vector3(0.11, 1.25, 0.11), p0 + Vector3(0, 0.55, 0), wood, Vector3(rng.randf_range(-0.05, 0.05), a0, rng.randf_range(-0.05, 0.05)))
		if i == 0 or i == n - 1:
			continue   # the gate, behind where you come in
		var mid := (p0 + p1) * 0.5; var d := p1 - p0
		for y in [0.45, 0.9]:
			var rail := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(0.07, 0.09, d.length() + 0.15)
			rail.mesh = b; rail.material_override = wood; g.add_child(rail)
			rail.look_at_from_position(mid + Vector3(0, y + rng.randf_range(-0.03, 0.03), 0), p1 + Vector3(0, y, 0), Vector3.UP)
	# Archery butts on the far side.
	for i in 3:
		var a := PI + (i - 1) * 0.16
		var p := _ground(c.x + sin(a) * (r - 2.0), c.z + cos(a) * (r - 2.0))
		var t := Node3D.new(); g.add_child(t); t.position = p; t.rotation.y = a + PI
		_cyl(t, 0.62, 0.62, 0.28, Vector3(0, 1.05, 0), _mat(Color(0.66, 0.56, 0.3), 1.0), Vector3(PI * 0.5 - 0.15, 0, 0), 18)
		_cyl(t, 0.4, 0.4, 0.29, Vector3(0, 1.05, 0), _mat(Color(0.75, 0.72, 0.62), 1.0), Vector3(PI * 0.5 - 0.15, 0, 0), 18)
		_cyl(t, 0.14, 0.14, 0.3, Vector3(0, 1.05, 0), _mat(Color(0.5, 0.1, 0.08)), Vector3(PI * 0.5 - 0.15, 0, 0), 12)
		for sx in [-0.4, 0.4]:
			_box(t, Vector3(0.07, 1.7, 0.07), Vector3(sx, 0.8, -0.3), wood, Vector3(-0.3, 0, 0))
		_box(t, Vector3(0.07, 1.7, 0.07), Vector3(0, 0.75, -0.75), wood, Vector3(0.45, 0, 0))
	# A weapon rack, bales, a water butt and a bench along the sides.
	for side: float in [-1.0, 1.0]:
		var a: float = side * 1.35
		var p := _ground(c.x + sin(a) * (r - 1.5), c.z + cos(a) * (r - 1.5))
		var rack := Node3D.new(); g.add_child(rack); rack.position = p; rack.rotation.y = a + PI
		for sx in [-0.9, 0.9]:
			_box(rack, Vector3(0.09, 1.5, 0.09), Vector3(sx, 0.75, 0), wood)
		for y in [0.5, 1.35]:
			_box(rack, Vector3(1.9, 0.07, 0.07), Vector3(0, y, 0), wood)
		for k in 6:
			var x := -0.7 + k * 0.28
			_cyl(rack, 0.02, 0.02, 1.6 + (k % 3) * 0.25, Vector3(x, 0.85 + (k % 3) * 0.12, 0.12), _mat(Color(0.36, 0.27, 0.16)), Vector3(-0.1, 0, 0), 5)
			if k % 2 == 0:
				_box(rack, Vector3(0.05, 0.3, 0.015), Vector3(x, 1.78 + (k % 3) * 0.24, 0.04), _mat(Color(0.45, 0.46, 0.5), 0.4), Vector3(-0.1, 0, 0))
		for k in 3:
			var a2: float = a + side * (0.2 + (k if k < 2 else 0.5) * 0.085)
			bale(g, _ground(c.x + sin(a2) * (r - 1.2), c.z + cos(a2) * (r - 1.2)) + Vector3(0, 0.5 if k == 2 else 0.0, 0), a2 + PI * 0.5)
		barrel(g, _ground(c.x + sin(a - side * 0.14) * (r - 1.2), c.z + cos(a - side * 0.14) * (r - 1.2)), rng)
		var bp := _ground(c.x + sin(a - side * 0.3) * (r - 1.4), c.z + cos(a - side * 0.3) * (r - 1.4))
		var bench := Node3D.new(); g.add_child(bench); bench.position = bp; bench.rotation.y = a - side * 0.3 + PI
		_box(bench, Vector3(1.8, 0.07, 0.32), Vector3(0, 0.45, 0), wood)
		for sx in [-0.75, 0.75]:
			_box(bench, Vector3(0.08, 0.45, 0.28), Vector3(sx, 0.22, 0), wood)

## The caravan's ground: a fire in the middle of the ring and a few bales and casks.
static func wagon_ring(g: Node3D) -> void:
	walls(g)
	fire(g, _ground(0.0, 0.0) + Vector3(2.5, 0, 2.0))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 12:
		var a := rng.randf() * TAU
		var p := _ground(sin(a) * rng.randf_range(3.5, 6.5), cos(a) * rng.randf_range(3.5, 6.5))
		match i % 3:
			0: crate(g, p, rng)
			1: barrel(g, p, rng, i % 2 == 0)
			2: sacks(g, p, rng, 2 + i % 2)

static func tarwins_gap(g: Node3D, night := false) -> void:
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
	if night:
		# Watch fires thrown well out up the pass, to see what comes by, and
		# torches along the line.
		for k in 3:
			for sx in [-w * 0.6, w * 0.6]:
				fire(g, _ground(sx * (1.0 - k * 0.1), z0 - 16.0 - k * 17.0))
		for sx in [-w * 0.9, -w * 0.3, w * 0.3, w * 0.9]:
			torch(g, _ground(sx, z0 + 1.5))
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
