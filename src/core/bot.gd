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
	var pick := ""; var score := 0.0
	var reach := 0.0
	for w in me.profile.weaves:
		var row: Dictionary = Rules.weaves[w]
		if row.kind in ["barrier", "heal", "sever", "utility"]:
			continue
		var rng: float = row.base.get("range", row.base.get("radius", 99.0))
		reach = maxf(reach, rng)
		# Do not weave fire at your own feet.
		if rng < best or (row.get("self", 0.0) > 0.0 and best < row.base.radius + 2.5):
			continue
		if me.cd.get(w, 0.0) > sim.t or Rules.cast_block(me.profile, w, sim.free_slots(me), me.stamina) != "":
			continue
		var s: float = row.base.get("damage", row.base.get("dps", 0.0)) * row.base.get("count", 1) * (1.5 if crowd > 3 and row.kind in ["ring", "burst", "cone"] else 1.0)
		if s > score:
			score = s; pick = w
	# Close to weaving distance, back off when they get near, otherwise hold ground.
	var move := Vector3.ZERO
	if best < 6.0 and near.speed > 0.0:
		move = -to
	elif best > reach * 0.8:
		move = to
	sim.set_input(id, move, atan2(to.x, to.z))
	if pick != "" and me.forming.is_empty():
		sim.request_cast(id, pick, sim.aim_at(me, pick, near))
