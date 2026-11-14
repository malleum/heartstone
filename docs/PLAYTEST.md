# Needs a human to feel it

Claude cannot feel the game. Each item records what was assumed so work could
continue; play it and change the number if it feels wrong. Tick items off here.

| # | What to try | Assumed for now | Where to change it |
|---|---|---|---|
| 1 | Progression pace: does 5 h to a third flow feel earned or grindy? | 3 flows ~5 h, 4 ~20 h, 5 ~40 h (bot-measured, a human casts less often, so likely slower) | `Rules.TUNE.flow_steps` |
| 2 | Weave mastery pace | Max level after roughly 15,000 casts of one weave | `Rules.TUNE.mastery_xp` |
| 3 | Form times (0.4-1.9 s) and half-speed movement while forming | Cast feels deliberate, not sluggish | `data/weaves.json` `form`; `Sim._step_player` |
| 4 | Endurance: can you cast as often as you want to? | 100 pool, 7/s regen, fireball costs 6 | `Rules.TUNE.endurance*`, weave `draw` |
| 5 | Trolloc threat: speed 3.4 m/s vs player 5.2 m/s, 18 damage a hit | Kiting is possible but crowds punish standing still | `data/enemies.json`, `Sim.add_player` |
| 8 | Camera and controls after the 2026-11-13 rework: orbit camera, run where you point, left click weaves, 1-9/wheel/Q,E select, crosshair snaps to the nearest Trolloc | Camera 3.6 m back, 0.6 m right, FOV 70; sensitivity 0.003 rad/px; snap radius 1.4 m. First play (before the rework) found the camera angle and controls bad | `src/game/game.gd` `_process`, `_unhandled_input`, `_aim_point` |
| 9 | Cast feel: enter and shoot clips against form time; does the fireball leave the hand when it should? | Clips are triggered on form start and on release, not synced to hand position | `game.gd` `_on_events`, `data/weaves.json` |
| 10 | Weave effects: fireball trail, explosion (flash, shockwave ring, sparks, rolling fire) and camera shake. Is the shake too much or too little? Still no hit-stop or sound; every weave other than fireball and blasts is a placeholder shape | Shake scales with blast radius over distance, decays in about half a second; fire may read as too white | `src/game/weavefx.gd`, `game.gd` `shake_at` |
| 11 | Player model in motion: jog, cast, hit and death clips on the sourced heroes; turning to face the target on a cast | Looks right in stills; feet are not IK-planted on slopes; no strafe clips exist | `src/gen/hero.gd`, `game.gd` `_draw_actors` |
| 6 | Trolloc walk and run: weight, lumber, arm swing | Looks right in stills and frame sheets only | `src/anim/walker.gd` |
| 7 | Hit-react strength and death fall | Readable in frame sheets; death is a stiff topple | `Walker.hit`, `Walker.compute` |
| 12 | Sound: cast hum and whoosh, explosion, lightning crack, earth rumble, hits. Volume, pitch, whether any of it is harsh | Synthesized from maths; never heard by anyone | `src/game/sfx.gd` |
| 13 | Camp: character creation choices and wording, activity board, returning with Enter, abandoning with F10 | Menu over a 3D backdrop; 20 creation points | `src/game/camp.gd` |
| 14 | Other weave effects (lightning, Riven Earth, Hammer of Air, shield, balefire) once learned | Checked in stills only | `src/game/weavefx.gd` |
| 15 | Wardrobe: do the looks read as their cultures (Asha'man, Aiel, Aes Sedai shawls, Accepted bands, Warder cloak)? How do skirts, cloaks and shawls move when running and casting? | Seen in stills and a few jog frames; the shawl may clip when arms rise to cast | `src/gen/hero.gd` `LOOKS`, `tools/blender/build_heroes.py` |
| 16 | Terrain: Tarwin's Gap lighting, road, grass density, cliffs. Is anything hard to read during a fight, or slow? | 60,000 grass tufts scattered, fps not re-measured with a horde | `shaders/ground.gdshader`, `src/world/scenery.gd` |
| 17 | Strength on Robert Jordan's scale: do the levels read well in the camp and HUD? Is potential 40(28) to 1(+12) (to ++1 for men, at 2 more points) the right spread, and is a Talent at x1.5 power worth 4 points now that it no longer unlocks a weave? | A new character starts near 60 and grows to its potential in about 20 h; default potential (8 points) is 18(6), slightly weaker than before the change | `Rules.TUNE.level_ratio`, `talent_power`, `Profile.potential_level` |
