extends Node
## Offline, Escape stops the world and lets the cursor go, with nothing put on the
## screen (so it can be moved out of the way for a screenshot). Escape again, or a
## click, carries on. It keeps listening while the tree is paused; the fight does not.
var g: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(ev: InputEvent) -> void:
	var tree := get_tree()
	if tree.paused:
		if (ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE) or (ev is InputEventMouseButton and ev.pressed):
			tree.paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE and g.can_pause():
		tree.paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
