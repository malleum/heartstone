# Backlog

Everything Josh has asked for that is not finished, in his words where it matters.
The order is free: he said to pick whatever makes sense and to guess when unsure.
Move an item to "Done" with the date when it is built, and say what was assumed in
`PLAYTEST.md`. Items found by looking at the game go at the bottom.

## Combat feel and rules
- [ ] **Each Power does something of its own:** the first pass is built (see Done).
  Still wanted: lightning that briefly charges and speeds them instead of stunning,
  Spirit with an effect of its own, and every effect made unmistakable on screen.
- [ ] **Knockdown, burning and stun visuals have not been looked at closely.** Only
  the weapon swing and the fireball's flight were checked in renders.
- [ ] Trolloc attacks: one overhead chop for every weapon. Wanted: thrusts for
  spears, sweeps for axes, and a hit reaction on the player that matches.

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

## Done
- 2026-11-14, combat pass (assumed numbers are in PLAYTEST.md items 19-22):
  - **Cooldowns** on every weave, shown beside each weave on the HUD.
  - **Fire burns** (and a burning Trolloc sets you alight when it hits you); **Air
    throws them back** hard for little damage; **Water and Earth knock them down**;
    **Lightning stuns.**
  - **Your own fire hurts you** if it bursts beside you, and sets you burning.
  - **Aim up and down:** weaves leave the hand toward the crosshair in 3D and land
    on real ground. **Fireball arcs**, so long throws need aiming high.
  - **Knockback is a throw:** a hit Trolloc slides back facing the way it was.
  - **Trees are solid** for you, for Trollocs and for weaves.
  - **Trollocs raise and bring down their weapon**, starting 0.4 s before the blow.
  - **Feet jog while you weave on the move.**
  - **Casting gestures vary** by person and weave (five gestures, chosen by a hash
    of the name and the weave).
