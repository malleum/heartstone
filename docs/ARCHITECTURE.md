# Heartstone architecture

Written so a fresh session can pick up cold. What the game is meant to be is in
`VISION.md`. Decisions here carry their reasons; if a reason stops being true, the
decision is open again.

## Layers (dependencies point downward only)
```
view    src/game/   nodes: camera, characters, weave effects, HUD
net     src/net/    Session: host-authoritative transport
rules   src/core/   Rules, Profile, Progression, Sim, Bot: no nodes at all
data    data/       weaves.json, enemies.json, activities.json
gen     src/gen/, src/anim/   generated creatures, sourced heroes, locomotion
```
- **Rules have no nodes and no rendering.** The host can referee headlessly, tests
  can play whole holdouts with a bot, and balance can be measured instead of
  guessed. The view only mirrors `Sim` state and events.
- **Data over code.** Adding a weave, enemy or activity is a JSON row. `kind` on a
  weave selects one of a small set of sim behaviours (projectile, burst, ring, line,
  beam, strike, cone, mover, barrier, heal, sever, utility). A new *kind* is code; a
  new weave of an existing kind is not.
- **All tuning numbers are in `Rules.TUNE`.**
- **Look at it, don't just test it.** Several bugs were invisible to every test and
  obvious in one screenshot.

## The character (src/core/profile.gd)
A plain Dictionary saved as JSON under `user://profiles/`.
- Fixed at creation (20 points shared): saidin/saidar, potential (strength ceiling),
  affinities in the five Powers, 0-2 Talents, origin and look. More potential means
  fewer Talents, as in `WEAVES.md`.
- Grows forever: strength (toward potential), affinity per Power (toward an aptitude
  ceiling), mastery per weave, flows held at once, weaves known, renown.

## The formula (src/core/rules.gd)
`power = strength x vigor x (0.5 + flow-weighted affinity) x (1 + 5% x mastery) x Talent`.
A weave's base numbers are written for power 25 (`TUNE.ref_power`) and scale linearly.
Casting needs: the weave learned, within the spoiler limit, any strength gate met, a
minimum affinity in every flow, and enough free flow slots. Nothing is ever refused
for lack of stamina.
- **Stamina** (`TUNE.stamina` 1500, +1.5 a second) lives on the sim's player entity
  and starts full in each activity. `Rules.vigor(stamina)` runs from 1.0 rested to
  `tired_floor` 0.25 at empty and multiplies both a weave's power and its cost, and
  the strength used for `level` gates. So a tired channeller weaves weak and cheap,
  and loses gateways. It replaced a 100-point pool that refilled in 15 seconds and
  was never shown on screen.
- **The weave tree** is two fields on a row: `needs` (weaves known first) and
  `study` (channelling to work it out, halved if the weave is in `profile.seen`).
  `profile.study` is the one weave being studied; `Progression.award` pays every
  activity's draw into it and picks the cheapest open weave if none is chosen.
  Activities `show` weaves (seen) and only the training yard `teaches` outright.
- **Cooldowns** (`cooldown` on a row) are kept per player in the sim; the view
  mirrors its own from the cast event for the HUD.
- **What a weave leaves behind** is data: `on_hit` (burn, stun, down), `self` (share
  of a blast its weaver takes), and `gravity`/`loft` for an arcing projectile.
- **Creation:** the first three points in the two Powers of your half of the Source
  cost half (`Profile.affinity_cost`); the starting weave is the simplest of your
  strongest Power (`Profile.STARTERS`, ties settled by a hash of the name).
- **Starting strength** is `start_gap` (10) levels below potential.
  `Profile._migrate` lifts older saves to that floor and follows renamed weaves.
- **Saidin leaps:** `profile.strength` accrues identically for everyone, but
  `Rules.strength(p)`, which every formula and screen uses, snaps a man to steps of
  `saidin_jump` (3) levels below his potential. Women use the raw value.
- **Strength is Robert Jordan's scale** (`WEAVES.md`): 72 up to 1, then ++6 to ++1
  for men only. It is stored as a magnitude so the formula stays a product, and
  `Rules.level_of` / `level_name` turn it into "19(7)" for every screen and gate.
  Level 1 is 100 and each level is a factor of `TUNE.level_ratio`; those ratios are
  ours, the Companion only ranks. Creation buys a potential level: 40(28) for no
  points, 1(+12) for 14, and saidin alone may spend 16 to reach ++1.
- **A Talent never unlocks a weave** (Josh, 2026-11-13). A weave's `talent` field
  names the Talent that multiplies its power by `TUNE.talent_power` and waives its
  `level` gate. Gateway and Deathgate carry `level: 19`.
- **Weaves can differ by sex:** `flows_saidin` on a row (Gateway, Healing).
- Linking should also clear a strength gate; there is no linking yet.
- **Flow slots** = total threads in the weave. Capacity starts at 2 and grows with
  lifetime channelling. It gates the big weaves (Blossoms of Fire needs 3) and lets
  you hold a shield while attacking.
- **Spoiler setting** is `book_limit` on the profile versus `book` on each weave.

## Progression (src/core/progression.gd)
One function, `Progression.award(profile, tally, activity, success)`, called when
any activity ends. Measured pacing with a bot (`tools/test.sh`): 3 flows at ~5 h,
4 at ~20 h, 5 at ~40 h; strength near potential by ~20 h.
- Known issue: renown is farmable by replaying a cleared activity (25% each time).
  Fine while renown only gates content; revisit before it buys anything.

## Networking (src/net/session.gd)
Host-authoritative. Clients send intent (movement, cast requests); the host steps
the one `Sim` and broadcasts snapshots (unreliable) and events (reliable).
Single-player is the same path with the host as sole player.
- Profiles live on their owner's machine. The host borrows them to run the rules and
  returns each player's tally; each client awards and saves locally.
- No anti-cheat by design: friends only.
- **A dedicated server** (`src/net/server.gd`, `docs/SERVER.md`) is the same Session
  with no player of its own. Friends on different networks all connect out to it,
  which is why no relay or NAT traversal was built: the server is the host. It
  starts a fight when the first player asks for one and resets when it ends or
  empties. One fight at a time.
- **The character store** is on the same server and the same port: the camp sends
  its copy, the server keeps whichever has channelled longer and answers with it.
  A name is guarded by a passphrase (stored hashed); the server as a whole by an
  optional word.
- Every machine keeps its Session at `/root/Session`, because RPCs go by node path.
- Players are introduced by a `player` event carrying name and look, enemies by
  `spawn`; a latecomer is sent `Sim.roster()`. A view never guesses from a snapshot.
- Snapshot entities cross the wire as one flat `PackedFloat32Array` (7 per entity),
  a fifth of the size of nested Variants.
- A host checks `Profile.valid` before running the rules on someone else's profile.
- `Session.version()` (a protocol number plus a hash of the data tables) is sent
  on joining; a host turns away a player whose game differs. Bump `PROTO` when
  an RPC or the snapshot format changes.
- Not done: prediction, a lobby, reconnect, rooms, encryption.

## Maps (src/core/map.gd, src/world/scenery.gd)
A map is pure maths in `Map`: a corridor along -Z whose half-width varies with z,
cliffs outside it, a spawn area at the far end and a defended line. The Sim clamps
everyone inside it, `Terrain.height` adds the cliffs, and feet plant on the same
function, so rules, mesh and gait cannot disagree. The sim stays on the ground plane for movement and crowding, but weaves fly in 3D:
they leave the hand toward the aim point, fall if they have `gravity`, and burst on
enemies, trees or the ground, which the sim reads from `Terrain.height` (pure
maths, no nodes). `Map.trees()` is the one list of trunks: the sim collides with
it and `Scenery` draws a tree at each. An activity names its map with
`"map"`; without one the ground is open. `Scenery` adds view-only dressing (the
breastwork, stakes, watch-fires, banners, boulders) and `Scenery.scatter` adds grass
tufts, loose stones and dead trees to any map. The ground shader is all world-space
noise: grass and dirt, a road (uniform `road`), bedded cliff rock projected from
three sides, snow above about 30 m. `World.build` takes the sun direction so each
place can be lit on purpose. Nothing in the pass blocks
movement yet except the cliffs: the wall has gaps and no collision on purpose,
because Trollocs still run straight at the nearest player with no pathfinding.

## Shadowspawn: generated (src/gen, src/anim)
Result of the first spike (seven review rounds, including a fresh-eyed reviewer).
- **How:** a creature is a table of ranges (`Species`) plus a seed. The body is
  signed-distance "clay": a smooth union of bone-tagged primitives, meshed with
  surface nets on a coarse grid for the body and fine grids for head and hands. Skin
  weights, colour and ambient occlusion come from the primitives. Armour is an offset
  shell of the body inside a mask; pauldrons and weapons are rigid props.
- **Gait (`Walker`):** feet plant and stay planted, stride is capped by leg reach
  (otherwise feet drag), two-bone IK, pelvis hung between the feet, layered spine and
  arm motion, a hit spring and a scripted death. `compute()` is thread-safe.
- **Verdict:** good enough for Shadowspawn at prototype quality (a reviewer gave
  Trollocs 5/10) and their mismatched variety is canon. Not good enough for human
  faces (3/10, 2/10 close up). Still missing: an attack animation.
- **Performance** (RX 7700 XT, shadows and SSAO on, 16 variants): 200 Trollocs at
  about 220 fps and 250 at about 180 fps at 1080p. Performance is not a constraint.
- Bench: `TEST=1 tools/render.sh <dir> [frames] -- --mode=lineup|walk|horde|humans|rig|heroes`.

## Player characters: sourced (src/gen/hero.gd)
Decided 2026-11-13 after the first hands-on play, where the generated human was the
worst thing on screen. `Hero` loads one of four Quaternius characters (male/female,
peasant/ranger) and drives it with the Universal Animation Library.
- `tools/blender/build_heroes.py` assembles each one headlessly in Blender: an outfit
  (which carries the 65-bone skeleton and the hands), the head, eyes and eyebrows
  cut from the matching base body, and hair. Textures are shrunk from 4K.
- Clips were authored on a mannequin with different limb lengths, so `Hero` keeps
  only bone rotations plus a rescaled hip height. Every clip then works on every
  body without retargeting.
- Hair ships as a grey map and is tinted per character.
- **Looks are data** (`Hero.LOOKS` plus seven generated Aes Sedai Ajahs): base model,
  pieces to hide, two cloth colours, and optional garments. `shaders/outfit.gdshader`
  recolours the pack's cloth by finding it in the atlas by colour, leaving leather and
  metal alone. Skirt, cloak, shawl and the men's long coat are generated in Blender by the same script as
  lofted sheets with hand-written skin weights (weights copied from the body make a
  skirt behave like trousers) and drawn by `shaders/garment.gdshader`, where UV.y runs
  from the top edge to the hem so bands, trim, fringe and fancloth are a line each.
  Trousers are hidden under a skirt. A new culture is a new row.
- The free packs hold two outfits and five hairstyles. More (nobles, armour, the
  full outfit set) are in the paid Source packs; Josh would buy those.
- `src/gen/human_rig.gd` (generated bodies on the older rig) is kept only for the
  test bench and crowds of background people. Do not use it for players.

## View (src/game)
`camp.tscn` is the main scene: the hub. It lists saved characters, runs character
creation, shows the activity board from `Rules.available`, and hands the choice to
`game.tscn` through the static `Launch.args`; the game returns to it with a report.
Command-line flags (`--auto`, `--activity=`, `--join=`) skip the camp, which is what
bots and renders use. The camp is a menu over a 3D backdrop for now; a walkable camp
can replace the backdrop without changing that flow.

`game.gd` is the activity view. It owns a `Session`, sends intent, and mirrors
snapshots and events: players are `Hero`es driven by clips, enemies are `Walker`s
that chase their sim position with their own gait.
- `Weavefx` draws every weave kind from primitives, particles and lights; `Sfx`
  synthesizes every sound from maths at startup (no audio files). `-- --auto
  --fxdemo` fires each effect in turn for review in a render.
- Trolloc attacks: the sim sends "swing" 0.4 s before the blow and `Walker.attack`
  plays an overhead chop on the weapon arm. Snapshots carry status bits (burning,
  down, stunned, thrown); the view adds flames or sparks, lays a Trolloc flat with
  the death fall played part-way (`Walker.downed`), and slides a thrown one
  without turning it.
- Casting clips: `Hero.cast_clip(name, weave)` picks one of five gestures; each has
  a `_Move` twin with the jog's legs grafted on, used while moving.
- Render flags: `--name=Bot` keeps renders off a real character; `--stand` makes
  the bot hold still and weave rarely so melee can be watched.
- Camera: an orbit camera over the right shoulder; pitch tilts the view itself.
- The character faces where it runs and turns to the target when it weaves, because
  the library has a forward jog but no strafes.
- Left click weaves the selected weave at the crosshair; the crosshair snaps to the
  enemy nearest the view ray, else the ground.
- `--auto` lets the bot play, which is how the game is rendered without a human
  (`tools/render.sh renders/game 240 -- --auto`).

## Dev environment
- NixOS flake: `nix develop` for the tools, `nix run` to play, `nix run .#horde` for
  the horde bench. Godot 4.7, Forward+.
- `tools/render.sh` renders on the real GPU through a headless sway compositor and
  writes PNG frames. `godot --headless` disables rendering and is for scripts only.
- **Standalone build:** `tools/export.sh` exports to `dist/` (committed). Josh tests on
  another NixOS machine, so run it and commit `dist/` before asking for a hands-on
  test, not on every commit. `dist/heartstone` is the launcher: the official export
  template is a generic Linux binary, so on NixOS it runs inside the flake's `fhs`
  environment (nix-ld alone lacks the display libraries).
- Blender is available. `blender -b --python script.py` for batch work;
  `tools/bl.py '<python>'` runs code in Josh's open Blender when the Blender Lab MCP
  add-on is enabled (port 9876).

## Third-party assets
CC0 or permissive only, unless Josh buys a pack. Every asset is listed here.

| Asset | Source | Licence | Used for |
|---|---|---|---|
| `assets/quaternius/chars/*.glb` | Quaternius: Modular Character Outfits - Fantasy (Standard) and Universal Base Characters (Standard), from quaternius.itch.io | CC0 1.0 | Player characters |
| `assets/quaternius/ual1.glb` | Quaternius: Universal Animation Library (Standard), from quaternius.itch.io | CC0 1.0 | 43 clips for player characters |
| `assets/quaternius/animation_library.glb` | Quaternius: Universal Animation Library, older rig, from opengameart.org | CC0 1.0 (`LICENSE.txt` beside it) | Skeleton and clips for generated humans |

## Next steps, in order
0. `BACKLOG.md` is the full list of what Josh has asked for; this is only an order.
1. Fight feel: clearer status effects and effects for the weaves beyond
   fireball. (Flows while forming and a view-only hit-stop are built: the struck
   body freezes, never the sim, so co-op is unaffected.)
2. Make three flows change the game: tying off or holding a weave while weaving
   another, so Dome of Air plus an attack is a real choice.
3. Co-op basics: a marker for who Healing will reach, a lobby screen. (The
   server, looks sent to other players and latecomer joins are built.)
4. Enemies that ask questions: Myrddraal, archers, Trollocs that path around the
   breastwork. Then a second holdout (Dumai's Wells).
5. One linear mission; then casting by drawing (see VISION.md).
6. From `WEAVES.md`, not built: Delving, Illusion and the weather weave; Skimming;
   techniques (tie off, invert, cut); linking; angreal. Gateway does nothing yet.
