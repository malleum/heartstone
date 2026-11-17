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
	if act.has("round") or int(p.get("format", 1)) >= 2:
		return _award_round(p, tally, activity_id, success)
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

	# Weapon skill, by family: every blow teaches a little, every kill more.
	var fam := {}
	for w in tally.get("blows", {}):
		if Rules.weapons.has(w):
			var f: String = Rules.weapons[w].family
			fam[f] = fam.get(f, 0.0) + tally.blows[w] + 2.0 * tally.get("kills", {}).get(w, 0)
	if not p.has("skills"):
		p.skills = {}
	for f in fam:
		var before := Rules.skill_level(p, f)
		p.skills[f] = p.skills.get(f, 0.0) + fam[f] * yield_.get("mastery", 1.0)
		if Rules.skill_level(p, f) > before:
			out.append("%s skill %d -> %d" % [f.capitalize(), before, Rules.skill_level(p, f)])

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

	# The weave being studied is worked out by channelling, whatever you channel. If
	# none was chosen, the nearest one is, so no practice is wasted.
	if p.get("study", "") == "" or not Rules.study_options(p).has(p.study):
		p.study = ""; p.study_done = 0.0
		for id in Rules.study_options(p):
			if p.study == "" or Rules.study_cost(p, id) < Rules.study_cost(p, p.study):
				p.study = id
		if p.study != "":
			out.append("You begin working out %s" % Rules.lore(p)[p.study].name)
	if p.study != "":
		# A channeller studies by channelling; a fighter by the breath spent fighting.
		var lore := Rules.lore(p)
		var fights: bool = p.get("cls", "channeller") != "channeller"
		p.study_done = p.get("study_done", 0.0) + (tally.get("effort", 0.0) if fights else draw)
		if p.study_done >= Rules.study_cost(p, p.study):
			if fights:
				if not p.has("forms"): p.forms = {}
				p.forms[p.study] = {known = true}
			else:
				p.weaves[p.study] = {known = true, xp = 0.0}
			out.append("Learned %s" % lore[p.study].name)
			p.study = ""; p.study_done = 0.0
		else:
			out.append("%s: %d%% worked out" % [lore[p.study].name, int(100.0 * p.study_done / Rules.study_cost(p, p.study))])

	var channels: bool = p.get("cls", "channeller") == "channeller"
	if success:
		for id in (act.get("shows", []) if channels else []):
			if not p.seen.has(id) and not p.weaves.has(id) and Rules.weaves[id].book <= p.book_limit:
				p.seen.append(id)
				out.append("You saw %s woven" % Rules.weaves[id].name)
		var first: bool = not p.done.has(activity_id)
		p.done[activity_id] = p.done.get(activity_id, 0) + 1
		var ren: float = act.renown * (1.0 if first else T.repeat_renown)
		p.renown += ren
		out.append("Renown +%.0f (%d)" % [ren, int(p.renown)])
		# Techniques are taught by an activity the first time it is cleared.
		for g in (act.get("grants", []) if channels else []):
			if not p.has("techniques"): p.techniques = []
			if not p.techniques.has(g):
				p.techniques.append(g)
				out.append({tie_off = "You have learned to tie off a weave (G): it holds without you for a while, and frees your flows"}.get(g, "Learned " + g))
		# The training yard hands its weaves over outright.
		for id in (act.get("teaches", []) if channels else []):
			if not p.weaves.has(id) and Rules.weaves[id].book <= p.book_limit:
				p.weaves[id] = {known = true, xp = 0.0}
				out.append("Learned %s" % Rules.weaves[id].name)
	return out


## A round leaves the character as it found them: strength, practice and body all
## belonged to the round. Only a win pays, in renown and one unlock to choose (a
## Talent, a weave, a form, a weapon, or a point of affinity; never raw strength).
static func _award_round(p: Dictionary, tally: Dictionary, activity_id: String, success: bool) -> Array[String]:
	var act: Dictionary = Rules.activities[activity_id]
	var out: Array[String] = []
	p.seconds += tally.get("seconds", 0.0)
	if not success:
		out.append("The round is lost. Nothing carries over but what you learned of it.")
		return out
	var first: bool = not p.done.has(activity_id)
	p.done[activity_id] = p.done.get(activity_id, 0) + 1
	var ren: float = act.renown * (1.0 if first else Rules.TUNE.repeat_renown)
	p.renown += ren
	out.append("Renown +%.0f (%d)" % [ren, int(p.renown)])
	# Only a round's win is worth keeping something for; practice and spars are not.
	if act.has("round"):
		p.unlocks_owed = int(p.get("unlocks_owed", 0)) + 1
		out.append("A win: choose something to keep in the camp")
	return out
