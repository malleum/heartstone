class_name Dreamfx
extends RefCounted
## What dream moves look like (see Dream, data/dream.json). Tel'aran'rhiod's own
## colour is a pale, cold silver-violet: nothing here is one of the Five Powers.

const PALE := Color(0.72, 0.7, 1.0)

## Gone from here, there at once: the place left folds in on itself, the place
## arrived at opens, and a thread joins them for an instant.
static func shift(g: Node3D, from: Vector3, to: Vector3) -> void:
	for end in [[from, 1.25, 0.15], [to, 0.2, 1.25]]:
		var sh := Flowfx.shell(1.0, PALE, 2.2)
		g.add_child(sh); sh.position = end[0] + Vector3(0, 1.1, 0); sh.scale = Vector3(end[1], end[1] * 1.3, end[1])
		var tw := g.create_tween().set_parallel()
		tw.tween_property(sh, "scale", Vector3(end[2], end[2] * 1.3, end[2]), 0.22).set_ease(Tween.EASE_OUT)
		tw.tween_property(sh.material_override, "shader_parameter/fade", 0.0, 0.3)
		tw.chain().tween_callback(sh.queue_free)
	Flowfx.beam(g, from + Vector3(0, 1.1, 0), to + Vector3(0, 1.1, 0), 0.12, PALE, 1.6, 0.4, 0.3)
	Weavefx._once(Weavefx._particles(PALE, 18, 0.5, 0.07, 2.5, 0.5), g, to + Vector3(0, 1.1, 0))
	Sfx.play(g, "whoosh", to + Vector3(0, 1.2, 0), -3.0, 1.9)

## Deny: a hard bright shell that is there for the instant it matters.
static func deny(g: Node3D, who: Node3D, secs: float, held := false) -> void:
	var sh := Flowfx.shell(1.0, Color(1.0, 0.95, 0.8) if held else PALE, 1.5 if held else 0.8)
	who.add_child(sh); sh.position.y = 1.1; sh.scale = Vector3(0.7, 1.1, 0.7) * (1.15 if held else 1.0)
	var tw := who.create_tween()
	tw.tween_property(sh.material_override, "shader_parameter/fade", 0.0, secs + (0.35 if held else 0.0))
	tw.tween_callback(sh.queue_free)
	if held:
		Sfx.play(g, "chime", who.position + Vector3(0, 1.2, 0), 0.0, 1.7)

## Chains closing on someone: links of pale light drawing in round them for
## `wind` seconds (the warning), and if they take, iron bands for `secs`.
static func chain_wind(g: Node3D, at: Vector3, wind: float) -> void:
	for i in 4:
		var a := i * TAU / 4.0
		Flowfx.streak(g, at + Vector3(cos(a) * 3.2, 2.6, sin(a) * 3.2), at + Vector3(cos(a) * 0.5, 0.9, sin(a) * 0.5), wind, PALE, 0.09, Vector3(-sin(a), 0.2, cos(a)) * 1.2, 2.0, 0.2)

static func chains(who: Node3D, secs: float) -> Node3D:
	var n := Node3D.new(); n.name = "Chains"
	who.add_child(n)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.2, 0.24); iron.metallic = 0.9; iron.roughness = 0.4
	iron.emission_enabled = true; iron.emission = PALE; iron.emission_energy_multiplier = 0.5
	for y in [0.5, 0.95, 1.4]:
		var t := TorusMesh.new(); t.inner_radius = 0.46; t.outer_radius = 0.52; t.rings = 28; t.ring_segments = 6
		var mi := MeshInstance3D.new(); mi.mesh = t; mi.material_override = iron
		mi.position.y = y; mi.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		n.add_child(mi)
	who.get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(n): n.queue_free())
	return n

## Where the ground is about to turn: a ring that closes in over `wind` seconds.
static func pit_warn(g: Node3D, at: Vector3, radius: float, wind: float) -> void:
	var t := TorusMesh.new(); t.inner_radius = 0.95; t.outer_radius = 1.0; t.rings = 48; t.ring_segments = 5
	var mi := Weavefx._mesh(t, Color(PALE, 0.8), 2.5)
	g.add_child(mi); mi.position = at + Vector3(0, 0.08, 0); mi.scale = Vector3(radius * 1.6, 1, radius * 1.6)
	var tw := g.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), wind).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)

## The things that last, drawn from the sim's effect list (Weavefx.live hands
## these kinds here). The game puts the node 1.2 m above the ground at its place.
static func live(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"dream_bolt":
			# A spear of pale light, turned along its flight by the game.
			var m := Armoury.missile("aiel_spear")
			n.add_child(m)
			var glow := Flowfx.ball(0.5, PALE, 1.4, 0.05); glow.scale = Vector3(0.12, 0.12, 1.6)
			n.add_child(glow)
			n.add_child(Flowfx.Ribbon.new(PALE, 0.16, 14, 2.0, 0.2))
			n.add_child(Weavefx._light(PALE, 1.5, 5.0))
			n.set_meta("aimed", true)
		"dream_pit":
			# The ground turned against whoever stands on it: a dark churning round
			# with hands of earth reaching up out of it.
			var c := CylinderMesh.new(); c.top_radius = 1.0; c.bottom_radius = 1.0; c.height = 0.04
			var disc := Weavefx._mesh(c, Color(0.03, 0.02, 0.05, 0.75), 0.0)
			disc.position.y = -1.14; disc.name = "Disc"
			n.add_child(disc)
			var t := TorusMesh.new(); t.inner_radius = 0.95; t.outer_radius = 1.0; t.rings = 48; t.ring_segments = 5
			var rim := Weavefx._mesh(t, Color(PALE, 0.7), 2.0); rim.position.y = -1.12; rim.name = "Rim"
			n.add_child(rim)
			for i in 9:
				var sh := Flowfx.shard(randf_range(0.5, 1.1), 0.12)
				var a := randf() * TAU; var r := sqrt(randf()) * 0.85
				sh.position = Vector3(cos(a) * r, -1.25, sin(a) * r); sh.set_meta("at", Vector2(cos(a) * r, sin(a) * r))
				sh.rotation = Vector3(randf_range(-0.5, 0.5), randf() * TAU, randf_range(-0.5, 0.5))
				n.add_child(sh)
			n.set_script(load("res://src/game/dreampit.gd"))
		"dream_wall":
			# A wall of old stone that was not there: dry courses of rough blocks,
			# no two alike, built one unit wide and stretched to the sim's width.
			var stone := Node3D.new(); stone.name = "Stone"
			var mats := []
			for g in [0.15, 0.22, 0.3]:
				var st := StandardMaterial3D.new(); st.albedo_color = Color(g, g, g * 1.12); st.roughness = 1.0
				st.emission_enabled = true; st.emission = PALE; st.emission_energy_multiplier = 0.03
				mats.append(st)
			var rng := RandomNumberGenerator.new(); rng.seed = 7
			var y := 0.0
			for course in 4:
				var h := rng.randf_range(0.45, 0.62)
				var x := -0.5 + (0.0 if course % 2 == 0 else -0.06)
				while x < 0.5:
					var w := minf(rng.randf_range(0.1, 0.17), 0.5 - x) if course < 3 else rng.randf_range(0.08, 0.13)
					if course == 3 and rng.randf() < 0.35:
						x += w; continue   # a broken top
					var b := BoxMesh.new(); b.size = Vector3(w * 0.96, h * 0.97, rng.randf_range(0.42, 0.56))
					var mi := MeshInstance3D.new(); mi.mesh = b
					mi.material_override = mats[rng.randi() % 3]
					mi.position = Vector3(x + w * 0.5, y + h * 0.5, rng.randf_range(-0.04, 0.04))
					mi.rotation = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.02, 0.02))
					stone.add_child(mi)
					x += w
				y += h
			n.add_child(stone)
			n.set_script(load("res://src/game/dreamwall.gd"))
	return n
