class_name Map
## Where an activity happens, as pure maths: no nodes, so the headless Sim, the
## terrain mesh and foot placement all agree on the same ground and the same walls.
## A map is a corridor running along -Z (enemies come from the far, negative end)
## whose half-width varies with z. Outside it the ground climbs into cliffs.

const MAPS := {
	open = {},
	# Tarwin's Gap: a pass between the Mountains of Dhoom. Wide where the Trollocs
	# gather, pinched at a chokepoint in front of the line the defenders hold.
	tarwins_gap = {length = 95.0, back = 22.0, wide = 30.0, narrow = 11.0, choke_z = -20.0, choke_len = 16.0, cliff = 46.0},
}
static var id := "open"
static var m := {}

static func use(map_id: String) -> void:
	id = map_id if MAPS.has(map_id) else "open"
	m = MAPS[id]

static func half_width(z: float) -> float:
	if m.is_empty():
		return 1e6
	var pinch := exp(-pow((z - m.choke_z) / m.choke_len, 2.0))
	return lerpf(m.wide, m.narrow, pinch) + sin(z * 0.11) * 1.5

## Keep a walker inside the pass. Cheap enough to call for every entity every tick.
static func clamp_pos(p: Vector3, margin := 0.6) -> Vector3:
	if m.is_empty():
		return p
	var w := half_width(p.z) - margin
	return Vector3(clampf(p.x, -w, w), p.y, clampf(p.z, -m.length, m.back))

## Extra ground height from the cliffs: zero inside the corridor, steep outside.
static func ridge(x: float, z: float) -> float:
	if m.is_empty():
		return 0.0
	var out := absf(x) - half_width(z)
	var side := smoothstep(-1.5, 14.0, out)
	# The pass is closed behind the defenders by a gentler rise, not a wall.
	var behind := smoothstep(m.back, m.back + 30.0, z) * 0.35
	return (side * side * (3.0 - 2.0 * side) + behind) * m.cliff

## Where a wave appears: spread across the far end of the pass.
static func spawn(rng: RandomNumberGenerator) -> Vector3:
	var z: float = -m.length + rng.randf_range(2.0, 22.0)
	var w := half_width(z) - 2.0
	return Vector3(rng.randf_range(-w, w), 0.0, z)

## The line the defenders stand on, just behind the chokepoint.
static func line_z() -> float:
	return 0.0 if m.is_empty() else m.choke_z + m.choke_len * 0.9
