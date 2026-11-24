class_name Debris
extends RefCounted
## Loose stuff on the ground (twigs, pebbles, tufts of dead grass) that a blast or
## a weave of Air throws about: it flies, tumbles and settles again. Seen only:
## each machine scatters its own, so friends do not see the same twig land in the
## same place, and nothing in the fight depends on it.

static var _pieces: Array = []    # {mm, i, pos, rot, size, vel, spin, light}
static var _host: Node3D

## Scatter pieces over the part of the field that is fought over. Four multimeshes
## (dark sticks, pale sticks, pebbles, tufts), not three hundred nodes: each piece
## is an instance, moved only while it flies.
static func setup(host: Node3D, seed_: int, radius := 20.0, count := 300) -> void:
	_pieces.clear()
	_host = host
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var mats := [Color(0.2, 0.14, 0.08), Color(0.36, 0.3, 0.2), Color(0.22, 0.21, 0.2), Color(0.42, 0.36, 0.17)]
	var box := BoxMesh.new()
	var ball := SphereMesh.new(); ball.radius = 1.0; ball.height = 2.0; ball.radial_segments = 6; ball.rings = 3
	var made := []
	for i in count:
		var kind := rng.randi() % 4
		var size := Vector3.ONE
		match kind:
			0, 1: size = Vector3(0.035, 0.035, rng.randf_range(0.3, 0.7))
			2:
				var r := rng.randf_range(0.04, 0.08)
				size = Vector3(r, r * 0.7, r)
			_: size = Vector3(0.12, 0.01, 0.12)
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		made.append({kind = kind, pos = Vector3(p.x, Terrain.height(p.x, p.z) + 0.02, p.z), rot = Vector3(0, rng.randf() * TAU, 0), size = size})
	for kind in 4:
		var mine := made.filter(func(q: Dictionary) -> bool: return q.kind == kind)
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ball if kind == 2 else box
		mm.instance_count = mine.size()
		var mat := StandardMaterial3D.new(); mat.albedo_color = mats[kind]; mat.roughness = 1.0
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mmi)
		for i in mine.size():
			var q: Dictionary = mine[i]
			var pc := {mm = mm, i = i, pos = q.pos, rot = q.rot, size = q.size, vel = Vector3.ZERO, spin = Vector3.ZERO, light = kind == 3}
			_place(pc)
			_pieces.append(pc)

static func _place(p: Dictionary) -> void:
	(p.mm as MultiMesh).set_instance_transform(p.i, Transform3D(Basis.from_euler(p.rot) * Basis.from_scale(p.size), p.pos))

## A shove of air from `at`: what lies near is thrown outward and up.
static func push(at: Vector3, power := 1.0) -> void:
	var r := 3.5 + power * 2.5
	for p in _pieces:
		var d: Vector3 = (p.pos - at) * Vector3(1, 0, 1)
		var dist := d.length()
		if dist > r:
			continue
		var k := (1.0 - dist / r) * power * (1.6 if p.light else 1.0)
		var out := d.normalized() if dist > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		p.vel += out * (5.0 + 5.0 * randf()) * k + Vector3.UP * (2.0 + 3.0 * randf()) * k
		p.spin += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * k

## Flight, bounce and rest. Only what is moving costs anything.
static func step(dt: float) -> void:
	if _pieces.is_empty() or not is_instance_valid(_host):
		return
	for p in _pieces:
		var v: Vector3 = p.vel
		if v.length_squared() < 0.0004 and p.spin.length_squared() < 0.01:
			continue
		v.y -= (5.0 if p.light else 14.0) * dt
		# Light stuff rides the wind a little while it is up.
		if p.light:
			v += Wind.at(p.pos) * dt * 2.0
		var pos: Vector3 = p.pos + v * dt
		var floor_y := Terrain.height(pos.x, pos.z) + 0.02
		var rot: Vector3 = p.rot
		if pos.y <= floor_y:
			pos.y = floor_y
			v = Vector3(v.x * 0.55, -v.y * 0.25, v.z * 0.55)
			p.spin *= 0.6
			if absf(v.y) < 0.6:
				v.y = 0.0
				# Settled: lying flat-ish on the ground again.
				rot.x = lerpf(rot.x, 0.0, 0.5); rot.z = lerpf(rot.z, 0.0, 0.5)
		p.pos = pos
		p.rot = rot + p.spin * dt
		p.spin *= 1.0 - minf(dt * 1.5, 1.0)
		p.vel = v
		_place(p)
