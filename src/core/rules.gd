class_name Rules
extends RefCounted
## The game's rules as pure functions over plain data: no nodes, no rendering.
## The sim, the UI, the host and the tests all call these, so there is exactly one
## answer to "can this character cast that, and how hard does it hit".

const ELEMENTS: Array[String] = ["fire", "earth", "water", "air", "spirit"]

## Every pacing number lives here so tuning never means hunting through code.
const TUNE := {
	ref_power = 10.0,          # weave base numbers are written for this power
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
	repeat_renown = 0.25,      # share of renown paid for replaying a cleared activity
	endurance = 100.0,         # how much of the Power can be drawn before tiring
	endurance_regen = 7.0,     # per second
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

static func mastery_level(p: Dictionary, weave_id: String) -> int:
	var xp: float = p.weaves.get(weave_id, {}).get("xp", 0.0)
	return mini(int(sqrt(xp / TUNE.mastery_xp)), TUNE.mastery_cap)

## Why a character cannot cast a weave right now, or "" if they can.
static func cast_block(p: Dictionary, weave_id: String, free_slots: int, endurance: float) -> String:
	var w: Dictionary = weaves[weave_id]
	if not p.weaves.get(weave_id, {}).get("known", false):
		return "not learned"
	if w.book > p.book_limit:
		return "beyond your reading"
	if w.has("talent") and not p.talents.has(w.talent):
		return "needs the %s Talent" % w.talent
	if p.strength < w.get("min_strength", 0.0):
		return "not strong enough"
	var fl := flows_of(w, p)
	for e in fl:
		if p.affinity[e] < TUNE.min_affinity:
			return "too weak in %s" % e
	if slots_of(w, p) > free_slots:
		return "too many flows"
	if endurance < draw_of(p, weave_id):
		return "exhausted"
	return ""

## Power = strength x affinity (weighted by flow share) x mastery x Talent.
static func power(p: Dictionary, weave_id: String) -> float:
	var w: Dictionary = weaves[weave_id]
	var fl := flows_of(w, p)
	var total := 0.0; var aff := 0.0
	for e in fl:
		total += fl[e]; aff += fl[e] * p.affinity[e]
	aff /= total
	var talent := 1.0
	if fl.has("earth") and p.talents.has("earth_singing"):
		talent = 1.2
	# Affinity 0.5 is "ordinary": it neither helps nor hurts.
	return p.strength * (0.5 + aff) * (1.0 + TUNE.mastery_power * mastery_level(p, weave_id)) * talent

## Multiplier applied to a weave's base damage/heal/absorb numbers.
static func scale(p: Dictionary, weave_id: String) -> float:
	return power(p, weave_id) / TUNE.ref_power

static func form_time(p: Dictionary, weave_id: String) -> float:
	return weaves[weave_id].form * maxf(1.0 - TUNE.mastery_speed * mastery_level(p, weave_id), 0.5)

static func draw_of(p: Dictionary, weave_id: String) -> float:
	return weaves[weave_id].draw * (1.0 - TUNE.mastery_thrift * mastery_level(p, weave_id))

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
