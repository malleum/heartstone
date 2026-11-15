class_name Faces
extends RefCounted
## Parametric human head. Same head-local units as heads.gd. Every f_* number in the
## spec is a slider a character creator could expose.

const HEAD := 4

static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

static func build(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var skin: Color = s.skin; skin.a = 0.5
	var hair: Color = s.fur; hair.a = 1.0
	var fem: float = s.fem
	var jw: float = s.f_jaw * lerpf(1.0, 0.9, fem)
	var chin: float = s.f_chin
	var brow: float = s.f_brow * lerpf(1.0, 0.55, fem)
	var nl: float = s.f_nose_len
	var nw: float = s.f_nose_w
	var lip: float = s.f_lip * lerpf(0.9, 1.2, fem)
	var eye: float = s.f_eye
	sd.use(HEAD, skin, 0.03)
	sd.ball(_v(0, 0.1, 0.005), _v(0.075, 0.09, 0.095))
	sd.ball(_v(0, 0.055, 0.04), _v(0.064 * jw, 0.075, 0.06))
	sd.use(HEAD, skin, 0.025)
	sd.ball(_v(0, -0.02 * chin, 0.078), _v(0.024 * jw, 0.02, 0.019))
	for sx in [-1.0, 1.0]:
		sd.use(HEAD, skin, 0.025)
		sd.cone(_v(0.052 * jw * sx, 0.012, 0.012), _v(0.016 * sx, -0.022 * chin, 0.072), 0.022, 0.02)
		sd.ball(_v(0.05 * sx, 0.058, 0.064), _v(0.021, 0.015, 0.02) * s.f_cheek)
		sd.use(HEAD, skin, 0.012)
		sd.ball(_v(0.0145 * nw * sx, 0.0415, 0.106 + 0.005 * nl), _v(0.0098, 0.0085, 0.0105))
		# Ear.
		sd.use(HEAD, skin.lerp(Color(0.5, 0.2, 0.15, 0.5), 0.12), 0.006)
		sd.ball(_v(0.077 * sx, 0.068, -0.002), _v(0.007, 0.03, 0.017), Basis(Vector3.UP, -0.35 * sx))
	sd.use(HEAD, skin, 0.015)
	sd.cone(_v(-0.044, 0.1, 0.086), _v(0.044, 0.1, 0.086), 0.011 * brow, 0.011 * brow)
	sd.use(HEAD, skin, 0.01)
	sd.cone(_v(0, 0.09, 0.097), _v(0, 0.052, 0.111 + 0.009 * nl), 0.0095 * s.f_bridge, 0.0115)
	sd.ball(_v(0, 0.0465, 0.113 + 0.01 * nl), _v(0.0128 * nw, 0.0115, 0.012))
	var blind: bool = s.get("eyeless", false)
	if blind:
		# The Eyeless: gaunt, bloodless, and nothing at all where the eyes should
		# be: skin as smooth as an egg from brow to cheek (Josh, 15 Nov: no hollows).
		# The gap between brow and cheekbone is filled so no socket is even hinted.
		sd.use(HEAD, skin, 0.022)
		for sx in [-1.0, 1.0]:
			sd.ball(_v(0.03 * sx, 0.083, 0.09), _v(0.022, 0.016, 0.018))
		# The mouth is a short hard line turned down at the corners (a wide one reads as a smile).
		var shade := Color(skin.darkened(0.2), 0.5)
		for sx in [-1.0, 1.0]:
			sd.use(HEAD, skin, 0.02)
			sd.ball(_v(0.05 * sx, 0.034, 0.083), _v(0.012, 0.024, 0.014)).op = Sdf.CARVE
			sd.use(HEAD, shade, 0.012)
			sd.ball(_v(0.046 * sx, 0.034, 0.078), _v(0.012, 0.024, 0.014)).op = Sdf.PAINT
			sd.use(HEAD, Color(0.07, 0.06, 0.065, 0.5), 0.002)
			sd.ball(_v(0.0165 * sx, 0.0168, 0.103), _v(0.004, 0.0013, 0.006), Basis(Vector3.BACK, -0.5 * sx)).op = Sdf.PAINT
		sd.use(HEAD, Color(skin.darkened(0.2), 0.5), 0.006)
		sd.ball(_v(0, 0.0215, 0.1), _v(0.016, 0.0035, 0.007))
		sd.ball(_v(0, 0.0155, 0.099), _v(0.015, 0.0035, 0.007))
		sd.use(HEAD, Color(0.07, 0.06, 0.065, 0.5), 0.002)
		sd.ball(_v(0, 0.0185, 0.106), _v(0.0155, 0.0012, 0.006)).op = Sdf.PAINT
	elif s.get("maw", false):
		# A Draghkar: the mouth is a wound, too wide and too red, open on teeth
		# like needles.
		var red := Color(0.42, 0.01, 0.02, 0.5)
		sd.use(HEAD, red, 0.005)
		sd.ball(_v(0, 0.029, 0.1), _v(0.032, 0.008, 0.0095))
		sd.ball(_v(0, 0.004, 0.097), _v(0.029, 0.008, 0.0095))
		sd.use(HEAD, Color(0.02, 0.0, 0.0, 0.5), 0.004)
		sd.ball(_v(0, 0.013, 0.106), _v(0.029, 0.013, 0.015)).op = Sdf.CARVE
		# (Everything is painted as well: blended clay alone takes the skin's colour.)
		# The whole of it raw red, from under the nose to the chin's fold, darker inside.
		sd.use(HEAD, Color(0.26, 0.008, 0.014, 0.5), 0.004)
		sd.ball(_v(0, 0.01, 0.096), _v(0.034, 0.027, 0.024)).op = Sdf.PAINT
		sd.use(HEAD, Color(0.03, 0.0, 0.0, 0.5), 0.003)
		sd.ball(_v(0, 0.008, 0.094), _v(0.027, 0.013, 0.016)).op = Sdf.PAINT
		sd.use(HEAD, Color(0.3, 0.008, 0.015, 0.5), 0.003)
		sd.ball(_v(0, 0.0305, 0.104), _v(0.034, 0.0075, 0.012)).op = Sdf.PAINT
		sd.ball(_v(0, -0.007, 0.1), _v(0.031, 0.0085, 0.016)).op = Sdf.PAINT
		var bone := Color(0.9, 0.88, 0.8, 0.0)
		for i in 7:
			var tx := (i - 3.0) * 0.0075
			var tz := 0.1035 - absf(tx) * 0.1
			for tooth in [[_v(tx, 0.027, tz), _v(tx, 0.011, tz + 0.001)], [_v(tx + 0.0037, -0.002, tz - 0.002), _v(tx + 0.0037, 0.012, tz)]]:
				sd.use(HEAD, bone, 0.001)
				sd.cone(tooth[0], tooth[1], 0.0027, 0.0005)
				sd.cone(tooth[0], tooth[1], 0.0031, 0.0008).op = Sdf.PAINT
	else:
		# Lips: a little geometry, mostly colour.
		var lipc := skin.lerp(Color(0.35, 0.07, 0.06, 0.5), 0.3 + 0.25 * fem)
		sd.use(HEAD, lipc, 0.007)
		sd.ball(_v(0, 0.0235, 0.101), _v(0.021, 0.0055 * lip, 0.008))
		sd.ball(_v(0, 0.013, 0.099), _v(0.019, 0.0065 * lip, 0.008))
		sd.use(HEAD, Color(0.05, 0.015, 0.015, 0.5), 0.0025)
		sd.ball(_v(0, 0.0185, 0.106), _v(0.022, 0.0012, 0.006)).op = Sdf.PAINT
	var eyes := []
	var iris: Color = [Color(0.12, 0.07, 0.03), Color(0.1, 0.2, 0.32), Color(0.16, 0.25, 0.12), Color(0.2, 0.2, 0.22)][rng.randi() % 4]
	# A Myrddraal has smooth skin where eyes would be: no sockets, no eyes, no brows.
	for sx in ([] if s.get("eyeless", false) else [-1.0, 1.0]):
		var ex: float = 0.031 * s.f_eye_gap * sx
		sd.use(HEAD, skin.darkened(0.1), 0.008)
		sd.ball(_v(ex, 0.083, 0.106), _v(0.0175 * eye, 0.0112 * eye, 0.017)).op = Sdf.CARVE
		if s.get("eyes_black", false):
			# Too large, and with nothing in them: no white, no colour, no lid. Clay,
			# like the rest of it, so they sit in the face whatever its shape.
			sd.use(HEAD, Color(0.004, 0.004, 0.006, 0.0), 0.002)
			sd.ball(_v(ex, 0.083, 0.0985), _v(0.0155 * eye, 0.0105 * eye, 0.0115))
			sd.ball(_v(ex, 0.083, 0.1), _v(0.0165 * eye, 0.0112 * eye, 0.013)).op = Sdf.PAINT
			continue
		else:
			eyes.append({pos = _v(ex, 0.0835, 0.0945), r = 0.0128, dir = _v(sx * 0.08, 0, 1), iris = iris})
		# Eyebrow.
		sd.use(HEAD, Color(hair.darkened(0.2), 0.8), 0.004)
		sd.cone(_v(0.014 * sx, 0.1005, 0.1), _v(0.05 * sx, 0.1, 0.086), 0.0045, 0.003).op = Sdf.PAINT
	_hair(sd, s, hair, fem)
	if s.beard == 1 and fem < 0.5:
		sd.use(HEAD, hair, 0.012)
		sd.ball(_v(0, -0.012, 0.06), _v(0.05 * jw, 0.034, 0.04))
		sd.ball(_v(0, 0.031, 0.1), _v(0.024, 0.005, 0.008))
	elif fem < 0.5 and not blind:
		# Stubble shadow.
		sd.use(HEAD, skin.lerp(Color(hair, 0.5), 0.3), 0.02)
		sd.ball(_v(0, -0.005, 0.06), _v(0.055, 0.035, 0.045)).op = Sdf.PAINT
	return eyes

static func _hair(sd: Sdf, s: Dictionary, hair: Color, _fem: float) -> void:
	var style: String = s.hair
	if style == "bald":
		return
	sd.use(HEAD, hair, 0.012)
	# Cap that leaves the forehead clear.
	sd.ball(_v(0, 0.116, -0.016), _v(0.081, 0.087, 0.097))
	sd.ball(_v(0, 0.158, 0.05), _v(0.066, 0.034, 0.05))
	sd.ball(_v(0.02, 0.143, 0.082), _v(0.05, 0.016, 0.02), Basis(Vector3.BACK, 0.2))
	for sx in [-1.0, 1.0]:
		sd.ball(_v(0.071 * sx, 0.105, 0.035), _v(0.013, 0.045, 0.035))
	match style:
		"long":
			sd.use(HEAD, hair, 0.02)
			sd.cone(_v(0, 0.09, -0.07), _v(0, -0.2, -0.075), 0.065, 0.045, Vector2(1, 0.6))
			for sx in [-1.0, 1.0]:
				sd.cone(_v(0.066 * sx, 0.07, -0.02), _v(0.075 * sx, -0.12, 0.0), 0.035, 0.022)
		"tail":
			sd.chain([_v(0, 0.11, -0.1), _v(0, 0.07, -0.14), _v(0, -0.04, -0.13), _v(0, -0.16, -0.1)], 0.03, 0.012)
		"bun":
			sd.ball(_v(0, 0.15, -0.105), _v(0.04, 0.04, 0.035))
		"braid":
			var pts := []
			for i in 7:
				pts.append(_v(0.03 + 0.012 * sin(i * 3.14), 0.08 - i * 0.055, -0.09 + i * 0.006))
			sd.chain(pts, 0.026, 0.014)
