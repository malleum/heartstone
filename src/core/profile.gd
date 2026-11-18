class_name Profile
extends RefCounted
## The persistent character: one per player, saved as JSON, carried through every
## activity. A profile is a plain Dictionary so it can go over the network and to disk
## unchanged. Creation choices are fixed; everything under "growth" only ever goes up.

const VERSION := 1
## Tests point this elsewhere so they never litter the player's character list.
static var dir := "user://profiles"
## The save format. Characters made before rounds (format 1, no stamp) are not
## carried over: the user asked for them to be cleared (17 Nov).
const FORMAT := 2
const CREATION_POINTS := 20
const TALENTS: Array[String] = ["healing", "travelling", "cloud_dancing", "delving", "earth_singing", "illusion", "reading_residues", "reading_weaves", "unweaving", "listening_to_the_wind", "dreaming", "foretelling"]

## opts: name, power (saidin|saidar), potential_pts, affinity_pts {element: pts},
## talents [], origin, look {}, book_limit. Points: 20 shared between potential,
## affinities and Talents (4 each), so a prodigy has fewer gifts.
static func create(opts: Dictionary) -> Dictionary:
	if opts.get("cls", "channeller") != "channeller":
		return create_fighter(opts)
	var power: String = opts.get("power", "saidar")
	# Canon lean, not rule: men Earth/Fire, women Air/Water, Spirit even.
	var lean := {fire = 0.3, earth = 0.3, water = 0.3, air = 0.3, spirit = 0.35}
	for e in (["earth", "fire"] if power == "saidin" else ["air", "water"]):
		lean[e] = 0.45
	var talents: Array = opts.get("talents", [])
	var pot_pts: int = opts.get("potential_pts", 6)
	var aff_pts: Dictionary = opts.get("affinity_pts", {})
	var spent := pot_pts + talents.size() * 4.0
	for e in aff_pts:
		spent += affinity_cost(power, e, int(aff_pts[e]))
	assert(spent <= CREATION_POINTS, "creation points overspent")
	var affinity := {}; var aptitude := {}
	for e in Rules.ELEMENTS:
		var a: float = lean[e] + 0.06 * int(aff_pts.get(e, 0))
		affinity[e] = minf(a, 0.9)
		# Aptitude is the ceiling practice can reach in that Power.
		aptitude[e] = minf(a + 0.35, 1.0)
	var potential := Rules.strength_of(potential_level(power, pot_pts))
	var p := {
		version = VERSION, name = opts.get("name", "Unnamed"), cls = "channeller",
		power = power, potential = potential, strength = start_strength(potential),
		affinity = affinity, aptitude = aptitude, talents = talents,
		origin = opts.get("origin", "two_rivers"), look = opts.get("look", {}),
		book_limit = opts.get("book_limit", 14),
		# Growth.
		channelled = 0.0, renown = 0.0, seconds = 0.0,
		weaves = {}, seen = [], done = {},
		stats = {might = 0, quickness = 0, endurance = 0}, skills = {}, kit = [],
		style = opts.get("style", {}),
	}
	# A channeller may carry one weapon and train it a little (Asha'man drill the sword).
	for w in opts.get("kit", []):
		if p.kit.size() < int(Rules.CLASSES.channeller.carry) and Rules.wield_block(p, w) == "":
			p.kit.append(w)
	# You begin knowing the simplest weave of the Power that answers you best; a tie
	# is settled by chance, fixed by the name so it is the same on every machine.
	var best: Array = []
	for e in Rules.ELEMENTS:
		if best.is_empty() or affinity[e] > affinity[best[0]] + 0.001:
			best = [e]
		elif absf(affinity[e] - affinity[best[0]]) <= 0.001:
			best.append(e)
	p.starter = STARTERS[best[hash(p.name) % best.size()]]
	p.weaves[p.starter] = {known = true, xp = 0.0}
	return p

## A character who does not channel: Warder, Aiel, Hunter of the Horn. opts: name,
## cls, sex (f|m), stat_pts {might, quickness, endurance} (0..8 each), skill_pts
## {family: 0..6}, kit [weapon ids], origin, look. The same twenty points.
static func create_fighter(opts: Dictionary) -> Dictionary:
	Rules.load_data()
	var c: String = opts.cls
	var sex: String = opts.get("sex", "m")
	var stats := {might = 0, quickness = 0, endurance = 0}
	var spent := 0
	for s in stats:
		stats[s] = clampi(int(opts.get("stat_pts", {}).get(s, 0)), 0, 8)
		spent += stats[s]
	var skills := {}
	for f in opts.get("skill_pts", {}):
		var n := clampi(int(opts.skill_pts[f]), 0, 6)
		spent += n
		# Points buy a starting level outright.
		skills[f] = float(n * n) * Rules.TUNE.skill_xp
	assert(spent <= CREATION_POINTS, "creation points overspent")
	var p := {
		version = VERSION, name = opts.get("name", "Unnamed"), cls = c, sex = sex,
		# A fighter touches no Power. These stay so that every profile has one shape.
		power = "saidar" if sex == "f" else "saidin", potential = 0.0, strength = 0.0,
		affinity = {}, aptitude = {}, talents = [],
		origin = opts.get("origin", "two_rivers"), look = opts.get("look", {}),
		book_limit = opts.get("book_limit", 14),
		channelled = 0.0, renown = 0.0, seconds = 0.0,
		weaves = {}, seen = [], done = {},
		stats = stats, skills = skills, kit = [], forms = {}, style = opts.get("style", {}),
	}
	for e in Rules.ELEMENTS:
		p.affinity[e] = 0.0; p.aptitude[e] = 0.0
	var want: Array = opts.get("kit", Rules.CLASSES[c].kit)
	for w in want:
		if p.kit.size() < int(Rules.CLASSES[c].carry) and Rules.wield_block(p, w) == "" and not Rules.weapons[w].get("earned", false):
			p.kit.append(w)
	if p.kit.is_empty():
		p.kit = ["belt_knife"]
	return p

## The simplest single-Power weave of each Power.
const STARTERS := {fire = "fireball", air = "hammer_of_air", earth = "heave_the_ground", water = "water_lash", spirit = "blade_of_spirit"}

## The Powers your half of the Source leans to (saidin Earth and Fire, saidar Air and
## Water) come easily: their first three points cost half.
static func affinity_cost(power: String, element: String, pts: int) -> float:
	var own: bool = element in (["earth", "fire"] if power == "saidin" else ["air", "water"])
	return (minf(pts, 3) * 0.5 + maxf(pts - 3, 0)) if own else float(pts)

## Potential bought with creation points, as a Companion level: 40(28) for nothing,
## 1(+12) for 14 points. Only saidin goes further, to ++1 at 16 points: the weakest
## man and woman are equals, but men have six levels above the strongest woman.
static func potential_level(power: String, pts: int) -> int:
	return maxi(40 - roundi(2.8 * pts), -5 if power == "saidin" else 1)

static func max_potential_pts(power: String) -> int:
	return 16 if power == "saidin" else 14

static func path(name: String) -> String:
	return "%s/%s.json" % [dir, name.to_lower().validate_filename()]

static func save(p: Dictionary) -> void:
	# The file says what format it is; characters made by make() say so themselves.
	var out := p.duplicate()
	out.format = p.get("format", FORMAT)
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(p.name), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))

static func load_profile(name: String) -> Dictionary:
	if not FileAccess.file_exists(path(name)):
		return {}
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path(name)))
	_migrate(p)
	return p

## Whether a Dictionary that arrived over the network is shaped like a character.
## A host runs the rules on other people's profiles, so it checks before trusting.
static func valid(p: Dictionary) -> bool:
	for k in ["name", "power", "potential", "strength", "channelled", "renown", "seconds", "book_limit"]:
		if not p.has(k) or (k in ["name", "power"]) != (p[k] is String):
			return false
		if not (p[k] is String or p[k] is float or p[k] is int):
			return false
	for k in ["affinity", "aptitude", "weaves", "done"]:
		if not (p.get(k) is Dictionary):
			return false
	if not (p.get("talents") is Array and p.get("seen") is Array):
		return false
	for e in Rules.ELEMENTS:
		if not (p.affinity.get(e) is float and p.aptitude.get(e) is float):
			return false
	for id in p.weaves:
		if not (p.weaves[id] is Dictionary):
			return false
	for k in [["stats", TYPE_DICTIONARY], ["skills", TYPE_DICTIONARY], ["kit", TYPE_ARRAY]]:
		if p.has(k[0]) and typeof(p[k[0]]) != k[1]:
			return false
	for w in p.get("kit", []):
		if not (w is String and Rules.weapons.has(w)):
			return false
	if p.has("style") and not (p.style is Dictionary and p.style.size() < 12):
		return false
	return p.name.length() > 0 and p.name.length() <= 40 and p.power in ["saidin", "saidar"] and Rules.CLASSES.has(p.get("cls", "channeller"))

## Channellers are strong before they are trained (Nynaeve): everyone starts at
## most TUNE.start_gap levels below their potential.
static func start_strength(potential: float) -> float:
	return Rules.strength_of(mini(Rules.level_of(potential) + int(Rules.TUNE.start_gap), 72))

## Saves from before a rules change: lift strength to the new starting floor and
## follow weaves that were renamed or removed.
static func _migrate(p: Dictionary) -> void:
	Rules.load_data()
	# Characters from before there were arms are channellers carrying nothing.
	for k in [["cls", "channeller"], ["stats", {might = 0, quickness = 0, endurance = 0}], ["skills", {}], ["kit", []], ["forms", {}], ["techniques", []]]:
		if not p.has(k[0]):
			p[k[0]] = k[1]
	p.kit = p.kit.filter(func(w: String) -> bool: return Rules.weapons.has(w))
	if p.cls != "channeller":
		return
	p.strength = maxf(p.strength, start_strength(p.potential))
	if p.weaves.has("shield_of_air"):
		p.weaves["dome_of_air"] = p.weaves["shield_of_air"]
	for id in p.weaves.keys():
		if not Rules.weaves.has(id):
			p.weaves.erase(id)


## Delete every saved character from before the current format. Returns how many.
static func purge_old() -> int:
	if not DirAccess.dir_exists_absolute(dir):
		return 0
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dir + "/" + f))
		if not (d is Dictionary) or int(d.get("format", 1)) < FORMAT:
			DirAccess.remove_absolute(dir + "/" + f)
			n += 1
	return n

static func current(p: Dictionary) -> bool:
	return int(p.get("format", 1)) >= FORMAT

# --- characters for rounds (format 2; the user's rules of 17 Nov) -------------------
# Strength is rolled each round, so a character is what they can take into one:
# affinity points, Talents, weaves and arms they own, and the loadout chosen from
# them before each game. Nothing here is raw strength or a fighter's body beyond
# the couple of creation points.

const AFF_OWN_MAX := 9       # affinity points a character can own
const AFF_BASE := 5          # affinity room with both Talent slots filled
const TALENT_SLOTS := 2
const WEAVE_SLOTS := 3       # weaves beyond the starting one, per game
const WEAPON_SLOTS := 3
const FORM_SLOTS := 3
const FIGHTER_POINTS := 6    # weapon 1, form 2, stat 1 (at most 2 in stats)

## The starting spread: two points in each of your half's Powers, one in Spirit.
static func default_aff(power: String) -> Dictionary:
	var out := {fire = 0, earth = 0, water = 0, air = 0, spirit = 1}
	for e in (["earth", "fire"] if power == "saidin" else ["air", "water"]):
		out[e] = 2
	return out

## Moving points: every point added somewhere costs two taken from elsewhere.
## Points left over after a trade are what remains to place (negative: too many added).
static func trade_left(before: Dictionary, after: Dictionary) -> int:
	var removed := 0; var added := 0
	for k in after:
		var d := int(after[k]) - int(before.get(k, 0))
		if d > 0: added += d
		else: removed -= d
	for k in before:
		if not after.has(k): removed += int(before[k])
	return removed - 2 * added

## Affinity points a character may have, by the Talents they have selected (kept
## from one fight to the next): 9 with none, 7 with one, 5 with two.
static func aff_cap(p: Dictionary, talents := -1) -> int:
	var n: int = p.get("talents", []).size() if talents < 0 else talents
	return mini(AFF_OWN_MAX, AFF_BASE + 2 * (TALENT_SLOTS - n))

static func aff_total(p: Dictionary) -> int:
	var n := 0
	for e in Rules.ELEMENTS: n += int(p.get("aff_owned", {}).get(e, 0))
	return n

## The rules read p.affinity (0..1 per Power); work it out from the points taken.
static func apply_affinity(p: Dictionary) -> void:
	# What you own is what you fight with (the user, 17 Nov: no separate "take").
	if p.has("aff_owned"):
		p.aff_pts = p.aff_owned.duplicate()
	var lean := {fire = 0.3, earth = 0.3, water = 0.3, air = 0.3, spirit = 0.35}
	for e in (["earth", "fire"] if p.power == "saidin" else ["air", "water"]):
		lean[e] = 0.45
	for e in Rules.ELEMENTS:
		var a: float = lean[e] + Rules.TUNE.aff_point * int(p.get("aff_pts", {}).get(e, 0))
		p.affinity[e] = minf(a, Rules.TUNE.aff_cap)
		p.aptitude[e] = p.affinity[e]

## The weave you were born knowing: the simplest of the Power that answers you
## best, a tie settled by the name so it is the same on every machine.
static func pick_starter(p: Dictionary) -> String:
	var best: Array = []
	for e in Rules.ELEMENTS:
		var v := int(p.aff_pts.get(e, 0))
		if best.is_empty() or v > int(p.aff_pts.get(best[0], 0)):
			best = [e]
		elif v == int(p.aff_pts.get(best[0], 0)):
			best.append(e)
	return STARTERS[best[hash(p.name) % best.size()]]

## A new character for rounds. Channellers: aff_pts {element: n} (a trade from the
## default spread), or talent: "<id>" to give up all five points for that Talent.
## Fighters: kit [weapons], forms [forms], stats {might, quickness, endurance}.
static func make(opts: Dictionary) -> Dictionary:
	Rules.load_data()
	var p: Dictionary
	if opts.get("cls", "channeller") == "channeller":
		var power: String = opts.get("power", "saidar")
		p = create({name = opts.name, power = power, potential_pts = 6, affinity_pts = {}, origin = opts.get("origin", "two_rivers"), look = opts.get("look", {}), style = opts.get("style", {})})
		var aff: Dictionary = opts.get("aff_pts", default_aff(power)).duplicate()
		p.talents = []
		if opts.get("talent", "") != "":
			# The one-time trade: no affinity at all, one Talent kept for good.
			for e in aff: aff[e] = 0
			p.talents = [opts.talent]
		p.aff_owned = aff.duplicate()
		p.aff_pts = aff.duplicate()
		p.talents_owned = p.talents.duplicate()
		apply_affinity(p)
		p.weaves = {}
		p.starter = pick_starter(p)
		p.weaves[p.starter] = {known = true, xp = 0.0}
		p.weaves_owned = []
		p.techniques = ["tie_off"]
	else:
		var stats: Dictionary = opts.get("stats", {})
		p = create_fighter({name = opts.name, cls = opts.cls, sex = opts.get("sex", "m"), stat_pts = stats, skill_pts = {}, kit = opts.get("kit", []), origin = opts.get("origin", "two_rivers"), look = opts.get("look", {}), style = opts.get("style", {})})
		p.forms = {}
		for f in opts.get("forms", []):
			p.forms[f] = {known = true}
		p.weapons_owned = p.kit.duplicate()
		p.forms_owned = p.forms.keys()
	p.unlocks_owed = 0
	p.format = FORMAT
	return p

## What a win can give this character: up to n choices, never strength.
static func unlock_offers(p: Dictionary, n: int, rng: RandomNumberGenerator) -> Array:
	var pool := []
	if p.get("cls", "channeller") == "channeller":
		for t in TALENTS:
			if not p.get("talents_owned", []).has(t):
				pool.append({kind = "talent", id = t, name = "The Talent for %s" % t.capitalize().to_lower()})
		for w in Rules.weaves:
			if not p.weaves.has(w) and not p.get("weaves_owned", []).has(w) and Rules.weaves[w].get("book", 1) <= p.book_limit and Rules.weaves[w].get("learnable", true):
				pool.append({kind = "weave", id = w, name = Rules.weaves[w].name})
		var owned := 0
		for e in p.get("aff_owned", {}):
			owned += int(p.aff_owned[e])
		if owned < aff_cap(p):
			for e in Rules.ELEMENTS:
				pool.append({kind = "affinity", id = e, name = "+1 affinity in %s" % e.capitalize()})
	else:
		var fams := {}
		for w in p.get("weapons_owned", p.kit):
			fams[Rules.weapons[w].family] = true
		for w in Rules.weapons:
			if not p.get("weapons_owned", p.kit).has(w) and Rules.wield_block(p, w) == "":
				pool.append({kind = "weapon", id = w, name = Rules.weapons[w].name})
		for f in Rules.forms:
			if fams.has(Rules.forms[f].family) and not p.get("forms_owned", []).has(f):
				pool.append({kind = "form", id = f, name = Rules.forms[f].name})
	var out := []
	while not pool.is_empty() and out.size() < n:
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out

## Keep an unlock: it joins what the character owns (taken into games by loadout).
static func take_unlock(p: Dictionary, u: Dictionary) -> void:
	match u.kind:
		"talent": p.talents_owned.append(u.id)
		"weave": p.weaves_owned.append(u.id)
		"affinity":
			p.aff_owned[u.id] = int(p.aff_owned.get(u.id, 0)) + 1
		"weapon": p.weapons_owned.append(u.id)
		"form": p.forms_owned.append(u.id)
	p.unlocks_owed = maxi(int(p.get("unlocks_owed", 0)) - 1, 0)
