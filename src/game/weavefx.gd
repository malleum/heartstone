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

## A persistent effect the sim is tracking (projectile, gate, ring, pending blast).
static func live(g: Node3D, kind: String) -> Node3D:
	var n := Node3D.new()
	g.add_child(n)
	match kind:
		"projectile":
			var s := SphereMesh.new(); s.radius = 0.28; s.height = 0.56
			n.add_child(_mesh(s, TINT.fire, 7.0)); n.add_child(_light(TINT.fire, 3.0, 7.0))
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
