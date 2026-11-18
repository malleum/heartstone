class_name Debris
extends RefCounted
## Loose stuff on the ground (twigs, pebbles, tufts of dead grass) that a blast or
## a weave of Air throws about: it flies, tumbles and settles again. Seen only:
## each machine scatters its own, so friends do not see the same twig land in the
## same place, and nothing in the fight depends on it.

static var _pieces: Array = []    # {node, vel, spin}
static var _host: Node3D

## Scatter pieces over the part of the field that is fought over.
static func setup(host: Node3D, seed_: int, radius := 20.0, count := 300) -> void:
	_pieces.clear()
	_host = host
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.2, 0.14, 0.08); wood.roughness = 1.0
	var pale := StandardMaterial3D.new(); pale.albedo_color = Color(0.36, 0.3, 0.2); pale.roughness = 1.0
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.22, 0.21, 0.2); stone.roughness = 1.0
	var tuft := StandardMaterial3D.new(); tuft.albedo_color = Color(0.42, 0.36, 0.17); tuft.roughness = 1.0
	for i in count:
		var mi := MeshInstance3D.new()
		var kind := rng.randi() % 4
		match kind:
			0, 1:
				var b := BoxMesh.new(); b.size = Vector3(0.035, 0.035, rng.randf_range(0.3, 0.7))
				mi.mesh = b; mi.material_override = wood if kind == 0 else pale
			2:
				var sm := SphereMesh.new(); sm.radius = rng.randf_range(0.04, 0.08); sm.height = sm.radius * 1.4
				sm.radial_segments = 6; sm.rings = 3
				mi.mesh = sm; mi.material_override = stone
			_:
				var q := BoxMesh.new(); q.size = Vector3(0.12, 0.01, 0.12)
				mi.mesh = q; mi.material_override = tuft
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mi)
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		mi.position = Vector3(p.x, Terrain.height(p.x, p.z) + 0.02, p.z)
		mi.rotation = Vector3(0, rng.randf() * TAU, 0)
		_pieces.append({node = mi, vel = Vector3.ZERO, spin = Vector3.ZERO, light = kind == 3})

## A shove of air from `at`: what lies near is thrown outward and up.
static func push(at: Vector3, power := 1.0) -> void:
	var r := 3.5 + power * 2.5
	for p in _pieces:
		var n: Node3D = p.node
		if not is_instance_valid(n):
			continue
		var d: Vector3 = (n.position - at) * Vector3(1, 0, 1)
		var dist := d.length()
		if dist > r:
			continue
		var k := (1.0 - dist / r) * power * (1.6 if p.light else 1.0)
		var out := d.normalized() if dist > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		p.vel += out * (5.0 + 5.0 * randf()) * k + Vector3.UP * (2.0 + 3.0 * randf()) * k
		p.spin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * k

## Flight, bounce and rest. Only what is moving costs anything.
static func step(dt: float) -> void:
	for p in _pieces:
		var v: Vector3 = p.vel
		if v.length_squared() < 0.0004 and p.spin.length_squared() < 0.01:
			continue
		var n: Node3D = p.node
		if not is_instance_valid(n):
			continue
		v.y -= (5.0 if p.light else 14.0) * dt
		# Light stuff rides the wind a little while it is up.
		if p.light:
			v += Wind.at(n.position) * dt * 2.0
		var pos := n.position + v * dt
		var floor_y := Terrain.height(pos.x, pos.z) + 0.02
		if pos.y <= floor_y:
			pos.y = floor_y
			v = Vector3(v.x * 0.55, -v.y * 0.25, v.z * 0.55)
			p.spin *= 0.6
			if absf(v.y) < 0.6:
				v.y = 0.0
				# Settled: lying flat-ish on the ground again.
				n.rotation.x = lerpf(n.rotation.x, 0.0, 0.5); n.rotation.z = lerpf(n.rotation.z, 0.0, 0.5)
		n.position = pos
		n.rotation += p.spin * dt
		p.spin *= 1.0 - minf(dt * 1.5, 1.0)
		p.vel = v
