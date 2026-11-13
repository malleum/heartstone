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

## Architecture principles
- Data over code: creatures are parameter tables plus a seed; weaves will be data rows.
  Adding a creature or weave should mean adding data, not engine code.
- Lean procedural: generated meshes, textures, synthesized audio where quality holds up.
- Comments say why, not what.

## Git
- Branch is `master` (not `main`). Commit directly and push at natural finishing points.
  No pull requests unless asked. Don't commit large render outputs.
