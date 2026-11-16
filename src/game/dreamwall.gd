extends Node3D
## A dream wall's view: as wide as the sim says, across the way its maker faced,
## risen out of the ground in a moment.
var up := 0.0
func set_r(width: float, yaw: float) -> void:
	rotation.y = yaw
	($Stone as Node3D).scale.x = width
func _process(dt: float) -> void:
	up = minf(up + dt * 6.0, 1.0)
	($Stone as Node3D).position.y = -2.4 * (1.0 - up) - 0.15
