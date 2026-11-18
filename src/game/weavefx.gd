class_name Weavefx
extends RefCounted
## Weave visuals: glowing primitives, lights and short tweens. First pass only;
## this is where the game's feel will be won, so expect it to be rebuilt richer.

const TINT := {fire = Color(1.0, 0.42, 0.1), earth = Color(0.75, 0.5, 0.2), air = Color(0.7, 0.85, 1.0), water = Color(0.25, 0.5, 1.0), spirit = Color(0.95, 0.95, 1.0)}

static func colour(weave: String) -> Color:
	# What the Shadow's channellers throw is not in the book of weaves.
	if not Rules.weaves.has(weave):
		return Color(1.0, 0.12, 0.04)
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

## Flame for anything that burns (a watch-fire, a torch, burning grass): quick,
## narrow tongues going from yellow through orange to a dark red as they rise, few
## enough that where they overlap it stays fire-coloured instead of summing to white.
## `box` spreads them over a patch of ground (zero for one fire).
static func flame(amount: int, size: float, rise: float, box := Vector3.ZERO) -> GPUParticles3D:
	var f := _particles(Color(1.0, 0.38, 0.08), amount, clampf(rise * 0.55, 0.35, 0.9), size, rise, rise * 1.2, 10.0)
	var pm := f.process_material as ParticleProcessMaterial
	if box != Vector3.ZERO:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box
	else:
		pm.emission_sphere_radius = size * 0.35
	pm.damping_min = 0.0; pm.damping_max = rise * 0.3
	var ramp := Gradient.new()
	# (Kept well short of opaque: added over sunlit ground, fuller tongues read as
	# solid orange cones.)
	ramp.set_color(0, Color(1.0, 0.72, 0.3, 0.55)); ramp.set_color(1, Color(0.5, 0.06, 0.02, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.45, 0.1, 0.5)); ramp.add_point(0.7, Color(0.8, 0.16, 0.04, 0.25))
	(pm.color_ramp as GradientTexture1D).gradient = ramp
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.7)); sc.add_point(Vector2(0.25, 1.0)); sc.add_point(Vector2(1, 0.1))
	(pm.scale_curve as CurveTexture).curve = sc
	var q := f.draw_pass_1 as QuadMesh
	(q.material as StandardMaterial3D).albedo_color = Color(0.95, 0.95, 0.95)
	(q.material as StandardMaterial3D).albedo_texture = _flame_tex()
	# Upright quads, a third as wide as they are tall: the round sprite stretches
	# into a tongue (square ones read as a heap of glowing orbs).
	q.size = Vector2(size * 0.85, size * 1.4)
	return f

## A tongue of flame to draw each flame particle with: wide and solid at the
## root, narrowing to a ragged tip (the round sprite read as floating orbs).
static var _flame: ImageTexture
static func _flame_tex() -> ImageTexture:
	if _flame != null:
		return _flame
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		var v := y / 63.0                     # 0 at the tip, 1 at the root
		var w := 0.46 * pow(v, 0.75) * (1.0 - 0.55 * smoothstep(0.82, 1.0, v))
		for x in 32:
			var d := absf(x / 31.0 - 0.5)
			var a := (1.0 - smoothstep(0.0, w, d)) * smoothstep(0.0, 0.3, v) * (1.0 - smoothstep(0.9, 1.0, v) * 0.7)
			var hot := (1.0 - smoothstep(0.0, w * 0.6, d)) * smoothstep(0.4, 0.95, v)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0).lerp(Color(1.0, 0.85, 0.6, 1.0), 1.0 - hot) * Color(1, 1, 1, a))
	_flame = ImageTexture.create_from_image(img)
	return _flame

## Smoke going up from a fire and leaning with the wind; `box` as for flame.
static func smoke_column(amount: int, size: float, at: Vector3, box := Vector3.ZERO) -> GPUParticles3D:
	var s := _particles(Color(0.16, 0.14, 0.13), amount, 3.4, size, 0.9, 0.7, 16.0, false)
	var pm := s.process_material as ParticleProcessMaterial
	if box != Vector3.ZERO:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box
	pm.gravity += Wind.at(at) * 0.35
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.2, 0.17, 0.15, 0.0)); ramp.set_color(1, Color(0.3, 0.29, 0.28, 0.0))
	ramp.add_point(0.15, Color(0.17, 0.15, 0.14, 0.5))
	(pm.color_ramp as GradientTexture1D).gradient = ramp
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.4)); sc.add_point(Vector2(1, 1.6))
	(pm.scale_curve as CurveTexture).curve = sc
	return s

static func _once(p: GPUParticles3D, g: Node3D, at: Vector3) -> void:
	p.one_shot = true; p.explosiveness = 0.92
	g.add_child(p); p.position = at; p.emitting = true
	g.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## A persistent effect the sim is tracking (projectile, gate, ring, pending blast).
static func live(g: Node3D, kind: String, weave := "") -> Node3D:
	if kind.begins_with("dream_"):
		var dn := Dreamfx.live(kind)
		g.add_child(dn)
		return dn
	var n := Node3D.new()
	g.add_child(n)
	match kind:
		"projectile" when weave != "" and Rules.weaves[weave].get("dart", false):
			# A dart of fire: a thin white-hot streak, fast, with almost no glow
			# around it. The game turns it along its flight.
			var c := CylinderMesh.new(); c.top_radius = 0.012; c.bottom_radius = 0.035; c.height = 1.1; c.radial_segments = 6; c.rings = 1
			var core := _mesh(c, Color(1.0, 0.9, 0.7), 9.0)
			core.rotation.x = PI * 0.5; core.position.z = 0.45
			n.add_child(core)
			n.add_child(Flowfx.Ribbon.new(Color(1.0, 0.4, 0.08), 0.2, 16, 3.5, 0.5))
			n.add_child(_light(TINT.fire, 1.6, 4.5))
			n.set_meta("aimed", true)
		"projectile":
			var col: Color = colour(weave) if weave != "" else TINT.fire
			if weave != "" and not Rules.weaves[weave].flows.has("fire"):
				# A blade of Spirit: a sliver of white light standing on edge, with a
				# thin wake. The game turns it along its flight.
				var bl := Flowfx.ball(0.5, col, 1.3, 0.05)
				bl.scale = Vector3(0.05, 1.5, 1.0)
				n.add_child(bl)
				for y in [-0.55, 0.0, 0.55]:
					var w := Node3D.new(); w.position.y = y; n.add_child(w)
					w.add_child(Flowfx.Ribbon.new(col, 0.1, 14, 2.5, 0.2))
				n.add_child(_light(col, 1.5, 6.0))
				n.set_meta("aimed", true)
			else:
				# A ball of fire: it boils, and drags flame behind it.
				n.add_child(Flowfx.ball(0.42, col, 1.5, 0.35))
				var heart := Flowfx.ball(0.2, col, 2.2, 0.1); n.add_child(heart)
				n.add_child(Flowfx.Ribbon.new(Color(1.0, 0.38, 0.06), 0.75, 18, 1.5, 0.85))
				n.add_child(Flowfx.Ribbon.new(Color(1.0, 0.7, 0.3), 0.3, 10, 1.6, 0.5))
				n.add_child(_light(col, 5.0, 11.0))
				# Embers stay in world space, falling away behind it.
				n.add_child(_particles(col, 30, 0.7, 0.09, 1.6, -3.0))
		"mover":
			# A Deathgate: a doorway onto a darkness that folds over itself, edged in
			# hard light, with threads torn off its corners as it sweeps along.
			var q := QuadMesh.new(); q.size = Vector2(2.4, 3.2)
			var door := MeshInstance3D.new(); door.mesh = q
			var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/portal.gdshader")
			sm.set_shader_parameter("tint", Color(0.3, 0.08, 0.5)); sm.set_shader_parameter("lit", 0.45)
			door.material_override = sm; door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(door)
			for edge in [[Vector3(-1.2, 0, 0), Vector3(0.05, 3.25, 0.05)], [Vector3(1.2, 0, 0), Vector3(0.05, 3.25, 0.05)], [Vector3(0, 1.6, 0), Vector3(2.45, 0.05, 0.05)], [Vector3(0, -1.6, 0), Vector3(2.45, 0.05, 0.05)]]:
				var bm := BoxMesh.new(); bm.size = edge[1]
				var em := _mesh(bm, Color(0.85, 0.75, 1.0), 4.0); em.position = edge[0]
				n.add_child(em)
			for c in [Vector3(-1.2, 1.6, 0), Vector3(1.2, 1.6, 0), Vector3(-1.2, -1.5, 0), Vector3(1.2, -1.5, 0)]:
				var w := Node3D.new(); w.position = c; n.add_child(w)
				w.add_child(Flowfx.Ribbon.new(Color(0.6, 0.35, 1.0), 0.22, 22, 2.0, 0.5))
			n.add_child(_light(Color(0.6, 0.4, 1.0), 2.5, 8.0))
		"ring":
			n.free()
			n = Wedge.new()
			(n as Wedge).half = deg_to_rad(float(Rules.weaves[weave].base.get("arc", 180.0))) if weave != "" else PI
			g.add_child(n)
		"blossom":
			n.free()
			n = Blossom.new()
			g.add_child(n)
		"missile" when weave == "dark_fire":
			# A Dreadlord's fire: a red-black ball with a dull trail.
			var s := SphereMesh.new(); s.radius = 0.3; s.height = 0.6
			n.add_child(_mesh(s, Color(1.0, 0.1, 0.03), 5.0))
			var core := SphereMesh.new(); core.radius = 0.17; core.height = 0.34
			n.add_child(_mesh(core, Color(0.05, 0.0, 0.0), 0.0))
			n.add_child(Flowfx.Ribbon.new(Color(0.9, 0.04, 0.02), 0.6, 18, 2.2, 0.8))
			n.add_child(_light(Color(1.0, 0.15, 0.05), 2.5, 6.0))
		"missile" when weave.ends_with(":lit"):
			# A fire arrow: lit from a fire, flame at the head and a smoky trail.
			n.add_child(Armoury.missile(weave.trim_suffix(":lit")))
			var fl := _particles(Color(1.0, 0.5, 0.12), 24, 0.35, 0.16, 0.6, 1.0, 40.0)
			n.add_child(fl); fl.position = Vector3(0, 0, -0.45)
			n.add_child(Flowfx.Ribbon.new(Color(1.0, 0.55, 0.2), 0.09, 22, 4.0, 0.5))
			n.add_child(_light(Color(1.0, 0.55, 0.2), 1.2, 4.0))
		"missile":
			var mm := Armoury.missile(weave)
			# Small things are drawn larger than life in the air, or they are not seen.
			var small: bool = weave in ["throwing_knives", "belt_knife", "sling"]
			if small:
				mm.scale = Vector3.ONE * 2.2
			n.add_child(mm)
			# A trail behind it, like a blade's streak, so the eye can follow its whole
			# flight and see where it went.
			n.add_child(Flowfx.Ribbon.new(Color(1.0, 0.95, 0.82), 0.1 if small else 0.075, 22, 4.0, 0.5))
			if small:
				n.add_child(_light(Color(1.0, 0.95, 0.85), 0.8, 2.5))
		"drop":
			# Spent and standing where it fell, point down, to be gathered up: a
			# ring on the ground and a thread of light mark it from a distance.
			var m := Armoury.missile(weave)
			m.rotation = Vector3(-1.2, randf() * TAU, 0); m.position.y = -1.05
			if weave in ["throwing_knives", "belt_knife"]:
				m.scale = Vector3.ONE * 1.8
			n.add_child(m)
			var ring := TorusMesh.new(); ring.inner_radius = 0.3; ring.outer_radius = 0.34
			var ri := _mesh(ring, Color(1.0, 0.82, 0.4, 0.7), 2.5); ri.position.y = -1.14
			n.add_child(ri)
			var beam := CylinderMesh.new(); beam.top_radius = 0.0; beam.bottom_radius = 0.03; beam.height = 1.6; beam.radial_segments = 5; beam.rings = 1
			var bi := _mesh(beam, Color(1.0, 0.85, 0.45, 0.3), 2.0); bi.position.y = -0.35
			n.add_child(bi)
		"blast":
			var c := CylinderMesh.new(); c.top_radius = 0.9; c.bottom_radius = 0.9; c.height = 0.05
			var mi := _mesh(c, TINT.fire, 2.0); mi.position.y = -1.1
			n.add_child(mi)
	return n

## The flows themselves, seen while a weave is made: one thread for each flow, and
## each Power moves in its own way (see FormFx). It lasts until the game frees it,
## because a finished weave can be held back in the hands.
static func forming(_g: Node3D, who: Node3D, weave: String, secs: float) -> Node3D:
	var fx := FormFx.new()
	fx.secs = maxf(secs, 0.15)
	fx.weave = weave
	who.add_child(fx)
	return fx

## Weaving, made visible. Fire climbs from the feet in a tight flickering helix;
## Earth is slow stones lifting from the ground; Air is fast wide rings; Water
## flows in a figure of eight; Spirit is motes falling inward from all around.
## All of them close on the hands, where a core in the weave's colour grows; when
## the weave is whole the core pulses and throws sparks until it is loosed.
class FormFx extends Node3D:
	var secs := 1.0
	var weave := ""
	var age := 0.0
	var parts: Array = []      # [node, element, index]
	var core: MeshInstance3D
	var lamp: OmniLight3D
	var halo: MeshInstance3D
	var burst_done := false
	var hoops: Array = []
	const HANDS := Vector3(0, 1.25, 0.5)

	func _ready() -> void:
		var fl: Dictionary = Rules.weaves[weave].flows
		var k := 0
		for e in fl:
			# A big weave shows more threads of each Power, so it looks like more work.
			for i in int(fl[e]) * 2:
				var n := Node3D.new(); add_child(n)
				# Each flow is a thread: a bright bead drawing a ribbon of its Power's
				# colour through the air, and all of them winding in on the hands.
				var sp := SphereMesh.new(); sp.radius = 0.028; sp.height = 0.056
				n.add_child(Weavefx._mesh(sp, Weavefx.TINT[e].lerp(Color.WHITE, 0.5), 3.0))
				var look: Array = {fire = [0.14, 22, 2.6, 0.7], earth = [0.17, 30, 2.2, 0.55], air = [0.09, 34, 2.4, 0.25], water = [0.12, 30, 2.6, 0.35]}.get(e, [0.07, 26, 2.6, 0.1])
				var rb := Flowfx.Ribbon.new(Weavefx.TINT[e] if e != "earth" else Color(0.95, 0.6, 0.2), look[0], look[1], look[2], look[3])
				rb.taper = 0.6
				n.add_child(rb)
				if e in ["fire", "earth"]:
					# Fire sheds sparks as it climbs; Earth drops grit.
					n.add_child(Weavefx._particles(Weavefx.TINT[e], 10, 0.5, 0.05, 0.6, 2.0 if e == "fire" else -4.0, 60.0))
				parts.append([n, e, k]); k += 1
		var col := Weavefx.colour(weave)
		# The weave itself, taking shape between the hands: a small bright heart and
		# hoops of each Power turning round it, one for every flow in it.
		core = Flowfx.ball(0.13, col, 3.5, 0.3)
		core.position = HANDS; add_child(core)
		var hi := 0
		for e in fl:
			for i in int(fl[e]):
				var t := TorusMesh.new(); t.inner_radius = 0.2 + 0.035 * hi; t.outer_radius = t.inner_radius + 0.012; t.rings = 40; t.ring_segments = 5
				var hoop := Weavefx._mesh(t, Weavefx.TINT[e].lerp(Color.WHITE, 0.2), 5.0)
				hoop.rotation = Vector3(hi * 1.1, hi * 2.3, hi * 0.7)
				core.add_child(hoop); hoops.append(hoop); hi += 1
		lamp = Weavefx._light(col, 0.5, 5.0); lamp.position = HANDS; add_child(lamp)
		if fl.has("spirit"):
			var t := TorusMesh.new(); t.inner_radius = 0.24; t.outer_radius = 0.27
			halo = Weavefx._mesh(t, Color(Weavefx.TINT.spirit, 0.7), 4.0)
			halo.position.y = 2.05; add_child(halo)
		_process(0.0)

	func _process(dt: float) -> void:
		age += dt
		var f := clampf(age / secs, 0.0, 1.0)
		var ready := age >= secs
		var n := float(maxi(parts.size(), 1))
		for row in parts:
			var node: Node3D = row[0]
			var i: float = row[2]
			var ph := i * TAU / n
			var at := Vector3.ZERO
			match row[1]:
				"fire":
					var a := age * 9.0 + ph
					var r := 0.5 * (1.0 - f) + 0.07
					at = Vector3(cos(a) * r, lerpf(0.15, HANDS.y, f) + 0.08 * sin(age * 23.0 + i), sin(a) * r + HANDS.z * f)
				"earth":
					var a := age * 2.6 + ph
					var r := 0.95 * (1.0 - f * 0.85) + 0.06
					at = Vector3(cos(a) * r, 0.2 + (HANDS.y - 0.2) * f * f, sin(a) * r + HANDS.z * f)
				"air":
					var a := age * 15.0 + ph
					var r := 0.8 * (1.0 - f) + 0.09
					at = Vector3(cos(a) * r, HANDS.y + 0.45 * (1.0 - f) * sin(age * 5.0 + i * 2.1), sin(a) * r + HANDS.z * f)
				"water":
					var a := age * 5.5 + ph
					var r := 0.7 * (1.0 - f * 0.9) + 0.07
					at = Vector3(sin(a) * r, HANDS.y - 0.25 * (1.0 - f) + 0.35 * (1.0 - f) * sin(a * 2.0), cos(a) * r * 0.6 + HANDS.z * (0.4 + 0.6 * f))
				_:
					# Spirit falls inward, again and again, from further than the rest.
					var u := fposmod(age * 1.4 + i * 0.37, 1.0)
					var a := ph + age * 0.6
					var r := (1.5 * (1.0 - u) + 0.05) * (1.0 - f * 0.6)
					at = Vector3(cos(a) * r, HANDS.y + 0.7 * (1.0 - u) * sin(ph * 3.0), sin(a) * r + HANDS.z * f)
			if ready:
				# Whole: the threads are a tight knot turning on the hands.
				var a2 := age * 7.0 + ph
				at = HANDS + Vector3(cos(a2), sin(a2 * 1.3 + i), sin(a2)) * 0.13
			node.position = at
		var pulse := 1.0 + (0.22 * sin(age * 16.0) if ready else 0.0)
		for i in hoops.size():
			var sp2 := (5.0 if ready else 1.5 + 2.5 * f) * (1.0 if i % 2 == 0 else -1.0)
			(hoops[i] as Node3D).rotate_object_local(Vector3(0.3, 1.0, 0.2 * i).normalized(), dt * sp2)
		core.scale = Vector3.ONE * (0.15 + 0.85 * f * f) * pulse
		lamp.light_energy = (0.4 + 2.2 * f) * pulse * (1.6 if ready else 1.0)
		if halo:
			halo.scale = Vector3.ONE * (0.4 + 0.8 * f)
			halo.rotate_y(dt * 2.0)
		if ready and not burst_done:
			burst_done = true
			var p := Weavefx._particles(Weavefx.colour(weave), 36, 0.45, 0.07, 4.5, -2.0, 180.0)
			p.one_shot = true; p.explosiveness = 0.95
			add_child(p); p.position = HANDS; p.emitting = true

## Blossoms of Fire once it has opened: a low, wide wheel of fire turning slowly,
## five curved arms of flame out to its edge. Before that, a thin pillar where it
## was aimed. The game feeds it its radius from the sim.
class Blossom extends Node3D:
	var r := 0.6
	var age := 0.0
	var spin := 0.0
	var arms: Array = []       # [emitter, arm index, fraction along the arm]
	var pillar: GPUParticles3D
	var column: MeshInstance3D
	var scorch: MeshInstance3D
	var rim: MeshInstance3D
	var edge: Array = []
	var lamp: OmniLight3D
	const RIM := 14
	const ARMS := 5
	const PER := 9

	func _ready() -> void:
		# The pillar: six feet of fire, no wider than a man.
		pillar = Weavefx._particles(Color(1.0, 0.35, 0.06), 90, 0.45, 0.22, 4.4, 3.0, 5.0)
		pillar.position.y = -1.0
		add_child(pillar)
		column = Flowfx.ball(0.5, Weavefx.TINT.fire, 1.6, 0.5)
		column.scale = Vector3(0.9, 0.2, 0.9); column.position.y = -1.0
		add_child(column)
		for a in ARMS:
			for j in PER:
				# Small deep-orange tongues, close together: an arm of flame, not a cloud.
				var e := Weavefx._particles(Color(1.0, 0.28, 0.04), 26, 0.6, 0.6 + 0.35 * j / PER, 1.0, 2.6, 22.0)
				# Dimmer than a fireball's flame: many overlap, and it must stay orange.
				((e.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.7, 0.7, 0.7)
				e.emitting = false
				add_child(e)
				arms.append([e, a, (j + 1.0) / PER])
		var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.04
		# The ground under it: burnt black, with a hot edge where the fire is spreading.
		scorch = Weavefx._mesh(c, Color(0.05, 0.02, 0.01, 0.4), 0.0)
		scorch.position.y = -1.12
		add_child(scorch)
		var rt := TorusMesh.new(); rt.inner_radius = 0.955; rt.outer_radius = 1.0
		rim = Weavefx._mesh(rt, Color(1.0, 0.4, 0.06, 0.8), 3.5)
		rim.position.y = -1.08
		add_child(rim)
		for i in RIM:
			var e := Weavefx._particles(Color(1.0, 0.3, 0.05), 12, 0.5, 0.45, 0.8, 2.2, 25.0)
			((e.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.6, 0.6, 0.6)
			e.emitting = false
			add_child(e); edge.append(e)
		lamp = Weavefx._light(Weavefx.TINT.fire, 3.0, 8.0)
		add_child(lamp)

	func set_r(radius: float, _yaw: float) -> void:
		r = radius

	func _process(dt: float) -> void:
		age += dt
		spin += dt * 0.75
		var open := r > 1.0
		pillar.emitting = age < 1.0
		if is_instance_valid(column):
			# The pillar stands up fast, then burns out as the wheel opens.
			var up := smoothstep(0.0, 0.25, age)
			column.scale = Vector3(0.9, 0.2 + 6.5 * up, 0.9)
			column.position.y = -1.0 + 1.6 * up
			(column.material_override as ShaderMaterial).set_shader_parameter("burn", smoothstep(0.8, 1.5, age))
			if age > 1.5:
				column.queue_free()
		scorch.scale = Vector3(r, 1.0, r)
		rim.scale = Vector3(r, 1.0, r)
		for i in RIM:
			var ea: float = -spin * 0.5 + i * TAU / RIM
			(edge[i] as GPUParticles3D).position = Vector3(cos(ea) * r, -0.95, sin(ea) * r)
			(edge[i] as GPUParticles3D).emitting = open
		lamp.omni_range = 6.0 + r * 2.0
		lamp.light_energy = 2.5 + r * 0.3 + sin(age * 9.0) * 0.4
		for row in arms:
			var e: GPUParticles3D = row[0]
			var fr: float = row[2]
			var rad := r * fr
			# Each arm trails behind its own tip, so the wheel reads as turning.
			var ang: float = spin + row[1] * TAU / ARMS - fr * 1.7
			e.position = Vector3(cos(ang) * rad, -0.95, sin(ang) * rad)
			e.emitting = open and rad > 0.6

## The Rolling Ring of Earth and Fire: a wedge of churned ground and flame rolling
## out the way it was thrown. Teeth of rock heave up and fall along its front as
## it goes. The game feeds it its radius and heading from the sim.
class Wedge extends Node3D:
	var r := 0.5
	var half := 0.6
	var age := 0.0
	var teeth: Array = []
	var fires: Array = []
	var lamp: OmniLight3D
	const N := 17

	func _ready() -> void:
		for i in N:
			var th := 1.3 + randf() * 0.9
			var mi := Flowfx.shard(th, 0.42 + 0.2 * randf())
			mi.set_meta("h", th)
			mi.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
			add_child(mi); teeth.append(mi)
			var f := Weavefx._particles(Color(1.0, 0.3, 0.05), 20, 0.5, 0.5, 1.2, 2.8, 30.0)
			((f.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.55)
			add_child(f); fires.append(f)
		# Dust thrown up behind the front.
		var d := Weavefx._particles(Color(0.36, 0.28, 0.2), 60, 1.1, 1.1, 2.0, 0.8, 80.0, false)
		d.name = "Dust"; add_child(d)
		lamp = Weavefx._light(Weavefx.TINT.fire, 2.2, 9.0); add_child(lamp)

	func set_r(radius: float, yaw: float) -> void:
		r = radius
		rotation.y = yaw

	func _process(dt: float) -> void:
		age += dt
		for i in N:
			var a := lerpf(-half, half, i / float(N - 1))
			var at := Vector3(sin(a) * r, 0.0, cos(a) * r)
			# The ground rises and drops in a ripple along the front.
			var up := absf(sin(age * 7.0 + i * 1.3))
			var h: float = (teeth[i] as MeshInstance3D).get_meta("h")
			(teeth[i] as MeshInstance3D).position = at + Vector3(0, -1.2 - h + h * (0.25 + 0.75 * up), 0)
			(fires[i] as GPUParticles3D).position = at + Vector3(0, -0.9 + h * 0.5 * up, 0)
		(get_node("Dust") as GPUParticles3D).position = Vector3(0, -0.9, maxf(r - 1.2, 0.0))
		lamp.position = Vector3(0, 0.2, r)

## A weave being held, for as long as it is held: the dome around its weaver,
## bands of Air on the one it binds, a mark over the one it shields; and a thread
## from the weaver's hand to it, which is what tying off cuts. The game moves
## "Body" to whoever it sits on and stretches "Tether" between the two.
static func hold(g: Node3D, weave: String) -> Node3D:
	var n := Node3D.new()
	g.add_child(n)
	var kind: String = Rules.weaves[weave].kind
	var col := colour(weave)
	var body := Node3D.new(); body.name = "Body"; n.add_child(body)
	match kind:
		"barrier":
			var mi := Flowfx.shell(1.5, col, 0.4); mi.position.y = 1.0
			body.add_child(mi)
			var ring := TorusMesh.new(); ring.inner_radius = 1.42; ring.outer_radius = 1.5
			var ri := _mesh(ring, Color(col, 0.5), 2.0); ri.position.y = 0.08
			body.add_child(ri)
		"bind":
			for y in [0.45, 1.05, 1.65]:
				var t := TorusMesh.new(); t.inner_radius = 0.66; t.outer_radius = 0.72
				var ti := _mesh(t, Color(col, 0.75), 3.5); ti.position.y = y
				ti.rotation = Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
				body.add_child(ti)
		"sever":
			# The shield sits round them: a thin shell they cannot reach through.
			var mi := Flowfx.shell(1.05, col, 0.5); mi.position.y = 1.2; mi.scale.y = 1.25
			body.add_child(mi)
			var t := TorusMesh.new(); t.inner_radius = 0.5; t.outer_radius = 0.54
			var ti := _mesh(t, Color(col, 0.7), 3.0); ti.position.y = 1.3
			body.add_child(ti)
	if kind != "barrier":
		var c := CylinderMesh.new(); c.top_radius = 0.018; c.bottom_radius = 0.018; c.height = 1.0; c.radial_segments = 6; c.rings = 1
		var th := _mesh(c, Color(col, 0.8), 4.0); th.name = "Tether"
		n.add_child(th)
	return n

## The knot of a tied-off weave: a small bright point where the thread was.
static func knot(n: Node3D, weave: String) -> void:
	var th := n.get_node_or_null("Tether")
	if th:
		th.visible = false
	var s := SphereMesh.new(); s.radius = 0.09; s.height = 0.18
	var mi := _mesh(s, colour(weave).lerp(Color.WHITE, 0.6), 8.0); mi.position.y = 2.05
	n.get_node("Body").add_child(mi)

## A charge leaping from one body to the next.
## Where lightning lands: no swelling ball, but a white flash gone at once, jagged
## arcs running out along the ground to the edge of what it struck, sparks, and a
## burnt star on the ground.
static func _strike_flash(g: Node3D, at: Vector3, radius: float) -> void:
	var col := Color(0.88, 0.93, 1.0)
	var mi := Flowfx.ball(1.0, col, 4.0, 0.2)
	mi.position = at + Vector3(0, 0.3, 0); mi.scale = Vector3.ONE * 0.5
	g.add_child(mi)
	var l := _light(col, 14.0, radius * 4.0)
	mi.add_child(l)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * minf(radius * 0.35, 1.2), 0.06)
	tw.tween_property(mi.material_override, "shader_parameter/burn", 1.0, 0.14)
	tw.tween_property(l, "light_energy", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
	for i in int(6 + radius * 1.5):
		var ang := randf() * TAU
		var end := at + Vector3(cos(ang), 0, sin(ang)) * radius * randf_range(0.6, 1.0)
		var prev := at + Vector3(0, 0.1, 0)
		for k in range(1, 6):
			var f := k / 5.0
			var p := at.lerp(end, f) + Vector3(randf_range(-0.3, 0.3), 0.1 + randf_range(0.0, 0.25) * (1.0 - f), randf_range(-0.3, 0.3))
			_fade(g, _bar(g, prev, p, 0.05, col, 12.0), randf_range(0.12, 0.25))
			prev = p
	_once(_particles(col, int(30 + radius * 10), 0.4, 0.07, 7.0, -9.0, 85.0), g, at + Vector3(0, 0.3, 0))
	var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.03
	var sc := _mesh(c, Color(0.03, 0.03, 0.04, 0.5), 0.0)
	sc.position = g._ground(at) + Vector3(0, 0.03, 0); sc.scale = Vector3(radius * 0.45, 1, radius * 0.45)
	g.add_child(sc)
	var ts := g.create_tween()
	ts.tween_interval(5.0)
	ts.tween_property(sc.material_override, "albedo_color:a", 0.0, 2.0)
	ts.tween_callback(sc.queue_free)

static func arc(g: Node3D, a: Vector3, b: Vector3) -> void:
	var prev := a
	for i in range(1, 7):
		var f := i / 6.0
		var p := a.lerp(b, f) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.35 * sin(f * PI)
		_fade(g, _bar(g, prev, p, 0.07, Color(0.9, 0.95, 1.0), 14.0), 0.28)
		prev = p
	_once(_particles(Color(0.8, 0.88, 1.0), 20, 0.3, 0.08, 5.0, -4.0, 90.0), g, b)
	Sfx.play(g, "crack", b, -6.0, 1.8)

## Both sides of a gateway: a slash of light that turns open into a doorway. The
## returned node holds the two, and is freed when the weave is let go.
static func gate(g: Node3D, a: Vector3, b: Vector3, flat_a := false, sky := 0.0) -> Node3D:
	var n := Node3D.new(); g.add_child(n)
	for side in [[a, b, flat_a, 0.0], [b, a, sky > 0.0, sky]]:
		var q := QuadMesh.new(); q.size = Vector2(1.9, 2.9)
		var mi := MeshInstance3D.new(); mi.mesh = q
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/portal.gdshader")
		sm.set_shader_parameter("tint", Color(0.75, 0.85, 1.0)); sm.set_shader_parameter("lit", 1.0)
		mi.material_override = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		mi.position = g._ground(side[0]) + Vector3(0, 1.5, 0)
		var away: Vector3 = (side[1] - side[0]) * Vector3(1, 0, 1)
		mi.rotation.y = atan2(away.x, away.z)
		if side[2]:
			# Laid flat: a hole in the ground, or an opening in the sky.
			mi.rotation = Vector3(-PI * 0.5, mi.rotation.y, 0)
			mi.position = g._ground(side[0]) + Vector3(0, 0.04 + side[3], 0)
		# It opens from a line: narrow, then wide.
		mi.scale = Vector3(0.02, 1.0, 1.0)
		g.create_tween().tween_property(mi, "scale", Vector3.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		var l := _light(Color(0.75, 0.85, 1.0), 3.0, 8.0); l.position = mi.position; n.add_child(l)
		Sfx.play(g, "chime", mi.position, 0.0, 0.55)
	return n

## Steel on steel: a spray of sparks, brighter for a clean parry.
static func sparks(g: Node3D, at: Vector3, bright: bool) -> void:
	_once(_particles(Color(1.0, 0.85, 0.5) if bright else Color(0.9, 0.75, 0.55), 40 if bright else 14, 0.35, 0.06, 7.0 if bright else 4.0, -9.0, 70.0), g, at)
	if bright:
		var l := _light(Color(1.0, 0.9, 0.7), 5.0, 6.0)
		g.add_child(l); l.position = at
		var tw := g.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.25); tw.tween_callback(l.queue_free)

static var _white: StandardMaterial3D

## The instant of impact: the struck body flashes white for a few frames.
static func flash(g: Node3D, who: Node3D, secs := 0.09) -> void:
	if _white == null:
		_white = StandardMaterial3D.new()
		_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Added light, not paint: the body brightens and keeps its shape and shading
		# (three-quarters-opaque white made it a flat cut-out for those frames).
		_white.albedo_color = Color(0.45, 0.41, 0.36)
		_white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_white.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# Thinned beside the lens like the bodies themselves (near_fade).
		_white.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		_white.distance_fade_min_distance = 0.5; _white.distance_fade_max_distance = 1.5
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
	if kind == "charge":
		# Charged by lightning: bright, quick sparks crawling over it.
		p = _particles(Color(0.85, 0.9, 1.0), 34, 0.22, 0.1, 4.5, 0.0)
		p.add_child(_light(Color(0.7, 0.8, 1.0), 1.6, 4.0))
	elif kind == "daze":
		# Dazed by Spirit: slow pale motes drifting round the head.
		p = _particles(Color(0.9, 0.88, 1.0), 16, 1.4, 0.09, 0.35, 0.25, 180.0)
		p.position.y = 2.1
		return p
	elif kind == "wet":
		# Soaked: water running off it.
		p = _particles(TINT.water.lerp(Color.WHITE, 0.25), 18, 0.5, 0.07, 0.6, -6.0, 60.0)
	elif kind == "fester":
		# A Myrddraal's wound: dark motes that sink instead of rising.
		p = _particles(Color(0.25, 0.05, 0.3), 18, 0.9, 0.16, 0.4, -1.2, 90.0, false)
	elif kind == "burn":
		p = _particles(TINT.fire, 40, 0.6, 0.3, 0.6, 2.2, 60.0)
		p.add_child(_light(TINT.fire, 2.0, 5.0))
	else:
		p = _particles(Color(0.75, 0.85, 1.0), 14, 0.35, 0.12, 2.5, 0.0)
	p.position.y = 1.2
	return p

static func blast(g: Node3D, at: Vector3, radius: float, weave: String) -> void:
	var col := colour(weave)
	if Rules.weaves.has(weave) and Rules.weaves[weave].get("dart", false):
		spit(g, at, col)
		return
	if weave == "lightning":
		_strike_flash(g, at, radius)
		return
	var fiery: bool = not Rules.weaves.has(weave) or Rules.weaves[weave].flows.has("fire")
	# The burst itself: a ball of the stuff that swells fast and then burns through
	# in holes, a smaller white heart that is gone at once, and a flash of light.
	var mi := Flowfx.ball(1.0, col, 2.2, 0.3)
	mi.position = at + Vector3(0, 0.4, 0); mi.scale = Vector3.ONE * 0.3
	g.add_child(mi)
	var heart := Flowfx.ball(1.0, col.lerp(Color.WHITE, 0.6), 3.0, 0.1)
	heart.scale = Vector3.ONE * 0.2; mi.add_child(heart)
	var l := _light(col, 10.0, radius * 4.5)
	mi.add_child(l)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.05, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi.material_override, "shader_parameter/burn", 1.0, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(heart.material_override, "shader_parameter/burn", 1.0, 0.16)
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_property(mi, "position:y", mi.position.y + radius * 0.35, 0.55)
	tw.chain().tween_callback(mi.queue_free)
	# A shockwave hugging the ground.
	var ring := TorusMesh.new(); ring.inner_radius = 0.9; ring.outer_radius = 1.0
	var ri := _mesh(ring, Color(col.lerp(Color.WHITE, 0.5), 0.6), 3.0)
	ri.position = at + Vector3(0, 0.15, 0); ri.scale = Vector3(0.4, 0.25, 0.4)
	g.add_child(ri)
	var tr := g.create_tween().set_parallel()
	tr.tween_property(ri, "scale", Vector3(radius * 1.8, 0.08, radius * 1.8), 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tr.tween_property(ri.material_override, "albedo_color:a", 0.0, 0.32)
	tr.chain().tween_callback(ri.queue_free)
	# Streamers thrown out of it in every direction, arcing over and falling.
	for i in int(7 + radius * 3.0):
		var d := Vector3(randf_range(-1, 1), randf_range(0.15, 1.0), randf_range(-1, 1)).normalized() * radius * randf_range(1.1, 2.0)
		Flowfx.streak(g, at + Vector3(0, 0.3, 0), at + d * Vector3(1, 0.25, 1), randf_range(0.25, 0.45), col, 0.16, Vector3(0, d.y * 0.9, 0), 2.2, 0.6)
	_once(_particles(col, int(30 + radius * 20), 0.9, 0.1, 5.0 + radius * 3.0, -9.0, 80.0), g, at + Vector3(0, 0.3, 0))
	if fiery:
		# What fire leaves: smoke rolling up after the flame is gone, and burnt ground.
		var sm := _particles(Color(0.06, 0.05, 0.05), int(8 + radius * 5), 1.8, 1.0 + radius * 0.45, 1.2 + radius * 0.5, 1.6, 70.0, false)
		g.get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(g): _once(sm, g, at + Vector3(0, 0.6, 0)))
		var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.03
		var sc := _mesh(c, Color(0.03, 0.02, 0.015, 0.55), 0.0)
		sc.position = g._ground(at) + Vector3(0, 0.03, 0); sc.scale = Vector3(radius * 0.8, 1, radius * 0.8)
		g.add_child(sc)
		var ts := g.create_tween()
		ts.tween_interval(3.0)
		ts.tween_property(sc.material_override, "albedo_color:a", 0.0, 4.0)
		ts.tween_callback(sc.queue_free)
	if g.has_method("shake_at"):
		g.shake_at(at, radius)
	Sfx.play(g, "boom", at, -4.0 + radius * 2.0, clampf(1.5 - radius * 0.2, 0.6, 1.4))

## Where a dart of fire goes through something or stops: a spit of sparks.
static func spit(g: Node3D, at: Vector3, col: Color) -> void:
	_once(_particles(col.lerp(Color.WHITE, 0.3), 14, 0.3, 0.07, 6.0, -8.0, 70.0), g, at)
	Sfx.play(g, "thud", at, -7.0, 2.4)

## A Myrddraal going into shadow, or coming out of one: a knot of black smoke
## that folds in on itself.
static func smoke(g: Node3D, at: Vector3, arriving: bool) -> void:
	_once(_particles(Color(0.02, 0.01, 0.03), 60, 0.8, 0.9, 2.2 if arriving else 0.8, 0.4, 180.0, false), g, at + Vector3(0, 1.1, 0))
	var s := SphereMesh.new(); s.radius = 1.0; s.height = 2.6
	var mi := _mesh(s, Color(0.0, 0.0, 0.0, 0.8), 0.0)
	g.add_child(mi); mi.position = at + Vector3(0, 1.2, 0)
	mi.scale = Vector3.ONE * (0.2 if arriving else 0.9)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * (0.9 if arriving else 0.05), 0.35)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)
	Sfx.play(g, "whoosh", at + Vector3(0, 1.2, 0), 0.0, 0.5)


## One spike of rock driven up out of the ground: it erupts, stands a moment,
## and sinks back.
static func spike(g: Node3D, at: Vector3, height: float, lean: Vector3) -> void:
	var mi := Flowfx.shard(height, 0.16 + height * 0.15)
	g.add_child(mi)
	mi.rotation = lean
	mi.position = at - Vector3(0, height * 1.1, 0)
	var tw := g.create_tween()
	tw.tween_property(mi, "position:y", at.y - height * 0.12, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.1 + randf() * 0.5)
	tw.tween_property(mi, "position:y", at.y - height * 1.2, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)

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

## A Draghkar's song, made visible: pale rings going out from it for as long as it
## sings. `who` carries them, so they end with it.
static func song(who: Node3D, secs: float) -> void:
	var n := int(secs / 0.45) + 1
	for i in n:
		var t := TorusMesh.new(); t.inner_radius = 0.92; t.outer_radius = 1.0; t.rings = 32; t.ring_segments = 6
		var mi := _mesh(t, Color(0.75, 0.6, 1.0, 0.0), 3.0)
		mi.position.y = 1.5; mi.scale = Vector3.ONE * 0.3
		who.add_child(mi)
		var tw := who.create_tween()
		tw.tween_interval(i * 0.45)
		tw.tween_property(mi.material_override, "albedo_color:a", 0.7, 0.1)
		tw.set_parallel()
		tw.tween_property(mi, "scale", Vector3(9, 2.5, 9), 1.3)
		tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 1.3).set_delay(0.15)
		tw.set_parallel(false)
		tw.tween_callback(mi.queue_free)

## Lightning called down by a Dreadlord (the bolt and a burst where it lands).
static func doom(g: Node3D, at: Vector3, radius: float) -> void:
	_bolt(g, at, Color(1.0, 0.25, 0.2))
	blast(g, at + Vector3(0, 0.5, 0), radius, "doom")

## A jagged line from a to b: `depth` halvings, each kinked sideways by `rough` of its length.
static func _jag(a: Vector3, b: Vector3, rough: float, depth: int) -> Array:
	var pts: Array = [a, b]
	for d in depth:
		var out: Array = [pts[0]]
		for i in range(1, pts.size()):
			var p: Vector3 = pts[i - 1]; var q: Vector3 = pts[i]
			var off := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * p.distance_to(q) * rough
			out.append((p + q) * 0.5 + off); out.append(q)
		pts = out
	return pts

## Forked lightning: a jittered path from the clouds, one branch, a flash, a crack.
static func _bolt(g: Node3D, at: Vector3, col: Color) -> void:
	var top := at + Vector3(randf_range(-8, 8), 55.0, randf_range(-8, 8))
	# Midpoint displacement: each halving kinks the line sideways by a share of its
	# length, so it zigzags at every scale (a sine sway read as a straight beam).
	var pts := _jag(top, at, 0.22, 5)
	for i in range(1, pts.size()):
		_fade(g, _bar(g, pts[i - 1], pts[i], 0.2, Color(0.92, 0.95, 1.0), 16.0), 0.32)
	# Forks: thinner, dimmer, dying out short of the ground.
	for k in 3:
		var from: Vector3 = pts[randi_range(4, pts.size() / 2 + 6)]
		var fork := _jag(from, from + Vector3(randf_range(-10, 10), -randf_range(8, 18), randf_range(-10, 10)), 0.25, 3)
		for i in range(1, fork.size()):
			_fade(g, _bar(g, fork[i - 1], fork[i], 0.09 * (1.0 - float(i) / fork.size()) + 0.03, col, 10.0), 0.22)
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
			# Liquid white fire: a hard white core, a wider body that boils along its
			# length, a few loose threads round it, and a wide pale ghost of it that
			# hangs in the air after the bar itself is gone.
			Flowfx.beam(g, from, to, b.width * 0.5, Color(1, 1, 1), 4.0, 0.0, 0.7)
			Flowfx.beam(g, from, to, b.width * 1.6, Color(1.0, 0.93, 0.7), 2.0, 0.8, 0.9)
			for i in 3:
				Flowfx.beam(g, from, to, b.width * 0.35, Color(1.0, 0.9, 0.6), 2.5, 0.3, 0.5 + 0.1 * i, b.width * 0.9)
			Flowfx.beam(g, from, to, b.width * 3.5, Color(0.6, 0.5, 0.9), 0.35, 0.6, 1.8)
			_once(_particles(Color(1.0, 0.95, 0.8), 40, 0.6, 0.1, 6.0, 0.0), g, from + e.dir * 1.5)
			var l := _light(Color(1, 0.97, 0.9), 14.0, 30.0)
			g.add_child(l); l.position = from + e.dir * 6.0
			var tw := g.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.6); tw.tween_callback(l.queue_free)
			Sfx.play(g, "crack", from, 2.0, 0.6)
			if g.has_method("shake_at"): g.shake_at(from, 2.5)
		"line":
			# Heave the Ground: a ridge of rock is driven up out of the earth along
			# the line, nearest first, each spike taller than a man in the middle
			# of it, and the ground stays torn for a while after.
			var steps := int(b.range / 1.1)
			var side: Vector3 = e.dir.cross(Vector3.UP)
			for i in steps:
				var u := (i + 0.5) / steps
				var big := sin(u * PI)
				var p: Vector3 = g._ground(feet + e.dir * (1.6 + i * 1.1))
				g.get_tree().create_timer(i * 0.028).timeout.connect(func() -> void:
					if not is_instance_valid(g):
						return
					spike(g, p, 1.0 + 1.7 * big + randf() * 0.4, Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.25, 0.25)))
					for sgn in [-1.0, 1.0]:
						spike(g, g._ground(p + side * sgn * (0.5 + 0.7 * big + randf() * 0.3)), 0.5 + 0.8 * big + randf() * 0.3, Vector3(sgn * 0.2, randf() * TAU, sgn * -0.5))
					_once(_particles(Color(0.24, 0.17, 0.1), 26, 1.0, 0.34, 9.0, -16.0, 35.0, false), g, p)
					_once(_particles(Color(0.5, 0.42, 0.33), 6, 1.3, 0.9, 1.4, 0.6, 80.0, false), g, p + Vector3(0, 0.4, 0))
					if i % 3 == 0:
						Sfx.play(g, "thud", p, 0.0, 0.55 + randf() * 0.2)
						if g.has_method("shake_at"): g.shake_at(p, 1.6))
			Sfx.play(g, "rumble", feet + e.dir * b.range * 0.5, 6.0)
			if g.has_method("shake_at"): g.shake_at(feet + e.dir * 4.0, 2.6)
		"lash":
			# A Lash of Water: a whip of it cracks out along the line, wraps what it
			# reaches and is hauled back in.
			# Drawn as one rope of water, thick at the hand and thin at the tip, with
			# a brighter thread down the middle of it.
			var count := 30
			var rope := Flowfx.Ribbon.new(TINT.water.lerp(Color(0.4, 0.75, 1.0), 0.3), 0.55, count, 2.4, 0.5)
			var vein := Flowfx.Ribbon.new(Color(0.7, 0.88, 1.0), 0.1, count, 1.4, 0.1)
			for r in [rope, vein]:
				r.fixed = true; r.taper = 0.75
				r.pts.resize(count); g.add_child(r)
			var side: Vector3 = e.dir.cross(Vector3.UP)
			var reach: float = b.range
			var tw := g.create_tween()
			tw.tween_method(func(f: float) -> void:
				if not is_instance_valid(rope) or not is_instance_valid(vein):
					return
				# Out fast (first quarter), then drawn back in.
				var ext := smoothstep(0.0, 0.22, f) * (1.0 - smoothstep(0.35, 1.0, f) * 0.85)
				for i in count:
					var u := i / float(count - 1)
					var wave := sin(u * 9.0 - f * 26.0) * 0.55 * u * (1.0 - smoothstep(0.1, 0.3, f) * 0.6)
					var p: Vector3 = from + e.dir * (0.4 + reach * ext * u) + side * wave + Vector3(0, -0.7 * u * ext + 0.3 * sin(u * PI) * (1.0 - f) + 0.25 * cos(u * 7.0 - f * 20.0) * u * (1.0 - f), 0)
					rope.pts[i] = p; vein.pts[i] = p
				rope.gain = 1.0 - smoothstep(0.8, 1.0, f); vein.gain = rope.gain, 0.0, 1.0, 0.75)
			tw.tween_callback(func() -> void:
				for m in [rope, vein]:
					if is_instance_valid(m): m.queue_free())
			for i in 5:
				var p: Vector3 = g._ground(feet + e.dir * (reach * (i + 1) / 5.0)) + Vector3(0, 0.7, 0)
				g.get_tree().create_timer(0.03 * i).timeout.connect(func() -> void:
					if is_instance_valid(g):
						_once(_particles(TINT.water.lerp(Color.WHITE, 0.3), 26, 0.6, 0.16, 4.0, -9.0, 120.0), g, p))
			Sfx.play(g, "crack", from + e.dir * reach * 0.7, -4.0, 2.2)
			Sfx.play(g, "whoosh", from, 2.0, 1.6)
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
			# The blow itself: threads of Air thrown out in a spreading fan.
			var up := Vector3.UP
			var sd: Vector3 = e.dir.cross(up).normalized()
			for i in 9:
				var ang := (i - 4) * 0.11
				var d: Vector3 = (e.dir * cos(ang) + sd * sin(ang)).normalized()
				var lift := Vector3(0, randf_range(-0.5, 0.9), 0)
				Flowfx.streak(g, from + sd * (i - 4) * 0.08, from + d * b.range + lift, 0.2 + randf() * 0.1, col.lerp(Color.WHITE, 0.3), 0.3, (sd * randf_range(-1, 1) + up * randf_range(-0.4, 0.6)) * 0.8, 1.6, 0.6)
			# Water goes out as spray; Air only lifts the dust.
			var wet: bool = Rules.weaves[e.weave].flows.has("water")
			_once(_particles(TINT.water.lerp(Color.WHITE, 0.3) if wet else Color(0.6, 0.56, 0.5), 70 if wet else 40, 0.7, 0.35 if wet else 0.4, 9.0 if wet else 8.0, -6.0 if wet else 0.5, 30.0, wet), g, feet + e.dir * 2.0 + Vector3(0, 0.6, 0))
			Sfx.play(g, "thud", from, 4.0, 0.7)
		"barrier":
			var mi := Flowfx.shell(1.0, Color(0.7, 0.85, 1.0), 2.5)
			g.add_child(mi); mi.position = feet + Vector3(0, 1.0, 0); mi.scale = Vector3.ONE * 0.5
			var tw := g.create_tween().set_parallel()
			tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi.material_override, "shader_parameter/fade", 0.0, 0.9)
			tw.chain().tween_callback(mi.queue_free)
			Sfx.play(g, "chime", from, -2.0, 0.8)
		"heal":
			# Healing: threads of Spirit, Water and Air go from the hands into the one
			# healed, then wind up round them from the feet to over the head.
			var who: Vector3 = g._ground(e.at)
			var gold := Color(0.75, 1.0, 0.7)
			for i in 3:
				Flowfx.streak(g, from, who + Vector3(0, 1.2, 0), 0.25 + 0.06 * i, [TINT.spirit, TINT.water, TINT.air][i], 0.1, Vector3(randf_range(-0.6, 0.6), 0.5 + 0.3 * i, randf_range(-0.6, 0.6)), 2.5, 0.2)
			for i in 3:
				var r := Flowfx.Ribbon.new(gold, 0.12, 26, 2.2, 0.25)
				r.follow = false; g.add_child(r)
				var tw := g.create_tween()
				tw.tween_interval(0.25)
				tw.tween_method(func(f: float) -> void:
					if is_instance_valid(r):
						var a := f * 9.0 + i * TAU / 3.0
						r.push(who + Vector3(cos(a) * 0.55, 0.1 + 2.1 * f, sin(a) * 0.55)), 0.0, 1.0, 1.0)
				tw.tween_property(r, "gain", 0.0, 0.4)
				tw.tween_callback(r.queue_free)
			var hl := _light(gold, 0.0, 5.0); g.add_child(hl); hl.position = who + Vector3(0, 1.2, 0)
			var tl := g.create_tween()
			tl.tween_property(hl, "light_energy", 3.0, 0.4); tl.tween_property(hl, "light_energy", 0.0, 1.0); tl.tween_callback(hl.queue_free)
			_once(_particles(Color(0.5, 1.0, 0.7), 24, 1.4, 0.08, 0.8, 1.2, 40.0), g, who + Vector3(0, 0.4, 0))
			Sfx.play(g, "chime", from, -2.0)
		"sever":
			# A shield: Spirit thrown across and closed round them like a hand.
			var tgt: Vector3 = g._ground(e.at) + Vector3(0, 1.3, 0)
			for i in 4:
				Flowfx.streak(g, from, tgt, 0.16 + 0.03 * i, TINT.spirit, 0.09, Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * 0.9, 2.5, 0.1)
			var sh := Flowfx.shell(1.0, TINT.spirit, 2.5)
			g.add_child(sh); sh.position = tgt; sh.scale = Vector3.ONE * 2.6
			var ts := g.create_tween().set_parallel()
			ts.tween_property(sh, "scale", Vector3.ONE * 1.05, 0.3).set_ease(Tween.EASE_IN).set_delay(0.15)
			ts.tween_property(sh.material_override, "shader_parameter/fade", 0.0, 0.5).set_delay(0.45)
			ts.chain().tween_callback(sh.queue_free)
			Sfx.play(g, "chime", from, -4.0, 0.6)
