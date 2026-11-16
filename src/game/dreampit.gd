extends Node3D
## A dream pit's view: spreads to the radius the sim gives it; its shards heave.
var age := 0.0
func set_r(radius: float, _yaw: float) -> void:
	for c in get_children():
		if c.name in ["Disc", "Rim"]:
			(c as Node3D).scale = Vector3(radius, 1, radius)
		elif c.has_meta("at"):
			var at: Vector2 = c.get_meta("at")
			(c as Node3D).position.x = at.x * radius; (c as Node3D).position.z = at.y * radius
func _process(dt: float) -> void:
	age += dt
	var i := 0
	for c in get_children():
		if c.has_meta("at"):
			(c as Node3D).position.y = -1.25 + 0.25 * sin(age * 5.0 + i * 1.7)
			i += 1
