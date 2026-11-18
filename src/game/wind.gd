class_name Wind
## The air over the field, for the view only: a steady wind per map (some places
## blow hard one way all round), and gusts from weaves and blasts. Grass, banners,
## cloaks and hair all read it, so they lean the same way, and a low wind sound
## follows its strength. Set through two global shader parameters (project.godot
## [shader_globals]): wind_vec (the steady wind, m/s-ish) and gust (xyz where, w how hard).

static var steady := Vector3.ZERO
static var gust_at := Vector3.ZERO
static var gust_amt := 0.0
static var _player: AudioStreamPlayer

## Per map: [the way it blows, in degrees from +z; how hard, 0..1].
const MAPS := {tarwins_gap = [180.0, 0.75], wagon_ring = [60.0, 0.35], open = [130.0, 0.2], camp = [100.0, 0.25]}

## The way the steady wind blows on a map, for things built once (banners stream
## downwind from their poles).
static func way(map_id: String) -> Vector3:
	var w: Array = MAPS.get(map_id, MAPS.open)
	var a := deg_to_rad(float(w[0]))
	return Vector3(sin(a), 0, cos(a)) * float(w[1])

static func setup(map_id: String, host: Node) -> void:
	var w: Array = MAPS.get(map_id, MAPS.open)
	var a := deg_to_rad(float(w[0]))
	steady = Vector3(sin(a), 0, cos(a)) * float(w[1])
	gust_amt = 0.0
	_push()
	# The sound of it: low, and louder where it blows hard.
	# One player for the whole game, under the root, so it carries across scenes.
	if host and DisplayServer.get_name() != "headless":
		if not is_instance_valid(_player):
			Sfx.build()
			_player = AudioStreamPlayer.new(); _player.name = "WindSound"
			host.get_tree().root.add_child.call_deferred(_player)
			_player.stream = Sfx.bank.wind
			_player.autoplay = true
		_player.volume_db = linear_to_db(clampf(0.15 + float(w[1]) * 0.6, 0.05, 1.0)) - 14.0

## A blast or a weave of Air shoving the air outwards from `at`.
static func gust(at: Vector3, power := 1.0) -> void:
	gust_at = at
	gust_amt = maxf(gust_amt, power)
	_push()
	Debris.push(at, power)   # and what lies on the ground goes flying

static func step(dt: float) -> void:
	if gust_amt > 0.0:
		gust_amt = maxf(gust_amt - dt * 0.9, 0.0)
		_push()
	if is_instance_valid(_player):
		var base := clampf(0.15 + steady.length() * 0.6, 0.05, 1.0)
		_player.volume_db = linear_to_db(base + gust_amt * 0.5) - 14.0

## The wind felt at a place: the steady wind plus any gust blowing out from its centre.
static func at(p: Vector3) -> Vector3:
	var out := steady
	if gust_amt > 0.0:
		var d := (p - gust_at) * Vector3(1, 0, 1)
		var fall := clampf(1.0 - d.length() / 12.0, 0.0, 1.0)
		if d.length() > 0.01:
			out += d.normalized() * gust_amt * fall * 2.0
	return out

static func _push() -> void:
	RenderingServer.global_shader_parameter_set("wind_vec", steady)
	RenderingServer.global_shader_parameter_set("gust", Vector4(gust_at.x, gust_at.y, gust_at.z, gust_amt))
