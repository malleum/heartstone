class_name Launch
## What the camp hands to the game scene (and command-line flags, for bots and renders).
## Static because a scene change destroys everything else.
static var args := {}
## The last activity's outcome, shown when the player is back in camp.
static var report: Array = []
static var last_name := ""
## The doorway last walked through, so you come back out of it.
static var last_activity := ""

static func cmdline() -> Dictionary:
	var out := {}
	# In the standalone, flags work with or without the `--` separator Godot wants
	# (`dist/heartstone --tour`): nobody remembers the separator.
	var all: Array = Array(OS.get_cmdline_user_args())
	if OS.has_feature("template"):
		all += Array(OS.get_cmdline_args()).filter(func(x: String) -> bool: return x.begins_with("--"))
	for a: String in all:
		var kv := a.trim_prefix("--").split("=")
		out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out

## `--tour[=N]`: a string of short stations, each putting a throwaway character in
## front of one thing to feel, so everything can be tried in minutes instead of
## earned over hours. Nothing is saved. Ordered by what most needs a human hand.
static var tour := 0
const CH := "fireball,hammer_of_air,water_lash,heave_the_ground"
const TOUR := [
	{title = "Weaving, the basics", feel = "Hold left click to form a weave, release to loose it. 1-4 or Q/E to change weave.\nDoes forming feel like gathering something? Is the aim where you expect?", args = {weaves = CH, spawn = "trolloc:3"}},
	{title = "The big weaves", feel = "Lightning (survivors are charged and arc), Blossoms of Fire, Arrows of Fire, the Rolling Ring.\nDo they feel worth their cost? Is the stun and the arc readable?", args = {weaves = "lightning,blossoms_of_fire,arrows_of_fire,rolling_ring", aff = "fire", spawn = "trolloc:8"}},
	{title = "Holding weaves", feel = "Dome of Air, Bonds of Air and the Shield last while held and use up flows (see the HUD).\nG ties the selected one off. Is juggling flows interesting or fiddly?", args = {weaves = "dome_of_air,bonds_of_air,shielding,fireball", aff = "air", tie = "1", spawn = "trolloc:4"}},
	{title = "Gateway and Healing", feel = "A hurt friend stands by you: Healing needs them in reach and shows who it will touch.\nGateway: two doorways, walk through. Is placing the far end clear?", args = {weaves = "healing,gateway,fireball", aff = "spirit", ally = "warder", ally_hp = "45", spawn = "trolloc:3"}},
	{title = "The Eyeless", feel = "Half of what you aim at it misses; Blade of Spirit does not. It cannot be thrown down,\nits wounds fester until Healed, and its Trollocs die with it. Frightening, or just annoying?", args = {weaves = "blade_of_spirit,lightning,fireball,healing", aff = "spirit", ally = "warder", spawn = "myrddraal:1,trolloc:3"}},
	{title = "Warder: sword and forms", feel = "Left click: light blow; hold: heavy. Right click: guard (a late guard parries, then riposte).\nSpace: sidestep, Shift+Space: roll, Ctrl: duck, F: throw. Forms are on the bar.", args = {"class": "warder", "kit": "sword,throwing_knives,belt_knife", "forms": "1", "spawn": "trolloc:2"}},
	{title = "Aiel: spear, javelins, knife", feel = "Faster and lighter. Throw javelins with F and pick them back up.\nDoes the spear's reach feel different from the sword?", args = {"class": "aiel", "kit": "aiel_spear,javelins,aiel_knife", "forms": "1", "spawn": "trolloc:3"}},
	{title = "Hunter: bows", feel = "Hold left click to draw, release to loose. Longbow against crossbow against sling.\nArchers shoot back: duck or sidestep. Is the draw time right?", args = {"class": "hunter", "kit": "longbow,crossbow,sling", "spawn": "trolloc:3,trolloc_archer:2"}},
	{title = "Heavy arms", feel = "Halberd, quarterstaff and hammer against a brute.\nDo the slow weapons feel weighty rather than merely slow?", args = {"class": "warder", "kit": "halberd,quarterstaff,hammer", "forms": "1", "spawn": "trolloc_brute:1,trolloc:2"}},
	{title = "Warder beside a channeller", feel = "Stand by your channeller with guard raised: you take the blows meant for them,\nand you both recover faster near each other. Can you tell it is happening?", args = {"class": "warder", "kit": "sword,horse_bow,belt_knife", "ally": "channeller", "spawn": "trolloc:4"}},
	{title = "The great weaves", feel = "Balefire and the Deathgate against a crowd.\nToo strong? Too cheap? Worth the wait?", args = {weaves = "balefire,deathgate,blossoms_of_fire,lightning", aff = "fire", spawn = "trolloc:10,trolloc_brute:2"}},
	{title = "Tarwin's Gap, the real fight", feel = "The breastwork is solid and stops arrows; Trollocs come round through the gaps.\nPlay as long as you like.", args = {activity = "tarwins_gap_watch", weaves = CH + ",lightning,dome_of_air,healing", ally = "warder"}},
	{title = "The wagon ring", feel = "They come from every side. Two bots lost this: is it too hard with a friend at your back?", args = {activity = "wagon_ring", weaves = CH + ",lightning,dome_of_air,bonds_of_air", ally = "warder"}},
]

static func station() -> Dictionary:
	var a: Dictionary = {name = "Tour", flows = "10", activity = "camp_training", tour = "1"}
	a.merge(TOUR[tour].args, true)
	if cmdline().has("auto"):
		a.auto = "1"   # a bot walks the tour, for checking the stations run
	return a
