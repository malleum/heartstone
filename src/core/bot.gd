class_name Bot
extends RefCounted
## A stand-in player for tests and soak runs: kites and casts the hardest-hitting
## weave it can. Not an AI opponent, just enough to exercise the rules.

static func drive(sim: Sim, id: int) -> void:
	var me: Dictionary = sim.ents[id]
	if not me.alive:
		return
	var near: Dictionary = {}
	var best := 1e9
	var crowd := 0
	for eid in sim.ents:
		var e: Dictionary = sim.ents[eid]
		if e.alive and e.team != me.team:
			var d: float = e.pos.distance_to(me.pos)
			if d < 9.0: crowd += 1
			if d < best:
				best = d; near = e
	if near.is_empty():
		sim.set_input(id, Vector3.ZERO, me.yaw)
		return
	var to: Vector3 = (near.pos - me.pos).normalized()
	# Back off when they get close; otherwise hold ground.
	sim.set_input(id, -to if best < 7.0 else Vector3.ZERO, atan2(to.x, to.z))
	if not me.forming.is_empty():
		return
	var pick := ""; var score := 0.0
	for w in me.profile.weaves:
		var row: Dictionary = Rules.weaves[w]
		if row.kind in ["barrier", "heal", "sever", "utility"] or row.base.get("range", 99.0) < best:
			continue
		if Rules.cast_block(me.profile, w, sim.free_slots(me), me.endurance) != "":
			continue
		var s: float = row.base.get("damage", row.base.get("dps", 0.0)) * row.base.get("count", 1) * (1.5 if crowd > 3 and row.kind in ["ring", "burst", "cone"] else 1.0)
		if s > score:
			score = s; pick = w
	if pick != "":
		sim.request_cast(id, pick, near.pos)
