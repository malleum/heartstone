extends SceneTree
## The dedicated server (for minimus): friends on different networks all join it,
## so nobody needs a VPN or a forwarded port, and it keeps their characters.
##   godot --headless --path . -s src/net/server.gd -- [--port=24690] [--word=secret]
## The word can also come from HEARTSTONE_WORD, so it need not appear in `ps`.
## It runs one fight at a time: the first player to arrive chooses the activity,
## everyone after joins it, and when it ends or empties the next arrival chooses again.

func _init() -> void:
	var args := Launch.cmdline()
	var s := Session.new()
	root.add_child.call_deferred(s)
	await process_frame
	var port := int(args.get("port", OS.get_environment("HEARTSTONE_PORT") if OS.has_environment("HEARTSTONE_PORT") else str(Session.PORT)))
	var err := s.serve(port, args.get("word", OS.get_environment("HEARTSTONE_WORD")))
	print("SERVER listening on udp %d err=%d word=%s" % [port, err, "set" if s.word != "" else "none"])
	if err != OK:
		quit(1)
	# HEARTSTONE_STATUS: a file the updater beside the server reads (flake.nix,
	# autoUpdate), saying whether anyone is in a fight, so it restarts the server
	# onto a new commit only when that interrupts nobody.
	var status := OS.get_environment("HEARTSTONE_STATUS")
	if status != "":
		while true:
			var f := FileAccess.open(status, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify({fights = s.busy_rooms(), camp = s._camp_peers.size(), t = int(Time.get_unix_time_from_system())}))
				f.close()
			await create_timer(2.0).timeout
