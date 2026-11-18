extends SceneTree
## Headless rules tests: godot --headless --path . -s tests/run_tests.gd
## Plays whole activities with a bot and checks the rules and progression pacing.

var fails := 0

func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL: ", what)

func play(profile: Dictionary, activity: String, max_s := 600.0, seed_ := 3) -> Sim:
	var sim := Sim.new(activity, seed_)
	var id := sim.add_player(profile)
	while not sim.over and sim.t < max_s:
		Bot.drive(sim, id)
		sim.step(1.0 / 30.0)
		sim.events.clear()
	return sim

## One fighter alone with one enemy standing `dist` in front, for exact checks.
func duel(profile: Dictionary, enemy: String, dist: float) -> Array:
	var sim := Sim.new("practice", 5)
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
	var sim := Sim.new("practice", 3)
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
	sim = Sim.new("practice", 3)
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
	sim = Sim.new("practice", 3)
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
	sim = Sim.new("practice", 3)
	sim._waves = []
	id = sim.add_player(p)
	check(sim.request_cast(id, "healing", sim.ents[id].pos).begins_with("no one there"), "Healing alone is refused: you cannot Heal yourself")
	var friend := sim.add_player(Profile.create({name = "Friend"}), Vector3(3, 0, 0))
	sim._add_enemy("dummy", Vector3(60, 0, -60))
	sim.ents[friend].hp = 20.0; sim.ents[friend].fester = 9.0; sim.ents[friend].fester_dps = 0.0
	check(sim.request_cast(id, "healing", sim.ents[friend].pos) == "", "Healing a friend is allowed")
	run(sim, 3.5)   # weak in Spirit, the weaving takes longer
	check(sim.ents[friend].hp > 50.0 and sim.ents[friend].fester == 0.0, "it mends them and ends the festering")

func _foes() -> void:
	print("== walls, archers and the Eyeless")
	var p := Profile.create({name = "Stander", cls = "warder", stat_pts = {endurance = 4}})
	# The breastwork is solid, and a Trolloc finds the gap.
	var sim := Sim.new("short_watch", 2)
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
		sim = Sim.new("short_watch", 2)
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
	sim = Sim.new("practice", 9)
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
	var seen := run(sim, 6.0)
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
	while not pair.over and pair.t < 300.0:
		Bot.drive(pair, a); Bot.drive(pair, b)
		pair.step(1.0 / 30.0)
		for e in pair.events:
			if e.e == "spawn": quarters[int(signf(e.pos.x)) * 2 + int(signf(e.pos.z))] = true
		pair.events.clear()
	print("  wagon ring, weaver and Warder: %s in %.0fs" % ["won" if pair.success else "lost", pair.t])
	check(quarters.size() == 4, "the wagon ring is attacked from every side")
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
	# (The fireball leaves the grass under it burning: keep the Trolloc alive through it.)
	foe.hp = 9999.0; foe.max_hp = 9999.0
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

## What Josh asked for after the first tour: weaving takes time and is held back
## until let go; each starter does its own thing; the fire weaves; the Eyeless;
## flurries, bows, the crossbow, what is thrown.
func _playtest() -> void:
	print("== weave-up, new weaves, the Eyeless, missiles")
	Map.use("open")
	var p := Profile.create({name = "Tester", potential_pts = 14, affinity_pts = {fire = 2, water = 1, earth = 1}})
	for w in Rules.weaves:
		p.weaves[w] = {known = true, xp = 0.0}
	p.channelled = Rules.TUNE.flow_steps[10]; p.book_limit = 99
	p.potential = Rules.strength_of(8.0); p.strength = p.potential
	for w in Rules.weaves:
		check(not Rules.weaves[w].has("cooldown") and float(Rules.weaves[w].form) >= 0.9, "%s has no cooldown and takes time to weave" % w)
	# A weave held back waits in the hands, and goes where it is aimed when let go.
	var d := duel(p, "dummy", 12.0)
	var sim: Sim = d[0]; var id: int = d[1]; var foe: Dictionary = d[2]
	var me: Dictionary = sim.ents[id]
	check(sim.request_cast(id, "fireball", Vector3(30, 1, 0), true) == "", "a weave can be begun and held")
	var seen := run(sim, 2.0)
	check(seen.has("ready") and not seen.has("cast") and not me.forming.is_empty(), "it is whole, and waits")
	var hp0: float = foe.hp
	sim.aim_cast(id, sim.aim_at(me, "fireball", foe), false)
	seen = run(sim, 1.5)
	check(seen.has("cast") and foe.hp < hp0, "let go, it flies where it is aimed then, not where it was begun")
	check(sim.request_cast(id, "fireball", foe.pos) == "", "and there is no cooldown: the next can be begun at once")
	run(sim, 2.0)
	# Lash of Water: hauls them in, soaks them, and lightning finds the soaked.
	d = duel(p, "trolloc", 12.0)
	sim = d[0]; id = d[1]; foe = d[2]; foe.hp = 9999.0; me = sim.ents[id]
	sim.request_cast(id, "water_lash", foe.pos)
	run(sim, 1.5)
	check(foe.pos.distance_to(me.pos) < 9.0 and foe.get("wet", 0.0) > 0.0, "a Lash of Water hauls a Trolloc in and soaks it")
	var dry := Sim.new("practice", 5); dry._waves = []
	var did := dry.add_player(p); dry._add_enemy("trolloc", Vector3(0, 0, 9)); dry.ents[did + 1].hp = 9999.0
	dry._hurt(dry.ents[did + 1], 100.0, did, "lightning")
	var h: float = foe.hp
	foe.stagger = 0.0
	sim._hurt(foe, 100.0, id, "lightning")
	check(h - foe.hp > (9999.0 - dry.ents[did + 1].hp) * 1.4, "lightning hits the soaked harder")
	# Arrows of Fire go through the first body into the one behind.
	sim = Sim.new("practice", 5); sim._waves = []
	id = sim.add_player(p)
	sim._add_enemy("trolloc", Vector3(0, 0, 8)); sim._add_enemy("trolloc", Vector3(0, 0, 11)); sim._add_enemy("dummy", Vector3(40, 0, 40))
	for k in [1, 2]: sim.ents[id + k].hp = 9999.0; sim.ents[id + k].speed = 0.0
	sim.request_cast(id, "arrows_of_fire", Vector3(0, 1.1, 8))
	seen = run(sim, 2.2)
	check(sim.ents[id + 1].hp < 9999.0 and sim.ents[id + 2].hp < 9999.0 and seen.has("pierce"), "a dart of fire goes through one Trolloc into the next")
	# Blossoms of Fire: a pillar, then a wide wheel that burns what stands in it.
	sim = Sim.new("practice", 5); sim._waves = []
	id = sim.add_player(p)
	sim._add_enemy("trolloc", Vector3(4.5, 0, 25)); sim._add_enemy("dummy", Vector3(60, 0, 60))
	var far: Dictionary = sim.ents[id + 1]; far.hp = 9999.0; far.speed = 0.0
	sim.request_cast(id, "blossoms_of_fire", Vector3(0, 0, 25))
	run(sim, Rules.weaves.blossoms_of_fire.form + 0.4)
	check(sim.effects.size() == 1 and sim.effects[0].kind == "blossom" and far.hp == 9999.0, "it begins as a pillar too thin to reach a Trolloc four paces off")
	run(sim, 3.0)
	var wheel: Dictionary = sim.effects[0]
	check(wheel.rad >= 3.0 and wheel.rad <= 9.0 and far.hp < 9999.0 and far.burn > 0.0, "then opens to between 10 and 30 feet and burns it")
	run(sim, 6.0)
	check(sim.effects.is_empty(), "and burns out")
	# The Rolling Ring is a wedge: it strikes ahead and not behind.
	sim = Sim.new("practice", 5); sim._waves = []
	id = sim.add_player(p)
	sim._add_enemy("trolloc", Vector3(0, 0, 9)); sim._add_enemy("trolloc", Vector3(0, 0, -9)); sim._add_enemy("trolloc", Vector3(9, 0, 0))
	for k in [1, 2, 3]: sim.ents[id + k].hp = 9999.0; sim.ents[id + k].speed = 0.0
	sim.request_cast(id, "rolling_ring", Vector3(0, 0, 9))
	run(sim, Rules.weaves.rolling_ring.form + 2.0)
	check(sim.ents[id + 1].hp < 9999.0 and sim.ents[id + 2].hp == 9999.0 and sim.ents[id + 3].hp == 9999.0, "the Rolling Ring strikes where it is thrown and not behind or beside")
	check(float(Rules.weaves.rolling_ring.base.arc) * 2.0 < 90.0, "and is narrower than a quarter circle")

	# The Eyeless: it lunges along a line it has chosen, and it steps through shadow.
	var blade := Profile.create({name = "Test Blade", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, skill_pts = {sword = 3}})
	sim = Sim.new("practice", 9); sim._waves = []
	id = sim.add_player(blade)
	sim._add_enemy("myrddraal", Vector3(0, 0, 9)); sim._add_enemy("dummy", Vector3(60, 0, 60))
	var fade: Dictionary = sim.ents[id + 1]
	var lunged := false; var gone := false; var back := false; var hidden := false
	for i in 30 * 40:
		sim.ents[id].hp = sim.ents[id].max_hp
		sim.step(1.0 / 30.0)
		for e in sim.events:
			if e.e == "lunge": lunged = true
			if e.e == "fade_out": gone = true
			if e.e == "fade_in": back = true
		if fade.get("gone", false):
			hidden = hidden or not sim._targets(sim.ents[id]).has(fade)
		sim.events.clear()
	check(lunged, "a Myrddraal lunges")
	check(gone and back and hidden, "and goes into shadow, where nothing can touch it, and comes out again")
	# Step off the line of a lunge and it goes past and is open.
	sim = Sim.new("practice", 9); sim._waves = []
	id = sim.add_player(blade)
	sim._add_enemy("myrddraal", Vector3(0, 0, 8)); sim._add_enemy("dummy", Vector3(60, 0, 60))
	fade = sim.ents[id + 1]
	sim._fade_lunge(fade, sim.ents[id], 0.7)
	sim.set_input(id, Vector3(1, 0, 0), 0.0)
	seen = run(sim, 1.6)
	check(seen.has("miss") and sim.ents[id].hp == sim.ents[id].max_hp, "walk off the line of its lunge and it goes past")

	# A flurry lands four times. A thrown-out weapon is not in the hand.
	var aiel := Profile.create({name = "Test Maiden", cls = "aiel", sex = "f", stat_pts = {might = 2, quickness = 5, endurance = 3}, skill_pts = {knife = 3, spear = 3}, kit = ["aiel_knife", "javelins"]})
	aiel.forms = {knife_flurry = {known = true}}
	d = duel(aiel, "trolloc", 1.4)
	sim = d[0]; id = d[1]; d[2].hp = 9999.0
	check(sim.request_attack(id, "form:knife_flurry", d[2].pos) == "", "a flurry can be thrown")
	var strikes := 0
	for i in 60:
		sim.ents[id].hp = sim.ents[id].max_hp
		strikes += run(sim, 1.0 / 30.0).count("strike")
	check(strikes == 4, "a flurry is four blows (%d)" % strikes)
	d = duel(aiel, "dummy", 14.0)
	sim = d[0]; id = d[1]; d[2].hp = 9999.0
	sim.equip(id, "javelins")
	sim.ents[id].ammo.javelins = 1
	run(sim, 0.3)
	sim.request_attack(id, "light", d[2].pos + Vector3(0, 2, 0)); run(sim, 1.5)
	check(sim.ents[id].ammo.javelins == 0 and sim.request_attack(id, "light", d[2].pos) != "", "with the last javelin thrown there is nothing in the hand to throw")
	# The crossbow has no half shot, and spans itself after each bolt.
	var hunter := Profile.create({name = "Test Hunter", cls = "hunter", stat_pts = {might = 4, quickness = 3, endurance = 2}, skill_pts = {bow = 3}, kit = ["crossbow", "longbow"]})
	d = duel(hunter, "dummy", 20.0)
	sim = d[0]; id = d[1]; d[2].hp = 99999.0; d[2].max_hp = 99999.0
	check(sim.request_attack(id, "light", d[2].pos + Vector3(0, 1, 0), 0.1) == "", "a spanned crossbow looses")
	run(sim, 0.5)
	check(sim.effects.size() > 0 or d[2].hp < d[2].max_hp, "at full strength however it was asked for")
	check(sim.request_attack(id, "light", d[2].pos, 1.0) == "still spanning", "and cannot loose again until it is spanned")
	run(sim, Rules.draw_time(hunter, "crossbow") + 0.3)
	check(sim.request_attack(id, "light", d[2].pos + Vector3(0, 1, 0), 1.0) == "", "which it does by itself")
	run(sim, 1.0)
	# A half-drawn longbow throws a slower, weaker arrow than a full one.
	sim.equip(id, "longbow"); run(sim, 0.3)
	sim.request_attack(id, "light", d[2].pos + Vector3(0, 6, 0), 0.3)
	var half := {}
	for i in 60:
		sim.step(1.0 / 30.0)
		for fx in sim.effects:
			if fx.kind == "missile" and half.is_empty(): half = fx.duplicate()
	sim.request_attack(id, "light", d[2].pos + Vector3(0, 6, 0), 1.0)
	var full := {}
	for i in 90:
		sim.step(1.0 / 30.0)
		for fx in sim.effects:
			if fx.kind == "missile" and full.is_empty() and fx.id != half.get("id", -1): full = fx.duplicate()
	check(not half.is_empty() and not full.is_empty() and full.vel.length() > half.vel.length() * 1.6 and full.dmg > half.dmg * 3.0, "a half-drawn longbow throws a slower, far weaker arrow")

func _dream() -> void:
	print("== Tel'aran'rhiod")
	Map.use("open")
	var a := Profile.create({name = "Dreamer", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = ["sword"]})
	var b := Profile.create({name = "Other", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = ["sword"]})
	var sim := Sim.new("dream_spar", 3)
	var ia := sim.add_player(a, Vector3(0, 0, 0)); var ib := sim.add_player(b, Vector3(0, 0, 14))
	var pa: Dictionary = sim.ents[ia]; var pb: Dictionary = sim.ents[ib]
	pa.yaw = 0.0; pb.yaw = PI
	check(Sim.new("practice", 1).request_dream(1, "shift_back", Vector3.ZERO) != "" , "no dream moves in the waking world")
	# Shifts.
	check(sim.request_dream(ia, "shift_behind", pb.pos) == "" and pa.pos.distance_to(pb.pos) < 3.0 and pa.pos.z > pb.pos.z, "step behind: you are at their back")
	check(absf(angle_difference(pa.yaw, atan2(pb.pos.x - pa.pos.x, pb.pos.z - pa.pos.z))) < 0.1, "and facing them")
	check(is_equal_approx(pa.will, 100.0 - 24.0), "it costs Will")
	var z0: float = pa.pos.z
	check(sim.request_dream(ia, "shift_back", Vector3.ZERO) == "" and absf(pa.pos.distance_to(Vector3(0, 0, z0)) - 7.0) < 0.2, "step away: seven paces back")
	var there: Vector3 = pa.pos + Vector3(10, 0, 0)
	check(sim.request_dream(ia, "shift_aim", there) == "" and pa.pos.distance_to(there) < 0.3, "step there: where you looked")
	pa.will = 5.0
	check(sim.request_dream(ia, "shift_aim", Vector3.ZERO) == "your will is spent", "with no Will left, nothing")
	run(sim, 4.0)
	check(pa.will > 40.0, "Will comes back when the mind is quiet")
	# A thrown spear, and Deny.
	pa.pos = Vector3(0, 0, 0); pb.pos = Vector3(0, 0, 12); pa.will = 100.0; pb.will = 100.0
	var hp: float = pb.hp
	sim.request_dream(ia, "dream_spear", pb.pos + Vector3(0, 1.2, 0))
	var seen := run(sim, 1.0)
	check(seen.has("dream_hit") and pb.hp < hp, "a thrown spear lands")
	hp = pb.hp
	sim.request_dream(ia, "dream_spear", pb.pos + Vector3(0, 1.2, 0))
	run(sim, 0.3)
	sim.request_dream(ib, "deny", Vector3.ZERO)
	seen = run(sim, 0.6)
	check(seen.has("denied") and is_equal_approx(pb.hp, hp), "Denied in the instant, it is unmade")
	check(pa.shaken > sim.t - 0.7 and sim.request_dream(ia, "shift_back", Vector3.ZERO) in ["your will is shaken", ""], "and the one who threw it is shaken")
	# Chains: hold unless you are gone first; a shift breaks them at a price.
	run(sim, 2.0)
	pa.pos = Vector3(0, 0, 0); pb.pos = Vector3(0, 0, 12); pa.will = 100.0; pb.will = 100.0
	sim.request_dream(ia, "dream_chains", pb.pos)
	seen = run(sim, 0.7)
	check(seen.has("chained") and pb.chained > sim.t, "chains take hold")
	check(sim.request_attack(ib, "light", pa.pos) == "chained" and sim.request_dodge(ib, Vector3.RIGHT) == "chained", "chained, you cannot strike or roll")
	var w: float = pb.will
	check(sim.request_dream(ib, "shift_back", Vector3.ZERO) == "" and pb.chained <= sim.t and is_equal_approx(w - pb.will, 18.0), "but you can be elsewhere, for half as much Will again")
	run(sim, 2.0)
	pb.pos = Vector3(0, 0, 12); pa.will = 100.0
	sim.request_dream(ia, "dream_chains", pb.pos)
	run(sim, 0.2)
	sim.request_dream(ib, "shift_aim", Vector3(9, 0, 12))
	seen = run(sim, 0.6)
	check(not seen.has("chained") and pb.chained <= sim.t, "gone from the spot before they close, they hold nothing")
	# A wall stops what is thrown.
	run(sim, 2.0)
	pa.pos = Vector3(0, 0, 0); pa.yaw = 0.0; pb.pos = Vector3(0, 0, 12); pb.yaw = PI; pa.will = 100.0; pb.will = 100.0
	sim.request_dream(ib, "dream_wall", Vector3.ZERO)
	hp = pb.hp
	sim.request_dream(ia, "dream_spear", pb.pos + Vector3(0, 1.2, 0))
	seen = run(sim, 1.0)
	check(not seen.has("dream_hit") and is_equal_approx(pb.hp, hp), "a wall stops a thrown spear")
	# The ground turns.
	run(sim, 4.0)
	pa.will = 100.0; pb.pos = Vector3(0, 0, 12); hp = pb.hp
	sim.request_dream(ia, "dream_pit", pb.pos)
	seen = run(sim, 1.5)
	check(seen.has("pit_open") and pb.hp < hp and pb.get("mired", 0.0) > sim.t - 0.2, "the ground takes hold of whoever stands on it")
	# The duel ends when one of them wakes.
	sim._hurt(pb, 9999.0, ia, "dream")
	run(sim, 0.2)
	check(sim.over and sim.success, "one of them wakes: the duel is over")

func _shadowspawn() -> void:
	print("== Darkhounds, Draghkar, Dreadlords")
	Map.use("open")
	var p := Profile.create({name = "Tester", potential_pts = 14, affinity_pts = {fire = 2, spirit = 2}})
	for w in Rules.weaves:
		p.weaves[w] = {known = true, xp = 0.0}
	p.channelled = Rules.TUNE.flow_steps[10]; p.book_limit = 99
	p.potential = Rules.strength_of(8.0); p.strength = p.potential
	var blade := Profile.create({name = "Blade", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = ["sword"]})
	# Darkhound: springs from a distance along a line it has chosen.
	var d := duel(p, "darkhound", 9.0)
	var sim: Sim = d[0]; var id: int = d[1]; var foe: Dictionary = d[2]
	var me: Dictionary = sim.ents[id]
	var hp0: float = me.hp
	var seen := run(sim, 4.0)
	check(seen.has("lunge") and me.hp < hp0, "a Darkhound springs, and its bite lands")
	check(me.get("fester", 0.0) > 0.0, "and the bite festers")
	# Steel does half to it; the Power does all; left alone it mends.
	sim = Sim.new("practice", 5); sim._waves = []
	id = sim.add_player(blade); sim._add_enemy("darkhound", Vector3(0, 0, 30)); foe = sim.ents[id + 1]; foe.speed = 0.0
	sim._hurt(foe, 40.0, id, "sword")
	check(is_equal_approx(foe.max_hp - foe.hp, 20.0), "steel does half its work on a Darkhound")
	var h: float = foe.hp
	sim._hurt(foe, 40.0, id, "fireball")
	check(h - foe.hp >= 39.9, "a weave does all of it")
	run(sim, 6.0)      # (the fire on it has to burn out first)
	h = foe.hp
	run(sim, 5.0)
	check(foe.hp > h + 20.0, "left alone, its wounds close")
	# Draghkar: aloft it cannot be reached; it lands and sings; unbroken, the song takes you.
	d = duel(p, "draghkar", 30.0)
	sim = d[0]; id = d[1]; foe = d[2]; me = sim.ents[id]
	run(sim, 0.3)
	check(foe.get("gone", false) and sim._targets(me).is_empty(), "a Draghkar on the wing is out of reach")
	seen = run(sim, 4.0)
	check(seen.has("land") and seen.has("song") and not foe.get("gone", false), "it lands a bowshot off and begins to sing")
	seen = run(sim, 3.0)
	check(seen.has("entranced") and me.get("entranced", 0.0) > sim.t, "let it finish and the song has you")
	check(sim.request_cast(id, "fireball", foe.pos) == "the song has you" and sim.request_dodge(id, Vector3.RIGHT) == "the song has you", "you can neither weave nor step aside")
	var far0: float = me.pos.distance_to(foe.pos)
	sim.set_input(id, Vector3(0, 0, -1), 0.0)
	run(sim, 2.0)
	check(me.pos.distance_to(foe.pos) < far0 - 2.0, "and your feet take you to it whatever you want")
	hp0 = me.hp
	seen = run(sim, 9.0)
	check(seen.has("kiss") and me.hp < hp0 * 0.85 and me.alive, "its kiss drains you, and then lets you go")
	check(me.get("entranced", 0.0) <= sim.t and seen.has("aloft"), "the trance ends and it takes wing again")
	# Hurt it while it sings and the song breaks.
	d = duel(p, "draghkar", 30.0)
	sim = d[0]; id = d[1]; foe = d[2]; me = sim.ents[id]
	var sang := false
	for i in 600:
		sim.step(1.0 / 60.0)
		for e in sim.events:
			if e.e == "song": sang = true
		sim.events.clear()
		if sang: break
	sim._hurt(foe, 10.0, id, "fireball")
	seen = run(sim, 4.0)
	check(sang and seen.has("song_end") and not seen.has("entranced"), "hurt it while it sings and the song breaks")
	# Dreadlord: gathers and throws fire that bursts; marks the ground for lightning.
	d = duel(p, "dreadlord", 18.0)
	sim = d[0]; id = d[1]; foe = d[2]; me = sim.ents[id]
	hp0 = me.hp
	seen = run(sim, 8.0)
	check(seen.has("channel") and seen.has("loose") and seen.has("blast"), "a Dreadlord gathers the Power, throws fire, and it bursts")
	check(seen.has("doom") and seen.has("doom_hit") and me.hp < hp0, "it marks the ground and lightning falls there")
	# Step out of the mark and the lightning finds nothing.
	d = duel(p, "dreadlord", 18.0)
	sim = d[0]; id = d[1]; foe = d[2]; me = sim.ents[id]
	foe.row = foe.row.duplicate(); foe.row.erase("ranged"); foe.speed = 0.01
	var marked := false; var struck := false
	for i in 900:
		sim.step(1.0 / 60.0)
		for e in sim.events:
			if e.e == "doom": marked = true; sim.set_input(id, Vector3(1, 0, 0), 0.0)
			if e.e == "doom_hit": struck = true
		sim.events.clear()
		if struck: break
	check(marked and struck and is_equal_approx(me.hp, me.max_hp), "walk out of the mark and it strikes empty ground")
	# Shielded, it can do neither.
	d = duel(p, "dreadlord", 14.0)
	sim = d[0]; id = d[1]; foe = d[2]; me = sim.ents[id]
	foe.speed = 0.0; foe.strike_at = 99.0; foe.atk = -99.0
	check(sim.request_cast(id, "shielding", foe.pos, false) == "", "a Dreadlord can be Shielded")
	run(sim, 3.0)
	check(foe.get("severed", 0.0) > sim.t, "and it is cut off")
	foe.strike_at = 0.0; foe.atk = 0.0
	seen = run(sim, 5.0)
	check(not seen.has("loose") and not seen.has("doom"), "cut off, it throws nothing and marks nothing")

func _trolloc_blows() -> void:
	print("== Trolloc attacks by weapon")
	Map.use("open")
	var p := Profile.create({name = "Blade", cls = "warder", stat_pts = {might = 4, quickness = 3, endurance = 3}, kit = ["sword"]})
	var sim := Sim.new("practice", 5); sim._waves = []
	var id := sim.add_player(p)
	var me: Dictionary = sim.ents[id]
	# Each weapon has its own blows and no others.
	var kinds := {}
	for arm in Sim.ARMS:
		sim._add_enemy("trolloc", Vector3(0, 0, 2)); var e: Dictionary = sim.ents[sim._next - 1]
		e.arm = arm; kinds[arm] = {}
		for i in 60:
			var b := sim._pick_blow(e, me, [me])
			kinds[arm][b.kind + ":" + b.height] = kinds[arm].get(b.kind + ":" + b.height, 0) + 1
		e.alive = false
	check(kinds.spear.has("thrust:mid") and not kinds.spear.has("chop:over") and kinds.club.has("chop:over") and not kinds.club.has("sweep:high"), "a spear thrusts and never chops; a club smashes and never sweeps")
	check(kinds.scythe.get("sweep:high", 0) > kinds.scythe.get("chop:over", 0) and kinds.axe.get("chop:over", 0) > kinds.axe.get("sweep:high", 0), "a scythe-sword mostly sweeps, an axe mostly chops")
	# What is in front of it decides: no high sweep at someone ducking.
	sim._add_enemy("trolloc", Vector3(0, 0, 2)); var sc: Dictionary = sim.ents[sim._next - 1]; sc.arm = "scythe"
	me.duck = true
	var high := 0
	for i in 60:
		if sim._pick_blow(sc, me, [me]).height == "high": high += 1
	me.duck = false
	check(high <= 6, "it does not sweep over someone ducking (%d of 60)" % high)
	sc.alive = false
	# A spear's thrust throws you back; an axe's chop leaves you reeling; steel in the way stops both.
	var d := duel(p, "trolloc", 2.0)
	sim = d[0]; id = d[1]; me = sim.ents[id]; var foe: Dictionary = d[2]
	foe.arm = "spear"; foe.speed = 0.0
	foe.aim_yaw = PI; foe.blow = {kind = "thrust", height = "mid", arc = 20.0, reach = 3.0, time = 0.0, dmg = 10.0, on = {push = 5}}
	sim._enemy_blow(foe, [me])
	var z0: float = me.pos.z
	run(sim, 0.5)
	check(me.pos.z < z0 - 0.5, "a spear thrust that lands throws you back")
	foe.blow = {kind = "chop", height = "over", arc = 20.0, reach = 4.0, time = 0.0, dmg = 10.0, on = {stagger = 0.7}}
	foe.aim_yaw = PI
	sim._enemy_blow(foe, [me])
	check(me.reel_until > sim.t, "an axe chop that lands leaves you reeling")
	run(sim, 1.5)
	me.yaw = 0.0; sim.set_input(id, Vector3.ZERO, 0.0)
	sim.set_guard(id, true)
	run(sim, 0.25)
	var z1: float = me.pos.z
	foe.blow = {kind = "thrust", height = "mid", arc = 20.0, reach = 5.0, time = 0.0, dmg = 10.0, on = {push = 5, stagger = 0.7}}
	sim._enemy_blow(foe, [me])
	run(sim, 0.3)
	check(absf(me.pos.z - z1) < 0.2 and me.reel_until <= sim.t, "met with steel, it neither throws nor staggers you")

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
			# (The weapon whose blow this is: each has its own now.)
			d[2].arm = {chop = "axe", sweep = "scythe", thrust = "spear"}[kind]
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
		for act in ["camp_training", "short_watch"]:
			var s := play(who, act)
			# A lone bot against a watch is chaotic: any small change in the rules
			# moves which seed it loses. Two tries; losing both is a real weakness.
			if not s.success:
				s = play(who, act, 600.0, 7)
			var tl: Dictionary = s.tallies[1]
			print("  %s, %s: %s in %.0fs, %d blows, health %d, stamina %d" % [who.name, act, "won" if s.success else "LOST", s.t, tl.blows.values().reduce(func(x, y): return x + y, 0), int(maxf(s.ents[1].hp, 0.0)), int(s.ents[1].stamina)])
			check(s.success, "%s can win %s" % [who.name, act])
			for line in Progression.award(who, tl, act, s.success):
				print("    + ", line)
		check(who.weaves.is_empty(), "%s learns no weaves" % who.name)
	check(warder.skills.sword > 3 * 3 * Rules.TUNE.skill_xp, "fighting raises the skill of the weapon used")

	print("== a fighter and a channeller together")
	var both := Sim.new("short_watch", 4)
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
	var ward := Sim.new("practice", 6)
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
		var s2 := Sim.new("practice", i)
		s2._add_enemy("trolloc", Vector3.ZERO)
		var e2: Dictionary = s2.ents[1]
		kinds[e2.arm + "/" + s2._pick_blow(e2).kind] = true
		s2._next += i % 4
	check(not kinds.has("club/thrust") and not kinds.has("spear/chop"), "a club never thrusts and a spear never chops: " + str(kinds.keys()))

func _rounds() -> void:
	print("== rounds")
	var rng := RandomNumberGenerator.new(); rng.seed = 12
	for man in [false, true]:
		var top := 0; var sum := 0.0; var n := 8000
		for i in n:
			var l := Round.roll_potential(rng, man)
			sum += l
			if l <= (-5.0 if man else 1.0): top += 1
		check(absf(sum / n - (14.0 if man else 20.0)) < 0.6 and top > n * 0.002 and top < n * 0.012, "potential rolls: a bell with a rare top (man=%s, mean %.1f, top %d in %d)" % [man, sum / n, top, n])
	var her := Profile.create({name = "Round Her", potential_pts = 8, affinity_pts = {water = 4, air = 2}})
	var saved := her.duplicate(true)
	var c := Round.begin(her, rng)
	var gap: float = c.round.start_level - c.round.pot_level
	check(gap >= 1.0 and gap <= 10.0 and c.potential > c.strength, "a round begins 1 to 10 levels below its rolled potential (%d)" % int(gap))
	check(her == saved, "the round copy leaves the saved character alone")
	var plan := Round.plan(Rules.activities.tarwins_gap_watch, rng)
	check(plan.size() == 16 and plan[-1].t > 1000.0 and plan[-1].t < 1800.0, "a round is about twenty to thirty minutes of waves (%d waves, last at %d s)" % [plan.size(), int(plan[-1].t)])
	var horde: int = plan[5].spawn.trolloc
	check(horde > plan[4].spawn.trolloc * 2 and plan[3].spawn.size() > 1 and plan[0].spawn.size() == 1, "some waves are Trollocs alone, some bring others, some are hordes")
	# The team levels as one, and each level carries a woman's strength on.
	var sim := Sim.new("tarwins_gap_watch", 7)
	var id := sim.add_player(her)
	var r: Dictionary = sim.ents[id].profile.round
	var s0: int = Rules.level_of(Rules.strength(sim.ents[id].profile))
	var levels := 0
	for i in 60:
		sim._gain(Round.xp_for(sim.team_level))
		for e in sim.events:
			if e.e == "level" and e.id == id: levels += 1
		sim.events.clear()
	check(levels == 60 and r.level == 61 and r.picks == 60, "every team level reaches every player, with a choice each")
	var s1: int = Rules.level_of(Rules.strength(sim.ents[id].profile))
	check(s1 < s0 and s1 >= int(r.pot_level), "levels carry strength toward potential and never past it (%d -> %d, potential %d)" % [s0, s1, int(r.pot_level)])
	var wv: String = sim.ents[id].profile.weaves.keys()[0]
	var w0 := Rules.mastery_level(sim.ents[id].profile, wv)
	check(sim.request_pick(id, "weave", wv) == "" and Rules.mastery_level(sim.ents[id].profile, wv) == w0 + 1, "a choice spent on a weave is a level of mastery")
	sim.ents[id].profile.round.picks = 0
	check(sim.request_pick(id, "weave", wv) != "", "no choice left, none can be spent")
	# Someone arriving late comes in at the team's level.
	var late := sim.add_player(Profile.create({name = "Round Late", cls = "warder", stat_pts = {might = 3}}))
	check(sim.ents[late].profile.round.level == sim.team_level, "a drop-in joins at the team's level")
	# Fighters are built for it: tougher, faster, more breath than a channeller.
	check(sim.ents[late].max_hp >= 1.5 * 100.0 and sim.ents[late].speed > sim.ents[id].speed * 1.1 and sim.ents[late].stamina_max >= 1.5 * sim.ents[id].stamina_max, "fighters have more health, speed and stamina than channellers")
	# An Aes Sedai sometimes arrives with a Warder, less often the stronger her roll.
	var got := 0; var tried := 0
	for seed_ in 40:
		var ws := Sim.new("tarwins_gap_watch", 100 + seed_)
		var wid := ws.add_player(Profile.create({name = "Round W%d" % seed_, potential_pts = 8}))
		tried += 1
		if ws.ents[wid].profile.round.warder:
			got += 1
			var has := false
			for k in ws.ents:
				if ws.ents[k].get("warder_of", 0) == wid and ws.ents[k].bot: has = true
			check(has, "a rolled Warder stands beside her and fights by himself")
	check(got > 4 and got < tried - 4, "Warders come to some and not others (%d of %d)" % [got, tried])
	check(Round.share_at_or_above(1.0, false) < 0.02 and Round.share_at_or_above(30.0, false) > 0.85, "the strongest rolls rarely bring a Warder; the common ones usually do")
	# Going down, getting up, dying and coming back.
	var ds := Sim.new("tarwins_gap_watch", 21)
	ds._waves = []
	var da := ds.add_player(Profile.create({name = "Down A", power = "saidin", potential_pts = 8}), Vector3(0, 0, 0))   # a man: no Warder to help
	var db := ds.add_player(Profile.create({name = "Down B", cls = "warder", stat_pts = {might = 3}}), Vector3(8, 0, 0))
	ds._add_enemy("dummy", Vector3(0, 0, -90))   # something left, so the round goes on
	var pa: Dictionary = ds.ents[da]
	ds._hurt(pa, pa.max_hp + 5.0, 0, "")
	check(pa.alive and pa.downed and ds.request_cast(da, pa.profile.weaves.keys()[0], Vector3(0, 1, 5)) == "you are down", "a player in a round goes down first, and cannot act")
	ds.ents[db].pos = Vector3(1.0, 0, 0)
	var seen := run(ds, Round.REVIVE_SECS + 0.3)
	check(seen.has("revived") and not pa.downed and pa.hp > 0.0 and pa.hp <= pa.max_hp * 0.3, "a friend standing over you brings you back, low on health")
	ds.ents[db].pos = Vector3(20, 0, 0)
	ds._hurt(pa, pa.hp + 1.0, 0, "")
	ds._hurt(pa, pa.max_hp * 0.5 + 1.0, 0, "")
	check(not pa.alive and pa.return_next, "half a body more while down kills you")
	var before: float = pa.profile.round.pot_level
	ds._spawn_wave({t = 0.0, spawn = {}})
	check(pa.alive and pa.profile.round.pot_level > before and pa.profile.round.pot_level - before <= 6.0, "the dead come back with the next wave, their potential fallen 1 to 6 levels")
	ds._hurt(pa, pa.hp + 1.0, 0, "balefire")
	check(not pa.alive and not pa.get("downed", false), "balefire leaves nothing to bring back")
	ds._spawn_wave({t = 0.0, spawn = {}})
	ds._hurt(pa, pa.hp + 1.0, 0, "")
	run(ds, Round.DOWN_SECS + 0.5)
	check(not pa.alive, "left down too long, you die")

	# Friendly fire: in a round a player's fire burns friends as well as foes.
	var ff := Sim.new("tarwins_gap_watch", 31)
	ff._waves = []
	var f1 := ff.add_player(Profile.create({name = "FF One", power = "saidin"}), Vector3(0, 0, 0))
	var f2 := ff.add_player(Profile.create({name = "FF Two", power = "saidin"}), Vector3(0, 0, 6))
	ff._add_enemy("dummy", Vector3(0, 0, -90))
	var hp2: float = ff.ents[f2].hp
	ff._blast(f1, "fireball", ff._feet(ff.ents[f2]) + Vector3(0, 1, 0), 2.0, 20.0)
	check(ff.ents[f2].hp < hp2, "in a round your fire hurts your friends")

	# The endless night: thirty minutes held is a win, even if they fall after.
	var en := Sim.new("endless", 41)
	var ep := en.add_player(Profile.create({name = "Endless", power = "saidin"}))
	check(en._waves.size() >= 60, "the endless night has waves for hours")
	en._waves = []; en._add_enemy("dummy", Vector3(0, 0, -90))
	en.t = 1799.0
	run(en, 1.5)
	en.ents[ep].alive = false
	run(en, 0.2)
	check(en.over and en.success, "held thirty minutes, the endless night is won however it ends")

	# A Darkfriend among them.
	var assigned := 0
	for seed_ in 30:
		var dsim := Sim.new("darkfriend", 300 + seed_)
		for k in 3:
			dsim.add_player(Profile.create({name = "Ring %d" % k, power = "saidin"}), Vector3(k * 2.0, 0, 0))
		dsim._assign_darkfriends()
		for k in dsim.ents:
			if dsim.ents[k].get("darkfriend", false): assigned += 1
	check(assigned >= 18 and assigned <= 29, "with three players there is usually, not always, a Darkfriend (%d of 30)" % assigned)
	var dg := Sim.new("darkfriend", 77)
	var ids := []
	for k in 4:
		ids.append(dg.add_player(Profile.create({name = "DF %d" % k, cls = "warder", stat_pts = {might = 3}}), Vector3(k * 3.0, 0, 0)))
	dg._waves = []; dg._add_enemy("dummy", Vector3(0, 0, -90))
	dg._df_assigned = true
	var traitor: int = ids[0]
	dg.ents[traitor].darkfriend = true; dg.ents[traitor].df_gate = true
	check(dg.request_df_gate(ids[1]) != "", "only a Darkfriend has the secret gateway")
	var before_n := dg.ents.size()
	check(dg.request_df_gate(traitor) == "" and dg.ents.size() >= before_n + 5 and dg.request_df_gate(traitor) == "already used", "the Darkfriend's gateway lets the Shadow's own through, once")
	var spared := true
	for k in 90:
		dg.step(1.0 / 30.0); dg.events.clear()
	for k in dg.ents:
		var e: Dictionary = dg.ents[k]
		if e.get("df_side", false) and e.get("chasing", 0) == traitor: spared = false
	check(spared, "the Shadow's own never go after the one who let them in")
	for k in ids.slice(1):
		dg.ents[k].alive = false
	dg.step(1.0 / 30.0)
	check(dg.over and dg.won(traitor) and not dg.won(ids[1]), "every loyal player dead: the Darkfriend wins")
	var dh := Sim.new("darkfriend", 78)
	var hid := []
	for k in 3:
		hid.append(dh.add_player(Profile.create({name = "DH %d" % k, power = "saidin"}), Vector3(k * 3.0, 0, 0)))
	dh._df_assigned = true; dh.ents[hid[0]].darkfriend = true
	dh._waves = []
	dh.ents[hid[0]].severed = 9999.0
	dh.step(2.0)
	check(dh.over and dh.won(hid[1]) and not dh.won(hid[0]), "the waves outlasted with the Darkfriend Shielded: the loyal win")
	var dj := Sim.new("darkfriend", 79)
	var jid := []
	for k in 3:
		jid.append(dj.add_player(Profile.create({name = "DJ %d" % k, power = "saidin"}), Vector3(k * 3.0, 0, 0)))
	dj._df_assigned = true; dj.ents[jid[0]].darkfriend = true
	dj._waves = []
	dj.step(2.0)
	check(dj.over and not dj.won(jid[1]) and dj.won(jid[0]), "the waves outlasted with the Darkfriend free: the Darkfriend wins")

	# Gateways: the Shadow's creatures die going through; arrows and weaves go through.
	var gs := Sim.new("practice", 51)
	gs._waves = []
	var gp := gs.add_player(Profile.create({name = "Gate", power = "saidin"}), Vector3(0, 0, 8))
	gs.effects.append({kind = "gate", owner = gp, weave = "gateway", pos = Vector3(0, 0, 0), to = Vector3(20, 0, 0), id = 900, flat_a = false, sky = 0.0, age = 5.0})
	gs._add_enemy("trolloc", Vector3(0.5, 0, 0))
	var tr: Dictionary = gs.ents[gs._next - 1]
	gs.step(1.0 / 30.0); gs.events.clear()
	check(tr.alive and tr.pos.distance_to(Vector3.ZERO) >= 1.1, "a Trolloc will not walk into a gateway")
	tr.pos = Vector3(-1.2, 0, 0.2); tr.vel = Vector3(9, 0, 0)
	run(gs, 0.5)
	check(not tr.alive, "shoved through a gateway, a Trolloc dies")
	gs.ents[gp].pos = Vector3(-1.0, 0, 0.3)
	run(gs, 0.05)
	gs.ents[gp].pos = Vector3(0.2, 0, 0.3)
	run(gs, 0.05)
	check(gs.ents[gp].pos.distance_to(Vector3(20.2, 0, 0.3)) < 0.5, "a person crossing a gateway is simply on the other side, moved by its offset")
	gs.ents[gp].pos = Vector3(0, 0, 30)
	gs.effects.append({kind = "projectile", owner = gp, weave = "fireball", pos = Vector3(-1.5, Terrain.height(0, 0) + 1.5, 0), vel = Vector3(20, 0, 0), dmg = 10.0, radius = 0.3, left = 30.0, gravity = 0.0, pierce = 0, passed = [], id = 901})
	run(gs, 0.2)
	var moved := false
	for fx in gs.effects:
		if fx.get("id", 0) == 901 and fx.pos.x > 18.0: moved = true
	check(moved, "a weave thrown into a gateway comes out of the far side")

	var gc := Sim.new("practice", 52)
	gc._waves = []
	var gcp := gc.add_player(Profile.create({name = "Cutter", power = "saidin"}), Vector3.ZERO)
	gc._add_enemy("trolloc", Vector3(0, 0, 10))
	var tc: Dictionary = gc.ents[gc._next - 1]
	gc._gate_cut(Vector3(0, 0, 10), gcp)
	check(tc.hp <= tc.max_hp - Rules.TUNE.gate_cut + 0.1 or not tc.alive, "a gateway opening on a Trolloc cuts it badly")

	# Rope: a fighter ties a downed player; they cannot walk or strike; anyone unties.
	var rs := Sim.new("darkfriend", 61)
	rs._waves = []; rs._add_enemy("dummy", Vector3(0, 0, -90))
	var rw := rs.add_player(Profile.create({name = "Roper", cls = "warder", stat_pts = {might = 3}}), Vector3(0, 0, 0))
	var rv := rs.add_player(Profile.create({name = "Roped", power = "saidin"}), Vector3(1.0, 0, 0))
	check(rs.set_tying(rw, true) != "", "a standing player cannot be tied")
	rs.ents[rv].downed = true; rs.ents[rv].down_left = 99.0; rs.ents[rv].down_hp = 50.0
	check(rs.set_tying(rw, true) == "", "a fighter can begin tying someone who is down")
	run(rs, Rules.TUNE.rope_secs + 0.2)
	check(rs.ents[rv].get("tied", false), "after a few seconds they are tied")
	rs.ents[rv].downed = false; rs.ents[rv].hp = 50.0
	rs.set_input(rv, Vector3.FORWARD, 0.0)
	check(rs.ents[rv].move == Vector3.ZERO and rs.request_dodge(rv, Vector3.FORWARD) == "tied with rope", "tied, you cannot walk or roll")
	rs.ents[rw].darkfriend = false; rs.ents[rv].darkfriend = true; rs._df_assigned = true
	check(not rs._df_free(), "a tied Darkfriend counts as held")
	check(rs.set_tying(rw, true) == "", "and can be untied")
	run(rs, Rules.TUNE.rope_secs + 0.2)
	check(not rs.ents[rv].get("tied", false), "untied after a few seconds")

	# Balefire: what the balefired thing did a moment ago is undone.
	var bs := Sim.new("tarwins_gap_watch", 71)
	bs._waves = []; bs._add_enemy("dummy", Vector3(0, 0, -90))
	var bv := bs.add_player(Profile.create({name = "Bale Victim", power = "saidin"}), Vector3(0, 0, 0))
	var bw := bs.add_player(Profile.create({name = "Bale Weaver", power = "saidin"}), Vector3(4, 0, 0))
	bs._add_enemy("trolloc", Vector3(0, 0, 2))
	var killer: Dictionary = bs.ents[bs._next - 1]
	bs._hurt(bs.ents[bv], 40.0, killer.id, "")
	bs.t += 1.0
	bs._hurt(killer, killer.hp + 5.0, bw, "balefire")
	check(bs.ents[bv].hp >= bs.ents[bv].max_hp - 0.5, "balefire on a Trolloc undoes the wound it just dealt")
	var bk := Sim.new("tarwins_gap_watch", 72)
	bk._waves = []; bk._add_enemy("dummy", Vector3(0, 0, -90))
	var bp := bk.add_player(Profile.create({name = "Bale Slayer", power = "saidin"}), Vector3(0, 0, 0))
	var bo := bk.add_player(Profile.create({name = "Bale Other", power = "saidin"}), Vector3(4, 0, 0))
	bk._add_enemy("trolloc", Vector3(0, 0, 5))
	var slain: Dictionary = bk.ents[bk._next - 1]
	bk._hurt(slain, slain.hp + 5.0, bp, "fireball")
	bk.t += 1.0
	bk._hurt(bk.ents[bp], 9999.0, bo, "balefire")
	check(slain.alive and not bk.ents[bp].alive, "balefire on a player brings back what they just killed")

	# Linking: a woman leads; men join only her circle; members cannot channel or leave.
	var ls := Sim.new("practice", 81)
	ls._waves = []; ls._add_enemy("dummy", Vector3(0, 0, -90))
	var w1 := ls.add_player(Profile.create({name = "Link W1", power = "saidar", potential_pts = 8}), Vector3(0, 0, 0))
	var m1 := ls.add_player(Profile.create({name = "Link M1", power = "saidin", potential_pts = 8}), Vector3(1.5, 0, 0))
	var m2 := ls.add_player(Profile.create({name = "Link M2", power = "saidin", potential_pts = 8}), Vector3(-1.5, 0, 0))
	ls.request_link(m1); ls.request_link(m2)
	check(ls.ents[m1].get("circle", []).is_empty() and ls.ents[m1].get("circle_of", 0) == 0, "two men cannot link with each other")
	var k0 := ls._circle_mult(ls.ents[w1])
	ls.request_link(w1)
	check(ls.ents[w1].circle.size() == 2 and ls.ents[m1].circle_of == w1, "a woman leading takes in those who offered, men too")
	check(ls._circle_mult(ls.ents[w1]) > k0 * 1.5, "the leader weaves with the circle's strength")
	check(ls.request_cast(m1, ls.ents[m1].profile.weaves.keys()[0], Vector3(0, 1, 9)).begins_with("linked") and ls.request_link(m1) != "", "a member cannot channel, or leave of themselves")
	ls._hurt(ls.ents[m2], ls.ents[m2].max_hp * 0.3, 0, "")
	check(ls.ents[m2].get("circle_of", 0) == 0 and ls.ents[w1].circle.size() == 1, "a heavy blow knocks a member out of the circle")
	ls.request_link(w1)
	check(ls.ents[w1].circle.is_empty() and ls.ents[m1].circle_of == 0, "the leader lets them go")

	# New weaves can be learned at a level-up; a lone choice takes itself.
	var lr := Sim.new("tarwins_gap_watch", 91)
	lr._waves = []; lr._add_enemy("dummy", Vector3(0, 0, -90))
	var lp := lr.add_player(Profile.create({name = "Learner", power = "saidin", potential_pts = 8}))
	var opts := Round.choices(lr.ents[lp].profile).filter(func(c: Dictionary) -> bool: return c.kind == "learn")
	check(not opts.is_empty(), "a level-up can teach a new weave from the chart")
	lr.ents[lp].profile.round.picks = 1
	check(lr.request_pick(lp, "learn", opts[0].id) == "" and lr.ents[lp].profile.weaves.has(opts[0].id), "and it is learned there and then")
	# Vaulting: Space by the breastwork goes over it (wagons are not vaulted).
	var vs := Sim.new("short_watch", 92)
	vs._waves = []
	var wg: Dictionary = Map.walls()[0]
	var vp := vs.add_player(Profile.create({name = "Vaulter", power = "saidin"}))
	vs.ents[vp].pos = Vector3(wg.x, 0, wg.z + 1.3)
	vs.ents[vp].stamina = 999.0
	check(vs.request_dodge(vp, Vector3(0, 0, -1), true) == "" and vs.ents[vp].dash.get("vault", false), "Space by the breastwork is a vault")
	run(vs, 1.0)
	check(vs.ents[vp].pos.z < wg.z - 0.3, "and lands on the far side")
	var ws := Sim.new("wagon_ring", 94)
	ws._waves = []
	var wagon: Dictionary = Map.walls()[0]
	var across := Vector3(cos(float(wagon.rot)), 0, -sin(float(wagon.rot)))
	check(not Map.in_wall(Vector3(wagon.x, 0, wagon.z) + across * 1.3 + Vector3(0, 0.5, 0)) and Map.in_wall(Vector3(wagon.x, 0.5, wagon.z)), "a wagon's solid is the wagon, not a box round it")

	# Backing away is slower than going forward, slower still while weaving.
	var bks := Sim.new("practice", 95)
	var bkp := bks.add_player(Profile.create({name = "Backer", power = "saidin"}))
	var bke: Dictionary = bks.ents[bkp]
	bke.pos = Vector3.ZERO; bks.set_input(bkp, Vector3(0, 0, 1), 0.0); run(bks, 1.0)
	var fwd_m: float = bke.pos.z
	bke.pos = Vector3.ZERO; bks.set_input(bkp, Vector3(0, 0, -1), 0.0); run(bks, 1.0)
	var bwd_m: float = -bke.pos.z
	check(bwd_m < fwd_m * 0.8 and bwd_m > fwd_m * 0.5, "backing away is slower than going forward (%.1f against %.1f m)" % [bwd_m, fwd_m])
	bke.down = 1.0; bke.pos = Vector3.ZERO; bks.set_input(bkp, Vector3(0, 0, 1), 0.0); run(bks, 0.5)
	var crawled: float = bke.pos.z
	run(bks, 1.0)
	check(crawled < fwd_m * 0.2 and bke.down == 0.0, "knocked down you crawl (%.1f m in half a second), and get up again" % crawled)

	# The ground changes for the round: fire catches, water douses, air blows out,
	# earth throws down stone and leaves rubble.
	var grs := Sim.new("short_watch", 96)
	grs._waves = []
	var grp := grs.add_player(Profile.create({name = "Grounder", power = "saidin", potential_pts = 8, affinity_pts = {fire = 3, earth = 3}}))
	grs._blast(grp, "fireball", Vector3(0, Terrain.height(0, -8), -8), 2.0, 10.0)
	check(grs.patches.size() == 1 and grs.patches[0].kind == "fire", "a fireball sets the grass alight")
	grs._puddle(Vector3(0.5, 0, -8), 2.0)
	check(grs.patches.size() == 1 and grs.patches[0].kind == "puddle", "a puddle puts the fire out")
	grs._blast(grp, "fireball", Vector3(0.5, Terrain.height(0.5, -8), -8), 2.0, 10.0)
	check(grs.patches.size() == 1, "wet ground does not catch")
	grs._ignite(Vector3(6, 0, -8), 2.0, grp)
	grs._blow_out(Vector3(5, 0, -8), 3.0)
	check(grs.patches.all(func(q: Dictionary) -> bool: return q.kind != "fire"), "air blows a fire out")
	grs._ignite(Vector3(10, 0, -12), 2.0, grp)
	var grpe: Dictionary = grs.ents[grp]
	grpe.pos = Vector3(10, 0, -12); grpe.burn = 0.0
	run(grs, 0.2)
	check(grpe.burn > 0.0, "burning grass sets you alight")
	var gstones0 := Map.walls().filter(func(w: Dictionary) -> bool: return w.look == "stone").size()
	var gsw: Dictionary = Map.walls()[0]
	grs._wreck_walls(Vector3(gsw.x, 0, gsw.z), 1.0)
	check(Map.walls().filter(func(w: Dictionary) -> bool: return w.look == "stone").size() == gstones0 - 1, "earth throws down a stone wall")
	grs._raise_rubble(Vector3(0, 0, 5), Vector3(1, 0, 0), 5.0)
	check(Map.in_wall(Vector3(2.5, Terrain.height(2.5, 5) + 0.3, 5)), "rubble raised by earth is solid")
	grs.t += 31.0; grs._step_patches(0.1)
	check(not Map.in_wall(Vector3(2.5, Terrain.height(2.5, 5) + 0.3, 5)), "and settles back after a while")

	# Healing a friend who is down brings them up off the ground.
	var hls := Sim.new("tarwins_gap_watch", 99)
	hls._waves = [{t = 999.0, spawn = {}}]
	var hl1 := hls.add_player(Profile.make({name = "Healer", power = "saidar"}))
	var hl2 := hls.add_player(Profile.make({name = "Fallen", power = "saidin"}), Vector3(1.5, 0, 0))
	hls.ents[hl1].profile.weaves["healing"] = {known = true, xp = 0.0}
	hls.ents[hl1].profile.no_roll = true
	hls.ents[hl1].profile.strength = Rules.strength_of(10.0)
	hls._hurt(hls.ents[hl2], 9999.0, 0, "")
	check(hls.ents[hl2].get("downed", false), "a round player goes down first")
	var hwhy := hls.request_cast(hl1, "healing", hls.ents[hl2].pos)
	run(hls, 4.0)
	check(hwhy == "" and not hls.ents[hl2].get("downed", false) and hls.ents[hl2].hp > 0.0, "Healing brings a downed friend up (%s)" % hwhy)

	# A blow at a run lands harder; an edge leaves them bleeding.
	var rn := Sim.new("practice", 100)
	rn._waves = []
	var rnp := rn.add_player(Profile.create({name = "Runner", cls = "warder", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["sword"]}), Vector3.ZERO)
	rn._add_enemy("trolloc", Vector3(0, 0, 1.6))
	var rne: Dictionary = rn.ents[rnp + 1]
	rne.speed = 0.0; rne.hp = 9999.0; rne.max_hp = 9999.0
	rn.set_input(rnp, Vector3(0, 0, 1), 0.0)
	rn.request_attack(rnp, "light", Vector3(0, 1, 2))
	check(rn.ents[rnp].swing.get("bonus", 1.0) > 1.0, "a blow struck at a run carries the run")
	run(rn, 0.8)
	check(rne.get("bleed", 0.0) > 0.0, "a sword cut leaves a Trolloc bleeding")
	# A blow asked for in a roll comes out of the roll.
	var rp2: Dictionary = rn.ents[rnp]
	rp2.swing = {}; rp2.queued = {}; rp2.stamina = 999.0
	rn.set_input(rnp, Vector3.ZERO, 0.0)
	var dodge_why := rn.request_dodge(rnp, Vector3(0, 0, 1), true)
	var att_why := rn.request_attack(rnp, "light", rp2.pos + Vector3(0, 1, 3))
	check(att_why == "" and rp2.queued.get("from_roll", false), "an attack asked for in a roll waits for it (%s / %s, dash %s)" % [dodge_why, att_why, rp2.dash])
	run(rn, 0.6)
	check(not rp2.swing.is_empty() or rn.tallies[rnp].blows.get("sword", 0) >= 2, "and comes out of it")

	# Wounds: rest cannot mend them; Healing does.
	var wds := Sim.new("practice", 101)
	wds._waves = [{t = 999.0, spawn = {}}]
	var wd1 := wds.add_player(Profile.create({name = "Wounded", power = "saidin"}))
	var wde: Dictionary = wds.ents[wd1]
	wds._hurt(wde, 60.0, 0, "")
	var cap: float = wde.max_hp - wde.wound
	check(wde.wound > 10.0, "a hurt leaves a wound")
	run(wds, 120.0)
	check(wde.hp <= cap + 0.01 and wde.hp > cap - 5.0, "rest mends up to the wound and no further (%.0f of %.0f)" % [wde.hp, wde.max_hp])

	# Fire arrows: drawn beside a watch-fire, an arrow is lit and the grass it
	# falls in catches.
	var fas := Sim.new("tarwins_gap_watch", 102)
	fas._waves = [{t = 999.0, spawn = {}}]
	var fire_at: Dictionary = Map.trees().filter(func(q: Dictionary) -> bool: return q.get("prop", "") == "fire")[0]
	var fap := fas.add_player(Profile.create({name = "Fire Archer", cls = "warder", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["sword", "horse_bow"]}), Vector3(fire_at.x + 1.5, 0, fire_at.z))
	var fape: Dictionary = fas.ents[fap]
	fape.pos = Vector3(fire_at.x + 1.5, 0, fire_at.z)
	check(fas._by_fire(fape.pos), "standing by a watch-fire, an archer can light an arrow")
	var eq_why := fas.equip(fap, "horse_bow")
	var sh_why := fas.request_attack(fap, "light", fape.pos + Vector3(4, 0, 0))
	var fa_ev := run(fas, 3.0)
	check(fas.patches.any(func(q: Dictionary) -> bool: return q.kind == "fire"), "a fire arrow sets the grass it falls in alight (%s / %s / %s)" % [eq_why, sh_why, fa_ev.slice(0, 10)])

	# Armour turns a cut but not a thrust.
	var ars := Sim.new("practice", 103)
	ars._waves = []
	var arp := ars.add_player(Profile.create({name = "Pointer", cls = "warder", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["sword"]}), Vector3.ZERO)
	ars._add_enemy("myrddraal", Vector3(0, 0, 1.5))
	var are: Dictionary = ars.ents[arp + 1]
	are.hp = 9999.0; are.max_hp = 9999.0; are.row = are.row.duplicate(); are.row.erase("evades")
	ars.ents[arp].swing = {move = "cut"}
	ars._wound(are, 100.0, arp, "sword", {}, Vector3(0, 0, 1))
	var after_cut: float = 9999.0 - are.hp
	ars.ents[arp].swing = {move = "thrust"}
	ars._wound(are, 100.0, arp, "sword", {}, Vector3(0, 0, 1))
	var after_thrust: float = 9999.0 - are.hp - after_cut
	check(after_cut < 80.0 and after_thrust > 95.0, "armour turns a cut (%.0f) but not a thrust (%.0f)" % [after_cut, after_thrust])

	# A spear held still stops what runs onto it.
	var sps := Sim.new("practice", 104)
	sps._waves = [{t = 999.0, spawn = {}}]
	var spp := sps.add_player(Profile.create({name = "Spearman", cls = "aiel", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["aiel_spear"]}), Vector3.ZERO)
	sps.ents[spp].yaw = 0.0
	sps.equip(spp, "aiel_spear")
	sps._add_enemy("trolloc", Vector3(0, 0, 8))
	var spe: Dictionary = sps.ents[spp + 1]
	spe.hp = 9999.0; spe.max_hp = 9999.0
	var sp_ev := run(sps, 4.0)
	check(sp_ev.has("set_spear") and spe.hp < 9999.0, "a Trolloc running onto a set spear meets the point")

	# The Eyeless gaze: facing a Myrddraal close by, weaving comes slowly.
	var gzs := Sim.new("practice", 98)
	gzs._waves = []
	var gzp := gzs.add_player(Profile.create({name = "Gazer", power = "saidin"}))
	var gze: Dictionary = gzs.ents[gzp]
	gze.pos = Vector3.ZERO; gze.yaw = 0.0
	gzs._add_enemy("myrddraal", Vector3(0, 0, 8))
	gzs.ents[gzp + 1].speed = 0.0
	gzs._gaze(gze)
	check(gze.get("afraid", 0.0) > gzs.t, "meeting a Myrddraal's stare up close, fear grips you")
	gze.afraid = 0.0; gze.yaw = PI
	gzs._gaze(gze)
	check(gze.get("afraid", 0.0) <= gzs.t, "looking away, it does not")

	# Every setup of every mode's doorway can be fought.
	var variants := Rules.activities.keys().filter(func(k: String) -> bool: return k.contains("@"))
	check(variants.size() == 12, "three modes of four setups each (%d)" % variants.size())
	for vid in variants:
		var vs2 := Sim.new(vid, 5)
		vs2.add_player(Profile.make({name = "Setup " + vid, power = "saidar"}))
		for k in 300: vs2.step(1.0 / 30.0)
		check(not vs2.ents.is_empty() and vs2.t > 9.0, vid + " runs")

	# Team battle: sides filled with bots, kills scored, one side wins.
	var tbs := Sim.new("team_battle", 97)
	var tbp := tbs.add_player(Profile.make({name = "Banner", power = "saidin"}))
	var tbt := 0.0
	while not tbs.over and tbs.t < 800.0:
		Bot.drive(tbs, tbp)
		tbs.step(1.0 / 15.0)
		tbs.events.clear()
	var sides := {1: 0, 2: 0}
	for k in tbs.ents:
		if tbs.ents[k].kind == "player": sides[tbs.ents[k].team] += 1
	print("  team battle: over %s at %.0fs, scores %s, winner %d, levels %s, sides %s" % [tbs.over, tbs.t, tbs.scores, tbs.winner, tbs.levels, sides])
	check(sides[1] == sides[2] and sides[1] >= 2, "both sides are filled to the same number")
	check(tbs.over and tbs.winner in [1, 2] and tbs.won(tbp) == (tbs.ents[tbp].team == tbs.winner), "a battle ends with one side the winner")
	check(tbs.scores[1] + tbs.scores[2] > 0, "deaths under the other banner are scored")

	# Affinity room follows the Talents selected: 9, 7, 5.
	var rp := Profile.make({name = "Roomy", power = "saidar"})
	check(Profile.aff_cap(rp) == 9 and Profile.aff_cap(rp, 1) == 7 and Profile.aff_cap(rp, 2) == 5, "affinity room is 9, 7 or 5 by Talents selected")
	rp.talents = ["healing", "foretelling"]; rp.talents_owned = rp.talents.duplicate()
	var rng_room := RandomNumberGenerator.new(); rng_room.seed = 3
	check(Profile.unlock_offers(rp, 50, rng_room).all(func(o: Dictionary) -> bool: return o.kind != "affinity"), "no +1 affinity offered with no room (5 of 5, two Talents)")
	rp.aff_owned.air = 3; Profile.apply_affinity(rp)
	check(int(rp.aff_pts.air) == 3, "all owned affinity counts in a fight")

	# A weave left going by itself.
	var au := Sim.new("practice", 93)
	au._waves = []
	var ap := au.add_player(Profile.create({name = "Autocaster", power = "saidin", potential_pts = 8, affinity_pts = {fire = 6}}))
	au.ents[ap].profile.channelled = float(Rules.TUNE.flow_steps[4])
	au._add_enemy("trolloc", Vector3(0, 0, 10))
	var auseen := []
	check(au.tie(ap, "fireball") == "" and au.ents[ap].autos.has("fireball"), "G on a weave that strikes keeps it going by itself")
	auseen = run(au, 4.0)
	check(auseen.has("cast"), "and it weaves itself at the nearest foe")
	check(au.tie(ap, "fireball") == "" and au.ents[ap].autos.is_empty(), "G again stops it")

	# A round leaves only what a win pays.
	var keep := her.duplicate(true)
	var lines := Progression.award(her, {seconds = 600.0}, "tarwins_gap_watch", false)
	check(her.strength == keep.strength and her.get("unlocks_owed", 0) == 0, "a lost round pays nothing")
	Progression.award(her, {seconds = 600.0}, "tarwins_gap_watch", true)
	check(her.strength == keep.strength and her.unlocks_owed == 1 and her.renown > keep.renown, "a won round pays renown and one unlock, never strength")

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
	for act in ["camp_training", "short_watch"]:
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

	print("== save / load")
	Profile.save(p)
	var q := Profile.load_profile(p.name)
	check(q.renown == p.renown and q.weaves.size() == p.weaves.size() and is_equal_approx(q.strength, p.strength), "profile round-trips to disk")

	print("== pacing: the same character over many hours (extrapolated from a measured holdout)")
	var sim := play(p.duplicate(true), "short_watch")
	var per: Dictionary = sim.tallies[1]
	var h := hours
	var marks := [1, 2, 5, 10, 20, 40, 80]
	print("  hours  strength/potential  flows  renown  fireball-mastery  fire-affinity")
	while not marks.is_empty():
		Progression.award(p, per, "short_watch", true)
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
	_playtest()
	_shadowspawn()
	_dream()
	_trolloc_blows()
	_rounds()
	print("RESULT: %s" % ("ok" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails else 0)
