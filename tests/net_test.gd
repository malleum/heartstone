extends SceneTree
## Co-op smoke test. One process hosts a holdout, others join as bot clients:
##   godot --headless -s tests/net_test.gd -- host <players>
##   godot --headless -s tests/net_test.gd -- client <name> [address] [word] [room] [activity]
##   godot --headless -s tests/net_test.gd -- lobby <address> <word>   (prints who is playing)
##   godot --headless -s tests/net_test.gd -- vault <address> <word>   (a dedicated server's store)
## Each prints one "NET ..." line that tools/test.sh checks.

var s: Session
var role := ""
var foes := {}
var last_snap := {}
var snaps := 0
var cast_t := 0.0

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	role = a[0]
	s = Session.new()
	root.add_child.call_deferred(s)
	await process_frame
	if role == "host":
		# A dedicated host with no character of its own: it only referees.
		var err := s.host("short_watch", {})
		print("NET host listening err=%d" % err)
		s.events.connect(func(list: Array) -> void:
			for e in list:
				if e.e == "over":
					print("NET host over success=%s players=%d t=%.0f" % [e.success, s.sim.tallies.size(), s.sim.t])
					create_timer(1.0).timeout.connect(quit))
		# Do not start the clock until everyone is in.
		s.set_physics_process(false)
		var want := int(a[1])
		while s._peer_ent.size() < want:
			await process_frame
		s.set_physics_process(true)
	elif role == "vault":
		_vault(a[1], a[2])
	elif role == "lobby":
		s.lobby.connect(func(fights: Array) -> void:
			print("NET lobby %d fights: %s" % [fights.size(), JSON.stringify(fights)]); quit())
		s.ask_lobby(a[1], a[2])
	else:
		Profile.dir = "user://test_profiles"
		var p := Profile.create({name = "Net " + a[1], potential_pts = 8, affinity_pts = {fire = 6}})
		var before: float = p.channelled
		s.rejected.connect(func(why: String) -> void:
			print("NET client %s rejected: %s" % [a[1], why]); quit())
		# With an address it is a dedicated server, and perhaps a room on it.
		s.join(a[2] if a.size() > 2 else "127.0.0.1", p, a[5] if a.size() > 5 else "short_watch", a[3] if a.size() > 3 else "", a[4] if a.size() > 4 else "")
		s.events.connect(func(list: Array) -> void:
			for e in list:
				if e.e == "spawn": foes[e.id] = true
				elif e.e == "die": foes.erase(e.id))
		s.snapshot.connect(func(snap: Dictionary) -> void:
			last_snap = snap; snaps += 1)
		s.finished.connect(func(ok: bool, report: Array) -> void:
			var saved := Profile.load_profile(p.name)
			print("NET client %s done success=%s snaps=%d channelled %.0f->%.0f saved_renown=%.0f report=%d" % [a[1], ok, snaps, before, p.channelled, saved.renown, report.size()])
			quit())
		process_frame.connect(_client_bot)
	create_timer(170.0).timeout.connect(func() -> void:
		print("NET %s TIMEOUT" % role); quit(1))

## Clients know only what snapshots tell them, like a real player.
func _client_bot() -> void:
	if s.my_id == 0 or last_snap.is_empty():
		return
	var me := Vector3.ZERO
	for e in last_snap.ents:
		if e[0] == s.my_id: me = Vector3(e[1], 0, e[2])
	var best := 1e9; var target := Vector3.ZERO
	for e in last_snap.ents:
		if foes.has(e[0]):
			var d := me.distance_to(Vector3(e[1], 0, e[2]))
			if d < best:
				best = d; target = Vector3(e[1], 0, e[2])
	if best > 1e8:
		return
	var to := (target - me).normalized()
	# Practice posts do not come to you: walk into range (and round whatever rise
	# was in the way) instead of throwing short for three minutes.
	s.send_input(-to if best < 7.0 else (to if best > 13.0 else Vector3.ZERO), atan2(to.x, to.z))
	cast_t -= 1.0 / 60.0
	if cast_t <= 0.0:
		cast_t = 0.3
		# Aim at the chest and allow for the fireball's fall, as a player learns to.
		s.cast("fireball", target + Vector3(0, Terrain.height(target.x, target.z) + 1.1 + 0.00446 * best * best - 0.052 * best, 0))

## The character store: a copy goes up, comes back to a machine that has none, is
## refused to the wrong passphrase, and is not replaced by an older copy.
func _vault(address: String, word: String) -> void:
	var p := Profile.create({name = "Vault %d" % (randi() % 100000), potential_pts = 8, affinity_pts = {fire = 6}})
	p.seconds = 500.0
	var ok := true
	var steps := [[p, "pass1", "", 500.0], [{}, "pass1", "", 500.0], [{}, "wrong", "that name", -1.0], [p.merged({seconds = 100.0}, true), "pass1", "", 500.0], [p.merged({seconds = 900.0}, true), "pass1", "", 900.0]]
	for st in steps:
		s.vault_sync(address, p.name, st[1], st[0], word)
		var r: Array = await s.vaulted
		var good: bool = (r[0].begins_with(st[2]) if st[2] != "" else r[0] == "") and (st[3] < 0.0 or (not r[1].is_empty() and is_equal_approx(r[1].seconds, st[3])))
		ok = ok and good
		if not good:
			print("NET vault step failed: ", r[0], " ", r[1].get("seconds", "-"))
	s.vault_sync(address, p.name, "pass1", {}, "notit")
	var r2: Array = await s.vaulted
	ok = ok and r2[0] == "wrong word"
	print("NET vault ok=%s" % ok)
	quit()
