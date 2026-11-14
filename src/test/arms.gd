extends Node3D
## Bench: every weapon in data/weapons.json in someone's hand, in rows, to check
## grips and proportions at a glance.
##   SCENE=res://src/test/arms.tscn tools/render.sh renders/armsbench 20 -- [--clip=Sword_Idle] [--row=0]

func _ready() -> void:
	Rules.load_data()
	var args := Launch.cmdline()
	World.build(self, 20.0, -32.0)
	Terrain.amp = 0.0
	add_child(Terrain.build_mesh(60.0, 2.0))
	var ids := Rules.weapons.keys()
	var row := int(args.get("row", 0))
	var per := 7
	for i in per:
		var k := row * per + i
		if k >= ids.size():
			break
		var who := Hero.instantiate(["warder", "aiel_f", "two_rivers_m", "hunter_f"][k % 4], k)
		add_child(who)
		who.position = Vector3((i - (per - 1) * 0.5) * 1.5, 0, 0)
		who.rotation.y = 0.5
		Hero.arm(who, ids[k])
		(who.get_meta("anim") as AnimationPlayer).play(args.get("clip", "Sword_Idle"))
		var t := Label3D.new(); t.text = Rules.weapons[ids[k]].name; t.font_size = 40; t.pixel_size = 0.004
		t.position = who.position + Vector3(0, 2.15, 0); t.billboard = BaseMaterial3D.BILLBOARD_ENABLED; t.outline_size = 10
		add_child(t)
	var cam := Camera3D.new(); cam.fov = 40.0; add_child(cam)
	cam.position = Vector3(0, 1.5, 8.2); cam.look_at(Vector3(0, 1.05, 0))
