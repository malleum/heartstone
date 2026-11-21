class_name Terrain
extends RefCounted
## One analytic height function shared by the ground mesh and by foot placement,
## so feet can query the ground without physics raycasts.

static var _n: FastNoiseLite
static var amp := 1.0

static func height(x: float, z: float) -> float:
	var h := dry(x, z)
	# Water sits in a dip in the ground (Map.water).
	var bs := Map.basin(x, z)
	if not bs.is_empty():
		h = lerpf(h, bs.bed, bs.w)
	return h

## The ground before any water has been dug into it.
static func dry(x: float, z: float) -> float:
	if _n == null:
		_n = FastNoiseLite.new()
		_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_n.fractal_octaves = 3
		_n.frequency = 0.045
		_n.seed = 7
	# Broad swells plus knee-high lumps: enough to test foot planting.
	var h := (_n.get_noise_2d(x, z) * 1.1 + _n.get_noise_2d(x * 5.0 + 90.0, z * 5.0) * 0.16) * amp
	var r := Map.ridge(x, z)
	# Cliffs get their own craggy noise so they do not look extruded.
	return h + r * (0.8 + 0.35 * _n.get_noise_2d(x * 2.2 + 300.0, z * 2.2))

static func normal(x: float, z: float) -> Vector3:
	var e := 0.15
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()

## tree: given, the work is spread over frames (a few rows each), so building a
## world beside one being played (a camp doorway's far side) never stalls a frame.
static func build_mesh(size: float, step: float, tree: SceneTree = null) -> MeshInstance3D:
	var n := int(size / step)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var idx := PackedInt32Array()
	for j in n + 1:
		if tree and j % 12 == 0:
			await tree.process_frame
		for i in n + 1:
			var x := -size * 0.5 + i * step; var z := -size * 0.5 + j * step
			verts.append(Vector3(x, height(x, z), z))
			norms.append(normal(x, z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			idx.append_array([a, a + 1, a + n + 1, a + 1, a + n + 2, a + n + 1])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	# The wet banks round the map's water (the ground shader darkens them).
	var segs := []; var rs := []
	for w: Dictionary in Map.water().slice(0, 4):
		segs.append(Vector4(w.x1, w.z1, w.x2, w.z2)); rs.append(w.r)
	while segs.size() < 4:
		segs.append(Vector4.ZERO); rs.append(0.0)
	mat.set_shader_parameter("water_seg", segs); mat.set_shader_parameter("water_r", PackedFloat32Array(rs))
	mat.set_shader_parameter("water_n", mini(Map.water().size(), 4))
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi
