class_name Settings
## The player's own settings that are not keys (those are Keys): sound for now.
## Kept in user://settings.json.
const FILE := "user://settings.json"
static var volume := 0.8
## How far into the books this player has read: weaves and Talents from later books
## are hidden (Rules.TALENT_BOOK, a weave's "book"). Through book 6 unless the hidden
## choice was opened (ten clicks on the menu's title) and "all books" chosen.
static var story := 6
static var story_open := false

static func book_limit() -> int:
	return story if story_open else 6

static func load_and_apply() -> void:
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
			story = int(d.get("story", story)); story_open = bool(d.get("story_open", story_open))
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)

static func save() -> void:
	FileAccess.open(FILE, FileAccess.WRITE).store_string(JSON.stringify({volume = volume, story = story, story_open = story_open}))
