class_name Ghost
extends RefCounted
## A scripted pair of hands: feeds real key and mouse events into the engine on
## given frames, so the path a person's input takes (not a bot's direct calls into
## the sim) can be exercised in a render or a test.
##   -- --ghost=arms | weaves | place | camp | dream
## Each script is a list of [frame, what, ...]: "key" keycode down?, "mouse"
## button down?, "tap" keycode (down and up).

const SCRIPTS := {
	# A fighter in the training yard: every control once.
	arms = [[60, "mouse", MOUSE_BUTTON_LEFT, true], [61, "mouse", MOUSE_BUTTON_LEFT, false],
		[70, "key", KEY_W, true], [150, "key", KEY_W, false],
		[160, "mouse", MOUSE_BUTTON_LEFT, true], [162, "mouse", MOUSE_BUTTON_LEFT, false],
		[180, "mouse", MOUSE_BUTTON_LEFT, true], [182, "mouse", MOUSE_BUTTON_LEFT, false],
		[200, "mouse", MOUSE_BUTTON_LEFT, true], [202, "mouse", MOUSE_BUTTON_LEFT, false],
		[260, "mouse", MOUSE_BUTTON_LEFT, true], [300, "mouse", MOUSE_BUTTON_LEFT, false],
		[360, "mouse", MOUSE_BUTTON_RIGHT, true], [420, "mouse", MOUSE_BUTTON_RIGHT, false],
		[440, "tap", KEY_SPACE],
		[540, "key", KEY_CTRL, true], [560, "mouse", MOUSE_BUTTON_LEFT, true], [562, "mouse", MOUSE_BUTTON_LEFT, false], [600, "key", KEY_CTRL, false],
		[630, "tap", KEY_2], [660, "mouse", MOUSE_BUTTON_LEFT, true], [720, "mouse", MOUSE_BUTTON_LEFT, false],
		[760, "tap", KEY_3], [790, "tap", KEY_F],
		[830, "tap", KEY_4], [850, "mouse", MOUSE_BUTTON_LEFT, true], [852, "mouse", MOUSE_BUTTON_LEFT, false],
		[900, "tap", KEY_1]],
	# A channeller: throw fire, raise the dome, bind, tie off, let go.
	weaves = [[60, "mouse", MOUSE_BUTTON_LEFT, true], [61, "mouse", MOUSE_BUTTON_LEFT, false],
		[90, "tap", KEY_1], [100, "mouse", MOUSE_BUTTON_LEFT, true], [101, "mouse", MOUSE_BUTTON_LEFT, false],
		[160, "tap", KEY_2], [170, "mouse", MOUSE_BUTTON_LEFT, true], [171, "mouse", MOUSE_BUTTON_LEFT, false],
		[240, "tap", KEY_G],
		[280, "tap", KEY_3], [290, "mouse", MOUSE_BUTTON_LEFT, true], [291, "mouse", MOUSE_BUTTON_LEFT, false],
		[360, "tap", KEY_2], [370, "mouse", MOUSE_BUTTON_LEFT, true], [371, "mouse", MOUSE_BUTTON_LEFT, false],
		[420, "tap", KEY_E], [430, "tap", KEY_Q], [436, "tap", KEY_1],
		[440, "mouse", MOUSE_BUTTON_LEFT, true], [500, "mouse", MOUSE_BUTTON_LEFT, false], [510, "tap", KEY_SPACE],
		# Keep a fireball aside (another slot while it is in hand), take it back up, loose it.
		[540, "tap", KEY_1], [550, "mouse", MOUSE_BUTTON_LEFT, true], [575, "tap", KEY_2], [580, "mouse", MOUSE_BUTTON_LEFT, false],
		[610, "tap", KEY_1], [630, "mouse", MOUSE_BUTTON_LEFT, true], [632, "mouse", MOUSE_BUTTON_LEFT, false]],
	# Placing: the other shape, a Wall of Air round you; then a gateway held until
	# whole, let go for the near end, the wheel turning the far end, a click for it.
	place = [[60, "tap", KEY_T], [80, "mouse", MOUSE_BUTTON_LEFT, true], [150, "mouse", MOUSE_BUTTON_LEFT, false],
		[180, "tap", KEY_2], [190, "tap", KEY_T],
		[200, "mouse", MOUSE_BUTTON_LEFT, true], [350, "mouse", MOUSE_BUTTON_LEFT, false],
		[370, "mouse", MOUSE_BUTTON_WHEEL_UP, true], [371, "mouse", MOUSE_BUTTON_WHEEL_UP, false],
		[390, "mouse", MOUSE_BUTTON_LEFT, true], [392, "mouse", MOUSE_BUTTON_LEFT, false]],
	# A duel in the dream: every dream key once, most of them before the shade
	# arrives (4 s in), stepping behind it and chaining it after.
	dream = [[40, "tap", KEY_T], [52, "tap", KEY_H], [64, "tap", KEY_U], [76, "tap", KEY_X], [88, "tap", KEY_V],
		[100, "tap", KEY_SHIFT], [150, "tap", KEY_Z], [260, "tap", KEY_Y], [320, "tap", KEY_I]],
	# The camp: hide and show the sheet, open and close the menu, walk at a doorway.
	camp = [[30, "tap", KEY_H], [60, "tap", KEY_H], [100, "tap", KEY_ESCAPE], [140, "tap", KEY_ESCAPE],
		[180, "key", KEY_W, true], [520, "key", KEY_W, false]],
}

static func step(script: String, frame: int) -> void:
	for row in SCRIPTS.get(script, []):
		if row[0] != frame and not (row[1] == "tap" and row[0] + 2 == frame):
			continue
		if row[1] == "mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = row[2]; ev.pressed = row[3]
			Input.parse_input_event(ev)
		else:
			var ev := InputEventKey.new()
			ev.keycode = row[2]; ev.physical_keycode = row[2]
			ev.pressed = row[3] if row[1] == "key" else row[0] == frame
			Input.parse_input_event(ev)
