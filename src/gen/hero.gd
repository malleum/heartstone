class_name Hero
## Player characters: sourced Quaternius bodies and outfits (assembled, with generated
## garments, by tools/blender/build_heroes.py), dressed here as Wheel of Time
## cultures. A look is data: which base model, which pieces show, and the colours.
## Shadowspawn stay generated; the player stares at this model all game.

const ANIMS := "res://assets/quaternius/ual1.glb"
const MODEL := "res://assets/quaternius/chars/%s.glb"
const OUTFIT := preload("res://shaders/outfit.gdshader")
const GARMENT := preload("res://shaders/garment.gdshader")
const HAIR := [Color(0.16, 0.1, 0.06), Color(0.38, 0.22, 0.1), Color(0.62, 0.3, 0.12), Color(0.75, 0.6, 0.33), Color(0.07, 0.06, 0.06)]
const AJAHS := {blue = Color(0.08, 0.16, 0.55), green = Color(0.07, 0.33, 0.12), yellow = Color(0.6, 0.47, 0.1), red = Color(0.5, 0.04, 0.04),
	white = Color(0.85, 0.85, 0.82), grey = Color(0.34, 0.34, 0.36), brown = Color(0.26, 0.15, 0.07)}

## base: model file. hide: mesh-name fragments to hide. p/s: cloth colours for the
## outfit shader (omit to keep the pack's own). Garments: [colour, style, trim].
## hair: mesh name to force; hood: true keeps hair hidden beneath it.
const LOOKS := {
	two_rivers_f = {label = "Two Rivers wool", sex = "f", base = "female_peasant", p = Color(0.78, 0.74, 0.62), s = Color(0.1, 0.16, 0.1),
		skirt = [Color(0.1, 0.17, 0.11), 4, Color(0.55, 0.5, 0.36)], hair = "Hair_Long"},
	novice = {label = "Novice white", sex = "f", base = "female_peasant", p = Color(0.88, 0.88, 0.86), s = Color(0.8, 0.8, 0.78),
		skirt = [Color(0.86, 0.86, 0.84), 0, Color.WHITE]},
	accepted = {label = "Accepted (banded hem)", sex = "f", base = "female_peasant", p = Color(0.88, 0.88, 0.86), s = Color(0.8, 0.8, 0.78),
		skirt = [Color(0.86, 0.86, 0.84), 1, Color.WHITE]},
	aiel_f = {label = "Aiel cadin'sor", sex = "f", base = "female_ranger", hide = ["Pauldron"], hood = true, p = Color(0.4, 0.35, 0.26), s = Color(0.27, 0.24, 0.19)},
	hunter_f = {label = "Traveller's cloak", sex = "f", base = "female_ranger", hide = ["Hood", "Pauldron"], p = Color(0.2, 0.24, 0.38), s = Color(0.08, 0.08, 0.1),
		cloak = [Color(0.12, 0.1, 0.09), 0, Color.WHITE]},
	two_rivers_m = {label = "Two Rivers wool", sex = "m", base = "male_peasant", p = Color(0.76, 0.72, 0.6), s = Color(0.09, 0.07, 0.05)},
	farmer_cloak = {label = "Two Rivers, cloaked", sex = "m", base = "male_peasant", p = Color(0.5, 0.52, 0.42), s = Color(0.1, 0.09, 0.07),
		cloak = [Color(0.2, 0.14, 0.09), 0, Color.WHITE]},
	ashaman = {label = "Asha'man black coat", sex = "m", base = "male_ranger", hide = ["Hood", "Pauldron"], p = Color(0.035, 0.035, 0.04), s = Color(0.02, 0.02, 0.025),
		coat = [Color(0.03, 0.03, 0.035), 4, Color(0.09, 0.09, 0.1)]},
	merchant = {label = "Long coat (Andor)", sex = "m", base = "male_peasant", p = Color(0.36, 0.08, 0.08), s = Color(0.12, 0.1, 0.09),
		coat = [Color(0.33, 0.07, 0.07), 4, Color(0.7, 0.58, 0.25)]},
	aiel_m = {label = "Aiel cadin'sor", sex = "m", base = "male_ranger", hide = ["Pauldron"], hood = true, p = Color(0.4, 0.35, 0.26), s = Color(0.27, 0.24, 0.19)},
	warder = {label = "Warder (fancloth cloak)", sex = "m", base = "male_ranger", hide = ["Hood"], p = Color(0.17, 0.2, 0.15), s = Color(0.07, 0.07, 0.06),
		cloak = [Color(0.2, 0.2, 0.18), 3, Color.WHITE]},
	borderlander = {label = "Borderlander", sex = "m", base = "male_ranger", hide = ["Hood"], p = Color(0.42, 0.3, 0.1), s = Color(0.1, 0.07, 0.05),
		cloak = [Color(0.3, 0.05, 0.04), 4, Color(0.6, 0.5, 0.2)]},
}
## Ids saved by earlier builds.
const LEGACY := {male_peasant = "two_rivers_m", female_peasant = "two_rivers_f", male_ranger = "warder", female_ranger = "aiel_f"}

## Release gestures a channeller may use; each person gets one per weave.
const CASTS: Array[String] = ["Spell_Simple_Shoot", "Punch_Jab", "Punch_Cross", "Pistol_Shoot", "Sword_Attack"]

static func _is_leg(path: NodePath) -> bool:
	var bone := String(path).get_slice(":", 1)
	return bone == "pelvis" or bone == "root" or bone.begins_with("thigh") or bone.begins_with("calf") or bone.begins_with("foot") or bone.begins_with("ball")

## The gesture this person uses for this weave: random between people, but always
## the same for one person and one weave, so it needs no storage.
static func cast_clip(who: String, weave: String) -> String:
	return CASTS[hash(who + "/" + weave) % CASTS.size()]

static var _libs := {}   # base -> AnimationLibrary fitted to that body's proportions

## Every look, with the seven Aes Sedai shawls generated from the Ajah table.
static func looks() -> Dictionary:
	var out := LOOKS.duplicate()
	for a in AJAHS:
		var col: Color = AJAHS[a]
		out["aes_sedai_" + a] = {label = "Aes Sedai, %s Ajah" % a.capitalize(), sex = "f", base = "female_peasant",
			p = col.lerp(Color(0.85, 0.85, 0.82), 0.55), s = col.darkened(0.45), hair = "Hair_Buns",
			skirt = [col.darkened(0.15), 4, col.lerp(Color.WHITE, 0.5)], shawl = [col, 2, Color(0.92, 0.9, 0.82)]}
	return out

static func kind_for(profile: Dictionary) -> String:
	var all := looks()
	var want = profile.get("look")
	if want is String:
		want = LEGACY.get(want, want)
		if all.has(want):
			return want
	var f: bool = profile.get("power", "saidar") == "saidar"
	match profile.get("origin", ""):
		"aiel": return "aiel_f" if f else "aiel_m"
		"tar_valon": return "accepted" if f else "ashaman"
		"borderlands": return "hunter_f" if f else "borderlander"
	return "two_rivers_f" if f else "two_rivers_m"

static func instantiate(look_id: String, seed := 0) -> Node3D:
	var all := looks()
	var look: Dictionary = all.get(LEGACY.get(look_id, look_id), all.two_rivers_f)
	var root: Node3D = (load(MODEL % look.base) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	ap.add_animation_library("", _library(look.base, sk))
	ap.playback_default_blend_time = 0.15
	root.set_meta("anim", ap)
	root.set_meta("skeleton", sk)
	var rng := RandomNumberGenerator.new(); rng.seed = hash(str(seed) + look_id)
	var tint: Color = HAIR[rng.randi() % HAIR.size()]
	var hairs: Array = []
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		m.extra_cull_margin = 1.0   # skinned bounds lag the pose
		var n := String(m.name)
		for h in look.get("hide", []):
			if n.contains(h):
				m.visible = false
		# Trousers under a skirt only ever show as a knee poking through the cloth.
		if look.has("skirt") and n.ends_with("_Legs"):
			m.visible = false
		if n in ["Skirt", "Cloak", "Shawl", "Coat"]:
			var spec: Array = look.get(n.to_lower(), [])
			m.visible = not spec.is_empty()
			if m.visible:
				var gm := ShaderMaterial.new(); gm.shader = GARMENT
				gm.set_shader_parameter("base", spec[0]); gm.set_shader_parameter("style", spec[1]); gm.set_shader_parameter("trim", spec[2])
				m.material_override = gm
		elif n.begins_with("Hair") or n.begins_with("Eyebrows"):
			# The pack ships hair as a grey map meant to be tinted.
			for i in m.mesh.get_surface_count():
				var mat: BaseMaterial3D = m.get_active_material(i).duplicate()
				mat.albedo_color = tint
				m.set_surface_override_material(i, mat)
			if n.begins_with("Hair_Beard"):
				m.visible = rng.randf() < 0.4 and look_id != "ashaman"
			elif n.begins_with("Hair"):
				hairs.append(m)
		elif look.has("p"):
			for i in m.mesh.get_surface_count():
				var src := m.get_active_material(i) as BaseMaterial3D
				# Identify the atlas by its texture: material names do not survive import.
				var tex := "" if src == null or src.albedo_texture == null else src.albedo_texture.resource_path + src.albedo_texture.resource_name
				var atlas := 0 if tex.contains("T_Ranger") else (1 if tex.contains("T_Peasant") else -1)
				if OS.has_environment("HERO_DEBUG"): print("HEROMAT ", n, " ", i, " ", tex, " ", atlas, " ", src)
				if atlas >= 0:
					var om := ShaderMaterial.new(); om.shader = OUTFIT
					om.set_shader_parameter("albedo_tex", src.albedo_texture)
					om.set_shader_parameter("normal_tex", src.normal_texture)
					om.set_shader_parameter("has_normal", src.normal_texture != null)
					om.set_shader_parameter("mode", atlas)
					om.set_shader_parameter("primary", look.p); om.set_shader_parameter("secondary", look.s)
					m.set_surface_override_material(i, om)
	# One hairstyle shows: the look's own, or one picked by the seed. None under a hood.
	var keep := rng.randi() % maxi(hairs.size(), 1)
	for i in hairs.size():
		var h: MeshInstance3D = hairs[i]
		h.visible = not look.get("hood", false) and (String(h.name).begins_with(look.hair) if look.has("hair") else i == keep)
	return root

## The clips were authored on a mannequin with other limb lengths. Keeping only the
## rotations (plus a rescaled hip height) lets every body keep its own proportions.
static func _library(kind: String, sk: Skeleton3D) -> AnimationLibrary:
	if _libs.has(kind):
		return _libs[kind]
	var src: Node = (load(ANIMS) as PackedScene).instantiate()
	var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var hip := sk.find_bone("pelvis")
	var ratio := sk.get_bone_rest(hip).origin.length() / maxf(ssk.get_bone_rest(ssk.find_bone("pelvis")).origin.length(), 0.001)
	var lib := AnimationLibrary.new()
	for clip in sap.get_animation_list():
		var a: Animation = sap.get_animation(clip).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var bone := String(a.track_get_path(t)).get_slice(":", 1)
			match a.track_get_type(t):
				Animation.TYPE_SCALE_3D:
					a.remove_track(t)
				Animation.TYPE_POSITION_3D:
					if bone == "pelvis":
						for k in a.track_get_key_count(t):
							a.track_set_key_value(t, k, a.track_get_key_value(t, k) * ratio)
					elif bone != "root":
						a.remove_track(t)
		lib.add_animation(clip, a)
	# Weaving on the move: the library has no clip for it, so graft the jog's legs
	# under each casting clip's upper body. Without this the feet slide.
	var jog: Animation = lib.get_animation("Jog_Fwd")
	for clip in CASTS + ["Spell_Simple_Enter"]:
		var a: Animation = lib.get_animation(clip).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			if _is_leg(a.track_get_path(t)):
				a.remove_track(t)
		for t in jog.get_track_count():
			if not _is_leg(jog.track_get_path(t)):
				continue
			var nt := a.add_track(jog.track_get_type(t))
			a.track_set_path(nt, jog.track_get_path(t))
			for rep in int(ceil(a.length / jog.length)):
				for k in jog.track_get_key_count(t):
					var at := jog.track_get_key_time(t, k) + rep * jog.length
					if at <= a.length:
						a.track_insert_key(nt, at, jog.track_get_key_value(t, k))
		lib.add_animation(clip + "_Move", a)
	src.free()
	_libs[kind] = lib
	return lib
