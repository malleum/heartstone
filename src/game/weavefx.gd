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
		"projectile" when weave != "" and Rules.weaves[weave].get("dart", false):
			# A dart of fire: a thin white-hot streak, fast, with almost no glow
			# around it. The game turns it along its flight.
			var c := CylinderMesh.new(); c.top_radius = 0.012; c.bottom_radius = 0.035; c.height = 1.1; c.radial_segments = 6; c.rings = 1
			var core := _mesh(c, Color(1.0, 0.9, 0.7), 9.0)
			core.rotation.x = PI * 0.5; core.position.z = 0.45
			n.add_child(core)
			var tail := CylinderMesh.new(); tail.top_radius = 0.0; tail.bottom_radius = 0.06; tail.height = 5.0; tail.radial_segments = 6; tail.rings = 1
			var tm := _mesh(tail, Color(1.0, 0.45, 0.1, 0.4), 3.0)
			tm.rotation.x = -PI * 0.5; tm.position.z = 2.7
			n.add_child(tm)
			n.add_child(_light(TINT.fire, 1.2, 3.5))
			n.set_meta("aimed", true)
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
			n.free()
			n = Wedge.new()
			(n as Wedge).half = deg_to_rad(float(Rules.weaves[weave].base.get("arc", 180.0))) if weave != "" else PI
			g.add_child(n)
		"blossom":
			n.free()
			n = Blossom.new()
			g.add_child(n)
		"missile":
			var mm := Armoury.missile(weave)
			# Small things are drawn larger than life in the air, or they are not seen.
			var small: bool = weave in ["throwing_knives", "belt_knife", "sling"]
			if small:
				mm.scale = Vector3.ONE * 2.2
			n.add_child(mm)
			# A pale streak behind it, so the eye can follow where it went.
			var tail := CylinderMesh.new(); tail.top_radius = 0.0; tail.bottom_radius = 0.035 if small else 0.022; tail.height = 2.4; tail.radial_segments = 5; tail.rings = 1
			var tm := _mesh(tail, Color(1.0, 0.97, 0.9, 0.45), 2.5)
			tm.rotation.x = -PI * 0.5; tm.position.z = 1.3
			n.add_child(tm)
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
	const HANDS := Vector3(0, 1.25, 0.5)

	func _ready() -> void:
		var fl: Dictionary = Rules.weaves[weave].flows
		var k := 0
		for e in fl:
			# A big weave shows more threads of each Power, so it looks like more work.
			for i in int(fl[e]) * 2:
				var n := Node3D.new(); add_child(n)
				var sp := SphereMesh.new(); sp.radius = 0.05; sp.height = 0.1
				n.add_child(Weavefx._mesh(sp, Weavefx.TINT[e].lerp(Color.WHITE, 0.35), 8.0))
				var tr: GPUParticles3D
				match e:
					"fire": tr = Weavefx._particles(Weavefx.TINT.fire, 46, 0.5, 0.13, 1.4, 2.5, 50.0)
					"earth": tr = Weavefx._particles(Color(0.85, 0.55, 0.2), 30, 0.7, 0.16, 0.5, -3.5, 70.0)
					"air": tr = Weavefx._particles(Weavefx.TINT.air, 60, 0.35, 0.1, 0.1, 0.0)
					"water": tr = Weavefx._particles(Weavefx.TINT.water.lerp(Color.WHITE, 0.2), 46, 0.6, 0.12, 0.3, -4.0, 40.0)
					_: tr = Weavefx._particles(Weavefx.TINT.spirit, 30, 0.5, 0.09, 0.05, 0.0)
				n.add_child(tr)
				parts.append([n, e, k]); k += 1
		var col := Weavefx.colour(weave)
		var cs := SphereMesh.new(); cs.radius = 0.16; cs.height = 0.32
		core = Weavefx._mesh(cs, col.lerp(Color.WHITE, 0.25), 6.0)
		core.position = HANDS; add_child(core)
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
	var scorch: MeshInstance3D
	var lamp: OmniLight3D
	const ARMS := 5
	const PER := 9

	func _ready() -> void:
		# The pillar: six feet of fire, no wider than a man.
		pillar = Weavefx._particles(Color(1.0, 0.35, 0.06), 90, 0.45, 0.22, 4.4, 3.0, 5.0)
		pillar.position.y = -1.0
		add_child(pillar)
		for a in ARMS:
			for j in PER:
				# Small deep-orange tongues, close together: an arm of flame, not a cloud.
				var e := Weavefx._particles(Color(1.0, 0.28, 0.04), 22, 0.55, 0.4 + 0.25 * j / PER, 1.0, 2.6, 22.0)
				# Dimmer than a fireball's flame: many overlap, and it must stay orange.
				((e.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.5, 0.5, 0.5)
				e.emitting = false
				add_child(e)
				arms.append([e, a, (j + 1.0) / PER])
		var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.04
		scorch = Weavefx._mesh(c, Color(0.9, 0.22, 0.03, 0.2), 0.6)
		scorch.position.y = -1.12
		add_child(scorch)
		lamp = Weavefx._light(Weavefx.TINT.fire, 3.0, 8.0)
		add_child(lamp)

	func set_r(radius: float, _yaw: float) -> void:
		r = radius

	func _process(dt: float) -> void:
		age += dt
		spin += dt * 0.75
		var open := r > 1.0
		pillar.emitting = age < 1.0
		scorch.scale = Vector3(r, 1.0, r)
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
		var rock := StandardMaterial3D.new()
		rock.albedo_color = Color(0.2, 0.15, 0.11); rock.roughness = 1.0
		rock.emission_enabled = true; rock.emission = Color(1.0, 0.3, 0.05); rock.emission_energy_multiplier = 0.5
		for i in N:
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.42 + 0.2 * randf(); c.height = 1.3 + randf() * 0.9; c.radial_segments = 5; c.rings = 1
			var mi := MeshInstance3D.new(); mi.mesh = c; mi.material_override = rock
			mi.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
			add_child(mi); teeth.append(mi)
			var f := Weavefx._particles(Color(1.0, 0.3, 0.05), 20, 0.5, 0.5, 1.2, 2.8, 30.0)
			((f.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.55)
			add_child(f); fires.append(f)
		# Dust thrown up behind the front.
		var d := Weavefx._particles(Color(0.36, 0.28, 0.2), 60, 1.1, 1.1, 2.0, 0.8, 80.0, false)
		d.name = "Dust"; add_child(d)
		lamp = Weavefx._light(Weavefx.TINT.fire, 6.0, 12.0); add_child(lamp)

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
			var h: float = ((teeth[i] as MeshInstance3D).mesh as CylinderMesh).height
			(teeth[i] as MeshInstance3D).position = at + Vector3(0, -1.2 - h * 0.5 + h * (0.25 + 0.75 * up), 0)
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
			var s := SphereMesh.new(); s.radius = 1.5; s.height = 3.0
			var mi := _mesh(s, Color(col, 0.05), 0.4); mi.position.y = 1.0
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
			var s := SphereMesh.new(); s.radius = 0.2; s.height = 0.4
			var mi := _mesh(s, Color(col, 0.8), 4.0); mi.position.y = 2.3
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
static func gate(g: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var n := Node3D.new(); g.add_child(n)
	for side in [[a, b], [b, a]]:
		var q := QuadMesh.new(); q.size = Vector2(1.9, 2.9)
		var mi := MeshInstance3D.new(); mi.mesh = q
		var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/portal.gdshader")
		sm.set_shader_parameter("tint", Color(0.75, 0.85, 1.0)); sm.set_shader_parameter("lit", 1.0)
		mi.material_override = sm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		mi.position = g._ground(side[0]) + Vector3(0, 1.5, 0)
		var away: Vector3 = (side[1] - side[0]) * Vector3(1, 0, 1)
		mi.rotation.y = atan2(away.x, away.z)
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
	if Rules.weaves[weave].get("dart", false):
		spit(g, at, col)
		return
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

static var _rock: StandardMaterial3D

## One spike of rock driven up out of the ground: it erupts, stands a moment,
## and sinks back.
static func spike(g: Node3D, at: Vector3, height: float, lean: Vector3) -> void:
	if _rock == null:
		_rock = StandardMaterial3D.new()
		_rock.albedo_color = Color(0.3, 0.24, 0.18); _rock.roughness = 1.0
	var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.2 + height * 0.2; c.height = height; c.radial_segments = 5; c.rings = 1
	var mi := MeshInstance3D.new(); mi.mesh = c; mi.material_override = _rock
	g.add_child(mi)
	mi.rotation = lean
	mi.position = at - Vector3(0, height * 0.6, 0)
	var tw := g.create_tween()
	tw.tween_property(mi, "position:y", at.y + height * 0.38, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.1 + randf() * 0.5)
	tw.tween_property(mi, "position:y", at.y - height * 0.7, 0.7).set_ease(Tween.EASE_IN)
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
			var beads: Array[MeshInstance3D] = []
			var count := 22
			for i in count:
				var sp := SphereMesh.new(); sp.radius = 0.11 - 0.07 * i / count; sp.height = sp.radius * 2.0
				var mi := _mesh(sp, TINT.water.lerp(Color.WHITE, 0.35), 4.0)
				g.add_child(mi); beads.append(mi)
			var side: Vector3 = e.dir.cross(Vector3.UP)
			var reach: float = b.range
			var tw := g.create_tween()
			tw.tween_method(func(f: float) -> void:
				# Out fast (first quarter), then drawn back in.
				var ext := smoothstep(0.0, 0.22, f) * (1.0 - smoothstep(0.35, 1.0, f) * 0.85)
				for i in count:
					if not is_instance_valid(beads[i]):
						continue
					var u := (i + 1.0) / count
					var wave := sin(u * 9.0 - f * 26.0) * 0.55 * u * (1.0 - smoothstep(0.1, 0.3, f) * 0.6)
					beads[i].position = from + e.dir * (reach * ext * u) + side * wave + Vector3(0, -0.7 * u * ext + 0.3 * sin(u * PI) * (1.0 - f), 0), 0.0, 1.0, 0.75)
			tw.tween_callback(func() -> void:
				for m in beads:
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
