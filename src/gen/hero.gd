class_name Hero
## Player characters: sourced Quaternius bodies and outfits (assembled, with generated
## garments, by tools/blender/build_heroes.py), dressed here as Wheel of Time
## cultures. A look is data: which base model, which pieces show, and the colours.
## Shadowspawn stay generated; the player stares at this model all game.

const ANIMS := "res://assets/quaternius/ual1.glb"
## The second library: sword cuts, block, shield, throw, knockback.
const ANIMS2 := "res://assets/quaternius/ual2.glb"
const MODEL := "res://assets/quaternius/chars/%s.glb"
const OUTFIT := preload("res://shaders/outfit.gdshader")
const GARMENT := preload("res://shaders/garment.gdshader")
const HAIR_SHADER := preload("res://shaders/hair.gdshader")
const HAIR := [Color(0.16, 0.1, 0.06), Color(0.38, 0.22, 0.1), Color(0.62, 0.3, 0.12), Color(0.75, 0.6, 0.33), Color(0.07, 0.06, 0.06)]
## What a player may choose about their body (profile.style). Each list is
## [label, value]; anything not chosen is rolled from the character's name.
const HAIR_COLOURS := [["Dark brown", Color(0.16, 0.1, 0.06)], ["Brown", Color(0.38, 0.22, 0.1)], ["Auburn", Color(0.62, 0.3, 0.12)], ["Fair", Color(0.75, 0.6, 0.33)], ["Black", Color(0.07, 0.06, 0.06)],
	["Aiel red", Color(0.7, 0.24, 0.08)], ["Pale gold", Color(0.9, 0.78, 0.5)], ["Grey", Color(0.5, 0.5, 0.5)], ["White", Color(0.9, 0.9, 0.88)]]
const SKINS := [["Fair", Color(1.0, 1.0, 1.0)], ["Pale", Color(1.2, 1.17, 1.15)], ["Sun-browned", Color(0.86, 0.76, 0.68)], ["Copper", Color(0.9, 0.66, 0.52)], ["Brown", Color(0.62, 0.48, 0.4)], ["Dark", Color(0.42, 0.32, 0.27)]]
const EYES := [["Brown", Color(1, 1, 1)], ["Blue", Color(0.55, 0.8, 1.6)], ["Grey", Color(0.8, 0.9, 1.05)], ["Green", Color(0.6, 1.25, 0.7)], ["Dark", Color(0.45, 0.4, 0.4)], ["Hazel", Color(1.1, 1.0, 0.6)]]
const HEIGHTS := [["Short", 0.93], ["Below middling", 0.965], ["Middling", 1.0], ["Tall", 1.035], ["Very tall", 1.07]]
const BUILDS := [["Slight", 0.92], ["Lean", 0.96], ["Middling", 1.0], ["Sturdy", 1.05], ["Broad", 1.1]]
## Cloaks anyone may choose over any dress: id -> [label, colour, garment style, trim].
## "" keeps whatever the dress comes with. Lengths cut the same cloak short in the shader.
const CLOAKS := {
	none = ["No cloak"],
	wool_brown = ["Brown wool", Color(0.2, 0.14, 0.09), 0, Color.WHITE],
	wool_grey = ["Grey wool", Color(0.2, 0.2, 0.21), 0, Color.WHITE],
	green = ["Forest green", Color(0.07, 0.16, 0.08), 0, Color.WHITE],
	black = ["Black", Color(0.02, 0.02, 0.025), 0, Color.WHITE],
	blue = ["Deep blue, trimmed", Color(0.06, 0.1, 0.3), 4, Color(0.75, 0.75, 0.8)],
	crimson = ["Crimson, gold hem", Color(0.42, 0.04, 0.04), 4, Color(0.8, 0.62, 0.2)],
	white = ["Snow white", Color(0.86, 0.86, 0.84), 0, Color.WHITE],
	fur = ["Winter cloak, fur-trimmed", Color(0.16, 0.12, 0.09), 7, Color(0.62, 0.56, 0.46)],
	lined = ["Black, lined with scarlet", Color(0.025, 0.025, 0.03), 8, Color(0.55, 0.04, 0.05)],
	lined_blue = ["Grey, lined with blue", Color(0.24, 0.24, 0.26), 8, Color(0.08, 0.16, 0.5)],
	silk = ["Worked silk", Color(0.1, 0.3, 0.26), 6, Color(0.85, 0.75, 0.4)],
	vines = ["Embroidered with vines", Color(0.12, 0.1, 0.2), 9, Color(0.8, 0.7, 0.35)],
	patches = ["Gleeman's patches", Color(0.3, 0.25, 0.2), 5, Color.WHITE],
	fancloth = ["Fancloth", Color(0.2, 0.2, 0.18), 3, Color.WHITE],
}
const CLOAK_LENGTHS := [["To the calf", 1.0], ["To the knee", 0.74], ["To the waist", 0.5], ["Shoulder cape", 0.3]]
const AJAHS := {blue = Color(0.08, 0.16, 0.55), green = Color(0.07, 0.33, 0.12), yellow = Color(0.6, 0.47, 0.1), red = Color(0.5, 0.04, 0.04),
	white = Color(0.85, 0.85, 0.82), grey = Color(0.34, 0.34, 0.36), brown = Color(0.26, 0.15, 0.07)}

## base: model file. hide: mesh-name fragments to hide. p/s: cloth colours for the
## outfit shader (omit to keep the pack's own). Garments: [colour, style, trim].
## hair: mesh name to force; hood: true keeps hair hidden beneath it.
const LOOKS := {
	two_rivers_f = {label = "Two Rivers wool", sex = "f", base = "female_peasant", p = Color(0.78, 0.74, 0.62), s = Color(0.1, 0.16, 0.1),
		skirt = [Color(0.1, 0.17, 0.11), 4, Color(0.55, 0.5, 0.36)], hair = "Hair_Long"},
	novice = {label = "Novice white", sex = "f", bodice = Color(0.84, 0.84, 0.82), base = "female_peasant", p = Color(0.88, 0.88, 0.86), s = Color(0.8, 0.8, 0.78),
		skirt = [Color(0.86, 0.86, 0.84), 0, Color.WHITE]},
	accepted = {label = "Accepted (banded hem)", sex = "f", bodice = Color(0.84, 0.84, 0.82), base = "female_peasant", p = Color(0.88, 0.88, 0.86), s = Color(0.8, 0.8, 0.78),
		skirt = [Color(0.86, 0.86, 0.84), 1, Color.WHITE]},
	aiel_f = {label = "Aiel cadin'sor", sex = "f", base = "female_ranger", hide = ["Pauldron"], hood = true, p = Color(0.4, 0.35, 0.26), s = Color(0.27, 0.24, 0.19)},
	hunter_f = {label = "Traveller's cloak", sex = "f", base = "female_ranger", hide = ["Hood", "Pauldron"], p = Color(0.2, 0.24, 0.38), s = Color(0.08, 0.08, 0.1),
		cloak = [Color(0.12, 0.1, 0.09), 0, Color.WHITE]},
	two_rivers_m = {label = "Two Rivers wool", sex = "m", base = "male_peasant", p = Color(0.76, 0.72, 0.6), s = Color(0.09, 0.07, 0.05)},
	farmer_cloak = {label = "Two Rivers, cloaked", sex = "m", base = "male_peasant", p = Color(0.5, 0.52, 0.42), s = Color(0.1, 0.09, 0.07),
		cloak = [Color(0.2, 0.14, 0.09), 0, Color.WHITE]},
	ashaman = {label = "Asha'man black coat", sex = "m", base = "male_ranger", hide = ["Hood", "Pauldron"], p = Color(0.035, 0.035, 0.04), s = Color(0.02, 0.02, 0.025),
		coat = [Color(0.03, 0.03, 0.035), 4, Color(0.09, 0.09, 0.1)], pins = 2},
	merchant = {label = "Long coat (Andor)", sex = "m", base = "male_peasant", p = Color(0.36, 0.08, 0.08), s = Color(0.12, 0.1, 0.09),
		coat = [Color(0.33, 0.07, 0.07), 4, Color(0.7, 0.58, 0.25)]},
	aiel_m = {label = "Aiel cadin'sor", sex = "m", base = "male_ranger", hide = ["Pauldron"], hood = true, p = Color(0.4, 0.35, 0.26), s = Color(0.27, 0.24, 0.19)},
	cairhien_m = {label = "Cairhienin coat (slashed)", sex = "m", base = "male_peasant", p = Color(0.05, 0.05, 0.07), s = Color(0.03, 0.03, 0.04), slashes = 5,
		coat = [Color(0.045, 0.045, 0.06), 0, Color.WHITE]},
	tairen_m = {label = "Tairen coat (striped sleeves)", sex = "m", base = "male_peasant", p = Color(0.5, 0.36, 0.08), s = Color(0.05, 0.04, 0.04), sleeve = Color(0.05, 0.04, 0.05, 1.0),
		coat = [Color(0.46, 0.33, 0.07), 6, Color(0.05, 0.04, 0.05)], sheen = 0.5},
	noble_m = {label = "Lord's silk coat", sex = "m", base = "male_peasant", p = Color(0.08, 0.14, 0.42), s = Color(0.04, 0.04, 0.06), sheen = 1.0,
		coat = [Color(0.07, 0.12, 0.38), 6, Color(0.8, 0.65, 0.25)]},
	queens_guard = {label = "Queen's Guard (Andor)", sex = "m", base = "male_ranger", hide = ["Hood"], p = Color(0.55, 0.06, 0.05), s = Color(0.7, 0.7, 0.68), mail = false,
		cloak = [Color(0.6, 0.07, 0.06), 4, Color(0.85, 0.85, 0.82)]},
	shienaran = {label = "Shienaran mail", sex = "m", base = "male_ranger", hide = ["Hood"], p = Color(0.3, 0.3, 0.32), s = Color(0.08, 0.07, 0.06), mail = true, hair = "Hair_Buzzed"},
	armsman_m = {label = "Armsman's mail and cloak", sex = "m", base = "male_ranger", hide = ["Hood"], p = Color(0.3, 0.3, 0.32), s = Color(0.12, 0.1, 0.08), mail = true,
		cloak = [Color(0.16, 0.2, 0.3), 0, Color.WHITE]},
	gleeman = {label = "Gleeman's cloak", sex = "m", base = "male_peasant", p = Color(0.7, 0.66, 0.55), s = Color(0.2, 0.14, 0.1),
		cloak = [Color(0.3, 0.25, 0.2), 5, Color.WHITE]},
	tinker_m = {label = "Tinker's colours", sex = "m", base = "male_peasant", p = Color(0.85, 0.7, 0.1), s = Color(0.1, 0.45, 0.2),
		coat = [Color(0.7, 0.12, 0.3), 4, Color(0.15, 0.5, 0.8)]},
	dedicated = {label = "Dedicated (sword pin)", sex = "m", base = "male_ranger", hide = ["Hood", "Pauldron"], p = Color(0.035, 0.035, 0.04), s = Color(0.02, 0.02, 0.025),
		coat = [Color(0.03, 0.03, 0.035), 4, Color(0.09, 0.09, 0.1)], pins = 1},
	wise_one = {label = "Wise One (algode and shawl)", sex = "f", base = "female_peasant", p = Color(0.9, 0.88, 0.82), s = Color(0.3, 0.22, 0.15),
		skirt = [Color(0.3, 0.23, 0.16), 0, Color.WHITE], shawl = [Color(0.36, 0.28, 0.2), 2, Color(0.5, 0.42, 0.32)], hair = "Hair_Long"},
	cairhien_f = {label = "Cairhienin gown (slashed)", sex = "f", bodice = Color(0.05, 0.05, 0.075), base = "female_peasant", p = Color(0.06, 0.06, 0.09), s = Color(0.04, 0.04, 0.05), slashes = 4,
		skirt = [Color(0.055, 0.055, 0.08), 6, Color(0.6, 0.1, 0.1)], hair = "Hair_Buns"},
	noble_f = {label = "Lady's silk gown", sex = "f", bodice = Color(0.07, 0.24, 0.19), base = "female_peasant", p = Color(0.12, 0.38, 0.3), s = Color(0.06, 0.2, 0.16), sheen = 1.0,
		skirt = [Color(0.1, 0.34, 0.27), 6, Color(0.85, 0.75, 0.4)]},
	domani_f = {label = "Domani gown", sex = "f", bodice = Color(0.46, 0.13, 0.15), base = "female_peasant", p = Color(0.6, 0.2, 0.22), s = Color(0.45, 0.14, 0.16), sheen = 0.7,
		skirt = [Color(0.58, 0.19, 0.21), 6, Color(0.85, 0.65, 0.3)], hair = "Hair_Long"},
	tairen_f = {label = "Tairen gown (striped sleeves)", sex = "f", bodice = Color(0.5, 0.11, 0.11), base = "female_peasant", p = Color(0.75, 0.62, 0.3), s = Color(0.3, 0.1, 0.1), sleeve = Color(0.3, 0.08, 0.1, 1.0), sheen = 0.4,
		skirt = [Color(0.6, 0.14, 0.14), 4, Color(0.8, 0.68, 0.3)]},
	tinker_f = {label = "Tinker's colours", sex = "f", bodice = Color(0.75, 0.2, 0.45), base = "female_peasant", p = Color(0.2, 0.55, 0.85), s = Color(0.85, 0.3, 0.1),
		skirt = [Color(0.85, 0.7, 0.1), 4, Color(0.7, 0.12, 0.3)], shawl = [Color(0.1, 0.5, 0.25), 2, Color(0.9, 0.8, 0.2)]},
	armswoman = {label = "Armswoman's mail and cloak", sex = "f", base = "female_ranger", hide = ["Hood"], p = Color(0.3, 0.3, 0.32), s = Color(0.12, 0.1, 0.08), mail = true,
		cloak = [Color(0.16, 0.2, 0.3), 0, Color.WHITE]},
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
			bodice = col.darkened(0.3), skirt = [col.darkened(0.15), 4, col.lerp(Color.WHITE, 0.5)], shawl = [col, 2, Color(0.92, 0.9, 0.82)]}
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

## style: what the player chose about the body (see HAIR_COLOURS and the rest):
## {hair: mesh name or "none", hair_col, skin, eyes, height, build: indexes, beard: bool}.
static var _cloaks := {}   # model -> the cloak mesh rehung from the shoulders

## The cloak was skinned partly to the legs below the hips, so its lower half walked
## with them while the top stayed with the back. Hand those weights to the pelvis:
## it hangs from the shoulders as one cloth, and the shader swings it (cloak_motion).
static func _cloak_from_shoulders(m: MeshInstance3D, base: String, sk: Skeleton3D) -> void:
	if _cloaks.has(base):
		m.mesh = _cloaks[base]
		return
	var mesh: ArrayMesh = m.mesh as ArrayMesh
	if mesh == null:
		return
	var names := []
	if m.skin:
		for i in m.skin.get_bind_count():
			var bn: String = m.skin.get_bind_name(i)
			names.append(bn if bn != "" else sk.get_bone_name(m.skin.get_bind_bone(i)))
	else:
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
	var pelvis := names.find("pelvis")
	if pelvis < 0:
		return
	var legs := {}
	for i in names.size():
		var nm: String = String(names[i]).to_lower()
		if nm.contains("thigh") or nm.contains("calf") or nm.contains("foot"):
			legs[i] = true
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		for i in bones.size():
			if legs.has(bones[i]):
				bones[i] = pelvis
		arr[Mesh.ARRAY_BONES] = bones
		var flags := mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), arr, [], {}, flags)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_cloaks[base] = out
	m.mesh = out

## The wind where this body stands, turned into its own frame (+z is its front).
static func _wind_local(root: Node3D) -> Vector3:
	if not root.is_inside_tree():
		return Vector3.ZERO
	return root.global_basis.orthonormalized().inverse() * Wind.at(root.global_position)

static func _hair_wind(root: Node3D, k: float) -> void:
	var wl := _wind_local(root)
	# Running blows it back (-z); the wind blows it its own way.
	var blow := Vector3(0, 0, -k) + wl
	for hm in root.get_meta("hair_mats", []):
		(hm as ShaderMaterial).set_shader_parameter("wind", blow.normalized() if blow.length() > 0.01 else Vector3(0, 0, -1))
		(hm as ShaderMaterial).set_shader_parameter("gust", 0.35 + 1.4 * blow.length())

## How the cloak moves with its wearer: speed in metres a second, 0 standing.
static func cloak_motion(root: Node3D, speed: float) -> void:
	var m: MeshInstance3D = root.get_meta("cloak", null) if root.has_meta("cloak") else null
	if m == null:
		for c in root.find_children("Cloak", "MeshInstance3D", true, false):
			m = c
		root.set_meta("cloak", m)
	if m == null or not m.visible or not (m.material_override is ShaderMaterial):
		_hair_wind(root, clampf(speed / 7.5, 0.0, 1.2))
		return
	# A walk barely lifts it; a run sends it back; a sprint streams it out. The wind
	# (the map's own, and gusts from weaves) carries it its way on top of that.
	var k := clampf(speed / 7.5, 0.0, 1.2)
	var wl := _wind_local(root)
	var mat: ShaderMaterial = m.material_override
	mat.set_shader_parameter("sway", Vector3(0.0, 0.14 * k * k, -0.42 * k * k) + Vector3(wl.x, absf(wl.length()) * 0.15, wl.z) * 0.32)
	# Always a little stir, as if there is air; more the faster you go, and in wind.
	mat.set_shader_parameter("flutter", 0.5 + 1.8 * k + wl.length() * 1.5)
	root.set_meta("wind_k", k)
	_hair_wind(root, k)

static func instantiate(look_id: String, seed := 0, style := {}) -> Node3D:
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
	if style.has("hair_col"):
		tint = HAIR_COLOURS[clampi(int(style.hair_col), 0, HAIR_COLOURS.size() - 1)][1]
	var skin: Color = SKINS[clampi(int(style.get("skin", 0)), 0, SKINS.size() - 1)][1]
	var eye: Color = EYES[clampi(int(style.get("eyes", 0)), 0, EYES.size() - 1)][1]
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
		if n == "Cloak":
			_cloak_from_shoulders(m, look.base, sk)
		if n in ["Skirt", "Cloak", "Shawl", "Coat"]:
			var spec: Array = look.get(n.to_lower(), [])
			var cut := 1.0
			if n == "Cloak":
				# The player's own cloak goes over whatever the dress came with.
				var own: Array = CLOAKS.get(str(style.get("cloak", "")), [])
				if own.size() == 1:
					spec = []
				elif own.size() == 4:
					spec = own.slice(1)
				cut = CLOAK_LENGTHS[clampi(int(style.get("cloak_len", 0)), 0, CLOAK_LENGTHS.size() - 1)][1]
			m.visible = not spec.is_empty()
			if m.visible:
				var gm := ShaderMaterial.new(); gm.shader = GARMENT
				gm.set_shader_parameter("base", spec[0]); gm.set_shader_parameter("style", spec[1]); gm.set_shader_parameter("trim", spec[2])
				gm.set_shader_parameter("pleats", n == "Skirt")
				gm.set_shader_parameter("cut", cut)
				m.material_override = gm
		elif n.begins_with("Hair") or n.begins_with("Eyebrows"):
			# The pack ships hair as a grey map meant to be tinted. Hair (not brows)
			# goes to a shader that lets it move in the wind (Hero.cloak_motion).
			var aabb := m.mesh.get_aabb()
			for i in m.mesh.get_surface_count():
				var src: BaseMaterial3D = m.get_active_material(i)
				if n.begins_with("Hair") and src != null:
					var hm := ShaderMaterial.new(); hm.shader = HAIR_SHADER
					hm.set_shader_parameter("tint", tint)
					hm.set_shader_parameter("use_tex", src.albedo_texture != null)
					if src.albedo_texture: hm.set_shader_parameter("tex", src.albedo_texture)
					hm.set_shader_parameter("top", aabb.end.y)
					hm.set_shader_parameter("span", maxf(aabb.size.y, 0.1))
					m.set_surface_override_material(i, hm)
					var list: Array = root.get_meta("hair_mats", [])
					list.append(hm)
					root.set_meta("hair_mats", list)
				else:
					var mat: BaseMaterial3D = src.duplicate()
					mat.albedo_color = tint
					m.set_surface_override_material(i, mat)
			if n.begins_with("Hair_Beard"):
				var rolled: bool = rng.randf() < 0.4 and look_id != "ashaman"
				m.visible = bool(style.beard) if style.has("beard") else rolled
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
					om.set_shader_parameter("slashes", int(look.get("slashes", 0)))
					om.set_shader_parameter("sleeve", look.get("sleeve", Color(0, 0, 0, 0)))
					om.set_shader_parameter("sheen", float(look.get("sheen", 0.0)))
					om.set_shader_parameter("mail", bool(look.get("mail", false)))
					# Only the torso piece: boots and bracers stay leather.
					if look.has("bodice") and n.ends_with("_Body"):
						om.set_shader_parameter("bodice", look.bodice)
					m.set_surface_override_material(i, om)
	# One hairstyle shows: the player's choice, else the look's own, else one picked
	# by the seed. None under a hood, or for a shaved head.
	var keep := rng.randi() % maxi(hairs.size(), 1)
	var want: String = style.get("hair", look.get("hair", ""))
	for i in hairs.size():
		var h: MeshInstance3D = hairs[i]
		h.visible = not look.get("hood", false) and want != "none" and (String(h.name).begins_with(want) if want != "" else i == keep)
	# Skin and eyes: tint the sourced maps (found by texture name, like the outfits).
	if style.has("skin") or style.has("eyes"):
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for i in m.mesh.get_surface_count():
				var src := m.get_active_material(i) as BaseMaterial3D
				if src == null or src.albedo_texture == null:
					continue
				var tex := src.albedo_texture.resource_path + src.albedo_texture.resource_name
				var col := skin if (tex.contains("Superhero") or tex.contains("Regular_")) else (eye if tex.contains("T_Eye") else Color(0, 0, 0, 0))
				if col.a > 0.0:
					var mat: BaseMaterial3D = src.duplicate()
					mat.albedo_color = col
					m.set_surface_override_material(i, mat)
	# Height and build: the whole figure, so clothes and weapons keep their fit.
	var tall: float = HEIGHTS[clampi(int(style.get("height", 2)), 0, HEIGHTS.size() - 1)][1]
	var wide: float = BUILDS[clampi(int(style.get("build", 2)), 0, BUILDS.size() - 1)][1]
	root.scale = Vector3(wide, tall, wide)
	if int(look.get("pins", 0)) > 0:
		_pins(root, int(look.pins))
	return root

## The Asha'man's collar pins: a silver sword for a Dedicated, and with it a
## red-and-gold dragon for a full Asha'man. Placed from the rest pose like weapons.
static func _pins(root: Node3D, n: int) -> void:
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var bone := sk.find_bone("neck_01")
	if bone < 0:
		return
	var to_model := Basis.IDENTITY
	var node: Node = sk
	while node != root and node is Node3D:
		to_model = (node as Node3D).transform.basis * to_model
		node = node.get_parent()
	var inv := sk.get_bone_global_rest(bone).basis.inverse() * to_model.inverse()
	var at := BoneAttachment3D.new(); at.name = "Pins"; at.bone_name = "neck_01"
	sk.add_child(at)
	for k in n:
		var side := -1.0 if k == 0 else 1.0
		var mi := MeshInstance3D.new(); var b := BoxMesh.new()
		b.size = Vector3(0.012, 0.045, 0.006) if k == 0 else Vector3(0.04, 0.016, 0.006)
		mi.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.87, 0.9) if k == 0 else Color(0.85, 0.3, 0.1)
		mat.metallic = 0.9; mat.roughness = 0.25
		mat.emission_enabled = true; mat.emission = mat.albedo_color; mat.emission_energy_multiplier = 0.35
		mi.material_override = mat
		mi.position = inv * Vector3(side * 0.05, -0.015, 0.085)
		mi.basis = inv * Basis(Vector3.UP, side * -0.5)
		at.add_child(mi)

## Put a weapon in the character's hands (or take it away with ""). The grip is
## worked out from the rest pose, where the arms are out to the sides and the
## palms down: a fist then holds a handle that points forward, flat edge-on to
## the arm, so no per-model numbers are needed.
static func arm(root: Node3D, weapon_id: String) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton")
	for old in sk.find_children("Held*", "BoneAttachment3D", false, false):
		old.free()
	var kit := Armoury.build(weapon_id)
	# Skeleton space may be turned against the model's: find model forward and up in it.
	var to_model := Basis.IDENTITY
	var n: Node = sk
	while n != root and n is Node3D:
		to_model = (n as Node3D).transform.basis * to_model
		n = n.get_parent()
	var fwd := to_model.inverse() * Vector3(0, 0, 1)
	var up := to_model.inverse() * Vector3(0, 1, 0)
	# The pose that draws a bow needs the same directions.
	var pose: ArmPose = root.get_meta("pose") if root.has_meta("pose") else null
	if pose == null:
		pose = ArmPose.new()
		sk.add_child(pose)
		root.set_meta("pose", pose)
	pose.fwd = fwd.normalized(); pose.up = up.normalized(); pose.left = up.cross(fwd).normalized()
	pose.mode = ""; pose.weight = 0.0
	for part in [[kit.main, "hand_r"], [kit.off, kit.off_bone]]:
		if part[0] == null:
			continue
		var bone := sk.find_bone(part[1])
		if bone < 0:
			part[0].free()
			continue
		var rest := sk.get_bone_global_rest(bone)
		var along := (rest.origin - sk.get_bone_global_rest(sk.get_bone_parent(bone)).origin).normalized()
		var at := BoneAttachment3D.new()
		at.name = "Held_" + part[1]
		at.bone_name = part[1]
		sk.add_child(at)
		var inv := rest.basis.inverse()
		var holder: Node3D = part[0]
		if part[1] == "hand_l" and part[0].has_meta("bow"):
			# A bow: carried along the arm; to shoot, upright with the string
			# toward the archer (grip "draw").
			var yb := (inv * fwd).normalized()
			var xb := (inv * along).normalized()
			xb = (xb - yb * xb.dot(yb)).normalized()
			holder.basis = Basis(xb, yb, xb.cross(yb))
			holder.position = inv * (along * 0.085 - up * 0.03)
			holder.set_meta("grips", {"": holder.transform})
			pose.grip_l = holder.basis
		elif part[1].begins_with("lowerarm"):
			# A buckler: flat against the back of the forearm.
			var out := inv * up
			var x := (inv * along).normalized()
			holder.basis = Basis(x, out, x.cross(out)).orthonormalized()
			holder.position = inv * (along * 0.14 + up * 0.07)
		else:
			# Long axis forward out of the fist, flat facing along the arm.
			var y := (inv * fwd).normalized()
			var x := (inv * along).normalized()
			x = (x - y * x.dot(y)).normalized()
			holder.basis = Basis(x, y, x.cross(y))
			holder.position = inv * (along * 0.085 - up * 0.03)
			# Couched: the long axis runs out along the forearm, point first, so a
			# driving arm drives the point (a spear thrust, not a punch with a stick).
			var y2 := (inv * along).normalized()
			var x2 := (inv * up).normalized()
			x2 = (x2 - y2 * x2.dot(y2)).normalized()
			pose.grip_r = holder.basis
			holder.set_meta("grips", {"": holder.transform, "couched": Transform3D(Basis(x2, y2, x2.cross(y2)), inv * (along * 0.085 - up * 0.02))})
		at.add_child(holder)

## Play a written-out sword stroke (ArmPose.STROKES) over whatever clip is running.
static func stroke(root: Node3D, id: String, land: float, after: float) -> void:
	if root.has_meta("pose"):
		(root.get_meta("pose") as ArmPose).stroke(id, land, after)

## How the right hand holds what is in it: "" as carried, "couched" point-forward
## along the arm for a thrust.
static func grip(root: Node3D, mode: String) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton")
	var at := sk.get_node_or_null("Held_hand_r")
	if at and at.get_child_count() > 0 and at.get_child(0).has_meta("grips"):
		var grips: Dictionary = at.get_child(0).get_meta("grips")
		(at.get_child(0) as Node3D).transform = grips.get(mode, grips[""])

## The bow in the left hand: how far its string is drawn, and whether an arrow is
## on it. (ArmPose turns the hand to hold it upright.)
static func bow(root: Node3D, _mode: String, pull: float, nocked: bool) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton")
	var at := sk.get_node_or_null("Held_hand_l")
	if at == null or at.get_child_count() == 0 or not at.get_child(0).has_meta("grips"):
		return
	var b: Node3D = at.get_child(0)
	Armoury.string(b, pull, nocked)

## Turn what is in the right hand about the fist (a sling being whirled);
## a negative angle puts it back as it is carried.
static func whirl(root: Node3D, angle: float) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton")
	var at := sk.get_node_or_null("Held_hand_r")
	if at == null or at.get_child_count() == 0:
		return
	var h: Node3D = at.get_child(0)
	if angle < 0.0:
		# At rest a sling hangs from the fist, whatever the arm is doing.
		h.global_basis = Basis.IDENTITY
	else:
		h.rotate_object_local(Vector3.RIGHT, angle)

## Whether what is carried in the right hand is seen (a thrown knife is gone
## from it until the next comes to hand).
static func show_held(root: Node3D, on: bool) -> void:
	var sk: Skeleton3D = root.get_meta("skeleton")
	var at := sk.get_node_or_null("Held_hand_r")
	if at:
		(at as Node3D).visible = on

## The clips were authored on a mannequin with other limb lengths. Keeping only the
## rotations (plus a rescaled hip height) lets every body keep its own proportions.
static func _library(kind: String, sk: Skeleton3D) -> AnimationLibrary:
	if _libs.has(kind):
		return _libs[kind]
	var lib := AnimationLibrary.new()
	var hip := sk.find_bone("pelvis")
	for file in [ANIMS, ANIMS2]:
		var src: Node = (load(file) as PackedScene).instantiate()
		var sap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
		var ratio := sk.get_bone_rest(hip).origin.length() / maxf(ssk.get_bone_rest(ssk.find_bone("pelvis")).origin.length(), 0.001)
		for clip in sap.get_animation_list():
			if lib.has_animation(clip):
				continue
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
		src.free()
	# Weaving on the move: the library has no clip for it, so graft the jog's legs
	# under each casting clip's upper body. Without this the feet slide.
	var jog: Animation = lib.get_animation("Jog_Fwd")
	for clip in CASTS + ["Spell_Simple_Enter", "Spell_Simple_Idle"]:
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
	_libs[kind] = lib
	return lib
