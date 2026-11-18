class_name Flowfx
extends RefCounted
## The pieces weave visuals are built from: ribbons that follow a moving point
## (the threads of the Power), a boiling ball of fire, a rim-lit shell. Weavefx
## says what each weave looks like; this is how the parts are drawn.

static var _noise: ImageTexture

## One seamless noise texture for every effect, made at once (a NoiseTexture2D
## fills in on a thread, and the first weave of a session would be blank).
static func noise() -> ImageTexture:
	if _noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.022; fn.fractal_octaves = 3; fn.seed = 7
		var img := fn.get_seamless_image(256, 256)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise

static func ribbon_mat(col: Color, energy := 3.0, rough := 0.4, flow := 2.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fx_ribbon.gdshader")
	m.set_shader_parameter("tint", col); m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("rough", rough); m.set_shader_parameter("flow", flow)
	m.set_shader_parameter("noise", noise())
	return m

static func fire_mat(hot: Color, cool: Color, energy := 3.0, swell := 0.25, speed := 1.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fx_fire.gdshader")
	m.set_shader_parameter("hot", hot); m.set_shader_parameter("cool", cool)
	m.set_shader_parameter("energy", energy); m.set_shader_parameter("swell", swell)
	m.set_shader_parameter("speed", speed); m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("burn", 0.0)   # set, so a tween can find it
	return m

## A ball of the Power in a weave's colour. For fire, pass nothing: it gets the
## white-yellow-orange of flame; any other colour runs white to itself.
static func ball(radius: float, col: Color, energy := 3.0, swell := 0.25) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = radius; s.height = radius * 2.0; s.radial_segments = 32; s.rings = 16
	var mi := MeshInstance3D.new(); mi.mesh = s
	var fiery := col.r > 0.8 and col.b < 0.4
	mi.material_override = fire_mat(Color(1.0, 0.85, 0.45) if fiery else col.lerp(Color.WHITE, 0.75), Color(0.9, 0.2, 0.02) if fiery else col * 0.8, energy, swell * radius * 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func shell(radius: float, col: Color, energy := 1.0) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = radius; s.height = radius * 2.0; s.radial_segments = 48; s.rings = 24
	var mi := MeshInstance3D.new(); mi.mesh = s
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fx_shell.gdshader")
	m.set_shader_parameter("tint", col); m.set_shader_parameter("energy", energy); m.set_shader_parameter("noise", noise())
	m.set_shader_parameter("fade", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A strip that trails behind wherever its parent goes (or behind points pushed
## to it), always turned to face the camera. It lives in world space, so a moving
## thing drags it; `keep` points long, thinning to nothing at the tail.
class Ribbon extends MeshInstance3D:
	var pts: PackedVector3Array = []
	var keep := 20
	var width := 0.05
	var follow := true        # take the parent's position each frame
	var fixed := false        # the points are set whole from outside (a whip, a bolt)
	var gain := 1.0           # multiplies the brightness: tween it to 0 to fade the thing out
	var taper := 1.0          # 1: thins to a point at the tail; 0: one width all along
	var im := ImmediateMesh.new()

	func _init(col := Color.WHITE, w := 0.05, n := 20, energy := 3.0, rough := 0.4) -> void:
		width = w; keep = n
		mesh = im
		material_override = Flowfx.ribbon_mat(col, energy, rough)
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		top_level = true
		extra_cull_margin = 16000.0

	func _ready() -> void:
		global_transform = Transform3D.IDENTITY

	func push(p: Vector3) -> void:
		pts.insert(0, p)
		if pts.size() > keep:
			pts.resize(keep)

	func _process(_dt: float) -> void:
		global_transform = Transform3D.IDENTITY
		if follow and not fixed and get_parent() is Node3D:
			push((get_parent() as Node3D).global_position)
		im.clear_surfaces()
		var n := pts.size()
		var cam := get_viewport().get_camera_3d()
		if n < 2 or cam == null or gain <= 0.001:
			return
		var eye := cam.global_position
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var p := pts[i]
			var along := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)])
			var side := along.cross(eye - p)
			side = side.normalized() if side.length_squared() > 1e-10 else Vector3.UP
			var u := i / float(n - 1)
			var w := width * 0.5 * lerpf(1.0, 1.0 - u, taper)
			# The tail fades; a fixed strip fades at both ends so neither is cut square.
			var a := ((minf(1.0, minf(u, 1.0 - u) * 12.0) if taper == 0.0 else sin(u * PI)) if fixed else minf(1.0, i * 0.7) * (1.0 - u)) * gain
			im.surface_set_color(Color(1, 1, 1, a))
			im.surface_set_uv(Vector2(u * n * 0.12, 0.0)); im.surface_add_vertex(p + side * w)
			im.surface_set_color(Color(1, 1, 1, a))
			im.surface_set_uv(Vector2(u * n * 0.12, 1.0)); im.surface_add_vertex(p - side * w)
		im.surface_end()

## A thread thrown from a to b: its head runs the line in `secs` (bowed sideways
## by `bow` metres on the way), the tail follows and it is gone.
static func streak(g: Node3D, a: Vector3, b: Vector3, secs: float, col: Color, width := 0.08, bow := Vector3.ZERO, energy := 3.5, rough := 0.4) -> void:
	var r := Ribbon.new(col, width, 14, energy, rough)
	r.follow = false
	g.add_child(r)
	var tw := g.create_tween()
	tw.tween_method(func(f: float) -> void:
		if is_instance_valid(r):
			r.push(a.lerp(b, f) + bow * sin(f * PI)), 0.0, 1.0, secs)
	tw.tween_property(r, "gain", 0.0, 0.25)
	tw.tween_callback(r.queue_free)

## A bar of the Power from a to b, all there at once and then fading: a still
## ribbon, shaken a little along its length when `jitter` is set.
static func beam(g: Node3D, a: Vector3, b: Vector3, width: float, col: Color, energy: float, rough: float, secs: float, jitter := 0.0) -> Ribbon:
	var n := 28
	var r := Ribbon.new(col, width, n, energy, rough)
	r.fixed = true; r.taper = 0.0
	r.pts.resize(n)
	for i in n:
		var u := i / float(n - 1)
		r.pts[i] = a.lerp(b, u) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter * sin(u * PI)
	g.add_child(r)
	var tw := g.create_tween()
	tw.tween_property(r, "gain", 0.0, secs).set_ease(Tween.EASE_IN)
	tw.tween_callback(r.queue_free)
	return r

static var _stone: StandardMaterial3D

## A shard of rock: a crooked, flat-faced spike with a kink in it, not a cone.
## Its base is at the origin and it stands `height` tall.
static func shard(height: float, girth: float) -> MeshInstance3D:
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.vertex_color_use_as_albedo = true; _stone.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 5
	var base: Array = []; var mid: Array = []
	var lean := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * girth * 0.5
	var tip := Vector3(lean.x * 1.6, height, lean.z * 1.6)
	for i in n:
		var a := (i + randf_range(-0.3, 0.3)) * TAU / n
		base.append(Vector3(cos(a), 0, sin(a)) * girth * randf_range(0.75, 1.25))
		mid.append(Vector3(cos(a), 0, sin(a)) * girth * randf_range(0.35, 0.7) + Vector3(lean.x, height * randf_range(0.45, 0.62), lean.z))
	for i in n:
		var j := (i + 1) % n
		# Each face its own shade of stone, darker earth at the foot.
		# (Vertex colours are linear: the old 0.1 to 0.19 came out the ground's own
		# beige, and the spikes read as card. Darker, greyer rock stands out of it.)
		var c := Color(0.055, 0.052, 0.05).lerp(Color(0.13, 0.12, 0.11), randf())
		var foot := Color(0.04, 0.03, 0.022)
		for tri in [[base[i], mid[i], base[j], foot, c, foot], [base[j], mid[i], mid[j], foot, c, c], [mid[i], tip, mid[j], c, c.lightened(0.15), c]]:
			for k in 3:
				st.set_color(tri[3 + k]); st.add_vertex(tri[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit(); mi.material_override = _stone
	return mi
