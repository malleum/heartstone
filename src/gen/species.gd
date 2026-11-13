class_name Species
extends RefCounted
## Creatures as data. A table maps each parameter to a constant, a Vector2 range, or
## an Array of choices; roll() turns a table plus a seed into a concrete spec.
## Adding a Shadowspawn type should mean adding a table here (and, at most, a head
## recipe in heads.gd).

# Lengths are fractions of height unless noted. bulk/limb/muscle/gut are multipliers
# on a lean human baseline.
const TROLLOC := {
	species = "trolloc",
	height = Vector2(2.3, 2.85),
	leg = Vector2(0.43, 0.47),         # hip joint height
	hip_w = Vector2(0.06, 0.072),
	shoulder_y = Vector2(0.77, 0.80),
	shoulder_w = Vector2(0.165, 0.2),
	neck_len = Vector2(0.035, 0.05),
	arm = Vector2(0.38, 0.43),          # shoulder to wrist
	crouch = Vector2(0.06, 0.1),        # how bent the legs stay
	hand = Vector2(1.6, 2.0),
	hunch = Vector2(0.55, 1.0),
	digit = [0, 1, 1],                  # 1: digitigrade leg (hoof or paw)
	bulk = Vector2(1.3, 1.6),
	limb = Vector2(1.15, 1.4),
	muscle = Vector2(0.6, 1.0),
	gut = Vector2(0.0, 0.8),
	head_size = Vector2(1.3, 1.55),
	head = ["boar", "wolf", "ram", "hawk", "bear"],
	skin = [Color(0.34, 0.27, 0.23), Color(0.25, 0.21, 0.2), Color(0.38, 0.33, 0.27), Color(0.3, 0.28, 0.29), Color(0.33, 0.22, 0.2)],
	fur = [Color(0.09, 0.08, 0.08), Color(0.2, 0.14, 0.1), Color(0.3, 0.29, 0.28), Color(0.24, 0.17, 0.13), Color(0.15, 0.11, 0.09)],
	horn = [Color(0.55, 0.5, 0.4), Color(0.17, 0.15, 0.14), Color(0.38, 0.31, 0.24)],
	fem = 0.0,
	furry = Vector2(0.3, 1.0),          # how far fur spreads over the body
	gear = "trolloc",
	cell = 0.026, head_cell = 0.0075,
}

const HUMAN := {
	species = "human",
	height = Vector2(1.6, 1.9),
	leg = Vector2(0.515, 0.535),
	hip_w = Vector2(0.048, 0.054),
	shoulder_y = Vector2(0.81, 0.82),
	shoulder_w = Vector2(0.095, 0.112),
	neck_len = Vector2(0.066, 0.074),
	arm = Vector2(0.305, 0.32),
	hand = Vector2(0.95, 1.05),
	hunch = Vector2(0.0, 0.1),
	crouch = 0.02,
	digit = 0,
	bulk = Vector2(0.86, 1.04),
	limb = Vector2(0.82, 0.98),
	muscle = Vector2(0.1, 0.6),
	gut = Vector2(0.0, 0.3),
	head_size = Vector2(1.03, 1.09),
	head = "human",
	skin = [Color(0.86, 0.68, 0.57), Color(0.78, 0.58, 0.46), Color(0.62, 0.43, 0.32), Color(0.42, 0.28, 0.2), Color(0.9, 0.74, 0.64)],
	fur = [Color(0.1, 0.08, 0.07), Color(0.28, 0.17, 0.09), Color(0.55, 0.4, 0.2), Color(0.4, 0.17, 0.08), Color(0.6, 0.58, 0.55)],
	horn = Color(0.8, 0.75, 0.7),
	furry = 0.0,
	gear = "clothes",
	outfit = ["two_rivers", "aiel", "aes_sedai", "cairhien", "warder", "domani"],
	fem = [0.0, 1.0],
	hair = ["short", "long", "tail", "bun", "braid", "bald"],
	beard = [0, 0, 1],
	# Face sliders: 1.0 is the neutral face.
	f_jaw = Vector2(0.88, 1.12), f_chin = Vector2(0.7, 1.4), f_cheek = Vector2(0.8, 1.25),
	f_brow = Vector2(0.7, 1.4), f_nose_len = Vector2(0.5, 1.4), f_nose_w = Vector2(0.8, 1.3),
	f_bridge = Vector2(0.8, 1.4), f_lip = Vector2(0.75, 1.3), f_eye = Vector2(0.88, 1.12),
	f_eye_gap = Vector2(0.94, 1.07),
	cell = 0.016, head_cell = 0.0037,
}

static func roll(table: Dictionary, seed_: int, overrides := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_)
	var s := {seed = seed_}
	for key in table:
		var v = table[key]
		if v is Vector2:
			s[key] = rng.randf_range(v.x, v.y)
		elif v is Array:
			s[key] = v[rng.randi() % v.size()]
		else:
			s[key] = v
	s.merge(overrides, true)
	# Tables are written in sRGB (what you'd pick by eye); shading wants linear.
	for key in s:
		if s[key] is Color:
			s[key] = (s[key] as Color).srgb_to_linear()
	return s
