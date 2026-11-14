class_name Rules
extends RefCounted
## The game's rules as pure functions over plain data: no nodes, no rendering.
## The sim, the UI, the host and the tests all call these, so there is exactly one
## answer to "can this character cast that, and how hard does it hit".

const ELEMENTS: Array[String] = ["fire", "earth", "water", "air", "spirit"]

## Every pacing number lives here so tuning never means hunting through code.
const TUNE := {
	ref_power = 16.0,          # weave base numbers are written for this power
	min_affinity = 0.12,       # per-flow floor to be able to form a weave at all
	mastery_xp = 150.0,        # level = floor(sqrt(xp / this)), capped
	mastery_cap = 10,
	mastery_power = 0.05,      # +5% power per mastery level
	mastery_speed = 0.035,     # -3.5% form time per level
	mastery_thrift = 0.03,     # -3% draw per level
	strength_k = 150000.0,     # lifetime draw to close ~63% of the gap to potential
	affinity_k = 80000.0,
	# Lifetime draw needed to hold this many flows at once: the headline progression.
	flow_steps = [0, 0, 0, 60000, 250000, 700000, 1600000, 3200000, 6000000, 10000000, 16000000],
	talent_power = 1.5,        # a weave woven by someone with the Talent for it
	earth_singing = 1.2,
	# Strength is stored as a magnitude and shown as a Companion level. Level 1 (the
	# strongest woman) is magnitude 100 and every level down divides by this, so
	# level 72 is about 10 and ++1 (the strongest man) about 121.
	level_ratio = 1.033,
	repeat_renown = 0.25,      # share of renown paid for replaying a cleared activity
	# Stamina replaces a mana bar: a deep pool that barely refills during a fight.
	# As it drains, weaves weaken and cost less, so a tired channeller keeps weaving
	# small, and loses the strength for gated weaves such as gateways.
	stamina = 1500.0,
	stamina_regen = 1.5,       # per second
	tired_floor = 0.25,        # share of your strength left at empty stamina
	hold_upkeep = 0.12,        # share of a weave's cost paid each second it is held
	tie_secs = 25.0,           # how long a tied-off weave lasts before it unravels (longer with mastery)
	start_gap = 10,            # a new channeller starts this many levels below potential
	saidin_jump = 3,           # men gain strength in jumps of this many levels
	# Arms (see docs/MELEE.md). Stats are 0..8 creation points.
	might_dmg = 0.05,          # +5% damage per point of might
	quick_speed = 0.03,        # -3% wind-up and recovery per point of quickness
	endur_thrift = 0.04,       # -4% stamina cost per point of endurance
	skill_xp = 60.0,           # weapon skill level = floor(sqrt(xp / this)), capped by class
	skill_dmg = 0.05,
	skill_speed = 0.02,
	skill_thrift = 0.02,
	guard_cost = 0.7,          # stamina per point of damage a guard stops
	parry_window = 0.25,       # a guard raised this soon before the blow is a parry
	parry_stagger = 1.1,
	chain_window = 0.5,        # s after a blow in which the next tap continues the chain
	swing_slow = 0.45,         # share of running speed kept while winding up a blow
	guard_slow = 0.5,
	duck_slow = 0.4,
	gang = 2,                  # how many enemies may be mid-attack on one person at once; the rest wait their turn
	ward_reach = 3.5,          # a guarding Warder this close to a channeller takes blows meant for them
	bond_reach = 15.0,         # a Warder and a channeller this close both recover stamina faster
	bond_regen = 3.0,
	rest_after = 6.0,          # s without being hurt before you catch your breath
	rest_regen = 0.03,         # share of full health recovered each second after that
	sidestep = {dist = 2.6, time = 0.28, safe = 0.22, cost = 14.0},
	roll = {dist = 4.8, time = 0.6, safe = 0.42, cost = 28.0},
}

## What each class is good at. skill_cap: ceiling on any weapon skill. guard,
## dodge_cost, safe (untouchable time) and speed are multipliers. kit: what a new
## character of the class carries unless they choose otherwise.
const CLASSES := {
	channeller = {name = "Channeller", skill_cap = 4, guard = 0.8, dodge_cost = 1.6, safe = 0.75, speed = 1.0, carry = 1, kit = [], hp = 100.0, armour = 0.0},
	warder = {name = "Warder", skill_cap = 10, guard = 1.15, dodge_cost = 1.0, safe = 1.0, speed = 1.0, carry = 3, kit = ["sword", "horse_bow", "belt_knife"], hp = 180.0, armour = 0.3},
	aiel = {name = "Aiel", skill_cap = 10, guard = 1.0, dodge_cost = 0.75, safe = 1.2, speed = 1.12, carry = 3, kit = ["aiel_spear", "aiel_knife", "horn_bow"], hp = 150.0, armour = 0.1},
	hunter = {name = "Hunter of the Horn", skill_cap = 9, guard = 0.95, dodge_cost = 0.9, safe = 1.0, speed = 1.04, carry = 3, kit = ["quarterstaff", "longbow", "throwing_knives"], hp = 160.0, armour = 0.2},
}
## hp: how much a body of that calling can take. armour: share of every blow
## turned by what they wear (a Warder's mail, a Hunter's leather, cadin'sor).
static func max_hp(p: Dictionary) -> float:
	return cls(p).hp + 6.0 * stat(p, "endurance")
const FAMILIES: Array[String] = ["sword", "knife", "spear", "staff", "axe", "bow", "thrown", "hand"]

static var weaves: Dictionary = {}
static var enemies: Dictionary = {}
static var activities: Dictionary = {}
static var weapons: Dictionary = {}
static var moves: Dictionary = {}
static var forms: Dictionary = {}

static func load_data() -> void:
	if not weaves.is_empty():
		return
	weaves = _json("res://data/weaves.json")
	enemies = _json("res://data/enemies.json")
	activities = _json("res://data/activities.json")
	weapons = _json("res://data/weapons.json")
	moves = weapons["_moves"]
	forms = weapons["_forms"]
	forms.erase("_doc")
	weapons.erase("_moves")
	weapons.erase("_forms")
	# A form is a move like any other once it is in the hand.
	for f in forms:
		moves[f] = forms[f]

static func _json(path: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d.erase("_doc")
	return d

## Flows of a weave for this character (gateways differ for saidin and saidar).
static func flows_of(w: Dictionary, p: Dictionary) -> Dictionary:
	if p.power == "saidin" and w.has("flows_saidin"):
		return w.flows_saidin
	return w.flows

static func slots_of(w: Dictionary, p: Dictionary) -> int:
	var n := 0
	for e in flows_of(w, p):
		n += int(flows_of(w, p)[e])
	return n

## A Talent no longer unlocks a weave: anyone can learn it, and the Talent makes
## it much stronger and waives any strength gate.
static func has_talent(p: Dictionary, w: Dictionary) -> bool:
	return w.has("talent") and p.talents.has(w.talent)

## Techniques are ways of handling weaves, learned once and used with any of them.
static func has_technique(p: Dictionary, name: String) -> bool:
	return p.get("techniques", []).has(name)

static func tie_time(p: Dictionary, weave_id: String) -> float:
	return TUNE.tie_secs * (1.0 + 0.15 * mastery_level(p, weave_id))

## The Wheel of Time Companion's scale as one number: 72 (weakest) up to 1 (the
## strongest woman), then 0 down to -5 for the six men's levels ++6 up to ++1.
static func level_of(strength: float) -> int:
	return clampi(roundi(1.0 - log(maxf(strength, 0.01) / 100.0) / log(TUNE.level_ratio)), -5, 72)

static func strength_of(level: float) -> float:
	return 100.0 * pow(TUNE.level_ratio, 1.0 - level)

static func _level_f(s: float) -> float:
	return 1.0 - log(maxf(s, 0.01) / 100.0) / log(TUNE.level_ratio)

## The strength a character channels with. Practice accrues the same for everyone
## (profile.strength), but women rise steadily through every level while men stay
## put and then leap several levels at once, as in the books.
static func strength(p: Dictionary) -> float:
	if p.power != "saidin":
		return p.strength
	var pot := _level_f(p.potential)
	var below := maxf(_level_f(p.strength) - pot, 0.0)
	if below > TUNE.start_gap - 0.5:
		return p.strength
	return strength_of(pot + TUNE.saidin_jump * roundf(below / TUNE.saidin_jump))

## Share of full strength available at this stamina (negative = rested).
static func vigor(stamina: float) -> float:
	if stamina < 0.0:
		return 1.0
	return lerpf(TUNE.tired_floor, 1.0, clampf(stamina / TUNE.stamina, 0.0, 1.0))

## "19(7)", "8(+5)" or "++2": the level, then its rank on the older White Tower
## scale, which began at what is now 13.
static func level_name(level: int) -> String:
	if level <= 0:
		return "++%d" % (level + 6)
	return "%d(%s)" % [level, str(level - 12) if level > 12 else "+%d" % (13 - level)]

static func mastery_level(p: Dictionary, weave_id: String) -> int:
	var xp: float = p.weaves.get(weave_id, {}).get("xp", 0.0)
	return mini(int(sqrt(xp / TUNE.mastery_xp)), TUNE.mastery_cap)

## Why a character cannot cast a weave right now, or "" if they can.
static func cast_block(p: Dictionary, weave_id: String, free_slots: int, stamina: float) -> String:
	var w: Dictionary = weaves[weave_id]
	if not p.weaves.get(weave_id, {}).get("known", false):
		return "not learned"
	# The weave you were born knowing is never hidden by the spoiler setting.
	if w.book > p.book_limit and p.get("starter", "") != weave_id:
		return "beyond your reading"
	# A strength gate is written as a Companion level; the Talent for the weave
	# waives it (Androl makes gateways his strength should not allow).
	if w.has("level") and not has_talent(p, w):
		if level_of(strength(p)) > int(w.level):
			return "needs strength %s or the Talent" % level_name(int(w.level))
		if level_of(strength(p) * vigor(stamina)) > int(w.level):
			return "too tired: needs strength %s" % level_name(int(w.level))
	var fl := flows_of(w, p)
	for e in fl:
		if p.affinity[e] < TUNE.min_affinity:
			return "too weak in %s" % e
	if slots_of(w, p) > free_slots:
		return "too many flows"
	return ""

## Power = strength x affinity (weighted by flow share) x mastery x Talent.
static func power(p: Dictionary, weave_id: String, stamina := -1.0) -> float:
	var w: Dictionary = weaves[weave_id]
	var fl := flows_of(w, p)
	var total := 0.0; var aff := 0.0
	for e in fl:
		total += fl[e]; aff += fl[e] * p.affinity[e]
	aff /= total
	var talent := 1.0
	if has_talent(p, w):
		talent = TUNE.talent_power
	elif fl.has("earth") and p.talents.has("earth_singing"):
		talent = TUNE.earth_singing
	# Affinity 0.5 is "ordinary": it neither helps nor hurts.
	return strength(p) * vigor(stamina) * (0.5 + aff) * (1.0 + TUNE.mastery_power * mastery_level(p, weave_id)) * talent

## Multiplier applied to a weave's base damage/heal/absorb numbers.
static func scale(p: Dictionary, weave_id: String, stamina := -1.0) -> float:
	return power(p, weave_id, stamina) / TUNE.ref_power

static func form_time(p: Dictionary, weave_id: String) -> float:
	return weaves[weave_id].form * maxf(1.0 - TUNE.mastery_speed * mastery_level(p, weave_id), 0.5)

## A tired channeller draws less of the Power, so the weave costs less too.
static func draw_of(p: Dictionary, weave_id: String, stamina := -1.0) -> float:
	return weaves[weave_id].draw * (1.0 - TUNE.mastery_thrift * mastery_level(p, weave_id)) * vigor(stamina)

## Seconds before the same weave can be woven again; practice shortens it a little.
static func cooldown(p: Dictionary, weave_id: String) -> float:
	return weaves[weave_id].get("cooldown", 0.0) * (1.0 - 0.03 * mastery_level(p, weave_id))

static func flow_capacity(p: Dictionary) -> int:
	var n := 2
	var steps: Array = TUNE.flow_steps
	for i in range(3, steps.size()):
		if p.channelled >= steps[i]:
			n = i
	return n

# --- arms -----------------------------------------------------------------------------

static func cls(p: Dictionary) -> Dictionary:
	return CLASSES.get(p.get("cls", "channeller"), CLASSES.channeller)

static func stat(p: Dictionary, name: String) -> float:
	return float(p.get("stats", {}).get(name, 0))

static func skill_level(p: Dictionary, family: String) -> int:
	return mini(int(sqrt(float(p.get("skills", {}).get(family, 0.0)) / TUNE.skill_xp)), int(cls(p).skill_cap))

## Why this character may not carry a weapon, or "".
static func wield_block(p: Dictionary, weapon_id: String) -> String:
	if not weapons.has(weapon_id):
		return "no such weapon"
	var w: Dictionary = weapons[weapon_id]
	var c: String = p.get("cls", "channeller")
	if c in w.get("never", []):
		return "an Aiel does not touch a sword" if c == "aiel" else "not a weapon for a %s" % cls(p).name
	if w.has("only") and not c in w.only:
		return "not a weapon for a %s" % cls(p).name
	if stat(p, "might") < w.get("might", 0):
		return "needs might %d" % w.might
	return ""

## The move a weapon answers an input with. kind: light | heavy | low | throw.
## `chain` is how many light blows have already run together.
static func move_for(weapon_id: String, kind: String, chain := 0) -> String:
	var w: Dictionary = weapons[weapon_id]
	if kind.begins_with("form:"):
		return kind.trim_prefix("form:") if forms.has(kind.trim_prefix("form:")) else ""
	match kind:
		"light": return w.light[chain % w.light.size()]
		"heavy": return w.heavy
		"low": return w.low
		"throw": return "throw" if w.has("throw") else ""
	return ""

static func _quick(p: Dictionary, weapon_id: String) -> float:
	var w: Dictionary = weapons[weapon_id]
	return float(w.speed) * (1.0 + TUNE.quick_speed * stat(p, "quickness") + TUNE.skill_speed * skill_level(p, w.family))

## Why this character cannot use a form right now with this weapon, or "".
static func form_block(p: Dictionary, form_id: String, weapon_id: String) -> String:
	if not forms.has(form_id) or not p.get("forms", {}).get(form_id, {}).get("known", false):
		return "not learned"
	var f: Dictionary = forms[form_id]
	if not weapons.has(weapon_id) or weapons[weapon_id].family != f.family:
		return "needs a %s in hand" % f.family
	return ""

## What a study row is for this character: a weave for a channeller, a form for a
## fighter. Both are worked out one at a time, by doing.
static func lore(p: Dictionary) -> Dictionary:
	return weaves if p.get("cls", "channeller") == "channeller" else forms

static func knows(p: Dictionary, id: String) -> bool:
	return p.get("weaves" if p.get("cls", "channeller") == "channeller" else "forms", {}).get(id, {}).get("known", false)

## [wind-up, recovery] in seconds for this character with this weapon.
static func move_times(p: Dictionary, weapon_id: String, move_id: String) -> Array:
	var m: Dictionary = moves[move_id]
	var q := _quick(p, weapon_id)
	return [m.wind / q, m.recover / q]

## Damage of one blow (or of the missile a missile move launches).
static func blow(p: Dictionary, weapon_id: String, move_id: String, stamina := -1.0) -> float:
	var w: Dictionary = weapons[weapon_id]
	var m: Dictionary = moves[move_id]
	var base: float = w.dmg * m.get("dmg", 1.0)
	var might := 1.0 + TUNE.might_dmg * stat(p, "might")
	if m.get("missile", false):
		var shot: Dictionary = w.get("shot", w.get("throw", {}))
		base = shot.get("dmg", 0.0)
		if shot.get("crank", false):
			might = 1.0
	return base * might * (1.0 + TUNE.skill_dmg * skill_level(p, w.family)) * vigor(stamina)

## A tired fighter swings with less behind it, and so spends less, like a channeller.
static func move_cost(p: Dictionary, weapon_id: String, move_id: String, stamina := -1.0) -> float:
	var w: Dictionary = weapons[weapon_id]
	return moves[move_id].cost * w.weight * maxf(1.0 - TUNE.endur_thrift * stat(p, "endurance") - TUNE.skill_thrift * skill_level(p, w.family), 0.3) * vigor(stamina)

## Share of a frontal blow this character's guard stops with this weapon.
static func guard_share(p: Dictionary, weapon_id: String) -> float:
	if not weapons.has(weapon_id):
		return 0.0
	var w: Dictionary = weapons[weapon_id]
	return minf(w.guard * cls(p).guard * (1.0 + 0.02 * skill_level(p, w.family)), 0.97) if w.guard > 0.0 else 0.0

## {dist, time, safe, cost} of a sidestep or a roll for this character.
static func dodge(p: Dictionary, rolling: bool) -> Dictionary:
	var d: Dictionary = TUNE.roll if rolling else TUNE.sidestep
	var c := cls(p)
	return {dist = d.dist * (1.0 + 0.02 * stat(p, "quickness")), time = d.time, safe = d.safe * c.safe,
		cost = d.cost * c.dodge_cost * maxf(1.0 - TUNE.endur_thrift * stat(p, "endurance"), 0.4)}

static func run_speed(p: Dictionary) -> float:
	return 5.2 * cls(p).speed * (1.0 + 0.01 * stat(p, "quickness"))

## Seconds to draw (or span) and loose, at this character's skill.
static func draw_time(p: Dictionary, weapon_id: String) -> float:
	var w: Dictionary = weapons[weapon_id]
	return w.shot.draw / (1.0 + TUNE.skill_speed * 2.0 * skill_level(p, w.family))

## The weave tree: what this character could study now, and what is still out of
## reach with the weaves it is waiting on. One weave is studied at a time.
static func study_options(p: Dictionary) -> Array:
	var out := []
	if p.get("cls", "channeller") != "channeller":
		# A fighter works out forms: those whose earlier forms are known and whose
		# weapon they are skilled enough with.
		for id in forms:
			if not knows(p, id) and missing_for(p, id).is_empty() and skill_level(p, forms[id].family) >= int(forms[id].get("skill", 0)):
				out.append(id)
		return out
	for id in weaves:
		if p.weaves.get(id, {}).get("known", false) or weaves[id].book > p.book_limit:
			continue
		if missing_for(p, id).is_empty():
			out.append(id)
	return out

static func missing_for(p: Dictionary, id: String) -> Array:
	var out := []
	for n in lore(p)[id].get("needs", []):
		if not knows(p, n):
			out.append(n)
	return out

## Channelling (or, for a form, stamina spent fighting) needed to work it out;
## half if you have seen it done.
static func study_cost(p: Dictionary, id: String) -> float:
	return lore(p)[id].get("study", 5000.0) * (0.5 if p.get("seen", []).has(id) else 1.0)

## Activities this character may start, in table order.
static func available(p: Dictionary) -> Array:
	var out := []
	for id in activities:
		var req: Dictionary = activities[id].requires
		if p.renown < req.get("renown", 0):
			continue
		var ok := true
		for d in req.get("done", []):
			if not p.done.has(d):
				ok = false
		if ok:
			out.append(id)
	return out
