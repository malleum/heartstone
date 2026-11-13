# Heartstone

3D Wheel of Time game in Godot 4 (Forward+), GDScript. Co-op PvE: channellers vs
Shadowspawn hordes. Design background is in `prompt.md`; weave/progression design
is in `weaves.md` (only read it when working on abilities).

## Dev environment
- `nix develop` gives Godot 4, sway, grim, ffmpeg, imagemagick. `nix run` launches the
  project for anyone (`nix run .#horde` for the horde scene).
- The dev desktop has no GUI session and is used over SSH.

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
- `docs/ARCHITECTURE.md`: decisions and reasons. Keep it current when a decision changes.
- `docs/PLAYTEST.md`: anything that needs the user's hands (camera, timing, hit feel)
  goes here with the assumed value. Never block on the user: assume, note, continue.
- `docs/ASSETS.md`: every third-party asset and its licence (CC0/permissive only).
- `tools/test.sh` runs the headless rules tests and a localhost co-op session. Run it
  after touching `src/core`, `src/net` or `data/`.

## Code map
- `src/core/`: rules with no nodes (Rules, Profile, Progression, Sim, Bot). `data/*.json`
  holds weaves, enemies, activities. `src/net/session.gd`: host-authoritative co-op.
- `src/gen/sdf.gd`: signed-distance "clay" + surface nets mesher; weights, colour, AO.
- `src/gen/species.gd`: creature tables (data). `creature.gd`: skeleton, body, build.
- `src/gen/heads.gd`, `faces.gd`: head recipes. `gear.gd`, `wardrobe.gd`: armour, clothes.
- `src/anim/walker.gd`: procedural gait (planted feet, IK legs, hit-react, death).
- `src/game/`: the playable view (main scene). `-- --auto` lets a bot play it.
- `src/gen/human_rig.gd`: generated humans on the sourced Quaternius rig and clips.
- `src/test/test_scene.gd`: test bench (`TEST=1 tools/render.sh ...`). Modes via `-- --mode=lineup|walk|horde|humans`
  plus `--n --seed --dist --yaw --speed --hit=<frame> --die=<frame> --bench=<frames>`.
- `tools/check.sh` syntax-checks all scripts (do this before rendering: a script error
  gives a grey frame). `tools/sheet.sh <dir> <nth> <cols> [crop]` makes a contact sheet.
- Findings of the procedural-character spike: `docs/trolloc-test-log.md`.

## Architecture principles
- Data over code: creatures are parameter tables plus a seed; weaves will be data rows.
  Adding a creature or weave should mean adding data, not engine code.
- Lean procedural: generated meshes, textures, synthesized audio where quality holds up.
- Comments say why, not what.

## Git
- Branch is `master` (not `main`). Commit directly and push at natural finishing points.
  No pull requests unless asked. Don't commit large render outputs.
