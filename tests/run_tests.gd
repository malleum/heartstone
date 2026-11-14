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
					"guard": sim.set_guard(d[1], true)
					"parry":
						if foe.swung and foe.atk >= foe.blow.time - 0.15: sim.set_guard(d[1], true)
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
		check(hurt[kind + "/guard"] > 0.0 and hurt[kind + "/guard"] < hurt[kind + "/stand"] * 0.4, "a guard stops most of a %s" % kind)
		check(hurt[kind + "/parry"] == 0.0, "a guard raised at the last moment parries a %s" % kind)
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
	sim.set_guard(d[1], true)
	check(run(sim, 3.0).has("guard_break"), "a guard with no stamina behind it breaks")

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
		check(who.weaves.is_empty() and who.get("study", "") == "", "%s learns no weaves" % who.name)
	check(warder.skills.sword > 3 * 3 * Rules.TUNE.skill_xp, "fighting raises the skill of the weapon used")

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
	print("RESULT: %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
