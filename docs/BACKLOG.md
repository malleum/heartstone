# Backlog

Everything Josh has asked for that is not finished, in his words where it matters.
The order is free: he said to pick whatever makes sense and to guess when unsure.
Move an item to "Done" with the date when it is built, and say what was assumed in
`PLAYTEST.md`. Items found by looking at the game go at the bottom.

## Combat feel and rules
- [ ] **Cooldowns on weaves** so a fight is not one button spammed. This also lets
  drawing a weave be faster than waiting, which rewards the drawing skill later.
- [ ] **Each Power does something of its own** so switching weaves is worth it, and
  the effect must be clear and visible:
  - Fire sets things on fire, and can set you on fire if you are too close.
  - Air does less damage but its knockback is good.
  - Water makes them slip and fall.
  - Lightning stuns, or charges them for a second or two.
  - Earth and Spirit: Claude's choice.
- [ ] **Your own fireball should hurt you** if it bursts beside you.
- [ ] **Aim up and down.** Weaves always fly parallel to the ground at present.
- [ ] **Fireball arcs,** so aiming it is a skill.
- [ ] **Knockback must look like being thrown.** Trollocs hit by Air turn round and
  walk a few steps as if they chose to.
- [ ] **Trees need hitboxes** (and anything else solid that has none).
- [ ] **Trollocs swing their weapons** when they attack.
- [ ] **Feet move when you walk while weaving.** They stand still at present.
- [ ] **Varied casting animations:** random per person, but the same every time for
  that person and that weave. Derive it from a seed so nothing extra is stored.

## Character and progression
- [ ] **A skill tree for weaves,** researched one at a time.
- [ ] **More character customisation:** face, body and so on.
- [ ] **More clothing options.** Asha'man need a black coat.
- [ ] **Casting by drawing** a shape after choosing the Powers (see VISION.md).

## Other classes
- [ ] Warder, Aiel and others must be able to fight, with real melee: block,
  several attacks (swing, stab, low sweep), dodge, roll, duck. Channellers can
  learn some of it, less well. All of it uses stamina.

## Online
- [ ] **A server on minimus** (`joshammer.com`, configured in `malleum/nixos`):
  - stores each player's character, so one character grows over time from any
    machine;
  - relays multiplayer so friends on different networks connect without a VPN.
  - This changes Josh's server, which is a system-wide change: build the server
    program and a NixOS module here, and let Josh deploy it.

## Found by looking (Claude)
- [ ] Gateway does nothing in play.
- [ ] Healing has no way to choose who is healed.
- [ ] Other players move in steps (no interpolation) and their chosen look is not
  sent, so they appear in a look picked from their id.
- [ ] Trollocs run straight at the nearest player; the breastwork blocks nothing.
- [ ] No visible flows while a weave forms; no pause on impact.
- [ ] Stamina starts full each activity; it may be better carried between them.

## In progress on branch `wip-combat` (not on master: the bot loses with it)
Written 2026-11-14, tests failing, view not wired. Finish or rework before merging.
- Sim: cooldowns; burn, stun and knockdown from `on_hit`; fireball arc and 3D
  flight; self-damage; tree collisions (`Map.trees`); Trolloc "swing" event.
- Data: cooldowns and effects on every weave; starter weaves Heave the Ground,
  Lash of Water (game choice), Blade of Spirit (game choice).
- Creation: starter weave from strongest Power; half-price first three points in
  the two Powers of your half of the Source.
- Walker: knockdown pose and weapon swing (never rendered or looked at).
- Hero: moving-cast clips and per-person cast gestures (not used by the view yet).
- Still to do there: rebalance so the bot wins the watch and the spar ends; wire
  `game.gd` (aim at chest, projectile height from the snapshot, status visuals,
  cooldowns and strength level on the HUD, swing and knockdown on Trollocs,
  thrown slide, moving-cast clips); render and look; update WEAVES.md.

## Done
