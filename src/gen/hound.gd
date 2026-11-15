class_name Hound
extends Node3D
## A Darkhound: a black hound the size of a pony. Clay like the Trollocs (Sdf), on
## a skeleton of its own with four legs, and a gait of its own: the biped Walker
## cannot run a quadruped. It answers to the same calls as a Walker (teleport,
## attack, hit, die; pos, vel, heading, downed) so the game drives both alike.

const BONES: Array[String] = ["hips", "chest", "neck", "head", "tail",
	"fl_up", "fl_low", "fr_up", "fr_low", "hl_up", "hl_low", "hr_up", "hr_low"]
const PARENT: Array[int] = [-1, 0, 1, 2, 0, 1, 5, 1, 7, 0, 9, 0, 11]
const HIPS := 0
const CHEST := 1
const NECK := 2
const HEAD := 3
const TAIL := 4
const LEG := 5          # then +2 per leg: fl, fr, hl, hr; +1 for the lower bone

static var _data := {}

var sk: Skeleton3D
var J: PackedVector3Array
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var heading := 0.0
var downed := false
var dead := -1.0
var phase := 0.0
var speed_s := 0.0
var spring_t := -1.0     # seconds into a spring or a bite, or -1
var spring_long := false
var flinch := 0.0
var push := Vector3.ZERO
var fall := 0.0          # 0 on its feet .. 1 on its side

static func joints() -> PackedVector3Array:
	var j := PackedVector3Array()
	j.resize(BONES.size())
	j[HIPS] = Vector3(0, 0.98, -0.52)
	j[CHEST] = Vector3(0, 1.02, 0.4)
	j[NECK] = Vector3(0, 1.14, 0.62)
	j[HEAD] = Vector3(0, 1.3, 0.92)
	j[TAIL] = Vector3(0, 1.0, -0.74)
	for side in 2:
		var x := 0.2 * (1.0 if side == 0 else -1.0)
		j[LEG + side * 2] = Vector3(x, 0.9, 0.42)
		j[LEG + side * 2 + 1] = Vector3(x, 0.47, 0.36)
		j[LEG + 4 + side * 2] = Vector3(x * 0.92, 0.9, -0.52)
		j[LEG + 4 + side * 2 + 1] = Vector3(x * 0.92, 0.46, -0.74)
	return j

## The clay, once: every Darkhound is the same beast.
static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	var j := joints()
	var fur := Color(0.009, 0.008, 0.01, 1.0)
	var hide := Color(0.035, 0.03, 0.03, 0.5)
	var sd := Sdf.new()
	# Trunk: a deep chest, a tucked belly, heavy shoulders standing above the back.
	sd.use(HIPS, fur, 0.07)
	sd.cone(j[HIPS] + Vector3(0, -0.04, 0), j[CHEST] + Vector3(0, -0.1, -0.1), 0.2, 0.25).bone2 = CHEST
	sd.use(CHEST, fur, 0.07)
	sd.ball(j[CHEST] + Vector3(0, -0.12, 0.02), Vector3(0.28, 0.35, 0.33))
	sd.ball(j[CHEST] + Vector3(0, 0.12, -0.02), Vector3(0.17, 0.14, 0.24))
	sd.use(HIPS, fur, 0.06)
	sd.ball(j[HIPS] + Vector3(0, -0.02, 0), Vector3(0.22, 0.24, 0.26))
	# Neck and head: thick neck carried low and forward, a long heavy muzzle.
	sd.use(NECK, fur, 0.06)
	sd.cone(j[CHEST] + Vector3(0, 0.04, 0.1), j[HEAD] + Vector3(0, -0.05, -0.06), 0.25, 0.17).bone2 = HEAD
	sd.use(HEAD, fur, 0.035)
	sd.ball(j[HEAD], Vector3(0.16, 0.145, 0.18))
	sd.cone(j[HEAD] + Vector3(0, -0.03, 0.1), j[HEAD] + Vector3(0, -0.07, 0.4), 0.115, 0.072, Vector2(1, 0.8))
	sd.use(HEAD, hide, 0.02)
	sd.ball(j[HEAD] + Vector3(0, -0.055, 0.44), Vector3(0.045, 0.035, 0.04))            # nose
	sd.use(HEAD, fur, 0.02)
	sd.cone(j[HEAD] + Vector3(0, -0.13, 0.06), j[HEAD] + Vector3(0, -0.15, 0.36), 0.06, 0.04, Vector2(1, 0.6))   # lower jaw
	for sx in [-1.0, 1.0]:
		# Ears laid back; brow ridges over the eyes.
		sd.use(HEAD, fur, 0.015)
		sd.cone(j[HEAD] + Vector3(0.09 * sx, 0.09, -0.06), j[HEAD] + Vector3(0.13 * sx, 0.2, -0.16), 0.045, 0.012, Vector2(0.5, 1))
		sd.ball(j[HEAD] + Vector3(0.07 * sx, 0.07, 0.1), Vector3(0.04, 0.025, 0.05))
		# Teeth: a pale line along the muzzle and two fangs.
		sd.use(HEAD, Color(0.75, 0.72, 0.62, 0.0), 0.004)
		sd.cone(j[HEAD] + Vector3(0.045 * sx, -0.105, 0.38), j[HEAD] + Vector3(0.045 * sx, -0.165, 0.375), 0.014, 0.004)
		sd.box(j[HEAD] + Vector3(0.06 * sx, -0.108, 0.24), Vector3(0.012, 0.012, 0.11), 0.004).op = Sdf.PAINT
	# Tail: carried low.
	sd.use(TAIL, fur, 0.03)
	sd.chain([j[TAIL] + Vector3(0, 0.02, 0.06), j[TAIL] + Vector3(0, -0.12, -0.2), j[TAIL] + Vector3(0, -0.4, -0.3), j[TAIL] + Vector3(0, -0.6, -0.26)], 0.06, 0.025)
	# Legs: upper, lower, paw.
	for leg in 4:
		var up := LEG + leg * 2
		var a := j[up]; var b := j[up + 1]
		var hind := leg >= 2
		var paw := Vector3(a.x, 0.07, (b.z + 0.16) if hind else (b.z + 0.1))
		sd.use(up, fur, 0.05)
		sd.cone(a + Vector3(0, 0.06, 0), b, 0.16 if hind else 0.14, 0.08, Vector2(0.8, 1))
		sd.use(up + 1, fur, 0.03)
		sd.cone(b, paw + Vector3(0, 0.05, -0.05), 0.075, 0.06)
		sd.ball(paw + Vector3(0, 0, 0.03), Vector3(0.1, 0.065, 0.125))
	sd.use(0, Color.BLACK, 0.004).box(Vector3(0, -0.5, 0), Vector3(3, 0.5, 3), 0.0).op = Sdf.CARVE
	var m := Sdf.MeshData.new()
	var body := sd.bounds().grow(0.05)
	var head := AABB(j[HEAD] - Vector3(0.22, 0.26, 0.2), Vector3(0.44, 0.52, 0.72))
	for region in [[body, 0.026], [head, 0.011]]:
		var g := Sdf.Grid.make(region[0], region[1])
		sd.fill(g)
		var skip: Array[AABB] = []
		if region[1] > 0.02:
			skip.append(head.grow(-0.026))
		m.append(Sdf.surface(g, skip, 0.05))
	Sdf.skin(m, sd.prims, sd.prims, BONES.size(), 0.05, 0.012, Color(0, 0, 0, -1))
	_data = {joints = j, body = m.arrays()}
	return _data

static func instantiate() -> Hound:
	var d := data()
	var h := Hound.new()
	h.J = d.joints
	h.sk = Skeleton3D.new()
	var skin := Skin.new()
	for i in BONES.size():
		h.sk.add_bone(BONES[i])
		h.sk.set_bone_parent(i, PARENT[i])
		var local: Vector3 = h.J[i] - (h.J[PARENT[i]] if PARENT[i] >= 0 else Vector3.ZERO)
		h.sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		h.sk.set_bone_pose_position(i, local)
		skin.add_bind(i, Transform3D(Basis.IDENTITY, -h.J[i]))
	h.add_child(h.sk)
	var mi := MeshInstance3D.new()
	mi.mesh = Creature.make_mesh(d)
	mi.skin = skin
	h.sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.custom_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	# Eyes that shine like silver in the dark.
	var at := BoneAttachment3D.new(); at.bone_name = "head"
	h.sk.add_child(at)
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.022; s.height = 0.044
		e.mesh = s
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.9, 0.92, 1.0); em.emission_enabled = true; em.emission = Color(0.8, 0.86, 1.0); em.emission_energy_multiplier = 3.0
		e.material_override = em
		e.position = Vector3(0.068 * sx, 0.04, 0.125)
		at.add_child(e)
	h.phase = randf()
	return h

func teleport(p: Vector3, yaw: float) -> void:
	pos = p; heading = yaw
	_place()

## A bite (short) or the spring before a pounce (thrust: crouch, then full stretch).
func attack(kind := "chop") -> void:
	spring_t = 0.0
	spring_long = kind == "thrust"

func hit(dir: Vector3, strength := 1.0) -> void:
	flinch = minf(flinch + 0.5 * strength, 1.0)
	push += dir.normalized() * 1.6 * strength

func die(dir: Vector3) -> void:
	dead = 0.0
	push += dir.normalized() * 1.5

func _place() -> void:
	position = Vector3(pos.x, Terrain.height(pos.x, pos.z), pos.z)
	rotation.y = heading

func _process(dt: float) -> void:
	if sk == null:
		return
	pos += (vel + push) * dt
	push = push.lerp(Vector3.ZERO, minf(6.0 * dt, 1.0))
	var sp := Vector2(vel.x, vel.z).length()
	speed_s = lerpf(speed_s, sp, minf(8.0 * dt, 1.0))
	if sp > 0.4 and dead < 0.0:
		heading = lerp_angle(heading, atan2(vel.x, vel.z), minf(9.0 * dt, 1.0))
	if dead >= 0.0:
		dead += dt
	fall = move_toward(fall, 1.0 if (dead >= 0.0 or downed) else 0.0, dt * (3.5 if dead >= 0.0 or downed else 2.5))
	flinch = move_toward(flinch, 0.0, dt * 3.0)
	if spring_t >= 0.0:
		spring_t += dt
		if spring_t > (1.3 if spring_long else 0.7):
			spring_t = -1.0
	_place()
	_pose(dt)

func _pose(dt: float) -> void:
	# The stride lengthens with speed: a walk under 2 m/s, a gallop above 5.
	var run := clampf((speed_s - 1.5) / 4.0, 0.0, 1.0)
	var go := clampf(speed_s / 1.2, 0.0, 1.0) * (1.0 - fall)
	phase = fposmod(phase + dt * (0.9 + speed_s * 0.34) * (1.0 if go > 0.01 else 0.0), 1.0)
	var swing := lerpf(0.35, 0.95, run) * go
	# What the whole body is doing.
	var crouch := 0.0; var stretch := 0.0; var bite := 0.0
	if spring_t >= 0.0:
		if spring_long:
			# Down on its haunches while it chooses the line, then flung out long.
			crouch = smoothstep(0.0, 0.25, spring_t) * (1.0 - smoothstep(0.5, 0.62, spring_t))
			stretch = smoothstep(0.5, 0.62, spring_t) * (1.0 - smoothstep(0.95, 1.3, spring_t))
			bite = stretch
		else:
			bite = sin(clampf(spring_t / 0.7, 0.0, 1.0) * PI)
	var bob := sin(phase * TAU * 2.0) * 0.035 * run * go
	var pitch := sin(phase * TAU + 0.6) * 0.1 * run * go + crouch * 0.22 + stretch * 0.08 - flinch * 0.12
	# On its side when dead or thrown down.
	sk.position = Vector3(0, bob - crouch * 0.2 - fall * 0.62 + stretch * 0.12, 0)
	sk.rotation = Vector3(-pitch, 0, fall * 1.45)
	var q := func(axis: Vector3, ang: float) -> Quaternion: return Quaternion(axis, ang)
	sk.set_bone_pose_rotation(CHEST, q.call(Vector3.RIGHT, sin(phase * TAU + 1.2) * 0.08 * run * go))
	sk.set_bone_pose_rotation(NECK, q.call(Vector3.RIGHT, 0.28 * run * go + crouch * 0.1 - stretch * 0.3 + flinch * 0.4 - bite * 0.15 + fall * 0.3))
	sk.set_bone_pose_rotation(HEAD, q.call(Vector3.RIGHT, -0.2 * run * go - crouch * 0.2 + bite * 0.25) * q.call(Vector3.UP, sin(Time.get_ticks_msec() * 0.0011 + phase * 9.0) * 0.12 * (1.0 - go)))
	sk.set_bone_pose_rotation(TAIL, q.call(Vector3.RIGHT, -0.5 * run * go + sin(phase * TAU) * 0.15 * go - fall * 0.4))
	for leg in 4:
		var hind := leg >= 2
		var up := LEG + leg * 2
		# A gallop gathers the hind legs together and throws the fore legs together;
		# at a walk the corners go in turn.
		var off: float = lerpf([0.0, 0.5, 0.75, 0.25][leg], [0.0, 0.1, 0.5, 0.6][leg], run)
		var a := sin((phase + off) * TAU)
		var lift := maxf(cos((phase + off) * TAU), 0.0)
		# Angles are "paw forward" positive, for both bones of every leg.
		var upper := a * swing * (0.9 if hind else 1.0)
		var lower := lift * swing * (0.9 if hind else -1.1)
		# Crouched: haunches folded under it. Flung out: fore legs forward, hind legs back.
		upper += crouch * (0.6 if hind else -0.3) + stretch * (-0.9 if hind else 1.0)
		lower += crouch * (-1.0 if hind else 0.6) + stretch * (-0.25 if hind else 0.25)
		# Dead or down: legs slack and a little folded.
		upper = lerpf(upper, 0.25 if hind else -0.2, fall)
		lower = lerpf(lower, -0.5 if hind else 0.45, fall)
		sk.set_bone_pose_rotation(up, q.call(Vector3.RIGHT, -upper))
		sk.set_bone_pose_rotation(up + 1, q.call(Vector3.RIGHT, -lower))
