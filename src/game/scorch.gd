class_name Scorch
## Where the grass has burned this round, for the view: a small greyscale map over
## the field (the global shader texture burn_map, placed by burn_rect = x0, z0,
## width, depth). The grass shader shrinks and blackens blades over burnt ground.

const RES := 128
static var _img: Image
static var _tex: ImageTexture
static var _rect := Vector4(-64, -64, 128, 128)

## A fresh map for a fight, covering `half` metres each way from the middle.
static func setup(half: float) -> void:
	_img = Image.create(RES, RES, false, Image.FORMAT_L8)
	_img.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(_img)
	_rect = Vector4(-half, -half, half * 2.0, half * 2.0)
	RenderingServer.global_shader_parameter_set("burn_map", _tex)
	RenderingServer.global_shader_parameter_set("burn_rect", _rect)

## Grass burnt in a circle.
static func burn(at: Vector3, r: float) -> void:
	if _img == null:
		return
	var cx := (at.x - _rect.x) / _rect.z * RES
	var cz := (at.z - _rect.y) / _rect.w * RES
	var rp := r / _rect.z * RES
	for y in range(maxi(int(cz - rp) - 1, 0), mini(int(cz + rp) + 2, RES)):
		for x in range(maxi(int(cx - rp) - 1, 0), mini(int(cx + rp) + 2, RES)):
			var d := Vector2(x - cx, y - cz).length() / maxf(rp, 0.5)
			if d < 1.0:
				var v := maxf(_img.get_pixel(x, y).r, clampf((1.0 - d) * 2.5, 0.0, 1.0))
				_img.set_pixel(x, y, Color(v, v, v))
	_tex.update(_img)
