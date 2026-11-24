class_name Round
extends RefCounted
## One round of a fight, as the players live it: everyone starts afresh and grows
## during the round, and what they become does not outlast it (the saved character
## keeps only what a win unlocks; see docs/ARCHITECTURE "Rounds").
##
## At the start the sim makes each player a round copy of their character with a
## rolled strength (channellers) or a rolled gift (fighters). The team shares
## experience from kills; each team level carries every channeller toward their
## rolled potential (women steadily, men in leaps of 2-5 levels at random) and gives
## everyone a choice on their tree. All the usual rules (Rules.power and the rest)
## then read the round copy as they would the saved one.

## Potential, on the Companion scale (1 the strongest woman, smaller is stronger).
## A bell centred near the gateway line, so about half can Travel, with a tail that
## reaches 1 about once in two hundred rolls. Men's curve sits six levels higher
## (stronger), as the men's table runs six levels above the women's.
const POT_MEAN := 20.0
const POT_SD := 7.4
const MEN_SHIFT := 6.0
## How far below potential a round begins: usually about six, never more than ten.
const GAP_MEAN := 6.0
const GAP_SD := 1.8
## Share of the gap to potential closed by the level an average win reaches.
const WIN_SHARE := 0.75
const WIN_LEVEL := 12
## Experience for the next team level: XP_BASE * level ^ XP_EXP.
const XP_BASE := 30.0
const XP_EXP := 1.35
## Going down in the waves: when the wave ends, a friend on their feet this close
## gets you up on 1 health; nobody, and you die.
const FRIEND_REACH := 5.0
## In a battle: this long for a friend to reach you, this close, for this long.
const DOWN_SECS := 15.0
const REVIVE_REACH := 1.8
const REVIVE_SECS := 2.0
## Darkfriend rounds: roles given out this many seconds in (so everyone who meant to
## join has).
const DF_ASSIGN_T := 8.0

## Standard normal cumulative distribution (Abramowitz and Stegun 7.1.26).
static func _phi(z: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(z) / sqrt(2.0))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-z * z / 2.0)
	return 0.5 * (1.0 + (y if z >= 0.0 else -y))

static func _mean(man: bool, bonus := 0.0) -> float:
	return POT_MEAN - (MEN_SHIFT if man else 0.0) - bonus

## Roll a potential level. bonus moves the mean stronger by that many levels
## (a Darkfriend among many loyal players). Clamped to the scale's ends.
static func roll_potential(rng: RandomNumberGenerator, man: bool, bonus := 0.0) -> float:
	var top := -5.0 if man else 1.0
	return clampf(roundf(rng.randfn(_mean(man, bonus), POT_SD)), top, 72.0)

## How often a roll is at least this strong: the share of rolls at or above it.
static func share_at_or_above(level: float, man: bool) -> float:
	return clampf(_phi((level + 0.5 - _mean(man)) / POT_SD), 0.0, 1.0)

static func roll_gap(rng: RandomNumberGenerator) -> float:
	return clampf(roundf(rng.randfn(GAP_MEAN, GAP_SD)), 1.0, 10.0)

static func xp_for(level: int) -> float:
	return XP_BASE * pow(float(level), XP_EXP)

## Experience a kill gives the team: tougher things give more.
static func xp_of(enemy_row: Dictionary) -> float:
	return float(enemy_row.get("hp", 60)) / 12.0 * (1.0 + 0.5 * float(enemy_row.get("tier", 0)))

## Make the round copy of a character. opts: {bonus: potential mean shift}.
static func begin(profile: Dictionary, rng: RandomNumberGenerator, opts := {}) -> Dictionary:
	var p: Dictionary = profile.duplicate(true)
	var man: bool = p.get("power", "saidar") == "saidin"
	var r := {level = 1, picks = 0, man = man}
	if p.get("cls", "channeller") == "channeller":
		var pot := roll_potential(rng, man, float(opts.get("bonus", 0.0)))
		var start := minf(pot + roll_gap(rng), 72.0)
		if p.get("no_roll", false):
			# A tour station or a render that set the strength: keep it.
			pot = float(Rules.level_of(p.potential)); start = float(Rules.level_of(p.strength))
		r.pot_level = pot; r.start_level = start; r.now_level = start
		# Men grow in leaps: how many levels owed before the next one, rolled anew each time.
		r.leap = rng.randi_range(2, 5); r.owed = 0.0
		p.potential = Rules.strength_of(pot)
		p.strength = Rules.strength_of(start)
		# All owned affinity counts (characters saved with a smaller "taken" share too).
		if p.has("aff_owned"): Profile.apply_affinity(p)
		# Every channeller can tie off a held weave (it used to be earned in the old
		# progression, which rounds no longer pay out).
		if not p.has("techniques"): p.techniques = []
		if not p.techniques.has("tie_off"): p.techniques.append("tie_off")
		# Three flows at once to begin with; more come with team levels.
		p.channelled = float(Rules.TUNE.flow_steps[3])
		for w in p.weaves:
			p.weaves[w].xp = 0.0
		# An Aes Sedai has a chance of a Warder as uncommon as her rolled potential
		# is common: the rarer and stronger the roll, the less likely a Warder.
		if not man:
			r.warder_chance = share_at_or_above(pot, false)
			r.warder = rng.randf() < r.warder_chance
	else:
		# A fighter's gift: a bell over a few points of body and how quickly the hand learns.
		var gift := clampf(rng.randfn(0.0, 1.0), -2.5, 3.0)
		r.gift = gift
		r.learn = 1.0 + 0.2 * gift
		var stats: Dictionary = p.get("stats", {}).duplicate()
		for st in ["might", "quickness", "endurance"]:
			stats[st] = maxi(int(stats.get(st, 0)) + int(roundf(gift * 0.8)), 0)
		p.stats = stats
		p.skills = {}
	p.round = r
	return p

## The level a channeller's strength should be at, at this team level, if they
## rose smoothly: WIN_SHARE of the way to potential at WIN_LEVEL, and on towards it.
static func path_level(r: Dictionary, team_level: int) -> float:
	var t := float(team_level - 1) / float(WIN_LEVEL - 1)
	var share := WIN_SHARE * t if t <= 1.0 else WIN_SHARE + (1.0 - WIN_SHARE) * (1.0 - exp(-(t - 1.0) * 1.5))
	return lerpf(r.start_level, r.pot_level, minf(share, 1.0))

## One team level for one player's round copy. Returns what changed, for the view.
static func level_up(p: Dictionary, team_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary = p.round
	r.level = team_level
	r.picks += 1
	var out := {level = team_level}
	if p.get("cls", "channeller") == "channeller":
		var want := path_level(r, team_level)
		if not r.man:
			# A woman passes through every level on the way.
			r.now_level = want
		else:
			# A man stays where he is, then leaps several levels at once.
			r.owed = r.now_level - want
			if r.owed >= r.leap:
				r.now_level -= r.leap
				out.leap = r.leap
				r.leap = rng.randi_range(2, 5)
		p.strength = Rules.strength_of(r.now_level)
		out.strength = Rules.level_of(p.strength)
		# A feeling, not a number: how far you can still go is never said outright.
		var left: float = r.now_level - r.pot_level
		out.hint = "The Source feels endless" if left > 4.0 else ("There is more in you yet" if left > 1.5 else ("You feel the edge of what you can hold" if left > 0.4 else "You hold all you can"))
		# Another flow every three levels, up to ten.
		var flows := mini(3 + (team_level - 1) / 3, 10)
		p.channelled = maxf(p.channelled, float(Rules.TUNE.flow_steps[flows]))
		out.flows = Rules.flow_capacity(p)
	else:
		# A fighter's body hardens: a point of something every other level.
		if team_level % 2 == 0:
			var st: String = ["endurance", "might", "quickness"][(team_level / 2) % 3]
			p.stats[st] = int(p.stats.get(st, 0)) + 1
			out.stat = st
	return out

## What a player may choose at a level-up: their own weaves (each choice is a level
## of mastery), or for a fighter a skill level in a weapon family they carry, a
## weapon their calling allows, or a form for a weapon they carry.
static func choices(p: Dictionary) -> Array:
	var out := []
	if p.get("cls", "channeller") == "channeller":
		for w in p.weaves:
			if Rules.weaves.has(w) and p.weaves[w].get("known", false) and Rules.mastery_level(p, w) < Rules.TUNE.mastery_cap:
				out.append({kind = "weave", id = w, name = Rules.weaves[w].name})
		# Or a new weave: any the chart says comes next from what is known.
		for w in Rules.study_options(p):
			out.append({kind = "learn", id = w, name = "Learn " + Rules.weaves[w].name})
		return out
	var fams := {}
	for w in p.get("kit", []):
		fams[Rules.weapons[w].family] = true
	for f in fams:
		if Rules.skill_level(p, f) < int(Rules.cls(p).skill_cap):
			out.append({kind = "skill", id = f, name = "%s skill" % f.capitalize()})
	for f in Rules.forms:
		if fams.has(Rules.forms[f].family) and not p.get("forms", {}).has(f):
			out.append({kind = "form", id = f, name = Rules.forms[f].name})
	# The next weapon along the tree; it replaces the one of its family in hand.
	for w in Rules.tree_weapons():
		if Rules.weapon_open(p, w):
			var old := ""
			for k in p.get("kit", []):
				if Rules.weapons[k].family == Rules.weapons[w].family: old = k
			if old != "" or p.get("kit", []).size() < int(Rules.cls(p).carry) + 1:
				out.append({kind = "weapon", id = w, name = Rules.weapons[w].name + ("  (for your %s)" % Rules.weapons[old].name.to_lower() if old != "" else "")})
	return out

## Spend a level-up on one choice. "" if done, or why not.
static func pick(p: Dictionary, choice_kind: String, id: String) -> String:
	var r: Dictionary = p.get("round", {})
	if r.get("picks", 0) <= 0:
		return "nothing to choose"
	match choice_kind:
		"weave":
			if not p.weaves.has(id):
				return "not a weave you know"
			# Already mastered as far as it goes: no pick is spent on it.
			if Rules.mastery_level(p, id) >= Rules.TUNE.mastery_cap:
				return "already mastered"
			# One level of mastery: the xp for the next level.
			var lv := Rules.mastery_level(p, id) + 1
			p.weaves[id].xp = maxf(p.weaves[id].xp, float(lv * lv) * Rules.TUNE.mastery_xp)
		"learn":
			if p.get("cls", "channeller") != "channeller" or not Rules.study_options(p).has(id):
				return "not a weave you can learn yet"
			p.weaves[id] = {known = true, xp = 0.0}
		"skill":
			var lv := Rules.skill_level(p, id) + 1
			if not p.has("skills"):
				p.skills = {}
			p.skills[id] = maxf(float(p.skills.get(id, 0.0)), float(lv * lv) * Rules.TUNE.skill_xp)
		"form":
			if not p.has("forms"):
				p.forms = {}
			p.forms[id] = {known = true}
		"weapon":
			if Rules.wield_block(p, id) != "":
				return Rules.wield_block(p, id)
			var at := -1
			for i in p.kit.size():
				if Rules.weapons[p.kit[i]].family == Rules.weapons[id].family: at = i
			if at >= 0:
				p.kit[at] = id
			else:
				p.kit.append(id)
			if not p.has("weapons_learned"): p.weapons_learned = []
			p.weapons_learned.append(id)
		_:
			return "no such choice"
	r.picks -= 1
	return ""

## The waves of a round, from the activity's "round" row:
##   {waves: 18, gap: 80, start: 8, grow: 1.2, specials: [type, ...], boss: {type: n}}
## Most waves are Trollocs alone, growing each time; every fourth brings the place's
## special Shadowspawn with them; every sixth is a horde, far more than before; the
## last brings the boss. Gaps shorten as the round wears on. A win is surviving them all.
static func plan(act: Dictionary, rng: RandomNumberGenerator) -> Array:
	var r: Dictionary = act.round
	var n := int(r.get("waves", 18))
	var gap := float(r.get("gap", 80.0))
	var start := float(r.get("start", 8.0))
	var grow := float(r.get("grow", 1.2))
	var specials: Array = r.get("specials", ["trolloc_archer", "trolloc_brute"])
	var out := []
	var t := 3.0
	for i in n:
		var count := start * pow(grow, i)
		var spawn := {}
		if i == n - 1:
			spawn = (r.get("boss", {"myrddraal": 1}) as Dictionary).duplicate()
			spawn.trolloc = int(count * 1.5)
		elif i % 6 == 5:
			# A horde: everything that was coming, and more besides.
			spawn.trolloc = int(count * 2.5)
		elif i % 4 == 3:
			spawn.trolloc = int(count * 0.7)
			var kind: String = specials[(i / 4) % specials.size()]
			spawn[kind] = maxi(1, int(round(count * (0.25 if kind.begins_with("trolloc") else 0.06))))
		else:
			spawn.trolloc = int(count)
		out.append({t = t, spawn = spawn})
		t += gap * lerpf(1.0, 0.7, float(i) / float(maxi(n - 1, 1)))
	return out

## A real death in a round: potential and strength both fall this many levels.
static func weaken(p: Dictionary, levels: int) -> void:
	var r: Dictionary = p.get("round", {})
	if not r.has("pot_level"):
		return
	r.pot_level = minf(r.pot_level + levels, 72.0)
	r.start_level = minf(r.start_level + levels, 72.0)
	r.now_level = minf(r.now_level + levels, 72.0)
	p.potential = Rules.strength_of(r.pot_level)
	p.strength = Rules.strength_of(r.now_level)

## A Darkfriend among many: the roll moves this many levels stronger (start, potential
## and now together), never past the top of their scale.
static func strengthen(p: Dictionary, levels: int) -> void:
	var r: Dictionary = p.get("round", {})
	if not r.has("pot_level") or levels <= 0:
		return
	var top := -5.0 if r.man else 1.0
	r.pot_level = maxf(r.pot_level - levels, top)
	r.start_level = maxf(r.start_level - levels, top)
	r.now_level = maxf(r.now_level - levels, top)
	p.potential = Rules.strength_of(r.pot_level)
	p.strength = Rules.strength_of(r.now_level)
