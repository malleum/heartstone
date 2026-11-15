# Backlog

Everything Josh has asked for that is not finished, in his words where it matters.
The order is free: he said to pick whatever makes sense and to guess when unsure.
Move an item to "Done" with the date when it is built, and say what was assumed in
`PLAYTEST.md`. Items found by looking at the game go at the bottom.

## Josh's hands-on notes, 14 Nov (tour playtest)
His words, lightly tidied. Do all of it, in detail; tick each when built and seen in a render.

**Keys**
- [ ] "Make it work with Dvorak keybinds. I hate having to switch back and forth between
  keyboards." (Movement and every other key should sit where WASD etc. sit physically.)

**Weaves**
- [ ] "Heave the Ground feels and looks lame."
- [ ] "The water starter weave feels exactly like the starter air weave."
- [ ] "I want the cooldown to be a pre-cooldown, not a cooldown proper, to make it feel
  like it takes time to weave up a weave before using it (this will also make sense once
  manually drawing to weave is introduced)."
- [ ] "Cool and different animations for this weaving activation delay, especially with
  sparks of the elements' colours."
- [ ] Big weaves: "same complaints as above."
- [ ] Arrows of Fire: "less bloom and more speed and penetration, like small bullet
  projectiles on fire."
- [ ] Blossoms of Fire: "a 6 ft tall very small pillar of fire (where you aim) and then
  it blossoms out into a 10 to 30 ft radius slow spinning fire tornado (but still
  relatively short for how wide the spinning arms of fire are)."
- [ ] Rolling Ring of Earth and Fire: "should look cooler and be more directed, not a
  full 360. Narrower than 90."
- [ ] Gateway: "I can't test it because the person you gave me wasn't strong enough."
  (Tour character needs the strength for it.)

**The Fade**
- [ ] "The Fade design needs much work. Its running speed is good, but it's weird just
  running around with it following me. It needs some sort of occasional lunge attack, or
  a fade into shadow, disappear and reappear in a different shadow ability."

**Melee: "still needs a good bit of work"**
- [ ] "Trollocs need more precise swing attacks."
- [ ] Parry: "if I hit my parry button (it should do nothing if I just hold it) right
  before their swing hits me, an animation plays blocking it, and if I timed it perfectly
  at the last possible moment they even get shaken and lose a step, like the perfect
  parry in Resident Evil 4 remake."
- [ ] "It's impossible to see thrown knives and where they land, and they are still
  shown in the hand after being thrown and being out of them."
- [ ] "Some of the forms look and feel like the normal two sword attacks."
- [ ] "The sidestep by default plays the forwards roll animation but my character goes
  backward, which just looks wrong."
- [ ] "Drop the Shift+Space keybind: it doesn't feel different from the normal dodge."
- [ ] "Flurry of blows on the knife looks like the normal animation."
- [ ] "The Aiel spear light attack looks really dumb."
- [ ] "Have the attacks show a clear visual hit box of what they are hitting (even if
  slightly bigger than the weapon), in almost a light anime style, so it's clear the path
  I'm swinging at."
- [ ] "Vary knockback/stun frames between different forms and weapons to add variety."
- [ ] "Improve the animations, graphics and physics of the bow, crossbow and sling. Make
  it clear by projectile speed, damage and arc when it is not a fully charged shot. Don't
  even let the crossbow do a light shot. Give the bow more power and speed the longer it
  is charged (with an animation for that). Sling: less warm-up, its rate of fire is fast."

## Combat feel and rules
- [ ] Effects per Power are all built (see Done). Not seen in a render: the
  charge arc between Trollocs, the daze motes, stun sparks, the thrown slide.
- [ ] Trolloc attacks: chop, sweep and thrust exist but are picked at random.
  Wanted: by the weapon carried, and a hit reaction on the player that matches.

## Character and progression
- [ ] Weave tree follow-ups: weaves beyond your book limit are simply absent (no
  hint that more exist); long names can touch a neighbour.
- [ ] Camp follow-ups: other players are not seen in the camp; the doorways show
  a silhouette of the place, not the place itself; the armoury and appearance are
  panels, not things you walk to.
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
- [ ] Enemies still to make: Draghkar, Darkhounds, Darkfriend channellers. Trolloc
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
