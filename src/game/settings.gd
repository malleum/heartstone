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

## Picture quality: 0 low, 1 medium, 2 high. Render scale, shadow map and grass; the
## frame cap and vsync are always on (an uncapped, vsync-less game ran the GPU flat
## out). `--uncap` lifts them for measuring.
static var quality := 2
const QUALITY_NAMES := ["Low", "Medium", "High"]

static func grass_stride() -> int:
	return [3, 2, 1][clampi(quality, 0, 2)]

static func book_limit() -> int:
	return story if story_open else 6

static func load_and_apply() -> void:
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			volume = clampf(float(d.get("volume", volume)), 0.0, 1.0)
			quality = clampi(int(d.get("quality", quality)), 0, 2)
			story = int(d.get("story", story)); story_open = bool(d.get("story_open", story_open))
	apply()

static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.001)
	var uncap := "--uncap" in OS.get_cmdline_user_args()
	Engine.max_fps = 0   # vsync holds it to the monitor's refresh rate; no cap of our own
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if uncap else DisplayServer.VSYNC_ENABLED)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.scaling_3d_scale = [0.67, 0.85, 1.0][clampi(quality, 0, 2)]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][clampi(quality, 0, 2)], true)

static func save() -> void:
	FileAccess.open(FILE, FileAccess.WRITE).store_string(JSON.stringify({volume = volume, quality = quality, story = story, story_open = story_open}))
