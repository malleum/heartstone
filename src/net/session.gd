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
signal lost                                    # the server went away mid-fight
signal camp_walkers(list: Array)               # camp link: [[name, x, z, yaw], ...] ten times a second
signal camp_looks(looks: Dictionary)           # camp link: name -> {kind, style}, when someone arrives

const PORT := 24690
const PROTO := 11              # bump when an RPC or the snapshot format changes
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

## hold: build the fight but keep it still until begin() (a camp doorway's far side,
## looked at before anyone has stepped through).
## listen: false for a game on this machine alone (every shared game is on the
## server now): no port is opened, so two copies of the game never collide.
func host(activity_id: String, my_profile: Dictionary, port := PORT, hold := false, listen := true) -> Error:
	Rules.load_data()
	if listen:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(port, 5)
		if err != OK:
			return err
		multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	multiplayer.peer_disconnected.connect(_on_left)
	multiplayer.peer_connected.connect(_greet)
	is_host = true; profile = my_profile; activity = activity_id
	_rooms[""] = {sim = Sim.new(activity_id, randi()), activity = activity_id, peers = {}, tick = 0, hold = hold}
	if not my_profile.is_empty():
		my_id = _rooms[""].sim.add_player(my_profile)
		_rooms[""].peers[1] = my_id
		_room_of[1] = ""
		started.emit(my_id, activity)
	return OK

## want: the activity to start if the host is a server with nothing running.
## room: on a server, the name of the group to play with ("" is the common room).
func join(address: String, my_profile: Dictionary, want := "", their_word := "", room := "", hold := false) -> Error:
	Rules.load_data()
	profile = my_profile
	return _connect(address, func() -> void: _hello.rpc_id(1, profile, want, _proof(their_word, _nonce), version(), room, hold), func() -> void:
		if rejoin_failed.is_valid(): rejoin_failed.call()
		else: rejected.emit("could not reach " + address))

## Set while knocking to be let back in (game.gd _on_lost): a knock nobody answers
## goes back there to try again, instead of turning into "could not reach".
var rejoin_failed: Callable

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
	if not multiplayer.server_disconnected.is_connected(_on_server_gone):
		multiplayer.server_disconnected.connect(_on_server_gone)
	return OK

func _on_server_gone() -> void:
	lost.emit()

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
## `where`: this camp's {x, z, yaw, kind, style}, for others to see us walk about.
func ask_lobby(address: String, their_word := "", me := "", where := {}) -> void:
	_connect(address, func() -> void: _who.rpc_id(1, _proof(their_word, _nonce), me.left(32), where), func() -> void: lobby.emit([]))

## The same question over a connection already open to a server (a camp doorway's
## fight joined there): false if this session is not joined to one.
func ask_here(their_word := "", me := "", where := {}) -> bool:
	var peer := multiplayer.multiplayer_peer
	if is_host or peer == null or peer is OfflineMultiplayerPeer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or _nonce == "":
		return false
	_who.rpc_id(1, _proof(their_word, _nonce), me.left(32), where)
	return true

# --- intent: called locally, routed to the host --------------------------------

func send_input(move: Vector3, yaw: float) -> void:
	if is_host:
		if sim != null:
			sim.set_input(my_id, move, yaw)
	else:
		_move.rpc_id(1, move, yaw)

## hold: keep the finished weave in the hands until aim() lets it go.
func cast(weave: String, at: Vector3, hold := false) -> void:
	if is_host:
		_do_cast(1, weave, at, hold)
	else:
		_cast_req.rpc_id(1, weave, at, hold)

## Where the weave in the making should go, and whether to keep holding it back.
func aim(at: Vector3, hold: bool) -> void:
	if is_host: _do_arms(1, "aim", [at, hold])
	else: _arms.rpc_id(1, "aim", [at, hold])

## Arms. kind: light | heavy | low | throw; charge is how far a bow was drawn.
func attack(kind: String, aim: Vector3, charge := 1.0) -> void:
	if is_host: _do_arms(1, "attack", [kind, aim, charge])
	else: _arms.rpc_id(1, "attack", [kind, aim, charge])

func guard(on: bool) -> void:
	if is_host: _do_arms(1, "guard", [on])
	else: _arms.rpc_id(1, "guard", [on])

func draw(on: bool) -> void:
	if is_host: _do_arms(1, "draw", [on])
	else: _arms.rpc_id(1, "draw", [on])

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

## A dream move, aimed where the player is looking (Tel'aran'rhiod only).
func dream(move: String, aim: Vector3) -> void:
	if is_host: _do_arms(1, "dream", [move, aim])
	else: _arms.rpc_id(1, "dream", [move, aim])

## Link (offer, lead, or let go: Sim.request_link).
func link() -> void:
	if is_host: _do_arms(1, "link", [])
	else: _arms.rpc_id(1, "link", [])

## Jump (Sim.request_jump): a low sweep passes under.
func jump() -> void:
	if is_host: _do_arms(1, "jump", [])
	else: _arms.rpc_id(1, "jump", [])

## Drop the weave being made, unloosed (Sim.cancel_weave).
func cancel_weave() -> void:
	if is_host: _do_arms(1, "cancel", [])
	else: _arms.rpc_id(1, "cancel", [])

## Tie or untie someone with rope (held down; Sim.set_tying).
func tie_rope(on: bool) -> void:
	if is_host: _do_arms(1, "rope", [on])
	else: _arms.rpc_id(1, "rope", [on])

## A Darkfriend's secret gateway (Sim.request_df_gate).
func df_gate() -> void:
	if is_host: _do_arms(1, "df_gate", [])
	else: _arms.rpc_id(1, "df_gate", [])

## Stepped through the doorway: let a held fight begin.
func begin() -> void:
	if is_host: _go_from(1)
	else: _go.rpc_id(1)

@rpc("any_peer", "reliable")
func _go() -> void:
	_go_from(multiplayer.get_remote_sender_id())

func _go_from(peer: int) -> void:
	var r: Dictionary = _rooms.get(_room_of.get(peer, ""), {})
	if not r.is_empty():
		r.hold = false

## Spend a level-up on the tree: kind is weave, skill, form or weapon.
func pick(kind: String, choice: String) -> void:
	if is_host: _do_arms(1, "pick", [kind, choice])
	else: _arms.rpc_id(1, "pick", [kind, choice])

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
		"draw":
			if a.size() == 1 and a[0] is bool: sim.set_draw(ent, a[0])
		"aim":
			if a.size() == 2 and a[0] is Vector3 and a[1] is bool: sim.aim_cast(ent, a[0], a[1])
		"duck":
			if a.size() == 1 and a[0] is bool: sim.set_duck(ent, a[0])
		"dodge":
			if a.size() == 2 and a[0] is Vector3 and a[1] is bool: why = sim.request_dodge(ent, a[0], a[1])
		"equip":
			if a.size() == 1 and a[0] is String: why = sim.equip(ent, a[0])
		"dream":
			if a.size() == 2 and a[0] is String and a[1] is Vector3: why = sim.request_dream(ent, a[0], a[1])
		"tie":
			if a.size() == 1 and a[0] is String and Rules.weaves.has(a[0]): why = sim.tie(ent, a[0])
		"link":
			why = sim.request_link(ent)
		"cancel":
			why = sim.cancel_weave(ent)
		"rope":
			if a.size() == 1 and a[0] is bool: why = sim.set_tying(ent, a[0])
		"jump":
			why = sim.request_jump(ent)
		"df_gate":
			why = sim.request_df_gate(ent)
		"pick":
			if a.size() == 2 and a[0] is String and a[1] is String: why = sim.request_pick(ent, a[0], a[1])
	if why != "" and why != "busy":
		if peer == 1: refused.emit(why)
		else: _refused.rpc_id(peer, why)

@rpc("any_peer", "reliable")
func _hello(their_profile: Dictionary, want: String, proof: String, their_version: String, room: String, hold := false) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not is_host or _room_of.has(peer):
		return
	if their_version != version():
		# The stamp at the end lets a newer client say which side is behind.
		_rejected.rpc_id(peer, "the host runs a different version of the game (%s, yours is %s): update both [build %s]" % [version(), their_version, JSON.stringify(Updater.stamp())])
		return
	if proof != _proof(word, _nonces.get(peer, "")) or not Profile.valid(their_profile):
		_rejected.rpc_id(peer, "the host turned you away (wrong word, or a character it cannot read)")
		return
	# Back after a dropped connection (want "_rejoin"): the same body, where it was
	# left, or word that the fight is gone; never a fresh fight in its place.
	if want == "_rejoin":
		var key := String(their_profile.name).to_lower()
		var back: Dictionary = _away.get(key, {})
		if back.is_empty() or not _rooms.has(back.room) or not _rooms[back.room].sim.ents.has(back.ent):
			_rejected.rpc_id(peer, "that fight is over")
			return
		_away.erase(key)
		var rb: Dictionary = _rooms[back.room]
		rb.sim.ents[back.ent].away = false
		rb.peers[peer] = back.ent
		_room_of[peer] = back.room
		print("SERVER takes %s back into %s" % [their_profile.name, rb.activity])
		rb.sim.events.append({e = "back", id = back.ent, name = their_profile.name})
		_welcome.rpc_id(peer, back.ent, rb.activity)
		_events.rpc_id(peer, rb.sim.roster())
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
		# A fight started from a camp doorway waits until someone steps through it.
		_rooms[room] = {sim = Sim.new(act, randi()), activity = act, peers = {}, tick = 0, hold = hold}
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

var _in_camp := {}     # name -> {t: when last heard asking from a camp, at: where they stand} (dedicated server)

## Where someone stands in their camp, as a camp sends it: position, facing and
## what they look like, so the others can show them walking about. Checked for
## shape (it comes from another machine), and small or nothing.
static func _camp_spot(where: Dictionary) -> Dictionary:
	if not (where.get("x") is float and where.get("z") is float and where.get("yaw") is float):
		return {}
	var style = where.get("style", {})
	if not style is Dictionary or JSON.stringify(style).length() > 2000:
		style = {}
	return {x = clampf(where.x, -60.0, 60.0), z = clampf(where.z, -60.0, 60.0), yaw = where.yaw,
		kind = String(where.get("kind", "")).left(24), style = style}

@rpc("any_peer", "reliable")
func _who(proof: String, me := "", where := {}) -> void:
	var peer := multiplayer.get_remote_sender_id()
	var out := []
	if dedicated and proof == _proof(word, _nonces.get(peer, "")):
		# Whoever asks from a camp is in their camp: others are told who is about,
		# and where they stand.
		var now := Time.get_ticks_msec() / 1000.0
		var mine := me.strip_edges()
		if mine != "":
			_in_camp[mine] = {t = now, at = _camp_spot(where)}
		var about := []
		var walkers := []
		# Not drawn in the camp: anyone in a fight just now, or not heard from lately.
		var fighting := []
		for room in _rooms:
			# (A held room is a doorway's fight looked into from a camp, not entered.)
			if _rooms[room].get("hold", false):
				continue
			for p in _rooms[room].peers:
				fighting.append(_rooms[room].sim.ents[_rooms[room].peers[p]].profile.name)
		for n in _in_camp.keys():
			if now - float(_in_camp[n].t) > 40.0:
				_in_camp.erase(n)
			elif n != mine:
				about.append(n)
				if not _in_camp[n].at.is_empty() and not n in fighting and now - float(_in_camp[n].t) < 15.0:
					var w: Dictionary = _in_camp[n].at.duplicate()
					w.name = n
					walkers.append(w)
		out.append({room = "_camp", players = about, walkers = walkers})
		for room in _rooms:
			var r: Dictionary = _rooms[room]
			var names := []
			for p in r.peers:
				names.append(r.sim.ents[r.peers[p]].profile.name)
			out.append({room = room, activity = r.activity, players = names, t = int(r.sim.t)})
	# Who this server is, for anyone asking (even without the word): its build stamp
	# and its handshake version, so a camp can show whether the two match.
	out.append({room = "_server", stamp = Updater.stamp(), version = version()})
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
func _cast_req(weave: String, at: Vector3, hold: bool) -> void:
	_do_cast(multiplayer.get_remote_sender_id(), weave, at, hold)

func _do_cast(peer: int, weave: String, at: Vector3, hold := false) -> void:
	var seat := _seat(peer)
	var sim: Sim = seat[0]
	var ent: int = seat[1]
	if ent == 0 or sim == null or not Rules.weaves.has(weave):
		return
	var why := sim.request_cast(ent, weave, at, hold)
	if why != "":
		if peer == 1: refused.emit(why)
		else: _refused.rpc_id(peer, why)

## Bodies kept for those whose connection dropped mid-fight: name (lower case) ->
## {room, ent, until}. A room with nobody in it but such bodies waits, unstepped.
const AWAY_SECS := 90.0
var _away := {}

func _awaited(room: String) -> bool:
	for n in _away:
		if _away[n].room == room:
			return true
	return false

## Places kept too long are given up: the body leaves the fight, and a room with
## nobody left in it goes.
func _expire_away() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for n in _away.keys():
		var a: Dictionary = _away[n]
		if now < float(a.until):
			continue
		_away.erase(n)
		if not _rooms.has(a.room):
			continue
		var r: Dictionary = _rooms[a.room]
		if r.sim.ents.has(a.ent):
			r.sim.ents[a.ent].away = false
			r.sim.ents[a.ent].alive = false
		if dedicated and r.peers.is_empty() and not _awaited(a.room):
			print("SERVER empty, %s abandoned" % r.activity)
			_rooms.erase(a.room)

func _on_left(peer: int) -> void:
	_nonces.erase(peer)
	if _camp_peers.has(peer):
		_camp_peers.erase(peer)
		_send_looks()
	var room: String = _room_of.get(peer, "?")
	_room_of.erase(peer)
	if not _rooms.has(room):
		return
	var r: Dictionary = _rooms[room]
	if r.peers.has(peer):
		var ent: Dictionary = r.sim.ents[r.peers[peer]]
		if not r.sim.over and ent.alive:
			# A dropped connection is not leaving: the body stands, out of reach,
			# for AWAY_SECS, and the same name coming back takes it up again.
			ent.away = true; ent.move = Vector3.ZERO
			_away[String(ent.profile.name).to_lower()] = {room = room, ent = ent.id, until = Time.get_ticks_msec() / 1000.0 + AWAY_SECS}
			print("SERVER keeps %s's place for %d s" % [ent.profile.name, int(AWAY_SECS)])
			r.sim.events.append({e = "away", id = ent.id, name = ent.profile.name, secs = AWAY_SECS})
		else:
			ent.alive = false
		r.peers.erase(peer)
	if dedicated and r.peers.is_empty() and not _awaited(room):
		# Nobody is left in it: the next to ask for that room starts something fresh.
		print("SERVER empty, %s abandoned" % r.activity)
		_rooms.erase(room)

func _physics_process(dt: float) -> void:
	if not is_host:
		return
	if not _away.is_empty():
		_expire_away()
	if dedicated and not _camp_peers.is_empty():
		_camp_t -= dt
		if _camp_t <= 0.0:
			_camp_t = CAMP_EVERY
			_send_walkers()
	for room in _rooms.keys():
		# Everyone in it dropped and may come back: it waits for them.
		if _rooms[room].peers.is_empty() and _awaited(room):
			continue
		_step_room(room, _rooms[room], dt)

func _step_room(room: String, r: Dictionary, dt: float) -> void:
	var sim: Sim = r.sim
	if sim.over and r.tick < 0:
		# Done and paid: keep the world moving (and drawn) for whoever is still in it.
		sim.step(dt)
		r.tick -= 1
		# Its news still goes out: without it, what anyone wove after the end was
		# never drawn (and the controls test lost its tie whenever fire finished the
		# last practice post early).
		_send_events(r, sim)
		if r.tick % SNAP_EVERY == 0 and not dedicated:
			snapshot.emit(sim.snapshot())
		return
	# Held: drawn (snapshots go out) but not run, until someone steps through.
	if not r.get("hold", false):
		sim.step(dt)
	r.tick += 1
	_send_events(r, sim)
	if r.tick % SNAP_EVERY == 0:
		var s := sim.snapshot()
		# Entities travel as one flat array of 32-bit floats: a fifth of the size of
		# nested Variants, which keeps a crowded field inside one packet.
		var flat := PackedFloat32Array()
		for e in s.ents:
			flat.append_array(PackedFloat32Array(e))
		for peer in r.peers:
			if peer != 1:
				_snap.rpc_id(peer, s.t, flat, s.fx, s.round)
		if not dedicated:
			snapshot.emit(s)
	if sim.over:
		r.tick = -1
		for peer in r.peers:
			var tl: Dictionary = sim.tallies[r.peers[peer]]
			# In a Darkfriend round the two sides win and lose apart.
			var won := sim.won(r.peers[peer])
			if peer == 1: _apply_result(tl, won)
			else: _result.rpc_id(peer, tl, won)
		if dedicated:
			print("SERVER %s over, success=%s" % [r.activity, sim.success])
			for peer in r.peers:
				_room_of.erase(peer)
			_rooms.erase(room)


## Each room's news goes only to those in it. The machine hosting hears its own
## room directly (and a referee with no character still hears it, for tests).
func _send_events(r: Dictionary, sim: Sim) -> void:
	if not sim.events.is_empty():
		var ev := sim.events.duplicate()
		sim.events.clear()
		# Some news is for one player only (`to`: a Darkfriend's role); it goes to
		# that player's machine and no other.
		for peer in r.peers:
			var mine := ev.filter(func(e: Dictionary) -> bool: return not e.has("to") or e.to == r.peers[peer])
			if peer != 1:
				if not mine.is_empty():
					_events.rpc_id(peer, mine)
			elif not dedicated:
				events.emit(mine)
		if not dedicated and not r.peers.has(1):
			events.emit(ev.filter(func(e: Dictionary) -> bool: return not e.has("to")))

# --- the camp link ---------------------------------------------------------------
# A camp keeps a connection of its own to the server while it is open (camp.gd,
# beside any doorway's fight), and says where its character stands ten times a
# second; the server tells every camp where all the others are, as often. What
# they look like goes once, when someone arrives.

const CAMP_EVERY := 0.1
var _camp_peers := {}   # server: peer -> {name, at: {x, z, yaw}, look: {kind, style}}
var _camp_t := 0.0

## Open the link (client): `where` as Session._camp_spot reads it.
func camp_join(address: String, their_word: String, me: String, where: Dictionary) -> Error:
	return _connect(address, func() -> void: _camp_hello.rpc_id(1, _proof(their_word, _nonce), me.left(32), where), func() -> void: rejected.emit("could not reach " + address))

## Where this camp's character is now (client, ten times a second).
func camp_at(x: float, z: float, yaw: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_camp_at.rpc_id(1, x, z, yaw)

@rpc("any_peer", "reliable")
func _camp_hello(proof: String, me: String, where: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not dedicated or proof != _proof(word, _nonces.get(peer, "")) or me.strip_edges() == "":
		return
	var spot := _camp_spot(where)
	_camp_peers[peer] = {name = me.strip_edges(), at = spot, look = {kind = spot.get("kind", ""), style = spot.get("style", {})}}
	_in_camp[me.strip_edges()] = {t = Time.get_ticks_msec() / 1000.0, at = spot}
	_send_looks()

@rpc("any_peer", "unreliable_ordered")
func _camp_at(x: float, z: float, yaw: float) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not _camp_peers.has(peer):
		return
	var c: Dictionary = _camp_peers[peer]
	c.at = {x = clampf(x, -60.0, 60.0), z = clampf(z, -60.0, 60.0), yaw = yaw}
	_in_camp[c.name] = {t = Time.get_ticks_msec() / 1000.0, at = c.at}

## Everyone's spot to every camp, leaving out each camp's own and anyone who has
## gone through a doorway into a fight (a held preview does not count).
func _send_walkers() -> void:
	var fighting := {}
	for room in _rooms:
		if _rooms[room].get("hold", false):
			continue
		for p in _rooms[room].peers:
			fighting[_rooms[room].sim.ents[_rooms[room].peers[p]].profile.name] = true
	var all := []
	for peer in _camp_peers:
		var c: Dictionary = _camp_peers[peer]
		if not fighting.has(c.name) and c.at.has("x"):
			all.append([c.name, snappedf(c.at.x, 0.01), snappedf(c.at.z, 0.01), snappedf(c.at.yaw, 0.01)])
	for peer in _camp_peers:
		var mine: String = _camp_peers[peer].name
		_camp_walkers_to.rpc_id(peer, all.filter(func(w: Array) -> bool: return w[0] != mine))

func _send_looks() -> void:
	var looks := {}
	for peer in _camp_peers:
		looks[_camp_peers[peer].name] = _camp_peers[peer].look
	for peer in _camp_peers:
		_camp_looks_to.rpc_id(peer, looks)

@rpc("authority", "unreliable_ordered")
func _camp_walkers_to(list: Array) -> void:
	camp_walkers.emit(list)

@rpc("authority", "reliable")
func _camp_looks_to(looks: Dictionary) -> void:
	camp_looks.emit(looks)

# --- client side ------------------------------------------------------------------

@rpc("authority", "reliable")
func _welcome(ent: int, activity_id: String) -> void:
	my_id = ent; activity = activity_id
	started.emit(my_id, activity)

@rpc("authority", "unreliable_ordered")
func _snap(t: float, flat: PackedFloat32Array, fx: Array, meter: Array = []) -> void:
	var es := []
	for i in range(0, flat.size(), 8):
		es.append([int(flat[i]), flat[i + 1], flat[i + 2], flat[i + 3], flat[i + 4], flat[i + 5], int(flat[i + 6]), flat[i + 7]])
	snapshot.emit({t = t, ents = es, fx = fx, round = meter})

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
	# (Whoever asked hangs up and frees this Session; clearing the peer here as
	# well cleared it twice, which Godot complains of.)
	vaulted.emit(status, kept)

@rpc("authority", "reliable")
func _who_reply(fights: Array) -> void:
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
