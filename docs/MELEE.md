# Arms: melee, missiles and the classes that use them

The plan and the to-do list for everything that is not channelling. Tick items here
as they are built; `BACKLOG.md` points at this file. Numbers that need Josh's hands
go in `PLAYTEST.md` as usual.

## What it should feel like
A channeller stands back and reshapes the field. Someone with a blade is in it:
reading a Trolloc's shoulder to know whether to duck, step aside or take it on the
steel, and spending breath on every choice. Every action costs **stamina**, the same
deep, slow pool channellers use, and a tired fighter hits softer, exactly as a tired
channeller weaves weaker.

## Rules in one page
- **A weapon is a row** in `data/weapons.json`; **a move is a row** in its `_moves`
  table. Adding a weapon or an attack is adding data.
- **Inputs:** left click attacks (tapping chains through the weapon's light moves;
  holding and releasing gives the heavy move, or draws a bow). Right click holds a
  guard, or readies a throw for weapons that are thrown. Ctrl ducks, and attacking
  from a duck is the low move. Space sidesteps; Shift+Space rolls. F throws the
  weapon in hand if it can be thrown. Number keys change what is in hand.
- **A blow** has a wind-up you can see, a reach, an arc, a height (high, mid, low)
  and a recovery. It lands only on what is inside the reach and arc when it lands.
- **Enemies obey the same rule.** A Trolloc commits to a direction when it starts
  its swing. Step out of the arc and it misses. A sweep is high: duck under it. A
  chop comes down: ducking does nothing, step aside. A thrust is narrow and long.
- **Guard** stops a share of the damage from the front (the weapon decides how
  much) and costs stamina for what it stops. A guard raised just before the blow
  is a **parry**: free, and the attacker staggers. Out of stamina, the guard breaks.
- **Sidestep and roll** make you untouchable for a moment and move you. The roll
  goes further and costs more.
- **Skill** grows per weapon family by use, like weave mastery: faster, harder,
  cheaper. **Might, quickness and endurance** are chosen at creation.
- **Classes.** Warder: best guard, sword forms. Aiel: spears, buckler, knives, bow,
  bare hands; an Aiel will not touch a sword. Hunter of the Horn: anything, a
  little less well, and the only one with thrown knives, staff, crossbow and
  ashandarei to start. **Channellers** may carry one weapon and train it to a low
  ceiling (Asha'man drill the sword), and can sidestep, roll and duck at a higher
  cost.

## To do

### 1. Foundations
- [ ] `data/weapons.json`: weapons and the `_moves` table, with a `_doc`.
- [ ] `Rules`: weapon damage, timing and cost from stats, skill, class and stamina.
- [ ] `Profile`: `cls`, `sex`, stats (might, quickness, endurance), `skills` (xp
      per family), `kit` (what is carried); creation for the martial classes;
      migration for existing characters (class channeller, empty kit).
- [ ] `Sim`: attack state machine (wind-up, strike, recovery, chain window, one
      buffered input), arcs and reach, heights.
- [ ] `Sim`: guard, parry, guard break; sidestep and roll with untouchable frames;
      duck.
- [ ] `Sim`: changing the weapon in hand; ammunition per activity.
- [ ] `Session`: intents for attack, guard, duck, dodge, equip; refusals.
- [ ] `Progression`: skill xp by family from blows and kills; non-channellers skip
      weave study; reports.
- [ ] `Bot`: a fighter that closes, attacks, guards against a swing and steps out.
- [ ] Tests: every weapon's moves resolve; guard, parry, dodge, duck against each
      enemy attack; a martial bot clears the training yard and the watch; co-op
      with a channeller and a fighter together.

### 2. Enemies that can be read
- [ ] Trolloc attacks by weapon: chop (axe, club), sweep (scythe-sword), thrust
      (spear). Each with its own wind-up time, arc, reach and height.
- [ ] The swing commits to a direction; a miss leaves the Trolloc open briefly.
- [ ] `Walker`: a different visible motion for each attack kind.
- [ ] The sim must know which weapon each Trolloc carries (today only the view
      does): choose it in the sim and tell the view.
- [ ] Trollocs that guard against blades and must be broken or flanked.
- [ ] Trolloc archers and javelin throwers, so a shield and a roll matter at range.
- [ ] Myrddraal: fast, parries, black blade that festers (damage over time);
      linked Trollocs die with it.
- [ ] Grabs and shoves that must be broken with a dodge.
- [ ] Hit reactions on the player that match the blow (stagger, knocked back,
      knocked down) and a get-up.

### 3. Weapons
Swords
- [ ] Sword (one hand, the plain soldier's blade)
- [ ] Hand-and-a-half sword (Borderlands)
- [ ] Heron-mark blade (two hands; a blademaster's, earned not chosen)
- [ ] Short sword
- [ ] Sabre (Saldaea; long sweeping cuts)
- [ ] Practice sword of bound lathes (training yard; bruises only)
- [ ] Power-wrought blade (never dulls; a reward)

Knives
- [ ] Belt knife (everyone has one; the weapon of last resort)
- [ ] Aiel long knife
- [ ] Paired daggers
- [ ] Throwing knives, a brace of eight (Mat, Thom, Faile)
- [ ] Knives recovered from the dead and the ground after a throw
- [ ] The ruby-hilted dagger of Shadar Logoth (a cursed reward: deadly, and it
      costs you)

Spears and polearms
- [ ] Aiel short spear with buckler; spare spears carried behind the buckler
- [ ] Aiel javelins and thrown short spears
- [ ] Boar spear (two hands, long, with a crossbar)
- [ ] Pike (very long, slow; holds a line)
- [ ] Halberd
- [ ] Ashandarei (sword-bladed black spear: cuts and thrusts)
- [ ] Lance, once there are horses

Staves
- [ ] Quarterstaff (Two Rivers; fast, sweeps, both ends)
- [ ] Iron-shod staff

Axes, hammers, clubs
- [ ] Half-moon axe with a back spike (Perrin's)
- [ ] Woodsman's axe
- [ ] Throwing axe
- [ ] Smith's hammer; war hammer
- [ ] Mace or cudgel

Bows and missiles
- [ ] Two Rivers longbow (very long range, slow, needs might)
- [ ] Aiel horn bow (short, quick)
- [ ] Horse bow (Saldaea)
- [ ] Crossbow with a crank (flat, hard-hitting, slow to span)
- [ ] Sling (cheap, stuns)
- [ ] Arrow kinds: broadhead, bodkin (through armour), fire arrows lit by a
      channeller's Fire
- [ ] Quiver counts, picking arrows back up

Shields and the off hand
- [ ] Aiel buckler (hide; light; parries well)
- [ ] Round shield; Borderland kite shield
- [ ] Shield bash; dash behind the shield
- [ ] A second weapon in the off hand (sword and knife)

Bare hands
- [ ] Aiel hand-and-foot fighting: strikes, kick, throw
- [ ] Shove and grapple break for everyone

### 4. Moves
- [ ] Light chain per family (cut, back-cut, finishing cut; jab, jab, thrust; and
      so on)
- [ ] Heavy move per family (overhead, lunge, great sweep)
- [ ] Low move per family (leg sweep that knocks down)
- [ ] Running attack; attack out of a roll
- [ ] Thrusts that pass through one body into the next
- [ ] Haft and pommel strikes that stagger
- [ ] Staff spin; spear held to keep them off (set against a charge)
- [ ] Bleeding from cuts, staggers from blunt blows, armour that turns cuts but
      not thrusts
- [ ] **Sword forms** as learned special moves on the bar with cooldowns, in a
      tree like the weave tree: Parting the Silk, The Boar Rushes Down the
      Mountain, Heron Wading in the Rushes, Apple Blossoms in the Wind, The
      Swallow Takes Flight, Arc of the Moon, Lightning of Three Prongs, The
      Kingfisher Takes a Silverback, The Courtier Taps His Fan, Sheathing the
      Sword (take a blow to give a killing one)
- [ ] Aiel forms: the dance of spears; veiling before a kill
- [ ] Finishing blows on downed Trollocs

### 5. Defence
- [ ] Guard, parry, guard break (see Foundations)
- [ ] Sidestep, roll, duck (see Foundations)
- [ ] Jump, for low sweeps
- [ ] Riposte after a parry
- [ ] Deflecting arrows with a shield
- [ ] Getting up from a knockdown: roll away or rise guarding

### 6. Seeing it
- [ ] Add the Universal Animation Library 2 clips (CC0): three sword cuts, heavy
      combo, dash, block, shield, overhand throw, knockback, slide.
- [ ] Weapons in the hand: generated meshes on the hand bone for every family;
      bow in the off hand; buckler on the forearm; sheathed when weaving.
- [ ] A clip (or a stand-in) for every move, timed so the blade lands when the
      sim says it does.
- [ ] Arrows, knives, javelins and stones in flight; stuck in what they hit.
- [ ] Trails on a swinging blade; sparks on a parry; blood or ichor on a hit.
- [ ] Sounds: swing, steel on steel, steel on flesh, bowstring, arrow strike,
      footfall of a roll.
- [ ] Stand-ins to replace with real animation: spear thrust, staff work, bow
      draw, low sweep, two-handed grips, Aiel hand fighting.
- [ ] Camera: a slight pull-in when guarding; lock-on to one enemy (optional).

### 7. HUD and camp
- [ ] Weapons on the bar beside weaves, with a drawn silhouette per family,
      ammunition count, and which is in hand.
- [ ] Guard and stamina feedback: a flash on parry, a crack on guard break.
- [ ] Creation: choose a class; for fighters, spend points on might, quickness,
      endurance and weapon families; choose a kit; looks that fit the class.
- [ ] The sheet shows class, stats, weapon skills and kit.
- [ ] An armoury in the camp (a rack you walk to) to change what you carry.
- [ ] A forms tree beside the weave tree.
- [ ] Controls shown in the camp and on first entering a fight.

### 8. Classes
- [ ] **Warder:** kit of sword, bow, knife. Best guard. Bond to a channeller in
      the party: sense where they are, share stamina, gain when near them. The
      colour-shifting cloak: hard for enemies to target when still. Guarding a
      channeller mid-weave (blows aimed at them are drawn to the Warder).
- [ ] **Aiel:** kit of spears and buckler, long knife, horn bow. Fastest, best
      sidestep, runs longest. No swords. Societies (Maidens, Stone Dogs, Red
      Shields, Thunder Walkers) as a small bonus each. Veil.
- [ ] **Hunter of the Horn:** any weapon; kits from the Two Rivers (longbow,
      staff), the Band of the Red Hand (crossbow, pike, ashandarei), a gleeman's
      knives, a blacksmith's hammer and axe.
- [ ] **Channellers with a weapon:** one weapon, skill ceiling 4 of 10, dodging
      costs more. Asha'man start with a sword; Aes Sedai with a belt knife.
- [ ] Wolfbrother, the Old Blood's memories of battle, a gambler's luck: gifts
      for fighters, as Talents are for channellers.
- [ ] Dreamer (see `VISION.md`), later.

### 9. Balance and progression
- [ ] A fighter and a channeller of equal hours should each feel needed: the
      fighter holds what the channeller cannot afford to have reach them.
- [ ] Skill pacing per family; what each level gives.
- [ ] Renown and activities that suit fighters (hold the breastwork, guard the
      Aes Sedai, a duel in the yard).
- [ ] Sparring between a fighter and a channeller in Tel'aran'rhiod.
- [ ] Wounds that last until Healed, so a Healer matters to fighters.

## Sources for weapons and forms
The names above are from the books (the sword forms from Rand's and Lan's fights,
the ashandarei and thrown knives from Mat, the Aiel kit from the Maidens and the
Stone Dogs, the longbow from the Two Rivers, crossbows from the Band of the Red
Hand). Numbers are the game's own.
