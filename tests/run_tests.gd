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

func _init() -> void:
	Rules.load_data()
	print("== rules")
	Profile.dir = "user://test_profiles"
	var p := Profile.create({name = "Test Novice", power = "saidar", potential_pts = 6, affinity_pts = {fire = 4, air = 2}, talents = ["healing"]})
	check(Rules.cast_block(p, "fireball", 2, 100.0) == "", "novice can cast fireball")
	check(Rules.cast_block(p, "arrows_of_fire", 2, 100.0) == "not learned", "unknown weave refused")
	p.weaves["blossoms_of_fire"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "blossoms_of_fire", Rules.flow_capacity(p), 100.0) == "too many flows", "3-flow weave needs 3 flows")
	p.weaves.erase("blossoms_of_fire")
	p.weaves["deathgate"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "deathgate", 9, 100.0).begins_with("needs"), "deathgate needs Travelling")
	p.weaves.erase("deathgate")
	var strong := Profile.create({name = "S", potential_pts = 12}); var weak := Profile.create({name = "W", potential_pts = 0})
	check(strong.potential > weak.potential and Rules.power(strong, "fireball") > Rules.power(weak, "fireball"), "potential buys power")
	var man := Profile.create({name = "M", power = "saidin"})
	check(Rules.flows_of(Rules.weaves.gateway, man).has("fire") and not Rules.flows_of(Rules.weaves.gateway, p).has("fire"), "gateway flows differ by saidin/saidar")
	p.book_limit = 2
	p.weaves["balefire"] = {known = true, xp = 0.0}
	check(Rules.cast_block(p, "balefire", 9, 100.0) == "beyond your reading", "spoiler limit hides later weaves")
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
	check(p.weaves.has("hammer_of_air") and p.weaves.has("riven_earth"), "weaves learned carry between activities")
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

	print("RESULT: %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
