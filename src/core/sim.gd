class_name Sim
extends RefCounted
## The authoritative fight, with no nodes and no rendering: players, enemies and live
## weaves on the ground plane. The host steps it; views and clients only mirror it.
## Running without graphics is what lets tests (and the co-op host) play whole
## holdouts headlessly.
##
## Everything is plain Dictionaries so state can be snapshotted over the network.

var t := 0.0
var ents := {}            # id -> entity
var effects: Array = []
var events: Array = []    # drained each tick by whoever is watching
var tallies := {}         # player id -> what Progression.award needs
var activity_id := ""
var over := false
var success := false
var rng := RandomNumberGenerator.new()
var _next := 1
var _waves: Array = []
var _spar := false
var dream := false       # Tel'aran'rhiod: dream moves are allowed here (see Dream)
var round_mode := false  # a round (see Round): everyone grows during it, from fresh
var team_level := 1
var team_xp := 0.0
# Team battle (an activity with "battle"): two sides of players, each with its own
# level, scoring the other side's deaths. Shadowspawn come for both.
var battle := {}
var scores := {1: 0, 2: 0}
var levels := {1: 1, 2: 1}
var xps := {1: 0.0, 2: 0.0}
var _filled := false
var _endless_won := false
var ledger: Array = []   # recent harm: {t, by, on, dmg, hp, downed}; balefire undoes it
var df_mode := false     # a Darkfriend round: one or two players may secretly serve the Shadow
var _df_assigned := false

func _init(activity: String, seed_ := 1) -> void:
	Rules.load_data()
	activity_id = activity
	rng.seed = seed_
	var act: Dictionary = Rules.activities[activity]
	_waves = act.get("waves", []).duplicate(true)
	if act.has("round"):
		round_mode = true
		df_mode = act.get("darkfriend", false)
		_waves = Round.plan(act, rng)
	_spar = act.kind == "spar"
	battle = act.get("battle", {})
	dream = act.get("dream", false)
	Dream.load_data()
	Map.use(act.get("map", "open"), activity)

func add_player(profile: Dictionary, pos := Vector3.ZERO, as_bot := false) -> int:
	if (round_mode or Rules.activities[activity_id].get("rolls", false)) and not profile.has("round"):
		# The round copy: rolled strength or gift, fresh practice. Someone arriving
		# part-way through catches up to the team's level.
		profile = Round.begin(profile, rng)
		for lv in range(2, (levels[_smaller_side()] if not battle.is_empty() else team_level) + 1):
			Round.level_up(profile, lv, rng)
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "player", profile = profile, pos = pos, yaw = PI, hp = 100.0, max_hp = 100.0,
		radius = 0.45, team = id if _spar else 0, alive = true, move = Vector3.ZERO, speed = 5.2,
		stamina = Rules.TUNE.stamina, forming = {}, held = [], barrier = 0.0, severed = 0.0, stagger = 0.0,
		cd = {}, burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, vel = Vector3.ZERO,
		# Arms: what is in hand, the blow in progress, and how it is being defended.
		weapon = "", ammo = {}, swing = {}, queued = {}, chain = 0, chain_t = 0.0, shot_free = -99.0,
		guard = false, guard_since = 0.0, parry_at = -9.0, parry_free = 0.0, duck = false, safe_until = 0.0, dash = {}, reel_until = 0.0,
		will = 100.0, will_t = -99.0, chained = 0.0, shaken = 0.0, deny_until = 0.0}
	var p: Dictionary = ents[id]
	p.bot = as_bot
	if not battle.is_empty():
		# No Warders in a battle: the sides are matched by number.
		if profile.has("round"): profile.round.warder = false
		# The side with fewer on it, at its own end of the field.
		p.team = _smaller_side()
		p.pos = _base(p.team) + Vector3(rng.randf_range(-2.0, 2.0), 0, 0)
		p.yaw = 0.0 if p.team == 1 else PI
	# Those who fight with their hands are built for it: more breath than a channeller.
	p.stamina_max = Rules.TUNE.stamina * (1.5 if profile.get("cls", "channeller") != "channeller" else 1.0)
	p.stamina = p.stamina_max
	p.speed = Rules.run_speed(profile)
	p.max_hp = Rules.max_hp(profile); p.hp = p.max_hp
	for w in profile.get("kit", []):
		var row: Dictionary = Rules.weapons[w]
		p.ammo[w] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	# A fighter arrives armed; a channeller's hands are free to weave.
	if profile.get("cls", "channeller") != "channeller" and not profile.get("kit", []).is_empty():
		p.weapon = profile.kit[0]
	tallies[id] = {casts = {}, kills = {}, blows = {}, draw = 0.0, effort = 0.0, seconds = 0.0}
	events.append(_intro(ents[id]))
	# An Aes Sedai whose roll gave her a Warder arrives with one: a middling
	# swordsman, but a real help, who keeps by her.
	if profile.get("round", {}).get("warder", false):
		var w := Profile.create({name = "%s's Warder" % profile.name, cls = "warder", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["sword", "horse_bow"]})
		w.round = {level = team_level, picks = 0, man = true, gift = 0.0, learn = 1.0}
		var wid := add_player(w, pos + Vector3(1.6, 0, 0.8), true)
		ents[wid].warder_of = id
	return id

## What a view needs to draw someone: who they are and how they chose to look.
func _intro(e: Dictionary) -> Dictionary:
	if e.kind == "enemy":
		return {e = "spawn", id = e.id, type = e.type, pos = e.pos}
	var pr: Dictionary = e.profile
	# What the player's own view needs of their round (never the rolled potential:
	# how far they can go is theirs to find out).
	var rd: Dictionary = pr.get("round", {})
	var round_view := {} if rd.is_empty() else {level = rd.get("level", 1), picks = rd.get("picks", 0), strength = Rules.level_of(Rules.strength(pr)) if pr.get("cls", "channeller") == "channeller" else 0, warder = rd.get("warder", false), gift = rd.get("gift", 0.0), bot = e.get("bot", false)}
	return {round = round_view, team = e.get("team", 0), e = "player", id = e.id, name = pr.name, look = pr.get("look", ""), power = pr.power, origin = pr.get("origin", ""), cls = pr.get("cls", "channeller"), weapon = e.weapon, style = pr.get("style", {}), pos = e.pos}

## Introductions for everyone alive, for a player who joins part-way through.
func roster() -> Array:
	var out := []
	for id in ents:
		if ents[id].alive:
			out.append(_intro(ents[id]))
	return out

## What a Trolloc carries, by id, so the view can show the same thing in its hand
## (see the variants in game.gd) and its attacks can follow from it.
const ARMS: Array[String] = ["scythe", "axe", "spear", "club"]

func _add_enemy(type: String, pos: Vector3) -> void:
	var row: Dictionary = Rules.enemies[type]
	var id := _next; _next += 1
	ents[id] = {id = id, kind = "enemy", type = type, row = row, pos = pos, yaw = 0.0, hp = float(row.hp), max_hp = float(row.hp),
		radius = float(row.radius), team = -1, alive = true, atk = 0.0, stagger = 0.0, vel = Vector3.ZERO,
		burn = 0.0, burn_dps = 0.0, burn_by = 0, down = 0.0, swung = false, blow = {}, aim_yaw = 0.0, arm = "club" if row.has("ranged") else ARMS[id % 4],
		speed = row.speed * rng.randf_range(0.85, 1.15)}
	events.append(_intro(ents[id]))

func set_input(id: int, move: Vector3, yaw: float) -> void:
	var p: Dictionary = ents[id]
	p.move = Vector3.ZERO if p.get("tied", false) else move.limit_length(1.0); p.yaw = yaw

## Rope (a fighter's way to hold someone): stand over a player who is down or
## knocked off their feet and keep at it for ROPE_SECS, and they are tied: no
## walking, no blows, no rolls. Rope does not stop channelling (the Power needs no
## hands): that takes a Shield as well. Anyone can untie a tied player the same way,
## and fire burns the ropes off. A tied Darkfriend counts as held.
func set_tying(id: int, on: bool) -> String:
	var p: Dictionary = ents.get(id, {})
	if p.is_empty() or not p.alive or p.get("downed", false) or p.get("tied", false):
		return "busy"
	if not on:
		p.tying = 0; p.tie_t = 0.0
		return ""
	var best := {}
	for k in ents:
		var o: Dictionary = ents[k]
		if o.kind == "player" and o.alive and k != id and o.pos.distance_to(p.pos) < 1.6:
			var can_tie: bool = p.profile.get("cls", "channeller") != "channeller" and not o.get("tied", false) and (o.get("downed", false) or o.down > 0.0 or o.stagger > 0.0)
			if can_tie or o.get("tied", false):
				best = o
	if best.is_empty():
		return "no one here to tie (they must be down) or untie" if p.profile.get("cls", "channeller") != "channeller" else "no one here to untie"
	p.tying = best.id; p.tie_t = 0.0
	return ""

func _step_tying(p: Dictionary, dt: float) -> void:
	var o: Dictionary = ents.get(p.get("tying", 0), {})
	if o.is_empty() or not o.alive or o.pos.distance_to(p.pos) > 1.8:
		p.tying = 0
		return
	p.move = Vector3.ZERO
	p.tie_t += dt
	if p.tie_t >= Rules.TUNE.rope_secs:
		o.tied = not o.get("tied", false)
		if o.tied:
			o.swing = {}; o.queued = {}; o.guard = false; o.move = Vector3.ZERO
		events.append({e = "tied" if o.tied else "untied", id = o.id, by = p.id})
		p.tying = 0

## Flows not taken up by weaves being held. A weave that has been tied off holds
## itself, and costs none.
func free_slots(p: Dictionary) -> int:
	var used := 0
	for h in p.held:
		if h.tied == 0.0:
			used += Rules.slots_of(Rules.weaves[h.weave], p.profile)
	for w in p.get("autos", []):
		used += Rules.slots_of(Rules.weaves[w], p.profile)
	return Rules.flow_capacity(p.profile) + 2 * p.get("circle", []).size() - used

## Who a held weave aimed at `aim` would fasten on: the nearest body the weave can
## take (anyone not on your side; only channellers for a shield) within a few paces.
func _aimed(p: Dictionary, w: Dictionary, aim: Vector3) -> int:
	var best := 0; var best_d := 3.0
	# With a Darkfriend among them, players can Shield and bind one another.
	for e in (_struck(p) if df_mode else _targets(p)):
		# (A Dreadlord channels, and can be cut off like anyone who does.)
		if w.kind == "sever" and e.kind != "player" and not e.get("row", {}).get("channels", false):
			continue
		if e.get("row", {}).get("speed", 1.0) == 0.0:
			continue
		var d := Vector2(e.pos.x - aim.x, e.pos.z - aim.z).length()
		if d < best_d and e.pos.distance_to(p.pos) < w.base.get("range", 30.0):
			best_d = d; best = e.id
	return best

## Tie off what you hold of this weave: it stays without you for a while, and the
## flows it took are yours again. A technique, learned and not born with.
func tie(id: int, weave: String) -> String:
	var p: Dictionary = ents[id]
	# On a weave that strikes and is done, the same key keeps it going by itself.
	if not Rules.weaves[weave].get("hold", false):
		return toggle_auto(id, weave)
	if not Rules.has_technique(p.profile, "tie_off"):
		return "you have not learned to tie off a weave"
	var any := false
	for h in p.held:
		if h.weave == weave and h.tied == 0.0:
			h.tied = t + Rules.tie_time(p.profile, weave)
			any = true
			events.append({e = "tie", id = id, weave = weave, target = h.target})
	return "" if any else "you are not holding that"

## Let go of a weave being made, or made and held back, without loosing it.
func cancel_weave(id: int) -> String:
	var p: Dictionary = ents.get(id, {})
	if p.is_empty() or p.forming.is_empty():
		return "nothing being woven"
	events.append({e = "cancel", id = id, weave = p.forming.weave})
	p.forming = {}
	return ""

## A weave left going on its own (G on a weave that strikes): it keeps the flows it
## needs, and weaves itself again at the nearest foe in reach whenever it is ready,
## paying its own stamina. The hands stay free for something else.
func toggle_auto(id: int, weave: String) -> String:
	var p: Dictionary = ents[id]
	if not p.has("autos"):
		p.autos = []; p.auto_t = {}
	if p.autos.has(weave):
		p.autos.erase(weave)
		events.append({e = "auto", id = id, weave = weave, on = false})
		return ""
	var w: Dictionary = Rules.weaves[weave]
	if Rules.slots_of(w, p.profile) > free_slots(p):
		return "not enough flows to keep it going"
	var why := Rules.cast_block(p.profile, weave, free_slots(p), p.stamina)
	if why != "":
		return why
	p.autos.append(weave)
	p.auto_t[weave] = t + Rules.form_time(p.profile, weave)
	events.append({e = "auto", id = id, weave = weave, on = true})
	return ""

func _step_autos(p: Dictionary) -> void:
	for weave in p.get("autos", []):
		if t < p.auto_t.get(weave, 0.0):
			continue
		var reach: float = float(Rules.weaves[weave].base.get("range", 25.0))
		var best := {}; var bd := reach
		for e in _targets(p):
			var d: float = e.pos.distance_to(p.pos)
			if d < bd and e.get("row", {}).get("speed", 1.0) > 0.0:
				bd = d; best = e
		if best.is_empty():
			p.auto_t[weave] = t + 0.3
			continue
		var cost := Rules.draw_of(p.profile, weave, p.stamina)
		if cost > p.stamina:
			p.auto_t[weave] = t + 1.0
			continue
		p.stamina -= cost
		_cast(p, weave, _feet(best) + Vector3(0, 1.1, 0))
		events.append({e = "cast", id = p.id, weave = weave, auto = true})
		p.auto_t[weave] = t + Rules.form_time(p.profile, weave) + Rules.cooldown(p.profile, weave)

## Start forming a weave at an aim point. Returns "" or the reason it was refused.
## `hold`: the weave, once made, waits in the hands until aim_cast lets it go
## (a held mouse button); without it the weave leaves the moment it is whole.
func request_cast(id: int, weave: String, aim: Vector3, hold := false) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or not p.forming.is_empty() or not p.swing.is_empty() or not p.dash.is_empty() or p.reel_until > t:
		return "busy"
	if p.get("entranced", 0.0) > t:
		return "the song has you"
	if p.get("circle_of", 0) != 0:
		return "linked: your circle's leader weaves"
	if p.severed > t:
		return "shielded from the Source"
	if p.get("bound_by", 0) != 0:
		return "bound in Air"
	if p.chained > t:
		return "chained"
	if p.get("downed", false):
		return "you are down"
	var row: Dictionary = Rules.weaves.get(weave, {})
	var target := 0
	if row.get("hold", false):
		# Weaving a held weave again lets it go. One that fastens on someone is let
		# go by weaving it at them again, or at nobody.
		if row.kind in ["bind", "sever"]:
			target = _aimed(p, row, aim)
			for h in p.held:
				if h.weave == weave and h.tied == 0.0 and (h.target == target or target == 0):
					release(id, weave, h.target)
					return ""
			if target == 0:
				return "no one there to hold"
		else:
			for h in p.held:
				if h.weave == weave and h.tied == 0.0:
					release(id, weave)
					return ""
	if p.cd.get(weave, 0.0) > t:
		return "not ready"
	if row.get("kind", "") == "heal" and _heal_target(p, aim, row.base.range).is_empty():
		return "no one there to Heal (you cannot Heal yourself)"
	var why := Rules.cast_block(p.profile, weave, free_slots(p), p.stamina)
	if why != "":
		return why
	p.forming = {weave = weave, left = Rules.form_time(p.profile, weave), aim = aim, target = target, hold = hold, ready = false}
	events.append({e = "form", id = id, weave = weave, time = p.forming.left})
	return ""

## Where the weave being made will go, and whether it is still being held back.
## Aim is taken when the weave leaves, not when it was begun: weaving takes time,
## and the fight moves.
func aim_cast(id: int, aim: Vector3, hold: bool) -> void:
	var p: Dictionary = ents[id]
	if not p.forming.is_empty():
		p.forming.aim = aim
		p.forming.hold = hold

# --- arms: intent ---------------------------------------------------------------------

## Take a weapon from the kit into the hand ("" empties the hands, to weave).
func equip(id: int, weapon: String) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or not p.swing.is_empty():
		return "busy"
	if weapon != "" and not p.profile.get("kit", []).has(weapon):
		return "not carried"
	if p.weapon != weapon:
		p.weapon = weapon; p.guard = false; p.chain = 0
		events.append({e = "equip", id = id, weapon = weapon})
	return ""

## Begin a blow. kind: light | heavy | low | throw. `charge` (0..1) is how far a bow
## was drawn. Returns "" or why not. A blow asked for mid-swing is kept and thrown
## as soon as the hands are free, which is what makes a chain.
func request_attack(id: int, kind: String, aim: Vector3, charge := 1.0) -> String:
	var p: Dictionary = ents[id]
	if not p.alive:
		return "busy"
	if p.get("entranced", 0.0) > t:
		return "the song has you"
	if p.weapon == "":
		return "nothing in hand"
	if p.get("bound_by", 0) != 0:
		return "bound in Air"
	if p.chained > t:
		return "chained"
	if p.get("downed", false):
		return "you are down"
	if p.get("tied", false):
		return "tied with rope"
	if not p.swing.is_empty():
		# Asked for during the last one: it goes when that is done (an arrow keeps the
		# draw it had when the string was let go).
		p.queued = {kind = kind, aim = aim, charge = charge, draw_since = p.get("draw_since", t) if p.get("draw_held", false) else -1.0}
		return ""
	# Asked for in a roll: it comes out of the roll, harder for it.
	var aim_dir: Vector3 = ((aim - p.pos) * Vector3(1, 0, 1)).normalized()
	if not p.dash.is_empty() and not p.dash.has("lunge") and not p.dash.get("vault", false) and kind in ["light", "heavy"] and p.forming.is_empty() \
			and p.dash.get("vel", Vector3.ZERO).normalized().dot(aim_dir) > 0.3:
		p.queued = {kind = kind, aim = aim, charge = charge, draw_since = -1.0, from_roll = true}
		return ""
	if p.reel_until > t or not p.forming.is_empty() or not p.dash.is_empty():
		return "busy"
	var w: Dictionary = Rules.weapons[p.weapon]
	# What has been thrown is not in the hand until it is picked up again.
	if w.has("throw") and p.ammo.get(p.weapon, 0) <= 0:
		return "none left: gather them up"
	if kind == "light" and p.duck:
		kind = "low"
	var chain: int = p.chain if t < p.chain_t else 0
	var move_id := Rules.move_for(p.weapon, kind, chain)
	if move_id == "":
		return "that cannot be thrown"
	var m: Dictionary = Rules.moves[move_id]
	if kind.begins_with("form:"):
		var why := Rules.form_block(p.profile, move_id, p.weapon)
		if why != "":
			return why
		if p.cd.get(move_id, 0.0) > t:
			return "not ready"
		p.cd[move_id] = t + float(m.get("cooldown", 0.0))
		# Some forms are paid for in blood.
		if m.has("self"):
			_hurt(p, float(m.self), p.id, "", true)
	var times := Rules.move_times(p.profile, p.weapon, move_id)
	var wind: float = times[0]
	if m.get("missile", false):
		if p.ammo.get(p.weapon, 0) <= 0:
			return "none left"
		if w.has("shot") and w.shot.get("crank", false):
			# A crossbow is spanned or it is not: there is no half shot. It spans
			# itself again after each bolt, and looses the instant it is asked.
			if t < p.shot_free + Rules.draw_time(p.profile, p.weapon):
				return "still spanning"
			charge = 1.0
		elif w.has("shot"):
			# The draw happens in the hand before the click is released; the sim only
			# makes sure nobody looses faster than the bow can be drawn.
			# The host counts the draw itself: an arrow has as much behind it as the
			# string was actually held for, and one asked for undrawn is drawn now.
			charge = clampf(charge, 0.2, 1.0)
			var drawn: float = t - p.get("draw_since", t) if p.get("draw_held", false) else 0.0
			# Drawn as far as it is going: it leaves now, not after a wind-up as well.
			wind = maxf(0.03, Rules.draw_time(p.profile, p.weapon) * charge - drawn)
			if wind > 0.15 and not p.get("draw_held", false):
				p.draw_since = t
			p.draw_held = false
	var cost := Rules.move_cost(p.profile, p.weapon, move_id, p.stamina)
	p.stamina = maxf(p.stamina - cost, 0.0)
	var to := aim - _feet(p); to.y = 0.0
	var dir := to.normalized() if to.length() > 0.05 else Vector3(sin(p.yaw), 0, cos(p.yaw))
	p.yaw = atan2(dir.x, dir.z)
	p.guard = false
	p.chain = chain + 1 if kind == "light" else 0
	# The wait before a bow looses is the draw, and is seen as one.
	p.drawing = m.get("missile", false) and w.has("shot") and not w.shot.get("crank", false) and wind > 0.15
	p.swing = {move = move_id, weapon = p.weapon, left = wind, struck = false, recover = times[1], dir = dir, aim = aim, charge = charge, heavy = kind == "heavy" or kind.begins_with("form:")}
	# A blow struck at a run carries the run into it; one out of a roll, the roll.
	if not m.get("missile", false):
		if t - p.get("rolled_at", -9.0) < 0.15:
			p.swing.bonus = 1.3
		elif p.move.length() > 0.8 and p.move.normalized().dot(dir) > 0.7 and not p.duck:
			p.swing.bonus = 1.2
	if m.has("lunge"):
		p.dash = {vel = dir * (m.lunge / maxf(wind, 0.05)), left = wind, lunge = true}
	var tl: Dictionary = tallies[id]
	tl.blows[p.weapon] = tl.blows.get(p.weapon, 0) + 1
	tl.effort += cost
	events.append({e = "blow", id = id, weapon = p.weapon, move = move_id, wind = wind, recover = times[1], dir = dir, form = kind.begins_with("form:")})
	return ""

## A parry is a moment, not a stance: pressing it puts the weapon in the way for
## parry_window seconds, and then it cannot be tried again for a breath. Holding
## the button does nothing more. (The name is kept from when it was a held guard.)
## A dream move (data/dream.json), where the activity is in Tel'aran'rhiod.
func request_dream(id: int, move: String, aim: Vector3) -> String:
	return Dream.request(self, id, move, aim)

func set_guard(id: int, on: bool) -> void:
	var p: Dictionary = ents[id]
	if not on or not p.alive or t < p.parry_free or p.reel_until > t or Rules.guard_share(p.profile, p.weapon) <= 0.0:
		return
	# Knocked down: rise behind the guard, a moment slower than rolling up.
	if p.down > 0.0:
		p.down = minf(p.down, 0.3)
		p.rise_guard = true
		return
	# It abandons a blow not yet thrown; one already landing finishes.
	if not p.swing.is_empty():
		if p.swing.struck:
			return
		p.swing = {}; p.queued = {}
	p.parry_at = t
	p.parry_free = t + Rules.TUNE.parry_again
	p.guard = true
	events.append({e = "parry_try", id = id})

## Up off the ground after a knockdown: by rolling away, behind a guard, or slowly
## when it wears off.
func _rise(p: Dictionary, how: String) -> void:
	if not p.get("lying", false):
		return
	p.lying = false
	events.append({e = "rise", id = p.id, how = how})

## A jump: clear of the ground for a moment, so a low sweep passes under (and it
## costs breath, like a roll, so it is not free).
const JUMP_SECS := 0.55
func request_jump(id: int) -> String:
	var p: Dictionary = ents[id]
	if not p.alive or p.get("downed", false) or p.down > 0.0 or p.get("tied", false) or p.chained > t or not p.dash.is_empty():
		return "busy"
	if p.get("air_until", 0.0) > t:
		return "busy"
	if p.stamina < 12.0:
		return "out of breath"
	p.stamina -= 12.0
	p.air_until = t + JUMP_SECS
	events.append({e = "jump", id = id})
	return ""

## Drawing a bow: known to the sim only so that everyone can see it, and so that
## nobody runs at full speed with a bow at full draw.
func set_draw(id: int, on: bool) -> void:
	var p: Dictionary = ents[id]
	var bow: bool = p.alive and Rules.weapons.has(p.weapon) and Rules.weapons[p.weapon].has("shot")
	# The draw counts from the press, even if the last arrow's follow-through is
	# not quite over: pressing again at once must not cost a second, hidden draw.
	if on and bow and not p.get("draw_held", false):
		p.draw_since = t
	p.draw_held = on and bow
	p.drawing = p.draw_held and p.swing.is_empty()

func set_duck(id: int, on: bool) -> void:
	ents[id].duck = on and ents[id].alive

## Sidestep (or roll) along dir: for a moment nothing can touch you.
func request_dodge(id: int, dir: Vector3, rolling := false) -> String:
	var p: Dictionary = ents[id]
	# Seized by a Trolloc: Space twists free (at a cost in breath), and that is all.
	if p.get("grabbed_by", 0) != 0 and p.chained > t:
		p.chained = 0.0
		var g: Dictionary = ents.get(p.grabbed_by, {})
		p.grabbed_by = 0
		p.stamina = maxf(p.stamina - 15.0, 0.0)
		if not g.is_empty():
			g.stagger = maxf(g.stagger, 0.5)
			p.shove = (p.pos - g.pos).normalized() * 4.0
		events.append({e = "broke_free", id = id})
		return ""
	if not p.alive or (not p.dash.is_empty() and not p.dash.has("lunge")) or p.reel_until > t:
		return "busy"
	if p.get("entranced", 0.0) > t:
		return "the song has you"
	if p.chained > t:
		return "chained"
	if p.get("downed", false):
		return "you are down"
	if p.get("tied", false):
		return "tied with rope"
	# Knocked down: the roll is how you get up, away from what put you there.
	if p.down > 0.0:
		p.down = 0.0
		rolling = true
		_rise(p, "roll")
	dir.y = 0.0
	# With no direction given it is a step back, out of reach, still facing them.
	var back := dir.length() <= 0.1
	dir = dir.normalized() if not back else -Vector3(sin(p.yaw), 0, cos(p.yaw))
	var d := Rules.dodge(p.profile, rolling)
	if back:
		d.dist *= 0.75
	if p.stamina < d.cost * 0.5:
		return "too tired"
	p.stamina = maxf(p.stamina - d.cost, 0.0)
	# Leaving is always possible: it abandons a blow or a weave half made.
	p.swing = {}; p.queued = {}; p.forming = {}; p.guard = false; p.drawing = false
	p.dash = {vel = dir * (d.dist / d.time), left = d.time}
	# A low wall or a wagon right ahead: over it, not into it.
	var over := Map.vault_over(p.pos, dir, 1.6, p.radius) if not back else 0.0
	if over > 0.0:
		var secs := maxf(d.time, over / 7.0)
		p.dash = {vel = dir * (over / secs), left = secs, vault = true}
	p.safe_until = t + maxf(d.safe, p.dash.left if over > 0.0 else 0.0)
	events.append({e = "dodge", id = id, roll = rolling, back = back, dir = dir, time = p.dash.left, vault = over > 0.0})
	return ""

## The friend a Healing aimed here would reach: the most hurt within reach of the
## aim point, never the Healer.
func _heal_target(p: Dictionary, aim: Vector3, reach: float) -> Dictionary:
	var best: Dictionary = {}
	for id in ents:
		var e: Dictionary = ents[id]
		if e.kind == "player" and e.alive and e.id != p.id and e.team == p.team and Vector2(e.pos.x - aim.x, e.pos.z - aim.z).length() < reach:
			if best.is_empty() or e.hp / e.max_hp < best.hp / best.max_hp:
				best = e
	return best

## Let go of a held weave (every hold of it, or only the one on `target`), and
## undo what it was doing.
func release(id: int, weave: String, target := -1) -> void:
	var p: Dictionary = ents[id]
	var kind: String = Rules.weaves[weave].kind
	for h in p.held.duplicate():
		if h.weave != weave or (target >= 0 and h.target != target):
			continue
		p.held.erase(h)
		if ents.has(h.target):
			var e: Dictionary = ents[h.target]
			if kind == "bind" and e.get("bound_by", 0) == id:
				e.bound_by = 0
			elif kind == "sever":
				e.severed = 0.0
		events.append({e = "release", id = id, weave = weave, target = h.target})
	if kind == "barrier":
		p.barrier = 0.0
	if kind == "gate":
		for fx in effects:
			if fx.kind == "gate" and fx.owner == id and not fx.get("gone", false):
				fx.gone = true
				# Folding shut, its edge cuts whatever stands in it.
				_gate_cut(fx.pos, id); _gate_cut(fx.to, id)

## Held weaves cost breath for as long as they are held, come undone when their
## knot runs out, and are lost with the one they were fastened on.
func _step_holds(p: Dictionary, dt: float) -> void:
	for h in p.held.duplicate():
		var gone: bool = h.target != 0 and not (ents.has(h.target) and ents[h.target].alive)
		if h.tied > 0.0:
			if t >= h.tied or gone:
				release(p.id, h.weave, h.target)
			continue
		if gone or (h.breaks > 0.0 and t >= h.breaks):
			if not gone:
				events.append({e = "broke", id = p.id, weave = h.weave, target = h.target})
			release(p.id, h.weave, h.target)
			continue
		var cost: float = Rules.draw_of(p.profile, h.weave, p.stamina) * Rules.TUNE.hold_upkeep * dt
		p.stamina -= cost
		tallies[p.id].draw += cost
		if p.stamina <= 0.0:
			# Nothing left to hold it with.
			p.stamina = 0.0
			release(p.id, h.weave, h.target)


func step(dt: float) -> void:
	if over:
		# The fight is done but the world is not frozen: the living still walk.
		for id in ents:
			var p: Dictionary = ents[id]
			if p.kind == "player" and p.alive and not p.get("downed", false):
				p.pos = Map.clamp_pos(Map.unblock(p.pos + p.move * p.speed * dt, p.radius))
		return
	t += dt
	# A round's field cleared early: the next wave comes in a few seconds, not when
	# its timer says.
	if round_mode and battle.is_empty() and not _waves.is_empty() and _waves[0].t > t + 6.0:
		var any_foe := false
		for id in ents:
			if ents[id].kind == "enemy" and ents[id].alive and ents[id].get("row", {}).get("speed", 1.0) > 0.0:
				any_foe = true; break
		if not any_foe:
			var shift: float = _waves[0].t - (t + 6.0)
			for w in _waves:
				w.t -= shift
	# Bots that belong to the fight itself (an Aes Sedai's Warder) are driven here,
	# so they fight the same on a server as on a desk.
	for id in ents:
		if ents[id].get("bot", false) and ents[id].alive:
			Bot.drive(self, id)
	if not ledger.is_empty() and ledger[0].t < t - 20.0:
		ledger = ledger.filter(func(h: Dictionary) -> bool: return h.t >= t - 20.0)
	if df_mode and not _df_assigned and t >= Round.DF_ASSIGN_T:
		_assign_darkfriends()
	while not _waves.is_empty() and _waves[0].t <= t:
		_spawn_wave(_waves.pop_front())
	var players: Array = []; var foes: Array = []
	var away := 0
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			# Someone whose connection dropped stands out of it (Session keeps the
			# place): not stepped, not hunted, but the fight is not over for them.
			if e.get("away", false):
				away += 1
				continue
			(players if e.kind == "player" else foes).append(e)
	for p in players:
		_step_player(p, dt)
	for e in players + foes:
		e.charge = maxf(e.get("charge", 0.0) - dt, 0.0)
		e.daze = maxf(e.get("daze", 0.0) - dt, 0.0)
		e.wet = maxf(e.get("wet", 0.0) - dt, 0.0)
		if e.burn > 0.0:
			e.burn -= dt
			_hurt(e, e.burn_dps * dt, e.burn_by, "", true)
		if e.get("fester", 0.0) > 0.0:
			e.fester -= dt
			_hurt(e, e.fester_dps * dt, 0, "", true)
		if e.get("bleed", 0.0) > 0.0:
			e.bleed -= dt
			_hurt(e, e.bleed_dps * dt, e.get("bleed_by", 0), "", true)
	_path_field(players)
	_step_enemies(foes, players, dt)
	_step_effects(dt)
	_step_patches(dt)
	# Outcome.
	if not battle.is_empty():
		_step_battle()
	elif _spar:
		if players.size() <= 1 and tallies.size() > 1:
			_finish(true)
	elif players.is_empty() and away == 0:
		# In the endless night, lasting long enough was already the win.
		_finish(_endless_won)
	elif df_mode and _df_assigned and players.all(func(q: Dictionary) -> bool: return q.get("darkfriend", false)):
		# Every loyal player dead: the Shadow's servant has won.
		_finish(false)
	elif round_mode and Rules.activities[activity_id].round.get("endless", false) and t >= float(Rules.activities[activity_id].round.get("win_at", 1800.0)) and not _endless_won:
		# Thirty minutes held: that is a win, whatever comes after. Fight on for the tale.
		_endless_won = true
		events.append({e = "endless_won", t = t})
	elif _waves.is_empty() and foes.is_empty() and t > 1.0:
		# In a Darkfriend round the waves outlasted are only half of it: every
		# Darkfriend must be dead or held (Shielded, or bound in Air) at the end.
		_finish(not df_mode or not _df_free())

## A few seconds in, once everyone is there: perhaps one player, perhaps two,
## secretly serve the Shadow. Each player is told only their own part. The more
## loyal players there are, the stronger a Darkfriend's roll (1d4 levels of mean
## per loyal player beyond one).
func _assign_darkfriends() -> void:
	_df_assigned = true
	var real := []
	for id in ents:
		if ents[id].kind == "player" and not ents[id].get("bot", false) and ents[id].alive:
			real.append(id)
	var n := real.size()
	var count := 0
	if n >= 3 and rng.randf() < (0.95 if n >= 4 else 0.8):
		count = 1
		if n >= 5 and rng.randf() < 0.6:
			count = 2
	var pool := real.duplicate()
	var dfs := []
	for i in count:
		dfs.append(pool.pop_at(rng.randi() % pool.size()))
	var loyal := n - count
	for id in real:
		var p: Dictionary = ents[id]
		if id in dfs:
			p.darkfriend = true
			p.df_gate = true
			var bonus := 0
			for k in maxi(loyal - 1, 0):
				bonus += rng.randi_range(1, 4)
			Round.strengthen(p.profile, bonus)
			events.append({e = "role", id = id, to = id, darkfriend = true, bonus = bonus, strength = Rules.level_of(Rules.strength(p.profile))})
		else:
			events.append({e = "role", id = id, to = id, darkfriend = false})

## Is any Darkfriend alive and free at the end?
func _df_free() -> bool:
	for id in ents:
		var p: Dictionary = ents[id]
		if p.get("darkfriend", false) and p.alive and p.get("severed", 0.0) <= t and p.get("bound_by", 0) == 0 and not p.get("tied", false):
			return true
	return false

## Did this player win? In a Darkfriend round the two sides win and lose apart.
func won(id: int) -> bool:
	if not battle.is_empty():
		return over and ents.get(id, {}).get("team", 0) == winner
	if not df_mode or not over:
		return success
	var df: bool = ents.get(id, {}).get("darkfriend", false)
	return (not success) if df else success

## The Darkfriend's one secret: a large gateway opens near them and the Shadow's own
## come through (blades with poisoned knives, archers, perhaps a channeller or two).
## A Darkfriend who channels must be strong enough for a gateway (19(7)); one who
## does not has it opened by one of those coming through. Once a game.
func request_df_gate(id: int) -> String:
	var p: Dictionary = ents.get(id, {})
	if p.is_empty() or not p.get("darkfriend", false) or not p.alive:
		return "busy"
	if not p.get("df_gate", false):
		return "already used"
	if p.get("downed", false):
		return "you are down"
	if p.profile.get("cls", "channeller") == "channeller" and Rules.level_of(Rules.strength(p.profile)) > Rules.weaves.gateway.get("level", 19):
		return "not yet strong enough to open a gateway"
	p.df_gate = false
	var side := Vector3(cos(p.yaw), 0, -sin(p.yaw))
	var at: Vector3 = p.pos + side * 5.0 + Vector3(sin(p.yaw), 0, cos(p.yaw)) * 2.0
	var come := {darkfriend_blade = 3, darkfriend_archer = 2}
	if rng.randf() < 0.6:
		come.dreadlord = 1 if rng.randf() < 0.7 else 2
	var first := _next
	for type in come:
		for i in int(come[type]):
			_add_enemy(type, at + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)))
	for k in range(first, _next):
		ents[k].df_side = true
	events.append({e = "df_gate", pos = at, yaw = p.yaw})
	return ""

## Balefire burns a thread out of the Pattern backwards: what it did in the last few
## seconds (longer from a stronger weaver) never happened. Those it killed stand
## again; what it did to the living is undone.
func _unmake(e: Dictionary, by: int) -> void:
	var src: Dictionary = ents.get(by, {})
	var back: float = Rules.TUNE.balefire_back * (Rules.reach(src.profile, "balefire", src.stamina) if src.get("kind", "") == "player" else 1.0)
	var undone := {}
	for h in ledger:
		if h.by != e.id or h.t < t - back:
			continue
		var o: Dictionary = ents.get(h.on, {})
		if o.is_empty():
			continue
		if not undone.has(o.id):
			undone[o.id] = h    # the earliest harm in the window: how they stood before it
	for oid in undone:
		var o: Dictionary = ents[oid]
		var h: Dictionary = undone[oid]
		var was_dead: bool = not o.alive
		o.alive = true
		o.hp = maxf(h.hp, 1.0)
		o.downed = h.downed and o.get("downed", false)
		o.return_next = false
		o.burn = 0.0; o.fester = 0.0
		events.append({e = "unmade", id = oid, dead = was_dead})
		if was_dead:
			events.append(_intro(o))
	ledger = ledger.filter(func(h: Dictionary) -> bool: return h.by != e.id)
	events.append({e = "balefire_unmade", id = e.id, n = undone.size()})

# --- linking (canon) -----------------------------------------------------------
## A woman leads a circle; those within reach who have offered to link join it. Men
## can link only into a woman's circle, never with each other. The leader weaves
## with the circle's strength; the others cannot channel, and none leave unless the
## leader lets them go (or a heavy blow, or going down, knocks them out of it).

func _woman_channeller(p: Dictionary) -> bool:
	return p.profile.get("cls", "channeller") == "channeller" and p.profile.get("power", "") == "saidar"

## L: offer to link; if you are a woman, lead those near you who have offered; if
## you lead, let everyone go.
func request_link(id: int) -> String:
	var p: Dictionary = ents.get(id, {})
	if p.is_empty() or not p.alive or p.get("downed", false):
		return "busy"
	if p.profile.get("cls", "channeller") != "channeller":
		return "only those who channel can link"
	if p.get("circle_of", 0) != 0:
		return "only the circle's leader can let you go"
	if not p.get("circle", []).is_empty():
		_dissolve(p)
		return ""
	p.link_open = t + 8.0
	var leader := p if _woman_channeller(p) else {}
	if leader.is_empty():
		# A man can be brought into a circle only by a woman: one leading near him.
		for k in ents:
			var o: Dictionary = ents[k]
			if o.kind == "player" and o.alive and not o.get("circle", []).is_empty() and o.pos.distance_to(p.pos) < Rules.TUNE.link_reach:
				leader = o
		if leader.is_empty():
			events.append({e = "link_open", id = id})
			return ""
	_gather(leader)
	return ""

func _gather(leader: Dictionary) -> void:
	if not leader.has("circle"):
		leader.circle = []
	for k in ents:
		var o: Dictionary = ents[k]
		if o.kind == "player" and o.alive and k != leader.id and o.get("link_open", 0.0) > t and o.get("circle_of", 0) == 0 \
				and o.get("circle", []).is_empty() and o.pos.distance_to(leader.pos) < Rules.TUNE.link_reach and leader.circle.size() < 12:
			leader.circle.append(k)
			o.circle_of = leader.id
			o.forming = {}
			for h in o.get("held", []).duplicate():
				release(o.id, h.weave, h.target)
	if not leader.circle.is_empty():
		events.append({e = "linked", id = leader.id, members = leader.circle.duplicate()})

func _dissolve(leader: Dictionary) -> void:
	for k in leader.get("circle", []):
		if ents.has(k):
			ents[k].circle_of = 0; ents[k].link_open = 0.0
	events.append({e = "unlinked", id = leader.id, members = leader.get("circle", []).duplicate()})
	leader.circle = []

## Knocked out of the circle: a heavy blow, going down, dying.
func _drop_from_circle(o: Dictionary) -> void:
	var lid: int = o.get("circle_of", 0)
	if lid != 0 and ents.has(lid):
		ents[lid].circle.erase(o.id)
		events.append({e = "link_lost", id = o.id, leader = lid})
	o.circle_of = 0; o.link_open = 0.0
	if not o.get("circle", []).is_empty():
		_dissolve(o)

## How much stronger the leader weaves: each member adds 60% of their own strength
## (measured against the leader's).
func _circle_mult(p: Dictionary) -> float:
	var c: Array = p.get("circle", [])
	if c.is_empty():
		return 1.0
	var mine := maxf(Rules.strength(p.profile), 0.01)
	var add := 0.0
	for k in c:
		if ents.has(k) and ents[k].alive:
			add += Rules.TUNE.link_share * Rules.strength(ents[k].profile) / mine
	return 1.0 + add

# --- team battle -------------------------------------------------------------------

func _smaller_side() -> int:
	var n := {1: 0, 2: 0}
	for id in ents:
		var e: Dictionary = ents[id]
		if e.kind == "player" and e.get("team", 0) in [1, 2]:
			n[e.team] += 1
	return 1 if n[1] <= n[2] else 2

## Each side's end of the field: outside the wagon ring, facing each other across it.
func _base(team: int) -> Vector3:
	return Vector3(0, 0, -21.0 if team == 1 else 21.0)

## A few seconds in: fill both sides with bots up to the same number (and at least
## `fill`), so a few friends, or one player alone, still have a fight.
func _fill_battle() -> void:
	_filled = true
	var n := {1: 0, 2: 0}
	for id in ents:
		var e: Dictionary = ents[id]
		if e.kind == "player" and e.get("team", 0) in [1, 2]:
			n[e.team] += 1
	var want: int = maxi(maxi(n[1], n[2]), int(battle.get("fill", 2)))
	var names := ["Aram", "Bain", "Corlan", "Daved", "Elyas", "Faile", "Gareth", "Hurin", "Ila", "Jaim", "Kiruna", "Lan", "Morvrin", "Nynaeve", "Ostric", "Perrin"]
	var k := 0
	for side in [1, 2]:
		while n[side] < want:
			var nm: String = names[(k * 7 + side) % names.size()] + " (bot)"
			k += 1
			var pr: Dictionary
			if rng.randf() < 0.5:
				pr = Profile.make({name = nm, power = "saidin" if rng.randf() < 0.5 else "saidar"})
			else:
				pr = Profile.create({name = nm, cls = "warder", stat_pts = {might = 2, quickness = 2, endurance = 2}, kit = ["sword", "horse_bow"]})
			# (add_player puts it on the smaller side, which is this one.)
			add_player(pr, Vector3.ZERO, true)
			n[side] += 1

## Someone under one banner killed by the other: a point to the killer's side, and
## experience for that whole side.
func _battle_death(e: Dictionary, by: int) -> void:
	var killer: Dictionary = ents.get(by, {})
	var side: int = killer.get("team", 0)
	if side in [1, 2] and side != e.team:
		scores[side] += 1
		_gain(Round.xp_of({tier = 3.0}) * 2.0, side)
	events.append({e = "score", scores = scores.duplicate(), by = by, id = e.id})
	e.return_at = t + float(battle.get("respawn", 8))

func _step_battle() -> void:
	if not _filled and t > 2.0:
		_fill_battle()
	for id in ents:
		var p: Dictionary = ents[id]
		if p.kind == "player" and not p.alive and p.has("return_at") and t >= float(p.return_at):
			p.erase("return_at")
			p.alive = true
			p.hp = p.max_hp; p.stamina = p.get("stamina_max", Rules.TUNE.stamina)
			p.pos = _base(p.team) + Vector3(rng.randf_range(-2.0, 2.0), 0, 0)
			p.safe_until = t + 2.0
			p.burn = 0.0; p.stagger = 0.0; p.down = 0.0; p.wound = 0.0
			events.append({e = "wound", id = id, to = id, w = 0.0})
			events.append({e = "returned", id = id, lost = 0, strength = Rules.level_of(Rules.strength(p.profile))})
			events.append(_intro(p))
	var goal := int(battle.get("kills", 10))
	if scores[1] >= goal or scores[2] >= goal:
		_finish_battle(1 if scores[1] >= goal else 2)
	elif t >= float(battle.get("time", 720)) and scores[1] != scores[2]:
		_finish_battle(1 if scores[1] > scores[2] else 2)

var winner := 0

func _finish_battle(side: int) -> void:
	winner = side
	_finish(true)

func _finish(ok: bool) -> void:
	over = true; success = ok
	events.append({e = "over", success = ok})

## Down: no moving, no acting. A friend standing over you for two seconds brings
## you back, low on health and breath; the time runs out and you die.
func _step_downed(p: Dictionary, dt: float) -> void:
	p.move = Vector3.ZERO
	p.down_left -= dt
	var helped := false
	for id in ents:
		var o: Dictionary = ents[id]
		# (Someone tying you up is not helping you up.)
		if o.kind == "player" and o.alive and o.id != p.id and o.team == p.team and not o.get("downed", false) and o.get("tying", 0) != p.id and o.pos.distance_to(p.pos) < Round.REVIVE_REACH:
			helped = true
	p.revive_t = p.get("revive_t", 0.0) + dt if helped else maxf(p.get("revive_t", 0.0) - dt, 0.0)
	if p.revive_t >= Round.REVIVE_SECS:
		p.downed = false
		p.hp = p.max_hp * 0.25
		p.stamina = p.get("stamina_max", Rules.TUNE.stamina) * 0.2
		p.safe_until = t + 1.0
		events.append({e = "revived", id = p.id})
	elif p.down_left <= 0.0:
		p.downed = false
		p.down_hp = 0.0
		p.finishing = true
		# Left to die: the death is still the work of whoever put them down.
		_hurt(p, p.hp + 1.0, p.get("downed_by", 0), "", true)
		p.finishing = false

## Those who died come back as a wave arrives, where the defenders stand, with
## their potential and strength fallen by 1d6 levels.
func _return_dead() -> void:
	for id in ents:
		var p: Dictionary = ents[id]
		if p.kind != "player" or p.alive or not p.get("return_next", false):
			continue
		p.return_next = false
		var lost := rng.randi_range(1, 6)
		Round.weaken(p.profile, lost)
		p.alive = true
		p.hp = p.max_hp; p.stamina = p.get("stamina_max", Rules.TUNE.stamina)
		p.pos = Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(2.0, 4.0))
		p.safe_until = t + 2.0
		p.burn = 0.0; p.stagger = 0.0; p.down = 0.0; p.wound = 0.0
		events.append({e = "wound", id = id, to = id, w = 0.0})
		events.append({e = "returned", id = id, lost = lost, strength = Rules.level_of(Rules.strength(p.profile))})
		events.append(_intro(p))

func _spawn_wave(w: Dictionary) -> void:
	if round_mode:
		_return_dead()
	var training: bool = Rules.activities[activity_id].kind == "training"
	var first := _next
	for type in w.spawn:
		for i in int(w.spawn[type]):
			var ang := rng.randf_range(-0.7, 0.7)
			var d := rng.randf_range(8.0, 13.0) if training else rng.randf_range(38.0, 52.0)
			var at := Vector3(sin(ang) * d, 0, -cos(ang) * d)
			# A practice post is never put behind a tree: it could not be hit from
			# where the novice stands, and the exercise would never end.
			for attempt in 12:
				if not training or _clear_of_trees(Vector3.ZERO, at):
					break
				ang = rng.randf_range(-0.7, 0.7); d = rng.randf_range(8.0, 13.0)
				at = Vector3(sin(ang) * d, 0, -cos(ang) * d)
			_add_enemy(type, at if Map.m.is_empty() else Map.spawn(rng))
	# Trollocs brought by a Myrddraal are linked to it, and die when it does.
	var lord := 0
	for id in range(first, _next):
		if ents[id].row.get("links", false):
			lord = id
	if lord != 0:
		for id in range(first, _next):
			if id != lord and ents[id].row.get("tier", 1) <= 2:
				ents[id].lord = lord
	events.append({e = "wave", left = _waves.size()})

## Is the straight line from a to b free of tree trunks (with room to spare)?
func _clear_of_trees(a: Vector3, b: Vector3) -> bool:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	for tr in Map.trees():
		# A crate or a stake is shot over; a tree or a banner pole is not.
		if float(tr.h) < 1.6:
			continue
		var ap := Vector2(tr.x - a.x, tr.z - a.z)
		var u := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
		if (ap - ab * u).length() < tr.r + 1.2:
			return false
	return true

var _dist := PackedInt32Array()
var _dist_t := -9.0

## How far (in grid steps) every open cell is from the nearest player, going
## round walls: what an enemy with no clear line follows downhill.
func _path_field(players: Array) -> void:
	var g := Map.grid()
	if g.is_empty() or t - _dist_t < 0.4:
		return
	_dist_t = t
	var n: int = g.nx * g.nz
	_dist.resize(n); _dist.fill(1 << 20)
	var queue := PackedInt32Array()
	for p in players:
		var c := _cell(g, p.pos)
		if c >= 0:
			_dist[c] = 0; queue.append(c)
	var head := 0
	var nx: int = g.nx
	var blocked: PackedByteArray = g.blocked
	while head < queue.size():
		var c := queue[head]; head += 1
		var d := _dist[c] + 1
		var cx := c % nx
		for step in [-nx, nx, -1, 1]:
			var o: int = c + step
			if o < 0 or o >= n or (step == -1 and cx == 0) or (step == 1 and cx == nx - 1):
				continue
			if blocked[o] == 0 and _dist[o] > d:
				_dist[o] = d; queue.append(o)

func _cell(g: Dictionary, p: Vector3) -> int:
	var ix := int(floor((p.x - g.x0) / g.cell)); var iz := int(floor((p.z - g.z0) / g.cell))
	return iz * g.nx + ix if ix >= 0 and iz >= 0 and ix < g.nx and iz < g.nz else -1

## Which way an enemy should walk to reach its target: straight at it when
## nothing is in the way, otherwise along the shortest way round.
func _steer(e: Dictionary, target: Dictionary) -> Vector3:
	var to: Vector3 = target.pos - e.pos
	var g := Map.grid()
	if g.is_empty() or _dist.is_empty() or not Map.crosses(e.pos, target.pos, e.radius):
		return to.normalized()
	var c := _cell(g, e.pos)
	if c < 0:
		return to.normalized()
	var best := _dist[c]; var dir := Vector3.ZERO
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var ix: int = c % g.nx + dx; var iz: int = c / g.nx + dz
			if (dx == 0 and dz == 0) or ix < 0 or iz < 0 or ix >= g.nx or iz >= g.nz:
				continue
			var o: int = iz * g.nx + ix
			if g.blocked[o] == 0 and _dist[o] < best:
				best = _dist[o]
				dir = Vector3(g.x0 + (ix + 0.5) * g.cell, 0, g.z0 + (iz + 0.5) * g.cell) - e.pos
	return dir.normalized() if dir != Vector3.ZERO else to.normalized()

## A spear held still, point out: whatever runs onto it from the front meets the
## point first (once each, every two seconds), and is stopped.
func _spear_set(p: Dictionary) -> void:
	if p.weapon == "" or Rules.weapons[p.weapon].family != "spear" or p.move.length() > 0.1 or not p.swing.is_empty() or not p.dash.is_empty():
		p.set_in = {}
		return
	var reach: float = Rules.weapons[p.weapon].reach
	var facing := Vector3(sin(p.yaw), 0, cos(p.yaw))
	var was: Dictionary = p.get("set_in", {})
	var now := {}
	for e in _targets(p):
		if e.kind != "enemy" or e.row.get("speed", 1.0) <= 0.0:
			continue
		var to: Vector3 = (e.pos - p.pos) * Vector3(1, 0, 1)
		var d := to.length()
		if d < reach + e.radius and d > 0.1 and facing.dot(to / d) > 0.6:
			now[e.id] = true
			if not was.has(e.id) and t >= float(p.get("set_hit", {}).get(e.id, -9.0)):
				if not p.has("set_hit"): p.set_hit = {}
				p.set_hit[e.id] = t + 2.0
				e.stagger = maxf(e.stagger, 0.6)
				e.vel = to / d * 3.0
				e.atk = 0.0
				events.append({e = "set_spear", id = p.id, on = e.id})
				_wound(e, Rules.blow(p.profile, p.weapon, Rules.weapons[p.weapon].light[0], p.stamina) * 1.2, p.id, p.weapon, {}, to / d)
	p.set_in = now

## The Eyeless gaze: meet a Myrddraal's eyeless stare up close and fear grips you:
## weaving comes slowly and the feet drag. Those who fight with their hands have
## schooled themselves against it and feel it for half as long.
func _gaze(p: Dictionary) -> void:
	var facing := Vector3(sin(p.yaw), 0, cos(p.yaw))
	for id in ents:
		var e: Dictionary = ents[id]
		if e.kind != "enemy" or not e.alive or e.get("type", "") != "myrddraal":
			continue
		var to: Vector3 = (e.pos - p.pos) * Vector3(1, 0, 1)
		var d := to.length()
		if d < 14.0 and d > 0.1 and facing.dot(to / d) > 0.9 and not Map.crosses(p.pos, e.pos, 0.0, 1.6):
			var was: float = p.get("afraid", 0.0)
			p.afraid = t + (0.75 if p.profile.get("cls", "channeller") != "channeller" else 1.5)
			if was <= t:
				events.append({e = "gaze", id = p.id, by = e.id})
			return

func _step_player(p: Dictionary, dt: float) -> void:
	tallies[p.id].seconds += dt
	if p.get("tying", 0) != 0:
		_step_tying(p, dt)
	if p.get("downed", false):
		_step_downed(p, dt)
		return
	# The bond: a Warder and a channeller near each other both recover faster.
	var bonded := 1.0
	for id in ents:
		var o: Dictionary = ents[id]
		if o.kind == "player" and o.alive and o.id != p.id and o.team == p.team and o.pos.distance_to(p.pos) < Rules.TUNE.bond_reach \
				and [p.profile.get("cls", "channeller"), o.profile.get("cls", "channeller")] in [["warder", "channeller"], ["channeller", "warder"]]:
			bonded = Rules.TUNE.bond_regen
	p.stamina = minf(p.stamina + Rules.TUNE.stamina_regen * bonded * dt, p.get("stamina_max", Rules.TUNE.stamina))
	p.stagger = maxf(p.stagger - dt, 0.0)
	p.down = maxf(p.down - dt, 0.0)
	if p.get("lying", false) and p.down <= 0.0:
		var guarding: bool = p.get("rise_guard", false)
		_rise(p, "guard" if guarding else "slow")
		if guarding:
			p.rise_guard = false
			p.guard = true; p.parry_at = t; p.parry_free = t + Rules.TUNE.parry_again
	if p.get("grabbed_by", 0) != 0:
		var gb: Dictionary = ents.get(p.grabbed_by, {})
		if gb.is_empty() or not gb.alive or gb.stagger > 0.0 or p.chained <= t:
			# Let go: it died, reeled, or you were held as long as it could.
			p.grabbed_by = 0; p.chained = minf(p.chained, t)
	_gaze(p)
	_spear_set(p)
	# Left alone for a while, anyone catches their breath: bruises, not wounds.
	if t - p.get("hurt_t", -99.0) > Rules.TUNE.rest_after and p.burn <= 0.0:
		# Rest mends bruises, not wounds: those wait for a Healer.
		p.hp = minf(p.hp + p.max_hp * Rules.TUNE.rest_regen * dt, maxf(p.max_hp - p.get("wound", 0.0), p.hp))
	# Forming a weave takes concentration: you move at half speed while doing it.
	p.guard = t - p.parry_at <= Rules.TUNE.parry_window
	var slow: float = Rules.TUNE.form_slow if not p.forming.is_empty() else 1.0
	if not p.swing.is_empty() and not p.swing.struck: slow = minf(slow, Rules.TUNE.swing_slow)
	if p.guard: slow = minf(slow, Rules.TUNE.guard_slow)
	if p.duck: slow = minf(slow, Rules.TUNE.duck_slow)
	if p.get("drawing", false): slow = minf(slow, Rules.TUNE.draw_slow)
	if p.reel_until > t: slow = 0.0
	if p.get("afraid", 0.0) > t: slow = minf(slow, 0.8)
	# Knocked off your feet: you crawl, you do not run.
	if p.down > 0.0: slow = minf(slow, 0.25)
	# Backing away is slower than going forward, and much slower while weaving or
	# guarding: you cannot run full tilt backwards with your eyes on the foe.
	var facing := Vector3(sin(p.yaw), 0, cos(p.yaw))
	var back: float = -p.move.dot(facing)
	if back > 0.3:
		var careful: bool = not p.forming.is_empty() or p.guard or p.get("drawing", false)
		slow *= lerpf(1.0, 0.55 if careful else 0.7, clampf((back - 0.3) / 0.5, 0.0, 1.0))
	var step: Vector3 = p.move * p.speed * slow * dt
	if p.get("shove", Vector3.ZERO).length() > 0.2:
		# Thrown back by a blow: carried a step whatever the feet wanted.
		step += p.shove * dt
		p.shove = p.shove.lerp(Vector3.ZERO, minf(7.0 * dt, 1.0))
	if p.get("entranced", 0.0) > t:
		# A Draghkar's song: your feet take you to it, and nothing else is yours.
		var d: Dictionary = ents.get(p.get("entranced_by", 0), {})
		if d.is_empty() or not d.alive:
			p.entranced = 0.0
		else:
			var to: Vector3 = (d.pos - p.pos) * Vector3(1, 0, 1)
			step = to.normalized() * float(d.row.song.pull) * dt if to.length() > 1.4 else Vector3.ZERO
			p.forming = {}
	if not p.dash.is_empty():
		# A sidestep, a roll or a lunge carries you; your feet are not your own.
		step = p.dash.vel * dt
		if p.dash.has("lunge"):
			# A lunge stops at the body it is aimed at; it does not run through it.
			for e in _targets(p):
				if (p.pos + step).distance_to(e.pos) < p.radius + e.radius + 0.5:
					step = Vector3.ZERO
		p.dash.left -= dt
		if p.dash.left <= 0.0:
			p.dash = {}
			# A blow asked for in the roll comes out of it now.
			if p.get("queued", {}).get("from_roll", false) and p.swing.is_empty():
				var q: Dictionary = p.queued
				p.queued = {}
				p.rolled_at = t
				request_attack(p.id, q.kind, q.aim, q.charge)
	if p.get("bound_by", 0) != 0 or p.chained > t:
		step = Vector3.ZERO
	elif p.get("mired", 0.0) > t:
		step *= p.mire
	if dream:
		Dream.step_player(self, p, dt)
	p.pos = Map.clamp_pos(Map.unblock(p.pos + step, p.radius, not p.dash.get("vault", false)))
	_step_holds(p, dt)
	if not p.get("autos", []).is_empty() and not p.get("downed", false) and p.severed <= t:
		_step_autos(p)
	_step_swing(p, dt)
	if p.forming.is_empty():
		return
	# Held by an Eyeless gaze, the weave comes slowly.
	p.forming.left -= dt * (0.6 if p.get("afraid", 0.0) > t else 1.0)
	if p.forming.left > 0.0:
		return
	if p.forming.hold:
		# Whole, and held back in the hands until it is let go.
		if not p.forming.ready:
			p.forming.ready = true
			events.append({e = "ready", id = p.id, weave = p.forming.weave})
		return
	var weave: String = p.forming.weave
	var aim: Vector3 = p.forming.aim
	p.fasten = p.forming.get("target", 0)
	var row: Dictionary = Rules.weaves[weave]
	if row.kind in ["bind", "sever"]:
		# It fastens on whoever it is aimed at when it leaves, if anyone.
		var now := _aimed(p, row, aim)
		if now != 0:
			p.fasten = now
		if not (ents.has(p.fasten) and ents[p.fasten].alive):
			p.forming = {}
			events.append({e = "fizzle", id = p.id, weave = weave})
			return
	p.forming = {}
	var cost := Rules.draw_of(p.profile, weave, p.stamina)
	p.stamina = maxf(p.stamina - cost, 0.0)
	var tl: Dictionary = tallies[p.id]
	tl.draw += cost
	tl.casts[weave] = tl.casts.get(weave, 0) + 1
	p.cd[weave] = t + Rules.cooldown(p.profile, weave)
	_cast(p, weave, aim)

## A blow in progress: wind-up, the instant it lands, recovery, then whatever was
## asked for meanwhile.
func _step_swing(p: Dictionary, dt: float) -> void:
	if p.swing.is_empty():
		return
	p.swing.left -= dt
	if p.swing.left > 0.0:
		return
	if not p.swing.struck:
		_strike(p)
		# A flurry lands several times before the hands come back.
		var again: int = p.swing.get("again", int(Rules.moves[p.swing.move].get("repeat", 1)) - 1)
		if again > 0:
			p.swing.again = again - 1
			p.swing.left += float(Rules.moves[p.swing.move].get("gap", 0.12))
			return
		p.swing.struck = true
		p.swing.left += p.swing.recover
		p.chain_t = t + p.swing.recover + Rules.TUNE.chain_window
		if p.swing.left > 0.0:
			return
	p.swing = {}
	if not p.queued.is_empty():
		var q: Dictionary = p.queued
		p.queued = {}
		if float(q.get("draw_since", -1.0)) >= 0.0:
			p.draw_held = true; p.draw_since = q.draw_since
		request_attack(p.id, q.kind, q.aim, q.charge)

func _strike(p: Dictionary) -> void:
	var sw: Dictionary = p.swing
	var w: Dictionary = Rules.weapons[sw.weapon]
	var m: Dictionary = Rules.moves[sw.move]
	var dmg := Rules.blow(p.profile, sw.weapon, sw.move, p.stamina)
	var dir: Vector3 = sw.dir
	if m.get("missile", false):
		var shot: Dictionary = w.get("shot", w.get("throw", {}))
		p.ammo[sw.weapon] = p.ammo.get(sw.weapon, 0) - 1
		p.shot_free = t
		p.drawing = false
		var hand := _feet(p) + Vector3(0, 1.45, 0)
		var throw: Vector3 = sw.aim - hand
		throw = throw.normalized() if throw.length() > 0.5 else dir
		# A half-drawn bow throws a slow arrow that drops short and barely bites;
		# the last of the draw is where the power is.
		var pull: float = sw.charge if w.has("shot") else 1.0
		effects.append({kind = "missile", owner = p.id, weapon = sw.weapon, pos = hand + throw * 0.5, vel = throw * shot.speed * lerpf(0.35, 1.0, pull * pull),
			dmg = dmg * lerpf(0.15, 1.0, pull * pull), radius = 0.5, left = shot.range * lerpf(0.4, 1.0, pull), gravity = shot.gravity, stagger = shot.get("stagger", 0.0) * pull,
			push = shot.get("push", 0.0) * pull, id = _fx_id(), lit = w.family == "bow" and not w.shot.get("crank", false) and _by_fire(p.pos)})
		events.append({e = "loose", id = p.id, weapon = sw.weapon, left = p.ammo[sw.weapon], pull = pull, lit = effects[-1].lit})
		return
	var reach: float = w.reach * m.get("reach", 1.0)
	var found := []
	for e in _struck(p):
		var d: Vector3 = e.pos - p.pos
		var dist := d.length()
		if dist < reach + e.radius and (dist < 0.6 or absf(rad_to_deg(dir.signed_angle_to(d / dist, Vector3.UP))) < m.arc):
			found.append(e)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_squared_to(p.pos) < b.pos.distance_squared_to(p.pos))
	# What the blow does besides wound: the move's own effect on top of the
	# weapon's (a hammer staggers, a spear point shoves back, a knife does neither).
	var on: Dictionary = m.get("on_hit", {}).duplicate()
	var imp: Dictionary = w.get("impact", {})
	for key in imp:
		on[key] = maxf(float(on.get(key, 0.0)), float(imp[key]) * minf(float(m.get("dmg", 1.0)), 1.6))
	dmg *= float(sw.get("bonus", 1.0))
	if sw.has("push"):
		on.push = maxf(float(on.get("push", 0.0)), float(sw.push))
	# An edge opens a wound that goes on bleeding; blunt weapons do not.
	if w.family in ["sword", "knife", "axe", "spear"] and not m.get("blunt", false):
		on.bleed = dmg * 0.2
	var n := 0
	for e in found:
		if n >= int(m.get("hits", 1)):
			break
		if e.get("safe_until", 0.0) > t:
			continue
		# A blow straight after a parry, or on one who is down, goes in deeper.
		var open := (1.5 if p.get("riposte_until", 0.0) > t else 1.0) * (1.5 if e.get("down", 0.0) > 0.0 else 1.0)
		_wound(e, dmg * pow(0.7, n) * open, p.id, sw.weapon, on, dir)
		n += 1
	if n > 0:
		p.riposte_until = 0.0
	events.append({e = "strike", id = p.id, weapon = sw.weapon, move = sw.move, hits = n, pos = _feet(p) + dir * reach * 0.7 + Vector3(0, 1.1, 0), dir = dir, reach = reach})

## Steel (or a fist) reaching a body: guard and parry for a player on the
## receiving end, then the hurt and whatever the blow does besides.
func _wound(e: Dictionary, dmg: float, by: int, weapon: String, on: Dictionary, dir: Vector3) -> void:
	if e.kind == "player":
		var whole := dmg
		dmg = _guarded(e, dmg, ents[by], dir)
		if dmg < 0.0:
			return
		# Steel in the way takes the weight of the blow as well as its edge.
		if dmg < whole:
			on = {}
		dmg *= 1.0 - Rules.cls(e.profile).armour
	# A bandleader turns blades that come at it from the front: flank it, or break
	# its guard with a heavy blow, a form, or while it reels.
	var in_hand: bool = Rules.weapons.has(weapon) and not ents.get(by, {}).get("swing", {}).is_empty()
	if in_hand and e.kind == "enemy" and e.row.has("guards") and e.stagger <= 0.0 and e.down <= 0.0 and ents.has(by):
		var from: Vector3 = (ents[by].pos - e.pos) * Vector3(1, 0, 1)
		var facing := Vector3(sin(e.yaw), 0, cos(e.yaw))
		var heavy: bool = ents[by].get("swing", {}).get("heavy", false)
		if from.length() > 0.01 and facing.dot(from.normalized()) > 0.5:
			if heavy:
				e.stagger = maxf(e.stagger, 0.9)
				events.append({e = "guard_broken", id = e.id})
			else:
				dmg *= 1.0 - float(e.row.guards)
				on = {}
				events.append({e = "blocked", id = e.id, pos = _feet(e) + Vector3(0, 1.3, 0) + from.normalized() * 0.5})
	# Mail and lacquered scale turn a cut; a point finds the gaps.
	if in_hand and e.kind == "enemy" and e.row.has("armour"):
		var mv: String = ents[by].get("swing", {}).get("move", "")
		if Rules.moves.get(mv, {}).get("trail", "") != "lance":
			dmg *= 1.0 - float(e.row.armour)
	if on.has("stagger"):
		e.stagger = maxf(e.stagger, on.stagger)
		if e.kind == "player":
			e.reel_until = maxf(e.reel_until, t + on.stagger * 0.5)
	if on.has("down") and e.kind == "enemy" and not e.row.get("steady", false):
		e.down = maxf(e.down, on.down)
	# A player swept off their feet: on the ground, guard and weave lost, until
	# they roll up (Space), rise guarding, or it wears off.
	if on.has("down") and e.kind == "player" and e.alive and not e.get("downed", false):
		e.down = maxf(e.down, float(on.down))
		e.lying = true
		e.guard = false; e.swing = {}; e.queued = {}; e.forming = {}
		events.append({e = "knocked_down", id = e.id, secs = e.down})
	if on.has("push"):
		e.vel += dir * on.push
		if e.kind == "player":
			# (Players are moved by their own feet, not by vel: a shove is its own thing.)
			e.shove = dir * float(on.push)
	if on.has("bleed") and e.kind == "enemy" and not e.get("row", {}).get("steady", false):
		# Bleeding: a quarter of the blow again, over four seconds.
		e.bleed = maxf(e.get("bleed", 0.0), 4.0); e.bleed_dps = maxf(e.get("bleed_dps", 0.0), float(on.bleed) / 4.0); e.bleed_by = by
	# How hard it was knocked, for the view: a hammer blow should look like one.
	e.knock = float(on.get("push", 0.0)) + float(on.get("stagger", 0.0)) * 4.0
	_hurt(e, dmg, by, weapon)
	e.knock = 0.0

## What is left of a blow after the target's guard. -1: it never landed (parried).
func _guarded(target: Dictionary, dmg: float, attacker: Dictionary, dir: Vector3) -> float:
	var since: float = t - target.parry_at
	if since > Rules.TUNE.parry_window:
		return dmg
	# A parry only covers the front.
	var facing := Vector3(sin(target.yaw), 0, cos(target.yaw))
	if facing.dot(-dir) < 0.2:
		return dmg
	if since <= Rules.TUNE.parry_perfect:
		# Met at the last instant: nothing gets through, and the one who struck is
		# shaken, knocked back a step and left open.
		attacker.stagger = maxf(attacker.stagger, Rules.TUNE.parry_stagger)
		attacker.vel = -dir * Rules.TUNE.parry_shove
		if attacker.kind == "player":
			attacker.reel_until = t + Rules.TUNE.parry_stagger * 0.6
		else:
			attacker.atk = 0.0; attacker.swung = false; attacker.blow = {}
			if attacker.get("mode", "") != "":
				attacker.mode = "rest"; attacker.mode_t = Rules.TUNE.parry_stagger
		target.riposte_until = t + 2.0
		target.parry_free = t   # a clean parry can be followed by another at once
		events.append({e = "parry", id = target.id, from = attacker.id, perfect = true})
		return -1.0
	# In time, not perfect: the steel takes it, and the arm pays.
	var stopped := dmg * minf(Rules.guard_share(target.profile, target.weapon) * 1.4, 1.0)
	var cost: float = stopped * Rules.TUNE.guard_cost
	if cost > target.stamina:
		# The guard gives way: only what the breath paid for is stopped.
		stopped *= target.stamina / maxf(cost, 0.01)
		target.stamina = 0.0
		target.guard = false
		target.reel_until = t + 0.8
		events.append({e = "guard_break", id = target.id})
	else:
		target.stamina -= cost
		events.append({e = "block", id = target.id, from = attacker.id})
	return dmg - stopped

func _cast(p: Dictionary, weave: String, aim: Vector3) -> void:
	var w: Dictionary = Rules.weaves[weave]
	var b: Dictionary = w.base
	var k := Rules.scale(p.profile, weave, p.stamina) * _circle_mult(p)
	# The fight is decided on the ground plane, but weaves fly in three dimensions:
	# they leave the hand, can be aimed up or down, and land on real ground.
	var from: Vector3 = _feet(p)
	var hand := from + Vector3(0, 1.4, 0)
	var to := aim - from; to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector3(sin(p.yaw), 0, cos(p.yaw))
	var at := from + dir * minf(dist, b.get("range", 1e9))
	at.y = Terrain.height(at.x, at.z)
	var throw := aim - hand
	throw = throw.normalized() if throw.length() > 0.5 else dir
	# Lofted weaves leave the hand tilted up and then fall, so range is a skill.
	throw = (throw + Vector3.UP * tan(deg_to_rad(b.get("loft", 0.0)))).normalized()
	events.append({e = "cast", id = p.id, weave = weave, kind = w.kind, pos = from, at = at, dir = dir, k = k})
	if w.get("hold", false):
		# breaks: when the one held can throw it off (0 = never, while it is held).
		p.held.append({weave = weave, target = p.get("fasten", 0) if w.kind in ["bind", "sever"] else 0, tied = 0.0, breaks = 0.0})
		events.append({e = "hold", id = p.id, weave = weave, target = p.held[-1].target})
	# Size, reach and duration grow with the root of power (Rules.reach).
	var kr := clampf(sqrt(k), 0.5, 2.2)
	match w.kind:
		"bind":
			# Bonds of Air: wrapped and held where they stand. The strong strain
			# against it and in time break free; lesser things stay until let go.
			var e: Dictionary = ents.get(p.fasten, {})
			if e.is_empty() or not e.alive:
				release(p.id, weave, p.fasten)
			else:
				e.bound_by = p.id
				e.vel = Vector3.ZERO
				if e.kind == "player":
					e.forming = {}; e.swing = {}; e.guard = false
				var tier: float = e.get("row", {}).get("tier", 2.0)
				if tier >= 2.0:
					p.held[-1].breaks = t + b.hold * k / (tier - 1.0)
		"projectile":
			var n: int = b.get("count", 1)
			for i in n:
				var a := deg_to_rad(b.get("spread", 0.0)) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "projectile", owner = p.id, weave = weave, pos = hand + throw * 0.6, vel = throw.rotated(Vector3.UP, a) * b.speed,
					dmg = b.damage * k, radius = b.radius * kr, left = b.range * kr, gravity = b.get("gravity", 0.0), pierce = int(b.get("pierce", 0)), passed = [], id = _fx_id()})
		"cone":
			if _power_of(weave) == "air":
				_blow_out(p.pos, b.range * kr, dir, float(b.arc))
			for e in _struck(p):
				var d: Vector3 = e.pos - p.pos
				# Thrown back, some are knocked to a knee.
				if e.kind == "enemy" and d.length() < b.range * kr and rng.randf() < 0.35:
					e.down = maxf(e.down, 0.9)
				if d.length() < b.range * kr and absf(rad_to_deg(dir.signed_angle_to(d.normalized(), Vector3.UP))) < b.arc:
					e.vel = d.normalized() * b.push
					e.stagger = maxf(e.stagger, 0.3 + b.push * 0.04)
					_hurt(e, b.damage * k, p.id, weave)
		"line", "beam", "lash":
			var reach_m: float = b.range * kr
			match _power_of(weave):
				"water":
					var s := 3.0
					while s < reach_m:
						_puddle(p.pos + dir * s, 1.6)
						s += 4.5
				"earth":
					var s2 := 2.0
					while s2 < reach_m:
						_wreck_walls(p.pos + dir * s2, b.width * kr + 0.6)
						s2 += 1.5
					_raise_rubble(p.pos + dir * (reach_m * 0.55), dir, minf(6.0, reach_m * 0.4))
			for e in _struck(p):
				var d: Vector3 = e.pos - p.pos
				var along := d.dot(dir)
				if along > 0.0 and along < b.range * kr and (d - dir * along).length() < b.width * kr + e.radius:
					e.stagger = maxf(e.stagger, b.get("stagger", 0.0))
					e.vel += dir * b.get("push", 0.0)
					# A lash of Water wraps what it reaches and hauls it in, off its feet.
					if b.has("pull") and not e.get("row", {}).get("steady", false) and e.get("row", {}).get("speed", 1.0) > 0.0:
						e.vel = -d.normalized() * minf(float(b.pull), maxf(d.length() - 2.5, 0.0) * 2.5)
					_hurt(e, b.damage * k, p.id, weave)
		"strike":
			_blast(p.id, weave, at, b.radius * kr, b.damage * k)
		"burst":
			for i in int(b.count):
				var off: Vector3 = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * b.scatter
				effects.append({kind = "blast", owner = p.id, weave = weave, pos = at + (off if i > 0 else Vector3.ZERO), dmg = b.damage * k, radius = b.radius * kr,
					left = b.delay * rng.randf_range(0.5, 1.5), id = _fx_id()})
		"blossom":
			# Blossoms of Fire: a thin pillar of flame where it is aimed, which then
			# opens into a wide, low, slowly turning wheel of fire. The stronger the
			# weaver, the wider it opens (10 to 30 feet).
			effects.append({kind = "blossom", owner = p.id, weave = weave, pos = Vector3(at.x, 0, at.z), r = b.pillar_radius, age = 0.0,
				max = clampf(b.radius * sqrt(k), b.radius_min, b.radius_max), pillar = b.pillar, open = b.open, left = b.pillar + b.open + b.duration,
				dps = b.dps * k, dmg = b.damage * k, id = _fx_id()})
		"ring":
			# It rolls out the way it was thrown, a wedge and not a circle.
			effects.append({kind = "ring", owner = p.id, weave = weave, pos = p.pos, r = 0.5, max = b.radius * kr, speed = b.speed, dmg = b.damage * k,
				yaw = atan2(dir.x, dir.z), arc = float(b.get("arc", 180.0)), id = _fx_id()})
		"mover":
			var n: int = b.count
			for i in n:
				var a := deg_to_rad(b.spread) * ((i + 0.5) / n - 0.5)
				effects.append({kind = "mover", owner = p.id, weave = weave, pos = p.pos + dir * 2.5, vel = dir.rotated(Vector3.UP, a) * b.speed,
					dps = b.dps * k, radius = b.radius * kr, left = b.duration * kr, id = _fx_id()})
		"barrier":
			p.barrier = b.absorb * k
		"gate":
			# A gateway: a hole from here to there, open while it is held (or tied).
			# Anyone who steps into one side steps out of the other: friend or not.
			# Either end can lie flat: aimed at the ground close by, the near end is a
			# hole at your feet; aimed high into the air, the far end opens in the sky
			# and what comes through it falls.
			var ground_at := Terrain.height(at.x, at.z)
			var flat_a: bool = Vector2(at.x - p.pos.x, at.z - p.pos.z).length() < 4.0
			var sky: float = clampf(at.y - ground_at, 0.0, 30.0) if at.y - ground_at > 4.0 else 0.0
			var near_side: Vector3 = Map.clamp_pos(Map.unblock(p.pos + dir * (2.0 if flat_a else 1.6), 0.6))
			var far_side: Vector3 = Map.clamp_pos(Map.unblock(Vector3(at.x, 0, at.z) + (dir * 6.0 if flat_a else Vector3.ZERO), 0.6))
			var gid := _fx_id()
			effects.append({kind = "gate", owner = p.id, weave = weave, pos = near_side, to = far_side, id = gid, flat_a = flat_a, sky = sky, age = 0.0})
			events.append({e = "gate_open", id = gid, a = near_side, b = far_side, by = p.id, flat_a = flat_a, sky = sky})
			# Opening, its edge slices through whatever is where it forms.
			_gate_cut(near_side, p.id); _gate_cut(far_side, p.id)
		"heal":
			# Canon: you cannot Heal yourself.
			var best := _heal_target(p, at, b.range)
			if not best.is_empty():
				# Healing brings the fallen back from the edge: up off the ground.
				if best.get("downed", false):
					best.downed = false
					best.hp = 0.0
					best.safe_until = t + 1.0
					events.append({e = "revived", id = best.id, healed = true})
				best.hp = minf(best.hp + b.heal * k, best.max_hp)
				best.fester = 0.0
				# Healing closes wounds, as rest cannot.
				best.wound = maxf(best.get("wound", 0.0) - b.heal * k * 1.5, 0.0)
				events.append({e = "wound", id = best.id, to = best.id, w = best.wound / best.max_hp})
				events.append({e = "heal", id = best.id})
		"sever":
			# Held between them and the Source for as long as you hold it, or until
			# they force it.
			var e: Dictionary = ents.get(p.fasten, {})
			if e.is_empty() or not e.alive:
				release(p.id, weave, p.fasten)
			else:
				e.severed = 1e9
				e.forming = {}
				for h in e.get("held", []).duplicate():
					release(e.id, h.weave, h.target)
				p.held[-1].breaks = t + b.duration * 4.0 * k

var _fx := 0
func _fx_id() -> int:
	_fx += 1
	return _fx

## Who an attack by `p` can actually hurt. In a round a player's weaves, arrows and
## blows hurt friends as fully as foes (the user's ruling: friendly fire, always);
## aiming and the bots still choose only foes (_targets). Shadowspawn spare each other.
func _struck(p: Dictionary) -> Array:
	if not (round_mode and p.kind == "player"):
		return _targets(p)
	var out := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive and e.id != p.id and not e.get("gone", false):
			out.append(e)
	return out

## The plane of a gateway: both ends stand the same way (facing along the line from
## one to the other), so going through is simply moving by the offset between them.
## That is what lets the view show each end as a window onto the other.
func _gate_normal(fx: Dictionary) -> Vector3:
	var n: Vector3 = (fx.to - fx.pos) * Vector3(1, 0, 1)
	return n.normalized() if n.length() > 0.01 else Vector3.FORWARD

## One body and one gateway: crossing an upright end's plane within its width moves
## them by exactly the offset to the other end (out on the matching side, going the
## same way); standing on a flat end drops them through. Shadowspawn keep off unless
## thrown in, and die if they go through; out of a sky end is a fall.
func _gate_step(fx: Dictionary, e: Dictionary) -> void:
	var n := _gate_normal(fx)
	var across := Vector3(n.z, 0, -n.x)
	var sides := [[fx.pos, fx.to - fx.pos, fx.get("flat_a", false), 0], [fx.to, fx.pos - fx.to, fx.get("sky", 0.0) > 0.0, 1]]
	for side in sides:
		if side[3] == 1 and fx.get("sky", 0.0) > 0.0:
			continue   # a sky end cannot be walked into from below
		var o: Vector3 = side[0]
		var rel: Vector3 = (e.pos - o) * Vector3(1, 0, 1)
		var key := "gd%d_%d" % [fx.id, side[3]]
		var through := false
		if side[2]:
			through = rel.length() < 1.0     # a hole at your feet: you drop in
		else:
			var d := rel.dot(n)
			var lat := absf(rel.dot(across))
			var before: float = e.get(key, d)
			e[key] = d
			through = lat < 0.95 and absf(d) < 1.5 and before * d < 0.0
		if not through:
			# The Shadow's creatures keep off it (they are not thrown in).
			if _is_shadowspawn(e) and e.vel.length() < 2.0 and fx.age > 0.6 and rel.length() < 1.3:
				e.pos = o + (rel.normalized() if rel.length() > 0.01 else -n) * 1.35
			continue
		var spawn := _is_shadowspawn(e)
		if spawn and e.vel.length() < 2.0 and fx.age > 0.6:
			e.pos = o + (rel.normalized() if rel.length() > 0.01 else -n) * 1.35
			continue
		e.pos = Map.clamp_pos(e.pos + side[1] * Vector3(1, 0, 1))
		if side[2]:
			e.pos += n * 1.4                # out of a hole, a step clear of the far end
		e.gated = t + 0.35
		# Seen from the far end now: no immediate crossing back.
		var other := "gd%d_%d" % [fx.id, 1 - side[3]]
		e[other] = ((e.pos - (fx.to if side[3] == 0 else fx.pos)) * Vector3(1, 0, 1)).dot(n)
		var before_side: float = -signf(rel.dot(n)) if not side[2] else 0.0   # the side they came from
		events.append({e = "gate_pass", id = e.id, pos = e.pos, by = (side[1] as Vector3), origin = o, n = n, s = before_side})
		if spawn:
			events.append({e = "gate_kill", id = e.id})
			_hurt(e, e.hp + 9999.0, fx.owner, "gateway", true)
		elif side[3] == 0 and fx.get("sky", 0.0) > 0.0:
			# Out of the sky: a fall, and a hard landing.
			e.down = maxf(e.down, 1.4)
			_hurt(e, fx.sky * 3.5, 0, "", true)
		return

## A gateway's edge, as it opens or folds shut: whatever stands in it is cut, badly.
## (The weaver is spared at their own near end.)
func _gate_cut(at: Vector3, weaver: int) -> void:
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive and id != weaver and e.pos.distance_to(at) < 1.0 + e.radius * 0.5:
			e.stagger = maxf(e.stagger, 0.8)
			_hurt(e, Rules.TUNE.gate_cut, weaver, "gateway")
			events.append({e = "gate_cut", id = id, pos = e.pos})

## Trollocs, Myrddraal, Darkhounds and Draghkar: made by the Shadow, and killed by a
## gateway. A Darkfriend or a Dreadlord is only a man.
func _is_shadowspawn(e: Dictionary) -> bool:
	return e.kind == "enemy" and e.row.get("gen", "") in ["TROLLOC", "FADE", "HOUND", "DRAGHKAR"]

func _targets(p: Dictionary) -> Array:
	var out := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive and e.team != p.team and not e.get("gone", false):
			out.append(e)
	return out

## Where an entity stands in the world: the sim plane lifted onto the terrain.
func _feet(e: Dictionary) -> Vector3:
	return Vector3(e.pos.x, Terrain.height(e.pos.x, e.pos.z), e.pos.z)

## Where to aim a weave to hit an entity: its chest, raised to allow for the fall
## of a lofted weave. Bots use it; people learn it.
func aim_at(from: Dictionary, weave: String, target: Dictionary) -> Vector3:
	var b: Dictionary = Rules.weaves[weave].base
	var c := _feet(target) + Vector3(0, 1.1, 0)
	var d := Vector2(c.x - from.pos.x, c.z - from.pos.z).length()
	var secs: float = d / maxf(b.get("speed", 1e6), 1.0)
	c.y += 0.5 * b.get("gravity", 0.0) * secs * secs - d * tan(deg_to_rad(b.get("loft", 0.0)))
	return c

## Where to aim an arrow or a thrown weapon to hit a moving body: ahead of it, and
## above it by the drop over the flight.
func aim_missile(from: Dictionary, weapon: String, target: Dictionary) -> Vector3:
	var w: Dictionary = Rules.weapons[weapon]
	var s: Dictionary = w.get("shot", w.get("throw", {}))
	var c := _feet(target) + Vector3(0, 1.1, 0)
	var secs: float = Vector2(c.x - from.pos.x, c.z - from.pos.z).length() / maxf(s.get("speed", 30.0), 1.0)
	c += target.get("move", Vector3.ZERO) * secs * 0.8
	c.y += 0.5 * s.get("gravity", 0.0) * secs * secs
	return c

func _blast(owner: int, weave: String, at: Vector3, radius: float, dmg: float) -> void:
	events.append({e = "blast", weave = weave, pos = at, radius = radius})
	_mark_ground(owner, weave, at, radius)
	for e in _struck(ents[owner]):
		if (_feet(e) + Vector3(0, 1.0, 0)).distance_to(at) < radius + e.radius + 0.5 and e.get("safe_until", 0.0) <= t:
			_hurt(e, dmg, owner, weave)
	# Fire does not know who wove it: stand too close to your own and you burn.
	var me: Dictionary = ents[owner]
	var own: float = Rules.weaves[weave].get("self", 0.0)
	if own > 0.0 and me.alive and (_feet(me) + Vector3(0, 1.0, 0)).distance_to(at) < radius + me.radius:
		_hurt(me, dmg * own, owner, "")
		me.burn = maxf(me.burn, 2.0); me.burn_dps = 3.0; me.burn_by = owner

## quiet: damage over time, which should not flinch, re-ignite or flash every tick.
func _hurt(e: Dictionary, dmg: float, by: int, weave: String, quiet := false) -> void:
	if not e.alive or e.get("away", false):
		return
	# Arms and weaves are made to kill Trollocs. Between two people sparring they
	# would end it in a few blows, so they do a share of their work (dream-things
	# are made for this and do all of theirs).
	if _spar and e.kind == "player" and weave != "dream":
		# ...and no one blow takes more than a share of a body, or a strong
		# channeller ends a weak one before either has done anything.
		dmg = minf(dmg * Rules.TUNE.spar_dmg, e.max_hp * Rules.TUNE.spar_cap)
	# A Myrddraal is not where the blow lands, half the time, unless something
	# has hold of it.
	# Spirit is not a thing to step aside from: it is woven at what the creature is.
	var of_spirit: bool = Rules.weaves.has(weave) and Rules.weaves[weave].flows.keys() == ["spirit"]
	if not quiet and not of_spirit and e.kind == "enemy" and e.row.has("evades") and e.stagger <= 0.0 and e.get("bound_by", 0) == 0 and rng.randf() < float(e.row.evades):
		events.append({e = "slip", id = e.id})
		return
	if not quiet and Rules.weaves.has(weave):
		var on: Dictionary = Rules.weaves[weave].get("on_hit", {})
		# Burns, stuns and soakings last longer from a stronger weaver.
		var src: Dictionary = ents.get(by, {})
		var kr: float = Rules.reach(src.profile, weave, src.stamina) if src.get("kind", "") == "player" and src.profile.weaves.has(weave) else 1.0
		if on.has("burn"):
			e.burn = maxf(e.burn, on.burn * kr); e.burn_dps = on.get("burn_dps", 6.0); e.burn_by = by
			if e.get("tied", false):
				e.tied = false
				events.append({e = "untied", id = e.id, by = by, burnt = true})
		if on.has("stun"):
			e.stagger = maxf(e.stagger, on.stun * kr)
		# Lightning leaves what survives it charged: it runs wild and faster, and the
		# next thing to strike it sends the charge leaping to those nearby.
		# Water soaks: the soaked are slowed, and lightning finds them.
		if on.has("wet"):
			e.wet = maxf(e.get("wet", 0.0), on.wet * kr)
		if on.has("charge") and e.get("wet", 0.0) > 0.0:
			dmg *= 1.6
		if on.has("charge"):
			e.charge = maxf(e.get("charge", 0.0), on.charge); e.charge_dmg = dmg * 0.4; e.charge_new = true
		# Spirit leaves them with no purpose for a moment: no attack, no pursuit.
		if on.has("daze"):
			e.daze = maxf(e.get("daze", 0.0), on.daze)
			if e.kind == "enemy":
				e.atk = 0.0; e.swung = false; e.blow = {}
			else:
				e.forming = {}
		if on.has("down") and e.kind == "enemy" and not e.row.get("steady", false):
			e.down = maxf(e.down, on.down)
	# Darkhounds: steel wounds close almost as they open. The Power is what kills them.
	if e.kind == "enemy" and e.row.has("steel") and weave != "" and not Rules.weaves.has(weave):
		dmg *= float(e.row.steel)
	if e.get("barrier", 0.0) > 0.0:
		var soak := minf(e.barrier, dmg)
		e.barrier -= soak; dmg -= soak
		if e.barrier <= 0.0:
			release(e.id, "dome_of_air")
	# What each did, a few seconds back: balefire can burn it out of the Pattern.
	if by != 0 and dmg > 0.0:
		ledger.append({t = t, by = by, on = e.id, dmg = minf(dmg, maxf(e.hp, 0.0) + (e.get("down_hp", 0.0) if e.get("downed", false) else 0.0)), hp = e.hp, downed = e.get("downed", false)})
	if e.kind == "player" and (e.get("circle_of", 0) != 0 or not e.get("circle", []).is_empty()) and dmg >= e.max_hp * 0.25:
		_drop_from_circle(e)
	if e.get("downed", false):
		# Already down: what lands now comes off what is left, half a body more.
		e.down_hp -= dmg
		if e.down_hp > 0.0:
			return
		e.downed = false
		e.hp = 0.0
	else:
		e.hp -= dmg
		# A share of every real hurt is a wound: it stays until Healed, and rest
		# cannot mend past it (bruises mend; cuts and burns wait for a Healer).
		if e.kind == "player" and dmg > 0.0 and weave != "dream":
			var w0: float = e.get("wound", 0.0)
			e.wound = minf(w0 + dmg * 0.3, e.max_hp * 0.6)
			if int(e.wound * 50.0 / e.max_hp) != int(w0 * 50.0 / e.max_hp):
				events.append({e = "wound", id = e.id, to = e.id, w = e.wound / e.max_hp})
		# In a round a player goes down before they die, and a friend can bring them
		# back. Balefire leaves nothing to bring back.
		if e.hp <= 0.0 and e.kind == "player" and round_mode and weave != "balefire" and not e.get("finishing", false):
			e.hp = 0.0
			e.downed = true
			e.down_left = Round.DF_DOWN_SECS if df_mode else Round.DOWN_SECS
			e.down_hp = e.max_hp * 0.5
			e.revive_t = 0.0
			e.forming = {}; e.swing = {}; e.queued = {}; e.guard = false; e.drawing = false
			for h in e.get("held", []).duplicate():
				release(e.id, h.weave, h.target)
			events.append({e = "downed", id = e.id, secs = e.down_left, by = by})
			e.downed_by = by
			_drop_from_circle(e)
			return
	if dmg > 0.0:
		e.hurt_t = t
		# Pain ends the song, for the singer and for the one who hears it.
		if e.kind == "enemy" and e.get("mode", "") in ["sing", "lure", "kiss"]:
			_song_end(e)
		elif e.kind == "player" and not quiet and e.get("entranced", 0.0) > t and by != e.get("entranced_by", 0):
			e.entranced = 0.0
			events.append({e = "song_end", id = e.entranced_by, target = e.id})
	if not quiet and dmg > 0.0 and e.get("charge", 0.0) > 0.0 and not e.get("charge_new", false):
		# The charge leaves it for the two nearest of its own kind.
		e.charge = 0.0
		var near := []
		for id in ents:
			var o: Dictionary = ents[id]
			if o.alive and o.id != e.id and o.team == e.team and o.pos.distance_to(e.pos) < 5.0:
				near.append(o)
		near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_squared_to(e.pos) < b.pos.distance_squared_to(e.pos))
		for o in near.slice(0, 2):
			events.append({e = "arc", from = _feet(e) + Vector3(0, 1.2, 0), to = _feet(o) + Vector3(0, 1.2, 0)})
			o.stagger = maxf(o.stagger, 0.5)
			_hurt(o, e.get("charge_dmg", 10.0), by, weave, true)
	e.charge_new = false
	if not quiet:
		events.append({e = "hit", id = e.id, dmg = dmg, by = by, knock = e.get("knock", 0.0)})
	if e.hp <= 0.0:
		e.alive = false
		# The dead hold nothing.
		for h in e.get("held", []).duplicate():
			release(e.id, h.weave, h.target)
		# Trollocs linked to a Myrddraal die with it.
		if e.kind == "enemy" and e.row.get("links", false):
			for id in ents:
				var o: Dictionary = ents[id]
				if o.alive and o.get("lord", 0) == e.id:
					o.alive = false
					events.append({e = "die", id = o.id, by = by, linked = true})
		events.append({e = "die", id = e.id, by = by})
		if e.kind == "player":
			_drop_from_circle(e)
		if weave == "balefire":
			_unmake(e, by)
		# Dead in a round: back at the next wave, weaker for it. In a battle, back
		# at your own end in a few seconds, and a point to the other side.
		if not battle.is_empty() and e.kind == "player":
			_battle_death(e, by)
		elif round_mode and e.kind == "player":
			e.return_next = not df_mode    # no coming back in a Darkfriend round
		if round_mode and e.kind == "enemy":
			_gain(Round.xp_of(e.row), ents.get(by, {}).get("team", 0))
		if tallies.has(by) and weave != "":
			var tl: Dictionary = tallies[by]
			tl.kills[weave] = tl.kills.get(weave, 0) + 1

## Advance a projectile one hop; true if it struck an enemy, a tree or the ground.
func _fly(fx: Dictionary, owner: Dictionary, dt: float) -> bool:
	fx.vel.y -= fx.gravity * dt
	var stepv: Vector3 = fx.vel * dt
	fx.pos += stepv; fx.left -= stepv.length()
	# Through a gateway: what is thrown or woven goes on out of the other side.
	if fx.get("gated", 0.0) <= t:
		for g in effects:
			if g.kind != "gate":
				continue
			var n := _gate_normal(g)
			var across := Vector3(n.z, 0, -n.x)
			for side in [[g.pos, g.to, 0.0], [g.to, g.pos, g.get("sky", 0.0)]]:
				var base: Vector3 = side[0] + Vector3(0, Terrain.height(side[0].x, side[0].z) + side[2], 0)
				var now: Vector3 = fx.pos - base
				var was: Vector3 = now - stepv
				# Through the mouth's plane, within its width and height: on out of the other end.
				if signf(now.dot(n)) != signf(was.dot(n)) and absf(now.dot(across)) < 0.95 and now.y > -0.2 and now.y < 3.3:
					var far_base: Vector3 = side[1] + Vector3(0, Terrain.height(side[1].x, side[1].z) + (g.get("sky", 0.0) if side[1] == g.to else 0.0), 0)
					fx.pos = far_base + now
					fx.gated = t + 0.3
					events.append({e = "fx_gate", id = fx.get("id", 0), pos = fx.pos})
					break
	for e in _struck(owner):
		var f := _feet(e)
		if not fx.get("passed", []).has(e.id) and Vector2(f.x - fx.pos.x, f.z - fx.pos.z).length() < fx.radius * 0.5 + e.radius and fx.pos.y > f.y - 0.3 and fx.pos.y < f.y + (1.3 if e.get("duck", false) else 2.4) and e.get("safe_until", 0.0) <= t:
			fx.struck = e.id
			return true
	for tr in Map.trees():
		if Vector2(tr.x - fx.pos.x, tr.z - fx.pos.z).length() < tr.r + 0.25 and fx.pos.y < Terrain.height(tr.x, tr.z) + tr.h:
			return true
	# A wall stops what flies below its top: cover from arrows, and from fire.
	if Map.in_wall(fx.pos) or (dream and Dream.walled(self, fx.pos - stepv, fx.pos)):
		return true
	var gy := Terrain.height(fx.pos.x, fx.pos.z)
	if fx.pos.y <= gy:
		fx.pos.y = gy
		return true
	return false

# --- the ground changed for the round -------------------------------------------
# Fire catches in the grass and burns a while; Water leaves puddles that put fire
# out and soak whoever stands in them; Air blows fires out; Earth tears down stone
# and leaves rubble you can shelter behind. The view hears of each change by event.

var patches: Array = []        # {id, kind "fire" | "puddle", pos, r, until, by}

func _power_of(weave: String) -> String:
	var fl: Dictionary = Rules.weaves.get(weave, {}).get("flows", {})
	if weave == "balefire" or fl.is_empty():
		return ""
	var best := ""; var n := 0
	for k in fl:
		if int(fl[k]) > n or (int(fl[k]) == n and k == "fire"):
			best = k; n = int(fl[k])
	# Any fire in it sets grass alight, whatever else is in the weave.
	return "fire" if fl.has("fire") else best

func _mark_ground(owner: int, weave: String, at: Vector3, r: float) -> void:
	match _power_of(weave):
		"fire": _ignite(at, clampf(r * 0.8, 1.2, 4.0), owner)
		"water": _puddle(at, clampf(r, 1.5, 3.5))
		"air": _blow_out(at, r * 1.5)
		"earth": _wreck_walls(at, r)

func _ignite(at: Vector3, r: float, by: int) -> void:
	# The training yard is trampled and swept: nothing to burn. (Grass fire there
	# finished off the practice posts, which ends the exercise, before a novice had
	# tried what they came to try.)
	if Rules.activities.get(activity_id, {}).get("bare_ground", false):
		return
	for p in patches:
		# Wet ground does not burn.
		if p.kind == "puddle" and p.pos.distance_to(at) < p.r + r * 0.5:
			return
	for p in patches:
		if p.kind == "fire" and p.pos.distance_to(at) < p.r:
			p.until = maxf(p.until, t + 9.0); p.r = minf(maxf(p.r, r), 5.0)
			events.append({e = "patch", id = p.id, kind = "fire", pos = p.pos, r = p.r, secs = p.until - t})
			return
	var pa := {id = _fx_id(), kind = "fire", pos = Vector3(at.x, Terrain.height(at.x, at.z), at.z), r = r, until = t + 9.0, by = by}
	patches.append(pa)
	events.append({e = "patch", id = pa.id, kind = "fire", pos = pa.pos, r = r, secs = 9.0})

func _puddle(at: Vector3, r: float) -> void:
	_douse_props(at, r)
	var keep: Array = []
	for p in patches:
		if p.kind == "fire" and p.pos.distance_to(at) < p.r + r:
			events.append({e = "patch_end", id = p.id, doused = true})
		else:
			keep.append(p)
	patches = keep
	var pa := {id = _fx_id(), kind = "puddle", pos = Vector3(at.x, Terrain.height(at.x, at.z), at.z), r = r, until = t + 45.0, by = 0}
	patches.append(pa)
	events.append({e = "patch", id = pa.id, kind = "puddle", pos = pa.pos, r = r, secs = 45.0})

## Standing by a fire (a watch-fire still burning, or burning grass), an archer can
## light an arrow from it.
func _by_fire(at: Vector3) -> bool:
	for tr in Map.trees():
		if tr.get("prop", "") == "fire" and not tr.get("out", false) and Vector2(tr.x - at.x, tr.z - at.z).length() < 3.0:
			return true
	for pa in patches:
		if pa.kind == "fire" and Vector2(pa.pos.x - at.x, pa.pos.z - at.z).length() < pa.r + 1.5:
			return true
	return false

## The map's own fires (watch-fires, the camp's) put out by wind or water.
func _douse_props(at: Vector3, r: float) -> void:
	var trees := Map.trees()
	for i in trees.size():
		var tr: Dictionary = trees[i]
		if tr.get("prop", "") == "fire" and not tr.get("out", false) and Vector2(tr.x - at.x, tr.z - at.z).length() < r + float(tr.r):
			tr.out = true
			events.append({e = "prop_out", index = i})

func _blow_out(at: Vector3, r: float, dir := Vector3.ZERO, arc := 180.0) -> void:
	_douse_props(at, r * 0.6)
	var keep: Array = []
	for p in patches:
		var off: Vector3 = (p.pos - at) * Vector3(1, 0, 1)
		var inside: bool = off.length() < r + p.r and (dir == Vector3.ZERO or off.length() < 1.0 or absf(rad_to_deg(dir.signed_angle_to(off.normalized(), Vector3.UP))) < arc)
		if p.kind == "fire" and inside:
			events.append({e = "patch_end", id = p.id, blown = true})
		else:
			keep.append(p)
	patches = keep

## Stone walls (and rubble) within r of `at` are thrown down. Wagons are not stone.
func _wreck_walls(at: Vector3, r: float) -> void:
	for w in Map.walls().duplicate():
		if not w.look in ["stone", "rubble"]:
			continue
		var l := Map._local(w, at.x, at.z)
		var dx := maxf(absf(l.x) - float(w.hx), 0.0); var dz := maxf(absf(l.y) - float(w.hz), 0.0)
		if Vector2(dx, dz).length() < r:
			Map.remove_wall(int(w.wid))
			events.append({e = "wall_gone", wid = w.wid})

## A low ridge of rubble thrown up along a line of Earth: cover, for a while.
func _raise_rubble(from: Vector3, dir: Vector3, length: float) -> void:
	var mid := from + dir * length * 0.5
	var w := Map.add_wall({x = mid.x, z = mid.z, hx = 0.45, hz = length * 0.5, h = 0.85, yaw = 0.0, rot = atan2(dir.x, dir.z), look = "rubble", until = t + 30.0})
	events.append({e = "wall_up", wall = w})

func _step_patches(dt: float) -> void:
	var keep: Array = []
	for p in patches:
		if t >= p.until:
			events.append({e = "patch_end", id = p.id})
			continue
		keep.append(p)
		for id in ents:
			var e: Dictionary = ents[id]
			if not e.alive or e.get("gone", false):
				continue
			var f := _feet(e)
			if Vector2(f.x - p.pos.x, f.z - p.pos.z).length() > p.r + e.radius * 0.5 or f.y > p.pos.y + 1.0:
				continue
			if p.kind == "fire":
				# Burning grass: it catches whoever stands in it, friend or foe.
				e.burn = maxf(e.burn, 1.2); e.burn_dps = maxf(e.burn_dps, 5.0); e.burn_by = p.by
			else:
				# A puddle puts out the burning and soaks the rest.
				e.burn = 0.0
				e.wet = maxf(e.get("wet", 0.0), 1.0)
	patches = keep
	# Rubble settles back into the ground in time.
	for w in Map.walls().duplicate():
		if w.has("until") and t >= float(w.until):
			Map.remove_wall(int(w.wid))
			events.append({e = "wall_gone", wid = w.wid})

func _step_effects(dt: float) -> void:
	var keep: Array = []
	for fx in effects:
		var alive := true
		var owner: Dictionary = ents[fx.owner]
		match fx.kind:
			"projectile":
				# Fast weaves are stepped in short hops so they cannot pass through a target.
				var hops := maxi(int(ceil(fx.vel.length() * dt / 0.6)), 1)
				var hit := false
				for hop in hops:
					if hit or not alive:
						break
					hit = _fly(fx, owner, dt / hops)
					alive = fx.left > 0.0
					if hit and fx.has("struck") and fx.get("pierce", 0) > 0 and not fx.passed.has(fx.struck):
						# A dart of fire goes through the first body and on into the next.
						fx.passed.append(fx.struck)
						fx.pierce -= 1
						events.append({e = "pierce", weave = fx.weave, pos = fx.pos})
						_hurt(ents[fx.struck], fx.dmg, fx.owner, fx.weave)
						fx.dmg *= 0.75
						fx.erase("struck")
						hit = false
				if hit or not alive:
					_blast(fx.owner, fx.weave, fx.pos, fx.radius, fx.dmg)
					alive = false
			"missile":
				# An arrow, a knife, a javelin: it wounds the one body it meets.
				var hops := maxi(int(ceil(fx.vel.length() * dt / 0.6)), 1)
				var hit := false
				for hop in hops:
					if hit or not alive:
						break
					hit = _fly(fx, owner, dt / hops)
					alive = fx.left > 0.0
				if hit:
					alive = false
					if fx.has("struck"):
						var flat: Vector3 = fx.vel * Vector3(1, 0, 1)
						var mon := {}
						if fx.stagger > 0.0: mon.stagger = fx.stagger
						if fx.get("push", 0.0) > 0.0: mon.push = fx.push
						_wound(ents[fx.struck], fx.dmg, fx.owner, fx.weapon, mon, flat.normalized())
						if fx.get("lit", false):
							var hit_e: Dictionary = ents[fx.struck]
							hit_e.burn = maxf(hit_e.burn, 3.0); hit_e.burn_dps = maxf(hit_e.burn_dps, 6.0); hit_e.burn_by = fx.owner
					elif fx.get("lit", false):
						# A fire arrow in the grass: it catches.
						_ignite(fx.pos, 1.4, fx.owner)
					if fx.get("blast", 0.0) > 0.0:
						# Woven fire: it bursts where it lands, and scorches who stands near.
						events.append({e = "blast", weave = fx.weapon, pos = fx.pos, radius = fx.blast})
						for o in _struck(owner):
							if o.id != fx.get("struck", 0) and _feet(o).distance_to(fx.pos) < fx.blast + o.radius and o.get("safe_until", 0.0) <= t:
								_hurt(o, fx.dmg * 0.6, fx.owner, "")
					events.append({e = "stick", pos = fx.pos, weapon = fx.weapon, into = fx.get("struck", 0), dir = fx.vel.normalized()})
					# It lies where it fell, to be gathered up: thrown weapons always, an
					# arrow if it did not break.
					if Rules.weapons.has(fx.weapon) and (Rules.weapons[fx.weapon].has("throw") or rng.randf() < 0.6):
						var at: Vector3 = fx.pos
						at.y = Terrain.height(at.x, at.z)
						keep.append({kind = "drop", owner = fx.owner, weapon = fx.weapon, pos = at, left = 90.0, id = _fx_id()})
			"gate":
				alive = not fx.get("gone", false) and owner.alive
				fx.age = fx.get("age", 0.0) + dt
				for id in ents:
					var e: Dictionary = ents[id]
					if not alive or not e.alive or e.get("gated", 0.0) > t or e.get("row", {}).get("speed", 1.0) == 0.0:
						continue
					_gate_step(fx, e)
			"dream_bolt", "dream_chain", "dream_pit", "dream_wall":
				alive = Dream.step_effect(self, fx, owner, dt)
			"doom":
				# Lightning called down on a marked circle: be out of it when it falls.
				fx.left -= dt
				alive = fx.left > 0.0 and owner.alive and owner.get("severed", 0.0) <= t and owner.stagger <= 0.0
				if fx.left <= 0.0 and owner.alive and owner.get("severed", 0.0) <= t:
					events.append({e = "doom_hit", pos = fx.pos, radius = fx.rad})
					for o in _struck(owner):
						if _feet(o).distance_to(fx.pos) < fx.rad + o.radius * 0.5 and o.get("safe_until", 0.0) <= t:
							_hurt(o, fx.dmg, fx.owner, "")
			"drop":
				fx.left -= dt
				alive = fx.left > 0.0
				for id in ents:
					var e: Dictionary = ents[id]
					if alive and e.alive and e.kind == "player" and e.ammo.has(fx.weapon) and Vector2(e.pos.x - fx.pos.x, e.pos.z - fx.pos.z).length() < 1.3:
						var row: Dictionary = Rules.weapons[fx.weapon]
						if e.ammo[fx.weapon] < int(row.get("shot", row.get("throw", {})).get("ammo", 0)):
							e.ammo[fx.weapon] += 1
							events.append({e = "pickup", id = e.id, weapon = fx.weapon, left = e.ammo[fx.weapon]})
							alive = false
			"blast":
				fx.left -= dt
				if fx.left <= 0.0:
					fx.pos.y = Terrain.height(fx.pos.x, fx.pos.z)
					_blast(fx.owner, fx.weave, fx.pos, fx.radius, fx.dmg)
					alive = false
			"ring":
				var r0: float = fx.r
				fx.r += fx.speed * dt
				var fwd := Vector3(sin(fx.yaw), 0, cos(fx.yaw))
				for e in _struck(owner):
					var off: Vector3 = e.pos - fx.pos
					var d: float = off.length()
					if d > r0 - e.radius and d <= fx.r and (d < 1.0 or absf(rad_to_deg(fwd.signed_angle_to(off / d, Vector3.UP))) < fx.arc + rad_to_deg(e.radius / maxf(d, 1.0))):
						e.stagger = maxf(e.stagger, 0.8)
						e.vel += fwd * 6.0
						_hurt(e, fx.dmg, fx.owner, fx.weave)
				alive = fx.r < fx.max
				if not alive:
					# The ring's teeth throw down stone in its path, and its fire catches.
					_wreck_walls(fx.pos + fwd * fx.max * 0.6, fx.max * 0.45)
					_ignite(fx.pos + fwd * fx.max * 0.7, 2.5, fx.owner)
			"blossom":
				fx.age += dt; fx.left -= dt
				var opening: float = clampf((fx.age - fx.pillar) / fx.open, 0.0, 1.0)
				var r1: float = lerpf(fx.r if fx.age < fx.pillar else 0.8, fx.max, opening * (2.0 - opening)) if fx.age >= fx.pillar else fx.r
				fx.rad = r1
				var hot: Array = _struck(owner)
				# Fire does not know who wove it.
				if owner.alive:
					hot.append(owner)
				for e in hot:
					if e.pos.distance_to(fx.pos) < r1 + e.radius and e.get("safe_until", 0.0) <= t:
						if not fx.get("seared", []).has(e.id):
							# The first touch of it is the worst.
							if not fx.has("seared"): fx.seared = []
							fx.seared.append(e.id)
							_hurt(e, fx.dmg * (0.4 if e.id == fx.owner else 1.0), fx.owner, fx.weave if e.id != fx.owner else "")
						_hurt(e, fx.dps * dt * (0.4 if e.id == fx.owner else 1.0), fx.owner, fx.weave if e.id != fx.owner else "", true)
						e.burn = maxf(e.burn, 2.5); e.burn_dps = 5.0; e.burn_by = fx.owner
				alive = fx.left > 0.0
				if not alive:
					# It leaves the grass under it burning.
					_ignite(fx.pos, clampf(fx.max * 0.6, 1.5, 5.0), fx.owner)
			"mover":
				fx.pos += fx.vel * dt; fx.left -= dt
				for e in _struck(owner):
					if e.pos.distance_to(fx.pos) < fx.radius + e.radius:
						_hurt(e, fx.dps * dt, fx.owner, fx.weave, true)
				alive = fx.left > 0.0
		if alive:
			keep.append(fx)
		else:
			events.append({e = "fx_end", id = fx.id})
	effects = keep

func _step_enemies(foes: Array, players: Array, dt: float) -> void:
	# Coarse grid so crowd separation stays cheap with hundreds of Trollocs.
	var grid := {}
	for e in foes:
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(e)
	# A crowd cannot all swing at once without hitting each other: only a few
	# press an attack on one person at a time, and the rest hang at arm's length.
	var pressing := {}
	for e in foes:
		if not e.blow.is_empty() and e.get("victim", 0) != 0:
			pressing[e.victim] = pressing.get(e.victim, 0) + 1
	for e in foes:
		e.stagger = maxf(e.stagger - dt, 0.0)
		e.down = maxf(e.down - dt, 0.0)
		e.vel = e.vel.lerp(Vector3.ZERO, minf(4.0 * dt, 1.0))
		var want := Vector3.ZERO
		var target: Dictionary = {}
		var best := 1e9
		for p in players:
			if p.get("darkfriend", false) and (e.get("df_side", false) or e.row.get("darkfriend", false)):
				continue    # they know their own
			var d: float = p.pos.distance_squared_to(e.pos)
			if d < best:
				best = d; target = p
		e.chasing = target.get("id", 0)
		if e.get("bound_by", 0) != 0:
			e.vel = Vector3.ZERO
		var free: bool = not target.is_empty() and e.speed > 0.0 and e.stagger <= 0.0 and e.down <= 0.0 and e.get("bound_by", 0) == 0
		if free and e.get("daze", 0.0) > 0.0:
			# Dazed by Spirit: it drifts, and does nothing it meant to.
			free = false
			want = Vector3(sin(e.id * 2.4 + t * 0.7), 0, cos(e.id * 2.4 + t * 0.7)) * e.speed * 0.25
			e.yaw = atan2(want.x, want.z)
		var shot: Dictionary = e.row.get("ranged", {})
		var far: float = target.pos.distance_to(e.pos) if not target.is_empty() else 0.0
		# Darkhounds mend when left alone.
		if e.row.has("regen") and t - e.get("hurt_t", -99.0) > float(e.row.regen.after) and e.hp < e.max_hp:
			e.hp = minf(e.hp + float(e.row.regen.rate) * dt, e.max_hp)
		var cut_off: bool = e.get("severed", 0.0) > t
		if e.row.has("strike") and free and not cut_off and far < float(e.row.strike.range) and t >= e.get("strike_at", float(e.row.strike.first)):
			# A Dreadlord marks the ground under you, and the lightning follows.
			var K: Dictionary = e.row.strike
			e.strike_at = t + float(K.every) * rng.randf_range(0.8, 1.2)
			var at: Vector3 = target.pos + target.move * target.speed * 0.4
			at.y = Terrain.height(at.x, at.z)
			effects.append({kind = "doom", owner = e.id, pos = at, left = float(K.wind), rad = float(K.radius), dmg = float(K.dmg), weave = "doom", id = _fx_id()})
			events.append({e = "doom", id = e.id, pos = at, radius = float(K.radius), time = float(K.wind)})
		if e.row.has("song") and not target.is_empty() and _draghkar(e, target, free, dt):
			want = e.want
		elif (e.row.has("lunge") or e.row.has("pounce")) and not target.is_empty() and (e.get("mode", "") == "gone" or free) and _fade(e, target, players, dt):
			want = e.want
		elif free and not shot.is_empty() and not cut_off and not e.swung and far > shot.keep * 0.45:
			# An archer: close to bowshot, stand, draw, loose. Pressed close, it
			# falls back on its blade like any other.
			e.yaw = atan2(target.pos.x - e.pos.x, target.pos.z - e.pos.z)
			e.blow = {}
			# No clear line (a wall, a wagon, a tree in the way): move until there is one.
			# (A waist-high breastwork is shot over; ducking behind it is the cover.)
			if far > shot.range or Map.crosses(e.pos, target.pos, 0.0, 1.6) or not _clear_of_trees(e.pos, target.pos):
				want = _steer(e, target) * e.speed
				e.atk = 0.0
			else:
				e.atk += dt
				# One who channels is seen to gather it first.
				if shot.has("wind") and e.atk >= shot.time - shot.wind and not e.get("told", false):
					e.told = true
					events.append({e = "channel", id = e.id, time = float(shot.wind)})
				if e.atk >= shot.time:
					e.atk = 0.0; e.told = false
					var from: Vector3 = _feet(e) + Vector3(0, 1.9, 0)
					var at: Vector3 = _feet(target) + Vector3(0, 0.65 if target.duck else 1.1, 0)
					var secs: float = Vector2(at.x - from.x, at.z - from.z).length() / shot.speed
					at += target.move * target.speed * secs * 0.7
					at.y += 0.5 * shot.gravity * secs * secs
					# Not every arrow is true.
					at += Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1, 1)) * far * 0.035
					var what: String = shot.get("weapon", "trolloc_arrow")
					effects.append({kind = "missile", owner = e.id, weapon = what, pos = from, vel = (at - from).normalized() * shot.speed,
						dmg = float(shot.dmg), radius = 0.5, left = shot.range * 1.5, gravity = shot.gravity, stagger = 0.0, blast = float(shot.get("blast", 0.0)), id = _fx_id()})
					events.append({e = "loose", id = e.id, weapon = what, left = 0})
		elif free:
			var to: Vector3 = target.pos - e.pos
			var dist := to.length()
			if e.swung:
				# Committed: it no longer turns, and it carries forward into the blow.
				# Step out of its line and it misses.
				e.atk += dt
				# (A step into it, no more: it does not run through the one it is striking.)
				want = Vector3(sin(e.aim_yaw), 0, cos(e.aim_yaw)) * minf(e.speed * 0.6, 2.2) if dist > e.radius + target.radius + 0.5 else Vector3.ZERO
				if e.atk >= e.blow.time:
					_enemy_blow(e, players)
					e.atk = 0.0; e.swung = false; e.blow = {}
					if e.row.has("lunge"):
						# A Myrddraal does not stand and trade blows: one cut, and away.
						e.close_until = 0.0
						e.think = t + rng.randf_range(1.0, 2.0)
			else:
				e.yaw = atan2(to.x, to.z)
				if dist > e.row.reach * 1.7:
					want = _steer(e, target) * e.speed
					e.atk = 0.0; e.blow = {}
				else:
					# Close enough to begin the blow: it keeps coming as it winds up,
					# rather than stopping first and giving the game away.
					if dist > e.row.reach * 0.8:
						want = _steer(e, target) * e.speed * 0.85
					if e.blow.is_empty():
						if pressing.get(target.id, 0) >= int(Rules.TUNE.gang):
							e.move = want
							e.pos = Map.clamp_pos(Map.unblock(e.pos + e.vel * dt, e.radius))
							continue
						e.blow = _pick_blow(e, target, players)
						e.victim = target.id
						pressing[target.id] = pressing.get(target.id, 0) + 1
					e.atk += dt
					# The swing starts before the blow lands, so it can be seen coming.
					if e.atk >= e.blow.time - 0.4:
						e.swung = true; e.aim_yaw = e.yaw
						# What the view needs to show exactly where this blow will fall.
						events.append({e = "swing", id = e.id, target = target.id, kind = e.blow.kind, yaw = e.aim_yaw, arc = e.blow.arc,
							reach = e.blow.reach, height = e.blow.height, time = e.blow.time - e.atk})
		else:
			e.atk = 0.0; e.swung = false; e.blow = {}
			# Staggered, bound or dazed out of whatever it was about to do.
			if e.get("mode", "") in ["wind", "lunge", "appear"]:
				e.mode = "rest"; e.mode_t = 0.4
		var key := Vector2i(floori(e.pos.x / 2.0), floori(e.pos.z / 2.0))
		var push := Vector3.ZERO
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for o in grid.get(key + Vector2i(dx, dz), []):
					if o.id != e.id:
						var d: Vector3 = e.pos - o.pos
						var len := d.length()
						var min_d: float = e.radius + o.radius
						if len < min_d and len > 0.001:
							push += d / len * (min_d - len)
		# Charged by lightning, it runs half again as fast.
		if e.get("charge", 0.0) > 0.0:
			want *= 1.5
		# Soaked, it drags.
		if e.get("wet", 0.0) > 0.0 and e.get("mode", "") == "":
			want *= 0.6
		e.move = want
		e.pos = Map.clamp_pos(Map.unblock(e.pos + (want + e.vel) * dt + push * 0.5, e.radius))

## A Myrddraal does not simply walk up and swing. It circles at a few paces,
## watching; then it lunges along a line it has chosen (step off the line and it
## goes past, open), or closes for a cut, or is gone into a shadow and out of
## another behind you. True when it has decided its own movement this tick (in
## e.want); false leaves it to fight as anything else would.
func _fade(e: Dictionary, target: Dictionary, players: Array, dt: float) -> bool:
	var row: Dictionary = e.row
	# (A Darkhound's pounce is the same commitment as a Myrddraal's lunge, without
	# the stalking and the shadows.)
	var L: Dictionary = row.get("lunge", row.get("pounce", {}))
	var to: Vector3 = target.pos - e.pos
	var dist := to.length()
	var toward := to / maxf(dist, 0.01)
	e.want = Vector3.ZERO
	match e.get("mode", ""):
		"gone":
			e.mode_t -= dt
			if e.mode_t <= 0.0:
				# Out of the shadow at the victim's back.
				var behind := -Vector3(sin(target.yaw), 0, cos(target.yaw)).rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
				e.pos = Map.clamp_pos(Map.unblock(target.pos + behind * float(row.shadow.dist), e.radius))
				e.gone = false
				e.mode = "appear"; e.mode_t = float(row.shadow.appear)
				e.yaw = atan2(target.pos.x - e.pos.x, target.pos.z - e.pos.z)
				events.append({e = "fade_in", id = e.id, pos = e.pos})
			return true
		"appear":
			e.mode_t -= dt
			e.yaw = atan2(to.x, to.z)
			if e.mode_t <= 0.0:
				_fade_lunge(e, target, float(L.wind) * 0.75)
			return true
		"wind":
			# Committed: it no longer turns.
			e.mode_t -= dt
			e.yaw = e.aim_yaw
			if e.mode_t <= 0.0:
				e.mode = "lunge"; e.mode_t = float(L.dist) / float(L.speed); e.lunged = false
			return true
		"lunge":
			e.mode_t -= dt
			e.yaw = e.aim_yaw
			e.want = Vector3(sin(e.aim_yaw), 0, cos(e.aim_yaw)) * float(L.speed)
			if not e.lunged:
				for p in players:
					if p.alive and p.pos.distance_to(e.pos) < 1.5 + p.radius:
						e.lunged = true
						e.blow = {kind = "thrust", height = "mid", arc = 50.0, reach = 2.2, time = 0.0, dmg = row.damage * float(L.dmg), on = L.get("on", {})}
						_enemy_blow(e, players)
						e.blow = {}
						if e.get("mode", "") != "lunge":
							return true   # parried: it is already reeling
						e.mode_t = minf(e.mode_t, 0.08)
						break
			if e.mode_t <= 0.0:
				e.mode = "rest"; e.mode_t = 0.45 if e.lunged else float(L.open)
				if not e.lunged:
					# It went past: for a moment it is only a thing with its back to you.
					e.stagger = maxf(e.stagger, float(L.open))
					events.append({e = "miss", id = e.id})
			return true
		"rest":
			e.mode_t -= dt
			if e.mode_t <= 0.0:
				e.mode = ""; e.think = t + rng.randf_range(1.2, 2.6); e.side = 1.0 if rng.randf() < 0.5 else -1.0
			return true
	# Stalking. Mid-cut, or sent in to close, it fights like anything else.
	if e.swung or not e.blow.is_empty() or t < e.get("close_until", 0.0):
		return false
	e.yaw = atan2(to.x, to.z)
	if t >= e.get("think", 2.0 if row.has("shadow") else 0.5):
		var roll := rng.randf()
		if not row.has("shadow"):
			# A hound: spring if the line is clear, else just run them down.
			if dist >= float(L.min) and dist <= float(L.max) and not Map.crosses(e.pos, target.pos, e.radius):
				_fade_lunge(e, target, float(L.wind))
				return true
			# Too far, it keeps coming and looks again at once; too close, it bites.
			e.think = t + (0.0 if dist > float(L.max) else rng.randf_range(1.0, 2.0))
			return false
		if t >= e.get("shadow_at", float(row.shadow.first)) and (dist > float(L.max) or roll < 0.45):
			e.gone = true
			e.mode = "gone"; e.mode_t = float(row.shadow.gone)
			e.shadow_at = t + float(row.shadow.every)
			e.vel = Vector3.ZERO; e.burn = 0.0
			events.append({e = "fade_out", id = e.id, pos = e.pos})
			return true
		if dist >= float(L.min) and dist <= float(L.max) and not Map.crosses(e.pos, target.pos, e.radius) and roll < 0.8:
			_fade_lunge(e, target, float(L.wind))
			return true
		e.close_until = t + 2.5
		e.think = t + 2.5 + rng.randf_range(1.0, 2.0)
		return false
	if not row.has("stalk"):
		return false
	# Circle at a few paces: never still, never quite in reach.
	var keep := float(row.stalk)
	var side: Vector3 = toward.rotated(Vector3.UP, PI * 0.5 * e.get("side", 1.0))
	if dist > keep + 2.5:
		e.want = _steer(e, target) * e.speed
	else:
		e.want = (side + toward * clampf((dist - keep) * 0.6, -1.0, 1.0)).normalized() * e.speed * 0.5
	return true

## The Draghkar: it comes on the wing, where nothing on the ground can reach it,
## lands a bowshot short and sings. If the song is let run its course the one it
## sings to walks to it, helpless, and it feeds. Hurt it, or put something between
## you and it, and the song breaks. Returns true while it is doing any of this.
func _draghkar(e: Dictionary, target: Dictionary, free: bool, dt: float) -> bool:
	var S: Dictionary = e.row.song
	e.want = Vector3.ZERO
	var mode: String = e.get("mode", "")
	if not free and not e.get("gone", false):
		# Staggered, bound or dazed on the ground: it cannot sing.
		if mode in ["sing", "lure", "kiss"]:
			_song_end(e)
		return true
	match mode:
		"", "fly":
			if mode == "":
				e.mode = "fly"; e.gone = true; e.side = rng.randf_range(-1.2, 1.2)
				events.append({e = "aloft", id = e.id})
			# To a place a bowshot short of them, off to one side.
			# (The side is chosen once: aimed afresh each step it would circle for ever.)
			if not e.has("perch"):
				var from: Vector3 = (e.pos - target.pos) * Vector3(1, 0, 1)
				e.perch = (from.normalized() if from.length() > 0.5 else Vector3.FORWARD).rotated(Vector3.UP, e.side * 0.5)
			var perch: Vector3 = Map.clamp_pos(target.pos + e.perch * float(S.range) * 0.65)
			var to: Vector3 = perch - e.pos
			e.yaw = atan2(to.x, to.z)
			if to.length() < 1.5:
				e.mode = "land"; e.mode_t = 0.8; e.gone = false; e.erase("perch")
				e.pos = Map.unblock(e.pos, e.radius)
				events.append({e = "land", id = e.id})
			else:
				e.want = to.normalized() * float(S.fly)
		"land":
			e.mode_t -= dt
			e.yaw = atan2(target.pos.x - e.pos.x, target.pos.z - e.pos.z)
			if e.mode_t <= 0.0:
				e.mode = "sing"; e.mode_t = float(S.hold); e.victim = target.id
				events.append({e = "song", id = e.id, target = target.id, time = float(S.hold)})
		"sing", "lure", "kiss":
			var v: Dictionary = ents.get(e.get("victim", 0), {})
			if v.is_empty() or not v.alive:
				_song_end(e)
				return true
			var d: float = v.pos.distance_to(e.pos)
			e.yaw = atan2(v.pos.x - e.pos.x, v.pos.z - e.pos.z)
			if mode == "sing":
				if d > float(S.range) * 1.25 or Map.crosses(e.pos, v.pos, 0.0):
					_song_end(e)
					return true
				e.mode_t -= dt
				if e.mode_t <= 0.0:
					v.entranced = t + float(S.last); v.entranced_by = e.id; v.forming = {}
					e.mode = "lure"
					events.append({e = "entranced", id = v.id, by = e.id})
			elif mode == "lure":
				if v.get("entranced", 0.0) <= t:
					_song_end(e)
				elif d < 1.9:
					e.mode = "kiss"; e.mode_t = float(S.kiss)
					events.append({e = "kiss", id = e.id, target = v.id})
			else:
				# The kiss: what it takes is not blood.
				_hurt(v, v.max_hp * float(S.drain) * dt, e.id, "", true)
				e.mode_t -= dt
				if e.mode_t <= 0.0 or not v.alive:
					_song_end(e)
		"flee":
			# On the ground a moment longer, then up and away to come again.
			e.mode_t -= dt
			if e.mode_t <= 0.0:
				e.mode = "away"; e.mode_t = rng.randf_range(4.0, 6.5); e.gone = true; e.side = rng.randf_range(-1.2, 1.2)
				events.append({e = "aloft", id = e.id})
		"away":
			e.mode_t -= dt
			var out: Vector3 = (e.pos - target.pos) * Vector3(1, 0, 1)
			var around: Vector3 = out.normalized().rotated(Vector3.UP, PI * 0.5) if out.length() > 0.5 else Vector3.RIGHT
			e.want = (around + out.normalized() * clampf((20.0 - out.length()) * 0.2, -1.0, 1.0)).normalized() * float(S.fly) * 0.7
			e.yaw = atan2(e.want.x, e.want.z)
			if e.mode_t <= 0.0:
				e.mode = "fly"
	return true

func _song_end(e: Dictionary) -> void:
	var v: Dictionary = ents.get(e.get("victim", 0), {})
	if not v.is_empty() and v.get("entranced_by", 0) == e.id:
		v.entranced = 0.0
	events.append({e = "song_end", id = e.id, target = e.get("victim", 0)})
	e.mode = "flee"; e.mode_t = 1.2

## Choose the line and crouch: the lunge follows after `wind` seconds, along that
## line and no other.
func _fade_lunge(e: Dictionary, target: Dictionary, wind: float) -> void:
	var L: Dictionary = e.row.get("lunge", e.row.get("pounce", {}))
	# It aims a little ahead of where its victim is going.
	var at: Vector3 = target.pos + target.move * target.speed * 0.15
	e.aim_yaw = atan2(at.x - e.pos.x, at.z - e.pos.z)
	e.yaw = e.aim_yaw
	e.mode = "wind"; e.mode_t = wind
	events.append({e = "lunge", id = e.id, yaw = e.aim_yaw, wind = wind, dist = float(L.dist)})

## Which of its attacks an enemy tries next. Each has its own arc, reach, height
## and time, so each asks for a different answer; which it is depends on what the
## enemy holds and on what is in front of it, so it can be read and learned.
func _pick_blow(e: Dictionary, target := {}, players := []) -> Dictionary:
	var all: Array = e.row.get("attacks", [{kind = "chop", height = "over", arc = 30.0}])
	var list := all.filter(func(x: Dictionary) -> bool: return not x.has("arms") or e.arm in x.arms)
	if list.is_empty():
		list = all
	var weights: Array[float] = []
	var total := 0.0
	var dist: float = target.pos.distance_to(e.pos) if not target.is_empty() else 0.0
	var crowd := 0
	for p in players:
		if p.pos.distance_to(e.pos) < e.row.reach + 1.0:
			crowd += 1
	var long := 0.0; var heavy := 0.0
	for a in list:
		long = maxf(long, float(a.get("reach", 1.0))); heavy = maxf(heavy, float(a.get("dmg", 1.0)))
	for i in list.size():
		var a: Dictionary = list[i]
		# Its favourite comes first in the data; a rare one says so ("weight").
		var w := (2.0 if i == 0 else 1.0) * float(a.get("weight", 1.0))
		if not target.is_empty():
			# A high sweep over someone ducking is wasted, and it knows it.
			if target.get("duck", false) and a.get("height", "mid") == "high":
				w *= 0.01
			# ...and so is a trip at someone already on the ground.
			if target.get("down", 0.0) > 0.0 and a.get("height", "mid") == "low":
				w *= 0.01
			# Two in front of it: the wide one.
			if crowd >= 2 and float(a.get("arc", 30.0)) >= 55.0:
				w *= 3.0
			# At the edge of its reach: the long one.
			if dist > e.row.reach * 0.7 and float(a.get("reach", 1.0)) >= long and long > 1.1:
				w *= 3.0
			# Someone who keeps turning its blows gets the heavy one.
			if t - target.get("parry_at", -99.0) < 2.5 and float(a.get("dmg", 1.0)) >= heavy:
				w *= 2.5
		if a.kind == e.get("last_blow", ""):
			w *= 0.5
		weights.append(w); total += w
	var roll := rng.randf() * total
	var a: Dictionary = list[-1]
	for i in list.size():
		roll -= weights[i]
		if roll <= 0.0:
			a = list[i]
			break
	e.last_blow = a.kind
	return {kind = a.kind, height = a.get("height", "mid"), arc = float(a.get("arc", 30.0)), reach = e.row.reach * a.get("reach", 1.0),
		time = e.row.attack_time * a.get("time", 1.0), dmg = e.row.damage * a.get("dmg", 1.0), on = a.get("on", {})}

## The blow lands along the line it was committed to, on whoever is still there.
func _enemy_blow(e: Dictionary, players: Array) -> void:
	var dir := Vector3(sin(e.aim_yaw), 0, cos(e.aim_yaw))
	var b: Dictionary = e.blow
	var target: Dictionary = {}
	for p in players:
		var d: Vector3 = p.pos - e.pos
		var dist := d.length()
		# Exactly the wedge that was shown: no more reach than the weapon has.
		if p.alive and dist < b.reach + p.radius and (dist < 0.8 or absf(rad_to_deg(dir.signed_angle_to(d / dist, Vector3.UP))) < b.arc):
			if target.is_empty() or dist < target.pos.distance_to(e.pos):
				target = p
	if target.is_empty():
		# It cut air, and is open for a moment.
		e.stagger = maxf(e.stagger, 0.45)
		events.append({e = "miss", id = e.id})
		return
	# A Warder with guard raised beside a channeller takes the blow meant for them.
	if target.profile.get("cls", "channeller") == "channeller":
		for p in players:
			if p.id != target.id and p.alive and p.team == target.team and p.guard and p.profile.get("cls", "") == "warder" and p.pos.distance_to(target.pos) < Rules.TUNE.ward_reach:
				events.append({e = "ward", id = p.id, saved = target.id})
				target = p
				# However it came, the Warder's steel is in its way.
				dir = -Vector3(sin(p.yaw), 0, cos(p.yaw))
				break
	if target.safe_until > t or (b.height == "high" and target.duck) or (b.height == "low" and target.get("air_until", 0.0) > t):
		e.stagger = maxf(e.stagger, 0.3)
		events.append({e = "evade", id = target.id, from = e.id, duck = target.safe_until <= t})
		return
	events.append({e = "attack", id = e.id, target = target.id, kind = b.kind, push = float(b.get("on", {}).get("push", 0.0))})
	var hp0: float = target.hp
	_wound(target, b.dmg, e.id, "", b.get("on", {}), dir)
	# A Myrddraal's black blade: the wound festers until it is Healed or runs its course.
	if target.hp < hp0 and e.row.has("fester"):
		target.fester = float(e.row.fester.secs); target.fester_dps = float(e.row.fester.dps)
		events.append({e = "fester", id = target.id})
	# A burning Trolloc sets alight what it reaches.
	if e.burn > 0.0 and target.hp < hp0:
		target.burn = maxf(target.burn, 2.0); target.burn_dps = 3.0; target.burn_by = e.id
	# Sometimes a Trolloc that gets a blow in unguarded seizes you as well: held
	# until you twist free (a roll, Space), and its next blow comes quickly.
	if target.hp < hp0 and target.hp > 0.0 and target.kind == "player" and e.get("type", "").begins_with("trolloc") and not e.row.has("ranged") \
			and target.hp < hp0 - b.dmg * 0.5 and rng.randf() < 0.12 and target.get("grabbed_by", 0) == 0:
		target.grabbed_by = e.id
		target.chained = t + 2.0
		target.forming = {}; target.swing = {}
		e.atk = maxf(e.atk, e.blow.get("time", 1.0) * 0.6) if not e.blow.is_empty() else e.atk
		events.append({e = "grabbed", id = target.id, by = e.id})

## Compact state for clients: enough to draw the fight, nothing they could cheat with.
## The team's experience: every kill counts for everyone. Each team level carries
## every player's round copy on (Round.level_up) and gives them a choice to make.
func _gain(xp: float, side := 0) -> void:
	if not battle.is_empty():
		# Each side levels on its own kills.
		if not side in [1, 2]:
			return
		xps[side] += xp
		while xps[side] >= Round.xp_for(levels[side]):
			xps[side] -= Round.xp_for(levels[side])
			levels[side] += 1
			_level_side(levels[side], side)
		return
	team_xp += xp
	while team_xp >= Round.xp_for(team_level):
		team_xp -= Round.xp_for(team_level)
		team_level += 1
		_level_side(team_level, -99)

func _level_side(level: int, side: int) -> void:
		for id in ents:
			var p: Dictionary = ents[id]
			if p.kind != "player" or not p.profile.has("round") or (side != -99 and p.get("team", 0) != side):
				continue
			var out := Round.level_up(p.profile, level, rng)
			var hp0: float = p.max_hp
			p.max_hp = Rules.max_hp(p.profile)
			p.hp += p.max_hp - hp0
			p.speed = Rules.run_speed(p.profile)
			out.e = "level"; out.id = id; out.picks = p.profile.round.picks
			events.append(out)
			# Only one thing it could be: it is done, nobody need choose.
			var ch := Round.choices(p.profile)
			if ch.size() == 1:
				request_pick(id, ch[0].kind, ch[0].id)

## The team's level and how far to the next, for the view.
func round_meter() -> Array:
	if not battle.is_empty():
		# Both sides' levels, then the score: each view shows its own side's.
		return [levels[1], xps[1] / Round.xp_for(levels[1]), levels[2], xps[2] / Round.xp_for(levels[2]), scores[1], scores[2], maxf(float(battle.get("time", 720)) - t, 0.0)]
	return [team_level, team_xp / Round.xp_for(team_level)] if round_mode else []

## A player spends a level-up on their tree (Round.choices). "" or why not.
func request_pick(id: int, kind: String, choice: String) -> String:
	var p: Dictionary = ents.get(id, {})
	if p.is_empty() or not p.profile.has("round"):
		return "not in a round"
	var why := Round.pick(p.profile, kind, choice)
	if why != "":
		return why
	if kind == "weapon":
		var row: Dictionary = Rules.weapons[choice]
		p.ammo[choice] = int(row.get("shot", row.get("throw", {})).get("ammo", 0))
	if kind == "learn" and Rules.weaves[choice].has("hold"):
		pass
	events.append({e = "picked", id = id, kind = kind, choice = choice, picks = p.profile.round.picks})
	return ""

func snapshot() -> Dictionary:
	var es := []
	for id in ents:
		var e: Dictionary = ents[id]
		if e.alive:
			# Status bits: 1 burning, 2 knocked down, 4 stunned, 8 thrown.
			# Then for those who bear arms: 16 guarding, 32 ducking, 64 sidestepping or rolling.
			var st := (1 if e.burn > 0.0 else 0) | (2 if e.down > 0.0 else 0) | (4 if e.stagger > 0.0 else 0) | (8 if e.vel.length() > 2.0 else 0) \
				| (16 if e.get("guard", false) else 0) | (32 if e.get("duck", false) else 0) | (64 if e.get("safe_until", 0.0) > t else 0) \
				| (128 if e.get("bound_by", 0) != 0 else 0) | (256 if e.get("fester", 0.0) > 0.0 else 0) \
				| (512 if e.get("charge", 0.0) > 0.0 else 0) | (1024 if e.get("daze", 0.0) > 0.0 else 0) \
				| (2048 if not e.get("forming", {}).is_empty() else 0) | (4096 if e.get("wet", 0.0) > 0.0 else 0) | (8192 if e.get("gone", false) else 0) | (16384 if e.get("drawing", false) else 0) \
				| (32768 if e.get("entranced", 0.0) > t else 0) | (65536 if e.get("severed", 0.0) > t and e.kind == "enemy" else 0) \
				| (131072 if e.get("chained", 0.0) > t else 0) | (262144 if e.get("shaken", 0.0) > t or e.get("afraid", 0.0) > t else 0) | (524288 if e.get("downed", false) else 0)
			es.append([id, e.pos.x, e.pos.z, e.yaw, e.hp, e.get("stamina", 0.0), st, e.get("will", 0.0)])
	var fx := []
	for f in effects:
		fx.append([f.id, f.kind, f.pos.x, f.pos.z, f.get("rad", f.get("r", 0.0)), f.pos.y, f.get("weave", f.get("weapon", "")) + (":lit" if f.get("lit", false) else ""), f.get("yaw", 0.0)])
	return {t = t, ents = es, fx = fx, round = round_meter()}
