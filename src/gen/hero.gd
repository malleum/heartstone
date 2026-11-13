class_name Hero
## Player characters: sourced Quaternius outfits (assembled by tools/blender/build_heroes.py)
## animated by the Universal Animation Library. Generated humans looked wrong up close,
## and the player stares at this model for the whole game, so it is the one place we
## spend sourced art. Shadowspawn stay generated.

const ANIMS := "res://assets/quaternius/ual1.glb"
const MODEL := "res://assets/quaternius/chars/%s.glb"
const KINDS := ["male_peasant", "female_peasant", "male_ranger", "female_ranger"]
## Origins that dress as travellers and fighters; everyone else wears village clothes.
const RANGER_ORIGINS := ["aiel", "warder", "borderlands", "domani"]

const HAIR := [Color(0.16, 0.1, 0.06), Color(0.38, 0.22, 0.1), Color(0.62, 0.3, 0.12), Color(0.75, 0.6, 0.33), Color(0.07, 0.06, 0.06)]

static var _libs := {}   # kind -> AnimationLibrary fitted to that body's proportions

static func kind_for(profile: Dictionary) -> String:
	if profile.has("look") and profile.look in KINDS:
		return profile.look
	var sex := "female" if profile.get("power", "saidar") == "saidar" else "male"
	return sex + ("_ranger" if profile.get("origin", "") in RANGER_ORIGINS else "_peasant")

static func instantiate(kind: String, seed := 0) -> Node3D:
	var root: Node3D = (load(MODEL % kind) as PackedScene).instantiate()
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap := AnimationPlayer.new()
	root.add_child(ap)
	ap.add_animation_library("", _library(kind, sk))
	ap.playback_default_blend_time = 0.15
	root.set_meta("anim", ap)
	root.set_meta("skeleton", sk)
	var tint: Color = HAIR[absi(hash(str(seed) + kind)) % HAIR.size()]
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		m.extra_cull_margin = 1.0   # skinned bounds lag the pose
		if m.name.begins_with("Hair") or m.name.begins_with("Eyebrows"):
			# The pack ships hair as a grey map meant to be tinted.
			for i in m.mesh.get_surface_count():
				var mat: BaseMaterial3D = m.get_active_material(i).duplicate()
				mat.albedo_color = tint
				m.set_surface_override_material(i, mat)
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
	src.free()
	_libs[kind] = lib
	return lib
