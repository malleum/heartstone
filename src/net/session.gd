class_name Session
extends Node
## Host-authoritative co-op, as in balefire: the host owns the one true Sim, clients
## send intent (movement, cast requests) and receive snapshots and events to draw.
## Single-player is the same code with the host as the only player.
##
## Characters stay on their owner's machine. The host borrows each profile to run
## the rules, and at the end sends back each player's tally; every client then
## applies Progression.award to their own save. (Friends-only game: we trust
## clients' profiles rather than building anti-cheat.)

signal started(my_id: int, activity: String)
signal snapshot(snap: Dictionary)
signal events(list: Array)
signal finished(success: bool, report: Array)
signal refused(why: String)
signal rejected(why: String)                    # could not join at all
signal vaulted(status: String, kept: Dictionary)  # the server's character store answered

const PORT := 24680
const PROTO := 4               # bump when an RPC or the snapshot format changes
const SNAP_EVERY := 2          # physics ticks between snapshots (30 Hz sim -> 15 Hz)

var sim: Sim                   # host only
var profile: Dictionary        # this machine's character
var my_id := 0
var activity := ""
var is_host := false
var dedicated := false         # a server with no player of its own (tools: src/net/server.gd)
var word := ""                 # host: the word a joiner must give, if any
var _peer_ent := {}            # peer id -> sim entity id (host)
var _tick := 0

func _init() -> void:
	# RPCs are addressed by node path, so every machine keeps its Session at /root/Session.
	name = "Session"

## Two machines can play together only if they speak the same protocol and hold
## the same tables of weaves, enemies and activities.
static func version() -> String:
	var data := ""
	for f in ["weaves", "enemies", "activities", "weapons"]:
		data += FileAccess.get_file_as_string("res://data/%s.json" % f)
	return "%d-%s" % [PROTO, data.md5_text().left(8)]

## "host" or "host:port".
static func split_address(address: String) -> Array:
	var parts := address.strip_edges().split(":")
	return [parts[0], int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else PORT]

## A dedicated server: it has no character, starts a fight when the first player
## asks for one, and keeps characters for players who want them stored.
func serve(port := PORT, join_word := "") -> Error:
	Rules.load_data()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 12)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	is_host = true; dedicated = true; word = join_word
	return OK

func host(activity_id: String, my_profile: Dictionary, port := PORT) -> Error:
	Rules.load_data()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 5)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	is_host = true; profile = my_profile; activity = activity_id
	sim = Sim.new(activity_id, randi())
	if not my_profile.is_empty():
		my_id = sim.add_player(my_profile)
		_peer_ent[1] = my_id
		started.emit(my_id, activity)
	return OK

## want: the activity to start if the host is a server with nothing running.
func join(address: String, my_profile: Dictionary, want := "", their_word := "") -> Error:
	Rules.load_data()
	profile = my_profile
	return _connect(address, func() -> void: _hello.rpc_id(1, profile, want, their_word, version()), func() -> void: rejected.emit("could not reach " + address))

func _connect(address: String, on_up: Callable, on_fail: Callable) -> Error:
	var a := split_address(address)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(a[0], a[1])
	if err != OK:
		on_fail.call()
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(on_up, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(on_fail, CONNECT_ONE_SHOT)
	return OK

## One round trip to a server's character store. Send the local copy (or {} if this
## machine has none); the server keeps whichever has channelled longer and answers
## with it through `vaulted`. Growth only goes up, so the longer one is the newer.
func vault_sync(address: String, name_: String, key: String, local: Dictionary, their_word := "") -> void:
	_connect(address, func() -> void: _vault.rpc_id(1, name_, key, their_word, local), func() -> void: vaulted.emit("could not reach " + address, {}))

# --- intent: called locally, routed to the host --------------------------------

func send_input(move: Vector3, yaw: float) -> void:
	if is_host:
		sim.set_input(my_id, move, yaw)
	else:
		_move.rpc_id(1, move, yaw)

func cast(weave: String, aim: Vector3) -> void:
	if is_host:
		_do_cast(1, weave, aim)
	else:
		_cast_req.rpc_id(1, weave, aim)

## Arms. kind: light | heavy | low | throw; charge is how far a bow was drawn.
func attack(kind: String, aim: Vector3, charge := 1.0) -> void:
	if is_host: _do_arms(1, "attack", [kind, aim, charge])
	else: _arms.rpc_id(1, "attack", [kind, aim, charge])

func guard(on: bool) -> void:
	if is_host: _do_arms(1, "guard", [on])
	else: _arms.rpc_id(1, "guard", [on])

func duck(on: bool) -> void:
	if is_host: _do_arms(1, "duck", [on])
	else: _arms.rpc_id(1, "duck", [on])

func dodge(dir: Vector3, rolling: bool) -> void:
	if is_host: _do_arms(1, "dodge", [dir, rolling])
	else: _arms.rpc_id(1, "dodge", [dir, rolling])

## Tie off the held weave of this name.
func tie(weave: String) -> void:
	if is_host: _do_arms(1, "tie", [weave])
	else: _arms.rpc_id(1, "tie", [weave])

func equip(weapon: String) -> void:
	if is_host: _do_arms(1, "equip", [weapon])
	else: _arms.rpc_id(1, "equip", [weapon])

# --- host side ------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _arms(what: String, a: Array) -> void:
	_do_arms(multiplayer.get_remote_sender_id(), what, a)

func _do_arms(peer: int, what: String, a: Array) -> void:
	var ent: int = _peer_ent.get(peer, 0)
	if ent == 0 or sim == null:
		return
	var why := ""
	# Arguments come from another machine: check their shapes before the sim sees them.
	match what:
		"attack":
			if a.size() == 3 and a[0] is String and a[1] is Vector3 and (a[2] is float or a[2] is int):
				why = sim.request_attack(ent, a[0], a[1], float(a[2]))
		"guard":
			if a.size() == 1 and a[0] is bool: sim.set_guard(ent, a[0])
		"duck":
			if a.size() == 1 and a[0] is bool: sim.set_duck(ent, a[0])
		"dodge":
			if a.size() == 2 and a[0] is Vector3 and a[1] is bool: why = sim.request_dodge(ent, a[0], a[1])
		"equip":
			if a.size() == 1 and a[0] is String: why = sim.equip(ent, a[0])
		"tie":
			if a.size() == 1 and a[0] is String and Rules.weaves.has(a[0]): why = sim.tie(ent, a[0])
	if why != "" and why != "busy":
		if peer == 1: refused.emit(why)
		else: _refused.rpc_id(peer, why)

@rpc("any_peer", "reliable")
func _hello(their_profile: Dictionary, want: String, their_word: String, their_version: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not is_host or _peer_ent.has(peer):
		return
	if their_version != version():
		_rejected.rpc_id(peer, "the host runs a different version of the game (%s, yours is %s): update both" % [version(), their_version])
		return
	if (word != "" and their_word != word) or not Profile.valid(their_profile):
		_rejected.rpc_id(peer, "the host turned you away (wrong word, or a character it cannot read)")
		return
	if dedicated and sim == null:
		activity = want if Rules.activities.has(want) and not want.begins_with("_") else "tarwins_gap_watch"
		sim = Sim.new(activity, randi()); _tick = 0
		print("SERVER begins %s for %s" % [activity, their_profile.name])
	if sim == null:
		return
	var spot := Vector3((_peer_ent.size() % 5 - 2) * 2.0, 0, 2.0)
	_peer_ent[peer] = sim.add_player(their_profile, spot)
	_welcome.rpc_id(peer, _peer_ent[peer], activity)
	# A latecomer missed the events that introduced everyone already on the field.
	_events.rpc_id(peer, sim.roster())

const VAULT := "user://vault"

@rpc("any_peer", "reliable")
func _vault(name_: String, key: String, their_word: String, theirs: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not dedicated:
		return
	var file := "%s/%s.json" % [VAULT, name_.to_lower().validate_filename()]
	var kept := {}
	var lock := (name_.to_lower() + "/" + key).sha256_text()
	if FileAccess.file_exists(file):
		var row = JSON.parse_string(FileAccess.get_file_as_string(file))
		if row is Dictionary and row.get("lock", "") != lock:
			_vault_reply.rpc_id(peer, "that name is kept under another passphrase", {})
			return
		if row is Dictionary:
			kept = row.get("profile", {})
	var status := ""
	if word != "" and their_word != word:
		status = "wrong word"
	elif key.length() < 4 or name_.strip_edges() == "":
		status = "the passphrase needs four letters or more"
	elif not theirs.is_empty() and (not Profile.valid(theirs) or theirs.name.to_lower() != name_.to_lower() or JSON.stringify(theirs).length() > 65536):
		status = "the server cannot read that character"
	if status != "":
		_vault_reply.rpc_id(peer, status, {})
		return
	if not theirs.is_empty() and (kept.is_empty() or float(theirs.seconds) >= float(kept.get("seconds", 0.0))):
		kept = theirs
		DirAccess.make_dir_recursive_absolute(VAULT)
		FileAccess.open(file, FileAccess.WRITE).store_string(JSON.stringify({lock = lock, profile = kept}))
		print("SERVER keeps %s (%d s)" % [name_, int(kept.seconds)])
	_vault_reply.rpc_id(peer, "" if not kept.is_empty() else "the server has no character of that name", kept)

@rpc("any_peer", "unreliable_ordered")
func _move(move: Vector3, yaw: float) -> void:
	var ent: int = _peer_ent.get(multiplayer.get_remote_sender_id(), 0)
	if ent:
		sim.set_input(ent, move, yaw)

@rpc("any_peer", "reliable")
func _cast_req(weave: String, aim: Vector3) -> void:
	_do_cast(multiplayer.get_remote_sender_id(), weave, aim)

func _do_cast(peer: int, weave: String, aim: Vector3) -> void:
	var ent: int = _peer_ent.get(peer, 0)
	if ent == 0 or not Rules.weaves.has(weave):
		return
	var why := sim.request_cast(ent, weave, aim)
	if why != "":
		if peer == 1: refused.emit(why)
		else: _refused.rpc_id(peer, why)

func _on_left(peer: int) -> void:
	if _peer_ent.has(peer):
		if sim != null:
			sim.ents[_peer_ent[peer]].alive = false
		_peer_ent.erase(peer)
	if dedicated and _peer_ent.is_empty() and sim != null:
		# Nobody is left: the next player to arrive starts something fresh.
		print("SERVER empty, %s abandoned" % activity)
		sim = null

func _physics_process(dt: float) -> void:
	if not is_host or sim == null or (sim.over and _tick < 0):
		return
	sim.step(dt)
	_tick += 1
	if not sim.events.is_empty():
		var ev := sim.events.duplicate()
		sim.events.clear()
		_events.rpc(ev)
		events.emit(ev)
	if _tick % SNAP_EVERY == 0:
		var s := sim.snapshot()
		# Entities travel as one flat array of 32-bit floats: a fifth of the size of
		# nested Variants, which keeps a crowded field inside one packet.
		var flat := PackedFloat32Array()
		for e in s.ents:
			flat.append_array(PackedFloat32Array(e))
		_snap.rpc(s.t, flat, s.fx)
		snapshot.emit(s)
	if sim.over:
		_tick = -1
		for peer in _peer_ent:
			var tl: Dictionary = sim.tallies[_peer_ent[peer]]
			if peer == 1: _apply_result(tl, sim.success)
			else: _result.rpc_id(peer, tl, sim.success)
		if dedicated:
			print("SERVER %s over, success=%s" % [activity, sim.success])
			sim = null; _peer_ent.clear()

# --- client side ------------------------------------------------------------------

@rpc("authority", "reliable")
func _welcome(ent: int, activity_id: String) -> void:
	my_id = ent; activity = activity_id
	started.emit(my_id, activity)

@rpc("authority", "unreliable_ordered")
func _snap(t: float, flat: PackedFloat32Array, fx: Array) -> void:
	var es := []
	for i in range(0, flat.size(), 7):
		es.append([int(flat[i]), flat[i + 1], flat[i + 2], flat[i + 3], flat[i + 4], flat[i + 5], int(flat[i + 6])])
	snapshot.emit({t = t, ents = es, fx = fx})

@rpc("authority", "reliable")
func _events(list: Array) -> void:
	events.emit(list)

@rpc("authority", "reliable")
func _refused(why: String) -> void:
	refused.emit(why)

@rpc("authority", "reliable")
func _rejected(why: String) -> void:
	rejected.emit(why)

@rpc("authority", "reliable")
func _vault_reply(status: String, kept: Dictionary) -> void:
	multiplayer.multiplayer_peer = null
	vaulted.emit(status, kept)

@rpc("authority", "reliable")
func _result(tally: Dictionary, success: bool) -> void:
	_apply_result(tally, success)

## The moment an activity pays into the persistent character.
func _apply_result(tally: Dictionary, success: bool) -> void:
	var report := Progression.award(profile, tally, activity, success)
	Profile.save(profile)
	finished.emit(success, report)
