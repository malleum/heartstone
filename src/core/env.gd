class_name Env
## What stands about a map answers what is done near it (the sim's half: Map's props
## and walls change, and the view hears by event):
##   torches, banners, stakes  knocked flat by Air, Earth or a heavy blow; a fallen one
##                             is shoved along the ground by Air; Air or Water puts a
##                             torch out, Fire lights it again
##   fires                     put out by Air or Water (Sim._douse_props), lit by Fire
##   barrels, crates, sacks    shoved by Air, burnt to nothing by Fire, smashed by Earth
##                             or a heavy blow
##   wagons                    shoved a little by Air, set alight by Fire (they burn,
##                             then fall in), wrecked by Earth or enough damage
## `power`: the weave's Power (Sim._power_of) or "blow" for a heavy hit of any kind.

const POLES := ["torch", "banner", "stake"]
const STORES := ["barrel", "crate", "sacks"]
const WAGON_HP := 260.0
const WAGON_BURN := 14.0
const STORE_BURN := 7.0
const MAX_SHOVE := 3.0       # how far a wagon can be pushed from where it stood

static func hit(sim: Sim, at: Vector3, r: float, power: String, dir := Vector3.ZERO, dmg := 0.0) -> void:
	var heavy := dmg >= 45.0 or power == "earth"
	var trees := Map.trees()
	var moved := false
	for i in trees.size():
		var tr: Dictionary = trees[i]
		var prop: String = tr.get("prop", "")
		if prop == "" or tr.get("gone", false):
			continue
		var off := Vector2(tr.x - at.x, tr.z - at.z)
		if off.length() > r + float(tr.r) + 0.4:
			continue
		var away: Vector2 = Vector2(dir.x, dir.z).normalized() if dir != Vector3.ZERO else (off.normalized() if off.length() > 0.05 else Vector2(1, 0))
		if prop in POLES:
			if not tr.get("fallen", false) and (power == "air" or heavy or (power == "water" and prop == "torch")):
				tr.fallen = true; tr.r = 0.12; tr.h = 0.3
				sim.events.append({e = "prop_fall", index = i, yaw = atan2(away.x, away.y)})
				moved = true
			elif tr.get("fallen", false) and power == "air":
				_shove(sim, i, tr, away * 1.6)
				moved = true
			if prop == "torch" and not tr.get("out", false) and power in ["air", "water"]:
				tr.out = true
				sim.events.append({e = "prop_out", index = i})
			elif prop == "torch" and tr.get("out", false) and power == "fire":
				# Fire lights it again (for good, until something puts it out).
				tr.out = false
				sim.events.append({e = "prop_lit", index = i})
		elif prop == "fire":
			if tr.get("out", false) and power == "fire":
				tr.out = false
				sim.events.append({e = "prop_lit", index = i})
		elif prop in STORES:
			if heavy:
				_gone(sim, i, tr, "smash")
				moved = true
			elif power == "fire" and not tr.has("burn_until"):
				tr.burn_until = sim.t + STORE_BURN
				sim.events.append({e = "prop_burn", index = i})
			elif power == "air":
				_shove(sim, i, tr, away * 1.4)
				moved = true
	if moved:
		Map._tgrid_n = -1
		Map._grid = {}
	for w in Map.walls().duplicate():
		if w.get("look", "") != "wagon":
			continue
		var l := Map._local(w, at.x, at.z)
		var dx := maxf(absf(l.x) - float(w.hx), 0.0); var dz := maxf(absf(l.y) - float(w.hz), 0.0)
		if Vector2(dx, dz).length() > r + 0.3:
			continue
		if power == "fire" and not w.has("burn_until"):
			w.burn_until = sim.t + WAGON_BURN
			sim.events.append({e = "wall_burn", wid = w.wid})
		if power == "air":
			var push := Vector2(dir.x, dir.z).normalized() if dir != Vector3.ZERO else (Vector2(w.x - at.x, w.z - at.z).normalized())
			var home: Vector2 = w.get("home", Vector2(w.x, w.z))
			w.home = home
			var to := Vector2(w.x, w.z) + push * 0.7
			if to.distance_to(home) <= MAX_SHOVE:
				var fx: float = w.x; var fz: float = w.z
				w.x = to.x; w.z = to.y
				Map._grid = {}
				sim.events.append({e = "wall_move", wid = w.wid, x = w.x, z = w.z, fx = fx, fz = fz})
		w.hp = float(w.get("hp", WAGON_HP)) - (dmg * (2.0 if power == "earth" else 1.0))
		if w.hp <= 0.0:
			_wreck(sim, w)

## Each tick: what is burning burns down.
static func step(sim: Sim) -> void:
	var trees := Map.trees()
	for i in trees.size():
		var tr: Dictionary = trees[i]
		if tr.has("burn_until") and not tr.get("gone", false) and sim.t >= float(tr.burn_until):
			_gone(sim, i, tr, "ash")
			Map._tgrid_n = -1; Map._grid = {}
	for w in Map.walls().duplicate():
		if w.has("burn_until") and sim.t >= float(w.burn_until):
			_wreck(sim, w)

static func _shove(sim: Sim, i: int, tr: Dictionary, by: Vector2) -> void:
	var to := Map.clamp_pos(Vector3(tr.x + by.x, 0, tr.z + by.y))
	var fx: float = tr.x; var fz: float = tr.z
	tr.x = to.x; tr.z = to.z
	sim.events.append({e = "prop_move", index = i, x = tr.x, z = tr.z, fx = fx, fz = fz})

static func _gone(sim: Sim, i: int, tr: Dictionary, how: String) -> void:
	tr.gone = true; tr.r = 0.0; tr.h = 0.0
	sim.events.append({e = "prop_gone", index = i, how = how})

static func _wreck(sim: Sim, w: Dictionary) -> void:
	if Map.remove_wall(int(w.wid)):
		sim.events.append({e = "wall_gone", wid = w.wid, how = "burnt" if w.has("burn_until") else "wrecked"})
