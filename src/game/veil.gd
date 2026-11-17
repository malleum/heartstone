class_name Veil
## The light of a doorway filling the screen while you pass through it. It lives
## under the tree's root, so it covers the change from camp to fight (and back):
## one scene raises it, the next lowers it once its world is built and drawn.

static func _rect() -> ColorRect:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.root.get_node_or_null("Veil") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new(); layer.name = "Veil"; layer.layer = 40
		tree.root.add_child(layer)
		var r := ColorRect.new(); r.name = "Light"; layer.add_child(r)
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/veil.gdshader")
		m.set_shader_parameter("amount", 0.0)
		r.material = m
	return layer.get_node("Light")

static func up() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.root.get_node_or_null("Veil")
	return layer != null and float((layer.get_node("Light") as ColorRect).material.get_shader_parameter("amount")) > 0.01

## Close the light in over `secs`, in a doorway's colour; `then` runs when it is whole.
static func cover(tint: Color, secs: float, then := Callable()) -> void:
	if DisplayServer.get_name() == "headless":
		if then.is_valid(): then.call()
		return
	var r := _rect()
	var m := r.material as ShaderMaterial
	m.set_shader_parameter("tint", tint)
	var tw := r.create_tween()
	tw.tween_property(m, "shader_parameter/amount", 1.0, secs).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if then.is_valid():
		tw.tween_callback(then)

## Let the world through again.
static func lift(secs: float) -> void:
	if not up():
		return
	var r := _rect()
	r.create_tween().tween_property(r.material, "shader_parameter/amount", 0.0, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
