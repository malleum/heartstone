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

## `--tour[=N]`: numbered stations, each a throwaway character in front of one thing,
## so everything can be tried in a sitting instead of earned over hours. Nothing is saved.
## Each station: sec (its part of the tour), title, test (the one thing to check, shown
## big), feel (what to do and what should happen), args (the game's flags). N next,
## B back, R again, F1 hides the card; `--tour=N` starts at station N. The same list,
## numbered, is docs/TOUR.md: say "#37" when something is wrong.
static var tour := 0
const CH := "fireball,hammer_of_air,water_lash,heave_the_ground"
const TOUR := [
	# --- the weaves, one each ------------------------------------------------------------
	{sec = "Weaves", title = "Fireball", test = "Hold to weave, let go: it flies where you look and bursts.", feel = "The ring at the crosshair fills while you weave; the burst's circle shows on the ground. Fire leaves the grass burning.", args = {"only": "fireball", "aff": "fire", "spawn": "trolloc:4"}},
	{sec = "Weaves", title = "Hammer of Air", test = "A cone that throws them back and down.", feel = "Short reach, wide. They tumble and slide. Its ring and threads are flows: only you (a woman) see them; the dust it throws anyone sees.", args = {"only": "hammer_of_air", "aff": "air", "spawn": "trolloc:4"}},
	{sec = "Weaves", title = "Heave the Ground", test = "A line of rock driven up along your aim.", feel = "Spikes nearest first, tallest in the middle; the ground stays torn a while.", args = {"only": "heave_the_ground", "aff": "earth", "spawn": "trolloc:5"}},
	{sec = "Weaves", title = "Lash of Water", test = "A whip that hauls them in and soaks them.", feel = "Soaked Trollocs are slowed; it leaves puddles that put fire out.", args = {"only": "water_lash", "aff": "water", "spawn": "trolloc:4"}},
	{sec = "Weaves", title = "Blade of Spirit", test = "A sliver that dazes: they stop attacking for a moment.", feel = "Spirit is never dodged (even by an Eyeless). The blade itself is flows; the daze motes anyone sees.", args = {"only": "blade_of_spirit", "aff": "spirit", "spawn": "trolloc:4"}},
	{sec = "Weaves", title = "Dome of Air", test = "A dome round you that soaks blows and arrows while held.", feel = "It takes flows (the dots top left) and breaks when it has soaked enough. Archers are shooting.", args = {"only": "dome_of_air", "aff": "air", "spawn": "trolloc_archer:3,trolloc:2"}},
	{sec = "Weaves", title = "Bonds of Air", test = "Aimed at one: it is held still while you hold the weave.", feel = "A thread runs from your hand to it. Two at once if you have the flows.", args = {"only": "bonds_of_air", "aff": "air", "spawn": "trolloc:3"}},
	{sec = "Weaves", title = "Lightning", test = "Falls from the sky on the aim; soaked ones take more, and it arcs.", feel = "A white flash, arcs along the ground, a scorch. What survives is charged: the next hit leaps on.", args = {"only": "lightning,water_lash", "aff": "air", "spawn": "trolloc:6"}},
	{sec = "Weaves", title = "Arrows of Fire", test = "Fast darts, each through two bodies.", feel = "Thin white-hot streaks, almost no glow.", args = {"only": "arrows_of_fire", "aff": "fire", "spawn": "trolloc:6"}},
	{sec = "Weaves", title = "Rolling Ring of Earth and Fire", test = "A wedge of fire and earth rolls out the way you face.", feel = "Read the wedge on the ground while you weave. Does the size feel right after the cut to two-thirds?", args = {"only": "rolling_ring", "aff": "earth", "spawn": "trolloc:8"}},
	{sec = "Weaves", title = "Blossoms of Fire", test = "A pillar, then a wheel of fire turning outward: stay out of it.", feel = "It hurts you too if you stand in it.", args = {"only": "blossoms_of_fire", "aff": "fire", "spawn": "trolloc:8"}},
	{sec = "Weaves", title = "Deathgate", test = "A doorway of darkness that sweeps forward through them.", feel = "Slow to weave. Worth the wait?", args = {"only": "deathgate", "aff": "fire", "spawn": "trolloc:10"}},
	{sec = "Weaves", title = "Torrent", test = "Only near water: a wave from the pond rolls over them.", feel = "You start beside the horse pond; weave at the Trollocs as they come. Away from water it will not weave.", args = {"only": "torrent,water_lash", "aff": "water", "at": "24,-6", "spawn": "trolloc:5"}},
	{sec = "Weaves", title = "Wall of Air", test = "Solid while held: nothing walks or is thrown through, either way.", feel = "Your own fire stops on it too. T: flat ahead or round you; the wheel turns it while you weave.", args = {"only": "wall_of_air,fireball", "aff": "air", "spawn": "trolloc_archer:3,trolloc:3"}},
	{sec = "Weaves", title = "Wall of Water", test = "Arrows fall short and fire goes out in it; people wade through.", feel = "A falling sheet. Try your own fireball through it (it hisses out).", args = {"only": "wall_of_water,fireball", "aff": "water", "spawn": "trolloc_archer:3,trolloc:3"}},
	{sec = "Weaves", title = "Balefire", test = "Kills outright, and undoes what the dead did in their last moments.", feel = "Let a Trolloc wound your Warder, then balefire it: the wound is gone. Hold the button after it is woven to keep it burning and sweep it.", args = {"only": "balefire,healing", "aff": "fire", "ally": "warder", "spawn": "trolloc:6"}},
	{sec = "Weaves", title = "Healing", test = "Aimed at a hurt friend in reach: their health and wounds come back.", feel = "It tires the one healed. You cannot Heal yourself. The dark end of the health bar is wounds: only Healing mends them.", args = {"only": "healing", "aff": "spirit", "ally": "warder", "ally_hp": "60", "spawn": "trolloc:2"}},
	{sec = "Weaves", title = "Shield from the Source", test = "On the Dreadlord: it cannot channel while you hold it.", feel = "It gathers fire and marks the ground red for lightning; shielded, it does neither.", args = {"only": "shielding,fireball", "aff": "spirit", "spawn": "dreadlord:1@20"}},
	{sec = "Weaves", title = "Gateway (quick)", test = "Tap: a gateway opens quickly where you look. Walk through.", feel = "Each side is a window onto the other.", args = {"only": "gateway", "aff": "spirit", "spawn": "trolloc:3"}},

	# --- weaving: the controls and the rules ----------------------------------------------
	{sec = "Weaving", title = "Gateway, end by end", test = "Hold until whole: let go sets the near end, click sets the far end.", feel = "T lays the end you are placing flat (aimed high: an opening in the sky to drop out of); the wheel turns it. Hammer a Trolloc into it: it dies. Fire goes through and comes out turned.", args = {"only": "gateway,hammer_of_air,fireball", "aff": "spirit", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "Placing walls", test = "T switches flat ahead / round you; the wheel turns 15 degrees a notch.", feel = "The shape shows on the ground while you weave. The turn resets for each new weave.", args = {"only": "wall_of_air,wall_of_water", "aff": "air", "spawn": "trolloc:4"}},
	{sec = "Weaving", title = "Holding and tying off", test = "Held weaves use flows; G ties off the chosen one, freeing the flow.", feel = "Dome, Bonds and the Shield. Is juggling flows interesting or fiddly?", args = {"only": "dome_of_air,bonds_of_air,shielding,fireball", "aff": "air", "tie": "1", "spawn": "trolloc:4"}},
	{sec = "Weaving", title = "Keeping a weave, two at once", test = "Weave a fireball, then change slot: it is kept aside; its slot takes it back up.", feel = "Both weave at 60% while both are being made; a whole kept one costs a little each second. Its slot shows it is kept.", args = {"only": "fireball,lightning,water_lash", "aff": "fire", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "The weave chart and the bar", test = "Tab: the chart. Drag slots on the bar to arrange them.", feel = "Is dragging easy, and do the slot marks (weaving, ready, kept) read?", args = {"weaves": CH + ",lightning,dome_of_air", "spawn": "trolloc:3"}},
	{sec = "Weaving", title = "A weak channeller", test = "Strength 35: everything is smaller, shorter and slower.", feel = "Compare with the next station.", args = {"only": "fireball,lightning,rolling_ring", "strength": "35", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "A very strong channeller", test = "Strength 1: bigger bursts, longer burns, faster weaving.", feel = "The same three weaves.", args = {"only": "fireball,lightning,rolling_ring", "strength": "1", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "Weaves change the ground", test = "Fire burns the grass, water puddles, air blows fire out, earth throws down the breastwork.", feel = "Heave the Ground leaves rubble to shelter behind.", args = {"activity": "tarwins_gap_watch", "only": "fireball,water_lash,hammer_of_air,heave_the_ground", "strength": "20", "spawn": "trolloc:6"}},
	{sec = "Weaving", title = "Seeing flows: a man beside a woman", test = "You are a man: her weaving is invisible to you; her fire is not.", feel = "Your own weaving you see. Her Dome or Bonds: you see only what they do.", args = {"only": "fireball,dome_of_air", "sex": "m", "aff": "fire", "ally": "channeller", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "Seeing flows: a fighter", test = "A Warder sees no weaving at all, only what weaves do.", feel = "Your channeller's fireballs fly from nothing; a Wall of Air would be invisible.", args = {"class": "warder", "kit": "sword", "ally": "channeller", "spawn": "trolloc:5"}},
	{sec = "Weaving", title = "First person: weaving", test = "Through your own eyes: the hands come up round the weave.", feel = "F5 switches back and forth any time (remembered). Is the bob too much?", args = {"only": "fireball,lightning,bonds_of_air", "fp": "1", "aff": "fire", "spawn": "trolloc:5"}},

	# --- arms: the basics -----------------------------------------------------------------
	{sec = "Arms", title = "Cut, heavy blow, parry", test = "Right click just before a blow lands: parry. At the last instant: perfect, they reel.", feel = "Left click cuts; hold for a heavy blow. The wedge on the ground is where their blow will fall.", args = {"class": "warder", "kit": "sword", "spawn": "trolloc:2"}},
	{sec = "Arms", title = "Roll, step back, duck, jump", test = "Space rolls (standing: steps back). Ctrl ducks a high swing. V jumps a low sweep (yellow wedge).", feel = "Caught by a sweep you go down: Space rolls up, right click rises behind your guard.", args = {"class": "aiel", "kit": "aiel_spear", "spawn": "trolloc:3,trolloc_brute:1"}},
	{sec = "Arms", title = "Throwing and gathering", test = "F throws; what you threw stands where it fell: walk over it to pick it up.", feel = "Throwing knives, javelins, axes.", args = {"class": "hunter", "kit": "throwing_knives,javelins,throwing_axes", "spawn": "trolloc:4"}},
	{sec = "Arms", title = "Sword and round shield", test = "Hold right click facing archers: arrows glance off the shield.", feel = "The heavy blow is a shield bash that shoves.", args = {"class": "warder", "kit": "sword_shield", "spawn": "trolloc_archer:3,trolloc:2"}},
	{sec = "Arms", title = "Drawing a bow", test = "Hold to draw (you turn to the aim); a half draw falls short.", feel = "Side-on stance, the string to the cheek.", args = {"class": "hunter", "kit": "longbow", "spawn": "trolloc:4"}},
	{sec = "Arms", title = "First person: weapons", test = "A blade held out ahead, a pole levelled; the bow drawn in view.", feel = "1-3 change weapon. Do blows read from the eyes (the streaks)?", args = {"class": "hunter", "kit": "sword,boar_spear,longbow", "fp": "1", "spawn": "trolloc:4"}},

	# --- every weapon -------------------------------------------------------------------------
	{sec = "Weapons", title = "Sword, hand-and-a-half, sabre", test = "Each swings and lands as it should; the bigger blade is slower and harder.", feel = "1, 2, 3 to change.", args = {"class": "hunter", "kit": "sword,bastard_sword,sabre", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Short sword, sword and knife, practice sword", test = "Sword and knife: the knife stabs between cuts from the off hand.", feel = "The practice sword barely hurts.", args = {"class": "hunter", "kit": "short_sword,sword_knife,practice_sword", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Belt knife, paired daggers, Aiel long knife", test = "Quick and short; the daggers flurry.", feel = "", args = {"class": "aiel", "kit": "belt_knife,daggers,aiel_knife", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Throwing knives, throwing axes, javelins", test = "Thrown arms in flight, stuck where they hit, gathered again.", feel = "", args = {"class": "hunter", "kit": "throwing_knives,throwing_axes,javelins", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Aiel spear, boar spear, pike", test = "The Aiel spear one-handed over the buckler; the others two-handed thrusts.", feel = "The pike reaches furthest.", args = {"class": "aiel", "kit": "aiel_spear,boar_spear,pike", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Halberd, ashandarei, quarterstaff", test = "Two hands on the haft: cuts both ways, overheads, butt strikes.", feel = "The halberd throws them back; the staff trips.", args = {"class": "hunter", "kit": "halberd,ashandarei,quarterstaff", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Iron-shod staff, half-moon axe, woodsman's axe", test = "Heavy chops; the axes hook.", feel = "", args = {"class": "hunter", "kit": "iron_staff,halfmoon_axe,wood_axe", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Smith's hammer, cudgel, sling", test = "The hammer reels them; the sling is quick and staggers.", feel = "", args = {"class": "hunter", "kit": "hammer,cudgel,sling", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Longbow, horn bow, horse bow", test = "Compare the three draws and ranges.", feel = "", args = {"class": "hunter", "kit": "longbow,horn_bow,horse_bow", "spawn": "trolloc:4,trolloc_archer:1"}},
	{sec = "Weapons", title = "Crossbow, bare hands", test = "Crossbow: one click, one hard bolt, then it spans itself. Hands: jab, cross, kick.", feel = "The kick lifts the leg; the low blow is a sweeping kick.", args = {"class": "hunter", "kit": "crossbow,hands", "spawn": "trolloc:4"}},
	{sec = "Weapons", title = "Earned weapons", test = "Heron-mark blade, Power-wrought blade (never dulls), the ruby dagger (bleeds; feeds on you).", feel = "Normally won: heron-mark at sword skill 6, Power-wrought at renown 60, the dagger at renown 30. Hold the dagger and watch your health.", args = {"class": "hunter", "kit": "heron_blade,power_blade,shadar_dagger", "earned": "1", "spawn": "trolloc:4"}},

	# --- forms ----------------------------------------------------------------------------
	{sec = "Forms", title = "Sword forms, first four", test = "Keys 2-5: Parting the Silk, the Boar Rushes, Apple Blossoms, Heron Wading.", feel = "Each has its own path, streak and colour; Heron Wading is on one foot. Each has a cooldown.", args = {"class": "warder", "kit": "sword", "forms": "1", "spawn": "trolloc:5"}},
	{sec = "Forms", title = "Sword forms, last four", test = "Keys 6-9: the Swallow, the Courtier's Fan, Arc of the Moon, Sheathing the Sword.", feel = "", args = {"class": "warder", "kit": "sword", "forms": "1", "spawn": "trolloc:5"}},
	{sec = "Forms", title = "Spear forms", test = "The Dance of Spears (three thrusts) and Set Against the Charge.", feel = "", args = {"class": "aiel", "kit": "aiel_spear", "forms": "1", "spawn": "trolloc:4,trolloc_brute:1"}},
	{sec = "Forms", title = "Whirling Staff, Hew, Flurry", test = "Staff, axe and knife (paired daggers) forms.", feel = "Flurry is four quick wounds.", args = {"class": "hunter", "kit": "quarterstaff,wood_axe,daggers", "forms": "1", "spawn": "trolloc:5"}},

	# --- the callings ----------------------------------------------------------------------
	{sec = "Callings", title = "The Warder's bond", test = "A knot marks your channeller, through walls; redder as she is hurt.", feel = "Out of sight it is an arrow at the screen's edge. If she goes down you rage: harder blows, no tiring, for 12 s.", args = {"class": "warder", "kit": "sword", "ally": "channeller", "ally_hp": "70", "spawn": "trolloc:5"}},
	{sec = "Callings", title = "The Warder's cloak and ward", test = "Stand still a second: they go for her instead. Parry beside her: you take her blow.", feel = "You both recover faster near each other.", args = {"class": "warder", "kit": "sword", "ally": "channeller", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Aiel: a Maiden of the Spear", test = "A little faster, and dodges cost less breath.", feel = "Veiled to fight.", args = {"class": "aiel", "sex": "f", "society": "far_dareis_mai", "kit": "aiel_spear,javelins,aiel_knife", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Aiel: a Stone Dog", test = "Standing your ground, a fifth less from every blow.", feel = "Compare standing still with moving.", args = {"class": "aiel", "society": "shaen_mtaal", "kit": "aiel_spear,aiel_knife,horn_bow", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Aiel: Brother of the Eagle", test = "The horn bow drawn a fifth faster.", feel = "", args = {"class": "aiel", "society": "far_aldazar_din", "kit": "horn_bow,aiel_spear", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Hunter: the Band of the Red Hand", test = "The kit whole: crossbow, pike, ashandarei, a level up in each.", feel = "", args = {"class": "hunter", "hkit": "red_hand", "kit": "crossbow,pike,ashandarei", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Gift: Wolfbrother", test = "A tenth faster, harder on Shadowspawn.", feel = "", args = {"class": "hunter", "gift": "wolfbrother", "kit": "sword", "spawn": "trolloc:4"}},
	{sec = "Callings", title = "Gift: a gambler's luck", test = "\"Lucky\": one blow in seven misses you; one of yours in ten lands double.", feel = "Watch the notices.", args = {"class": "hunter", "gift": "gamblers_luck", "kit": "sword", "spawn": "trolloc:5"}},

	# --- the Shadow ------------------------------------------------------------------------
	{sec = "Enemies", title = "Trollocs", test = "Each weapon has its own two blows; a blow unguarded staggers or throws you.", feel = "Scythe-swords sweep, axes chop, spears thrust, clubs smash. Read the wedges.", args = {"class": "warder", "kit": "sword", "spawn": "trolloc:4"}},
	{sec = "Enemies", title = "Trolloc archers", test = "They shoot from range: duck, roll, or shield.", feel = "", args = {"class": "warder", "kit": "sword_shield", "spawn": "trolloc_archer:4"}},
	{sec = "Enemies", title = "A bandleader (brute)", test = "Big and hard-hitting; its low sweep trips (jump it, V).", feel = "", args = {"class": "warder", "kit": "bastard_sword", "spawn": "trolloc_brute:1,trolloc:2"}},
	{sec = "Enemies", title = "The Eyeless, blade to blade", test = "It circles, lunges along the red line, or vanishes and comes out behind you.", feel = "Roll off the line or parry. Its wounds fester until Healed.", args = {"class": "warder", "kit": "sword", "spawn": "myrddraal:1"}},
	{sec = "Enemies", title = "The Eyeless and the dark", test = "As a channeller: the dark closes in as it comes near; its stare slows your weaving.", feel = "Half of what you throw misses it; Blade of Spirit does not. Look away from its gaze.", args = {"only": "blade_of_spirit,fireball,lightning", "aff": "spirit", "spawn": "myrddraal:1@14"}},
	{sec = "Enemies", title = "Darkhounds", test = "They spring from far off along the red line; steel does half; weaves kill.", feel = "They mend when left alone.", args = {"only": "fireball,arrows_of_fire,bonds_of_air", "aff": "fire", "ally": "warder", "spawn": "darkhound:3@16"}},
	{sec = "Enemies", title = "A Draghkar", test = "It lands and sings (the rings): hit it before the song ends, or break its sight.", feel = "Let it finish once to feel it.", args = {"only": "fireball,hammer_of_air,lightning", "aff": "fire", "spawn": "draghkar:1@28"}},
	{sec = "Enemies", title = "A Dreadlord", test = "Fire that bursts, red ground where lightning will fall.", feel = "Shield it, or out-weave it.", args = {"only": "shielding,fireball,dome_of_air", "aff": "spirit", "spawn": "dreadlord:1@24,trolloc:2"}},
	{sec = "Enemies", title = "Darkfriends", test = "Men with blades and bows, smaller than Trollocs, fighting like people.", feel = "", args = {"class": "warder", "kit": "sword", "spawn": "darkfriend_blade:2,darkfriend_archer:2"}},
	{sec = "Enemies", title = "A horde", test = "Thirty Trollocs: does it stay smooth?", feel = "Rolling Ring and Blossoms into the crowd.", args = {"only": "rolling_ring,blossoms_of_fire,fireball", "aff": "fire", "strength": "6", "spawn": "trolloc:30"}},

	# --- the dream ---------------------------------------------------------------------------
	{sec = "Dream", title = "Dream duel: moving and denying", test = "Z X V T Y U H Shift: the shifts, deny, spear, chains, pit, wall.", feel = "Will (the pale bar) pays for everything. Deny, pressed as something reaches you, unmakes it. I opens all 24.", args = {"activity": "dream_spar", "class": "warder", "kit": "sword", "foe": "warder", "dreambar": "shift_behind,shift_back,shift_aim,deny,dream_spear,dream_chains,dream_pit,dream_wall"}},
	{sec = "Dream", title = "Dream duel: the wild things", test = "Side-step, swap, arrows, boulder, ravens, cage, forget, shove.", feel = "Caged? Deny and wait. Swap trades places.", args = {"activity": "dream_spar", "class": "warder", "kit": "sword", "foe": "warder", "dreambar": "shift_side,shift_swap,dream_arrows,dream_boulder,dream_ravens,dream_cage,dream_forget,dream_shove"}},
	{sec = "Dream", title = "Dream duel: the strange ones", test = "Pull, fire, storm, ring, mirror, mend, fade, haste.", feel = "The mirror turns things back. Fade: unseen. Haste: quicker.", args = {"activity": "dream_spar", "class": "warder", "kit": "sword", "foe": "warder", "dreambar": "dream_pull,dream_fire,dream_storm,dream_ring,dream_mirror,dream_mend,dream_fade,dream_haste"}},
	{sec = "Dream", title = "Dream inventory", test = "I: click an ability, then a slot, to put it on the bar.", feel = "Is it friendly enough? Are the bar's marks readable?", args = {"activity": "dream_spar", "only": "fireball", "foe": "channeller"}},

	# --- whole fights ---------------------------------------------------------------------
	{sec = "Fights", title = "A round, sped up", test = "Tab: choices waiting (six levels in). Waves four times as fast.", feel = "Your fire hurts your Warder. Go down and he comes to stand over you.", args = {"activity": "tarwins_gap_watch", "weaves": CH + ",lightning,dome_of_air,healing", "ally": "warder", "roll": "1", "levels": "6", "fast": "1"}},
	{sec = "Fights", title = "Guard the Aes Sedai", test = "She seals the Waygate (timer at the top); they go for her; if she falls it is lost.", feel = "Her mark points to her when she is out of sight.", args = {"activity": "guard_door@tarwins_day", "class": "warder", "kit": "sword,horse_bow,belt_knife", "fast": "1"}},
	{sec = "Fights", title = "Guard her as a channeller", test = "A Dome over her, Bonds on what reaches her.", feel = "", args = {"activity": "guard_door@wagon_ring", "weaves": CH + ",dome_of_air,bonds_of_air,healing", "fast": "1"}},
	{sec = "Fights", title = "Two banners (team battle)", test = "Blue rings yours, red theirs; kill theirs, stand over your own.", feel = "Bots fill out the numbers.", args = {"activity": "team_battle", "weaves": CH + ",lightning,dome_of_air", "roll": "1", "levels": "3"}},
	{sec = "Fights", title = "The wagon ring, sped up", test = "From every side, with archers and an Eyeless.", feel = "", args = {"activity": "wagon_ring", "weaves": CH + ",lightning,dome_of_air,bonds_of_air", "ally": "warder", "roll": "1", "levels": "4", "fast": "1"}},
	{sec = "Fights", title = "The Wild Hunt, sped up", test = "Darkhounds, a Draghkar, Dreadlords together.", feel = "", args = {"activity": "wild_hunt", "weaves": CH + ",lightning,dome_of_air,shielding", "ally": "warder", "roll": "1", "levels": "6", "fast": "1"}},
	{sec = "Fights", title = "The endless night, sped up", test = "Waves without end, at night, eight levels in.", feel = "Last station: N goes back to the camp. Things to try there are in docs/TOUR.md.", args = {"activity": "endless", "weaves": CH + ",lightning,dome_of_air,healing", "ally": "warder", "roll": "1", "levels": "8", "fast": "1"}},
]

static func station() -> Dictionary:
	var a: Dictionary = {name = "Tour", flows = "10", strength = "8", activity = "camp_training", tour = "1"}
	a.merge(TOUR[tour].args, true)
	# Enemies start a little way off, so you see what is coming (unless a station says).
	if a.has("spawn"):
		var parts := []
		for sp in String(a.spawn).split(","):
			parts.append(sp if sp.contains("@") else sp + "@12")
		a.spawn = ",".join(parts)
	# A round station rolls its strength like any round.
	if a.has("roll"):
		a.erase("strength"); a.erase("flows")
	if cmdline().has("auto"):
		a.auto = "1"   # a bot walks the tour, for checking the stations run
	return a
