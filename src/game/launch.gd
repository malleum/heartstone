class_name Launch
## What the camp hands to the game scene (and command-line flags, for bots and renders).
## Static because a scene change destroys everything else.
static var args := {}
## The last activity's outcome, shown when the player is back in camp.
static var report: Array = []
static var last_name := ""

static func cmdline() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out
