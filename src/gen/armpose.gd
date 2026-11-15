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

func _process_modification() -> void:
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
