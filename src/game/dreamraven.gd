extends Node3D
## A dream raven's view: its wings beat.
var age := randf() * 3.0
func _process(dt: float) -> void:
	age += dt
	var a := sin(age * 18.0) * 0.7
	for c in get_children():
		if c.name == "Wing1": (c as Node3D).rotation.z = a
		elif c.name == "Wing-1": (c as Node3D).rotation.z = -a
