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
  clear; and nothing proves the server is the real one.
- Characters are trusted as sent (no anti-cheat, by design: friends only). The
  server only checks that a character is shaped like one.
- Progress is saved when an activity ends; a character is sent to the server when
  you are next in the camp.
- You do not see friends walking about in the camp, only their names in a fight.

## Where it lives
- `src/net/server.gd`: the program (a Godot script with no window).
- `src/net/session.gd`: `serve`, `_rooms`, `_hello` (the word, the room, starting
  a fight, the roster for latecomers), `_who` (the lobby), `_vault` (the character
  store), `_greet` / `_proof` / `_seal` (secrets), `vault_sync` and `ask_lobby`
  (the client side).
- `flake.nix`: `packages.server`, `nixosModules.default`, `checks.module`.
- `tools/test.sh` runs a server on localhost with two players in two rooms at
  once, the lobby query, a stranger with the wrong word, and the character store.


## Releases and updates (17 Nov)
Pushing a tag `v*` runs `.github/workflows/release.yml`: it builds Linux and Windows
with Godot 4.7.2's official templates (any hardware: Vulkan, D3D12, then OpenGL) and
publishes a GitHub release with `heartstone-linux-x86_64.zip`, `heartstone-windows.zip`
and the game data alone, `heartstone-engine-4.7.2.pck`.

Installed games update themselves (`src/game/updater.gd`): from the camp they ask the
GitHub API for the latest release, download that pack to `user://update`, and restart
into it with `--main-pack` (straight away if nobody has stepped through a doorway yet,
else on the next start). A release on a different engine version cannot be swapped in:
the game says to download the new build. The API needs the repository to be public.

Online, the server refuses a client whose handshake version differs (`Session.version`:
protocol number plus a hash of `data/*.json`); the client then says to update. So when
a release changes the data files, update the server to the same commit: in the nixos
repo, `nix flake update heartstone`, commit, push, then on minimus `git pull && nh os switch`.

To release: `git tag v0.2.0 && git push origin v0.2.0`.

## Who is in camp (18 Nov, PROTO 9)
A camp's lobby question now carries its character's name; the server remembers
names heard in the last 40 s and answers with the others in a `_camp` entry. The
camp lists them under Playing now and says when one arrives.
