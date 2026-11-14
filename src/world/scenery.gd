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
