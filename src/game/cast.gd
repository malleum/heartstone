class_name Cast
## Every generated Shadowspawn a fight can show, made once per run on worker
## threads and kept across scene changes. The camp starts it on arrival, so by the
## time anyone reaches a doorway it is done and the fight opens without a pause.
## (Made in the fight scene, it cost seconds on a fast machine and far more on a
## slow one, and a Draghkar's first appearance hitched mid-wave.)

static var trollocs: Array = []   # eight, variant i carrying weapon kind i % 4 (Sim.ARMS)
static var archers: Array = []    # two, carrying bows
static var by_gen := {}           # "FADE", "DRAGHKAR", "DREADLORD" -> creature data
static var _specs: Array = []
static var _out: Array = []
static var _task := -1

static func _make_specs() -> void:
	_specs = []
	for i in 8:
		_specs.append(Species.roll(Species.TROLLOC, 20 + i, {lod = 1.7, head = ["boar", "wolf", "ram", "hawk", "bear"][i % 5], weapon_kind = i % 4}))
	for i in 2:
		_specs.append(Species.roll(Species.TROLLOC, 40 + i, {lod = 1.7, head = ["wolf", "hawk"][i], weapon_kind = 5}))
	_specs.append(Species.roll(Species.MYRDDRAAL, 7, {lod = 1.2}))
	_specs.append(Species.roll(Species.DRAGHKAR, 11, {lod = 1.3}))
	_specs.append(Species.roll(Species.DREADLORD, 11, {lod = 1.3}))

## Start making everything in the background (once; later calls do nothing).
static func begin() -> void:
	if _task != -1 or not trollocs.is_empty():
		return
	Rules.load_data()
	_make_specs()
	_out = []; _out.resize(_specs.size())
	# Each creature is one task, so the slow Myrddraal runs beside the Trollocs
	# instead of after them.
	_task = WorkerThreadPool.add_group_task(func(i: int) -> void: _out[i] = Creature.build(_specs[i]), _specs.size(), -1, true, "cast")

static func ready_now() -> bool:
	return not trollocs.is_empty() or (_task != -1 and WorkerThreadPool.is_group_task_completed(_task))

## Have everything, waiting for whatever is still being made.
static func wait() -> void:
	if not trollocs.is_empty():
		return
	begin()
	WorkerThreadPool.wait_for_group_task_completion(_task)
	_task = -1
	trollocs = _out.slice(0, 8)
	archers = _out.slice(8, 10)
	by_gen = {FADE = _out[10], DRAGHKAR = _out[11], DREADLORD = _out[12]}
	_out = []
