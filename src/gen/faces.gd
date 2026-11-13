class_name Faces
extends RefCounted

static func build(sd: Sdf, s: Dictionary, rng: RandomNumberGenerator) -> Array:
	var skin: Color = s.skin; skin.a = 0.5
	Heads._skull(sd, skin)
	return []
