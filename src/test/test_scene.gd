extends Node3D

func _ready() -> void:
	print("adapter: ", RenderingServer.get_video_adapter_name(), " | ", RenderingServer.get_rendering_device() != null)
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 1, 4)
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-40, 30, 0); l.shadow_enabled = true
	var m := MeshInstance3D.new(); m.mesh = TorusMesh.new(); add_child(m)
	var e := WorldEnvironment.new(); e.environment = Environment.new(); add_child(e)
	e.environment.background_mode = Environment.BG_SKY; e.environment.sky = Sky.new(); e.environment.sky.sky_material = ProceduralSkyMaterial.new()
