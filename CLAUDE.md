# Heartstone

3D Wheel of Time game in Godot 4 (Forward+), GDScript. Co-op PvE: channellers vs
Shadowspawn hordes. A private game for the user and friends. The vision is in
`docs/VISION.md`; canon weaves, Talents and the strength scale are in `docs/WEAVES.md` (read it when
working on abilities; the user's rulings there are final).

## Dev environment
- `nix develop` gives Godot 4, sway, grim, ffmpeg, imagemagick. `nix run` launches the
  project for anyone (`nix run .#horde` for the horde scene).
- The dev desktop is often used over SSH with no GUI session, and sometimes has a real
  desktop session running. Rendering must never depend on, or appear on, that session.

## Render workflow: look at it, don't just test it
- `tools/render.sh <out-dir> [frames] [-- game args]` renders off-screen on the real GPU
  through a headless sway compositor (auto-started) and writes PNG frames with Godot's
  movie writer at a fixed 30 fps. It re-execs itself inside `nix develop` if needed.
  - `RES=1920x1080`, `KEEP_EVERY=n`, `SCENE=res://...`; `NOMOVIE=1` runs in real time
    (use that for fps measurements; movie mode is not real time).
- Never use `godot --headless` for visuals: it disables rendering. It is fine for
  script-only runs.
- View the PNGs with the Read tool. Use `montage` for contact sheets of walk cycles.
- Render outputs go in `renders/` (gitignored). Curated screenshots live in `docs/img/`.
- Several bugs are invisible to tests and obvious in one screenshot. Render and look
  before calling anything visual done.

## Read first
- `docs/VISION.md`: what the game is meant to be.
- `docs/ARCHITECTURE.md`: decisions and reasons, the asset/licence table, next steps.
  Keep it current when a decision changes.
- `docs/BACKLOG.md`: everything the user has asked for that is not built. Work from it.
- `docs/MELEE.md`: arms (melee, missiles, the fighter classes): the plan, a long
  to-do list with ticks, and what the ticks do not cover. Work from it.
- `docs/SERVER.md`: the dedicated server and character store, and how it is deployed.
- `docs/PLAYTEST.md`: anything that needs the user's hands (camera, timing, hit feel)
  goes here with the assumed value. Never block on the user: assume, note, continue.
- Third-party assets must be CC0/permissive and listed in ARCHITECTURE.md.
- `tools/test.sh` runs the headless rules tests and a localhost co-op session. Run it
  after touching `src/core`, `src/net` or `data/`.

## Code map
- `src/core/`: rules with no nodes (Rules, Profile, Progression, Sim, Bot). `data/*.json`
  holds weaves, enemies, activities, weapons (and their moves). `src/net/session.gd`: host-authoritative co-op;
  `src/net/server.gd`: the dedicated server (`nix run .#server`).
- `src/gen/sdf.gd`: signed-distance "clay" + surface nets mesher; weights, colour, AO.
- `src/gen/species.gd`: creature tables (data). `creature.gd`: skeleton, body, build.
- `src/gen/heads.gd`, `faces.gd`: head recipes. `gear.gd`, `wardrobe.gd`: armour, clothes.
- `src/anim/walker.gd`: procedural gait (planted feet, IK legs, hit-react, death).
- `src/game/`: `camp` (walkable hub with a doorway per activity, main scene), `game`
  (activity view), `hud`, `weavetree`, `glyph` (hand-drawn UI), `weavefx`, `sfx`,
  `launch`. Camp renders: `-- --who=Name --show=tree|menu --stroll=N`. `-- --auto` skips the camp and lets a bot play; add `--fxdemo` to review effects,
  `--name=Bot` to keep off a real character, `--stand` to watch melee,
  `--class=warder|aiel|hunter [--kit=sword,longbow]` for a throwaway fighter.
  For looking at one thing: `--only=weave` (the bot knows nothing else),
  `--demo=weave[:metres]` (woven ahead every 4 s whoever the bot is), `--strength=N`,
  `--spawn=type:n`, `--camyaw=deg --camdist=m --campitch=deg` (swing the bot's camera round it),
  `--log` (prints `BLOW <frame> <move>` so a blow's frames can be found; render with
  `KEEP_EVERY=1`).
  Bench: `--species=myrddraal|draghkar|dreadlord`.
- `src/game/armsfx.gd`: blade streaks, the warning wedge under an enemy's blow, stuck
  missiles. `src/game/keys.gd`: bindings are by key position; hints go through it.
- `src/gen/armoury.gd`: generated weapon models; `Hero.arm` puts one in the hand.
- `src/gen/hero.gd`: player characters (sourced Quaternius models and clips), built by
  `tools/blender/build_heroes.py`. `human_rig.gd`: older generated humans, bench only.
- `tools/bl.py`: run Python in the user's open Blender (full permission granted).
- `src/test/test_scene.gd`: test bench (`TEST=1 tools/render.sh ...`). Modes via `-- --mode=lineup|walk|horde|humans|heroes`
  plus `--n --seed --dist --yaw --speed --hit=<frame> --die=<frame> --bench=<frames>`.
- `tools/ghost.sh` tests the controls end to end: scripted hands (`src/game/ghost.gd`,
  `-- --ghost=arms|weaves|camp`) press real keys and buttons and it checks what the
  game did. Run it after touching input in `game.gd` or `camp.gd`: bots call the sim
  directly and cannot catch input bugs (one was found this way).
- `-- --tour[=N]` (table in `src/game/launch.gd`, rewritten 22 Nov: 80 numbered stations, every
  weave, weapon, form, calling, enemy, dream ability and mode): each a throwaway character in front
  of one thing, the card says what to test; N/B/R to move on, F1 hides the card, nothing saved.
  Add a station when you add something that needs feeling, then `python3 tools/tourdoc.py`
  (writes `docs/TOUR.md`, the numbered list). Station args: `society`, `hkit`, `gift`, `earned`,
  `dreambar`, `fp`, `sex`, plus the usual; spawns without `@m` start 12 m off. `--ally=warder|channeller`
  puts a bot friend beside the player.
- `tools/strokes.sh [weapon:move ...]` (the sword forms, or the named written moves, side by
  side, four moments each; strokes in `ArmPose.STROKES`/`WRITTEN`, by weapon, family, move). Bench:
  `--mode=hound [--speed= --spring=<frame> --die=<frame>]`, `--species=draghkar|dreadlord`,
  `--mode=heroes --strokes` / `--cloaks=<look>`; lineup `--face=0.8 [--turn=deg]` looks the first one in the face. Game: `--spawn=type:n@metres`.
- `tools/views.sh <name> [bench args]` (three views of a bench creature on one sheet)
  and `tools/skirts.sh` (the gowns standing and moving). After replacing a `.glb`, run
  `nix develop -c godot --headless --path . --import` or renders show the old model.
- `tools/weave.sh <id>` (one weave side-on at six moments; `DEMO=<m>` for weaves the bot
  will not choose) and `tools/face.sh <name> [bench args]` (a face, front and three-quarter).
  Weave visuals are built from `src/game/flowfx.gd` (ribbons, fire ball, shell, rock shard).
- Dream duels: `src/core/dream.gd`, `data/dream.json` (24 moves; a dream bar of eight, I for the
  inventory); `--activity=dream_spar --foe=warder`, `--dreamdemo[=move,..]` to stage the moves (all
  24 by default), `tests/dream_duel.gd [-mix]` for bot-versus-bot numbers (`-mix`: random bars).
- Camp doorways are live portals into a preloaded fight (`camp.gd` `_portal`; see ARCHITECTURE
  "Doorways you walk through"). `--offline` skips the server; `--timing` prints where opening
  a fight spends its time. Notices go through `Toast.say`, never text across the screen.
- `tools/poses.sh [warder|aiel|hunter|weaves]`: characters caught mid-blow and mid-weave,
  no HUD (`-- --clean`), sheets in `renders/poses_*.jpg`.
- Pictures: `--clean` (no HUD, notices, blow warnings or hit flash), `--cloak=<Hero.CLOAKS id>`,
  `--demo=weave:12@-28,20@22` (woven in turn at several spots, metres@degrees). The user's
  taste: night (`--activity=holdout@tarwins_night`), capes in the wind, weaves lighting the
  enemies; pick frames by brightness after the cast, not over the whole run.
- `--shape=alt --turn=deg` (the bot's walls round it, gateway far ends flat; turned) and
  `--gate=metres@degrees` (where `--gate` opens its far end); `--walkgate` walks in at the
  near end's front and out of the far end's. `tools/ghost.sh` has a `place` script (T, the
  wheel, a gateway set end by end).
- Camp pictures: `--campos=x,z` stands you there, `--show=none` hides the sheet. Game: `--hideme`
  (your own figure not drawn). `tools/postcards.sh [setup..]` re-renders the doorways' pictures
  (`assets/postcards/`, imported with `godot --headless --import`); rerun after a map changes.
- Flows are seen only by channellers of the weaver's sex (`Weavefx.sees`, `Weavefx.flows`): a
  fighter bot's render shows no weaving. `--sight=all` shows every flow; `--sex=m` makes a
  throwaway channeller a man (women by default), `--allysex=m` the `--ally`.
- Fighters' trees (`weavetree.gd`, pages "weapons"/"forms", columns by weapon kind): the weapon
  tree is `needs` (any one of) / `study` / `skill` on each row of `data/weapons.json`; a fighter
  owns one weapon of each kind (`Rules.gain_weapon` replaces). Between rounds the chosen weapon
  or form is worked out by effort spent fighting (`Progression._study_arms`); skill gates apply
  only in a round (`Rules.skills_count`). Camp: T or the sheet's button; `--show=tree --page=forms`.
- Damage numbers: `hud.gd` `pop()` from the `hit` event (yours, and smaller red for hurts taken).
- Versions: `Updater.VERSION` is the release being made; raise it before pushing a `v*` tag
  (the workflow refuses a tag that does not match). Every build shows it, the server's too;
  camps report theirs to the server, which lists each player's in the lobby.
- The server proves the word first (`Session._challenge` / `_vouch`, on the client's own
  number) before a client sends its proof, profile or character.
- Forms are not on the bar (`known`): `my_forms`, shown for the weapon in hand beside it
  (`hud.gd` `_form_icon`), Z/X/R then Shift+number (`game.gd` `_use_form`). Beams, lashes and
  cones are pitched by the aim (`Sim.aim_pitch`, `_reach_to_ground`, `_at_height`).
- Missile forms (`missile` true on a form; `lit`, `blast`, `burn`, `burn_dps` for a fire arrow): `count` and `spread` (a fan), `pierce`; bow forms
  are fully drawn in their own wind. Ghost scripts can wait on the game: `[frame, "when", flag,
  rows]` with `Ghost.flags` set by game.gd (ready, marked).
- Speed: `-- --perf` prints a line every 2 s (fps, draw calls, triangles, nodes, and the game's
  parts timed by `Perf.add`); `--census` lists what is drawn by kind and owner (game frame 400,
  camp 600). Measure with `NOMOVIE=1 TIMEOUT=35 tools/render.sh ... -- --perf --uncap` and one
  run at a time (a killed render.sh leaves its Godot running). Static scenery is merged with
  `Scenery.bake(node)` (one mesh per material); creature meshes are shared per body with LODs.
- First person: F5 in play (`Settings.first_person`); `--fp` for a run, `--fpout` shows its arm
  poses from outside; bench `--mode=heroes --looks=x --arms=w --pose=ready|weave --kind=blade|pole|fist`.
- `--at=x,z` puts the bot there (pictures of one place, e.g. by a pond); `--demo2=weave:m`
  weaves a second thing 40 frames after each `--demo` (a fireball at a Wall of Water);
  `--quality=0|1|2` renders one picture-quality level without changing the saved one.
  Camera pitch for the bot is negative to look down (`--campitch=-20`).
- Several renders may run at once: `tools/place.py` (started by render.sh) keeps their
  windows apart in the 5120x2880 invisible compositor.
- Work list for a lighter model (well-defined tasks with briefs): top of `docs/BACKLOG.md`.
- `tools/check.sh` syntax-checks all scripts (do this before rendering: a script error
  gives a grey frame). `tools/sheet.sh <dir> <nth> <cols> [crop]` makes a contact sheet.

## Architecture principles
- Data over code: creatures are parameter tables plus a seed; weaves are rows in `data/weaves.json`.
  Adding a creature or weave should mean adding data, not engine code.
- Lean procedural: generated meshes, textures, synthesized audio where quality holds up.
- Comments say why, not what.

## Git
- Releases: push a `v*` tag and GitHub Actions builds Linux and Windows and publishes them
  (`.github/workflows/release.yml`). Installed games update themselves (`updater.gd`: the
  data is embedded in the executable, the release carries the bare executables and
  `build.json`, the game swaps its own executable; never `--main-pack`). The server on
  minimus updates itself from `master` (flake `autoUpdate`). See SERVER.md.
- After every commit that touches game code or data, rebuild and commit `dist/` (the user
  and friends play the standalone against the self-updating server).
- Branch is `master` (not `main`). Commit directly and push at natural finishing points.
  No pull requests unless asked. Don't commit large render outputs.

## Working with the user
- They test on another NixOS machine. Before asking for a hands-on test, run
  `tools/export.sh` and commit `dist/`. Batch a lot of work between test requests.
- They are not watching live. Say what you are about to do, then do it.
- Ask before anything destructive, any system-wide change, or anything expensive to
  reverse.
