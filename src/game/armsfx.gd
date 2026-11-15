class_name Armsfx
extends RefCounted
## What makes arms readable: the streak a blow leaves where it cuts (so it is plain
## what was in its path), the wedge on the ground where an enemy's blow is about
## to fall, and the small things that say where a missile went.

const TRAIL := preload("res://shaders/trail.gdshader")
const WARN := preload("res://shaders/warn.gdshader")

## A band swept round +Y from angle a0 to a1 (radians, 0 = +Z), between radii r0
## and r1. UV.x runs along the sweep, UV.y from inner to outer edge. `pinch` thins
## the band to nothing at both ends, which is what makes it a crescent.
static func _band(a0: float, a1: float, r0: float, r1: float, pinch: bool, segs := 20) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var u := i / float(segs)
		var a := lerpf(a0, a1, u)
		var inner := lerpf(r1, r0, sin(u * PI)) if pinch else r0
		st.set_uv(Vector2(u, 0.0)); st.add_vertex(Vector3(sin(a) * inner, 0, cos(a) * inner))
		st.set_uv(Vector2(u, 1.0)); st.add_vertex(Vector3(sin(a) * r1, 0, cos(a) * r1))
	return st.commit()

## A long thin point from the hand out to `reach`.
static func _lance(reach: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 9:
		var u := i / 8.0
		var w := width * sin(minf(u * 1.6, 1.0) * PI * 0.5) * (1.0 - u * u)
		st.set_uv(Vector2(u, 0.2)); st.add_vertex(Vector3(-w, 0, lerpf(0.4, reach, u)))
		st.set_uv(Vector2(u, 1.0)); st.add_vertex(Vector3(w, 0, lerpf(0.4, reach, u)))
	return st.commit()

static func _streak(g: Node3D, mesh: Mesh, xf: Transform3D, col: Color, secs: float, sweep := 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sm := ShaderMaterial.new(); sm.shader = TRAIL
	sm.set_shader_parameter("tint", col); sm.set_shader_parameter("sweep", sweep)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	mi.transform = xf
	var tw := g.create_tween()
	tw.tween_method(func(f: float) -> void: sm.set_shader_parameter("progress", f), 0.0, 1.0, secs)
	tw.tween_callback(mi.queue_free)

## The streak of one blow, by the move's `trail`: arc (a level cut), wide, down
## (an overhead blow, a standing crescent), low (at the shins), ring (all the way
## round), lance (a thrust), cross (two cuts), fan (a small quick tap), moon (one
## great tilted crescent). It is as long as the weapon reaches and as wide as the
## move's arc, a little generous, so what is inside it is what was struck.
static func trail(g: Node3D, feet: Vector3, dir: Vector3, reach: float, m: Dictionary, nth: int, hit: bool) -> void:
	var shape: String = m.get("trail", "arc")
	var tint: Array = m.get("tint", [0.92, 0.95, 1.0])
	var col := Color(tint[0], tint[1], tint[2])
	var arc := deg_to_rad(float(m.get("arc", 40.0)))
	var yaw := atan2(dir.x, dir.z)
	var face := Basis(Vector3.UP, yaw)
	var r1 := reach + 0.35
	var r0 := maxf(r1 - 1.1, 0.5)
	# Cuts alternate sides, as hands do.
	var flip := -1.0 if nth % 2 == 0 else 1.0
	var secs := 0.26 if hit else 0.2
	match shape:
		"lance":
			var side := face * Vector3(0.18 * flip if int(m.get("repeat", 1)) > 1 else 0.0, 0, 0)
			_streak(g, _lance(r1 + 0.3, 0.16 + 0.1 * minf(float(m.get("dmg", 1.0)), 2.0)), Transform3D(face * Basis(Vector3.FORWARD, 0.4 * flip), feet + Vector3(0, 1.2, 0) + side), col, 0.2, 0.6)
		"down":
			# A standing crescent in the plane of the blow: from over the head, down
			# in front. (The band's own +Z is turned up and its +X forward.)
			_streak(g, _band(-0.35, 1.9, r0, r1, true), Transform3D(face * Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), feet + Vector3(0, 1.0, 0)), col, secs + 0.04)
		"low":
			_streak(g, _band(-arc * flip, arc * flip, r0, r1, true), Transform3D(face, feet + Vector3(0, 0.3, 0)), col, secs)
		"ring":
			_streak(g, _band(-PI * flip, PI * flip, r0, r1, false, 40), Transform3D(face, feet + Vector3(0, 1.1, 0)), col, 0.4)
			_streak(g, _band(PI * flip, -PI * flip, r0 * 0.8, r1 * 0.8, false, 40), Transform3D(face, feet + Vector3(0, 1.45, 0)), col.lerp(Color.WHITE, 0.4), 0.5)
		"cross":
			for s in [-1.0, 1.0]:
				_streak(g, _band(-0.9 * s, 0.9 * s, r0, r1 + 0.3, true), Transform3D(face * Basis(Vector3.BACK, 0.8 * s), feet + Vector3(0, 1.25, 0)), col, 0.34)
		"fan":
			_streak(g, _band(-0.35 * flip, 0.35 * flip, r1 - 0.5, r1, true, 10), Transform3D(face * Basis(Vector3.RIGHT, -0.5), feet + Vector3(0, 1.75, 0)), col, 0.18)
		"moon":
			_streak(g, _band(-1.3, 1.3, r0 - 0.2, r1 + 0.5, true, 28), Transform3D(face * Basis(Vector3.BACK, -0.95), feet + Vector3(0, 1.3, 0)), col, 0.5)
			_streak(g, _band(-1.3, 1.3, r1 + 0.3, r1 + 0.6, true, 28), Transform3D(face * Basis(Vector3.BACK, -0.95), feet + Vector3(0, 1.3, 0)), Color.WHITE, 0.6)
		"wide":
			_streak(g, _band(-arc * flip, arc * flip, r0 - 0.2, r1 + 0.15, true, 28), Transform3D(face * Basis(Vector3.BACK, 0.12 * flip), feet + Vector3(0, 1.15, 0)), col, secs + 0.06)
		_:
			_streak(g, _band(-arc * flip, arc * flip, r0, r1, true), Transform3D(face * Basis(Vector3.BACK, 0.3 * flip), feet + Vector3(0, 1.2, 0)), col, secs)

## Where an enemy's blow will land, on the ground, from the moment it commits
## until it lands `secs` later: a wedge that fills outward. A blow that can be
## ducked is drawn paler; one that cannot, red.
static func telegraph(g: Node3D, feet: Vector3, yaw: float, reach: float, arc_deg: float, secs: float, height: String) -> void:
	var arc := deg_to_rad(arc_deg)
	var mi := MeshInstance3D.new()
	mi.mesh = _band(-arc, arc, 0.5, reach, false, 18)
	var sm := ShaderMaterial.new(); sm.shader = WARN
	sm.set_shader_parameter("tint", Color(1.0, 0.55, 0.1) if height == "high" else Color(1.0, 0.1, 0.05))
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), feet + Vector3(0, 0.12, 0))
	var tw := g.create_tween()
	tw.tween_method(func(f: float) -> void: sm.set_shader_parameter("fill", f), 0.0, 1.0, maxf(secs, 0.05))
	tw.tween_interval(0.08)
	tw.tween_callback(mi.queue_free)

## The line a Myrddraal has chosen to lunge along.
static func lunge_line(g: Node3D, feet: Vector3, yaw: float, dist: float, secs: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in 2:
		st.set_uv(Vector2(0, i)); st.add_vertex(Vector3(-0.55, 0, 0.6 + (dist - 0.6) * i))
		st.set_uv(Vector2(1, i)); st.add_vertex(Vector3(0.55, 0, 0.6 + (dist - 0.6) * i))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new(); sm.shader = WARN
	sm.set_shader_parameter("tint", Color(0.55, 0.0, 0.12))
	mi.material_override = sm
	g.add_child(mi)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), feet + Vector3(0, 0.14, 0))
	var tw := g.create_tween()
	tw.tween_method(func(f: float) -> void: sm.set_shader_parameter("fill", f), 0.0, 1.0, maxf(secs, 0.05))
	tw.tween_interval(0.35)
	tw.tween_callback(mi.queue_free)

## A perfect parry: a ring of light thrown off the steel.
static func ring_flash(g: Node3D, at: Vector3) -> void:
	var t := TorusMesh.new(); t.inner_radius = 0.9; t.outer_radius = 1.0
	var mi := Weavefx._mesh(t, Color(1.0, 0.95, 0.8), 9.0)
	g.add_child(mi); mi.position = at
	mi.scale = Vector3.ONE * 0.15
	mi.look_at_from_position(at, at + Vector3(0, 1, 0.01))
	var cam := g.get_viewport().get_camera_3d()
	if cam:
		mi.basis = Basis.looking_at(cam.global_position - at) * Basis(Vector3.RIGHT, PI * 0.5)
		mi.scale = Vector3.ONE * 0.15
	var tw := g.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.6, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
	var l := Weavefx._light(Color(1.0, 0.92, 0.75), 9.0, 8.0)
	g.add_child(l); l.position = at
	var tl := g.create_tween(); tl.tween_property(l, "light_energy", 0.0, 0.3); tl.tween_callback(l.queue_free)

## An arrow, a knife or a javelin standing in the body it struck, for a while.
static func stuck(body: Node3D, at: Vector3, dir: Vector3, weapon: String) -> void:
	if body.get_child_count() > 60:
		return
	var m := Armoury.missile(weapon)
	body.add_child(m)
	m.global_position = at - dir * 0.25
	if dir.length() > 0.1:
		m.global_basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)
	body.get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if is_instance_valid(m): m.queue_free())

## Where a missile met the ground: a puff of dust.
static func puff(g: Node3D, at: Vector3) -> void:
	Weavefx._once(Weavefx._particles(Color(0.5, 0.43, 0.34), 10, 0.5, 0.3, 2.0, 0.4, 70.0, false), g, at + Vector3(0, 0.1, 0))
