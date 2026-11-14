class_name Progression
extends RefCounted
## The one place a character grows. Every activity (training, holdout, mission, spar)
## ends by handing its tally to award(); none of them keeps progress of its own, so
## an hour in any of them moves the same character forward.
##
## Growth follows the books: strength creeps toward potential with use, each Power
## improves by being woven, weaves are mastered by weaving them and learned by seeing
## them woven, and holding more flows at once is the long road.

## tally: {casts: {weave: n}, kills: {weave: n}, draw: float, seconds: float}
## Returns human-readable lines describing what changed.
static func award(p: Dictionary, tally: Dictionary, activity_id: String, success: bool) -> Array[String]:
	var T := Rules.TUNE
	var act: Dictionary = Rules.activities[activity_id]
	var yield_: Dictionary = act.get("yield", {})
	var out: Array[String] = []
	var flows_before := Rules.flow_capacity(p)
	var draw: float = tally.get("draw", 0.0)
	p.seconds += tally.get("seconds", 0.0)

	# Weave mastery: one xp per cast, one more per kill made with it.
	var per_el := {}
	for id in tally.get("casts", {}):
		var n: float = tally.casts[id] + tally.get("kills", {}).get(id, 0)
		var before := Rules.mastery_level(p, id)
		p.weaves[id].xp += n * yield_.get("mastery", 1.0)
		var after := Rules.mastery_level(p, id)
		if after > before:
			out.append("%s mastery %d -> %d" % [Rules.weaves[id].name, before, after])
		var fl := Rules.flows_of(Rules.weaves[id], p)
		var slots := float(Rules.slots_of(Rules.weaves[id], p))
		for e in fl:
			per_el[e] = per_el.get(e, 0.0) + Rules.draw_of(p, id) * tally.casts[id] * fl[e] / slots

	# Each Power improves toward its aptitude by being woven.
	for e in per_el:
		var gain: float = (p.aptitude[e] - p.affinity[e]) * (1.0 - exp(-per_el[e] / T.affinity_k))
		if gain > 0.0:
			var a0 := int(p.affinity[e] * 100.0)
			p.affinity[e] += gain
			if int(p.affinity[e] * 100.0) > a0:
				out.append("%s affinity %d -> %d" % [e.capitalize(), a0, int(p.affinity[e] * 100.0)])

	# Strength grows toward potential with use; holding more flows comes with experience.
	var s0: float = Rules.strength(p)
	p.strength += (p.potential - p.strength) * (1.0 - exp(-draw * yield_.get("strength", 1.0) / T.strength_k))
	if Rules.level_of(Rules.strength(p)) < Rules.level_of(s0):
		out.append("Strength %s -> %s (potential %s)" % [Rules.level_name(Rules.level_of(s0)), Rules.level_name(Rules.level_of(Rules.strength(p))), Rules.level_name(Rules.level_of(p.potential))])
	p.channelled += draw
	if Rules.flow_capacity(p) > flows_before:
		out.append("You can now hold %d flows at once" % Rules.flow_capacity(p))

	if success:
		var first: bool = not p.done.has(activity_id)
		p.done[activity_id] = p.done.get(activity_id, 0) + 1
		var ren: float = act.renown * (1.0 if first else T.repeat_renown)
		p.renown += ren
		out.append("Renown +%.0f (%d)" % [ren, int(p.renown)])
		# Weaves are learned by seeing them woven.
		for id in act.get("teaches", []):
			if not p.weaves.has(id) and Rules.weaves[id].book <= p.book_limit:
				p.weaves[id] = {known = true, xp = 0.0}
				out.append("Learned %s" % Rules.weaves[id].name)
	return out
