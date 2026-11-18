class_name Launch
## What the camp hands to the game scene (and command-line flags, for bots and renders).
## Static because a scene change destroys everything else.
static var args := {}
## The last activity's outcome, shown when the player is back in camp.
static var report: Array = []
static var last_name := ""
## The doorway last walked through, so you come back out of it.
static var last_activity := ""
static var return_preview := false   # the camp is being built as the far side of a gateway home
static var left_camp := 0   # ticks when a doorway was walked through (for --timing)
## Every game goes through the one server (docs/SERVER.md). `--server=host:port`
## points elsewhere (the tests run their own on this machine).
const SERVER := "joshammer.com:24690"
static func server() -> String:
	return cmdline().get("server", SERVER)

## Started by a render, a test or a bot (any of these flags): characters it makes or
## changes go to a folder of their own, never the player's.
const DEV_FLAGS := ["auto", "ghost", "who", "name", "activity", "new", "show", "stroll", "timing", "offline", "tour", "join", "class", "weaves", "only", "spawn", "homewalk", "walkgate"]
static func dev() -> bool:
	var c := cmdline()
	for f in DEV_FLAGS:
		if c.has(f):
			return true
	return false

static func use_profile_dir() -> void:
	if dev() and Profile.dir == "user://profiles":
		Profile.dir = "user://dev_profiles"

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
	{title = "Weaving: the four starters", feel = "Hold left click to weave (the ring fills, each Power moves differently); let go and it flies where you are looking.\nHeave the Ground throws up a ridge of rock. Lash of Water hauls them in and soaks them. Hammer of Air throws them back.", args = {weaves = CH, spawn = "trolloc:4"}},
	{title = "The big weaves", feel = "Lightning (hits soaked Trollocs harder, and arcs). Arrows of Fire: fast darts that go through two bodies.\nBlossoms of Fire: a pillar, then a wide slow wheel of fire: stay out of it. Rolling Ring: a wedge, the way you face.", args = {weaves = "lightning,arrows_of_fire,blossoms_of_fire,rolling_ring,water_lash", aff = "fire", spawn = "trolloc:9"}},
	{title = "Holding weaves", feel = "Dome of Air, Bonds of Air and the Shield last while held and use up flows (see the HUD).\nTie off the chosen one with the key shown at the start. Is juggling flows interesting or fiddly?", args = {weaves = "dome_of_air,bonds_of_air,shielding,fireball", aff = "air", tie = "1", spawn = "trolloc:4"}},
	{title = "Gateway and Healing", feel = "A hurt friend stands by you: Healing needs them in reach and shows who it will touch.\nGateway (you are strong enough here): aim where the far door should open, weave, walk through.", args = {weaves = "gateway,healing,fireball", aff = "spirit", tie = "1", ally = "warder", ally_hp = "45", spawn = "trolloc:3"}},
	{title = "The Eyeless", feel = "It circles, then lunges along the red line (roll off the line, or parry it), or is gone and comes out behind you.\nHalf of what you throw misses; Blade of Spirit does not. Its wounds fester until Healed.", args = {weaves = "blade_of_spirit,lightning,fireball,healing", aff = "spirit", ally = "warder", spawn = "myrddraal:1,trolloc:3"}},
	{title = "Darkhounds", feel = "They spring along the red line from a long way off and the bite festers. Steel does half its work on them\nand they mend when left alone: weaves kill them. Do they read as hounds? Is the spring fair?", args = {weaves = "fireball,arrows_of_fire,bonds_of_air,lightning", aff = "fire", ally = "warder", spawn = "darkhound:3@16"}},
	{title = "A Draghkar", feel = "It flies in out of reach, lands and sings (the rings): hit it with anything before the song ends, or get out of its sight.\nLet it finish once to feel what happens: you walk to it and cannot act, it feeds, then it lets go.", args = {weaves = "fireball,hammer_of_air,lightning", aff = "fire", spawn = "draghkar:1@28"}},
	{title = "A Dreadlord", feel = "It gathers the Power (you can see it) and throws fire that bursts; it marks the ground red, and lightning falls there.\nShield from the Source cuts it off for as long as you hold the weave.", args = {weaves = "shielding,fireball,dome_of_air,lightning", aff = "spirit", spawn = "dreadlord:1@24,trolloc:2"}},
	{title = "Tel'aran'rhiod: a duel in the dream", feel = "The dream does what you will, while your Will lasts (the pale bar). The keys are listed on the right:\nstep behind them, step away, step where you look; throw a spear; chain them; turn the ground; raise a wall.\nDeny, pressed just as something reaches you, unmakes it and shakes whoever made it. Chained? Step away.", args = {"activity": "dream_spar", "class": "warder", "kit": "sword,throwing_knives,belt_knife", "forms": "1", "foe": "warder"}},
	{title = "Warder: sword, parry, forms", feel = "Left click: cut; hold: heavy. Right click just before a blow lands: parry. At the last instant it is perfect and they reel.\nThe wedge on the ground is where their blow will fall. Space: roll. Forms are on the bar: each should look its own.", args = {"class": "warder", "kit": "sword,throwing_knives,belt_knife", "forms": "1", "spawn": "trolloc:3"}},
	{title = "Aiel: spear, javelins, knife", feel = "The spear is held point-forward for its thrusts now. Javelins: thrown ones stand where they land; walk over them.\nFlurry (knife form) is four quick wounds. Dance of Spears is three thrusts.", args = {"class": "aiel", "kit": "aiel_spear,javelins,aiel_knife", "forms": "1", "spawn": "trolloc:3"}},
	{title = "Hunter: longbow and sling", feel = "Hold to draw: the arm comes back and the ring fills. A half draw falls short and barely bites; a full one flies flat.\nThe sling is quick and light and staggers. Archers shoot back: duck or roll.", args = {"class": "hunter", "kit": "longbow,sling,quarterstaff", "forms": "1", "spawn": "trolloc:3,trolloc_archer:2"}},
	{title = "Crossbow, horn bow, horse bow", feel = "The crossbow has no half shot: one click, one hard flat bolt, then it spans itself again (the ring is the crank).\nCompare the two short bows' draw against the longbow's.", args = {"class": "hunter", "kit": "crossbow,horn_bow,horse_bow", "spawn": "trolloc:4,trolloc_brute:1"}},
	{title = "Heavy arms", feel = "Halberd, quarterstaff and hammer against a bandleader. Each shoves and staggers differently:\nthe hammer reels them, the halberd throws them back, the staff trips them.", args = {"class": "warder", "kit": "halberd,quarterstaff,hammer", "forms": "1", "spawn": "trolloc_brute:1,trolloc:2"}},
	{title = "Warder beside a channeller", feel = "Parry beside your channeller and you take the blow meant for them;\nyou both recover faster near each other. Can you tell it is happening?", args = {"class": "warder", "kit": "sword,horse_bow,belt_knife", "ally": "channeller", "spawn": "trolloc:4"}},
	{title = "The great weaves", feel = "Balefire and the Deathgate against a crowd. They take a long time to weave: is the wait worth it?", args = {weaves = "balefire,deathgate,blossoms_of_fire,lightning", aff = "fire", spawn = "trolloc:10,trolloc_brute:2"}},
	{title = "Tarwin's Gap, the real fight", feel = "The breastwork is solid and stops arrows; Trollocs come round through the gaps.\nPlay as long as you like.", args = {activity = "tarwins_gap_watch", weaves = CH + ",lightning,dome_of_air,healing", ally = "warder"}},
	{title = "The wagon ring", feel = "They come from every side. Two bots lost this: is it too hard with a friend at your back?", args = {activity = "wagon_ring", weaves = CH + ",lightning,dome_of_air,bonds_of_air", ally = "warder"}},
]

static func station() -> Dictionary:
	var a: Dictionary = {name = "Tour", flows = "10", strength = "8", activity = "camp_training", tour = "1"}
	a.merge(TOUR[tour].args, true)
	if cmdline().has("auto"):
		a.auto = "1"   # a bot walks the tour, for checking the stations run
	return a
