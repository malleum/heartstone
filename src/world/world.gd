class_name World
extends RefCounted
## Sky, sun, fog: the shared look of every outdoor scene.

## sun_yaw 0 shines toward -Z (from behind a defender facing up a pass).
static func build(parent: Node, sun_yaw := 40.0, sun_pitch := -28.0, night := false) -> void:
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
	if night:
		# A moon instead of the sun: cold, dim, high, so fires and weaves are the
		# light of the place. Kept bright enough to see a Trolloc at forty paces.
		sky.sky_top_color = Color(0.015, 0.02, 0.05); sky.sky_horizon_color = Color(0.07, 0.085, 0.14)
		sky.ground_horizon_color = Color(0.05, 0.06, 0.09); sky.ground_bottom_color = Color(0.01, 0.01, 0.015)
		sky.sun_angle_max = 3.0; sky.sun_curve = 0.02
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.2, 0.25, 0.4); env.ambient_light_energy = 0.55
		env.fog_light_color = Color(0.05, 0.06, 0.1); env.fog_density = 0.011
		env.glow_intensity = 1.2
		# Stars: points on a panorama laid over the sky (thinned toward the poles,
		# where a panorama's pixels crowd together).
		var img := Image.create(2048, 1024, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new(); rng.seed = 41
		for i in 2600:
			var v := acos(rng.randf_range(0.0, 1.0)) / PI      # upper half only
			var b := pow(rng.randf(), 3.0) * 0.9 + 0.1
			var c := Color(b, b, b * rng.randf_range(0.85, 1.2))
			var px := rng.randi_range(0, 2047); var py := int(v * 1023.0)
			img.set_pixel(px, py, c)
			if b > 0.6:
				img.set_pixel((px + 1) % 2048, py, c * 0.5); img.set_pixel(px, mini(py + 1, 1023), c * 0.5)
		sky.sky_cover = ImageTexture.create_from_image(img)
		sky.sky_cover_modulate = Color(1.6, 1.6, 1.8)
		sun.rotation_degrees = Vector3(-52.0, sun_yaw + 30.0, 0)
		sun.light_color = Color(0.62, 0.72, 1.0); sun.light_energy = 0.75
		rim.light_energy = 0.12
