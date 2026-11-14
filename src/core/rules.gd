class_name Rules
extends RefCounted
## The game's rules as pure functions over plain data: no nodes, no rendering.
## The sim, the UI, the host and the tests all call these, so there is exactly one
## answer to "can this character cast that, and how hard does it hit".

const ELEMENTS: Array[String] = ["fire", "earth", "water", "air", "spirit"]

## Every pacing number lives here so tuning never means hunting through code.
const TUNE := {
	ref_power = 25.0,          # weave base numbers are written for this power
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
	start_gap = 10,            # a new channeller starts this many levels below potential
	saidin_jump = 3,           # men gain strength in jumps of this many levels
}

static var weaves: Dictionary = {}
static var enemies: Dictionary = {}
static var activities: Dictionary = {}

static func load_data() -> void:
	if not weaves.is_empty():
		return
	weaves = _json("res://data/weaves.json")
	enemies = _json("res://data/enemies.json")
	activities = _json("res://data/activities.json")

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
