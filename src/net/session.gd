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
signal lobby(fights: Array)                     # the server said who is playing what

const PORT := 24680
const PROTO := 6               # bump when an RPC or the snapshot format changes
const SNAP_EVERY := 2          # physics ticks between snapshots (30 Hz sim -> 15 Hz)

const MAX_ROOMS := 8
const ROOM_SIZE := 6

var profile: Dictionary        # this machine's character
var my_id := 0
var activity := ""
var is_host := false
var dedicated := false         # a server with no player of its own (tools: src/net/server.gd)
var word := ""                 # host: the word a joiner must give, if any
## A host runs fights in rooms: name -> {sim, activity, peers {peer id: entity id},
## tick}. Someone hosting from the camp has one room, ""; a server has one for
## every group that asked for its own.
var _rooms := {}
var _room_of := {}             # peer id -> room name
## The fight this machine is hosting for itself (bots and renders drive it).
var sim: Sim:
	get: return _rooms[""].sim if _rooms.has("") else null
## Kept for tests that wait for everyone to arrive: who is in the host's own room.
var _peer_ent: Dictionary:
	get: return _rooms[""].peers if _rooms.has("") else {}

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
	var err := peer.create_server(port, 32)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	multiplayer.peer_connected.connect(_greet)
	is_host = true; dedicated = true; word = join_word
	return OK

# --- secrets ---------------------------------------------------------------------
# This build of Godot has no encrypted transport, so nothing secret is sent. A host
# greets each arrival with a number used once. The word is proved by a hash of
# word and number, and a character's passphrase lock travels sealed under a key
# made from the same two: someone listening learns neither, and cannot replay
# what they heard. (With no word set there is nothing to make a key from, and the
# seal is only a veil: say so in SERVER.md.)

var _nonces := {}              # host: peer id -> the number it was greeted with
var _nonce := ""               # client: the number this host greeted us with
var _on_nonce: Callable

func _greet(peer: int) -> void:
	_nonces[peer] = Crypto.new().generate_random_bytes(16).hex_encode()
	_hail.rpc_id(peer, _nonces[peer])

@rpc("authority", "reliable")
func _hail(nonce: String) -> void:
	_nonce = nonce
	if _on_nonce.is_valid():
		_on_nonce.call()

static func _proof(secret: String, nonce: String) -> String:
	return (secret + "/" + nonce).sha256_text() if secret != "" else ""

static func _seal(text: String, secret: String, nonce: String, open := false) -> String:
	var aes := AESContext.new()
	var key := (secret + "/" + nonce + "/seal").sha256_buffer()
	var iv := nonce.hex_decode()
	if iv.size() != 16:
		return ""
	if open:
		var raw := text.hex_decode()
		if raw.is_empty() or raw.size() % 16 != 0:
			return ""
		aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
		var out := aes.update(raw); aes.finish()
		return out.get_string_from_utf8().strip_edges()
	var data := text.to_utf8_buffer()
	while data.size() % 16 != 0:
		data.append(32)
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var sealed := aes.update(data); aes.finish()
	return sealed.hex_encode()

func host(activity_id: String, my_profile: Dictionary, port := PORT) -> Error:
	Rules.load_data()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 5)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_left)
	multiplayer.peer_connected.connect(_greet)
	is_host = true; profile = my_profile; activity = activity_id
	_rooms[""] = {sim = Sim.new(activity_id, randi()), activity = activity_id, peers = {}, tick = 0}
	if not my_profile.is_empty():
		my_id = _rooms[""].sim.add_player(my_profile)
		_rooms[""].peers[1] = my_id
		_room_of[1] = ""
		started.emit(my_id, activity)
	return OK

## want: the activity to start if the host is a server with nothing running.
## room: on a server, the name of the group to play with ("" is the common room).
func join(address: String, my_profile: Dictionary, want := "", their_word := "", room := "") -> Error:
	Rules.load_data()
	profile = my_profile
	return _connect(address, func() -> void: _hello.rpc_id(1, profile, want, _proof(their_word, _nonce), version(), room), func() -> void: rejected.emit("could not reach " + address))

## Connect, and act once the host has greeted us with its number (see secrets).
func _connect(address: String, on_up: Callable, on_fail: Callable) -> Error:
	var a := split_address(address)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(a[0], a[1])
	if err != OK:
		on_fail.call()
		return err
	multiplayer.multiplayer_peer = peer
	_on_nonce = on_up
	multiplayer.connection_failed.connect(on_fail, CONNECT_ONE_SHOT)
	return OK

## One round trip to a server's character store. Send the local copy (or {} if this
## machine has none); the server keeps whichever has channelled longer and answers
## with it through `vaulted`. Growth only goes up, so the longer one is the newer.
func vault_sync(address: String, name_: String, key: String, local: Dictionary, their_word := "") -> void:
	if key.length() < 4 or name_.strip_edges() == "":
		vaulted.emit.call_deferred("the passphrase needs four letters or more", {})
		return
	# The passphrase itself never leaves this machine: only its lock, sealed.
	var lock := (name_.to_lower() + "/" + key).sha256_text()
	_connect(address, func() -> void: _vault.rpc_id(1, name_, _seal(lock, their_word, _nonce), _proof(their_word, _nonce), local), func() -> void: vaulted.emit("could not reach " + address, {}))

## Ask a server who is playing what, answered through `lobby`: a list of
## {room, activity, players [names], t (seconds in)}. Empty if nobody, or no answer.
func ask_lobby(address: String, their_word := "") -> void:
	_connect(address, func() -> void: _who.rpc_id(1, _proof(their_word, _nonce)), func() -> void: lobby.emit([]))

# --- intent: called locally, routed to the host --------------------------------

func send_input(move: Vector3, yaw: float) -> void:
	if is_host:
		if sim != null:
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

## The fight a peer is in, and which body in it is theirs: [Sim or null, entity id].
func _seat(peer: int) -> Array:
	var r: Dictionary = _rooms.get(_room_of.get(peer, "?"), {})
	return [r.get("sim"), r.get("peers", {}).get(peer, 0)]

func _do_arms(peer: int, what: String, a: Array) -> void:
	var seat := _seat(peer)
	var sim: Sim = seat[0]
	var ent: int = seat[1]
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
func _hello(their_profile: Dictionary, want: String, proof: String, their_version: String, room: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not is_host or _room_of.has(peer):
		return
	if their_version != version():
		_rejected.rpc_id(peer, "the host runs a different version of the game (%s, yours is %s): update both" % [version(), their_version])
		return
	if proof != _proof(word, _nonces.get(peer, "")) or not Profile.valid(their_profile):
		_rejected.rpc_id(peer, "the host turned you away (wrong word, or a character it cannot read)")
		return
	# Someone hosting from the camp has the one fight; a server keeps rooms.
	room = room.strip_edges().to_lower().left(24) if dedicated else ""
	if not _rooms.has(room):
		if not dedicated:
			return
		if _rooms.size() >= MAX_ROOMS:
			_rejected.rpc_id(peer, "the server is full of fights already")
			return
		var act: String = want if Rules.activities.has(want) and not want.begins_with("_") else "tarwins_gap_watch"
		_rooms[room] = {sim = Sim.new(act, randi()), activity = act, peers = {}, tick = 0}
		print("SERVER begins %s for %s%s" % [act, their_profile.name, " in room '%s'" % room if room != "" else ""])
	var r: Dictionary = _rooms[room]
	if r.peers.size() >= ROOM_SIZE:
		_rejected.rpc_id(peer, "that fight is full")
		return
	var spot := Vector3((r.peers.size() % 5 - 2) * 2.0, 0, 2.0)
	r.peers[peer] = r.sim.add_player(their_profile, spot)
	_room_of[peer] = room
	_welcome.rpc_id(peer, r.peers[peer], r.activity)
	# A latecomer missed the events that introduced everyone already on the field.
	_events.rpc_id(peer, r.sim.roster())

@rpc("any_peer", "reliable")
func _who(proof: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	var out := []
	if dedicated and proof == _proof(word, _nonces.get(peer, "")):
		for room in _rooms:
			var r: Dictionary = _rooms[room]
			var names := []
			for p in r.peers:
				names.append(r.sim.ents[r.peers[p]].profile.name)
			out.append({room = room, activity = r.activity, players = names, t = int(r.sim.t)})
	_who_reply.rpc_id(peer, out)

const VAULT := "user://vault"

@rpc("any_peer", "reliable")
func _vault(name_: String, sealed: String, proof: String, theirs: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not dedicated:
		return
	if proof != _proof(word, _nonces.get(peer, "")):
		_vault_reply.rpc_id(peer, "wrong word", {})
		return
	var file := "%s/%s.json" % [VAULT, name_.to_lower().validate_filename()]
	var kept := {}
	var lock := _seal(sealed, word, _nonces.get(peer, ""), true)
	if lock.length() != 64:
		_vault_reply.rpc_id(peer, "the server could not read that passphrase", {})
		return
	if FileAccess.file_exists(file):
		var row = JSON.parse_string(FileAccess.get_file_as_string(file))
		if row is Dictionary and row.get("lock", "") != lock:
			_vault_reply.rpc_id(peer, "that name is kept under another passphrase", {})
			return
		if row is Dictionary:
			kept = row.get("profile", {})
	var status := ""
	if name_.strip_edges() == "":
		status = "a name is needed"
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
	var seat := _seat(multiplayer.get_remote_sender_id())
	if seat[1] != 0 and seat[0] != null:
		(seat[0] as Sim).set_input(seat[1], move, yaw)

@rpc("any_peer", "reliable")
func _cast_req(weave: String, aim: Vector3) -> void:
	_do_cast(multiplayer.get_remote_sender_id(), weave, aim)

func _do_cast(peer: int, weave: String, aim: Vector3) -> void:
	var seat := _seat(peer)
	var sim: Sim = seat[0]
	var ent: int = seat[1]
	if ent == 0 or sim == null or not Rules.weaves.has(weave):
		return
	var why := sim.request_cast(ent, weave, aim)
	if why != "":
		if peer == 1: refused.emit(why)
		else: _refused.rpc_id(peer, why)

func _on_left(peer: int) -> void:
	_nonces.erase(peer)
	var room: String = _room_of.get(peer, "?")
	_room_of.erase(peer)
	if not _rooms.has(room):
		return
	var r: Dictionary = _rooms[room]
	if r.peers.has(peer):
		r.sim.ents[r.peers[peer]].alive = false
		r.peers.erase(peer)
	if dedicated and r.peers.is_empty():
		# Nobody is left in it: the next to ask for that room starts something fresh.
		print("SERVER empty, %s abandoned" % r.activity)
		_rooms.erase(room)

func _physics_process(dt: float) -> void:
	if not is_host:
		return
	for room in _rooms.keys():
		_step_room(room, _rooms[room], dt)

func _step_room(room: String, r: Dictionary, dt: float) -> void:
	var sim: Sim = r.sim
	if sim.over and r.tick < 0:
		return
	sim.step(dt)
	r.tick += 1
	# Each room's news goes only to those in it. The machine hosting hears its own
	# room directly (and a referee with no character still hears it, for tests).
	if not sim.events.is_empty():
		var ev := sim.events.duplicate()
		sim.events.clear()
		for peer in r.peers:
			if peer != 1:
				_events.rpc_id(peer, ev)
		if not dedicated:
			events.emit(ev)
	if r.tick % SNAP_EVERY == 0:
		var s := sim.snapshot()
		# Entities travel as one flat array of 32-bit floats: a fifth of the size of
		# nested Variants, which keeps a crowded field inside one packet.
		var flat := PackedFloat32Array()
		for e in s.ents:
			flat.append_array(PackedFloat32Array(e))
		for peer in r.peers:
			if peer != 1:
				_snap.rpc_id(peer, s.t, flat, s.fx)
		if not dedicated:
			snapshot.emit(s)
	if sim.over:
		r.tick = -1
		for peer in r.peers:
			var tl: Dictionary = sim.tallies[r.peers[peer]]
			if peer == 1: _apply_result(tl, sim.success)
			else: _result.rpc_id(peer, tl, sim.success)
		if dedicated:
			print("SERVER %s over, success=%s" % [r.activity, sim.success])
			for peer in r.peers:
				_room_of.erase(peer)
			_rooms.erase(room)

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
func _who_reply(fights: Array) -> void:
	multiplayer.multiplayer_peer = null
	lobby.emit(fights)

@rpc("authority", "reliable")
func _result(tally: Dictionary, success: bool) -> void:
	_apply_result(tally, success)

## The moment an activity pays into the persistent character.
func _apply_result(tally: Dictionary, success: bool) -> void:
	var report := Progression.award(profile, tally, activity, success)
	# The tour's characters are throwaway: nothing they do is kept.
	if not Launch.args.has("tour"):
		Profile.save(profile)
	finished.emit(success, report)
