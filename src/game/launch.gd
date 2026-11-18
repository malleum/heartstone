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
	{title = "A round, sped up", feel = "You start six levels in with choices waiting: Tab opens the weave chart: click a weave you know to grow it, an open one to learn it. Waves come four times as fast. G on an attack weave keeps it going by itself.\nYour fire hurts your Warder as much as a Trolloc. Go down and he comes to stand over you; half a body more while down and you are dead (back next wave, weaker).", args = {activity = "tarwins_gap_watch", weaves = CH + ",lightning,dome_of_air,healing", ally = "warder", roll = "1", levels = "6", fast = "1"}},
	{title = "Weaving: the four starters", feel = "Hold left click to weave (the ring fills; a Power you are strong in weaves faster), let go and it flies where you look.\nHeave the Ground throws up rock. Lash of Water hauls them in and soaks them. Hammer of Air throws them back.", args = {weaves = CH, spawn = "trolloc:4"}},
	{title = "Gateways", feel = "Weave a gateway where you look: each side is a window onto the other. Walk through. Aim at the ground close by for a hole at your feet, high into the air for one in the sky.\nHammer a Trolloc into it and it dies; throw fire into it and the fire comes out the far side; opening on something cuts it.", args = {weaves = "gateway,hammer_of_air,fireball", aff = "spirit", tie = "1", spawn = "trolloc:5"}},
	{title = "The big weaves", feel = "Lightning (hits soaked Trollocs harder, and arcs). Arrows of Fire: fast darts through two bodies. Blossoms of Fire: a pillar, then a wheel of fire: stay out of it.\nRolling Ring: a wedge the way you face. Stronger weavers make all of these bigger and longer-lasting.", args = {weaves = "lightning,arrows_of_fire,blossoms_of_fire,rolling_ring,water_lash", aff = "fire", spawn = "trolloc:9"}},
	{title = "Balefire", feel = "Let a Trolloc wound your Warder, then balefire it: what it did in its last moments never happened, and the wound is gone.\nBalefire also kills outright: nobody comes back from it.", args = {weaves = "balefire,fireball,healing", aff = "fire", ally = "warder", spawn = "trolloc:6"}},
	{title = "Holding weaves", feel = "Dome of Air, Bonds of Air and the Shield last while held and use up flows (the dots top left).\nTie off the chosen one (G). Is juggling flows interesting or fiddly?", args = {weaves = "dome_of_air,bonds_of_air,shielding,fireball", aff = "air", tie = "1", spawn = "trolloc:4"}},
	{title = "Healing", feel = "A hurt friend stands by you: Healing needs them in reach and shows who it will touch. You cannot Heal yourself.", args = {weaves = "healing,fireball", aff = "spirit", ally = "warder", ally_hp = "45", spawn = "trolloc:3"}},
	{title = "The Eyeless", feel = "It circles, then lunges along the red line (roll off the line, or parry it), or is gone and comes out behind you.\nHalf of what you throw misses; Blade of Spirit does not. Its wounds fester until Healed.", args = {weaves = "blade_of_spirit,lightning,fireball,healing", aff = "spirit", ally = "warder", spawn = "myrddraal:1,trolloc:3"}},
	{title = "Darkhounds", feel = "They spring along the red line from a long way off and the bite festers. Steel does half its work on them\nand they mend when left alone: weaves kill them.", args = {weaves = "fireball,arrows_of_fire,bonds_of_air,lightning", aff = "fire", ally = "warder", spawn = "darkhound:3@16"}},
	{title = "A Draghkar", feel = "It flies in, lands and sings (the rings): hit it with anything before the song ends, or get out of its sight.\nLet it finish once to feel what happens.", args = {weaves = "fireball,hammer_of_air,lightning", aff = "fire", spawn = "draghkar:1@28"}},
	{title = "A Dreadlord", feel = "It gathers the Power and throws fire that bursts; it marks the ground red, and lightning falls there.\nShield from the Source cuts it off for as long as you hold the weave.", args = {weaves = "shielding,fireball,dome_of_air,lightning", aff = "spirit", spawn = "dreadlord:1@24,trolloc:2"}},
	{title = "Tel'aran'rhiod: a duel in the dream", feel = "The dream does what you will, while your Will lasts (the pale bar). The keys are listed on the right:\nstep behind them, step away, step where you look; throw a spear; chain them; turn the ground; raise a wall.\nDeny, pressed just as something reaches you, unmakes it and shakes whoever made it. Chained? Step away.", args = {"activity": "dream_spar", "class": "warder", "kit": "sword,throwing_knives,belt_knife", "forms": "1", "foe": "warder"}},
	{title = "Warder: sword, parry, forms", feel = "Left click: cut; hold: heavy. Right click just before a blow lands: parry. At the last instant it is perfect and they reel.\nThe wedge on the ground is where their blow will fall. Space: roll. Forms are on the bar.", args = {"class": "warder", "kit": "sword,throwing_knives,belt_knife", "forms": "1", "spawn": "trolloc:3"}},
	{title = "Aiel: spear, javelins, knife", feel = "Javelins stand where they land; walk over them to gather them.\nFlurry (knife form) is four quick wounds. Dance of Spears is three thrusts.", args = {"class": "aiel", "kit": "aiel_spear,javelins,aiel_knife", "forms": "1", "spawn": "trolloc:3"}},
	{title = "Hunter: longbow and sling", feel = "Hold to draw (you turn to your aim); let go and it flies at once, with a trail behind it. A half draw falls short.\nThe sling is quick and staggers. Archers shoot back: duck or roll.", args = {"class": "hunter", "kit": "longbow,sling,quarterstaff", "forms": "1", "spawn": "trolloc:3,trolloc_archer:2"}},
	{title = "Crossbow, horn bow, horse bow", feel = "The crossbow has no half shot: one click, one hard bolt, then it spans itself again (the ring is the crank).\nCompare the two short bows' draw against the longbow's.", args = {"class": "hunter", "kit": "crossbow,horn_bow,horse_bow", "spawn": "trolloc:4,trolloc_brute:1"}},
	{title = "Heavy arms", feel = "Halberd, quarterstaff and hammer against a bandleader. The hammer reels them, the halberd throws them back, the staff trips them.", args = {"class": "warder", "kit": "halberd,quarterstaff,hammer", "forms": "1", "spawn": "trolloc_brute:1,trolloc:2"}},
	{title = "Warder beside a channeller", feel = "Parry beside your channeller and you take the blow meant for them; you both recover faster near each other.\nIf they go down, stand over them to bring them back.", args = {"class": "warder", "kit": "sword,horse_bow,belt_knife", "ally": "channeller", "spawn": "trolloc:4"}},
	{title = "The great weaves", feel = "Balefire and the Deathgate against a crowd. They take a long time to weave: is the wait worth it?", args = {weaves = "balefire,deathgate,blossoms_of_fire,lightning", aff = "fire", spawn = "trolloc:10,trolloc_brute:2"}},
	{title = "The wagon ring, sped up", feel = "They come from every side, with archers and an Eyeless. Space by a wagon vaults it. Waves four times as fast.", args = {activity = "wagon_ring", weaves = CH + ",lightning,dome_of_air,bonds_of_air", ally = "warder", roll = "1", levels = "4", fast = "1"}},
	{title = "The endless night, sped up", feel = "Waves without end at Tarwin's Gap by night, four times as fast, eight levels in.", args = {activity = "endless", weaves = CH + ",lightning,dome_of_air,healing", ally = "warder", roll = "1", levels = "8", fast = "1"}},
]

static func station() -> Dictionary:
	var a: Dictionary = {name = "Tour", flows = "10", strength = "8", activity = "camp_training", tour = "1"}
	a.merge(TOUR[tour].args, true)
	# A round station rolls its strength like any round.
	if a.has("roll"):
		a.erase("strength"); a.erase("flows")
	if cmdline().has("auto"):
		a.auto = "1"   # a bot walks the tour, for checking the stations run
	return a
