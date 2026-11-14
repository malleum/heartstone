class_name Profile
extends RefCounted
## The persistent character: one per player, saved as JSON, carried through every
## activity. A profile is a plain Dictionary so it can go over the network and to disk
## unchanged. Creation choices are fixed; everything under "growth" only ever goes up.

const VERSION := 1
## Tests point this elsewhere so they never litter the player's character list.
static var dir := "user://profiles"
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
		stats = stats, skills = skills, kit = [], forms = {},
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
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(path(p.name), FileAccess.WRITE)
	f.store_string(JSON.stringify(p, "  "))

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
	for k in [["cls", "channeller"], ["stats", {might = 0, quickness = 0, endurance = 0}], ["skills", {}], ["kit", []], ["forms", {}]]:
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
