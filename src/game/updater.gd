class_name Updater
## Keeps a released game up to date by itself (the way malleum/ultimategrapple does).
## A release (.github/workflows/release.yml) is one executable with the game data
## inside it (embed_pck), published bare beside the zips, with build.json: the tag,
## commit and commit time it was built from. From the camp the game asks GitHub for
## the latest release and its build.json; if that is a newer build than the one baked
## into this executable, the executable for this platform is downloaded next to ours
## and swapped in. Linux replaces the file (the running game keeps its old copy);
## Windows cannot overwrite a running .exe but can rename it, so the old one moves to
## .old and is removed at the next start. The game restarts into it at once if the
## player is idle in the camp, else it is there the next time they open the game.
##
## Only for release builds that know their tag: never from source, under Nix (the
## store is read-only), for the dedicated server or headless runs.

const REPO := "malleum/heartstone"
const RELEASES := "https://github.com/malleum/heartstone/releases/latest"
const ASSET_LINUX := "heartstone.x86_64"
const ASSET_WINDOWS := "heartstone.exe"
const MIN_SIZE := 8 * 1024 * 1024   # the real thing is around a hundred MB
## The release this code is, or the one being made: raised just before a v* tag is
## pushed (the release workflow refuses a tag that does not match). Every build knows
## it, the server's from source too, so each can say which version it is.
const VERSION := "0.2.12"

static var checked := false
static var newest := ""          # the latest release's tag, once known
static var installed := ""       # a newer build already swapped in, waiting for a restart

## This build's release tag ("" in development, where nothing is updated).
static func tag() -> String:
	return String(stamp().get("tag", ""))

## "v0.2.11": the release tag, or for a build from source the version it belongs to.
static func release() -> String:
	return tag() if tag() != "" else "v" + VERSION

## This build's stamp: {tag, engine, commit, date (unix)}; empty when run from source.
static func stamp() -> Dictionary:
	if not FileAccess.file_exists("res://build.json"):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://build.json"))
	if not d is Dictionary:
		return {}
	if String(d.get("tag", "")) == "":
		d.release = "v" + VERSION
	return d

## "v0.2.0 · b141541 · 17 Nov 2026 23:25", or "run from source".
static func label(st: Dictionary) -> String:
	if st.is_empty():
		return "run from source"
	var parts := []
	if String(st.get("tag", "")) != "": parts.append(st.tag)
	elif String(st.get("release", "")) != "": parts.append(st.release)
	if String(st.get("commit", "")) != "": parts.append(st.commit)
	if int(st.get("date", 0)) > 0:
		# In the player's own time zone (the stamp is UTC).
		var dt := Time.get_datetime_dict_from_unix_time(int(st.date) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
		parts.append("%d %s %d %02d:%02d" % [dt.day, ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][dt.month], dt.year, dt.hour, dt.minute])
	return " · ".join(parts)

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

## Can this build replace itself?
static func supported() -> bool:
	if tag() == "" or not OS.has_feature("template") or DisplayServer.get_name() == "headless":
		return false
	return not OS.get_executable_path().begins_with("/nix/store")

static func _asset_name() -> String:
	return ASSET_WINDOWS if OS.has_feature("windows") else ASSET_LINUX

## At start: clear what the last update left behind. Never restarts (returns false):
## the swap already happened when the update was downloaded.
static func boot(_tree: SceneTree) -> bool:
	if not supported():
		return false
	var exe := OS.get_executable_path()
	for left in [exe + ".old", exe + ".download"]:
		if FileAccess.file_exists(left):
			DirAccess.remove_absolute(left)
	# The data used to sit beside the executable; it is inside it now, and a stale
	# copy beside it would only confuse.
	var side := exe.get_basename() + ".pck"
	if stamp().get("embedded", false) and FileAccess.file_exists(side):
		DirAccess.remove_absolute(side)
	# What the old way of updating left in user://update.
	if DirAccess.dir_exists_absolute("user://update"):
		for f in DirAccess.get_files_at("user://update"):
			DirAccess.remove_absolute("user://update/" + f)
		DirAccess.remove_absolute("user://update")
	return false

## Is `remote` (a release's build.json) a newer build than `mine`?
static func is_newer(mine: Dictionary, remote: Dictionary) -> bool:
	if String(remote.get("commit", "")) == "" or remote.get("commit", "") == mine.get("commit", ""):
		return false
	return int(remote.get("date", 0)) > int(mine.get("date", 0))

static func _asset_url(rel: Dictionary, name: String) -> Dictionary:
	for a in rel.get("assets", []):
		if a is Dictionary and String(a.get("name", "")) == name:
			return a
	return {}

## Ask GitHub for the latest release; if it is newer, fetch and install it. `idle`
## is asked once it is in place: true restarts into it there and then.
static func check(host: Node, idle: Callable) -> void:
	if checked or tag() == "" or DisplayServer.get_name() == "headless":
		return
	checked = true
	_fetch(host, "https://api.github.com/repos/%s/releases/latest" % REPO, func(body: PackedByteArray) -> void:
		var rel = JSON.parse_string(body.get_string_from_utf8())
		if not (rel is Dictionary) or not rel.has("tag_name"):
			return
		newest = rel.tag_name
		var bj := _asset_url(rel, "build.json")
		var exe := _asset_url(rel, _asset_name())
		if bj.is_empty() or exe.is_empty():
			if newest != tag():
				Toast.say("A new version: %s" % newest, "Download it from %s and replace this one." % RELEASES, "warn", 14.0)
			return
		_fetch(host, String(bj.browser_download_url), func(b2: PackedByteArray) -> void:
			var remote = JSON.parse_string(b2.get_string_from_utf8())
			if not (remote is Dictionary and is_newer(stamp(), remote)):
				return
			if not supported():
				Toast.say("A new version: %s" % newest, "Download it from %s." % RELEASES, "warn", 14.0)
				return
			_download(host, exe, String(remote.get("tag", newest)), idle)))

static func _fetch(host: Node, url: String, then: Callable) -> void:
	var req := HTTPRequest.new(); req.timeout = 20.0
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			then.call(body))   # offline or rate-limited: try again next start
	if req.request(url, ["User-Agent: heartstone-updater", "Accept: application/vnd.github+json"]) != OK:
		req.queue_free()

static func _download(host: Node, asset: Dictionary, new_tag: String, idle: Callable) -> void:
	var exe := OS.get_executable_path()
	var part := exe + ".download"
	DirAccess.remove_absolute(part)
	var probe := FileAccess.open(part, FileAccess.WRITE)
	if probe == null:
		Toast.say("A new version: %s" % new_tag, "The game cannot write to its own folder (%s). Download it from %s." % [exe.get_base_dir(), RELEASES], "warn", 14.0)
		return
	probe.close()
	Toast.say("Updating to %s" % new_tag, "Downloading in the background (%d MB)." % int(int(asset.get("size", 0)) / 1048576), "info", 6.0)
	var req := HTTPRequest.new()
	req.use_threads = true
	req.download_file = part
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		req.queue_free()
		var size := 0
		var f := FileAccess.open(part, FileAccess.READ)
		if f:
			size = f.get_length(); f.close()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200 or size < MIN_SIZE or (int(asset.get("size", 0)) > 0 and size != int(asset.size)):
			DirAccess.remove_absolute(part)
			Toast.say("The update did not download", "It will try again next time (or get it from %s)." % RELEASES, "warn", 10.0)
			return
		var err := swap(exe, part, OS.has_feature("windows"))
		if err != "":
			Toast.say("The update could not be put in place", "%s. Get it from %s." % [err, RELEASES], "warn", 14.0)
			return
		installed = new_tag
		if is_instance_valid(host) and idle.call():
			Toast.say("Updated to %s" % new_tag, "Restarting...", "good", 3.0)
			host.get_tree().create_timer(1.2).timeout.connect(func() -> void: restart(host.get_tree()))
		else:
			Toast.say("%s is installed" % new_tag, "It starts the next time you open the game.", "good", 10.0))
	if req.request(String(asset.browser_download_url), ["User-Agent: heartstone-updater"]) != OK:
		req.queue_free()
		DirAccess.remove_absolute(part)

## Put `new_path` in place of the executable at `exe`. "" or what went wrong (the
## old executable is left working).
static func swap(exe: String, new_path: String, windows: bool) -> String:
	if not windows:
		OS.execute("chmod", PackedStringArray(["+x", new_path]))
		if DirAccess.rename_absolute(new_path, exe) != OK:
			return "Could not replace %s (no permission?)" % exe
		return ""
	var old := exe + ".old"
	DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		return "Could not move %s aside (no permission?)" % exe
	if DirAccess.rename_absolute(new_path, exe) != OK:
		DirAccess.rename_absolute(old, exe)
		return "Could not put the new version in place"
	return ""

static func restart(tree: SceneTree) -> void:
	var args := Array(OS.get_cmdline_args())
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		args.append("--")
		args.append_array(user)
	OS.create_process(OS.get_executable_path(), PackedStringArray(args))
	tree.quit()
