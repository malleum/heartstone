class_name Settings
## The player's own settings that are not keys (those are Keys): sound for now.
## Kept in user://settings.json.
const FILE := "user://settings.json"
static var volume := 0.8

static func load_and_apply() -> void:
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)

static func save() -> void:
	FileAccess.open(FILE, FileAccess.WRITE).store_string(JSON.stringify({volume = volume}))
