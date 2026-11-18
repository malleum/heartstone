extends SceneTree
## Is the server there? Connects, waits for its greeting, asks who is playing, and
## says what came back. Needs no word: a wrong word still gets an (empty) answer.
##   godot --headless --path . -s tests/probe_server.gd -- [host:port] [word]
var s: Session
var t0 := 0
func _init() -> void:
	Rules.load_data()
	var a := OS.get_cmdline_user_args()
	var addr: String = a[0] if a.size() > 0 else Launch.SERVER
	var w: String = a[1] if a.size() > 1 else ""
	s = Session.new()
	root.add_child(s)
	s.lobby.connect(func(fights: Array) -> void:
		print("PROBE answered in %d ms: %s" % [Time.get_ticks_msec() - t0, fights])
		quit())
	t0 = Time.get_ticks_msec()
	print("PROBE asking %s (our version %s)" % [addr, Session.version()])
	(func() -> void: s.ask_lobby(addr, w)).call_deferred()
	create_timer(10.0).timeout.connect(func() -> void:
		print("PROBE no answer after 10 s (connection status %s)" % [s.multiplayer.multiplayer_peer.get_connection_status() if s.multiplayer.multiplayer_peer else -1])
		quit())
