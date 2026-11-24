class_name Rules
extends RefCounted
## The game's rules as pure functions over plain data: no nodes, no rendering.
## The sim, the UI, the host and the tests all call these, so there is exactly one
## answer to "can this character cast that, and how hard does it hit".

const ELEMENTS: Array[String] = ["fire", "earth", "water", "air", "spirit"]

## Every pacing number lives here so tuning never means hunting through code.
const TUNE := {
	# Weave base numbers are written for this power: re-anchored when the scale went to
	# 5% a level (17 Nov) so a typical starting roll (26) hits as hard as before.
	ref_power = 10.64,
	weave_scale = 0.8,
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
	level_ratio = 1.05,         # 5% a level (the user's ruling, 17 Nov; was 3.3%)
	aff_point = 0.1,           # affinity per point (was 0.06), up to aff_cap
	aff_cap = 1.4,
	repeat_renown = 0.25,      # share of renown paid for replaying a cleared activity
	# Stamina replaces a mana bar: a deep pool that barely refills during a fight.
	# As it drains, weaves weaken and cost less, so a tired channeller keeps weaving
	# small, and loses the strength for gated weaves such as gateways.
	stamina = 1500.0,
	stamina_regen = 1.5,       # per second
	tired_floor = 0.25,        # share of your strength left at empty stamina
	hold_upkeep = 0.12,        # share of a weave's cost paid each second it is held
	split = 0.6,               # weaving two at once (one kept, one in hand): each comes at this speed
	kept_upkeep = 0.05,        # share of a whole weave's cost paid each second it is kept ready
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
	parry_window = 0.45,       # a parry pressed this long before the blow still stops it
	parry_perfect = 0.14,      # pressed this late, it is perfect: the attacker is shaken and thrown back
	parry_again = 0.7,         # s before a parry that met nothing can be tried again
	parry_stagger = 1.6,
	parry_shove = 7.0,         # how hard a perfect parry throws the attacker back
	form_slow = 0.6,           # share of running speed kept while a weave is being made
	chain_window = 0.5,        # s after a blow in which the next tap continues the chain
	swing_slow = 0.45,         # share of running speed kept while winding up a blow
	guard_slow = 0.5,
	duck_slow = 0.4,
	draw_slow = 0.45,          # share of running speed kept with a bow drawn
	gang = 2,                  # how many enemies may be mid-attack on one person at once; the rest wait their turn
	ward_reach = 3.5,          # a guarding Warder this close to a channeller takes blows meant for them
	spar_dmg = 0.35,           # share of a blow's or weave's damage that lands on another player in a duel
	balefire_back = 5.0,       # seconds of what a balefired thing did that are burnt away (times reach)
	link_reach = 4.0,          # how near to link
	link_share = 0.6,          # share of each member's strength the circle's leader gains
	rope_secs = 3.0,           # standing over someone to tie or untie them
	gate_cut = 120.0,          # damage from a gateway's edge as it opens or closes on you
	spar_cap = 0.07,           # and the most of a body one such blow can take
	bond_reach = 15.0,         # a Warder and a channeller this close both recover stamina faster
	bond_regen = 3.0,
	bond_fury = 12.0,          # seconds a Warder fights on in fury when his channeller falls
	fury_dmg = 1.25,
	rest_after = 10.0,         # s without being hurt before you catch your breath
	rest_regen = 0.008,        # share of full health recovered each second after that (slow: a fight is won by Healing, not waiting)
	# One dodge: a roll the way you are moving, or a step back if you are standing.
	sidestep = {dist = 3.6, time = 0.4, safe = 0.32, cost = 16.0},
}

## What each class is good at. skill_cap: ceiling on any weapon skill. guard,
## dodge_cost, safe (untouchable time) and speed are multipliers. kit: what a new
## character of the class carries unless they choose otherwise.
const CLASSES := {
	channeller = {name = "Channeller", skill_cap = 4, guard = 0.8, dodge_cost = 1.6, safe = 0.75, speed = 1.0, carry = 1, kit = [], hp = 200.0, armour = 0.0},
	warder = {name = "Warder", skill_cap = 10, guard = 1.15, dodge_cost = 1.0, safe = 1.0, speed = 1.0, carry = 3, kit = ["sword", "horse_bow", "belt_knife"], hp = 360.0, armour = 0.3},
	aiel = {name = "Aiel", skill_cap = 10, guard = 1.0, dodge_cost = 0.75, safe = 1.2, speed = 1.12, carry = 3, kit = ["aiel_spear", "aiel_knife", "horn_bow"], hp = 300.0, armour = 0.1},
	hunter = {name = "Hunter of the Horn", skill_cap = 9, guard = 0.95, dodge_cost = 0.9, safe = 1.0, speed = 1.04, carry = 3, kit = ["quarterstaff", "longbow", "throwing_knives"], hp = 320.0, armour = 0.2},
}
## hp: how much a body of that calling can take. armour: share of every blow
## turned by what they wear (a Warder's mail, a Hunter's leather, cadin'sor).
static func max_hp(p: Dictionary) -> float:
	return cls(p).hp + 12.0 * stat(p, "endurance")
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
	_expand_setups()
	weapons = _json("res://data/weapons.json")
	moves = weapons["_moves"]
	forms = weapons["_forms"]
	forms.erase("_doc")
	weapons.erase("_moves")
	weapons.erase("_forms")
	# A form is a move like any other once it is in the hand.
	for f in forms:
		moves[f] = forms[f]

## A doorway with a `pool` is a mode, not a place: one hidden activity is made for
## each setup in its pool ("<door>@<setup>": the setup's map, light and enemies with
## the door's rules), and walking up to the doorway picks one (`pick_setup`). Every
## machine makes the same rows, so a server and its players agree on the ids.
static var setups := {}

static func _expand_setups() -> void:
	setups = activities.get("_setups", {})
	activities.erase("_setups")
	for door in activities.keys():
		var d: Dictionary = activities[door]
		if not d.has("pool"):
			continue
		for sid in d.pool:
			var st: Dictionary = setups[sid]
			var v: Dictionary = d.duplicate(true)
			v.erase("pool")
			v.hidden = true
			v.door = door
			v.setup = sid
			if st.get("map", "open") != "open":
				v.map = st.map
			if st.get("night", false):
				v.night = true
			v.name = "%s: %s" % [d.name, st.label]
			v.blurb = st.blurb
			var specials: Array = (st.specials as Array).duplicate()
			for x in d.get("extra_specials", []):
				if not specials.has(x): specials.append(x)
			v.round.specials = specials
			v.round.boss = (st.boss as Dictionary).duplicate()
			activities["%s@%s" % [door, sid]] = v

## Which setup a doorway opens onto this time (an activity id that can be hosted).
static func pick_setup(id: String, rng: RandomNumberGenerator = null) -> String:
	var d: Dictionary = activities.get(id, {})
	if not d.has("pool"):
		return id
	var pool: Array = d.pool
	var k: int = (rng.randi() if rng else randi()) % pool.size()
	return "%s@%s" % [id, pool[k]]

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
## The book a Talent is first shown in, for the spoiler limit (1 unless listed). By
## the user's ruling: books 1 to 6 are open to all; these come later.
const TALENT_BOOK := {travelling = 12, unweaving = 7, reading_residues = 8, cloud_dancing = 8}
static func talent_book(t: String) -> int:
	return int(TALENT_BOOK.get(t, 1))

static func has_talent(p: Dictionary, w: Dictionary) -> bool:
	return w.has("talent") and p.talents.has(w.talent) and talent_book(w.talent) <= int(p.get("book_limit", 14))

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
## "19", or "++2" for the six men's levels above the strongest woman. (The older
## White Tower number in brackets was dropped: the player knows what the main one means.)
static func level_name(level: int) -> String:
	if level <= 0:
		return "++%d" % (level + 6)
	return str(level)

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
	elif fl.has("earth") and p.talents.has("earth_singing") and talent_book("earth_singing") <= int(p.get("book_limit", 14)):
		talent = TUNE.earth_singing
	# Affinity 0.5 is "ordinary": it neither helps nor hurts.
	return strength(p) * vigor(stamina) * (0.5 + aff) * (1.0 + TUNE.mastery_power * mastery_level(p, weave_id)) * talent

## Multiplier applied to a weave's base damage/heal/absorb numbers.
static func scale(p: Dictionary, weave_id: String, stamina := -1.0) -> float:
	# weave_scale: every weave's whole effect, turned down (18 Nov: a starting
	# channeller near rank 30 was mowing down hordes).
	return power(p, weave_id, stamina) / TUNE.ref_power * TUNE.weave_scale

## How readily the weave's Powers answer this character: affinity averaged over its
## flows by how many of each it uses (0.5 is ordinary).
static func weave_affinity(p: Dictionary, weave_id: String) -> float:
	var fl := flows_of(weaves[weave_id], p)
	var total := 0.0; var aff := 0.0
	for e in fl:
		total += fl[e]; aff += fl[e] * p.affinity[e]
	return aff / maxf(total, 1.0)

## Practice and affinity both quicken the weaving: an ordinary affinity weaves at the
## written speed, a strong one in as little as half the time, a weak one 20% slower.
static func form_time(p: Dictionary, weave_id: String) -> float:
	var aff := clampf(1.5 - weave_affinity(p, weave_id), 0.5, 1.2)
	return weaves[weave_id].form * maxf(1.0 - TUNE.mastery_speed * mastery_level(p, weave_id), 0.5) * aff

## Size, reach and the length of what a weave does (burns, stuns, holds) grow with
## the square root of its power: a weave twice as strong is twice the damage over
## about 1.4 times the radius, not four times the effect.
static func reach(p: Dictionary, weave_id: String, stamina := -1.0) -> float:
	return clampf(sqrt(scale(p, weave_id, stamina)), 0.5, 2.2)

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
## What a character works out: weaves for a channeller; for a fighter forms and the
## weapon tree together (their ids never clash), so study, cost and "first you must
## know" work the same for both.
static func lore(p: Dictionary) -> Dictionary:
	if p.get("cls", "channeller") == "channeller":
		return weaves
	if _arms_lore.is_empty():
		_arms_lore = forms.duplicate()
		for w in tree_weapons():
			_arms_lore[w] = weapons[w]
	return _arms_lore

static var _arms_lore := {}

static func knows(p: Dictionary, id: String) -> bool:
	if p.get("cls", "channeller") == "channeller":
		return p.get("weaves", {}).get(id, {}).get("known", false)
	if weapons.has(id) and not forms.has(id):
		return weapon_known(p, id)
	return p.get("forms", {}).get(id, {}).get("known", false) or p.get("forms_owned", []).has(id)

# --- the weapon tree ------------------------------------------------------------------
## Weapons on the tree (not the practice sword, not bare hands).
static func tree_weapons() -> Array:
	return weapons.keys().filter(func(w: String) -> bool: return not w.begins_with("_") and weapons[w].get("tree", true))

## Everything a weapon grows out of, all the way back (needs is any-of).
static func weapon_roots(w: String) -> Dictionary:
	var out := {}
	var todo: Array = weapons[w].get("needs", []).duplicate()
	while not todo.is_empty():
		var n: String = todo.pop_back()
		if out.has(n) or not weapons.has(n):
			continue
		out[n] = true
		todo.append_array(weapons[n].get("needs", []))
	return out

## Known: learned once, carried, or outgrown (something it leads to is yours).
static func weapon_known(p: Dictionary, w: String) -> bool:
	var mine: Array = p.get("weapons_learned", []) + p.get("weapons_owned", []) + p.get("kit", [])
	if mine.has(w):
		return true
	for m in mine:
		if weapons.has(m) and weapon_roots(m).has(w):
			return true
	return false

## Open to work out: not known, a weapon this calling may carry (and, if earned, earned),
## skill enough with its family, and one of what it grows from known.
static func weapon_open(p: Dictionary, w: String) -> bool:
	if weapon_known(p, w) or wield_block(p, w) != "" or not weapons[w].get("tree", true):
		return false
	if weapons[w].get("earned", false) and not earned_ok(p, w):
		return false
	# Skill is grown inside a round (it starts again each one), so it gates only there.
	if skills_count(p) and skill_level(p, weapons[w].family) < int(weapons[w].get("skill", 0)):
		return false
	var needs: Array = weapons[w].get("needs", [])
	return needs.is_empty() or needs.any(func(n: String) -> bool: return weapon_known(p, n))

## A new weapon: learned, and it takes the place of the one of its family that this
## character owned and carried (one sword, not a sword, a sabre and a heron-mark blade).
## Returns the weapon it replaced, or "".
static func gain_weapon(p: Dictionary, w: String) -> String:
	var fam: String = weapons[w].family
	if not p.has("weapons_learned"): p.weapons_learned = []
	if not p.weapons_learned.has(w): p.weapons_learned.append(w)
	var old := ""
	for list_key in ["weapons_owned", "kit"]:
		if not p.has(list_key): p[list_key] = []
		var l: Array = p[list_key]
		var at := -1
		for i in l.size():
			if weapons.has(l[i]) and weapons[l[i]].family == fam and l[i] != w:
				at = i; old = l[i]; break
		if at >= 0:
			l[at] = w
			# (Any second one of the family, from before this rule, goes.)
			for i in range(l.size() - 1, at, -1):
				if weapons.has(l[i]) and weapons[l[i]].family == fam: l.remove_at(i)
		elif not l.has(w) and (list_key == "weapons_owned" or l.size() < int(cls(p).carry)):
			l.append(w)
	return old

## Does weapon skill mean anything for this character now? In a round, yes; for a
## save of the old kind (skill kept between fights), yes; between rounds, no: skill is
## grown afresh each round.
static func skills_count(p: Dictionary) -> bool:
	return p.has("round") or int(p.get("format", 1)) < 2

## A fighter's own weapon of a family, if any.
static func weapon_of(p: Dictionary, fam: String) -> String:
	for w in p.get("weapons_owned", p.get("kit", [])):
		if weapons.has(w) and weapons[w].family == fam:
			return w
	return ""

## [wind-up, recovery] in seconds for this character with this weapon.
static func move_times(p: Dictionary, weapon_id: String, move_id: String) -> Array:
	var m: Dictionary = moves[move_id]
	var q := _quick(p, weapon_id)
	return [m.wind / q, m.recover / q]

## Damage of one blow (or of the missile a missile move launches).
## Gifts for fighters, as Talents are for channellers: one, chosen at creation.
const GIFTS := {
	wolfbrother = {name = "Wolfbrother", blurb = "The wolves' quickness on your feet and their hatred of the Shadowspawn: a tenth faster, a sixth harder on them; the night is not so dark."},
	old_blood = {name = "The Old Blood", blurb = "Memories of battles you never fought: blows land a little harder, and skill with arms comes half again as fast."},
	gamblers_luck = {name = "A gambler's luck", blurb = "The dice tumble your way: one blow in seven that would land on you misses, and one of yours in ten lands twice as hard."},
}

## The Aiel warrior societies: an Aiel joins one at creation, for a small edge of its own.
## Women who take the spear are Far Dareis Mai and only that; men may join any other.
## mods: speed, dodge_cost, regen (stamina), parry (window), draw (bows faster), still
## (share of every hurt taken while standing still), fam {family: blow multiplier}.
const SOCIETIES := {
	far_dareis_mai = {name = "Far Dareis Mai", sub = "Maidens of the Spear", sex = "f", mods = {speed = 1.05, dodge_cost = 0.85},
		blurb = "The Maidens: quick on their feet and quicker to dance the spears. A twentieth faster, and every dodge costs less."},
	shaen_mtaal = {name = "Shae'en M'taal", sub = "Stone Dogs", sex = "m", mods = {still = 0.8},
		blurb = "They tie themselves to the ground and do not retreat: standing your ground, a fifth less from every blow."},
	aethan_dor = {name = "Aethan Dor", sub = "Red Shields", sex = "m", mods = {parry = 1.3},
		blurb = "The ones who keep order: a buckler and a blade always ready. A parry catches blows a third later."},
	shamad_conde = {name = "Sha'mad Conde", sub = "Thunder Walkers", sex = "m", mods = {fam = {spear = 1.1}},
		blurb = "They walk into battle as into a storm: spear blows a tenth harder."},
	sovin_nai = {name = "Sovin Nai", sub = "Knife Hands", sex = "m", mods = {fam = {knife = 1.12, hand = 1.12}},
		blurb = "Close in, where the knife is: knife and hand blows an eighth harder."},
	duadhe_mahdiin = {name = "Duadhe Mahdi'in", sub = "Water Seekers", sex = "m", mods = {regen = 1.2},
		blurb = "They find water where there is none, and run the length of a day: breath comes back a fifth faster."},
	far_aldazar_din = {name = "Far Aldazar Din", sub = "Brothers of the Eagle", sex = "m", mods = {draw = 1.2},
		blurb = "Eyes like the eagle's: the horn bow drawn a fifth faster."},
}

static func society(p: Dictionary) -> Dictionary:
	return SOCIETIES.get(p.get("society", ""), {})

## A society's edge for this character (`def` when they have none, or it gives none).
static func soc(p: Dictionary, key: String, def := 1.0) -> float:
	return float(society(p).get("mods", {}).get(key, def))

## What a Hunter of the Horn may set out with: the arms of where they are from. Taking a
## kit whole gives a start in its weapons (a level in each family).
const KITS := {
	two_rivers = {name = "Two Rivers", weapons = ["longbow", "quarterstaff", "belt_knife"],
		blurb = "A longbow that shoots twice as far as any other, and a quarterstaff."},
	red_hand = {name = "The Band of the Red Hand", weapons = ["crossbow", "ashandarei", "short_sword"],
		blurb = "The Band's crossbow, a soldier's short sword, and a black-hafted spear with a blade like a sword."},
	gleeman = {name = "A gleeman's knives", weapons = ["throwing_knives", "daggers", "quarterstaff"],
		blurb = "Knives from the sleeves, two in the hands, and a walking staff."},
	smith = {name = "A blacksmith's arms", weapons = ["hammer", "throwing_axes", "belt_knife"],
		blurb = "The hammer from the forge, axes to throw and a knife: heavy blows that stagger."},
}

static func has_gift(p: Dictionary, id: String) -> bool:
	return p.get("gifts", []).has(id)

## May this character be offered an earned weapon yet (its `earn`: renown, or a
## skill level in a family)?
static func earned_ok(p: Dictionary, weapon_id: String) -> bool:
	var e: Dictionary = weapons[weapon_id].get("earn", {})
	if e.has("renown") and float(p.get("renown", 0.0)) < float(e.renown):
		return false
	# (Skill only counts where it exists: in a round, or an old-format save.)
	if e.has("skill") and skills_count(p) and skill_level(p, String(e.skill[0])) < int(e.skill[1]):
		return false
	return true

static func blow(p: Dictionary, weapon_id: String, move_id: String, stamina := -1.0) -> float:
	var w: Dictionary = weapons[weapon_id]
	var m: Dictionary = moves[move_id]
	var base: float = w.dmg * m.get("dmg", 1.0)
	var might := 1.0 + TUNE.might_dmg * stat(p, "might")
	if m.get("missile", false):
		var shot: Dictionary = w.get("shot", w.get("throw", {}))
		base = shot.get("dmg", 0.0) * float(m.get("dmg", 1.0))
		if shot.get("crank", false):
			might = 1.0
	# A Power-wrought blade never dulls: it cuts as hard tired as fresh.
	var tired: float = 1.0 if w.get("keen", false) else vigor(stamina)
	var band: float = float(society(p).get("mods", {}).get("fam", {}).get(w.family, 1.0))
	return base * might * (1.0 + TUNE.skill_dmg * skill_level(p, w.family)) * tired * (1.08 if has_gift(p, "old_blood") else 1.0) * band

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
	var d: Dictionary = TUNE.sidestep
	var c := cls(p)
	return {dist = d.dist * (1.0 + 0.02 * stat(p, "quickness")), time = d.time, safe = d.safe * c.safe,
		cost = d.cost * c.dodge_cost * soc(p, "dodge_cost") * maxf(1.0 - TUNE.endur_thrift * stat(p, "endurance"), 0.4)}

static func run_speed(p: Dictionary) -> float:
	# Those who fight with their hands run faster than those who weave.
	return 4.7 * cls(p).speed * soc(p, "speed") * (1.15 if p.get("cls", "channeller") != "channeller" else 1.0) * (1.0 + 0.01 * stat(p, "quickness"))

## Seconds to draw (or span) and loose, at this character's skill.
static func draw_time(p: Dictionary, weapon_id: String) -> float:
	var w: Dictionary = weapons[weapon_id]
	return w.shot.draw / (1.0 + TUNE.skill_speed * 2.0 * skill_level(p, w.family)) / soc(p, "draw")

## The weave tree: what this character could study now, and what is still out of
## reach with the weaves it is waiting on. One weave is studied at a time.
static func study_options(p: Dictionary) -> Array:
	var out := []
	if p.get("cls", "channeller") != "channeller":
		# A fighter works out forms: those whose earlier forms are known and whose
		# weapon they are skilled enough with.
		for id in forms:
			# (Between rounds, where skill is not kept, a form needs a weapon of its kind.)
			var ready: bool = skill_level(p, forms[id].family) >= int(forms[id].get("skill", 0)) if skills_count(p) else weapon_of(p, forms[id].family) != ""
			if not knows(p, id) and missing_for(p, id).is_empty() and ready:
				out.append(id)
		# And the weapons the tree opens next.
		for w in tree_weapons():
			if weapon_open(p, w):
				out.append(w)
		return out
	for id in weaves:
		if p.weaves.get(id, {}).get("known", false) or weaves[id].book > p.book_limit:
			continue
		if missing_for(p, id).is_empty():
			out.append(id)
	return out

static func missing_for(p: Dictionary, id: String) -> Array:
	var out := []
	# A weapon needs any one of what it grows from.
	if weapons.has(id) and not forms.has(id) and p.get("cls", "channeller") != "channeller":
		var needs: Array = weapons[id].get("needs", [])
		return [] if needs.is_empty() or needs.any(func(n: String) -> bool: return weapon_known(p, n)) else needs.duplicate()
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
