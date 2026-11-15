class_name Keys
extends RefCounted
## Every binding in the game is by where a key sits on the board (as on a US
## QWERTY one), never by the letter printed on it: the hand rests in the same place
## on Dvorak, Colemak or AZERTY, and nobody has to switch layout to play. So the
## code says KEY_W and means "the key where W is on QWERTY"; hints on screen ask
## the system which letter the player's own layout has there.

static func name(k: Key) -> String:
	var code := DisplayServer.keyboard_get_keycode_from_physical(k)
	var s := OS.get_keycode_string(code if code != KEY_NONE else k)
	return s if s != "" else OS.get_keycode_string(k)

## The four movement keys as the player's board names them ("WASD", or ",AOE").
static func move() -> String:
	return name(KEY_W) + name(KEY_A) + name(KEY_S) + name(KEY_D)

static func down(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)
