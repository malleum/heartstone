class_name Updater
## Keeps a released game up to date by itself. A release (.github/workflows/release.yml)
## carries the game data on its own, heartstone-engine-<godot version>.pck. From the
## camp the game asks GitHub for the latest release; if it is newer, the data is
## downloaded into user://update and the game restarts into it with --main-pack
## (at once if the player has not started anything, else at the next start). A
## release built on a different engine cannot be swapped in like that: the player is
## told to download the new build instead.

const REPO := "malleum/heartstone"
const DIR := "user://update"

static var checked := false
static var newest := ""          # the latest release's tag, once known

## This build's release tag ("" in development, where nothing is updated).
static func tag() -> String:
	if not FileAccess.file_exists("res://build.json"):
		return ""
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://build.json"))
	return String(d.get("tag", "")) if d is Dictionary else ""

## This build's stamp: {tag, commit, date (unix)}; empty when run from source.
static func stamp() -> Dictionary:
	if not FileAccess.file_exists("res://build.json"):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://build.json"))
	return d if d is Dictionary else {}

## "v0.2.0 · b141541 · 17 Nov 2026 23:25", or "run from source".
static func label(st: Dictionary) -> String:
	if st.is_empty():
		return "run from source"
	var parts := []
	if String(st.get("tag", "")) != "": parts.append(st.tag)
	if String(st.get("commit", "")) != "": parts.append(st.commit)
	if int(st.get("date", 0)) > 0:
		# In the player's own time zone (the stamp is UTC).
		var dt := Time.get_datetime_dict_from_unix_time(int(st.date) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
		parts.append("%d %s %d %02d:%02d" % [dt.day, ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][dt.month], dt.year, dt.hour, dt.minute])
	return " · ".join(parts)

## Two builds of the same commit that still differ in version (the server's copy
## of the data was stale): neither is behind by its stamp.
## Which of two builds is behind, by their commit times: "the server", "your game",
## or "" if it cannot be told.
static func behind(mine: Dictionary, theirs: Dictionary) -> String:
	var a := int(mine.get("date", 0)); var b := int(theirs.get("date", 0))
	if a <= 0 or b <= 0 or a == b:
		return ""
	return "your game" if a < b else "the server"

static func engine() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch] if v.patch > 0 else "%d.%d" % [v.major, v.minor]

## At start: a newer downloaded pack waiting, and not already running it? Restart
## into it. True if the game is restarting (the caller should stop).
static func boot(tree: SceneTree) -> bool:
	# Off: Godot's official release builds refuse --main-pack ("compiled without
	# support for path overrides") and abort, so a downloaded pack made every
	# launch die within a second. A pack left from before is cleared, and newer
	# versions are announced instead (check) for a fresh download.
	if FileAccess.file_exists(DIR + "/current.json"):
		DirAccess.remove_absolute(DIR + "/current.json")
	return false
	@warning_ignore("unreachable_code")
	if tag() == "" or OS.get_cmdline_args().has("--main-pack"):
		return false
	var meta := _meta()
	if meta.is_empty() or meta.get("engine", "") != engine() or meta.get("tag", "") == tag() or not FileAccess.file_exists(meta.get("pack", "")):
		return false
	var args := ["--main-pack", ProjectSettings.globalize_path(meta.pack)]
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		args.append("--")
		args.append_array(user)
	OS.create_process(OS.get_executable_path(), args)
	tree.quit()
	return true

static func _meta() -> Dictionary:
	var f := DIR + "/current.json"
	if not FileAccess.file_exists(f):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(f))
	return d if d is Dictionary else {}

## Ask GitHub for the latest release, and fetch its data if it is newer. `idle` is
## asked when the download finishes: true restarts into it there and then.
static func check(host: Node, idle: Callable) -> void:
	if checked or tag() == "" or DisplayServer.get_name() == "headless":
		return
	checked = true
	var req := HTTPRequest.new(); host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var rel = JSON.parse_string(body.get_string_from_utf8())
		if not (rel is Dictionary) or not rel.has("tag_name"):
			return
		newest = rel.tag_name
		if newest == tag() or newest == _meta().get("tag", ""):
			return
		var want := "heartstone-engine-%s.pck" % engine()
		var url := ""
		for a in rel.get("assets", []):
			if a.get("name", "") == want:
				url = a.browser_download_url
		# (Not downloaded and swapped in: see boot. Said, with where to get it.)
		Toast.say("A new version: %s" % newest, "Download it from github.com/%s/releases/latest and replace this one." % REPO, "warn", 14.0))
	req.request("https://api.github.com/repos/%s/releases/latest" % REPO, ["User-Agent: heartstone-updater", "Accept: application/vnd.github+json"])

static func _download(host: Node, url: String, new_tag: String, idle: Callable) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/heartstone-%s.pck" % [DIR, new_tag.validate_filename()]
	var req := HTTPRequest.new(); host.add_child(req)
	req.download_file = path + ".part"
	Toast.say("Updating to %s" % new_tag, "Downloading in the background.", "info", 5.0)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			Toast.say("The update did not download", "It will try again next time.", "warn")
			return
		DirAccess.rename_absolute(path + ".part", path)
		var f := FileAccess.open(DIR + "/current.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({tag = new_tag, engine = engine(), pack = path}))
		f.close()
		if idle.call():
			boot(host.get_tree())
		else:
			Toast.say("%s is ready" % new_tag, "It starts the next time you open the game.", "good", 8.0))
	req.request(url, ["User-Agent: heartstone-updater"])
