# Heartstone — kickoff prompt for Claude Code (Fable 5.2)

> Paste everything below into Claude Code, started inside tmux in the project folder on the desktop.

---

## Your task this session

You are starting a new 3D Wheel of Time game called **Heartstone**. This session covers two jobs, in order. Do the full work, iterating and reviewing your own results across multiple attempts, and only then come back with a final report:

1. **Phase 0: Give yourself eyes.** Set up off-screen GPU rendering on this machine so you can run Godot, render frames to PNG, and look at them yourself.
2. **Phase 1: The procedural Trolloc test.** Build procedurally generated Trollocs in Godot 4, with real skeletons and procedural walking, and render them so we can judge whether procedural characters are good enough for this game.

Don't start the full game yet. Phase 1 is a feasibility spike, and its result decides how characters get made for the whole project.

**Ignore `./weaves.md` for now.** It holds the canon weave research and the ability and progression design for future steps. You don't need it this session.

---

## The machine

- My desktop, reached over SSH. There is **no GUI session running**: it sits at the display manager's login screen. You're in a tmux pane in the project folder.
- GPU with **8 GB VRAM**. Decent CPU and RAM.
- It runs NixOS, but that shouldn't matter much beyond the dev setup below.
- I'm on a **Claude Pro plan**, so usage is limited. Work efficiently: don't burn tokens re-reading big files or re-rendering needlessly, but don't cut corners on the iteration this test needs.

## Dev environment: flake.nix

- Use a **`flake.nix`** for the project. It should provide:
  - a **dev shell** (`nix develop`) with everything needed to work on the project: Godot 4, the headless compositor and screenshot tools from Phase 0, and anything else you use;
  - an easy way for **anyone to run the project and see what it looks like**, e.g. `nix run` launching the game or the test scene.
- For your own testing loop you **don't have to go through `nix run`** if it's inefficient. Call Godot and your render script directly from inside the dev shell.

## Phase 0: off-screen rendering (do this first)

You can view image files with your Read tool, so the goal is to get Godot rendering on the real GPU into a display nobody sees, then save frames to disk.

- **Don't use `godot --headless` for anything visual.** It disables rendering, so screenshots come out blank. It's fine for running scripts and tests.
- **Preferred: a headless Wayland compositor that uses the GPU.** For example, sway with `WLR_BACKENDS=headless` (plus `WLR_LIBINPUT_NO_DEVICES=1`) running in its own tmux window, with `WAYLAND_DISPLAY` pointed at it for Godot. Then capture frames either:
  - in Godot: `get_viewport().get_texture().get_image().save_png(path)` from a capture script, or
  - with `grim`, or
  - with Godot's movie writer (`--write-movie out.png --fixed-fps 30 --quit-after N`) for frame sequences: use this to check animation such as walk cycles.
- **Fallback: Xvfb.** It renders on the CPU, so expect it to be slow and limited to Godot's Compatibility renderer. Use it only if the GPU route fails, and tell me if you had to.
- **Confirm it really is the GPU:** check which renderer and adapter Godot prints at startup, and that the Forward+ renderer works.
- Write a tiny reusable script, e.g. `tools/render.sh <scene> <out-dir> [frames]`, so every later session can render with one command.
- Write a minimal **`CLAUDE.md`** for the repo with the project rules from this prompt that future sessions need: the render workflow, flake usage, git branch, and the architecture principles below.

## Phase 1: the procedural Trolloc test

**Why procedural:** I want to know whether characters can be generated in code (mesh, skeleton, procedural animation) rather than bought as asset packs. Trollocs are the ideal test, because canon makes them mismatched beast–human hybrids: boar tusks, wolf snouts, goat horns, hawk beaks, bear-like bulk, some with hooves or paws. Variety from generation is lore-accurate, and slightly-off proportions are fine. My previous game (balefire, below) used a strict "nothing is an asset" rule, with everything generated from tables of numbers, and I like that philosophy, but I'm open to a hybrid if procedural humans turn out bad.

**Build:**
- A **Trolloc generator** in Godot 4 (GDScript unless C# is clearly better; justify the choice). Given a seed and a few parameters, it outputs a skinned mesh on a real `Skeleton3D`: roughly human-shaped, hulking, about 1.5× human mass, with a swappable beast head type (at least boar, wolf, goat/ram, hawk/beak, bear), and variation in height, bulk, posture, limb proportions, and hooves vs feet. Rough black mail or hide armour as a simple procedural layer is a bonus.
- **Procedural locomotion:** a walk and run on the skeleton, driven by code: foot placement with inverse kinematics (feet planted on uneven ground), body sway, a heavy, lumbering gait. A simple procedural idle and a hit-react or stagger would be great. Ragdoll or procedural death is a stretch goal.
- A **test scene:** uneven terrain, decent lighting, a camera at a third-person over-the-shoulder distance, and a **line-up of 8 or more Trollocs from different seeds**. Also a **horde stress test**: 150–250 Trollocs walking toward the camera. Measure the frame rate on this GPU.
- **A human test as well.** Build a procedural human (body, head with adjustable facial features, clothing layers) so the verdict on human player characters rests on evidence, not guesswork. take your time since this will be complicated

**Iterate before reporting. This is the important part.**
- Work in **multiple rounds**: build, render, review critically, fix, render again. Don't come back after the first thing that runs.
- Each round, review your renders as a harsh art director and a technical reviewer would:
  - Silhouettes: do they read as Trollocs at gameplay distance, and do different seeds read as different creatures?
  - Skinning: no tearing, collapsing joints or candy-wrapper twists.
  - Locomotion: no foot sliding, believable weight, feet actually planted on uneven ground.
  - Lighting and materials: good enough to judge the shapes.
  - Performance: horde fps.
- Consider spinning up a fresh-eyed review pass (a subagent that hasn't seen the code) on the renders, so the work isn't only grading itself.
- Keep a short log (`docs/trolloc-test-log.md`) of each round: what changed, what improved, what's still wrong.
- Stop iterating when further rounds stop producing meaningful improvement, or you hit a hard limit of the approach. Then write the final report.

**Final report:**
1. What the generator can do and what it can't yet.
2. The best renders: file paths, with the 5–8 most telling picked out (Trolloc line-up, head close-ups, walk-cycle frames, horde shot, the human test).
3. Horde performance numbers.
4. A summary of the iteration rounds: what got better, and what plateaued.
5. Your honest verdict on whether procedural generation is good enough for (a) Shadowspawn and (b) human player characters with customizable faces and clothing. If not for humans, recommend the hybrid: what to procedurally generate and what to source (e.g. a base human mesh plus procedural clothing and colour).
6. What you would do next.

Then stop and wait for me.

---

## Background: the game (conclusions so far)

### The goal
Insomniac's Spider-Man makes you feel like Spider-Man. Heartstone should make you feel like a **channeller** in the Wheel of Time world (Rand at Dumai's Wells, Egwene holding a line), and eventually also like a Warder, an Aiel warrior, or a Dreamer. The core fantasy came from rereading the **"Vows" chapter of *Knife of Dreams***: a powerful channeller tearing through waves of Trollocs with Arrows of Fire, Blossoms of Fire, Deathgates, lightning and fireballs.

The key insight: Spider-Man's feel comes from thousands of hand-made animations, but **a channeller's feel comes mostly from effects**: glowing flows, fire blossoms bursting, lightning arcing, the ground tearing open, Trolloc lines burning away. That's shaders, particles, light, sound and camera work, all of which code can produce. One good set of casting animations plus excellent weave effects gets a long way. Weave effects and game feel (hit-stop, camera shake, impact, sound) will be first-class work in later phases.

### Scope and structure
- **One connected game, not separate modes.** One character, one progression, a hub (camp), and several mission types sharing the same systems:
  1. **Holdouts:** wave defence on hand-built maps (first map idea: **Tarwin's Gap**; Dumai's Wells-style battles). This gets built first, after this spike: it delivers the core fantasy fastest.
  2. **Linear missions,** Resident Evil 4-style: escorts, defend the gateway, assault a Darkfriend manor, Waygate runs.
  3. **Tel'aran'rhiod (World of Dreams) missions,** later.
  4. **PvP is sparring in Tel'aran'rhiod** between friends, with the same characters and abilities.
- **Not** an open world with lots of quests: big, empty and content-heavy. Small and dense beats big and hollow.
- **Multiplayer:** online co-op for me and 1–5 friends. PvE is the focus.
- **Classes:** Channeller first; Warder, Aiel warrior, and Dreamer later. Each has meaningful choices at creation (including strong visual customization of body, face, hair and clothing by origin) plus meaningful growth while levelling. The detailed design is in `weaves.md`.
- **Spoiler setting:** players pick how far they've read, and content that first appears later is hidden.

### Enemies (for later, but they shape the Trolloc test)
Trollocs (procedural variety, hordes of them), Myrddraal (Fades: eyeless, pale, sinuous, dangerous elites), Draghkar, Darkhounds, and Darkfriend channellers. Keep the Trolloc generator's design open to extension toward Myrddraal and other Shadowspawn.

### Engine: Godot 4 (decided)
It has built-in skeletal animation and blending, navigation meshes for hordes, physics, GPU particles and shaders, and multiplayer, and runs natively on an 8 GB GPU.

### Architecture principles (carried over from balefire, where they worked)
- **Weaves will be data** (relevant later): adding a weave means adding a data row, not engine code. Generators should follow the same idea: creatures defined by parameter tables and seeds.
- **Look at it, don't just test it.** Several balefire bugs were invisible to every test and obvious in one screenshot. Render and look before calling something done.
- **Comments say why, not what.**
- Lean procedural: generated meshes, textures and synthesized audio where quality holds up.

### Git
- This repo uses **`master`**, not `main`.
- It's fine to commit directly to `master` and push at natural finishing points. Don't open pull requests unless I ask.
- Commit Phase 0 setup, the flake, and the Phase 1 rounds as separate, clearly described commits. Don't commit large render outputs: keep them in a gitignored folder, except a small curated set of final screenshots if useful.

---

## Reference: my previous game, balefire

GitHub: `malleum/balefire`. It's a top-down Vampire Survivors-style Wheel of Time roguelite in TypeScript with Phaser, about 38k lines. Its notable features: a deterministic simulation, host-authoritative co-op via a relay, weaves as data rows, and everything procedurally generated from tables of numbers (enemy silhouettes, textures, synthesized sound). Its weaves were mostly invented, so Heartstone uses canon research instead (in `weaves.md`, later). You don't need to clone it for this session.

---

## How I like to work
- Start with a sentence on what you're about to do, then do it. Don't wait for approval on routine steps.
- Ask me before anything destructive, any system-wide config change, or any decision that's expensive to reverse.
- I'm not watching live. Work through all the iteration rounds on your own and give me one comprehensive final report.
