class_name Hitboxes
## --hitboxes: what the sim collides with, drawn over what the view shows, so the two
## can be compared in a render: walls as the boxes the sim keeps people out of
## (turned as the sim turns them, `h` high), trees and props as their circles, deep
## water's unwalkable core, and the edge of the map where walking stops.

static func draw(root: Node3D) -> void:
	var lines := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	lines.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for w in Map.walls():
		var y0 := Terrain.height(w.x, w.z)
		var cs := []
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			cs.append(Map._world(w, Vector2(c.x * w.hx, c.y * w.hz)))
		for i in 4:
			var a: Vector2 = cs[i]; var b: Vector2 = cs[(i + 1) % 4]
			for y in [y0 + 0.03, y0 + float(w.h)]:
				_line(lines, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Color(1, 0.2, 0.2))
			_line(lines, Vector3(a.x, y0, a.y), Vector3(a.x, y0 + float(w.h), a.y), Color(1, 0.2, 0.2))
	for t in Map.trees():
		var y0 := Terrain.height(t.x, t.z)
		var col := Color(0.2, 1, 0.3) if t.has("prop") else Color(0.3, 0.8, 1)
		for y in [y0 + 0.03, y0 + float(t.h)]:
			_circle(lines, Vector3(t.x, y, t.z), float(t.r), col)
		_line(lines, Vector3(t.x + float(t.r), y0, t.z), Vector3(t.x + float(t.r), y0 + float(t.h), t.z), col)
	for w: Dictionary in Map.water():
		if w.deep:
			_circle(lines, Vector3(w.x1, float(w.y) + 0.05, w.z1), float(w.r) * 0.6, Color(0.3, 0.4, 1))
	# The edge of the walkable ground, sampled round it.
	var ring := Map.edge_points()
	for i in ring.size():
		var a: Vector3 = ring[i]; var b: Vector3 = ring[(i + 1) % ring.size()]
		_line(lines, a + Vector3(0, 0.3, 0), b + Vector3(0, 0.3, 0), Color(1, 0.9, 0.2))
	lines.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = lines
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func _line(m: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	m.surface_set_color(c); m.surface_add_vertex(a)
	m.surface_set_color(c); m.surface_add_vertex(b)

static func _circle(m: ImmediateMesh, at: Vector3, r: float, c: Color) -> void:
	for i in 16:
		var a0 := TAU * i / 16.0; var a1 := TAU * (i + 1) / 16.0
		_line(m, at + Vector3(cos(a0), 0, sin(a0)) * r, at + Vector3(cos(a1), 0, sin(a1)) * r, c)
