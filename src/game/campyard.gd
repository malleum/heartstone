class_name CampYard
extends Node3D
## The training yard, in the camp itself: practice posts off to the side of the
## doorways, and a small sim of your own (only you and the posts in it, so nobody else
## in the camp can be struck: no friendly fire) that takes your blows, rolls and weaves
## as a fight would. Knocking every post down counts as the yard's exercise (its first
## time teaches what it always taught); the posts stand up again.

# West of the middle, where no doorway stands (they arc from north round to east).
const MIDDLE := Vector2(-20.0, -9.0)
const SPOTS := [Vector2(-24.5, -9.0), Vector2(-23.5, -13.0), Vector2(-20.0, -14.5), Vector2(-16.5, -13.5), Vector2(-25.0, -5.0), Vector2(-22.0, -4.0)]
const RAIL := 9.0
const REACH := 11.0          # how near the middle you must be for clicks to be blows and weaves
const BACK_UP := 5.0         # seconds before a fallen post stands again

var camp: Node3D
var sim: Sim
var me := 0
var posts := {}              # post entity id -> {node, spot, down_at}
var fx := {}                 # sim effect id -> node
var forming: Node3D
var done_once := false

## Build it beside the camp (the camp's Map stays the camp's).
func setup(c: Node3D, profile: Dictionary) -> void:
	camp = c
	var keep := Map.state()
	sim = Sim.new("camp_yard", 7)
	Map.set_state(keep)
	sim._waves = []
	me = sim.add_player(profile, Vector3(MIDDLE.x + 4.0, 0, MIDDLE.y + 2.0))
	for i in SPOTS.size():
		_raise(i)
	# A ring of bales and a rail round the yard, so it reads as a place.
	var wood := Scenery._mat(Color(0.25, 0.18, 0.11))
	for k in 18:
		var a := TAU * k / 18.0
		if absf(wrapf(a - atan2(-MIDDLE.y, -MIDDLE.x), -PI, PI)) < 0.5:
			continue   # open toward the middle of the camp
		var p := MIDDLE + Vector2(cos(a), sin(a)) * RAIL
		var at := Vector3(p.x, Terrain.height(p.x, p.y), p.y)
		Scenery._box(self, Vector3(0.12, 1.0, 0.12), at + Vector3(0, 0.5, 0), wood)
		var q := MIDDLE + Vector2(cos(a + TAU / 18.0), sin(a + TAU / 18.0)) * RAIL
		var mid := (p + q) * 0.5; var d := q - p
		Scenery._box(self, Vector3(0.07, 0.07, d.length()), Vector3(mid.x, Terrain.height(mid.x, mid.y) + 0.85, mid.y), wood, Vector3(0, atan2(d.x, d.y), 0))

func _raise(i: int) -> void:
	var spot: Vector2 = SPOTS[i]
	sim._add_enemy("dummy", Vector3(spot.x, 0, spot.y))
	var id := sim._next - 1
	sim.ents[id].pos = Vector3(spot.x, 0, spot.y)
	sim.ents[id].speed = 0.0
	var n := _post_node()
	add_child(n)
	n.position = Vector3(spot.x, Terrain.height(spot.x, spot.y), spot.y)
	n.rotation.y = atan2(MIDDLE.x - spot.x, MIDDLE.y - spot.y)
	n.scale = Vector3(1, 0.05, 1)
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)
	posts[id] = {node = n, spot = i, down_at = -1.0}

## A practice post: a stake with a cross-bar and a sacking head.
static func _post_node() -> Node3D:
	var n := Node3D.new()
	var wood := Scenery._mat(Color(0.32, 0.22, 0.13))
	var straw := Scenery._mat(Color(0.62, 0.52, 0.3))
	Scenery._cyl(n, 0.09, 0.11, 1.9, Vector3(0, 0.95, 0), wood)
	Scenery._box(n, Vector3(1.0, 0.08, 0.08), Vector3(0, 1.35, 0), wood)
	Scenery._cyl(n, 0.2, 0.22, 0.45, Vector3(0, 1.75, 0), straw)
	Scenery._cyl(n, 0.24, 0.24, 0.5, Vector3(0, 1.1, 0), straw)
	return n

## Is someone at `pos` in the yard (so clicks are blows and weaves, not looking about)?
func near(pos: Vector3) -> bool:
	return Vector2(pos.x - MIDDLE.x, pos.z - MIDDLE.y).length() < REACH

## Each frame: the camp's walking is the truth, except in a roll (the sim carries you).
func step(dt: float, pos: Vector3, face: float) -> Vector3:
	# The posts are solid underfoot.
	for id in posts:
		if sim.ents.has(id) and sim.ents[id].alive:
			var c: Vector3 = sim.ents[id].pos
			var off := Vector2(pos.x - c.x, pos.z - c.z)
			if off.length() < 0.75 and off.length() > 0.001:
				off = off.normalized() * 0.75
				pos = Vector3(c.x + off.x, pos.y, c.z + off.y)
	var p: Dictionary = sim.ents[me]
	if p.dash.is_empty():
		p.pos = Vector3(pos.x, 0, pos.z)
		p.yaw = face
	sim.over = false
	sim.step(dt)
	_events()
	_fx()
	_posts_up()
	return Vector3(p.pos.x, pos.y, p.pos.z) if not p.dash.is_empty() else pos

func attack(aim: Vector3, heavy: bool) -> void:
	var p: Dictionary = sim.ents[me]
	if p.weapon == "" and not p.profile.get("kit", []).is_empty():
		sim.equip(me, p.profile.kit[0])
	sim.request_attack(me, "heavy" if heavy else "light", aim)

func cast(weave: String, aim: Vector3) -> void:
	sim.equip(me, "")
	var why := sim.request_cast(me, weave, aim, false)
	if why != "" and why != "busy":
		Toast.say(why.capitalize(), "", "warn", 1.5)
	if Launch.cmdline().has("ghost"):
		print("GHOST yard cast %s -> '%s'" % [weave, why])

func roll(dir: Vector3) -> void:
	sim.request_dodge(me, dir, true)

## The nearest standing post, for aiming at when nothing better is under the crosshair.
func nearest_post(from: Vector3) -> Vector3:
	var best := Vector3.ZERO; var bd := 1e9
	for id in posts:
		if sim.ents.has(id) and sim.ents[id].alive:
			var at: Vector3 = sim.ents[id].pos
			var d := at.distance_to(from)
			if d < bd:
				bd = d; best = at
	return Vector3(best.x, Terrain.height(best.x, best.z) + 1.2, best.z) if bd < 1e8 else from + Vector3(0, 1.2, -6)

func _events() -> void:
	var ev := sim.events.duplicate()
	sim.events.clear()
	var model: Node3D = camp.model
	for e in ev:
		if Launch.cmdline().has("ghost") and e.e in ["form", "cast", "blow", "strike", "dodge", "die"] and e.get("id", me) in [me] + posts.keys():
			print("GHOST yard %s %s" % [e.e, e.get("weave", e.get("move", ""))])
		match e.e:
			"form":
				if e.id == me and is_instance_valid(model):
					_end_form()
					forming = Weavefx.forming(camp, model, e.weave, float(e.time), model.get_meta("power", "saidar") if model.has_meta("power") else "")
			"cast":
				if e.id == me:
					_end_form()
					if is_instance_valid(model):
						# The hands throw it, as in a fight.
						var apc: AnimationPlayer = model.get_meta("anim")
						var cc := Hero.cast_clip(String(camp.profile.get("name", "")), e.weave)
						if apc.has_animation(cc):
							apc.play(cc, 0.1)
							camp.set_meta("busy_until", Time.get_ticks_msec() / 1000.0 + 0.9)
				Weavefx.cast(camp, e)
			"fizzle":
				_end_form()
			"blast":
				Weavefx.blast(camp, e.pos, e.radius, e.weave)
			"blow":
				if e.id == me and is_instance_valid(model):
					var ap: AnimationPlayer = model.get_meta("anim")
					var m: Dictionary = Rules.moves.get(e.move, {})
					var clip: String = m.get("clip", "Sword_Attack")
					if not ap.has_animation(clip): clip = "Sword_Attack"
					if ap.has_animation(clip):
						ap.play(clip, 0.08, clampf(ap.get_animation(clip).length * float(m.get("at", 0.4)) / maxf(float(e.wind), 0.05), 0.35, 4.0))
					Hero.stroke(model, e.move, e.wind, e.recover * 0.8, e.weapon)
					camp.set_meta("busy_until", Time.get_ticks_msec() / 1000.0 + float(e.wind) + float(e.recover))
					Sfx.play(camp, "whoosh", model.position + Vector3(0, 1.3, 0), -5.0, 1.3)
			"strike":
				if e.hits > 0:
					Sfx.play(camp, "thud", e.pos, 1.0, 1.25)
				Armsfx.trail(camp, model.position, e.dir, e.reach, Rules.moves.get(e.move, {}), 1, e.hits > 0)
			"dodge":
				if e.id == me and is_instance_valid(model):
					var ap2: AnimationPlayer = model.get_meta("anim")
					if ap2.has_animation("Roll"):
						ap2.play("Roll", 0.05, 1.6)
					camp.set_meta("busy_until", Time.get_ticks_msec() / 1000.0 + 0.6)
			"hit":
				if posts.has(e.id):
					var n: Node3D = posts[e.id].node
					if is_instance_valid(n):
						var tw := n.create_tween()
						tw.tween_property(n, "rotation:z", 0.12, 0.06)
						tw.tween_property(n, "rotation:z", 0.0, 0.18)
			"die":
				if posts.has(e.id):
					var post: Dictionary = posts[e.id]
					post.down_at = sim.t
					var n2: Node3D = post.node
					if is_instance_valid(n2):
						n2.create_tween().tween_property(n2, "rotation:x", -PI * 0.47, 0.4).set_ease(Tween.EASE_IN)
					_check_done()

func _end_form() -> void:
	if forming and is_instance_valid(forming):
		forming.queue_free()
	forming = null

## Every post down at once: the yard's exercise is done.
func _check_done() -> void:
	for id in posts:
		if posts[id].down_at < 0.0:
			return
	var profile: Dictionary = camp.profile
	if profile.is_empty():
		return
	var first: bool = not profile.get("done", {}).has("camp_training")
	var report := Progression.award(profile, sim.tallies[me], "camp_training", true)
	sim.tallies[me] = {casts = {}, kills = {}, blows = {}, draw = 0.0, effort = 0.0, seconds = 0.0}
	if not Launch.dev():
		Profile.save(profile)
	Toast.say("Every post down", ("You learned: " + ", ".join(report.filter(func(l: String) -> bool: return l.begins_with("Learned")))) if first else "They will stand again in a moment.", "good", 5.0)
	camp.call("_sheet")

func _posts_up() -> void:
	for id in posts.keys():
		var post: Dictionary = posts[id]
		if post.down_at >= 0.0 and sim.t - post.down_at > BACK_UP:
			if is_instance_valid(post.node):
				post.node.queue_free()
			sim.ents.erase(id)
			posts.erase(id)
			_raise(post.spot)

## Weaves in flight: drawn where the yard's sim has them.
func _fx() -> void:
	var live := {}
	for f in sim.effects:
		if not f.kind in ["projectile", "missile"]:
			continue
		live[f.id] = true
		if not fx.has(f.id):
			fx[f.id] = Weavefx.live(camp, f.kind, f.get("weave", f.get("weapon", "")), "")
		var n: Node3D = fx[f.id]
		if is_instance_valid(n):
			var was := n.position
			n.position = f.pos
			if was.distance_to(n.position) > 0.05 and was != Vector3.ZERO:
				n.basis = Basis.looking_at(n.position - was, Vector3.UP if absf((n.position - was).normalized().y) < 0.98 else Vector3.RIGHT)
	for id in fx.keys():
		if not live.has(id):
			if is_instance_valid(fx[id]):
				fx[id].queue_free()
			fx.erase(id)
