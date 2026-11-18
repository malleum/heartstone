class_name Walker
extends Node3D
## Procedural locomotion for any Creature rig: no authored animation at all.
##
## Feet are the source of truth. Each foot is either planted at a fixed world point
## or swinging to a predicted landing spot on the terrain; the pelvis is then hung
## between the feet and the legs solved with two-bone IK, so planted feet cannot slide.
## Everything above the hips is layered rotation: sway, counter-twist, arm swing.
##
## compute() touches only this object's own state (safe on worker threads);
## apply() pushes the result to the scene tree on the main thread.

const C = preload("res://src/gen/creature.gd")

var sk: Skeleton3D
var spec: Dictionary
var J: PackedVector3Array
var off := PackedVector3Array()
var L := 1.0                      # hip height: the natural length scale of the gait
var l1 := 0.5
var l2 := 0.5
var rest_thigh: Array[Basis] = [Basis(), Basis()]
var rest_shin: Array[Basis] = [Basis(), Basis()]
var foot_vec: Array[Vector3] = [Vector3(), Vector3()]
var ball_rest: Array[Vector3] = [Vector3(), Vector3()]
var heavy := 1.0                  # 0 light human, 1 lumbering Trolloc
var hunch := 0.0
var digit := false
var crouch0 := 0.03
var weapon_side := -1

# Commanded motion.
var vel := Vector3.ZERO
var look_yaw := 0.0

# State.
var pos := Vector3.ZERO
var heading := 0.0
var face_yaw := 999.0   # < 100: face this way whatever way it walks
var root_y := 0.0
var phase := 0.0
var time := 0.0
var push := Vector3.ZERO          # knockback velocity
var lean := Vector2.ZERO          # hit-react spring (x sideways, y forward), radians
var lean_v := Vector2.ZERO
var dead := -1.0                  # seconds since death, or -1
var downed := false               # knocked flat; gets up when cleared
var floor_t := 0.0
var swing_t := -1.0               # seconds into a weapon swing, or -1
var swing_kind := "chop"          # chop | sweep | thrust: each reads differently, each is answered differently
var dead_dir := 1.0
var ft_pos: Array[Vector3] = [Vector3(), Vector3()]   # current ball position, world
var ft_from: Array[Vector3] = [Vector3(), Vector3()]
var ft_tgt: Array[Vector3] = [Vector3(), Vector3()]
var ft_swing: Array[bool] = [false, false]
var ft_yaw: Array[float] = [0.0, 0.0]
var ft_yaw_from: Array[float] = [0.0, 0.0]
var ft_pitch: Array[float] = [0.0, 0.0]
var ft_gy: Array[float] = [0.0, 0.0]                  # ground height under the foot, ignoring lift
var speed_s := 0.0

# Output of compute().
var rot: Array[Basis] = []
var quat: Array[Quaternion] = []
var hips_pos := Vector3.ZERO


func setup(data: Dictionary, skeleton: Skeleton3D) -> void:
	sk = skeleton; spec = data.spec; J = data.joints
	off.resize(C.NB); rot.resize(C.NB); quat.resize(C.NB)
	for i in C.NB:
		off[i] = J[i] - (J[C.PARENT[i]] if C.PARENT[i] >= 0 else Vector3.ZERO)
		rot[i] = Basis.IDENTITY; quat[i] = Quaternion.IDENTITY
	L = J[C.THIGH].y
	l1 = J[C.THIGH].distance_to(J[C.SHIN]); l2 = J[C.SHIN].distance_to(J[C.FOOT])
	for side in 2:
		var o := C.RIGHT * side
		var n := (J[C.FOOT + o] - J[C.THIGH + o]).cross(Vector3.BACK).normalized()
		rest_thigh[side] = _leg_basis(n, J[C.SHIN + o] - J[C.THIGH + o]).transposed()
		rest_shin[side] = _leg_basis(n, J[C.FOOT + o] - J[C.SHIN + o]).transposed()
		foot_vec[side] = J[C.TOE + o] - J[C.FOOT + o]
		ball_rest[side] = J[C.TOE + o]
	hunch = spec.hunch
	digit = spec.digit == 1
	crouch0 = spec.get("crouch", 0.03)
	weapon_side = spec.get("weapon_side", -1)
	heavy = clampf((spec.bulk - 1.0) * 2.0, 0.0, 1.0)
	phase = fposmod(hash(spec.seed) * 0.0001, 1.0)
	time = phase * 20.0

func teleport(p: Vector3, yaw: float) -> void:
	pos = p; heading = yaw
	root_y = Terrain.height(p.x, p.z)
	var lf := Vector3(cos(yaw), 0, -sin(yaw)); var fw := Vector3(sin(yaw), 0, cos(yaw))
	for i in 2:
		var w := pos + lf * ball_rest[i].x + fw * ball_rest[i].z
		w.y = Terrain.height(w.x, w.z)
		ft_pos[i] = w; ft_tgt[i] = w; ft_from[i] = w; ft_gy[i] = w.y
		ft_yaw[i] = yaw; ft_swing[i] = false

## Start a weapon swing; the blow lands 0.4 s later.
func attack(kind := "chop") -> void:
	swing_t = 0.0
	swing_kind = kind

## A blow from world direction dir (pointing the way the force travels).
func hit(dir: Vector3, strength := 1.0) -> void:
	var local := Basis(Vector3.UP, -heading) * dir.normalized()
	lean_v += Vector2(-local.x, local.z) * 13.0 * strength
	push += dir.normalized() * 2.2 * strength

func die(dir: Vector3) -> void:
	dead = 0.0
	dead_dir = signf((Basis(Vector3.UP, -heading) * dir).z + 0.001)
	push += dir.normalized() * 1.5

static func _leg_basis(n: Vector3, d: Vector3) -> Basis:
	var y := d.normalized()
	var x := (n - y * n.dot(y)).normalized()
	return Basis(x, y, x.cross(y))

static func _rx(a: float) -> Basis: return Basis(Vector3.RIGHT, a)
static func _ry(a: float) -> Basis: return Basis(Vector3.UP, a)
static func _rz(a: float) -> Basis: return Basis(Vector3.BACK, a)


func compute(dt: float) -> void:
	time += dt
	lean_v += (-lean * 70.0 - lean_v * 6.0) * dt
	lean += lean_v * dt
	push *= exp(-3.5 * dt)
	floor_t = move_toward(floor_t, 1.0 if downed else 0.0, dt * (2.2 if downed else 1.1))
	if swing_t >= 0.0:
		swing_t += dt
		if swing_t > 0.9:
			swing_t = -1.0
	var v := vel + push if dead < 0.0 else push
	v.y = 0.0
	var speed := v.length()
	speed_s = lerpf(speed_s, speed, 1.0 - exp(-6.0 * dt))
	if face_yaw < 100.0 and dead < 0.0:
		# Told which way to face (stepping back to where it was thrown, still facing you).
		heading = lerp_angle(heading, face_yaw, 1.0 - exp(-6.0 * dt))
	elif vel.length() > 0.1 and dead < 0.0:
		heading = lerp_angle(heading, atan2(vel.x, vel.z), 1.0 - exp(-4.0 * dt))
	pos += v * dt
	root_y = lerpf(root_y, Terrain.height(pos.x, pos.z), 1.0 - exp(-5.0 * dt))
	if dead >= 0.0:
		dead += dt
		# Legs give out: the feet skid away from the fall so the body can lie flat.
		if dead < 1.3:
			for i in 2:
				ft_pos[i] -= Vector3(sin(heading), 0, cos(heading)) * dead_dir * 0.75 * L * dt
				ft_pos[i].y = Terrain.height(ft_pos[i].x, ft_pos[i].z)

	# Gait timing from dimensionless speed, so every leg length gets its own cadence.
	var sp := speed_s / sqrt(9.8 * L)
	var runb := smoothstep(0.7, 1.1, sp)
	var duty := lerpf(0.64, 0.38, runb)          # fraction of the cycle a foot is down
	var crouch := crouch0 + 0.04 * runb
	# A planted foot can only stay planted while the leg reaches it, so the stride
	# is capped by leg geometry: overlong strides are what cause foot dragging.
	var reach := (l1 + l2) * 0.985
	var hip_drop := J[C.THIGH].y * (1.0 - crouch) - J[C.FOOT].y
	var span := 2.0 * sqrt(maxf(reach * reach - hip_drop * hip_drop, 0.01)) * 0.9 + (0.0 if digit else 0.5 * foot_vec[0].length())
	var lam := minf(L * (1.25 + 1.0 * sp), span / duty)   # ground covered per full cycle
	var moving := speed > 0.08
	var freq := speed / lam if moving else 0.0
	var fw := Vector3(sin(heading), 0, cos(heading))
	var lf := Vector3(cos(heading), 0, -sin(heading))
	if not moving:
		if ft_swing[0] or ft_swing[1]:
			freq = 1.3
		else:
			# Standing with a foot left behind (after a stop or a shove): step it home.
			for i in 2:
				var home := pos + lf * ball_rest[i].x + fw * ball_rest[i].z
				if Vector2(home.x - ft_pos[i].x, home.z - ft_pos[i].z).length() > 0.22 * L:
					phase = fposmod(duty + 0.001 - 0.5 * i, 1.0)
					freq = 1.3
					break
	phase = fposmod(phase + freq * dt, 1.0)
	var T := 1.0 / maxf(freq, 0.2)
	var vdir := v / speed if moving else fw
	var lift := L * lerpf(0.09 + 0.05 * heavy, 0.2, runb)
	var heel_max := (0.35 if digit else 0.75) * clampf(sp * 2.5, 0.0, 1.0)
	var stance_w := 1.0 + 0.25 * heavy
	for i in 2:
		var p := fposmod(phase + 0.5 * i, 1.0)
		var sx := 1.0 - 2.0 * i
		if p < duty or dead >= 0.0:
			if ft_swing[i]:
				ft_swing[i] = false
				ft_pos[i] = ft_tgt[i]
				ft_yaw[i] = heading + sx * 0.14
			ft_gy[i] = ft_pos[i].y
			ft_pitch[i] = smoothstep(duty * 0.5, duty, p) * heel_max
		else:
			if not ft_swing[i]:
				ft_swing[i] = true
				ft_from[i] = ft_pos[i]
				ft_yaw_from[i] = ft_yaw[i]
			var s := (p - duty) / (1.0 - duty)
			# Land half a stance-length ahead of where the hip will be at touchdown.
			var tgt := pos + v * ((1.0 - p) * T) + lf * (ball_rest[i].x * stance_w) + fw * ball_rest[i].z + vdir * (speed * duty * T * 0.5)
			tgt.y = Terrain.height(tgt.x, tgt.z)
			ft_tgt[i] = tgt
			var e := s * s * (3.0 - 2.0 * s)
			var cur := ft_from[i].lerp(tgt, e)
			ft_gy[i] = cur.y
			cur.y += lift * sin(PI * s) ** 0.8
			ft_pos[i] = cur
			ft_yaw[i] = lerp_angle(ft_yaw_from[i], heading + sx * 0.14, e)
			# Toe trails after push-off, then lifts ahead of landing.
			ft_pitch[i] = heel_max * (1.0 - smoothstep(0.0, 0.5, s)) + (0.5 if digit else 0.25) * sin(PI * s) - 0.22 * smoothstep(0.55, 0.85, s) * (1.0 - smoothstep(0.85, 1.0, s)) * (0.0 if digit else 1.0)

	# --- pelvis, in model space ---------------------------------------------
	var inv := Basis(Vector3.UP, -heading)
	var origin := Vector3(pos.x, root_y, pos.z)
	var a2 := TAU * phase
	var walk_amt := clampf(sp * 4.0, 0.0, 1.0)
	var idle := 1.0 - walk_amt
	var ph0 := lerpf(0.0, duty * 0.5, runb)
	var bob := -cos(2.0 * (a2 - TAU * ph0)) * L * lerpf(0.022 + 0.014 * heavy, 0.05, runb) * walk_amt
	var sway := cos(a2 - PI * duty) * L * lerpf(0.035 + 0.03 * heavy, 0.012, runb) * walk_amt
	var yaw := -cos(a2) * lerpf(0.1 + 0.05 * heavy, 0.2, runb) * walk_amt
	var roll := cos(a2 - PI * duty) * lerpf(0.05 + 0.04 * heavy, 0.04, runb) * walk_amt
	var fwd_lean := 0.03 + 0.16 * sp
	# Idle: slow weight shift and breathing.
	var breath := sin(time * (1.6 - 0.5 * heavy))
	sway += sin(time * 0.43) * L * 0.02 * idle
	var gy := (ft_gy[0] + ft_gy[1]) * 0.5 - root_y
	hips_pos = J[C.HIPS] + Vector3(sway, gy * 0.8 + bob - J[C.THIGH].y * crouch + breath * 0.004 * L * idle, 0.02 * L * sp)
	var r_hips := _ry(yaw) * _rz(roll) * _rx(fwd_lean * 0.4)

	var fall := 0.0
	# Knocked down is the death fall played part-way and reversed to get up again.
	var floored := dead >= 0.0 or floor_t > 0.001
	if floored:
		# Procedural death: knees give way, then the body topples the way it was hit.
		var ft := dead / 1.1 if dead >= 0.0 else floor_t
		fall = smoothstep(0.0, 1.0, ft)
		fall = fall * fall
		var drop := smoothstep(0.0, 0.7, ft)
		hips_pos.y = lerpf(hips_pos.y, 0.17 * L, drop)
		hips_pos.z += dead_dir * 0.35 * L * fall
		r_hips = _rx(dead_dir * fall * 1.55) * _ry(yaw + fall * 0.25)

	# Feet to model space; keep the hips within reach of both ankles.
	var ankle: Array[Vector3] = [Vector3(), Vector3()]
	var r_foot: Array[Basis] = [Basis(), Basis()]
	var r_flat: Array[Basis] = [Basis(), Basis()]
	for i in 2:
		var o := C.RIGHT * i
		var ball := inv * (ft_pos[i] - origin)
		var n := inv * Terrain.normal(ft_pos[i].x, ft_pos[i].z)
		# Tilt the sole to the slope, then turn and pitch the foot about the ball.
		var tilt := Basis(Quaternion(Vector3.UP, Vector3.UP.lerp(n, 0.0 if ft_swing[i] else 0.85).normalized()))
		r_flat[i] = tilt * _ry(ft_yaw[i] - heading)
		r_foot[i] = r_flat[i] * _rx(ft_pitch[i])
		if floored:
			r_foot[i] = r_flat[i] * _rx(fall * 0.9)
		ankle[i] = ball - r_foot[i] * foot_vec[i]
		var h := hips_pos + r_hips * off[C.THIGH + o]
		var d := h - ankle[i]
		var horiz := d.x * d.x + d.z * d.z
		if horiz < reach * reach:
			var ymax := sqrt(reach * reach - horiz)
			if d.y > ymax:
				hips_pos.y -= d.y - ymax

	# --- spine --------------------------------------------------------------
	var hx := lean.y; var hz := lean.x
	var limp := fall * 0.5
	rot[C.HIPS] = r_hips
	rot[C.SPINE] = r_hips * _ry(-yaw * 0.6) * _rz(-roll * 0.9 + hz * 0.4) * _rx(fwd_lean * 0.3 + hunch * 0.08 + hx * 0.4 + limp * 0.3)
	rot[C.CHEST] = rot[C.SPINE] * _ry(-yaw * 1.1) * _rz(-roll * 0.5 + hz * 0.5) * _rx(fwd_lean * 0.3 + hunch * 0.1 + hx * 0.5 + breath * 0.012 + limp * 0.3)
	# The head stays level and looks where it wants; the neck splits the difference.
	var look := look_yaw + sin(time * 0.31) * 0.35 * idle + sin(time * 0.83) * 0.1 * idle
	var r_head := _ry(look) * _rx(0.02 + hunch * 0.03 + sin(time * 0.57) * 0.06 * idle - hx * 0.35 + bob / L * 1.0) * _rz(-hz * 0.3)
	if floored:
		r_head = rot[C.CHEST] * _rx(-0.3 * fall * dead_dir)
	rot[C.NECK] = Basis(rot[C.CHEST].get_rotation_quaternion().slerp(r_head.get_rotation_quaternion(), 0.5))
	rot[C.HEAD] = r_head

	# --- arms: hang under gravity, swing against the legs -------------------
	var arm_amp := lerpf(0.38 - 0.1 * heavy, 0.75, runb) * walk_amt
	var chest_yaw := -yaw * 0.7
	for i in 2:
		var o := C.RIGHT * i
		var sx := 1.0 - 2.0 * i
		var swing := -sx * cos(a2) * arm_amp
		var armed := weapon_side == i
		# A weapon arm swings less and stays cocked so the blade rides clear of the legs.
		if armed:
			swing *= 0.45
		var adrop := 0.7 - (0.08 + 0.12 * heavy) - breath * 0.01
		var hang := 0.05 * hunch - 0.06
		var flex := lerpf(0.18 + 0.1 * hunch, 1.3, runb) + maxf(swing, 0.0) * 0.6 + (0.45 if armed else 0.0)
		var base := _ry(chest_yaw + sx * 0.12) * _rz(-hz * 0.5)
		var r_u := base * _rx(-swing - hang + hx * 0.6) * _rz(-sx * adrop)
		var r_f := base * _rx(-swing - hang - flex + hx * 0.3) * _rz(-sx * adrop)
		if armed and swing_t >= 0.0 and not floored:
			# Overhead chop: the arm goes up and back, comes down hard, then recovers.
			# The blow lands at 0.4 s, when the sim applies the damage.
			var up := smoothstep(0.0, 0.3, swing_t) * (1.0 - smoothstep(0.34, 0.44, swing_t))
			var thru := smoothstep(0.34, 0.44, swing_t) * (1.0 - smoothstep(0.55, 0.85, swing_t))
			match swing_kind:
				"sweep":
					# The arm goes out wide and level, then scythes across the body:
					# a blow at head height, to be ducked.
					var raised := maxf(up, thru)
					var across := sx * (1.5 * up - 1.2 * thru)
					r_u = _ry(chest_yaw + across) * _rx(-1.5 * raised) * _rz(-sx * 0.15)
					r_f = r_u * _rx(-0.35 * up)
				"thrust":
					# Elbow drawn back beside the ribs, then driven straight out.
					r_u = base * _rx(0.75 * up - 1.45 * thru) * _rz(-sx * 0.2)
					r_f = r_u * _rx(-1.7 * up - 0.05 * thru)
				_:
					var ang := -2.9 * up - 0.95 * thru
					r_u = base * _rx(ang) * _rz(-sx * 0.25)
					r_f = base * _rx(ang - 0.9 * up - 0.15 * thru) * _rz(-sx * 0.25)
		if floored:
			# Limp: arms settle beside the body instead of holding a pose.
			r_u = rot[C.CHEST] * _rz(-sx * (adrop - 0.25 * fall)) * _rx(-0.25 * fall)
			r_f = r_u * _rx(-0.3 * fall)
		rot[C.CLAV + o] = rot[C.CHEST]
		rot[C.UARM + o] = r_u
		rot[C.FARM + o] = r_f
		rot[C.HAND + o] = r_f * _rx(-0.2)

	# --- legs: two-bone IK onto the ankles ------------------------------------
	for i in 2:
		var o := C.RIGHT * i
		var sx := 1.0 - 2.0 * i
		var hip := hips_pos + r_hips * off[C.THIGH + o]
		var to := ankle[i] - hip
		var dist := to.length()
		if dist > reach:
			to *= reach / dist
		var tgt := hip + to
		var pole := _ry((ft_yaw[i] - heading) * 0.6) * Vector3(sx * (0.1 + 0.12 * heavy), 0, 1)
		if floored:
			pole = Vector3(sx * 0.8, 0, 1)
		var knee := C.ik2(hip, tgt, l1, l2, pole)
		var n := to.cross(pole).normalized()
		rot[C.THIGH + o] = _leg_basis(n, knee - hip) * rest_thigh[i]
		rot[C.SHIN + o] = _leg_basis(n, tgt - knee) * rest_shin[i]
		rot[C.FOOT + o] = r_foot[i]
		rot[C.TOE + o] = r_flat[i] if not ft_swing[i] and not floored else r_foot[i]

	for b in C.NB:
		var par := C.PARENT[b]
		quat[b] = (rot[b] if par < 0 else rot[par].transposed() * rot[b]).get_rotation_quaternion()


func apply() -> void:
	transform = Transform3D(Basis(Vector3.UP, heading), Vector3(pos.x, root_y, pos.z))
	sk.set_bone_pose_position(C.HIPS, hips_pos)
	for b in C.NB:
		sk.set_bone_pose_rotation(b, quat[b])
