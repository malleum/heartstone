class_name Ghost
extends RefCounted
## A scripted pair of hands: feeds real key and mouse events into the engine on
## given frames, so the path a person's input takes (not a bot's direct calls into
## the sim) can be exercised in a render or a test.
##   -- --ghost=arms | weaves | place | camp | dream
## Each script is a list of [frame, what, ...]: "key" keycode down?, "mouse"
## button down?, "tap" keycode (down and up). [frame, "when", flag, rows]: from that
## frame on, once the game says `flag` (Ghost.flags), play `rows` (frames counted
## from then), so a script waits for the game rather than guessing how long it takes.

const SCRIPTS := {
	# A fighter in the training yard: every control once.
	arms = [[60, "mouse", MOUSE_BUTTON_LEFT, true], [61, "mouse", MOUSE_BUTTON_LEFT, false],
		[70, "key", KEY_W, true], [150, "key", KEY_W, false],
		[160, "mouse", MOUSE_BUTTON_LEFT, true], [162, "mouse", MOUSE_BUTTON_LEFT, false],
		[180, "mouse", MOUSE_BUTTON_LEFT, true], [182, "mouse", MOUSE_BUTTON_LEFT, false],
		[200, "mouse", MOUSE_BUTTON_LEFT, true], [202, "mouse", MOUSE_BUTTON_LEFT, false],
		[260, "mouse", MOUSE_BUTTON_LEFT, true], [300, "mouse", MOUSE_BUTTON_LEFT, false],
		[360, "mouse", MOUSE_BUTTON_RIGHT, true], [420, "mouse", MOUSE_BUTTON_RIGHT, false],
		[440, "tap", KEY_SHIFT],
		[540, "key", KEY_CTRL, true], [560, "mouse", MOUSE_BUTTON_LEFT, true], [562, "mouse", MOUSE_BUTTON_LEFT, false], [600, "key", KEY_CTRL, false],
		[630, "tap", KEY_2], [660, "mouse", MOUSE_BUTTON_LEFT, true], [720, "mouse", MOUSE_BUTTON_LEFT, false],
		[760, "tap", KEY_3], [790, "tap", KEY_CAPSLOCK],
		[830, "tap", KEY_1], [850, "tap", KEY_5],
		[900, "tap", KEY_1]],
	# A channeller (the held-key way): 1 weaves fire, 2 raises the dome, Q ties it off,
	# 3 binds nobody; a fireball clicked and held, loosed on letting go; a roll mid-weave
	# keeps the weave; then fire and the dome made together.
	weaves = [[60, "mouse", MOUSE_BUTTON_LEFT, true], [61, "mouse", MOUSE_BUTTON_LEFT, false],
		[90, "tap", KEY_1],
		[160, "tap", KEY_2],
		[240, "tap", KEY_Q],
		[280, "tap", KEY_3],
		[360, "tap", KEY_2],
		[436, "tap", KEY_1], [440, "mouse", MOUSE_BUTTON_LEFT, true], [470, "tap", KEY_SHIFT], [500, "mouse", MOUSE_BUTTON_LEFT, false],
		[540, "tap", KEY_2], [560, "tap", KEY_1], [565, "tap", KEY_2]],
	# Placing: the other shape, a Wall of Air round you; then a gateway held until
	# whole, let go for the near end, the wheel turning the far end, a click for it.
	place = [[60, "tap", KEY_1], [70, "mouse", MOUSE_BUTTON_MIDDLE, true], [71, "mouse", MOUSE_BUTTON_MIDDLE, false],
		[200, "tap", KEY_2], [215, "mouse", MOUSE_BUTTON_LEFT, true], [216, "mouse", MOUSE_BUTTON_LEFT, false],
		[220, "when", "marked", [[10, "mouse", MOUSE_BUTTON_WHEEL_UP, true], [11, "mouse", MOUSE_BUTTON_WHEEL_UP, false],
			[30, "mouse", MOUSE_BUTTON_LEFT, true], [32, "mouse", MOUSE_BUTTON_LEFT, false]]]],
	# A duel in the dream: every dream key once, most of them before the shade
	# arrives (4 s in), stepping behind it and chaining it after.
	dream = [[40, "tap", KEY_T], [52, "tap", KEY_5], [64, "tap", KEY_Z], [76, "tap", KEY_V], [88, "tap", KEY_X],
		[100, "tap", KEY_E], [150, "tap", KEY_R], [260, "tap", KEY_F], [320, "tap", KEY_TAB]],
	# Jumps: standing, then running (pictures of the leap).
	jumps = [[30, "tap", KEY_SPACE], [70, "key", KEY_W, true], [95, "tap", KEY_SPACE], [140, "key", KEY_W, false]],
	# Pictures of the forms row: the sword in hand and its forms; a form; the bow and
	# its forms; another; the knife.
	formsdemo = [[40, "tap", KEY_1], [90, "tap", KEY_Z], [160, "tap", KEY_2], [210, "tap", KEY_X], [290, "tap", KEY_3]],
	# The camp's yard: take the mouse, strike or weave at a post, roll, again.
	yard = [[30, "mouse", MOUSE_BUTTON_LEFT, true], [31, "mouse", MOUSE_BUTTON_LEFT, false],
		[60, "tap", KEY_3], [150, "tap", KEY_SHIFT], [200, "tap", KEY_3]],
	# The camp: hide and show the sheet, open and close the menu, walk at a doorway.
	camp = [[30, "tap", KEY_H], [60, "tap", KEY_H], [100, "tap", KEY_ESCAPE], [140, "tap", KEY_ESCAPE],
		[180, "key", KEY_W, true], [520, "key", KEY_W, false]],
}

static var flags := {}     # what the game says is so this frame (ready, marked)
static var _fired := {}    # "when" rows already started, by index
static var _later := []    # [frame, row] scheduled by them

static func step(script: String, frame: int) -> void:
	var rows: Array = SCRIPTS.get(script, [])
	for i in rows.size():
		var row: Array = rows[i]
		if row[1] == "when" and frame >= row[0] and not _fired.has(i) and flags.get(row[2], false):
			_fired[i] = true
			for r in row[3]:
				var abs_row: Array = r.duplicate(); abs_row[0] = frame + int(r[0])
				_later.append(abs_row)
	for row in rows.filter(func(r: Array) -> bool: return r[1] != "when") + _later:
		_play(row, frame)

static func _play(row: Array, frame: int) -> void:
	if row[0] != frame and not (row[1] == "tap" and row[0] + 2 == frame):
		return
	if row[1] == "mouse":
		var ev := InputEventMouseButton.new()
		ev.button_index = row[2]; ev.pressed = row[3]
		Input.parse_input_event(ev)
	else:
		var ev := InputEventKey.new()
		ev.keycode = row[2]; ev.physical_keycode = row[2]
		ev.pressed = row[3] if row[1] == "key" else row[0] == frame
		Input.parse_input_event(ev)
