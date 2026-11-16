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
- **No cooldowns: weaving takes time instead** (Josh, 14 Nov: "a pre-cooldown, not a
  cooldown proper"; it is also where casting by drawing will slot in). `form` on a row
  is the seconds it takes. `request_cast(..., hold)` begins it; with `hold` the whole
  weave waits in the hands (event `ready`) until `aim_cast(id, aim, false)`, and the aim
  used is the one given last, so a weave goes where the player is looking when it
  leaves. Held weaves that fasten on someone pick their target at that moment
  (`fizzle` if nobody is there). The view sends the aim a few times a second.
- **Parry is a press** (`Sim.set_guard` keeps its old name): it opens a window
  (`parry_window`), perfect within `parry_perfect`. There is no held guard.
- **Keys are by position** (`Keys`, `physical_keycode`), never by letter: see
  `src/game/keys.gd`. Use `Keys.name(KEY_X)` in any hint.
- **Arm poses the animation pack lacks** (drawing a bow, levelling a crossbow) are a
  `SkeletonModifier3D` (`src/gen/armpose.gd`) that turns the arm bones after the clip
  has played; the bow hand is turned outright so the bow stands upright whatever
  twist the clip left in the arm.
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

## Held weaves (src/core/sim.gd)
`p.held` is a list of `{weave, target, tied, breaks}`. `free_slots` counts the
flows of entries that are not tied; `_step_holds` charges upkeep, expires knots
and drops holds whose target died or broke free; `release` undoes whatever the
weave was doing. Events `hold`, `release`, `tie` and `broke` let the view keep a
node per hold (`Weavefx.hold`: a body on the target and a tether to the weaver).
Techniques (`profile.techniques`, granted by an activity's `grants`) gate `tie`.

## Arms (data/weapons.json, docs/MELEE.md)
Everything that is not channelling. The plan and to-do list are in `MELEE.md`.
- **A weapon is a row; a move is a row** in the same file's `_moves`. A weapon
  names the moves its light chain walks through, its heavy move and its low move,
  and whether it can be thrown or shot. Adding one is data.
- `Rules`: `CLASSES` (Channeller, Warder, Aiel, Hunter of the Horn: skill ceiling,
  guard, dodge cost, speed, health, armour, starting kit), `blow`, `move_times`,
  `move_cost`, `guard_share`, `dodge`, `skill_level`, `wield_block`.
- `Profile`: every profile has `cls`, `stats` (might, quickness, endurance),
  `skills` (xp per weapon family) and `kit`. A fighter's Power fields are zeros so
  that all profiles share one shape.
- `Sim`: `request_attack` (wind-up, strike, recovery, one buffered input, chain),
  `_strike` (reach and arc, or a `missile` effect), `set_guard`, `set_duck`,
  `request_dodge`, `equip`. `_wound` is the one path for steel reaching a body:
  guard and parry, armour, stagger, push, then `_hurt`.
- **Enemy blows are geometry.** A Trolloc picks one of its row's `attacks`, and
  0.4 s before it lands commits to a direction (`aim_yaw`). At the end
  `_enemy_blow` hits whoever is in the arc: not someone who stepped out, not
  someone untouchable mid-sidestep, not someone ducking under a high one.
- **Forms** (`_forms` in the same file) are moves a fighter learns: `Rules.lore(p)`
  is the weave table for a channeller and the form table for a fighter, so study,
  the tree screen and progression are shared. `tally.effort` (stamina spent on
  blows) is to forms what `tally.draw` is to weaves.
- `Sim.ARMS[id % 4]` is what a Trolloc carries; `attacks` rows name the `arms`
  that can make them. `src/test/arms.tscn` shows every weapon in a hand.
- Stamina is the one resource for all of it, and `Rules.vigor` weakens blows as
  it does weaves.
- View: `Armoury` builds each weapon from boxes and rods; `Hero.arm` puts it in
  the hand using the rest pose to find the grip (no per-model numbers). The
  `blow` event plays the move's clip at the speed that makes it land on time.

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
- **Rooms:** a host keeps `_rooms` (name -> sim, activity, peers, tick) and sends
  each room's events and snapshots only to its peers. Hosting from the camp is
  one room, "". A server makes a room for each name asked for.
- **Secrets without encryption** (this Godot build has no DTLS): `_greet` sends
  each arrival a nonce; `_proof` hashes the word with it; the passphrase lock is
  `_seal`ed (AES-CBC) under a key made of word and nonce. See `SERVER.md`.
- **Lobby:** `ask_lobby` returns who is in which room; the camp polls it.
- **Prediction:** a client moves its own body at once (`game.gd` `_predict`, the
  same speed rules as the sim) and leans back toward the host's position as
  snapshots arrive, snapping if they disagree by more than 3 m.
- Not done: reconnect, a certificate to prove the server is the real one,
  friends visible in the camp.

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

### Walls and finding a way (src/core/map.gd, sim.gd)
- `Map.walls()` are boxes `{x, z, hx, hz, h, yaw, look}` made by `Map.use` for the
  map (the breastwork, the wagon ring). `Map.unblock` keeps bodies out of them,
  `Map.in_wall` stops anything flying below their top, and `Scenery.walls` builds
  each from its `look`: the view cannot disagree with the sim.
- `Map.grid()` marks which 1.25 m cells can be stood in. Every 0.4 s
  `Sim._path_field` floods outward from the players; an enemy whose straight
  line to its target crosses a wall (`Map.crosses`) walks downhill on that field
  (`Sim._steer`), and otherwise goes straight. Maps with no walls skip all of it.
- A map with `around = true` (the wagon ring) spawns waves all round its rim.
- Enemy rows may have `ranged` (archers), `evades`, `steady`, `links`, `fester`
  (see `data/enemies.json` `_doc`). The Myrddraal body is `Species.MYRDDRAAL`, a
  generated human with no eyes.

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

## More Shadowspawn (15 Nov)
Each is a row in `data/enemies.json` plus one behaviour in `Sim`; the row's doc line
says what every number does.
- A wardrobe shell with `cell` (and `bone`) is a hanging piece meshed alone at its own
  cell size and hung from one bone: the Myrddraal's cloak. `talons`, `maw`,
  `eyes_black` are species flags read by `Creature` and `Faces`. In the clay, colour
  blended from a small prim loses to the skin around it: paint it as well (`PAINT`).
- **Darkhound** (`gen: HOUND`, `src/gen/hound.gd`): the same clay on a four-legged
  skeleton of its own with its own gait (walk to gallop, crouch and spring, fall).
  It answers to the Walker's calls so the game drives both alike. `pounce` reuses the
  Myrddraal's lunge (`Sim._fade`) without the stalking; `regen` and `steel` are new.
- **Draghkar** (`gen: DRAGHKAR`): a generated man (`Species.DRAGHKAR`) with `Wings`
  (flat membranes on finger bones, hung from the chest bone; mirrored in their points,
  because a mirrored node cannot also be turned reliably). `Sim._draghkar`: fly
  (untargetable, like a Myrddraal in shadow), land, sing, lure, kiss, flee, away.
  A player under the song has `entranced` (status bit 32768): input is overridden and
  casting, striking and dodging are refused.
- **Dreadlord** (`gen: DREADLORD`, `channels: true`): the archer's `ranged` block with
  a `weapon` (dark_fire bursts) and a `wind` (it is seen gathering), plus `strike`
  (a `doom` effect: marked ground, then lightning). Shield from the Source fastens on
  anything with `channels`; cut off (bit 65536), it can do neither.
- Draghkar and Dreadlord bodies are built the first time one is met, then kept.
- **Trolloc blows**: `attacks` are per weapon, the favourite first; `Sim._pick_blow`
  weighs them by the target (ducking, parrying), the crowd and the distance; `on` is
  what a blow does to someone it lands on unguarded (players are shoved through
  `shove`, since their `vel` is not what moves them).
- **Sword forms**: `ArmPose.STROKES` holds a keyed path of the sword hand and blade
  per form (t = 1 as the blow lands); a two-bone reach and a hand turned outright
  follow it over whatever clip is playing, with the trunk twisted and leant.

## What the Shadowspawn are meant to look like (researched 15 Nov)
From the Tar Valon Library pages for each (which cite the novels and *The World of
Robert Jordan's The Wheel of Time*), and what the game does about it.
| Creature | Canon | In the game |
|---|---|---|
| Myrddraal | Tall, muscular, every one alike; fishbelly-white skin; a man's face with smooth skin where the eyes would be; lifeless black hair; black plate in overlapping strips over black; a black cloak with a deep cowl that hangs still in any wind; a black Thakan'dar sword whose wounds fester; moves like a serpent; black corrosive blood | Tall and muscular (was thin); strips of black plate round the trunk and in rings down the arms, pauldrons; a full cloak from cowl to heel hung from the chest bone alone, so nothing stirs it; a straight black sword; a man's hands (no claws). Not done: the hair (under the cowl), black blood |
| Draghkar | A tall pale man; eyes far too big; a mouth like an open wound, red, with pointed teeth; talons; huge bat wings that hang about it like a dark cloak; soars like a bird of prey; a soft crooning song | Tall, thin, pale; a long hairless skull, no nose to speak of (a ridge and two slits), large all-black almond eyes, and a wide thin red mouth set low with points of teeth in it (Josh, 15 Nov: the first one read as a human head with a red moustache); long talons; wings folded in a V behind it like a cloak, spread to fly face-down. Weak: wings are flat panels and cannot wrap round the front |
| Darkhound | A hound only in outline; darker than night; big as a pony; eyes that shine like silver; teeth like burnished steel; smells of sulphur; no prints on soft ground, prints in stone; cut apart, it runs to liquid shadow and re-forms; only the Power kills the newer breed | Pony-sized, near-black, hackles down the spine, silver eyes that glow, a steel-toothed open jaw; killed, it sinks into a pool of shadow instead of lying there. Not done: prints in stone |
| Dreadlord | No set look: men and women who channel for the Shadow | A hooded man in black with blood-red slashes and sash. Not done: women |
| Gholam, Gray Men | Look like ordinary people (boneless; unnoticeable) | Not in the game |
Trollocs were left alone, by Josh's word.

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
- The skirt (redone 15 Nov after "they don't quite look right") is cut from the
  outfit's own measured waist and hips, gathered under a waistband, and falls in
  folds that deepen to the hem. `pleat()` in the Blender script and in the garment
  shader are the same function (the shader shades the creases): change both. After
  rebuilding a `.glb`, run `godot --headless --import` inside `nix develop`, or
  renders keep showing the old model.
- Cloaks are the player's choice, not only the look's: `style.cloak` picks a row of
  `Hero.CLOAKS` over any dress and `style.cloak_len` cuts it short (the shader
  discards below `cut` and rescales so hems and fur sit at the new edge). A look's
  `bodice` colour recuts the pack's leather bodice as cloth (torso mesh only).
- The Myrddraal's cowl is a free-standing hollow shape (`free = true` on a wardrobe
  shell: meshed once, whole, not cut to the body's grids) with the face set back
  inside it; `Faces` has an `eyeless` branch (hollows of smooth skin, hard mouth).
- `shaders/outfit.gdshader` also draws Cairhienin `slashes`, Tairen `sleeve`
  stripes, silk `sheen` and `mail` (rings of steel where the cloth is) from one
  row each; its cloth masks are set from colours measured in the atlas.
  `garment.gdshader` has a gleeman's patches (5) and a silk border (6).
- **The body is the player's** (`profile.style`): hair mesh and colour, skin and
  eye tints on the sourced maps, height and build as a scale of the whole
  figure, beard. `Hero.instantiate(look, seed, style)`; the `player` event
  carries it, so everyone sees it. `src/test/looks.tscn` shows every outfit.
- The free packs hold two outfits and five hairstyles. More (nobles, armour, the
  full outfit set) are in the paid Source packs; Josh would buy those.
- `src/gen/human_rig.gd` (generated bodies on the older rig) is kept only for the
  test bench and crowds of background people. Do not use it for players.

## View (src/game)
`camp.tscn` is the main scene: the hub, and you walk it (same controls as a fight:
WASD, click to look around, Esc frees the mouse).
- **Activities are doorways.** `camp.gd` `_doors` stands one stone doorway per row
  of `data/activities.json` in an arc (`Scenery.doorway`, `shaders/portal.gdshader`);
  an open one glows in the colour of its kind, a closed one is dark and says what
  it needs. Stepping into an open one calls `_go`, which hands the choice to
  `game.tscn` through the static `Launch.args`. You come back out of the doorway you
  left by (`Launch.last_activity`). A new activity is a new row, nothing else.
- The character sheet stays on the left. There is no right-hand panel: the server,
  joining a friend and quitting are behind Esc (`_menu_fill`).
- **The weave tree** (`weavetree.gd`, T) is a wheel of the Five Powers: each Power
  has a point on the rim where its simplest weave sits, weaves that join Powers sit
  between them and further in by how many weaves they wait on, and Balefire is the
  hub. Positions are computed from `flows` and `needs`, so a new weave places
  itself. Click an open weave to study it.
- `glyph.gd` draws a weave the same way everywhere (tree and HUD): a disc ringed by
  one arc per flow in its Power's colour, the flows crossing inside.
- `hud.gd` draws the fight's HUD by hand from the game view's state: name, strength
  and flow pips; health and stamina bars; the known weaves as glyphs with a
  clock-face cooldown; a crosshair ring that fills as the chosen weave comes
  ready; other players' names and health; red edges when hurt.
- UI is laid out for 1280x720 and scaled to the window (`project.godot` stretch
  mode `canvas_items`, aspect `expand`).
- Command-line flags (`--auto`, `--activity=`, `--join=`) skip the camp, which is
  what bots and renders use. To render the camp itself: `--who=Name`,
  `--show=tree|menu`, `--stroll=N` (walk to doorway N), `--new` (creation).

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

### Weave effects (rebuilt 15 Nov after a review of every weave in renders)
`src/game/flowfx.gd` holds the parts and `weavefx.gd` says what each weave is made of:
- `Flowfx.Ribbon`: a camera-facing strip that trails a moving point in world space
  (`shaders/fx_ribbon.gdshader`: bright core, body broken by scrolling noise). It is
  the thread of the Power: the flows while a weave is made, a fireball's wake, the
  Lash of Water (one `fixed` ribbon whose points are set each frame), balefire
  (`Flowfx.beam`), Hammer of Air's gusts and an explosion's streamers (`Flowfx.streak`).
- `Flowfx.ball` (`fx_fire.gdshader`): a sphere whose surface boils; `burn` 0 to 1 opens
  holes in it, so a burst burns out instead of fading like a balloon.
- `Flowfx.shell` (`fx_shell.gdshader`): rim-lit, with threads running round it: the
  Dome of Air and the shield that closes on a channeller.
- `Flowfx.shard`: a crooked flat-faced spike of rock (Heave the Ground, Rolling Ring).
A `ShaderMaterial` parameter must be set once before a tween can find it
(`shader_parameter/burn`): `fire_mat` and `shell` do so.
`tools/weave.sh <id>` renders one weave side-on at six moments (woven, loosed, landing);
`DEMO=<metres> tools/weave.sh <id>` for the ones the bot will not choose.
The stubble paint on generated male faces is skipped for the Eyeless and for a
Draghkar: it is laid last and washed the colour out of anything on the lower face.

## Testing
- `tools/test.sh`: rules and progression (`tests/run_tests.gd`: every weapon, every
  defence, holds, enemies, Powers, whole activities played by bots), co-op over
  localhost, and a dedicated server with two rooms, the lobby and the store.
- `tools/ghost.sh`: the controls. `Ghost` feeds real input events on scripted
  frames, the game prints what the sim made of them, and the script checks it.
  It exists because bots drive the sim directly: an error on the input path
  (aiming with a weapon selected) passed every other test.
- `src/test/arms.tscn`, `looks.tscn`: lineups of every weapon and every outfit.

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
| `assets/quaternius/ual2.glb` | Quaternius: Universal Animation Library 2 (Standard), from quaternius.itch.io | CC0 1.0 (`ual2_License.txt` beside it) | Sword cuts, block, shield, throw and knockback clips for player characters |
| `assets/quaternius/animation_library.glb` | Quaternius: Universal Animation Library, older rig, from opengameart.org | CC0 1.0 (`LICENSE.txt` beside it) | Skeleton and clips for generated humans |

## Next steps, in order
0. `BACKLOG.md` is the full list of what Josh has asked for; this is only an order.
1. Fight feel: clearer status effects and effects for the weaves beyond
   fireball. (Flows while forming and a view-only hit-stop are built: the struck
   body freezes, never the sim, so co-op is unaffected.)
2. More to hold and more techniques: inverting, cutting another's weave,
   linking. (Holding, upkeep and tying off are built.)
3. Co-op: friends visible in the camp, reconnecting. (The server with rooms and
   a lobby, prediction, looks and latecomer joins are built.)
4. More enemies (Draghkar, Darkhounds, Darkfriend channellers) and a third map.
   (Archers, the Myrddraal, pathing round walls and the wagon ring are built.)
5. One linear mission; then casting by drawing (see VISION.md).
6. From `WEAVES.md`, not built: Delving, Illusion and the weather weave; Skimming;
   techniques (tie off, invert, cut); linking; angreal. Gateway does nothing yet.
