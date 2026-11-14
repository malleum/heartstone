# The server (for minimus)

One small program does both things Josh asked for:

- **Friends on different networks play together with no VPN.** Everyone connects
  out to the server, so nobody forwards a port. The server runs the fight itself
  (it is the host; the game was already host-authoritative), which is simpler and
  fairer than relaying one player's machine.
- **Characters are kept on it,** so one character grows from any machine.

Nothing has been deployed. Deploying changes minimus, so that step is Josh's.

## Deploying on minimus (in `malleum/nixos`)

```nix
# flake.nix
inputs.heartstone.url = "github:malleum/heartstone";

# in minimus's modules
imports = [ inputs.heartstone.nixosModules.default ];
services.heartstone = {
  enable = true;
  # port = 24680;            # UDP; opened in the firewall unless openFirewall = false
  environmentFile = "/run/secrets/heartstone";   # a file containing: HEARTSTONE_WORD=some-word
};
```

- **The word** is what friends type to be let in. Without `environmentFile` anyone
  who finds the port can play and store characters. Keep the file out of the Nix
  store (sops-nix, agenix, or a file placed by hand).
- If minimus sits behind a router, forward **UDP 24680** to it. That is the only
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
- **Play on the server:** when ticked, starting an activity starts it on the
  server. The first to arrive chooses the activity; everyone who starts anything
  after that joins the same fight, even part-way through. When it ends or everyone
  leaves, the next arrival chooses again.
- **Save, and send this character:** from then on the camp exchanges the character
  with the server every time it is shown. The copy that has channelled longer
  wins, in both directions.
- **Fetch that character:** on a new machine, type the character's name and fetch
  it instead of making a new one.

## What it does not do
- One fight at a time: there are no rooms. Fine for one group of friends.
- The connection is not encrypted, so the word and passphrase cross the internet
  in the clear. Do not reuse a real password.
- Characters are trusted as sent (no anti-cheat, by design: friends only). The
  server only checks that a character is shaped like one.
- Progress is saved when an activity ends; a character is sent to the server when
  you are next in the camp.

## Where it lives
- `src/net/server.gd`: the program (a Godot script with no window).
- `src/net/session.gd`: `serve`, `_hello` (the word, starting a fight, the roster
  for latecomers), `_vault` (the character store), `vault_sync` (the client side).
- `flake.nix`: `packages.server`, `nixosModules.default`, `checks.module`.
- `tools/test.sh` runs a server, a player, a stranger with the wrong word and the
  character store on localhost.
