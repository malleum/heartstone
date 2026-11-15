class_name Wings
extends Node3D
## A Draghkar's wings: two leathery membranes on finger bones, hung from its back.
## Folded they trail behind it like a cloak; spread they carry it. The game sets
## `spread` (0 folded .. 1 flying) and they beat by themselves when spread.

var spread := 0.0
var _w: Array[Node3D] = []
var _t := 0.0

static func build(u: float) -> Wings:
	var out := Wings.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.025, 0.03); mat.roughness = 0.95; mat.metallic_specular = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.09, 0.07, 0.07); bone.roughness = 0.6
	# The arm runs out and up to the wrist; three fingers fan from there, and the
	# skin between them hangs in scallops down to the hip.
	var root := Vector3(0, 0, 0); var wrist := Vector3(0.85, 0.42, 0)
	var tips := [Vector3(2.05, 0.3, 0), Vector3(1.75, -0.75, 0), Vector3(1.05, -1.3, 0), Vector3(0.1, -1.35, 0)]
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		# The left wing is the right one mirrored in its own points: a mirrored node
		# (negative scale) cannot also be turned reliably.
		var flip := Vector3(side, 1, 1)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var edge: Array = [wrist]
		for i in tips.size():
			edge.append(tips[i])
			if i < tips.size() - 1:
				# The skin sags inward between two fingers.
				var mid: Vector3 = (tips[i] + tips[i + 1]) * 0.5
				edge.append(mid.lerp(wrist, 0.22))
		for i in range(1, edge.size() - 1):
			for v: Vector3 in [wrist, edge[i], edge[i + 1]]:
				st.set_normal(Vector3(0, 0, 1)); st.add_vertex(v * u * flip)
		for v: Vector3 in [root, wrist, tips[3]]:
			st.set_normal(Vector3(0, 0, 1)); st.add_vertex(v * u * flip)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit(); mi.material_override = mat
		pivot.add_child(mi)
		for seg in [[root, wrist, 0.035], [wrist, tips[0], 0.02], [wrist, tips[1], 0.018], [wrist, tips[2], 0.016]]:
			var a: Vector3 = seg[0] * u * flip; var b: Vector3 = seg[1] * u * flip
			var c := CylinderMesh.new(); c.top_radius = seg[2] * u * 0.5; c.bottom_radius = seg[2] * u; c.height = a.distance_to(b); c.radial_segments = 6; c.rings = 1
			var ci := MeshInstance3D.new(); ci.mesh = c; ci.material_override = bone
			ci.position = (a + b) * 0.5
			ci.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
			pivot.add_child(ci)
		out.add_child(pivot)
		out._w.append(pivot)
	return out

func _process(dt: float) -> void:
	_t += dt
	var beat := sin(_t * 7.0) * 0.45 * spread
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var p := _w[i]
		# Folded: swept back behind the shoulders and drawn in. Spread: straight out.
		p.rotation = Vector3(0, side * lerpf(1.45, 0.0, spread), 0)
		p.rotate_object_local(Vector3(0, 0, 1), side * (beat + lerpf(-0.25, 0.08, spread)))
		p.scale = Vector3(lerpf(0.5, 1.0, spread), 1, 1)
