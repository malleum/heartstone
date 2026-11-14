extends Node3D
## Bench: every look in Hero.looks(), in rows, each with a different body, to
## check the wardrobe at a glance.
##   SCENE=res://src/test/looks.tscn tools/render.sh renders/looks 20 -- --row=0

func _ready() -> void:
	Rules.load_data()
	var args := Launch.cmdline()
	World.build(self, 20.0, -32.0)
	Terrain.amp = 0.0
	add_child(Terrain.build_mesh(60.0, 2.0))
	var all := Hero.looks()
	var ids := all.keys()
	var row := int(args.get("row", 0))
	var per := int(args.get("per", 8))
	for i in per:
		var k := row * per + i
		if k >= ids.size():
			break
		var style := {skin = k % Hero.SKINS.size(), eyes = k % Hero.EYES.size(), height = k % 5, build = (k * 2) % 5, hair_col = k % Hero.HAIR_COLOURS.size()}
		var who := Hero.instantiate(ids[k], k, style if args.has("vary") else {})
		add_child(who)
		who.position = Vector3((i - (per - 1) * 0.5) * 1.05, 0, 0)
		who.rotation.y = 0.35
		(who.get_meta("anim") as AnimationPlayer).play("Idle")
		var t := Label3D.new(); t.text = all[ids[k]].label.replace(" (", "\n("); t.font_size = 30; t.pixel_size = 0.004
		t.position = who.position + Vector3(0, 2.3, 0); t.billboard = BaseMaterial3D.BILLBOARD_ENABLED; t.outline_size = 10
		add_child(t)
	var cam := Camera3D.new(); cam.fov = 30.0; add_child(cam)
	cam.position = Vector3(0, 1.3, 8.4); cam.look_at(Vector3(0, 1.05, 0))
