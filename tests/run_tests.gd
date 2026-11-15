extends SceneTree
## Headless rules tests: godot --headless --path . -s tests/run_tests.gd
## Plays whole activities with a bot and checks the rules and progression pacing.

var fails := 0

func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL: ", what)

func play(profile: Dictionary, activity: String, max_s := 600.0) -> Sim:
	var sim := Sim.new(activity, 3)
	var id := sim.add_player(profile)
	while not sim.over and sim.t < max_s:
		Bot.drive(sim, id)
		sim.step(1.0 / 30.0)
		sim.events.clear()
	return sim

## One fighter alone with one enemy standing `dist` in front, for exact checks.
func duel(profile: Dictionary, enemy: String, dist: float) -> Array:
	var sim := Sim.new("camp_training", 5)
	sim._waves = []
	var id := sim.add_player(profile, Vector3.ZERO)
	sim._add_enemy(enemy, Vector3(0, 0, dist))
	sim.events.clear()
	return [sim, id, sim.ents[id + 1]]

func run(sim: Sim, secs: float) -> Array:
	var seen := []
	var steps := int(secs * 30.0)
	for i in steps:
		sim.step(1.0 / 30.0)
		for e in sim.events:
			seen.append(e.e)
		sim.events.clear()
	return seen

func _powers() -> void:
	print("== what each Power does, gateways, Healing")
	Map.use("open")
	var p := Profile.create({name = "Powers", potential_pts = 14, affinity_pts = {spirit = 2, air = 2}})
	for w in ["lightning", "blade_of_spirit", "gateway", "healing", "fireball"]:
		p.weaves[w] = {known = true, xp = 0.0}
	p.channelled = Rules.TUNE.flow_steps[4]
	# Lightning: survivors run wild, and the next blow sends the charge on.
	var sim := Sim.new("camp_training", 3)
	sim._waves = []
	var id := sim.add_player(p)
	for i in 3:
		sim._add_enemy("trolloc", Vector3(i * 1.5 - 1.5, 0, 14.0))
		sim.ents[id + 1 + i].hp = 5000.0
	var a: Dictionary = sim.ents[id + 1]; var b: Dictionary = sim.ents[id + 2]
	sim._hurt(a, 10.0, id, "lightning")
	check(a.get("charge", 0.0) > 0.0, "lightning leaves a survivor charged")
	a.stagger = 0.0; a.speed = 3.0; b.speed = 3.0
	var z0: float = a.pos.z; var z1: float = b.pos.z
	run(sim, 1.5)
	check((z0 - a.pos.z) > (z1 - b.pos.z) * 1.25, "a charged Trolloc runs faster than the others")
	var hp_b: float = b.hp
	var seen := []
	sim._hurt(a, 5.0, id, "fireball")
	for e in sim.events: seen.append(e.e)
	check(seen.has("arc") and b.hp < hp_b and a.charge == 0.0, "the next blow sends the charge to its neighbours")
	# Spirit: dazed, it does not attack; and a Myrddraal cannot slip it.
	sim = Sim.new("camp_training", 3)
	sim._waves = []
	id = sim.add_player(p)
	sim._add_enemy("trolloc", Vector3(0, 0, 1.6))
	sim._hurt(sim.ents[id + 1], 1.0, id, "blade_of_spirit")
	seen = run(sim, 2.5)
	check(not seen.has("swing") and sim.ents[id].hp == sim.ents[id].max_hp, "a Trolloc dazed by Spirit does not attack")
	check(run(sim, 3.0).has("swing"), "and comes back to itself")
	sim._add_enemy("myrddraal", Vector3(0, 0, 30.0))
	var fade: Dictionary = sim.ents[id + 2]
	var landed := 0
	for i in 40:
		var h0: float = fade.hp
		fade.daze = 0.0
		sim._hurt(fade, 0.01, id, "blade_of_spirit")
		if fade.hp < h0: landed += 1
	check(landed == 40, "a Myrddraal cannot step aside from Spirit")
	# A gateway: step in here, step out there; closed when it is let go.
	sim = Sim.new("camp_training", 3)
	sim._waves = []
	id = sim.add_player(p)
	sim._add_enemy("dummy", Vector3(60, 0, -60))
	var me: Dictionary = sim.ents[id]
	me.yaw = 0.0
	check(sim.request_cast(id, "gateway", Vector3(0, 0, 40)) == "", "someone strong enough can open a gateway")
	run(sim, 4.5)
	check(me.held.size() == 1 and sim.effects.size() == 1, "it stays open while held")
	sim.set_input(id, Vector3(0, 0, 1), 0.0)
	seen = run(sim, 1.5)
	check(seen.has("gate_pass") and me.pos.z > 35.0, "walking into it comes out forty paces away (z=%.0f)" % me.pos.z)
	sim.set_input(id, Vector3.ZERO, 0.0)
	sim.request_cast(id, "gateway", me.pos)
	run(sim, 0.3)
	check(sim.effects.is_empty() and me.held.is_empty(), "weaving it again closes it")
	var weak := Profile.create({name = "Weak", potential_pts = 2})
	weak.weaves["gateway"] = {known = true, xp = 0.0}
	check(Rules.cast_block(weak, "gateway", 9, 1500.0).begins_with("needs strength"), "the weak cannot make a gateway at all")
	# Healing: someone else, in reach; and it ends a festering wound.
	sim = Sim.new("camp_training", 3)
	sim._waves = []
	id = sim.add_player(p)
	check(sim.request_cast(id, "healing", sim.ents[id].pos).begins_with("no one there"), "Healing alone is refused: you cannot Heal yourself")
	var friend := sim.add_player(Profile.create({name = "Friend"}), Vector3(3, 0, 0))
	sim._add_enemy("dummy", Vector3(60, 0, -60))
	sim.ents[friend].hp = 20.0; sim.ents[friend].fester = 9.0; sim.ents[friend].fester_dps = 0.0
	check(sim.request_cast(id, "healing", sim.ents[friend].pos) == "", "Healing a friend is allowed")
	run(sim, 2.5)
	check(sim.ents[friend].hp > 50.0 and sim.ents[friend].fester == 0.0, "it mends them and ends the festering")

func _foes() -> void:
	print("== walls, archers and the Eyeless")
	var p := Profile.create({name = "Stander", cls = "warder", stat_pts = {endurance = 4}})
	# The breastwork is solid, and a Trolloc finds the gap.
	var sim := Sim.new("tarwins_gap_watch", 2)
	sim._waves = []
	var wall: Dictionary = Map.walls()[Map.walls().size() / 2]
	var id := sim.add_player(p, Vector3(wall.x, 0, wall.z + 2.5))
	sim._add_enemy("trolloc", Vector3(wall.x, 0, wall.z - 6.0))
	var foe: Dictionary = sim.ents[id + 1]
	check(Map.crosses(foe.pos, sim.ents[id].pos) and not Map.crosses(Vector3(40, 0, 10), Vector3(41, 0, 12)), "the wall lies between them")
	var inside := false; var reached := false
	foe.hp = 99999.0
	for i in 600:
		sim.step(1.0 / 30.0); sim.events.clear()
		if absf(foe.pos.x - wall.x) < wall.hx - 0.1 and absf(foe.pos.z - wall.z) < wall.hz - 0.1: inside = true
		if foe.pos.distance_to(sim.ents[id].pos) < 3.2 and foe.pos.z > wall.z: reached = true
	check(not inside, "a Trolloc does not walk through the breastwork")
	check(reached, "it goes round through a gap and reaches the defender")
	# Archers: standing in the open you are shot; ducked behind the wall you are not.
	var shots := {}
	for how in ["standing", "ducked behind the wall"]:
		sim = Sim.new("tarwins_gap_watch", 2)
		sim._waves = []
		wall = Map.walls()[Map.walls().size() / 2]
		id = sim.add_player(p, Vector3(wall.x, 0, wall.z + 0.9))
		sim._add_enemy("trolloc_archer", Vector3(wall.x, 0, wall.z - 15.0))
		sim.ents[id + 1].speed = 0.001
		var loosed := 0
		for i in 900:
			if how != "standing": sim.set_duck(id, true)
			sim.step(1.0 / 30.0)
			for e in sim.events:
				if e.e == "loose": loosed += 1
			sim.events.clear()
		shots[how] = sim.ents[id].max_hp - sim.ents[id].hp
		check(loosed >= 6, "the archer looses (%d arrows, %s)" % [loosed, how])
	check(shots["standing"] > 20.0, "arrows wound someone standing at the wall (%d)" % int(shots["standing"]))
	check(shots["ducked behind the wall"] < shots["standing"] * 0.25, "the breastwork is cover (%d)" % int(shots["ducked behind the wall"]))
	# The Myrddraal: hard to hit, cannot be put down, its wounds fester, and its Trollocs die with it.
	sim = Sim.new("camp_training", 9)
	sim._waves = []
	id = sim.add_player(p)
	sim._spawn_wave({spawn = {myrddraal = 1, trolloc = 3}})
	var fade: Dictionary = {}
	for k in sim.ents:
		if sim.ents[k].get("type", "") == "myrddraal": fade = sim.ents[k]
	var landed := 0
	for i in 200:
		var hp0: float = fade.hp
		sim._hurt(fade, 0.01, id, "sword")
		if fade.hp < hp0: landed += 1
	check(landed > 60 and landed < 140, "about half of what is aimed at a Myrddraal lands (%d of 200)" % landed)
	sim._wound(fade, 0.01, id, "sword", {down = 2.0}, Vector3(0, 0, 1))
	check(fade.down == 0.0, "it cannot be knocked down")
	fade.pos = sim.ents[id].pos + Vector3(0, 0, 1.5)
	var seen := run(sim, 3.0)
	check(seen.has("fester") and sim.ents[id].get("fester", 0.0) > 0.0, "its blade leaves a festering wound")
	fade.hp = 0.001; fade.stagger = 1.0
	sim._hurt(fade, 1.0, id, "sword")
	var left := 0
	for k in sim.ents:
		if sim.ents[k].alive and sim.ents[k].kind == "enemy": left += 1
	check(not fade.alive and left == 0, "when it dies, the Trollocs linked to it die too")
	# The wagon ring: they come from all sides, and it can be played to an end.
	var pair := Sim.new("wagon_ring", 4)
	var weaver := Profile.create({name = "Ring Weaver", potential_pts = 8, affinity_pts = {fire = 6}})
	weaver.weaves["dome_of_air"] = {known = true, xp = 0.0}
	var a := pair.add_player(weaver, Vector3(0, 0, 1)); var b := pair.add_player(p, Vector3(1, 0, 0))
	var quarters := {}
	while not pair.over and pair.t < 500.0:
		Bot.drive(pair, a); Bot.drive(pair, b)
		pair.step(1.0 / 30.0)
		for e in pair.events:
			if e.e == "spawn": quarters[int(signf(e.pos.x)) * 2 + int(signf(e.pos.z))] = true
		pair.events.clear()
	print("  wagon ring, weaver and Warder: %s in %.0fs" % ["won" if pair.success else "lost", pair.t])
	check(pair.over and quarters.size() == 4, "the wagon ring is attacked from every side and plays to an end")
	Map.use("open")

func _holds() -> void:
	print("== holding weaves")
	var p := Profile.create({name = "Holder", potential_pts = 8, affinity_pts = {air = 4, fire = 2}})
	for w in ["bonds_of_air", "dome_of_air", "fireball", "lightning"]:
		p.weaves[w] = {known = true, xp = 0.0}
	check(Rules.flow_capacity(p) == 2, "a new channeller holds two flows")
	var d := duel(p, "trolloc", 8.0)
	var sim: Sim = d[0]; var id: int = d[1]; var foe: Dictionary = d[2]
	var me: Dictionary = sim.ents[id]
	check(sim.request_cast(id, "bonds_of_air", foe.pos) == "", "Bonds of Air can be woven at a Trolloc")
	run(sim, 1.3)
	var where: Vector3 = foe.pos
	var seen := run(sim, 2.0)
	check(foe.get("bound_by", 0) == id and foe.pos.distance_to(where) < 0.05 and not seen.has("swing"), "the Trolloc is held where it stands")
	check(sim.free_slots(me) == 1, "holding it takes one of the two flows")
	check(sim.request_cast(id, "lightning", foe.pos) == "too many flows", "so a two-flow weave no longer fits")
	check(sim.request_cast(id, "fireball", sim.aim_at(me, "fireball", foe)) == "", "but a one-flow weave does")
	var st0: float = me.stamina
	run(sim, 3.0)
	check(me.stamina < st0 - 6.0 + 3.0 * Rules.TUNE.stamina_regen, "holding costs breath every second")
	check(sim.tie(id, "bonds_of_air") != "", "tying off must be learned")
	p.techniques = ["tie_off"]
	check(sim.tie(id, "bonds_of_air") == "" and sim.free_slots(me) == 2, "tied off, the weave holds itself and the flow is free")
	run(sim, 2.0)
	check(foe.get("bound_by", 0) == id, "and it goes on holding")
	run(sim, Rules.tie_time(p, "bonds_of_air") + 1.0)
	check(foe.get("bound_by", 0) == 0 and me.held.is_empty(), "until the knot runs out")
	# Let go by weaving it again at the same one; and the strong break free.
	foe.hp = 9999.0; foe.max_hp = 9999.0
	me.cd = {}
	sim.request_cast(id, "bonds_of_air", foe.pos); run(sim, 1.3)
	check(foe.get("bound_by", 0) == id, "held again")
	sim.request_cast(id, "bonds_of_air", foe.pos); run(sim, 0.2)
	check(foe.get("bound_by", 0) == 0 and me.held.is_empty(), "weaving it at them again lets go")
	d = duel(p, "trolloc_brute", 8.0)
	sim = d[0]
	sim.request_cast(d[1], "bonds_of_air", d[2].pos)
	seen = run(sim, 1.3)
	check(d[2].get("bound_by", 0) == d[1], "a bandleader can be held")
	check(run(sim, 30.0).has("broke") and d[2].get("bound_by", 0) == 0, "but strains free in time")
	# The dome is held too, and what holds it dies with you.
	d = duel(p, "trolloc", 8.0)
	sim = d[0]; me = sim.ents[d[1]]
	sim.request_cast(d[1], "dome_of_air", me.pos); run(sim, 1.7)
	sim.request_cast(d[1], "bonds_of_air", d[2].pos); run(sim, 1.3)
	check(me.held.size() == 2 and sim.free_slots(me) == 0 and me.barrier > 0.0, "dome and bonds together fill both flows")
	check(sim.request_cast(d[1], "fireball", d[2].pos) == "too many flows", "and leave nothing to attack with: the third flow is what changes that")
	p.channelled = Rules.TUNE.flow_steps[3]
	check(sim.request_cast(d[1], "fireball", sim.aim_at(me, "fireball", d[2])) == "", "with three flows you hold both and still throw fire")
	me.hp = 1.0; me.barrier = 0.0
	sim._hurt(me, 50.0, d[2].id, "")
	check(d[2].get("bound_by", 0) == 0, "the dead hold nothing")

func _arms() -> void:
	print("== arms")
	var warder := Profile.create({name = "Test Warder", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, skill_pts = {sword = 3}})
	var aiel := Profile.create({name = "Test Aiel", cls = "aiel", sex = "f", stat_pts = {might = 2, quickness = 5, endurance = 3}, skill_pts = {spear = 3}})
	var hunter := Profile.create({name = "Test Hunter", cls = "hunter", stat_pts = {might = 4, quickness = 3, endurance = 2}, skill_pts = {bow = 3, staff = 2}})
	check(warder.kit.has("sword") and aiel.kit.has("aiel_spear") and hunter.kit.has("longbow"), "each class starts with its kit")
	check(Rules.wield_block(aiel, "sword") != "" and Rules.wield_block(warder, "sword") == "", "an Aiel will not carry a sword")
	check(Rules.wield_block(warder, "ashandarei") != "" and Rules.wield_block(hunter, "ashandarei") == "", "the ashandarei is a Hunter's")
	check(Rules.skill_level(warder, "sword") == 3 and Rules.skill_level(warder, "spear") == 0, "creation points buy a starting skill")
	var chan := Profile.create({name = "Test Asha'man", power = "saidin", kit = ["sword", "longbow"]})
	check(chan.kit == ["sword"], "a channeller carries one weapon")
	chan.skills.sword = 100000.0
	check(Rules.skill_level(chan, "sword") == 4, "a channeller's weapon skill has a low ceiling")
	check(Profile.valid(warder) and Profile.valid(chan), "fighters and armed channellers pass the host's check")
	check(Rules.blow(warder, "sword", "cut") > Rules.blow(warder, "sword", "cut", 0.0), "a tired fighter hits softer")
	check(Rules.move_times(aiel, "aiel_spear", "jab")[0] < Rules.moves.jab.wind, "quickness and skill shorten the wind-up")

	# Every move of every weapon does what its row says against a post.
	var every := Profile.create({name = "Every", cls = "hunter", stat_pts = {might = 8}})
	var bad := []
	for w in Rules.weapons:
		every.kit = [w]
		for kind in ["light", "light", "light", "light", "light", "heavy", "low", "throw"]:
			var d := duel(every, "dummy", 1.2)
			var sim: Sim = d[0]; var foe: Dictionary = d[2]
			# Walk the chain to the blow under test.
			var why := sim.request_attack(d[1], kind, foe.pos + Vector3(0, 1, 0))
			if kind == "throw" and not Rules.weapons[w].has("throw"):
				if why == "": bad.append(w + " threw")
				continue
			run(sim, 4.0)
			if why != "" or foe.hp >= foe.max_hp:
				bad.append("%s %s (%s)" % [w, kind, why])
				break
	check(bad.is_empty(), "every weapon's moves land: " + ", ".join(bad))

	# A chain walks through the light moves, and a pause starts it again.
	var d := duel(warder, "dummy", 1.4)
	var sim: Sim = d[0]
	d[2].hp = 99999.0
	var moves := []
	for i in 3:
		sim.request_attack(d[1], "light", d[2].pos)
		moves.append(sim.ents[d[1]].swing.move)
		run(sim, 0.75)
	check(moves == ["cut", "backcut", "finisher"], "tapping chains cut, back-cut, finishing cut: " + str(moves))
	run(sim, 2.0)
	sim.request_attack(d[1], "light", d[2].pos)
	check(sim.ents[d[1]].swing.move == "cut", "a pause begins the chain again")

	# Defence against a Trolloc's blow. Force each attack kind in turn.
	var saved: Array = Rules.enemies.trolloc.attacks
	var hurt := {}
	for kind in ["chop", "sweep", "thrust"]:
		for how in ["stand", "guard", "parry", "duck", "sidestep", "walk_aside"]:
			Rules.enemies.trolloc.attacks = saved.filter(func(a: Dictionary) -> bool: return a.kind == kind)
			d = duel(warder, "trolloc", 1.6)
			sim = d[0]
			var me: Dictionary = sim.ents[d[1]]
			me.yaw = 0.0
			var done := false
			var t := 0.0
			while t < 3.0 and not done:
				var foe: Dictionary = d[2]
				match how:
					"guard":
						if foe.swung and foe.atk >= foe.blow.time - 0.36: sim.set_guard(d[1], true)
					"parry":
						if foe.swung and foe.atk >= foe.blow.time - 0.1: sim.set_guard(d[1], true)
					"duck": sim.set_duck(d[1], true)
					"sidestep":
						if foe.swung and foe.atk >= foe.blow.time - 0.12: sim.request_dodge(d[1], Vector3(1, 0, 0))
					"walk_aside":
						if foe.swung: sim.set_input(d[1], Vector3(1, 0, 0), 0.0)
				sim.step(1.0 / 30.0); t += 1.0 / 30.0
				for e in sim.events:
					if e.e in ["attack", "miss", "evade", "parry"]:
						done = true
				sim.events.clear()
			hurt[kind + "/" + how] = me.max_hp - me.hp
	Rules.enemies.trolloc.attacks = saved
	for kind in ["chop", "sweep", "thrust"]:
		check(hurt[kind + "/stand"] > 10.0, "standing still, a %s lands" % kind)
		check(hurt[kind + "/guard"] < hurt[kind + "/stand"] * 0.4, "a parry pressed in time stops most of a %s" % kind)
		check(hurt[kind + "/parry"] == 0.0, "a parry at the last moment stops all of a %s" % kind)
		check(hurt[kind + "/sidestep"] == 0.0, "a sidestep at the last moment avoids a %s" % kind)
	check(hurt["sweep/duck"] == 0.0, "a sweep passes over a duck")
	check(hurt["chop/duck"] > 10.0 and hurt["thrust/duck"] > 10.0, "a chop or a thrust does not")
	check(hurt["chop/walk_aside"] == 0.0 and hurt["thrust/walk_aside"] == 0.0, "walking out of a chop's or a thrust's line makes it miss")
	check(hurt["sweep/walk_aside"] > 10.0, "a sweep is too wide to walk out of")

	# A guard costs breath, and with none left it breaks.
	d = duel(warder, "trolloc_brute", 1.6)
	sim = d[0]
	sim.ents[d[1]].stamina = 6.0
	sim.ents[d[1]].yaw = 0.0
	var broke := false
	for i in 90:
		if d[2].swung and d[2].atk >= d[2].blow.time - 0.36: sim.set_guard(d[1], true)
		broke = broke or run(sim, 1.0 / 30.0).has("guard_break")
	check(broke, "a parry with no stamina behind it breaks")
	# Holding the button is not a guard: pressed long before, it stops nothing.
	d = duel(warder, "trolloc", 1.6)
	sim = d[0]; sim.ents[d[1]].yaw = 0.0
	sim.set_guard(d[1], true)
	run(sim, 3.0)
	check(sim.ents[d[1]].hp < sim.ents[d[1]].max_hp, "a parry pressed long before the blow stops nothing")
	# A perfect parry shakes the one who struck and throws it back a step.
	d = duel(warder, "trolloc", 1.6)
	sim = d[0]; sim.ents[d[1]].yaw = 0.0
	var gap0 := 0.0; var shaken := false
	for i in 120:
		if d[2].swung and d[2].atk >= d[2].blow.time - 0.08 and not shaken: sim.set_guard(d[1], true)
		if not shaken: gap0 = d[2].pos.distance_to(sim.ents[d[1]].pos)
		if run(sim, 1.0 / 30.0).has("parry"): shaken = true
		if shaken and d[2].stagger < 1.0: break
	check(shaken and d[2].pos.distance_to(sim.ents[d[1]].pos) > gap0 + 0.5, "a perfect parry shakes the attacker and throws it back a step")

	# Missiles: an arrow reaches a distant Trolloc, and the quiver empties.
	d = duel(hunter, "trolloc", 30.0)
	sim = d[0]
	sim.equip(d[1], "longbow")
	sim.request_attack(d[1], "light", sim.aim_missile(sim.ents[d[1]], "longbow", d[2]))
	run(sim, 2.5)
	check(d[2].hp < d[2].max_hp and sim.ents[d[1]].ammo.longbow == 29, "an arrow flies thirty paces and one is gone from the quiver")
	sim.ents[d[1]].ammo.longbow = 0
	check(sim.request_attack(d[1], "light", d[2].pos) == "none left", "an empty quiver refuses")

	print("== fighters through the activities")
	for who in [warder, aiel, hunter]:
		for act in ["camp_training", "tarwins_gap_watch"]:
			var s := play(who, act)
			var tl: Dictionary = s.tallies[1]
			print("  %s, %s: %s in %.0fs, %d blows, health %d, stamina %d" % [who.name, act, "won" if s.success else "LOST", s.t, tl.blows.values().reduce(func(x, y): return x + y, 0), int(maxf(s.ents[1].hp, 0.0)), int(s.ents[1].stamina)])
			check(s.success, "%s can win %s" % [who.name, act])
			for line in Progression.award(who, tl, act, s.success):
				print("    + ", line)
		check(who.weaves.is_empty(), "%s learns no weaves" % who.name)
	check(warder.skills.sword > 3 * 3 * Rules.TUNE.skill_xp, "fighting raises the skill of the weapon used")

	print("== a fighter and a channeller together")
	var both := Sim.new("tarwins_gap_watch", 4)
	var weaver := Profile.create({name = "Pair Weaver", potential_pts = 8, affinity_pts = {fire = 6}})
	var blade := Profile.create({name = "Pair Blade", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, skill_pts = {sword = 3}})
	var iw := both.add_player(weaver, Vector3(0, 0, 4)); var ib2 := both.add_player(blade, Vector3(2, 0, 0))
	while not both.over and both.t < 400.0:
		Bot.drive(both, iw); Bot.drive(both, ib2)
		both.step(1.0 / 30.0)
		both.events.clear()
	print("  %s in %.0fs: weaver %d casts, health %d; blade %d blows, health %d" % ["won" if both.success else "LOST", both.t, both.tallies[iw].casts.values().reduce(func(x, y): return x + y, 0), int(maxf(both.ents[iw].hp, 0.0)), both.tallies[ib2].blows.values().reduce(func(x, y): return x + y, 0), int(maxf(both.ents[ib2].hp, 0.0))])
	check(both.success and both.tallies[iw].casts.size() > 0 and both.tallies[ib2].blows.size() > 0, "a channeller and a Warder hold the watch together, each doing their part")

	# The Warder's work: beside a channeller with guard raised, the blow is theirs.
	var ward := Sim.new("camp_training", 6)
	ward._waves = []
	var cw := ward.add_player(weaver, Vector3.ZERO); var ww := ward.add_player(blade, Vector3(1.5, 0, 0))
	ward._add_enemy("trolloc", Vector3(0, 0, 1.6))
	ward.ents[ww].yaw = 0.0
	ward.ents[cw].stamina = 100.0; ward.ents[ww].stamina = 100.0
	var saw := []
	for i in 120:
		var wf: Dictionary = ward.ents[ww + 1]
		if wf.swung and wf.atk >= wf.blow.time - 0.3: ward.set_guard(ww, true)
		ward.step(1.0 / 30.0)
		for e in ward.events: saw.append(e.e)
		ward.events.clear()
	check(saw.has("ward") and ward.ents[cw].hp == ward.ents[cw].max_hp, "a guarding Warder takes the blow meant for the channeller beside them")
	check(ward.ents[cw].stamina > 100.0 + 4.0 * Rules.TUNE.stamina_regen * 2.0, "bonded, they recover stamina faster")

	# A parry opens the way for a harder blow; so does a foe on the ground.
	d = duel(warder, "dummy", 1.4)
	sim = d[0]
	d[2].hp = 99999.0
	sim.request_attack(d[1], "light", d[2].pos); run(sim, 1.0)
	var plain: float = 99999.0 - d[2].hp
	d[2].hp = 99999.0; sim.ents[d[1]].riposte_until = sim.t + 5.0; sim.ents[d[1]].chain_t = 0.0
	sim.request_attack(d[1], "light", d[2].pos); run(sim, 1.0)
	check(99999.0 - d[2].hp > plain * 1.4, "a blow after a parry bites deeper")

	# Forms: worked out by fighting, used with the right weapon, on a cooldown.
	check(not warder.forms.is_empty() and (not aiel.forms.is_empty() or aiel.get("study_done", 0.0) > 0.0), "fighting works out forms: %s, %s" % [str(warder.forms.keys()), str(aiel.forms.keys())])
	check(not Rules.study_options(warder).has("arc_of_the_moon") and not Rules.study_options(warder).has("sheathing_the_sword"), "the forms tree gates on what is known")
	check(not Rules.study_options(aiel).has("boar_rushes") and not aiel.forms.has("parting_the_silk"), "forms follow the weapon you are skilled with")
	warder.forms["parting_the_silk"] = {known = true}
	d = duel(warder, "dummy", 1.4)
	sim = d[0]
	d[2].hp = 99999.0
	check(sim.request_attack(d[1], "form:parting_the_silk", d[2].pos) == "", "a known form can be used")
	run(sim, 1.5)
	check(99999.0 - d[2].hp > plain * 1.5, "and hits harder than a plain cut")
	check(sim.request_attack(d[1], "form:parting_the_silk", d[2].pos) == "not ready", "then it must wait")
	check(sim.request_attack(d[1], "form:arc_of_the_moon", d[2].pos) == "not learned", "an unknown form is refused")
	sim.equip(d[1], "belt_knife")
	sim.ents[d[1]].cd = {}
	check(sim.request_attack(d[1], "form:parting_the_silk", d[2].pos).begins_with("needs a sword"), "a sword form needs a sword in hand")

	# A thrown knife can be gathered up again.
	var thrower := Profile.create({name = "Thrower", cls = "hunter", kit = ["throwing_knives"]})
	d = duel(thrower, "dummy", 6.0)
	sim = d[0]
	d[2].hp = 99999.0
	sim.request_attack(d[1], "light", sim.aim_missile(sim.ents[d[1]], "throwing_knives", d[2]))
	run(sim, 1.5)
	check(sim.ents[d[1]].ammo.throwing_knives == 7, "a knife thrown is a knife fewer")
	sim.set_input(d[1], Vector3(0, 0, 1), 0.0)
	check(run(sim, 2.0).has("pickup") and sim.ents[d[1]].ammo.throwing_knives == 8, "walking over it picks it up")

	# What a Trolloc swings follows from what it holds.
	var kinds := {}
	for i in 40:
		var s2 := Sim.new("camp_training", i)
		s2._add_enemy("trolloc", Vector3.ZERO)
		var e2: Dictionary = s2.ents[1]
		kinds[e2.arm + "/" + s2._pick_blow(e2).kind] = true
		s2._next += i % 4
	check(not kinds.has("club/thrust") and not kinds.has("spear/chop"), "a club never thrusts and a spear never chops: " + str(kinds.keys()))

func _init() -> void:
	Rules.load_data()
	print("== rules")
	Profile.dir = "user://test_profiles"
	var p := Profile.create({name = "Test Novice", power = "saidar", potential_pts = 6, affinity_pts = {fire = 6}, talents = ["healing"]})
	check(Rules.cast_block(p, "fireball", 2, Rules.TUNE.stamina) == "", "novice can cast fireball")
	check(Rules.cast_block(p, "arrows_of_fire", 2, Rules.TUNE.stamina) == "not learned", "unknown weave refused")
	p.weaves["blossoms_of_fire"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "blossoms_of_fire", Rules.flow_capacity(p), Rules.TUNE.stamina) == "too many flows", "3-flow weave needs 3 flows")
	p.weaves.erase("blossoms_of_fire")
	p.weaves["deathgate"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "deathgate", 9, Rules.TUNE.stamina).begins_with("needs"), "deathgate needs Travelling")
	p.weaves.erase("deathgate")
	var strong := Profile.create({name = "S", potential_pts = 12}); var weak := Profile.create({name = "W", potential_pts = 0})
	check(strong.potential > weak.potential and Rules.power(strong, "fireball") > Rules.power(weak, "fireball"), "potential buys power")
	var man := Profile.create({name = "M", power = "saidin"})
	check(Rules.flows_of(Rules.weaves.gateway, man).has("fire") and not Rules.flows_of(Rules.weaves.gateway, p).has("fire"), "gateway flows differ by saidin/saidar")
	p.book_limit = 2
	p.weaves["balefire"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "balefire", 9, Rules.TUNE.stamina) == "beyond your reading", "spoiler limit hides later weaves")
	p.weaves.erase("balefire"); p.book_limit = 14

	print("== one character through every activity")
	var hours := 0.0
	for act in ["camp_training", "tarwins_gap_watch"]:
		check(Rules.available(p).has(act), act + " is available")
		var sim := play(p, act)
		var tl: Dictionary = sim.tallies[1]
		hours += tl.seconds / 3600.0
		print("  %s: %s in %.0fs, %d casts, draw %.0f" % [act, "won" if sim.success else "LOST", sim.t, tl.casts.values().reduce(func(a, b): return a + b, 0), tl.draw])
		check(sim.success, act + " is winnable by the bot")
		for line in Progression.award(p, tl, act, sim.success):
			print("    + ", line)
	check(p.weaves.has("hammer_of_air") and p.seen.has("dome_of_air"), "weaves taught and seen carry between activities")
	check(p.get("study", "") != "" and p.study_done > 0.0, "channelling works out the weave being studied")
	check(Rules.study_options(p).has("dome_of_air") and not Rules.study_options(p).has("blossoms_of_fire"), "the weave tree gates on what you know")
	check(not Rules.available(p).has("tarwins_gap_night"), "the long night is gated on renown")

	print("== save / load")
	Profile.save(p)
	var q := Profile.load_profile(p.name)
	check(q.renown == p.renown and q.weaves.size() == p.weaves.size() and is_equal_approx(q.strength, p.strength), "profile round-trips to disk")

	print("== pacing: the same character over many hours (extrapolated from a measured holdout)")
	var sim := play(p.duplicate(true), "tarwins_gap_watch")
	var per: Dictionary = sim.tallies[1]
	var h := hours
	var marks := [1, 2, 5, 10, 20, 40, 80]
	print("  hours  strength/potential  flows  renown  fireball-mastery  fire-affinity")
	while not marks.is_empty():
		Progression.award(p, per, "tarwins_gap_watch", true)
		h += per.seconds / 3600.0
		if h >= marks[0]:
			print("  %5d  %6.1f / %-6.0f     %d      %4d    %2d                %.2f" % [marks.pop_front(), p.strength, p.potential, Rules.flow_capacity(p), int(p.renown), Rules.mastery_level(p, "fireball"), p.affinity.fire])
	check(Rules.flow_capacity(p) >= 4, "long play unlocks more flows")
	check(p.strength < p.potential, "strength never exceeds potential")

	print("== spar")
	var a := Profile.create({name = "A"}); var b := Profile.create({name = "B"})
	var spar := Sim.new("dream_spar", 1)
	var ia := spar.add_player(a, Vector3(0, 0, 8)); var ib := spar.add_player(b, Vector3(0, 0, -8))
	while not spar.over and spar.t < 120.0:
		Bot.drive(spar, ia); Bot.drive(spar, ib)
		spar.step(1.0 / 30.0)
	check(spar.over, "a spar between two bots ends")
	Progression.award(a, spar.tallies[ia], "dream_spar", spar.ents[ia].alive)
	check(a.channelled > 0.0, "sparring pays into the same progression")

	_arms()
	_holds()
	_foes()
	_powers()
	print("RESULT: %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
