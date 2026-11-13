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

const PORT := 24680
const SNAP_EVERY := 2          # physics ticks between snapshots (30 Hz sim -> 15 Hz)

var sim: Sim                   # host only
var profile: Dictionary        # this machine's character
var my_id := 0
var activity := ""
var is_host := false
var _peer_ent := {}            # peer id -> sim entity id (host)
var _tick := 0

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

func join(address: String, my_profile: Dictionary, port := PORT) -> Error:
	Rules.load_data()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	profile = my_profile
	multiplayer.connected_to_server.connect(func() -> void: _hello.rpc_id(1, profile))
	return OK

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

# --- host side ------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(their_profile: Dictionary) -> void:
	var peer := multiplayer.get_remote_sender_id()
	var spot := Vector3((_peer_ent.size() % 5 - 2) * 2.0, 0, 2.0)
	_peer_ent[peer] = sim.add_player(their_profile, spot)
	_welcome.rpc_id(peer, _peer_ent[peer], activity)

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
		sim.ents[_peer_ent[peer]].alive = false
		_peer_ent.erase(peer)

func _physics_process(dt: float) -> void:
	if not is_host or sim == null or sim.over and _tick < 0:
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
		_snap.rpc(s)
		snapshot.emit(s)
	if sim.over:
		_tick = -1
		for peer in _peer_ent:
			var tl: Dictionary = sim.tallies[_peer_ent[peer]]
			if peer == 1: _apply_result(tl, sim.success)
			else: _result.rpc_id(peer, tl, sim.success)

# --- client side ------------------------------------------------------------------

@rpc("authority", "reliable")
func _welcome(ent: int, activity_id: String) -> void:
	my_id = ent; activity = activity_id
	started.emit(my_id, activity)

@rpc("authority", "unreliable_ordered")
func _snap(s: Dictionary) -> void:
	snapshot.emit(s)

@rpc("authority", "reliable")
func _events(list: Array) -> void:
	events.emit(list)

@rpc("authority", "reliable")
func _refused(why: String) -> void:
	refused.emit(why)

@rpc("authority", "reliable")
func _result(tally: Dictionary, success: bool) -> void:
	_apply_result(tally, success)

## The moment an activity pays into the persistent character.
func _apply_result(tally: Dictionary, success: bool) -> void:
	var report := Progression.award(profile, tally, activity, success)
	Profile.save(profile)
	finished.emit(success, report)
