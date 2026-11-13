class_name Heads
extends RefCounted
## Head recipes, written in head-local human-head units: origin at the skull base,
## +Z out of the face, +Y up. The caller places and scales the brush.
## Each returns the eyes to attach: [{pos, r, dir, iris}].

const HEAD := Creature.HEAD

static func build(sd: Sdf, s: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([s.seed, "head"])
	match s.head:
		"boar": return _boar(sd, s, rng)
		"wolf": return _wolf(sd, s, rng)
		"ram": return _ram(sd, s, rng)
		"hawk": return _hawk(sd, s, rng)
		"bear": return _bear(sd, s, rng)
		"human": return Faces.build(sd, s, rng)
	return []

static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

## Shared Trolloc skull: a heavy-browed, roughly human cranium the beast parts grow from.
static func _skull(sd: Sdf, c: Color, wide := 1.0, brow := 1.0) -> void:
	sd.use(HEAD, c, 0.03)
	sd.ball(_v(0, 0.09, 0.0), _v(0.082 * wide, 0.08, 0.095))
	sd.use(HEAD, c, 0.02)
	sd.cone(_v(-0.05 * wide, 0.103, 0.072), _v(0.05 * wide, 0.103, 0.072), 0.024 * brow, 0.024 * brow)

static func _eyes(sd: Sdf, x: float, y: float, z: float, r: float, iris: Color, toe_out := 0.25) -> Array:
	var out := []
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, Color(0.02, 0.015, 0.015, 0.5), 0.012)
		sd.ball(_v(x * sx, y, z + r * 1.6), _v(r * 1.8, r * 1.3, r * 1.9)).op = Sdf.CARVE
		out.append({pos = _v(x * sx, y, z + r * 0.75), r = r * 1.15, dir = _v(sx * toe_out, -0.05, 1), iris = iris})
	return out

static func _mouth(sd: Sdf, y: float, z0: float, z1: float, w: float) -> void:
	sd.use(HEAD, Color(0.03, 0.01, 0.01, 0.5), 0.008)
	sd.ball(_v(0, y, (z0 + z1) * 0.5), _v(w, 0.007, (z1 - z0) * 0.5)).op = Sdf.CARVE

## Open, snarling mouth: a dark red gash with teeth along the upper jaw and two
## lower fangs. z0..z1 is the length of the muzzle, w its half width.
static func _snarl(sd: Sdf, y: float, z0: float, z1: float, w: float, fang := 1.0) -> void:
	sd.use(HEAD, Color(0.12, 0.012, 0.01, 0.4), 0.008)
	sd.ball(_v(0, y - 0.006, (z0 + z1) * 0.5 + 0.01), _v(w, 0.016, (z1 - z0) * 0.5)).op = Sdf.CARVE
	sd.use(HEAD, Color(0.62, 0.58, 0.46, 0.12), 0.003)
	for sx in [-1.0, 1.0]:
		for i in 4:
			var t := i / 3.0
			var p := _v(sx * w * lerpf(0.8, 0.38, t), y + 0.012, lerpf(z0 + 0.03, z1 - 0.012, t))
			var big := fang if i == 3 else 0.45
			sd.cone(p, p + _v(0, -0.03 * big, 0.002), 0.0075 * (0.7 + 0.5 * big), 0.002)
		var q := _v(sx * w * 0.5, y - 0.024, z1 - 0.03)
		sd.cone(q, q + _v(0, 0.03 * fang, 0.004), 0.008, 0.002)

static func _iris(rng: RandomNumberGenerator) -> Color:
	return [Color(0.55, 0.3, 0.04), Color(0.7, 0.5, 0.08), Color(0.35, 0.42, 0.5), Color(0.6, 0.08, 0.03)][rng.randi() % 4]


static func _boar(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var skin: Color = s.skin; skin.a = 0.5
	var fur: Color = s.fur; fur.a = 1.0
	var tusk := Color(0.6, 0.55, 0.42, 0.12)
	var ln := rng.randf_range(0.85, 1.15)      # snout length
	var tk := rng.randf_range(0.8, 1.4)        # tusk size
	_skull(sd, skin, 1.05, 1.1)
	sd.use(HEAD, skin, 0.03)
	sd.cone(_v(0, 0.055, 0.06), _v(0, 0.03, 0.2 * ln), 0.064, 0.046, Vector2(1, 0.85))
	sd.cone(_v(0, 0.0, 0.03), _v(0, -0.008, 0.17 * ln), 0.052, 0.036)
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, skin, 0.03)
		sd.ball(_v(0.06 * sx, 0.015, 0.04), _v(0.045, 0.05, 0.05))
		sd.use(HEAD, tusk, 0.006)
		sd.chain([_v(0.042 * sx, -0.005, 0.135 * ln), _v(0.07 * sx, 0.025, 0.165 * ln), _v(0.08 * sx, 0.025 + 0.05 * tk, 0.165 * ln), _v(0.072 * sx, 0.025 + 0.095 * tk, 0.145 * ln)], 0.017, 0.004)
		sd.use(HEAD, fur, 0.012)
		sd.cone(_v(0.066 * sx, 0.14, -0.01), _v(0.125 * sx, 0.215, -0.04), 0.034, 0.006, Vector2(1, 0.35))
	# Snout disc and nostrils.
	sd.use(HEAD, Color(0.24, 0.12, 0.1, 0.5), 0.008)
	sd.ball(_v(0, 0.032, 0.2 * ln + 0.04), _v(0.045, 0.04, 0.014))
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, Color(0.02, 0.01, 0.01, 0.5), 0.006)
		sd.ball(_v(0.016 * sx, 0.036, 0.2 * ln + 0.055), _v(0.008, 0.011, 0.012)).op = Sdf.CARVE
	_snarl(sd, 0.012, 0.07, 0.2 * ln, 0.055, 0.6)
	# Bristle ridge over the skull and down the neck.
	sd.use(HEAD, fur, 0.012)
	for i in 6:
		var p := _v(0, 0.165 - i * i * 0.006, 0.05 - i * 0.034)
		sd.cone(p, p + _v(0, 0.05, -0.03), 0.022, 0.005, Vector2(0.6, 1))
	return _eyes(sd, 0.043, 0.082, 0.082, 0.011, _iris(rng))


static func _wolf(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var fur: Color = s.fur; fur.a = 1.0
	var pale := fur.lerp(Color(0.4, 0.37, 0.33, 1.0), 0.35)
	var ln := rng.randf_range(0.9, 1.15)
	var ear := rng.randf_range(0.85, 1.2)
	_skull(sd, fur, 1.0, 0.9)
	sd.use(HEAD, fur, 0.03)
	sd.ball(_v(0, 0.08, 0.07), _v(0.05, 0.04, 0.05))
	sd.cone(_v(0, 0.06, 0.07), _v(0, 0.042, 0.215 * ln), 0.052, 0.028, Vector2(0.8, 1))
	sd.use(HEAD, pale, 0.025)
	sd.cone(_v(0, 0.004, 0.03), _v(0, -0.022, 0.185 * ln), 0.04, 0.02, Vector2(0.8, 1))
	sd.use(HEAD, Color(0.015, 0.012, 0.012, 0.3), 0.008)
	sd.ball(_v(0, 0.05, 0.215 * ln + 0.022), _v(0.018, 0.015, 0.016))
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, fur, 0.012)
		sd.cone(_v(0.055 * sx, 0.15, -0.02), _v(0.08 * sx, 0.15 + 0.125 * ear, -0.04), 0.038, 0.006, Vector2(1, 0.4))
		# Cheek ruff.
		sd.use(HEAD, pale, 0.02)
		sd.ball(_v(0.07 * sx, 0.04, 0.0), _v(0.04, 0.06, 0.05))
		sd.cone(_v(0.08 * sx, 0.03, -0.01), _v(0.125 * sx, -0.02, -0.03), 0.03, 0.006, Vector2(1, 0.5))
	_snarl(sd, 0.022, 0.06, 0.215 * ln, 0.04, 1.2)
	return _eyes(sd, 0.038, 0.088, 0.088, 0.0105, [Color(0.45, 0.33, 0.05), Color(0.25, 0.3, 0.33)][rng.randi() % 2], 0.35)


static func _ram(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var fur: Color = s.fur; fur.a = 1.0
	var skin: Color = s.skin; skin.a = 0.5
	var horn: Color = s.horn; horn.a = 0.0
	var curl := rng.randf() < 0.6
	var hs := rng.randf_range(0.85, 1.25)
	_skull(sd, fur, 0.98, 1.0)
	sd.use(HEAD, fur.lerp(skin, 0.5), 0.03)
	sd.cone(_v(0, 0.078, 0.05), _v(0, 0.008, 0.17), 0.058, 0.037, Vector2(0.85, 1))
	sd.cone(_v(0, 0.0, 0.03), _v(0, -0.028, 0.145), 0.04, 0.026)
	sd.use(HEAD, Color(0.05, 0.03, 0.03, 0.5), 0.01)
	sd.ball(_v(0, 0.0, 0.2), _v(0.022, 0.016, 0.012))
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, horn, 0.008)
		var pts := []
		if curl:
			# Ram: a spiral that leaves the crown backwards and comes round to the cheek.
			for i in 9:
				var t := i / 8.0
				var ang := -0.35 + t * 4.7
				var r := (0.088 - 0.022 * t) * hs
				pts.append(_v((0.06 + 0.075 * t * hs) * sx, 0.085 + r * cos(ang), -0.015 - r * sin(ang)))
			sd.chain(pts, 0.04 * hs, 0.008)
		else:
			# Goat: long back-swept blades.
			pts = [_v(0.04 * sx, 0.15, 0.025), _v(0.055 * sx, 0.15 + 0.1 * hs, -0.02), _v(0.08 * sx, 0.15 + 0.18 * hs, -0.11 * hs), _v(0.11 * sx, 0.15 + 0.22 * hs, -0.21 * hs)]
			sd.chain(pts, 0.03, 0.006, Vector2(0.75, 1))
		sd.use(HEAD, fur, 0.01)
		sd.cone(_v(0.07 * sx, 0.1 if not curl else 0.075, -0.02), _v(0.155 * sx, 0.085 if not curl else 0.05, -0.045), 0.03, 0.008, Vector2(0.4, 1))
		sd.use(HEAD, Color(0.02, 0.01, 0.01, 0.5), 0.005)
		sd.ball(_v(0.012 * sx, 0.006, 0.208), _v(0.005, 0.009, 0.008)).op = Sdf.CARVE
	sd.use(HEAD, fur, 0.012)
	sd.cone(_v(0, -0.03, 0.1), _v(0, -0.15, 0.115), 0.03, 0.005)
	_snarl(sd, -0.006, 0.06, 0.185, 0.034, 0.5)
	return _eyes(sd, 0.045, 0.085, 0.082, 0.011, _iris(rng), 0.5)


static func _hawk(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var fur: Color = s.fur; fur.a = 1.0
	var beak := Color(0.3, 0.22, 0.07, 0.12)
	var hook := rng.randf_range(0.8, 1.25)
	_skull(sd, fur, 0.95, 0.6)
	sd.use(HEAD, beak, 0.014)
	sd.chain([_v(0, 0.072, 0.075), _v(0, 0.07, 0.15), _v(0, 0.05, 0.2), _v(0, 0.05 - 0.05 * hook, 0.218)], 0.05, 0.009, Vector2(0.72, 1))
	sd.cone(_v(0, 0.018, 0.06), _v(0, 0.004, 0.165), 0.036, 0.012, Vector2(0.8, 0.7))
	sd.use(HEAD, Color(0.03, 0.025, 0.02, 0.0), 0.02)
	sd.ball(_v(0, 0.05 - 0.05 * hook, 0.218), _v(0.012, 0.012, 0.012)).op = Sdf.PAINT
	for sx in [-1.0, 1.0]:
		# Scowling feathered brows.
		sd.use(HEAD, fur, 0.012)
		sd.cone(_v(0.012 * sx, 0.098, 0.105), _v(0.075 * sx, 0.125, 0.06), 0.02, 0.016)
		sd.ball(_v(0.07 * sx, 0.03, 0.0), _v(0.04, 0.07, 0.06))
		sd.use(HEAD, Color(0.02, 0.01, 0.01, 0.5), 0.004)
		sd.ball(_v(0.018 * sx, 0.085, 0.14), _v(0.006, 0.005, 0.01)).op = Sdf.CARVE
	_mouth(sd, 0.03, 0.06, 0.2, 0.045)
	# Crest of swept-back feathers.
	sd.use(HEAD, fur.lerp(Color(0.4, 0.35, 0.25, 1.0), 0.3), 0.01)
	for i in 7:
		var x := (i - 3) * 0.022
		var p := _v(x, 0.155 - absf(x) * 0.5, 0.01 - (i % 2) * 0.03)
		sd.cone(p, p + _v(x * 0.8, 0.03 + (i % 3) * 0.012, -0.16), 0.024, 0.004, Vector2(1, 0.4))
	return _eyes(sd, 0.042, 0.086, 0.084, 0.0135, Color(0.6, 0.38, 0.02), 0.6)


static func _bear(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var fur: Color = s.fur; fur.a = 1.0
	var tan := fur.lerp(Color(0.2, 0.13, 0.08, 1.0), 0.35)
	var w := rng.randf_range(1.1, 1.3)
	_skull(sd, fur, w, 1.25)
	sd.use(HEAD, fur, 0.03)
	sd.ball(_v(0, 0.07, 0.03), _v(0.085 * w, 0.075, 0.08))
	sd.use(HEAD, tan, 0.03)
	sd.cone(_v(0, 0.055, 0.07), _v(0, 0.04, 0.195), 0.058, 0.04, Vector2(1, 0.9))
	sd.cone(_v(0, -0.004, 0.03), _v(0, -0.03, 0.17), 0.05, 0.03)
	sd.use(HEAD, Color(0.015, 0.012, 0.012, 0.3), 0.008)
	sd.ball(_v(0, 0.056, 0.228), _v(0.024, 0.017, 0.015))
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, fur, 0.012)
		sd.ball(_v(0.082 * w * sx, 0.15, -0.025), _v(0.026, 0.026, 0.012))
		sd.use(HEAD, fur, 0.03)
		sd.ball(_v(0.07 * sx, 0.015, 0.03), _v(0.05, 0.055, 0.055))
	_snarl(sd, 0.014, 0.07, 0.2, 0.05, 1.3)
	return _eyes(sd, 0.04, 0.086, 0.088, 0.0095, _iris(rng), 0.2)
