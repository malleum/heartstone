class_name World
extends RefCounted
## Sky, sun, fog: the shared look of every outdoor scene.

## sun_yaw 0 shines toward -Z (from behind a defender facing up a pass).
static func build(parent: Node, sun_yaw := 40.0, sun_pitch := -28.0) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.17, 0.23, 0.36); sky.sky_horizon_color = Color(0.68, 0.58, 0.48)
	sky.sky_curve = 0.09; sky.sun_angle_max = 22.0; sky.sun_curve = 0.12
	sky.ground_bottom_color = Color(0.08, 0.07, 0.06); sky.ground_horizon_color = Color(0.5, 0.45, 0.4)
	env.sky = Sky.new(); env.sky.sky_material = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true; env.fog_light_color = Color(0.56, 0.52, 0.5); env.fog_density = 0.006
	env.fog_aerial_perspective = 0.4
	# Weaves are the brightest things in the world: let them bloom.
	env.glow_enabled = true; env.glow_intensity = 0.9; env.glow_bloom = 0.15; env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new(); we.environment = env; parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0)
	sun.light_color = Color(1.0, 0.84, 0.68); sun.light_energy = 2.2
	sun.shadow_enabled = true; sun.directional_shadow_max_distance = 70.0
	parent.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, -150, 0)
	rim.light_color = Color(0.6, 0.72, 1.0); rim.light_energy = 0.5
	parent.add_child(rim)
