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
- `tools/check.sh` syntax-checks all scripts (do this before rendering: a script error
  gives a grey frame). `tools/sheet.sh <dir> <nth> <cols> [crop]` makes a contact sheet.

## Architecture principles
- Data over code: creatures are parameter tables plus a seed; weaves are rows in `data/weaves.json`.
  Adding a creature or weave should mean adding data, not engine code.
- Lean procedural: generated meshes, textures, synthesized audio where quality holds up.
- Comments say why, not what.

## Git
- Branch is `master` (not `main`). Commit directly and push at natural finishing points.
  No pull requests unless asked. Don't commit large render outputs.

## Working with the user
- They test on another NixOS machine. Before asking for a hands-on test, run
  `tools/export.sh` and commit `dist/`. Batch a lot of work between test requests.
- They are not watching live. Say what you are about to do, then do it.
- Ask before anything destructive, any system-wide change, or anything expensive to
  reverse.
