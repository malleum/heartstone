# The server (for minimus)

One small program does both things Josh asked for:

- **Friends on different networks play together with no VPN.** Everyone connects
  out to the server, so nobody forwards a port. The server runs the fight itself
  (it is the host; the game was already host-authoritative), which is simpler and
  fairer than relaying one player's machine.
- **Characters are kept on it,** so one character grows from any machine.

The config is in `malleum/nixos` (`modules/services/heartstone.nix`, tag `heartstone`
on minimus, UDP 24690, join word in `modules/secrets/heartstone.yaml`; read it with
`sops -d`). It evaluates but is **not yet live**: Josh still has to add the Oracle VCN
ingress rule for UDP 24690 and run the switch on minimus. To pick up a newer game on the
server: `nix flake update heartstone` there, then switch. The section below is what was
written into that repo.

## Deploying on minimus (in `malleum/nixos`)

```nix
# flake.nix
inputs.heartstone.url = "github:malleum/heartstone";

# in minimus's modules
imports = [ inputs.heartstone.nixosModules.default ];
services.heartstone = {
  enable = true;
  # port = 24690;            # UDP; opened in the firewall unless openFirewall = false
  environmentFile = "/run/secrets/heartstone";   # a file containing: HEARTSTONE_WORD=some-word
};
```

- **The word** is what friends type to be let in. Without `environmentFile` anyone
  who finds the port can play and store characters. Keep the file out of the Nix
  store (sops-nix, agenix, or a file placed by hand).
- If minimus sits behind a router, forward **UDP 24690** to it. That is the only
  port. Nothing goes through the web server or needs a certificate.
- The service runs as a throwaway user with a locked-down sandbox. Its only
  writable place is `/var/lib/heartstone`; characters are JSON files under
  `/var/lib/heartstone/data/godot/app_userdata/Heartstone/vault/`. Back that up.
- **The server and the players must run the same version of the game.** Update with
  `nix flake update heartstone` and a rebuild whenever `dist/` is rebuilt. A
  player whose game differs from the server's (network protocol or the weave,
  enemy and activity tables) is turned away with a message saying so.
- Logs: `journalctl -u heartstone`. Lines start with `SERVER`.

To try it without NixOS configuration: `nix run github:malleum/heartstone#server`
(state goes to `~/.local/state/heartstone`; set `HEARTSTONE_WORD` and
`HEARTSTONE_PORT` in the environment).

## Using it from the game

In the camp, under **Server**:

- **server address:** `joshammer.com` (or `host:port`).
- **the server's word:** the word above.
- **your passphrase:** yours alone, four letters or more. It guards your
  character's name on the server.
- **room:** a name your group agrees on. Everyone who types the same room plays
  together; a different room is a different fight at the same time. Blank is the
  common room.
- **Doorways lead to the server:** when ticked, walking through a doorway starts
  that activity on the server, in your room. The first to arrive chooses the
  activity; anyone who then walks through any doorway with the same room joins
  that fight, even part-way through. When it ends or everyone leaves, the next
  arrival chooses again.
- **Who is playing:** the camp asks the server every twelve seconds. The Server
  panel lists each fight (who, what, how long in), and standing at a doorway
  tells you if friends are already fighting in your room.
- **Save, and send this character:** from then on the camp exchanges the character
  with the server every time it is shown. The copy that has channelled longer
  wins, in both directions.
- **Fetch that character:** on a new machine, type the character's name and fetch
  it instead of making a new one.

## What it does not do
- Up to eight fights at once, six players in each.
- **Secrets.** This build of Godot has no encrypted transport, so the game sends
  nothing secret instead. The server greets each connection with a number used
  once; the word is proved by a hash of word and number, and your passphrase
  never leaves your machine (only a lock made from it, sealed under a key made
  from the word and the number). Someone listening on the network learns
  neither and cannot replay what they heard. Limits: with **no word set** the
  seal protects nothing, so set one; the characters themselves are sent in the
  clear. The server proves itself the same way, first (24 Nov): the game sends a
  number of its own, the server answers with a hash of the word and that number,
  and only if it is right does the game send its proof or anything else. An
  impostor at the address (no word) learns nothing to guess the word from and
  can neither take nor hand back a character.
- Characters are trusted as sent (no anti-cheat, by design: friends only). The
  server only checks that a character is shaped like one.
- Progress is saved when an activity ends; a character is sent to the server when
  you are next in the camp.
- (Seeing friends walk about the camp: done 18 Nov, see below.)

## Where it lives
- `src/net/server.gd`: the program (a Godot script with no window).
- `src/net/session.gd`: `serve`, `_rooms`, `_hello` (the word, the room, starting
  a fight, the roster for latecomers), `_who` (the lobby), `_vault` (the character
  store), `_greet` / `_proof` / `_seal` / `_challenge` / `_vouch` (secrets), `vault_sync` and `ask_lobby`
  (the client side).
- `flake.nix`: `packages.server`, `nixosModules.default`, `checks.module`.
- `tools/test.sh` runs a server on localhost with two players in two rooms at
  once, the lobby query, a stranger with the wrong word, and the character store.


## Releases and updates (17 Nov)
Pushing a tag `v*` runs `.github/workflows/release.yml`: it builds Linux and Windows
with Godot 4.7.2's official templates (any hardware: Vulkan, D3D12, then OpenGL), the
game data inside each executable (`embed_pck`), checks the Linux build starts without
script errors, and publishes `heartstone-linux-x86_64.zip`, `heartstone-windows.zip`,
the bare `heartstone.x86_64` and `heartstone.exe`, and `build.json` (tag, commit, commit
time).

Installed games update themselves (23 Nov, the way malleum/ultimategrapple does it).
From the camp, `Updater.check` reads the latest release and its `build.json`; if that
build is newer than the one baked into this executable, the executable for this
platform downloads next to ours (`<exe>.download`) and is swapped in: Linux renames it
over the running file (the process keeps its copy); Windows cannot overwrite a running
.exe but can rename it, so the old one becomes `<exe>.old` and is deleted at the next
start (`Updater.boot`). Idle in the camp, the game restarts into it at once; otherwise
the new one is there the next time it is opened. Nothing is done from source, under
Nix (read-only store), headless, or in `dist/` builds (no tag).
History: until 19 Nov it downloaded the data alone and restarted with `--main-pack`,
which official release builds refuse (every launch died); 19-23 Nov it only announced
new releases. Games from before v0.2.9 still need the new zip once, by hand.

Online, the server refuses a client whose handshake version differs (`Session.version`:
protocol number plus a hash of `data/*.json`); the client then says which side is
behind. The server follows `master` by itself (below, "Keeping itself up to date"); to
make it move at once: `ssh minimus sudo systemctl restart heartstone` (ends any fight).
Players need the matching build: tag a release and have them download it.

To release: `git tag -a v0.2.5 -m "..." && git push origin v0.2.5` (latest: v0.2.4).

## Who is in camp (18 Nov, PROTO 9)
A camp's lobby question now carries its character's name; the server remembers
names heard in the last 40 s and answers with the others in a `_camp` entry. The
camp lists them under Playing now and says when one arrives.

## Dropped connections (18 Nov)
- When a player's connection drops mid-fight, the server keeps their body for 90 s
  (`Session.AWAY_SECS`). It stands where it was, out of the fight: not stepped,
  not hunted, not hurt, and it still counts, so the fight does not end on its
  account. A room whose players have all dropped waits, unstepped.
- The game keeps knocking every 4 s with `want = "_rejoin"`. The server answers
  only by giving back the same body (by the character's name, after the word is
  proved) or with "that fight is over"; a rejoin never starts a new fight.
- Others in the fight are told "X lost the connection" and "X is back".
- Tested in `tools/test.sh` (the `dropper` client).

## Friends in the camp (18 Nov, PROTO 11)
- While the camp is open it keeps a connection of its own to the server (the camp
  link), in a branch of the scene with its own multiplayer, so a doorway's fight
  can be joined beside it. Its node is named `Session` so calls find the server's
  Session (paths are relative to each side's multiplayer root).
- The camp says where its character stands ten times a second (`_camp_at`,
  unreliable); the server sends every camp everyone else's spot as often
  (`_camp_walkers_to`), leaving out anyone who has gone into a fight (a held
  doorway preview does not count). What they look like (`kind`, `style`) goes once,
  reliably, whenever someone arrives or leaves (`_camp_looks_to`).
- Each friend's figure walks to their newest spot, about a tenth of a second
  behind. (The first version rode on the 1.5 s lobby question and ran seconds
  behind; the user rightly called that unacceptable.)
- The slow lobby question still runs, for who is fighting what and the server's
  build; it only places figures when the link is down.
- Not shown: names over their heads (nothing is written on the world) or what
  they hold.

## Keeping itself up to date (18 Nov)
`services.heartstone.autoUpdate.enable` (on by default) runs the server from a git
checkout of `master` in its state directory instead of the snapshot from the last
NixOS switch, and keeps it there:
- On start the checkout is brought to the newest commit (a shallow, sparse clone:
  the built games in `dist/` are never fetched), stamped into `build.json`,
  imported, and the game server started from it.
- A loop beside it asks the repository for the newest commit every 120 s
  (`autoUpdate.every`). When there is a new one it waits until nobody is in a fight
  (the server writes `status.json` every 2 s; a doorway looked into from a camp does
  not count), then stops the server. systemd (`Restart = always`) starts it again
  onto the new commit. Players in their camps reconnect by themselves.
- If the repository cannot be reached at start, the snapshot from the last switch
  runs, as before.
- Characters stay under the state directory's `data/`, untouched by updates.
- A switch is still needed when the updater script, Godot or the module itself
  changes, not for the game.
- A private repository needs a credential: `autoUpdate.tokenFile` names a file
  holding a GitHub token (on minimus, the sops secret `github_token` that gh and
  nix already use). systemd reads it as root and hands it to the sandboxed
  service (`LoadCredential`); git gets it from a credential helper that reads the
  file when asked, so it never shows in a command line, the environment or a log.
  (`autoUpdate.keyFile`, a read-only SSH deploy key, works too.) A public
  repository needs neither.
- A check that cannot reach the repository is logged and tried again next time;
  it never stops the server.
- Logs: `journalctl -u heartstone` shows `UPDATER running <commit>`, `<commit> is
  waiting: N fight(s) going` and `<commit> is out: restarting onto it`.

## Doorways and rooms on the server (19 Nov)
- Each camp doorway has its own room, named for its mode (`camp_training`,
  `holdout`, `darkfriend_door`, `endless_door`, `team_battle`, `dream_spar`): the
  practice yard never shares the wave fight's room.
- Walking up to a doorway joins its room with `hold`. If nobody is fighting there
  the room is held (drawn, not stepped). If a fight is already running, the
  looker's body is added but kept `away` (not stepped, not hunted, not drawn to
  others, not in the party bars) until they step through (`_go_from`).
- Only those who stepped through (or joined directly) are `entered`; only they keep
  their place for 90 s when the connection drops. A preview that closes leaves at
  once. (Before this, previews left "clones" standing in the fight.)
- Known open bug: each camp picks a random setup per walk-up, so a player can be
  shown a different map from the one the room runs (BACKLOG, first evening).
