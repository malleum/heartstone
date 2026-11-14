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
	var power: String = opts.get("power", "saidar")
	# Canon lean, not rule: men Earth/Fire, women Air/Water, Spirit even.
	var lean := {fire = 0.3, earth = 0.3, water = 0.3, air = 0.3, spirit = 0.35}
	for e in (["earth", "fire"] if power == "saidin" else ["air", "water"]):
		lean[e] = 0.45
	var talents: Array = opts.get("talents", [])
	var pot_pts: int = opts.get("potential_pts", 6)
	var aff_pts: Dictionary = opts.get("affinity_pts", {})
	var spent := pot_pts + talents.size() * 4
	for e in aff_pts:
		spent += int(aff_pts[e])
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
		power = power, potential = potential, strength = potential * 0.2 + 4.0,
		affinity = affinity, aptitude = aptitude, talents = talents,
		origin = opts.get("origin", "two_rivers"), look = opts.get("look", {}),
		book_limit = opts.get("book_limit", 14),
		# Growth.
		channelled = 0.0, renown = 0.0, seconds = 0.0,
		weaves = {fireball = {known = true, xp = 0.0}}, seen = [], done = {},
	}
	return p

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
	return p
