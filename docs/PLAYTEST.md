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
| 10 | Weave effects: do blasts feel powerful? No hit-stop, camera shake or sound exists yet | Placeholder glowing spheres with light flashes | `src/game/weavefx.gd` |
| 11 | Player model in motion: jog, cast, hit and death clips on the sourced heroes; turning to face the target on a cast | Looks right in stills; feet are not IK-planted on slopes; no strafe clips exist | `src/gen/hero.gd`, `game.gd` `_draw_actors` |
| 6 | Trolloc walk and run: weight, lumber, arm swing | Looks right in stills and frame sheets only | `src/anim/walker.gd` |
| 7 | Hit-react strength and death fall | Readable in frame sheets; death is a stiff topple | `Walker.hit`, `Walker.compute` |
