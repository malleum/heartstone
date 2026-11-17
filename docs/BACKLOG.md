# Backlog

Everything Josh has asked for that is not finished, in his words where it matters.
The order is free: he said to pick whatever makes sense and to guess when unsure.
Move an item to "Done" with the date when it is built, and say what was assumed in
`PLAYTEST.md`. Items found by looking at the game go at the bottom.

## Josh's notes, 15 Nov
- [x] "all the skirts and dresses need something because they don't quite look
  right": the skirt's waist had been cut to shoulder width, so it stood off the body
  like a hoop, and it was a smooth cone. Rebuilt: fitted waist and hips from the
  model's own measurements, waistband and gathers, folds deepening to the hem, the
  inside in shade. PLAYTEST 57.
- [x] "the fade's head doesn't look right at all": the hood was a puffy cap round a
  smiling mannequin face. Now a deep cowl falling onto the shoulders with the face
  set back in it, and a gaunt eyeless face. PLAYTEST 58.

- [x] "give more cloak options for characters": any character can now wear any of
  fourteen cloaks over any dress (plain wools, trimmed, fur-trimmed winter cloak,
  lined in a second colour, worked silk, embroidered vines, gleeman's patches,
  fancloth) or none, at four lengths (calf, knee, waist, shoulder cape). Chosen at
  creation and under Appearance; `Hero.CLOAKS`, `Hero.CLOAK_LENGTHS`; saved in
  `style.cloak` / `style.cloak_len`. It is one cloak shape cut short in the shader:
  no hood up, no different drape. PLAYTEST 59.
- [x] Picked by me ("find something that needs to be worked on"): the gowns' bodice
  was the pack's brown leather whatever the dress, so a novice in white had a leather
  bust and corset. Gowns now recut it in the dress's cloth (`bodice` on a look).
  Two Rivers and Wise One dress keep the leather. PLAYTEST 60.

- [x] "do 2, 3, then 1. save drawing for later" (15 Nov):
  2. Sword forms that look their own: each of the eight has a written hand-and-blade
     path (`ArmPose.STROKES`), two hands on the hilt where the form wants it, and a
     lifted knee for Heron Wading. The legs still come from the pack's clips. PLAYTEST 61.
  3. More Shadowspawn: Darkhounds, a Draghkar, Dreadlords, and an activity that has
     all three (The Wild Hunt). PLAYTEST 62 to 64.
  1. Trolloc attacks by weapon and by situation, with hit reactions. PLAYTEST 65.
  Casting by drawing is kept for later, by his word.

- [x] "research what all the shadow spawn are supposed to look like ... improvements
  and major refactors upon everything other than trollocs" (15 Nov): the table in
  ARCHITECTURE ("What the Shadowspawn are meant to look like") has canon against the
  game for each. Rebuilt: the Myrddraal (body, armour, cloak, sword, hands), the
  Draghkar's face, talons and wing fold, the Darkhound's head, hackles and death.
  Blender was not needed: these are generated in the game's own clay. Left: Draghkar
  teeth, wings that wrap, prints in stone, women Dreadlords. PLAYTEST 67 to 69.

## Josh's hands-on notes, 14 Nov (tour playtest)
His words, lightly tidied, with what was done about each on the night of 14-15 Nov.
A tick means built, tested by rule and seen in a render; it does not mean it feels
right: every one is a question in `PLAYTEST.md` (43 to 54). "To look at again" lines
are what the 4:44 review, or the next session, should pick up.

**Keys**
- [x] "Make it work with Dvorak keybinds. I hate having to switch back and forth between
  keyboards." Every binding is now by the key's position (`physical_keycode`), so the
  hand sits in the same place on any layout; hints name the letter your layout has
  there (`src/game/keys.gd`). Not checked on a real Dvorak board.

**Weaves**
- [x] "Heave the Ground feels and looks lame." A ridge of rock spikes (taller than a
  man mid-line) erupts along 17 m, nearest first, throws them 9 back and puts them
  down 2 s; dust, thuds, shake.
- [x] "The water starter weave feels exactly like the starter air weave." Lash of
  Water is now a whip along a narrow 18 m line that **hauls them in**, knocks them down
  and leaves them **soaked** (slowed 40% for 6 s; lightning hits the soaked 60% harder).
  Hammer of Air stays the wide shove away.
- [x] "I want the cooldown to be a pre-cooldown." No weave has a cooldown. The time is
  in the weaving (0.9 s fireball to 6 s balefire). Hold the button to weave; once whole
  it waits in the hands and goes where you are looking **when you let go** (a tap
  looses it the moment it is whole).
- [x] "Cool and different animations for this weaving activation delay, especially with
  sparks of the elements' colours." Each Power moves its own way (`Weavefx.FormFx`):
  Fire climbs from the feet in a helix, Earth is slow stones lifting, Air fast wide
  rings, Water a figure of eight, Spirit motes falling inward under a halo; a core in
  the weave's colour grows on the hands, then pulses and throws sparks when whole.
- [x] Big weaves: "same complaints as above." Same system; more flows show more threads.
- [x] Arrows of Fire: six thin white-hot darts at 85 m/s, 7 degrees of spread, each
  goes through two bodies; a spit of sparks on impact and no fireball bloom.
- [x] Blossoms of Fire: a 0.6 m pillar for 0.7 s where aimed, then it opens over 1.4 s
  into a low wheel of five flame arms turning at 0.75 rad/s for 5 s, 3 to 9 m radius by
  strength (10 to 30 ft). It burns you too if you stand in it (40%).
  Looked at again from above at 4:44: fuller arms, burnt ground under it and a burning
  rim at its edge; it reads as a wheel now. From a low camera it is still mostly a
  band of flame.
- [x] Rolling Ring: a wedge 34 degrees each side of where it is thrown (68 in all),
  22 m, rock teeth heaving along the front with fire and dust.
- [x] Gateway: the tour's channeller is strength 8 with every book read (`--strength=8`),
  so it can be woven at station 4.

**The Fade**
- [x] Design: taller (2.06 to 2.12 m) and thinner, deep hood, mantle and a long robe,
  black lacquered scale armour in lapping rows. The hood has a soft peak (4:44). The robe is close-cut
  because a wide cloak falls outside the mesh grid; it has no cloak that hangs separately.
- [x] Behaviour: it circles at 6 m, then **lunges** 12 m along a line shown on the
  ground (0.7 s warning; off the line it goes past and is open 1.3 s; it can be
  parried), or closes for one cut and backs off, or **goes into shadow** (untouchable
  1.1 s) and comes out 3.4 m behind you, lunging half a second later.

**Melee**
- [x] "Trollocs need more precise swing attacks." The blow hits exactly the wedge shown
  on the ground from the moment it commits (red: cannot be ducked; orange: can), with
  no extra reach; it no longer runs through you while swinging.
- [x] Parry: a press, not a hold (holding does nothing). Within 0.45 s before the blow
  it is stopped (a block clip plays, sparks); within the last 0.14 s it is **perfect**:
  nothing gets through, they reel 1.6 s and are thrown back a step, a ring of light,
  and your next blow does half again. A parry that meets nothing cannot be retried for
  0.7 s.
- [x] Thrown knives: drawn 2.2x in flight with a pale streak and a small light; where
  they land a gold ring and a thread of light mark them; they stand in a body they hit.
  The hand is empty after a throw (the next comes to hand 0.3 s later) and stays empty
  when they are all thrown; nothing can be struck with a weapon that has been thrown.
- [x] Forms differ: each has its own streak shape and colour and most a body movement
  (two spins for Apple Blossoms and Whirling Staff, one for Heron Wading, a leap for
  the Boar, the Swallow and Hew, a dash for Parting the Silk and Sheathing the Sword).
  Still only seen as small figures; the underlying arm clips are shared between
  several forms (the pack has six sword clips), so the difference is in the streak,
  the colour and what the body does.
- [x] Sidestep: with a direction it is a roll that way, body turned to it; standing
  still it is a step back, facing them (the jog played backwards, leaning away).
- [x] Shift+Space is gone: one dodge (3.6 m, 0.4 s, 0.32 s untouchable).
- [x] Flurry is four separate quick stabs, hand after hand, each with its own streak.
- [x] The Aiel spear: thrusts are made with the spear turned point-forward along the
  arm ("couched" grip), with a lance streak. Seen close up at 4:44: the jab drives the
  arm straight with the spear level along it; the thrust is a deep lunge.
- [x] "A clear visual hit box": every blow leaves a streak the size of what it could
  hit (reach plus a little, the move's arc): level crescents, standing crescents for
  overhead blows, low ones for sweeps, rings, lances for thrusts.
- [x] Knockback and stun vary by weapon (`impact` on each weapon: a hammer staggers 1 s
  and shoves 7, a pike shoves 8, a knife does neither) and by form.
- [x] Bows: a draw pose (bow arm out, string hand back to the cheek), a string that
  bends with an arrow on it, seen on other players too. A half draw is slow, short and
  weak (speed and damage go with the square of the draw). Longbow 1.5 s for 105 at
  88 m/s. Crossbow: no light shot, one click, 135 at 105 m/s, then it spans itself for
  2.6 s. Sling: 0.12 s wind-up. Arrows have a streak and knock back.
  Seen at 4:44: the crossbow points at the ground while it spans and comes level when
  ready. The sling now hangs from the fist with a stone in its pouch and is whirled
  for the length of the throw (the whirl itself was not caught in a frame).

**Added in the 4:44 review (my own judgement, not asked for)**
- Hit reactions scale with what the blow does: a knife barely moves a Trolloc, a
  hammer or a pike throws it back on its heels and it hangs longer.
- The HUD and the weave tree say how long each weave takes to make.
- Right click with a bow, sling or throwing knives says there is nothing to parry with.
- The tour caption sits under the name block in a narrow column instead of over it.
- Render flags `--log` (prints the frame each blow starts) and `--campitch`.

**Known loose ends from that night**
- The dedicated-server test's training-yard client timed out about one run in four (it did again on 15 Nov; the test bot stood still and threw short at posts out of range, so it now walks into range).
  Likely cause found and fixed at 4:44: a practice post could spawn behind a tree where
  fireballs never reached it; posts are now placed with a clear line. Passed since,
  but it was intermittent, so a few more runs are needed to be sure.
- Blade trails use the move's arc from the weapon data, so a streak can be wider than
  the clip's arm movement suggests.

## Combat feel and rules
- [ ] Effects per Power are all built (see Done). Not seen in a render: the
  charge arc between Trollocs, the daze motes, stun sparks, the thrown slide.
- [x] Trolloc attacks (15 Nov): each weapon has its own two blows (scythe-sword
  sweeps and chops, axe chops hard and sweeps, spear thrusts long and shoves with the
  haft, club smashes and shoves), chosen by what is in front of it, and a blow that
  lands unguarded staggers you or throws you back, with a matching hit clip. PLAYTEST 65.

## Character and progression
- [ ] Weave tree follow-ups: weaves beyond your book limit are simply absent (no
  hint that more exist); long names can touch a neighbour.
- [ ] Camp follow-ups: other players are not seen in the camp; the doorways show
  a silhouette of the place, not the place itself; the armoury and appearance are
  panels, not things you walk to.
- [ ] Looks, what is left: the face itself cannot be shaped (the sourced heads
  have no shape keys; only skin, eyes, hair and beard change). Armour is mail
  drawn on cloth, not plate. (The women's bodice is now cloth on gowns, 15 Nov.)
- [ ] **Casting by drawing** a shape after choosing the Powers (see VISION.md).

## Other classes and arms
- [ ] Warder, Aiel and others must be able to fight, with real melee: block,
  several attacks (swing, stab, low sweep), dodge, roll, duck. Channellers can
  learn some of it, less well. All of it uses stamina. Many weapons: knives and
  thrown knives, bows of several kinds, staff, spear, Aiel javelins, swords.
  **The full plan and to-do list is `MELEE.md`.**

## Online
- [ ] **Deploy the server on minimus.** It is built and tested on localhost (see
  Done and `SERVER.md`); adding it to `malleum/nixos` and forwarding UDP 24690 is
  Josh's step, because it changes his server.
- [ ] Server follow-ups: reconnecting after a dropped connection; proof that the
  server is the real one; friends seen walking in the camp.

## Found by looking (Claude)
- [ ] Gateway: the edges do not cut, and nothing uses one yet (a mission could).
- [ ] Healing has a marker and a refusal when nobody is in reach; it has not been
  tried with two people.
- [ ] Movement prediction is built but has only run on one machine, where there
  is no delay to hide. It needs a real connection to judge.
- [x] Darkhounds, Draghkar and Dreadlords (15 Nov): see ARCHITECTURE "More
  Shadowspawn" and PLAYTEST 62 to 64. Not made: Gholam, Grey Men, Forsaken.
- [ ] Trolloc
  archers carry whatever their body was given, not a bow. The Myrddraal has no
  cloak and no fear in its gaze. The wagon ring was lost by a two-bot party.
- [ ] Stamina starts full each activity; it may be better carried between them.

## Done
- 2026-11-14: **polish.** Server: up to eight fights at once in named rooms, a
  list of who is playing what, and the word and passphrases no longer cross the
  network. Co-op: your own movement is predicted. Camp: the doorway posts are
  solid, H hides the sheet, and each doorway shows a silhouette of where it leads.
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
- 2026-11-16, Dreamworld duelling (asked for 15 Nov; first version built, see
  ARCHITECTURE "Duelling in the dream" and PLAYTEST 72-74). Still to do:
  - Rebinding the dream keys in the camp (`profile.dream_keys` is already read).
  - More imagined things (a change of clothes, a sudden pit under a runner, a
    mirror image), and dream moves against Shadowspawn in a dream mission.
  - A duel of real players over the server has passed the co-op test path only as
    far as snapshots; nobody has fought one.
- 2026-11-17, asked by the user:
  - **Key rebinding** for everything, and **choosing what sits in each hotbar slot**
    (1–9, or whatever those keys are remapped to): weaves, weapons, forms.
  - **A bot Warder for Aes Sedai players**, decided per round with the strength roll:
    the chance of having one equals how common your rolled potential is. A
    potential reached 40% of the time gives a 40% chance of a Warder; a top roll
    reached 1% of the time gives 1%. The Warder is middling but definitely useful.
    It offsets men's curve sitting 6 ranks higher. (My reading: "Aes Sedai
    player" means a woman channeller, and "how common" means the share of rolls
    at or above yours, so rarer and stronger means less likely.)
