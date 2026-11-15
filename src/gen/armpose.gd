class_name ArmPose
extends SkeletonModifier3D
## Poses the arms on top of whatever clip is playing, for things the animation
## pack has no clip for: drawing a bow, levelling a crossbow. It runs after the
## animation each frame and turns the two bones of each arm to point where the
## pose wants them, blended in by `weight`.
##   mode: "" | "bow" | "crossbow"
##   pull: 0..1, how far the bow is drawn (the string hand travels back to the cheek)
##   pitch: radians the aim is raised (+) or lowered (-)

var mode := ""
var pull := 0.0
var pitch := 0.0
var weight := 0.0
## Model directions in the skeleton's own space (Hero works these out).
var fwd := Vector3(0, 0, 1)
var up := Vector3(0, 1, 0)
var left := Vector3(1, 0, 0)
## How what is carried sits in each hand (the holder's basis in the hand's space),
## so the hand can be turned to put the bow upright or the crossbow level
## whatever twist the arm happens to have.
var grip_l := Basis.IDENTITY
var grip_r := Basis.IDENTITY

## --- sword forms -------------------------------------------------------------------
## The pack has three sword cuts, and eight forms cannot all be one of them. A
## stroke is the path of the hand and the blade, written out: keys of
##   [t, hand, blade, twist, lean, knee]
## t: 0 at the start, 1 as the blow lands, past 1 the follow-through.
## hand: where the sword hand is from its own shoulder (right, up, forward), in
##   metres on an arm of 0.55 m. blade: which way the blade points (same axes).
## twist: the trunk turned about the spine (rad, + to the left). lean: bent forward.
## knee: the left knee lifted (0..1). `two`: both hands on the hilt.
## The legs and hips stay with whatever clip is playing.
const STROKES := {
	# A level draw-cut, right to left, through everything in front.
	parting_the_silk = {keys = [
		[0.0, Vector3(0.38, -0.05, 0.05), Vector3(0.9, 0.1, -0.4), -0.8, 0.0, 0.0],
		[1.0, Vector3(-0.02, -0.06, 0.52), Vector3(-0.1, 0.03, 1.0), 0.1, 0.12, 0.0],
		[1.6, Vector3(-0.42, -0.04, 0.22), Vector3(-0.95, 0.05, 0.25), 0.8, 0.05, 0.0]]},
	# From over the back, both hands, down through the skull.
	boar_rushes = {two = true, keys = [
		[0.0, Vector3(-0.08, 0.46, -0.02), Vector3(0.0, 0.45, -0.9), 0.0, -0.2, 0.0],
		[0.7, Vector3(-0.08, 0.5, 0.1), Vector3(0.0, 0.8, -0.6), 0.0, -0.1, 0.0],
		[1.0, Vector3(-0.1, -0.12, 0.5), Vector3(0.0, -0.3, 0.95), 0.0, 0.5, 0.0],
		[1.5, Vector3(-0.1, -0.36, 0.4), Vector3(0.0, -0.65, 0.76), 0.0, 0.55, 0.0]]},
	# Three cuts thrown wide, high to low and back, scattering them.
	apple_blossoms = {keys = [
		[0.0, Vector3(0.42, 0.28, 0.08), Vector3(0.8, 0.6, -0.1), -0.6, 0.0, 0.0],
		[0.5, Vector3(-0.3, -0.12, 0.42), Vector3(-0.65, -0.3, 0.7), 0.6, 0.15, 0.0],
		[1.0, Vector3(0.42, -0.12, 0.38), Vector3(0.8, -0.2, 0.55), -0.6, 0.15, 0.0],
		[1.6, Vector3(-0.34, 0.32, 0.28), Vector3(-0.7, 0.7, 0.2), 0.55, 0.0, 0.0]]},
	# On one foot, the sword level above the head, then all the way round and down.
	heron_wading = {two = true, keys = [
		[0.0, Vector3(-0.05, 0.5, 0.08), Vector3(-1.0, 0.12, 0.0), 0.0, -0.05, 1.0],
		[0.6, Vector3(-0.05, 0.52, 0.1), Vector3(-0.9, 0.2, -0.3), -0.3, -0.05, 1.0],
		[1.0, Vector3(0.12, 0.1, 0.48), Vector3(0.45, -0.25, 0.85), 0.3, 0.25, 0.6],
		[1.5, Vector3(-0.3, -0.25, 0.34), Vector3(-0.6, -0.6, 0.5), 0.6, 0.3, 0.0]]},
	# A thrust that begins by the hip and ends above the head.
	swallow_flight = {keys = [
		[0.0, Vector3(0.14, -0.46, -0.06), Vector3(0.0, -0.15, 1.0), -0.35, 0.25, 0.0],
		[1.0, Vector3(0.0, 0.16, 0.6), Vector3(0.0, 0.5, 0.87), 0.3, 0.1, 0.0],
		[1.5, Vector3(0.0, 0.34, 0.52), Vector3(0.0, 0.7, 0.7), 0.3, -0.05, 0.0]]},
	# All wrist: the blade upright, snapped flat onto the head, and upright again.
	courtier_fan = {keys = [
		[0.0, Vector3(0.14, 0.26, 0.24), Vector3(0.12, 1.0, -0.15), 0.0, 0.0, 0.0],
		[0.75, Vector3(0.12, 0.3, 0.26), Vector3(0.1, 0.95, -0.3), 0.0, -0.03, 0.0],
		[1.0, Vector3(0.05, 0.24, 0.46), Vector3(0.0, 0.3, 0.95), 0.1, 0.06, 0.0],
		[1.45, Vector3(0.14, 0.26, 0.26), Vector3(0.12, 1.0, 0.0), 0.0, 0.0, 0.0]]},
	# One great rising crescent, low on the left to high on the right.
	arc_of_the_moon = {two = true, keys = [
		[0.0, Vector3(-0.34, -0.42, 0.08), Vector3(-0.7, -0.7, 0.1), 0.85, 0.3, 0.0],
		[0.55, Vector3(-0.36, -0.44, 0.06), Vector3(-0.75, -0.65, 0.0), 0.95, 0.35, 0.0],
		[1.0, Vector3(0.08, 0.2, 0.5), Vector3(0.3, 0.5, 0.8), -0.1, 0.0, 0.0],
		[1.5, Vector3(0.4, 0.5, 0.1), Vector3(0.6, 0.8, -0.1), -0.75, -0.12, 0.0]]},
	# Drawn back level beside the head, then run home and left there.
	sheathing_the_sword = {keys = [
		[0.0, Vector3(0.3, 0.12, -0.2), Vector3(0.0, 0.0, 1.0), -0.6, -0.05, 0.0],
		[0.6, Vector3(0.32, 0.14, -0.24), Vector3(0.0, 0.0, 1.0), -0.7, -0.08, 0.0],
		[1.0, Vector3(0.0, 0.0, 0.62), Vector3(0.0, -0.06, 1.0), 0.45, 0.4, 0.0],
		[1.6, Vector3(0.0, -0.02, 0.6), Vector3(0.0, -0.1, 1.0), 0.45, 0.42, 0.0]]},
}
var _stroke := {}
var _st := 0.0
var _land := 0.3
var _total := 0.6

## Begin a stroke: `land` seconds to the blow, `after` seconds of follow-through.
func stroke(id: String, land: float, after: float) -> void:
	_stroke = STROKES.get(id, {})
	_st = 0.0; _land = maxf(land, 0.05); _total = _land + maxf(after, 0.1)

func stop_stroke() -> void:
	_stroke = {}

func _stroke_step() -> void:
	_st += get_process_delta_time()
	if _st >= _total:
		_stroke = {}
		return
	var keys: Array = _stroke.keys
	# Time in the stroke's own units: 1 as the blow lands, and the follow-through
	# spread over what is left.
	var last: float = keys[keys.size() - 1][0]
	var t := _st / _land if _st < _land else 1.0 + (last - 1.0) * (_st - _land) / (_total - _land) * 1.25
	t = minf(t, last)
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1][0]:
		i += 1
	var a: Array = keys[i]; var b: Array = keys[i + 1]
	var x := clampf((t - a[0]) / maxf(b[0] - a[0], 0.001), 0.0, 1.0)
	# Into the blow it quickens; out of it, it eases.
	x = x * x if b[0] <= 1.0 and b[0] > 0.9 else x * x * (3.0 - 2.0 * x)
	var hand: Vector3 = (a[1] as Vector3).lerp(b[1], x)
	var blade: Vector3 = (a[2] as Vector3).normalized().slerp((b[2] as Vector3).normalized(), x)
	var twist: float = lerpf(a[3], b[3], x); var lean: float = lerpf(a[4], b[4], x); var knee: float = lerpf(a[5], b[5], x)
	var w := smoothstep(0.0, 0.07, _st) * (1.0 - smoothstep(_total - 0.16, _total, _st))
	var sk := get_skeleton()
	var right := -left
	# The trunk first: the shoulders ride on it.
	for bone in ["spine_01", "spine_02", "spine_03"]:
		var bi := sk.find_bone(bone)
		if bi >= 0:
			var cur := sk.get_bone_global_pose(bi)
			var q := Quaternion(up, twist * w / 3.0) * Quaternion(right, lean * w / 3.0)
			sk.set_bone_global_pose(bi, Transform3D(Basis(q) * cur.basis, cur.origin))
	var save := weight
	weight = w
	var world := func(v: Vector3) -> Vector3: return right * v.x + up * v.y + fwd * v.z
	var bdir: Vector3 = world.call(blade).normalized()
	var target := _reach("upperarm_r", "lowerarm_r", "hand_r", world.call(hand), (right * 0.5 - up * 0.8 - fwd * 0.3).normalized())
	# The blade along its line, edge leading into the cut.
	var vel: Vector3 = world.call((b[1] as Vector3) - (a[1] as Vector3) + ((b[2] as Vector3) - (a[2] as Vector3)) * 0.6)
	var edge := vel - bdir * vel.dot(bdir)
	if edge.length() < 0.05:
		edge = up - bdir * up.dot(bdir)
	edge = edge.normalized()
	_hold("hand_r", Basis(bdir.cross(edge), bdir, edge) * grip_r.inverse())
	if _stroke.get("two", false):
		# The other hand under the first, on the same hilt.
		var s_l := sk.find_bone("upperarm_l"); var s_r := sk.find_bone("upperarm_r")
		if s_l >= 0 and s_r >= 0:
			var off := target - bdir * 0.11 - sk.get_bone_global_pose(s_l).origin
			_reach("upperarm_l", "lowerarm_l", "hand_l", off, (left * 0.5 - up * 0.8 - fwd * 0.3).normalized(), true)
	if knee > 0.01:
		weight = w * knee
		_point("thigh_l", "calf_l", (fwd * 0.85 - up * 0.45 + left * 0.15).normalized())
		_point("calf_l", "foot_l", (-up * 0.95 - fwd * 0.3).normalized())
	weight = save

## Two-bone reach: put `tip` at `off` from the root bone (skeleton space; in metres
## on a 0.55 m arm unless `exact`), elbow toward `pole`. Returns where it went.
func _reach(root: String, mid: String, tip: String, off: Vector3, pole: Vector3, exact := false) -> Vector3:
	var sk := get_skeleton()
	var r := sk.find_bone(root); var m := sk.find_bone(mid); var e := sk.find_bone(tip)
	if r < 0 or m < 0 or e < 0:
		return Vector3.ZERO
	var s := sk.get_bone_global_pose(r).origin
	var l1 := s.distance_to(sk.get_bone_global_pose(m).origin)
	var l2 := sk.get_bone_global_pose(m).origin.distance_to(sk.get_bone_global_pose(e).origin)
	if not exact:
		off *= (l1 + l2) / 0.55
	var d := clampf(off.length(), absf(l1 - l2) + 0.02, (l1 + l2) * 0.985)
	var dir := off.normalized()
	# The elbow sits on the circle where the two bones meet, on the pole's side.
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var out := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var side := pole - dir * pole.dot(dir)
	side = side.normalized() if side.length() > 0.01 else up
	var elbow := dir * along + side * out
	_point(root, mid, elbow.normalized())
	_point(mid, tip, (dir * d - elbow).normalized())
	return s + dir * d

func _process_modification() -> void:
	if not _stroke.is_empty():
		_stroke_step()
		return
	if weight <= 0.01 or mode == "":
		return
	var aim := (fwd * cos(pitch) + up * sin(pitch)).normalized()
	match mode:
		"bow":
			# The bow arm straight out; the string hand from the bow back to the cheek,
			# elbow high and out behind.
			var bow_arm := (aim * 0.92 + left * 0.38).normalized()
			_point("upperarm_l", "lowerarm_l", bow_arm)
			_point("lowerarm_l", "hand_l", bow_arm)
			# The bow upright, its back to the target and its string to the archer.
			var by := (up - aim * up.dot(aim)).normalized()
			_hold("hand_l", Basis(aim, by, aim.cross(by)) * grip_l.inverse())
			var u0 := (aim * 0.75 - left * 0.25 - up * 0.25).normalized()
			var u1 := (-left * 0.8 - aim * 0.35 + up * 0.25).normalized()
			var f0 := (aim * 0.9 + left * 0.35).normalized()
			var f1 := (aim * 0.55 + left * 0.8 + up * 0.05).normalized()
			_point("upperarm_r", "lowerarm_r", u0.slerp(u1, pull))
			_point("lowerarm_r", "hand_r", f0.slerp(f1, pull))
		"crossbow":
			# Stock in the right hand at the shoulder, the left hand under the tiller.
			_point("upperarm_r", "lowerarm_r", (aim * 0.45 - left * 0.25 - up * 0.85).normalized())
			_point("lowerarm_r", "hand_r", (aim * 0.98 + up * 0.12).normalized())
			_point("upperarm_l", "lowerarm_l", (aim * 0.7 + left * 0.1 - up * 0.6).normalized())
			_point("lowerarm_l", "hand_l", (aim * 0.85 - left * 0.45 + up * 0.2).normalized())
			# The stock along the aim, the prod level across it.
			var cz := (left - aim * left.dot(aim)).normalized()
			_hold("hand_r", Basis(aim.cross(cz), aim, cz) * grip_r.inverse())

## Turn `bone` so that it points along `dir` (skeleton space), keeping as much of
## its animated twist as it can, blended by weight.
func _point(bone: String, child: String, dir: Vector3) -> void:
	var sk := get_skeleton()
	var b := sk.find_bone(bone); var c := sk.find_bone(child)
	if b < 0 or c < 0:
		return
	var cur := sk.get_bone_global_pose(b)
	var now := (sk.get_bone_global_pose(c).origin - cur.origin).normalized()
	if now.length() < 0.5 or dir.length() < 0.5:
		return
	var turn := Quaternion(now, dir)
	var q := Quaternion.IDENTITY.slerp(turn, clampf(weight, 0.0, 1.0))
	sk.set_bone_global_pose(b, Transform3D(Basis(q) * cur.basis, cur.origin))

## Turn a hand to an orientation outright (skeleton space), blended by weight.
func _hold(bone: String, want: Basis) -> void:
	var sk := get_skeleton()
	var b := sk.find_bone(bone)
	if b < 0:
		return
	var cur := sk.get_bone_global_pose(b)
	var q := cur.basis.get_rotation_quaternion().slerp(want.orthonormalized().get_rotation_quaternion(), clampf(weight, 0.0, 1.0))
	sk.set_bone_global_pose(b, Transform3D(Basis(q).scaled(cur.basis.get_scale()), cur.origin))
