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
| 8 | **First hands-on play** (`nix run`): camera distance and shoulder offset, mouse sensitivity, aiming at the ground under the crosshair | Camera 4.2 m back, 0.55 m right; sensitivity 0.003 rad/px. Never played by a human: only by the bot | `src/game/game.gd` `_process`, `_unhandled_input` |
| 9 | Cast feel: enter and shoot clips against form time; does the fireball leave the hand when it should? | Clips are triggered on form start and on release, not synced to hand position | `game.gd` `_on_events`, `data/weaves.json` |
| 10 | Weave effects: do blasts feel powerful? No hit-stop, camera shake or sound exists yet | Placeholder glowing spheres with light flashes | `src/game/weavefx.gd` |
| 11 | Human walk/jog/cast clips on generated bodies | Look natural in frame sheets; feet are not yet IK-planted on slopes | `src/gen/human_rig.gd` |
| 6 | Trolloc walk and run: weight, lumber, arm swing | Looks right in stills and frame sheets only | `src/anim/walker.gd` |
| 7 | Hit-react strength and death fall | Readable in frame sheets; death is a stiff topple | `Walker.hit`, `Walker.compute` |
