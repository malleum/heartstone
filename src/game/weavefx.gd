class_name Weavefx
extends RefCounted
## Weave visuals: glowing primitives, lights and short tweens. First pass only;
## this is where the game's feel will be won, so expect it to be rebuilt richer.

const TINT := {fire = Color(1.0, 0.42, 0.1), earth = Color(0.75, 0.5, 0.2), air = Color(0.7, 0.85, 1.0), water = Color(0.25, 0.5, 1.0), spirit = Color(0.95, 0.95, 1.0)}

static func colour(weave: String) -> Color:
	var fl: Dictionary = Rules.weaves[weave].flows
	var c := Color(0, 0, 0); var n := 0.0
	for e in fl:
		c += TINT[e] * float(fl[e]); n += fl[e]
	return c / n

static func _glow(col: Color, energy := 5.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, minf(col.a, 0.85))   # callers pass a lower alpha for halos
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = col; m.emission_energy_multiplier = energy
	return m

static func _mesh(mesh: Mesh, col: Color, energy := 5.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = _glow(col, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _light(col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col; l.light_energy = energy; l.omni_range = reach
	return l

static var _dot: GradientTexture2D

## Soft round sprite shared by every particle system.
static func _sprite() -> GradientTexture2D:
	if _dot == null:
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1)); gr.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = gr; _dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5); _dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64; _dot.height = 64
	return _dot

## Additive billboard particles fading from a white-hot core colour to nothing.
## `speed` in m/s, `gravity` negative pulls sparks down, positive lets smoke rise.
static func _particles(col: Color, amount: int, life: float, size: float, speed: float, gravity: float, spread := 180.0, additive := true) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.6
	pm.direction = Vector3.UP; pm.spread = spread
	pm.initial_velocity_min = speed * 0.35; pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = speed * 0.4; pm.damping_max = speed * 0.8
	pm.scale_min = 0.5; pm.scale_max = 1.3
	var ramp := Gradient.new()
	if additive:
		ramp.set_color(0, col.lerp(Color.WHITE, 0.35)); ramp.set_color(1, Color(col.r * 0.6, col.g * 0.25, col.b * 0.25, 0.0))
		ramp.add_point(0.35, col)
	else:
		# Dust and dirt: opaque-ish, no glow.
		ramp.set_color(0, Color(col.r, col.g, col.b, 0.9)); ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var rt := GradientTexture1D.new(); rt.gradient = ramp
	pm.color_ramp = rt
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.6)); sc.add_point(Vector2(0.2, 1.0)); sc.add_point(Vector2(1, 0.15))
	var st := CurveTexture.new(); st.curve = sc
	pm.scale_curve = st
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _sprite()
	mat.albedo_color = Color(1.25, 1.25, 1.25) if additive else Color.WHITE   # over 1 so the glow pass picks it up
	var q := QuadMesh.new(); q.size = Vector2(size, size); q.material = mat
	var p := GPUParticles3D.new()
	p.process_material = pm; p.draw_pass_1 = q
	p.amount = amount; p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static func _once(p: GPUParticles3D, g: Node3D, at: Vector3) -> void:
	p.one_shot = true; p.explosiveness = 0.92
	g.add_child(p); p.position = at; p.emitting = true
	g.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## A persistent effect the sim is tracking (projectile, gate, ring, pending blast).
static func live(g: Node3D, kind: String, weave := "") -> Node3D:
	var n := Node3D.new()
	g.add_child(n)
	match kind:
		"projectile":
			var s := SphereMesh.new(); s.radius = 0.28; s.height = 0.56
			var col: Color = colour(weave) if weave != "" else TINT.fire
			n.add_child(_mesh(s, col.lerp(Color.WHITE, 0.35), 5.0)); n.add_child(_light(col, 4.0, 9.0))
			# Flames stay in world space, so a moving ball drags a tail behind it.
			var trail := _particles(col, 70, 0.4, 0.34, 0.9, 1.2)
			n.add_child(trail)
		"mover":
			var b := BoxMesh.new(); b.size = Vector3(2.4, 3.2, 0.08)
			n.add_child(_mesh(b, Color(0.05, 0.02, 0.08), 0.0)); n.add_child(_light(TINT.spirit, 2.5, 8.0))
			var rimm := BoxMesh.new(); rimm.size = Vector3(2.6, 3.4, 0.04)
			n.add_child(_mesh(rimm, TINT.spirit, 5.0))
		"ring":
			var t := TorusMesh.new(); t.inner_radius = 0.93; t.outer_radius = 1.0
			n.add_child(_mesh(t, TINT.fire, 6.0))
			# A wall of flame standing on the ring; it scales outward with the node.
			var f := _particles(TINT.fire, 260, 0.6, 0.12, 0.25, 0.6, 25.0)
			var pm: ParticleProcessMaterial = f.process_material
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = Vector3.UP; pm.emission_ring_radius = 1.0; pm.emission_ring_inner_radius = 0.97; pm.emission_ring_height = 0.05
			f.local_coords = true
			n.add_child(f)
		"blast":
			var c := CylinderMesh.new(); c.top_radius = 0.9; c.bottom_radius = 0.9; c.height = 0.05
			var mi := _mesh(c, TINT.fire, 2.0); mi.position.y = -1.1
			n.add_child(mi)
	return n

## The flows themselves, seen while a weave forms: one bright thread for each flow,
## in its Power's colour, circling in front of the weaver and drawing together as
## the weave completes. Bigger weaves show more threads and take longer to close.
static func forming(g: Node3D, who: Node3D, weave: String, secs: float) -> void:
	var hub := Node3D.new()
	who.add_child(hub); hub.position = Vector3(0, 1.25, 0.1)
	var threads: Array[Node3D] = []
	var fl: Dictionary = Rules.weaves[weave].flows
	for e in fl:
		for i in int(fl[e]):
			var n := Node3D.new(); hub.add_child(n)
			var sp := SphereMesh.new(); sp.radius = 0.06; sp.height = 0.12
			n.add_child(_mesh(sp, TINT[e].lerp(Color.WHITE, 0.3), 7.0))
			# World-space particles, so each thread leaves a streak of its colour.
			n.add_child(_particles(TINT[e], 60, 0.45, 0.15, 0.05, 0.0))
			threads.append(n)
	hub.add_child(_light(colour(weave), 1.2, 4.0))
	var count := threads.size()
	var tw := g.create_tween()
	tw.tween_method(func(f: float) -> void:
		if not is_instance_valid(hub):
			return
		for i in count:
			var ang := f * TAU * 2.0 + i * TAU / count
			# They circle the weaver wide enough to be seen from behind, then close
			# on the hands, where the weave leaves.
			var r := 0.8 * (1.0 - f * f) + 0.04
			threads[i].position = Vector3(cos(ang) * r, sin(ang * 1.5 + i) * r * 0.45 + 0.15 * f, sin(ang) * r + 0.4 * f), 0.0, 1.0, maxf(secs, 0.15))
	tw.tween_callback(func() -> void:
		if is_instance_valid(hub):
			hub.queue_free())

static var _white: StandardMaterial3D

## The instant of impact: the struck body flashes white for a few frames.
static func flash(g: Node3D, who: Node3D, secs := 0.09) -> void:
	if _white == null:
		_white = StandardMaterial3D.new()
		_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_white.albedo_color = Color(1.0, 0.95, 0.85, 0.75)
		_white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var meshes := who.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		(m as MeshInstance3D).material_overlay = _white
	g.get_tree().create_timer(secs).timeout.connect(func() -> void:
		for m in meshes:
			if is_instance_valid(m):
				(m as MeshInstance3D).material_overlay = null)

## What clings to someone a weave has marked: flames on the burning, sparks on the
## stunned. The caller frees it when the status ends.
static func status(kind: String) -> Node3D:
	var p: GPUParticles3D
	if kind == "burn":
		p = _particles(TINT.fire, 40, 0.6, 0.3, 0.6, 2.2, 60.0)
		p.add_child(_light(TINT.fire, 2.0, 5.0))
	else:
		p = _particles(Color(0.75, 0.85, 1.0), 14, 0.35, 0.12, 2.5, 0.0)
	p.position.y = 1.2
	return p

static func blast(g: Node3D, at: Vector3, radius: float, weave: String) -> void:
	var col := colour(weave)
	var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0
	var mi := _mesh(s, col, 2.5)
	mi.position = at + Vector3(0, 0.4, 0); mi.scale = Vector3.ONE * 0.3
	g.add_child(mi)
	var l := _light(col, 9.0, radius * 4.0)
	mi.add_child(l)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.4)
	tw.tween_property(l, "light_energy", 0.0, 0.4)
	tw.chain().tween_callback(mi.queue_free)
	# Shockwave hugging the ground, sparks thrown out, and fire rolling upward: three
	# layers at three speeds read as an explosion; one sphere reads as a balloon.
	var ring := TorusMesh.new(); ring.inner_radius = 0.82; ring.outer_radius = 1.0
	var ri := _mesh(ring, col.lerp(Color.WHITE, 0.4), 6.0)
	ri.position = at + Vector3(0, 0.15, 0); ri.scale = Vector3(0.4, 0.25, 0.4)
	g.add_child(ri)
	var tr := g.create_tween().set_parallel()
	tr.tween_property(ri, "scale", Vector3(radius * 1.7, 0.1, radius * 1.7), 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tr.tween_property(ri.material_override, "albedo_color:a", 0.0, 0.38)
	tr.chain().tween_callback(ri.queue_free)
	_once(_particles(col, int(40 + radius * 30), 0.9, 0.16, 5.0 + radius * 3.0, -9.0, 80.0), g, at + Vector3(0, 0.3, 0))
	_once(_particles(col, int(10 + radius * 6), 0.7, 0.8 + radius * 0.3, 1.5 + radius, 2.5), g, at + Vector3(0, 0.5, 0))
	if g.has_method("shake_at"):
		g.shake_at(at, radius)
	Sfx.play(g, "boom", at, -4.0 + radius * 2.0, clampf(1.5 - radius * 0.2, 0.6, 1.4))

static func _fade(g: Node3D, mi: MeshInstance3D, secs: float) -> void:
	var tw := g.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, secs)
	tw.tween_callback(mi.queue_free)

## A thin glowing bar from a to b.
static func _bar(g: Node3D, a: Vector3, b: Vector3, thick: float, col: Color, energy: float) -> MeshInstance3D:
	var m := CylinderMesh.new(); m.top_radius = thick * 0.5; m.bottom_radius = thick * 0.5
	m.height = a.distance_to(b); m.radial_segments = 8; m.rings = 1
	var mi := _mesh(m, col, energy)
	g.add_child(mi)
	mi.position = (a + b) * 0.5
	if not a.is_equal_approx(b):
		# Cylinders run along Y, looking_at aims -Z: tip it over.
		mi.basis = Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	return mi

## Forked lightning: a jittered path from the clouds, one branch, a flash, a crack.
static func _bolt(g: Node3D, at: Vector3, col: Color) -> void:
	var top := at + Vector3(randf_range(-8, 8), 55.0, randf_range(-8, 8))
	var prev := top
	for i in range(1, 15):
		var f := i / 14.0
		var p := top.lerp(at, f) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 2.2 * sin(f * PI)
		_fade(g, _bar(g, prev, p, 0.22, Color(0.92, 0.95, 1.0), 16.0), 0.32)
		if i == 6:
			_fade(g, _bar(g, p, p + Vector3(randf_range(-9, 9), -14.0, randf_range(-9, 9)), 0.1, col, 10.0), 0.22)
		prev = p
	var l := _light(Color(0.8, 0.88, 1.0), 16.0, 40.0)
	g.add_child(l); l.position = at + Vector3(0, 3, 0)
	var tw := g.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35)
	tw.tween_callback(l.queue_free)
	_once(_particles(col, 50, 0.6, 0.14, 9.0, -12.0, 85.0), g, at + Vector3(0, 0.3, 0))
	Sfx.play(g, "crack", at, 4.0)
	if g.has_method("shake_at"):
		g.shake_at(at, 3.0)

## Instant weaves that the sim resolves in one tick.
static func cast(g: Node3D, e: Dictionary) -> void:
	var col := colour(e.weave)
	var feet: Vector3 = g._ground(e.pos)
	var from := feet + Vector3(0, 1.4, 0)
	var b: Dictionary = Rules.weaves[e.weave].base
	Sfx.play(g, "whoosh", from, -6.0)
	match e.kind:
		"beam":
			# Balefire: a white-hot bar with a wider halo that lingers as an afterimage.
			var to: Vector3 = from + e.dir * b.range
			_fade(g, _bar(g, from, to, b.width * 0.45, Color(1, 1, 1), 18.0), 0.9)
			_fade(g, _bar(g, from, to, b.width * 1.1, Color(1.0, 0.95, 0.8, 0.22), 2.0), 0.5)
			var l := _light(Color(1, 0.97, 0.9), 14.0, 30.0)
			g.add_child(l); l.position = from + e.dir * 6.0
			var tw := g.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.6); tw.tween_callback(l.queue_free)
			Sfx.play(g, "crack", from, 2.0, 0.6)
			if g.has_method("shake_at"): g.shake_at(from, 2.5)
		"line":
			# Riven Earth: the ground bursts along the line, nearest first.
			var steps := int(b.range / 1.5)
			for i in steps:
				var p: Vector3 = g._ground(feet + e.dir * (2.0 + i * 1.5))
				g.get_tree().create_timer(i * 0.03).timeout.connect(func() -> void:
					_once(_particles(Color(0.24, 0.17, 0.1), 22, 0.9, 0.3, 8.0, -16.0, 30.0, false), g, p)
					_once(_particles(Color(0.5, 0.42, 0.33), 5, 1.0, 0.6, 1.2, 0.6, 80.0, false), g, p + Vector3(0, 0.3, 0)))
			Sfx.play(g, "rumble", feet + e.dir * b.range * 0.5, 4.0)
			if g.has_method("shake_at"): g.shake_at(feet + e.dir * 4.0, 2.0)
		"strike":
			_bolt(g, g._ground(e.at), col)
		"cone":
			# Hammer of Air: a pressure ring thrown forward, widening as it goes.
			var ring := TorusMesh.new(); ring.inner_radius = 0.85; ring.outer_radius = 1.0
			var mi := _mesh(ring, Color(col.lerp(Color.WHITE, 0.35), 0.5), 2.5)
			g.add_child(mi)
			mi.position = from + e.dir * 0.8
			mi.basis = Basis.looking_at(e.dir, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			mi.scale = Vector3.ONE * 0.4
			var tw := g.create_tween().set_parallel()
			tw.tween_property(mi, "position", from + e.dir * b.range, 0.28)
			tw.tween_property(mi, "scale", Vector3.ONE * b.range * 0.45, 0.28)
			tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3)
			tw.chain().tween_callback(mi.queue_free)
			# Water goes out as spray; Air only lifts the dust.
			var wet: bool = Rules.weaves[e.weave].flows.has("water")
			_once(_particles(TINT.water.lerp(Color.WHITE, 0.3) if wet else Color(0.6, 0.56, 0.5), 70 if wet else 24, 0.7, 0.35 if wet else 0.9, 9.0 if wet else 6.0, -6.0 if wet else 0.5, 30.0, wet), g, feet + e.dir * 2.0 + Vector3(0, 0.6, 0))
			Sfx.play(g, "thud", from, 4.0, 0.7)
		"barrier":
			var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0
			var mi := _mesh(s, Color(0.7, 0.85, 1.0, 0.1), 0.5)
			g.add_child(mi); mi.position = feet + Vector3(0, 1.0, 0); mi.scale = Vector3.ONE * 0.5
			var tw := g.create_tween().set_parallel()
			tw.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 1.1)
			tw.chain().tween_callback(mi.queue_free)
			Sfx.play(g, "chime", from, -2.0, 0.8)
		"heal":
			_once(_particles(Color(0.5, 1.0, 0.7), 40, 1.2, 0.14, 1.2, 1.6, 40.0), g, g._ground(e.at) + Vector3(0, 0.4, 0))
			Sfx.play(g, "chime", from, -2.0)
		"sever":
			_fade(g, _bar(g, from, g._ground(e.at) + Vector3(0, 1.4, 0), 0.06, TINT.spirit, 6.0), 0.5)
			Sfx.play(g, "chime", from, -4.0, 0.6)
