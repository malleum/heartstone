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
	m.albedo_color = Color(col.r, col.g, col.b, 0.85)
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
static func _particles(col: Color, amount: int, life: float, size: float, speed: float, gravity: float, spread := 180.0) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.6
	pm.direction = Vector3.UP; pm.spread = spread
	pm.initial_velocity_min = speed * 0.35; pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = speed * 0.4; pm.damping_max = speed * 0.8
	pm.scale_min = 0.5; pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, col.lerp(Color.WHITE, 0.35)); ramp.set_color(1, Color(col.r * 0.6, col.g * 0.25, col.b * 0.25, 0.0))
	ramp.add_point(0.35, col)
	var rt := GradientTexture1D.new(); rt.gradient = ramp
	pm.color_ramp = rt
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.6)); sc.add_point(Vector2(0.2, 1.0)); sc.add_point(Vector2(1, 0.15))
	var st := CurveTexture.new(); st.curve = sc
	pm.scale_curve = st
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _sprite()
	mat.albedo_color = Color(1.25, 1.25, 1.25)   # over 1 so the glow pass picks it up
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
static func live(g: Node3D, kind: String) -> Node3D:
	var n := Node3D.new()
	g.add_child(n)
	match kind:
		"projectile":
			var s := SphereMesh.new(); s.radius = 0.28; s.height = 0.56
			n.add_child(_mesh(s, Color(1.0, 0.72, 0.35), 5.0)); n.add_child(_light(TINT.fire, 4.0, 9.0))
			# Flames stay in world space, so a moving ball drags a tail behind it.
			var trail := _particles(TINT.fire, 70, 0.4, 0.34, 0.9, 1.2)
			n.add_child(trail)
		"mover":
			var b := BoxMesh.new(); b.size = Vector3(2.4, 3.2, 0.08)
			n.add_child(_mesh(b, Color(0.05, 0.02, 0.08), 0.0)); n.add_child(_light(TINT.spirit, 2.5, 8.0))
			var rimm := BoxMesh.new(); rimm.size = Vector3(2.6, 3.4, 0.04)
			n.add_child(_mesh(rimm, TINT.spirit, 5.0))
		"ring":
			var t := TorusMesh.new(); t.inner_radius = 0.93; t.outer_radius = 1.0
			n.add_child(_mesh(t, TINT.fire, 6.0))
		"blast":
			var c := CylinderMesh.new(); c.top_radius = 0.9; c.bottom_radius = 0.9; c.height = 0.05
			var mi := _mesh(c, TINT.fire, 2.0); mi.position.y = -1.1
			n.add_child(mi)
	return n

static func blast(g: Node3D, at: Vector3, radius: float, weave: String) -> void:
	var col := colour(weave)
	var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.0
	var mi := _mesh(s, col, 8.0)
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
	_once(_particles(col, int(30 + radius * 16), 0.7, 0.9 + radius * 0.35, 1.5 + radius, 2.5), g, at + Vector3(0, 0.5, 0))
	if g.has_method("shake_at"):
		g.shake_at(at, radius)

## Instant weaves that the sim resolves in one tick.
static func cast(g: Node3D, e: Dictionary) -> void:
	var col := colour(e.weave)
	var from: Vector3 = g._ground(e.pos) + Vector3(0, 1.4, 0)
	match e.kind:
		"beam", "line":
			var b: Dictionary = Rules.weaves[e.weave].base
			var m := BoxMesh.new(); m.size = Vector3(b.width * (0.5 if e.kind == "beam" else 1.0), 0.3 if e.kind == "beam" else 0.15, b.range)
			var mi := _mesh(m, col, 10.0 if e.kind == "beam" else 4.0)
			g.add_child(mi)
			mi.position = from + e.dir * b.range * 0.5 - Vector3(0, 0.0 if e.kind == "beam" else 1.2, 0)
			mi.rotation.y = atan2(e.dir.x, e.dir.z)
			var tw := g.create_tween()
			tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.5)
			tw.tween_callback(mi.queue_free)
		"strike":
			var m := CylinderMesh.new(); m.top_radius = 0.12; m.bottom_radius = 0.3; m.height = 60.0
			var mi := _mesh(m, col, 12.0)
			g.add_child(mi); mi.position = g._ground(e.at) + Vector3(0, 30, 0)
			var tw := g.create_tween()
			tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.25)
			tw.tween_callback(mi.queue_free)
		"cone":
			blast(g, from + e.dir * 3.0, 2.5, e.weave)
