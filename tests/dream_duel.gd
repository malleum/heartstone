extends SceneTree
## Two bots duel in Tel'aran'rhiod and the fight is printed: how long it lasts and
## what was used. `godot --headless -s tests/dream_duel.gd -- [warder|aiel|hunter|channeller] [..] [seed] [-v]`
func _init() -> void:
	Rules.load_data(); Map.use("open")
	var a := OS.get_cmdline_user_args()
	var kinds := [a[0] if a.size() > 0 else "warder", a[1] if a.size() > 1 else "warder"]
	var sim := Sim.new("dream_spar", int(a[2]) if a.size() > 2 else 1)
	var ids := []
	for i in 2:
		var p: Dictionary
		if kinds[i] == "channeller":
			p = Profile.create({name = "C%d" % i, potential_pts = 8, affinity_pts = {fire = 4, air = 2}})
			for w in ["fireball", "hammer_of_air", "lightning"]:
				p.weaves[w] = {known = true, xp = 0.0}
		else:
			p = Profile.create({name = "F%d" % i, cls = kinds[i], stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = Rules.CLASSES[kinds[i]].kit})
		ids.append(sim.add_player(p, Vector3(0, 0, 14.0 * i)))
	sim.ents[ids[0]].yaw = 0.0
	var count := {}
	while not sim.over and sim.t < 180.0:
		for id in ids:
			if sim.ents[id].alive:
				Bot.dream(sim, id); Bot.drive(sim, id)
		sim.step(1.0 / 30.0)
		for e in sim.events:
			count[e.e] = count.get(e.e, 0) + 1
			if a.has("-v") and e.e in ["shift", "dream", "denied", "chained", "dream_hit", "blow", "strike", "cast", "blast", "die", "hit"]:
				print("%6.2f %s %s" % [sim.t, e.e, str(e.get("move", e.get("weave", e.get("id", ""))))])
		sim.events.clear()
	print("DUEL %s v %s: %.1f s, hp %d / %d, will %d / %d" % [kinds[0], kinds[1], sim.t, sim.ents[ids[0]].hp, sim.ents[ids[1]].hp, sim.ents[ids[0]].will, sim.ents[ids[1]].will])
	print(count)
	quit()
