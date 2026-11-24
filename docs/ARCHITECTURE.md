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

### Arms added 18 Nov
- A blow struck running toward its aim does 20% more; one asked for while rolling
  toward the aim waits for the roll's end and comes out of it 30% harder
  (`queued.from_roll`, `rolled_at`). Rolling away and attacking is still "busy".
- Swords, knives, axes and spears leave enemies bleeding (a fifth of the blow over
  4 s, `bleed`). The bandleader (`guards` in enemies.json) turns 65% of a blade from
  its front unless the blow is heavy or a form, which breaks the guard (staggers it).
- Wounds: 30% of each hurt a player takes is a `wound` (to 60% of health), sent to
  that player only; rest mends up to it, Healing closes it, death clears it.
- Trollocs sometimes seize a player they hit unguarded (`grabbed_by`, `chained`);
  Space twists free for 15 breath. Bots twist free at once.
- Fire arrows: a bow (not a crossbow) drawn within 3 m of a burning watch-fire or
  burning grass looses a lit arrow (`lit`): it sets what it hits burning, and the
  grass where it falls. The view gets `weapon:lit` in the effect row.
- Armour (`armour` in enemies.json: bandleader 0.3, Myrddraal 0.35) turns that share
  of a blow in hand unless the move is a thrust (`trail: lance`).
- A spear held still (no move, no swing) is set: an enemy entering its reach from
  the front meets the point (120% of a jab, staggered, stopped), once each per 2 s.
- The Eyeless gaze: facing a Myrddraal within 14 m slows weaving to 60% and feet to
  80% for 1.5 s after (0.75 s for fighters).
- Fighter bots flee only when badly hurt and pressed by three or more, and turn back
  at half health or when one or two are left (natural healing is slow).

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
- **Server only (17 Nov).** Every doorway joins the one game running on the server
  (`Launch.SERVER`, `--server=` to override); one game at a time, everyone in it,
  no rooms in the interface. If the server does not answer (camp polls it; a join
  gives up after 6 s), the fight is played on this machine alone and a notice says
  so. The old "host and let friends join by address" path is gone from the menus.
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

### Scenery pass (16 Nov, after rendering every map and ranking what looked worst)
- **Night.** An activity with `"night": true` (the long night) gets a moon instead of
  the sun, a flat cold ambient, a star panorama generated in `World.build`, watch
  fires up the pass and torches on the line. It had been broad daylight.
- **Cliffs** (`shaders/ground.gdshader`): beds of uneven thickness that dip and wander,
  a dark ledge under each, cracks down the face. The old shading read as cloud.
- **Props** in `scenery.gd`, all unsolid and kept off the fighting ground: `barrel`,
  `crate`, `sacks`, `bale`, `tent`, `torch`, `practice_post` (replaces the white
  cylinder), `yard` (rail fence, archery butts, weapon rack round the training
  ground), `camp` (tents, stores, banner). Fallen rock is angular, not cubes.
- Camp doorways are stacks of rough stones. `--camyaw=deg` works in the camp too.

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

### Doorways you walk through (17 Nov; camp.gd `_portal`, game.gd "far side")
No loading screen and no flash between the camp and a fight. Coming within 10 m of
an open doorway, the camp instantiates the fight scene inside a `SubViewport` with
its own `World3D` (`preview` in its args) and shows that viewport on the doorway's
face, sampled at `SCREEN_UV`, from a camera placed in the fight exactly as the camp's
camera stands relative to the doorway (`M = gate_frame * door_frame⁻¹`).
- Until your feet are 0.6 m through, the fight's body for you copies the camp
  body's transform and animation frame (`stand_in`), so the half of you past the
  threshold is seen through the doorway in step.
- Feet through: keys move that body (`take_control`); the camp camera follows it,
  mapped back.
- Camera 0.3 m short of the threshold: the fight node is moved out of the
  SubViewport into the root (`moving_worlds` stops `_exit_tree` ending the session),
  the camp is removed, the fight's camera is made current where it already is, and
  it eases from the camp's framing to its own (`enter_world`).
- In preview the fight renders with linear tone mapping and no glow, so the camp's
  own tone mapping is applied once; both are restored on arrival.
- The far side's gateway is only an outline of light (a gateway is a slit in the
  air); grass and stones behind it are removed, and the far camera's near plane sits
  just short of the doorway, so nothing on the near side gets in the view.
- `Map` and `Terrain.amp` are global and the fight sets them while the camp is still
  walked in, so the camp keeps its own copy (`Map.state()`) and asks its heights and
  walls through it.
- Shadowspawn are generated once per run on worker threads (`Cast`), started on
  arrival in the camp; Draghkar and Dreadlords no longer hitch on first sight.
- **Home the same way** (`game.gd` `_open_home`): when a round ends, a gateway opens
  ahead with the camp built behind it in its own world (`Launch.return_preview`; the
  camp keeps still and hidden, `returning`), arriving at the doorway you left by
  (`home_frame`). The round is over, so the body walks in the view alone; as the
  camera crosses, the camp takes over (`enter_from_fight`). Enter still goes straight
  back. The dead are carried home (Enter).
- No stalls (17 Nov): the camp loads the fight scene on a thread when it opens
  (`load_threaded_request`), and the far world builds its terrain and grass a few
  rows a frame (`Terrain.build_mesh`/`Scenery.scatter` take a tree to spread over).
- The far fight is held still (`Session` room `hold`, PROTO 8) until your feet are
  through (`take_control` sends `begin`): waves do not start while you look.

### Making a character (17 Nov)
Two panels with the character standing between them: who you are and how you look on
the left (calling, half of the Source or sex, origin as cards; appearance below), your
gifts on the right (affinity as coloured bars with steppers and the Talent trade as
cards for a channeller; weapons, forms and body for a fighter, with costs and points
left shown). Cards draw their own icons (`Icon`: a weave's threads, a weapon, a
Power's colour). **Origin** sets the dress and looks a character starts with
(`ORIGIN_LOOKS`: Aiel tall and red-haired in cadin'sor, Cairhienin short and pale,
Domani copper-skinned, and so on); all of it can still be changed.

### Keys and the bar (17 Nov)
Every key can be rebound (Esc menu, Keys): `Keys.k(KEY_W)` is whatever the player
bound to the key that sits where W does on QWERTY; the game still names defaults,
and hints go through `Keys.name`, so they follow. Bindings live in `user://keys.json`.
The bar's order (slots 1-9) is set in the loadout and kept as `profile.hotbar`.

### Pause menu (17 Nov; `pauser.gd`)
Escape opens a menu: resume, hide everything (a screenshot of the paused game; Escape
brings it back), keys, sound (`Settings`, `user://settings.json`), back to the camp,
quit. Offline the world stops while it is open; online it goes on. The end of a round
is a notice, never text across the screen, and the world keeps moving after it.
Renders, tests and bots keep their characters in `user://dev_profiles`
(`Launch.use_profile_dir`), never the player's folder.

### Words on screen (17 Nov)
Nothing is written across the middle of the screen. `Toast.say(title, body, kind)`
puts a small card at the top right that fades; it lives under the root, so a notice
raised before a scene change survives it. The camp sheet is built from `_section`,
`_row`, `_pips` and quiet `_button`s on `Glyph.card`. Doorways have no floating
names: coming up to one raises a notice. The round's result and the tour notes sit
on cards. Offline, Escape pauses with nothing on screen (`pauser.gd`).
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

## Rounds (src/core/round.gd; built 17 Nov, the multiplayer direction)
The game is moving to multiplayer rounds (the user's design, 17 Nov; their answers
are recorded in BACKLOG). An activity with a `"round"` row (the holdouts and the Wild
Hunt) is a round: everyone starts afresh and grows during it, and none of that
outlasts it.
- **Round copy.** `Sim.add_player` makes `Round.begin(profile)`: a duplicate with a
  rolled potential and start (channellers) or a rolled gift (fighters), practice
  zeroed, three flows. Every rule (`Rules.power` etc.) reads it as it would the
  saved character. The saved character is never touched by a round.
- **Strength roll.** Potential is a bell on the Companion scale: mean 20(8), sd 7.4,
  so about 47% of women can open a gateway and 0.6% reach 1(+12); men's curve is
  six levels stronger (77% gateway, 0.6% reach ++1). The start is potential plus a
  bell gap (mean 6, 1 to 10). The potential is never shown: level-ups give a hint
  ("There is more in you yet").
- **Team levels.** Kills give the team experience (`Round.xp_of`: hp/12 times tier).
  Each team level reaches every player: women's strength moves smoothly along a
  path that closes 75% of the gap by level 12; men stay put and leap 2 to 5 levels
  at random, averaging the same; a flow every three levels; a fighter gets a stat
  point every other level. Each level also gives a choice (`Round.choices`, Tab in
  the game): a level of mastery in a known weave, or for fighters a skill level, a
  form, or a weapon. Bots spend theirs at random. A drop-in arrives at the team's
  level.
- **Fighters' bodies.** 1.5x a channeller's health (by class) and stamina
  (`stamina_max`), 15% faster running (`Rules.run_speed`), and a gift roll (bell,
  ±2.5) that adds to their stats.
- **Warders.** A woman channeller has a chance of a bot Warder equal to the share
  of rolls at or above hers (`share_at_or_above`); it is a middling warder driven by
  the sim itself (`bot` entities are driven in `Sim.step`, so on a server too).
- **Waves.** `Round.plan` builds 16-18 waves over about 20-25 minutes from the row:
  most are Trollocs alone and grow 18-20% a wave, every fourth brings the place's
  specials, every sixth is a horde (2.5x), the last brings the boss. Surviving them
  all is the win.
- **Friendly fire.** In a round a player's blows, missiles, bursts, beams and
  rolling fire hurt friends fully (`Sim._struck`); aiming and bots choose only foes.
- **Going down.** At 0 health a player in a round is down (`downed`), not dead, and
  cannot act. Nothing more lands on them in the waves (enemies move on; balefire still
  unmakes). When the wave ends (`Sim._wave_end`: its field cleared, or the next wave
  arriving first), a friend on their feet within 5 m (`Round.FRIEND_REACH`) gets them
  up on 1 health; with nobody near they die. Healing gets them up at once, from 0.
  Everyone down at once is a death for all (the round is lost). The dead come back
  with the next wave, potential and strength fallen 1d6 levels (`Round.weaken`).
  (User's ruling, 23 Nov: the old 15 s timer and "half a body more" pool read badly
  on the health bar.) Bots Heal a downed friend if they can, else go to them once
  three or fewer foes are left.
- **No lasting wounds** (23 Nov): the hatched end of the health bar (hurt rest could not
  mend) read as "more to take before dying" and was dropped; rest mends all of it.
- **Damage numbers** (`Hud.pop`): on every `hit` you dealt (and, smaller and red, those you
  took), merged when they land within 0.3 s on one body; size, colour and liveliness grow
  with the number (five steps, the last a shimmering white-hot one with a ring).
- **Bots weave like people** (`Bot.drive`): only at what they can see (they go round
  otherwise), a pause between weaves and an aim error; human-paced against players,
  steadier against Shadowspawn (they are the test stand-in for winnable rounds).
- **Speed pass (23-24 Nov).** Measured with `--perf` (80 Trollocs, 1080p, RX 7700 XT,
  uncapped): walkers posed on worker threads, and every frame only near and in view (60 Hz
  further, 30 Hz far or out of view; settled corpses frozen); one shared mesh per creature
  body with generated LODs (`Creature.make_mesh`); trees found by grid cell in the sim
  (`Map.trees_near`); dead trees, walls, wagons, doorway stones, stations, barrels, crates
  and tents merged into one mesh per material (`Scenery.bake`); debris as four multimeshes.
  Draw calls: fight about 2200 to 1100-1350, camp 1870 to about 500; nodes in the camp 1260
  to 320. Fight fps about 105 to 260 at the start. Picture quality now also sets shadow
  cascades and distance, soft-shadow filtering, SSAO quality and MSAA (High as before).
- **Fighters' trees** (`MELEE.md`, "The weapon and form trees"): the weapon tree is data on
  each weapon row; one weapon of each kind; studied between rounds by effort.
- **Balefire** burns its victim's last moments out of the Pattern (`Sim._unmake`):
  whatever it harmed in the last 5 s (times the weaver's reach) stands again as it
  was, the dead included. Harm is kept for 20 s in `Sim.ledger` for this.
- **Linking** (L; `Sim.request_link`, canon): a woman leads and takes in every
  channeller within 4 m who has offered (L); men join only a woman's circle, never
  each other. The leader weaves with 1 + 0.6 x each member's strength over hers
  (`_circle_mult`) and two more flows per member; members cannot channel and cannot
  leave unless she lets them go (L again). A blow of a quarter of their health, or
  going down, knocks someone out.
- (17 Nov, after the user's play) Level-ups can learn a new weave from the chart
  (`learn` in `Round.choices`); Tab opens the weave chart for a channeller (click a
  known weave to grow it, an open one to learn it); a lone choice takes itself. G on
  a weave that strikes keeps it going by itself (`Sim.toggle_auto`: it holds its
  flows and weaves itself at the nearest foe whenever ready). Right click drops a
  weave being made. A cleared field brings the next wave in 6 s. Trollocs are a
  little faster, begin their blow while still closing, and a Hammer of Air drops
  some to a knee; the player is a little slower (4.7 m/s base). Space by a low wall
  or a wagon vaults it (`Map.vault_over`). Wagons collide as oriented boxes
  (`rot`). Archers need a clear line (wagons and trees block it; a breastwork is
  shot over). Natural healing is slow (0.8%/s after 10 s). Ranks show one number.
  The cloak hangs from the shoulders (leg weights moved to the pelvis at load) and
  swings in the shader with speed (`Hero.cloak_motion`).
- **Results.** `Progression._award_round`: a loss pays nothing; a win pays renown and
  one unlock owed (`unlocks_owed`; the camp's unlock choice is not built yet).
- **Characters and loadouts** (`Profile.make`, camp `_loadout`, `_retrain`, `_unlocks`).
  A channeller is created with 2 + 2 affinity in their half's Powers and 1 in Spirit,
  moved two-for-one, or traded away whole for one Talent (once, at creation). They
  own affinity (up to 9), Talents, weaves; into a game they take at most 2 Talents,
  3 weaves besides the one they were born with, and 5 affinity points plus 2 per
  empty Talent slot. Between games affinity moves two-for-one, also into might,
  quickness and endurance. (The loadout page also moves owned points, two for one: one page, 17 Nov.) A fighter spends 6 points: weapon 1, form 2, stat 1 (2 at
  most), and takes up to 3 weapons and 3 forms. A won round owes one unlock: three
  offers (Talents, weaves, +1 affinity; weapons, forms), one kept. Practice and spars
  no longer grow a character at all.
- **Saves.** Characters carry `format = 2`; older ones are deleted when the camp
  opens and old copies from the server are not taken back (the user asked).
- `short_watch` is the old three-wave watch, hidden from the camp, kept for tests.
- (17 Nov) Every activity is open from the start except the dream duel (renown 15).
  The training yard rolls strength each time (`"rolls": true`) without being a full
  round, and its practice posts have 45 health. `practice` is the same yard without
  the roll, a fixed sandbox for the rules tests. A tour station or render that sets
  `--strength` keeps it (`no_roll`). Offline games open no port (`Session.host`
  with `listen = false`, an `OfflineMultiplayerPeer`), so two copies of the game on
  one machine never collide.

## A Darkfriend among us (17 Nov; `darkfriend` activity, Sim `_assign_darkfriends`)
A single-stage round in the wagon ring. Eight seconds in, roles are given out among
the real players (bots never): with 3 players an 80% chance of one Darkfriend, with
4 or more 95%, and with 5 or more a further 60% of a second. Each player is told only
their own role: events carrying `to` go to that player's machine alone
(`Session._step_room`). A Darkfriend's roll moves 1d4 levels stronger for each loyal
player beyond one (`Round.strengthen`). Two Darkfriends are not told of each other.
- The Darkfriend's secret (J, shown only to them): once a game a large gateway opens
  beside them and three Darkfriend blades (poisoned knives), two archers and perhaps
  a Dreadlord or two come through (`request_df_gate`). A Darkfriend who channels
  needs gateway strength, 19(7); one who does not has it opened by one of them.
  The Shadow's own never choose the Darkfriend as their quarry.
- Players can Shield and bind one another here (`_aimed` takes players in this mode).
- Down as in rounds (up at the wave's end with a friend near), and no coming back after a death.
- Ends: every loyal player dead, the Darkfriend wins. The waves outlasted, the loyal
  win only if every Darkfriend is dead, Shielded or bound in Air at that moment;
  otherwise the Darkfriend wins. `Sim.won(id)` gives each side its own result.
- **Rope** (K, held; `Sim.set_tying`): a fighter standing over a player who is down,
  knocked over or staggering ties them in 3 s: no walking, blows or rolls (channelling
  still works, as in the books, so a channeller also needs a Shield). Anyone unties
  them the same way; fire burns the rope off. A tied Darkfriend counts as held.
- Talking happens over the group's own voice chat.

## Seeing the flows (21 Nov, the user's rule)
Only a channeller sees flows, and only those of their own half of the Power; anyone sees
what a weave does. `Weavefx.sees` is set from the one watching (`game.gd` `_set_sight`), and
each visual says which it is: `Weavefx.flows(node, power)` hides a node of flows, and
`cast()` puts flows under `_flow_parent`. The weaver's power comes from the player's spawn
row (`power`), and the snapshot's fx rows carry their owner (index 8) for things in flight.
Hiding is per machine, by visibility, so the gateway windows follow it too. `--sight=all`
shows everything (pictures); `--sex=m|f` and `--allysex` choose throwaway channellers'
halves (women unless told).

## Gateways (17 Nov, the user's rulings)
- The Shadow's creatures (Trollocs, Myrddraal, Darkhounds, Draghkar: `_is_shadowspawn`)
  die passing through a gateway. They keep off one, unless shoved in (moving faster
  than 2 m/s) or caught by it in its first 0.6 s. Darkfriends and Dreadlords are men
  and pass.
- **Windows.** Both ends stand the same way, so going through is moving by the
  offset between them (`_gate_step`: crossing an upright end's plane within its
  width; standing on a flat end). Each face shows a SubViewport rendered from the main
  camera moved by that offset (`game.gd` `_open_window`), untoned so the main view
  tones it once, never drawing the faces themselves, near plane just short of the far
  face. When your body crosses, the camera stays on its side (`cam_shift`) until it
  reaches the plane too, so you are seen through the window and nothing jumps.
- Missiles and woven bolts crossing a mouth go on out of the other end by the same
  offset (`_fly`). Blows, cones and beams do not pass yet.
- A gateway's edge cuts as it opens and as it folds shut: anything standing where
  either end forms or closes takes `TUNE.gate_cut` (120) and staggers (`_gate_cut`).
- Either end can lie flat: aimed at the ground within 4 m, the near end is a hole at
  your feet; aimed more than 4 m up into the air, the far end opens in the sky, and
  whoever comes through falls (knocked down, 3.5 damage a metre).

## The endless night (`endless`)
Eighty growing waves at Tarwin's Gap by night; thirty minutes held is a win
(`endless_won`), and the fight goes on for as long as anyone lasts.

## One doorway per mode (18 Nov, the user's ask)
- The hub has a doorway per mode: training, Hold the line (`holdout`), A Darkfriend
  among us (`darkfriend_door`), The endless night (`endless_door`), Two banners, and
  the dream duel. A mode row with a `pool` names setups from `_setups` in
  activities.json (a map, night or not, the special enemies and the last wave):
  Tarwin's Gap by day and by night, the wagon ring, the Wild Hunt.
- `Rules._expand_setups` makes a hidden activity "<mode>@<setup>" for each, the mode's
  rules with the setup's place and foes (endless adds its own extra specials), so
  every machine has the same ids. Walking up to the doorway picks one at random
  (`Rules.pick_setup`) and a notice names it; `--activity=holdout` does the same.
- The old per-place rows stay, hidden, for the tests and tour stations.

## Two banners: team battle (`team_battle`; Sim `battle`, built 18 Nov)
- Two sides of players. Each player joins the side with fewer on it, at that side's
  end of the field (outside the wagon ring, 21 m out). A few seconds in, bots fill
  both sides to the same number (at least `battle.fill`, 2), half channellers, half
  Warders. No rolled Warders in a battle: the sides are matched by number.
- Each side levels on its own kills (`levels`, `xps`); killing one of theirs is worth
  about two Trollocs to the whole side. The round meter carries both sides' levels,
  the score and the time left; each view shows its own side's (`game.my_team`).
- Going down works the old way here (no waves): a friend standing over you 2 s brings you
  back, 15 s alone or one more blow from the other side finishes you;
  a death scores a point for the side that caused it (a downed player left to die is
  still the work of whoever put them down: `downed_by`) and you return at your end
  after `battle.respawn` seconds, with no strength lost.
- Ends at `battle.kills` (10) or, after `battle.time` (12 min), with whoever leads.
  `Sim.won(id)` is by side. A light trickle of Shadowspawn harasses both sides.
- Rings at everyone's feet: blue for your side, red for theirs.

## Weaves change the ground (Sim `patches`, `_mark_ground`; built 18 Nov)
- Fire in a weave (not balefire) leaves burning grass where it lands (9 s; it
  burns anyone standing in it). Lash of Water leaves puddles along its line (45 s):
  they put fire out, douse the burning and soak. Air (a Hammer, an Air blast) blows
  fires out. Heave the Ground and the Rolling Ring throw down stone walls they cross,
  and Heave leaves a ridge of rubble (vaultable cover, 30 s).
- Walls carry ids (`wid`) so they can fall and rise in play: `Map.add_wall`,
  `Map.remove_wall`, and `wall_up` / `wall_gone` events that clients apply to their
  own Map. A player joining late misses earlier changes (not sent in the roster).

## Debris (18 Nov)
`src/game/debris.gd`: 300 loose pieces (twigs, pebbles, dead tufts) scattered over
the field when a fight is set up. `Wind.gust` (any blast, any weave mostly of Air)
throws those near it outward and up; they tumble, bounce and settle. Seen only, like
Wind and Scorch: each machine scatters its own, and nothing in the sim depends on
it, so nothing is sent. Only moving pieces cost anything per frame.

## Solid props and wind (18 Nov)
- Every prop that stands on a fighting ground is placed by `Map._props` (by map and
  activity) as a circle in `Map.trees()` with a `prop` name, or as a wall: the sim
  collides with it where `Scenery.props` / `Scenery.yard` / `Scenery.camp` draw it.
  Props below 1.6 m do not block an archer's line. Enemies path round props too.
- Wind (`src/game/wind.gd`, view only): a steady wind per place and gusts from
  blasts and Air weaves, passed to shaders as the global parameters `wind_vec` and
  `gust` (declared in project.godot). Grass, banners (`shaders/flag.gdshader`),
  cloaks and hair (`Hero.cloak_motion`) read it; a looped wind sound follows it.

## Duelling in the dream (src/core/dream.gd, data/dream.json; built 16 Nov)
An activity with `"dream": true` (only `dream_spar` so far) gives every player **Will**
(100; back at 13/s after 1 s without spending, x1.6 standing still) and the dream moves,
each a row in `data/dream.json` with its cost and numbers. Arms and weaves still
work beside them. (21 Nov, the user's ask: three times as many, 24, and a dream bar
of eight slots with an inventory, I, to choose which eight; see below the table.)

| Move | Key (default bar) | Will | What it does |
|---|---|---|---|
| Step behind | Z | 24 | Behind the nearest opponent within 32 m, facing their back |
| Step away | X | 12 | 7 m straight back |
| Step there | V | 16 | To where you are looking, up to 24 m |
| Deny | Shift | 7 | For 0.45 s, the next dream-thing to reach you is unmade: you get 14 Will, its maker loses 12 and is shaken (no dream moves) for 1.3 s |
| A thrown spear | T | 11 | 15 damage, fast, straight |
| Chains | Y | 26 | After 0.45 s they close on the nearest opponent to the aim point; held 2 s (no blows, rolls or walking) unless they left the spot or Denied |
| The ground turns | U | 20 | A marked circle opens after 0.55 s: slow and 9 damage/s for 3 s |
| A wall | H | 18 | Stone across your front for 3.5 s; stops spears, arrows and thrown weaves |
| Step aside | | 10 | 6 m to whichever side you look toward |
| Change places | | 28 | You and the opponent nearest the aim (within 30 m) swap places |
| A flight of arrows | | 14 | Five arrows fanned 16 degrees, 5 each |
| A boulder | | 22 | Slow (22 m/s), 26 damage, a wide hit, knocks down 1.2 s |
| Ravens | | 18 | Three birds fanned wide that turn after the nearest foe, 7 each |
| A cage | | 30 | Like Chains but slower (0.7 s) and held 3 s, and no step gets you out |
| Forgetting | | 16 | After 0.35 s on the one looked at: 35 Will gone, unless they left the spot or Denied |
| A great hand | | 14 | After 0.2 s they are thrown 7 m away |
| Drawn in | | 14 | After 0.2 s they are dragged to your feet (up to 9 m) |
| The ground burns | | 22 | A circle of 3.4 m burns 16/s for 3 s; no mire |
| Lightning from a clear sky | | 26 | A marked circle of 2.4 m is struck once after 0.9 s for 30 |
| A ring of stone | | 24 | Six walls round you (radius 2.6 m) for 3 s |
| A mirror | | 20 | A 4 m pane ahead for 2.5 s: dream-things thrown at it go back, now the mirror-maker's |
| It never happened | | 32 | 30 health back |
| Not quite here | | 20 | 1.4 s untouchable, and no blows, weaves or dream attacks meanwhile |
| Quick as thought | | 16 | 3 s at 1.6 times your speed |

- **The dream bar and inventory** (21 Nov). Eight slots (`tune.bar`, keys `tune.bar_keys`:
  Z X V T Y U H Shift by position), drawn bottom right with a mark for what each does
  and its cost, grey when the Will is short. I opens every ability: click one, then a
  slot (one already on the bar changes places). Kept as `profile.dream_bar`; the slot
  keys can be changed in the camp's Keys panel (`profile.dream_slot_keys`). The bot
  plays from its own bar by kind (`Bot.dream`), so a shade fights with yours.

- Any step frees you from chains, for half as much Will again. A step also drops a
  swing or a forming weave and leaves you unhittable for 0.14 s.
- **Sparring damage.** Arms and weaves are tuned to kill Trollocs, and bots killed each
  other in five seconds with them. In any spar, a blow or weave on another player does
  `TUNE.spar_dmg` (0.35) of its damage and never more than `spar_cap` (7%) of the
  target's health. Dream-things do their full written damage. Bot duels now last
  16 to 100 s.
- **Opponent.** A spar entered alone conjures "Your shade" after 4 s (a bot of the same
  kind as you; since 24 Nov made by the sim, so on the server as well);
  `--foe=warder|aiel|hunter|channeller|mirror` picks one. A duel ends when someone has
  been beaten and one is left standing; a friend still only looking in at the doorway
  (`away`) is waited for, and one who walked off without entering (`looked_only`) has
  not lost. `Sim.won` is true only for the one standing. `Bot.dream`
  plays the moves: Denies or steps from what is coming, steps out of chains, attacks
  when its Will is above 50.
- Snapshot rows carry Will as an eighth number; status bits 131072 (chained) and 262144
  (shaken). The client's unpacking stride in `Session._snap` must match the row length:
  it did not at first, which broke every joined game until the co-op test caught it.
- View: `dreamfx.gd` (pale shell and streak for a step, a shell for Deny, chains,
  spear; arrows, a tumbling boulder, ravens with beating wings (`dreamraven.gd`), a
  cage of bars, burning ground, a storm cloud and its strike, a glass mirror, and
  shells and streaks for fade, haste and mend), `dreampit.gd`, `dreamwall.gd`; the
  world is drained of colour and fogged. The HUD shows Will above health and the
  dream bar at the bottom right.
- Tools: `tests/dream_duel.gd` (two bots duel headless and the fight is counted),
  `--dreamdemo[=move,move]` (the player works through the moves for a render),
  `tools/ghost.sh` presses every dream key.
- Not built: rebinding the dream keys in the camp (`profile.dream_keys` is read if
  present), dream moves against Shadowspawn, the Dreamer Talent, shaping the place.

## Testing
- `tools/test.sh`: rules and progression (`tests/run_tests.gd`: every weapon, every
  defence, holds, enemies, Powers, whole activities played by bots), co-op over
  localhost, and a dedicated server with two rooms, the lobby and the store.
- `tools/ghost.sh`: the controls. `Ghost` feeds real input events on scripted
  frames, the game prints what the sim made of them, and the script checks it.
  It exists because bots drive the sim directly: an error on the input path
  (aiming with a weapon selected) passed every other test.
- `src/test/arms.tscn`, `looks.tscn`: lineups of every weapon and every outfit.
- Renders may run side by side. The invisible compositor is 5120x2880 and
  `tools/place.py` (started by render.sh) moves each new window into a free
  quarter of it. Godot keeps writing frames while sway suspends a window that
  another covers, but its world stops, which is the kind of fault that looks like
  a game bug. Found 18 Nov while chasing the controls test's lost tie. That turned
  out to be something else (the yard burning down to its last post), but
  overlapping windows can do the same.
- When a fight is over, the host still passes on its room's news while anyone
  stays in it (`Session._send_events` on both branches); the sim's clock stops.

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

## Spoilers shared in a fight (18 Nov)
`Settings.story` (per machine; through book 6 unless opened by ten clicks on the camp
menu's title) becomes each character's `book_limit` in the camp and the game. In a
fight `Sim._share_story` takes the lowest limit among the human players and applies
it to everyone; an event `story` (also first in `roster()`) tells each machine, which
drops later weaves from the chart and bar. Talents' books: `Rules.TALENT_BOOK`
(Travelling 12, Unweaving 7, Reading Residues 8, Cloud Dancing 8). Weaves past book 6:
Arrows of Fire, Blossoms of Fire, the Deathgate (11). Heave the Ground is book 1 by
the user's ruling.

## Weave strength (18-19 Nov)
`Rules.scale` multiplies every weave's effect by `TUNE.weave_scale` (0.8): a new
channeller near rank 30 was clearing hordes. 0.7 made the bot channeller lose its
trial watch. The fireball's burst is 1.3 m (was 1.6). Tune further by play.

## Arms added 18 Nov (evening)
Trolloc trips (a low blow, yellow wedge, knocks you down), jumping (V, 0.55 s), getting
up (Space rolls up, guard rises behind it), Sword and round shield (turns arrows while
the guard is held, `guard_held`; heavy blow a shield bash). Bots jump trips, roll up,
and drop a bow draw for the blade within 2.5 m. See MELEE.md.

## Next steps, in order
0. `BACKLOG.md` is the full list of what Josh has asked for; this is only an order.
   Its top section lists well-defined tasks for a lighter model, with briefs.
1. (Fixed 20 Nov, to confirm in play) The doorway world mismatch: the camp's flat
   ground (`Terrain.amp`) leaked into doorway fights; the camp named its own setup.
2. (Fixed 20 Nov) The camp link's lifecycle (errors when the camp leaves the tree).
3. Performance, Windows first: measure, then frame cap, quality setting, cheaper
   doorway views, shadows.
4. Prepared and multiple weaves, and a better weave bar (design with the user).
5. Balance by play: weave_scale, Rolling Ring, health, Healing's cost.
6. (Water and held Balefire built 20 Nov.) The Air wall weave, gateway placement.
7. The super backlog: multi-stage runs; casting by drawing (see VISION.md).

## Maps with edges and heights (24 Nov)
- Every map ends in rock you can see: a corridor (Tarwin's Gap) is closed at both ends by the
  same cliffs as its sides, a round map (the wagon ring, the open fields, the Watch Hill) by a ring
  of hills (`Map.bound_dist` drives both the cliff height and where walking stops, so the stop is
  always at the foot of a slope too steep to go on). The camp has a palisade (`Scenery.palisade`).
- Ledges are data (`ledges` on a map: a rounded block `h` high with an optional `ramp`
  direction), added flat to the ground by `Terrain.dry` so their tops are level and their sides a
  metre-wide cliff. `Map.walk` refuses a step up anything steeper than `STEEP` (1.15) unless it is
  within a jump's reach; the path grid marks those edges, so enemies go round by the ramps.
- Why not physics: the sim stays pure maths shared by server and clients; heights are one function.

## Things that answer the fight (24 Nov)
- `Env` (src/core/env.gd) changes Map's props and walls when weaves land near them and tells the
  view by event; the view keeps each prop in its own node. Late joiners do not yet get that state.
