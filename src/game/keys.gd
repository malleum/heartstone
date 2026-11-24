class_name Keys
extends RefCounted
## Every binding in the game is by where a key sits on the board (as on a US
## QWERTY one), never by the letter printed on it: the hand rests in the same place
## on Dvorak, Colemak or AZERTY, and nobody has to switch layout to play. So the
## code says KEY_W and means "the key where W is on QWERTY"; hints on screen ask
## the system which letter the player's own layout has there.

## The player's own bindings (user://keys.json): each default key position -> the
## key they chose for it. The code keeps naming the defaults; k() turns them into
## whatever is bound now.
const FILE := "user://keys.json"
const ACTIONS := [
	[KEY_W, "Walk forward"], [KEY_S, "Walk back"], [KEY_A, "Walk left"], [KEY_D, "Walk right"],
	[KEY_SHIFT, "Roll"], [KEY_SPACE, "Jump (over a low wall: vault)"], [KEY_CTRL, "Duck"], [KEY_CAPSLOCK, "Throw"],
	[KEY_Q, "Tie off the weave held last (fighters: rope, held)"], [KEY_TAB, "Inventory, and choosing at a level-up"],
	[KEY_J, "The Darkfriend's gateway"], [KEY_L, "Link (offer, lead, let go)"], [KEY_H, "Hide the camp sheet"],
	[KEY_1, "Weave 1 / weapon 1"], [KEY_2, "Weave 2 / weapon 2"], [KEY_3, "Weave 3 / weapon 3"], [KEY_4, "Weave 4 / weapon 4"],
	[KEY_5, "Weave 5 / form 1"], [KEY_Z, "Weave 6 / form 2"], [KEY_X, "Weave 7 / form 3"], [KEY_C, "Weave 8 / form 4"]]
static var _map := {}
static var _loaded := false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			for k in d:
				_map[int(k)] = int(d[k])

## The key bound to this default position now.
static func k(default: Key) -> Key:
	_load()
	return _map.get(int(default), int(default)) as Key

static func bind(default: Key, to: Key) -> void:
	_load()
	if to == default:
		_map.erase(int(default))
	else:
		_map[int(default)] = int(to)
	var out := {}
	for key in _map:
		out[str(key)] = _map[key]
	FileAccess.open(FILE, FileAccess.WRITE).store_string(JSON.stringify(out))

static func reset() -> void:
	_map = {}
	_loaded = true
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)

## Which bar slot (0-8) a key is bound to, or -1.
static func slot_of(key: Key) -> int:
	for i in 9:
		if k(KEY_1 + i) == key:
			return i
	return -1

static func name(default: Key) -> String:
	var kk := k(default)
	# (A headless run has no keyboard to ask.)
	var code := DisplayServer.keyboard_get_keycode_from_physical(kk) if DisplayServer.get_name() != "headless" else KEY_NONE
	var s := OS.get_keycode_string(code if code != KEY_NONE else kk)
	return s if s != "" else OS.get_keycode_string(kk)

## The four movement keys as the player's board names them ("WASD", or ",AOE").
static func move() -> String:
	return name(KEY_W) + name(KEY_A) + name(KEY_S) + name(KEY_D)

static func down(default: Key) -> bool:
	return Input.is_physical_key_pressed(k(default))
