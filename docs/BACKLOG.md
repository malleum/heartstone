# Backlog

Everything Josh has asked for that is not finished, in his words where it matters.
The order is free: he said to pick whatever makes sense and to guess when unsure.
Move an item to "Done" with the date when it is built, and say what was assumed in
`PLAYTEST.md`. Items found by looking at the game go at the bottom.

## Combat feel and rules
- [ ] Effects per Power are all built (see Done). Not seen in a render: the
  charge arc between Trollocs, the daze motes, stun sparks, the thrown slide.
- [ ] Trolloc attacks: chop, sweep and thrust exist but are picked at random.
  Wanted: by the weapon carried, and a hit reaction on the player that matches.

## Character and progression
- [ ] Weave tree follow-ups: weaves beyond your book limit are simply absent (no
  hint that more exist); long names can touch a neighbour.
- [ ] Camp follow-ups: doorways are not solid; the sheet cannot be hidden; other
  players are not seen in the camp; the doorways show light, not the place.
- [ ] Looks, what is left: the face itself cannot be shaped (the sourced heads
  have no shape keys; only skin, eyes, hair and beard change). Armour is mail
  drawn on cloth, not plate. The women's bodice stays the pack's leather.
- [ ] **Casting by drawing** a shape after choosing the Powers (see VISION.md).

## Other classes and arms
- [ ] Warder, Aiel and others must be able to fight, with real melee: block,
  several attacks (swing, stab, low sweep), dodge, roll, duck. Channellers can
  learn some of it, less well. All of it uses stamina. Many weapons: knives and
  thrown knives, bows of several kinds, staff, spear, Aiel javelins, swords.
  **The full plan and to-do list is `MELEE.md`.**

## Online
- [ ] **Deploy the server on minimus.** It is built and tested on localhost (see
  Done and `SERVER.md`); adding it to `malleum/nixos` and forwarding UDP 24680 is
  Josh's step, because it changes his server.
- [ ] Server follow-ups: rooms for more than one fight at a time, encryption, a
  lobby that shows who is there.

## Found by looking (Claude)
- [ ] Gateway: the edges do not cut, and nothing uses one yet (a mission could).
- [ ] Healing has a marker and a refusal when nobody is in reach; it has not been
  tried with two people.
- [ ] Other players are smoothed but not predicted; over the internet your own
  movement will lag by the round trip. Not tried over a real connection.
- [ ] Enemies still to make: Draghkar, Darkhounds, Darkfriend channellers. Trolloc
  archers carry whatever their body was given, not a bow. The Myrddraal has no
  cloak and no fear in its gaze. The wagon ring was lost by a two-bot party.
- [ ] Stamina starts full each activity; it may be better carried between them.

## Done
- 2026-11-14: **looks.** Hair style and colour, skin, eyes, height, build and a
  beard are chosen at creation and can be changed later (Appearance on the
  sheet), and other players see them. Sixteen more outfits: Cairhienin slashes,
  Tairen striped sleeves, lords' and ladies' silks, Domani, Tinkers, a gleeman's
  patched cloak, mail for armsmen and Shienarans, the Queen's Guard, a Wise One,
  and the Dedicated's sword pin and Asha'man's dragon.
- 2026-11-14: **the rest of the Powers.** Lightning charges what survives it
  (faster, and the next blow arcs to two neighbours); Spirit dazes, and a
  Myrddraal cannot dodge it; a Gateway is two held doorways anyone can walk
  through; Healing needs someone else in reach, shows who, and ends festering.
- 2026-11-14: **enemies that ask questions, and a second map.** Walls are solid
  (the breastwork at Tarwin's Gap, wagons) and stop arrows and low weaves;
  Trollocs find their way round through the gaps. Trolloc archers. A Myrddraal:
  half of what is aimed at it misses, it cannot be knocked down, its wounds
  fester until Healed, and the Trollocs it brought die with it. A new holdout,
  the wagon ring, attacked from every side.
- 2026-11-14: **holding weaves, so flows matter.** Held weaves take up flows and
  cost stamina each second; Bonds of Air (new) holds a Trolloc where it stands;
  a Shield lasts while held; tying off (G) frees the flows for a while and is
  learned at the first watch. The dome, the bonds and the thread back to the
  weaver are drawn, and the HUD shows which flows are in use.
- 2026-11-14: **arms, first pass** (`MELEE.md` has the full list with ticks).
  Warder, Aiel and Hunter of the Horn; 28 weapons; chains, heavy and low blows,
  throwing and shooting; guard, parry, sidestep, roll, duck; Trollocs that chop,
  sweep and thrust along a line you can step out of; weapons in the hand.
- 2026-11-14: **the camp is walked, not a menu.** The right-hand panel is gone:
  each activity is a stone doorway you walk through, and you come back out of
  it. Server, friends and quit are behind Esc.
- 2026-11-14: **the weave tree is drawn** as a wheel of the Five Powers (T in the
  camp), and **the HUD is drawn** (weave glyphs with cooldown clocks, bars,
  crosshair ring, party list, red edges when hurt) instead of lines of text.
- 2026-11-14: **flows you can see.** While a weave forms, one bright thread per
  flow, in its Power's colour, circles the weaver and closes on the hands. **Impact:**
  a struck Trolloc flashes white and hangs for a few frames, and your own hits
  push the view in slightly. Healing is aimed at a friend under the crosshair.
- 2026-11-14: **the server** (`docs/SERVER.md`). A dedicated host friends join by
  address with no VPN, which also keeps characters so one character follows you
  between machines. Camp has a Server panel (address, word, passphrase, play on
  the server, fetch a character). NixOS module `services.heartstone` in the
  flake. Other players now appear in the look they chose, and joining part-way
  through a fight works.
- 2026-11-14: **weave tree.** Every weave lists the weaves you must know first and
  how much channelling it takes to work out. You study one at a time, chosen in
  the camp; any channelling advances it; having seen it woven in an activity
  halves the work; changing your mind loses the progress. The training yard still
  hands over Fireball and Hammer of Air outright.
- 2026-11-14: **long coat** for men, generated like the skirts: the Asha'man black
  coat and a red Andoran coat. Knockdown checked in a render; the water weave now
  sprays blue.
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
