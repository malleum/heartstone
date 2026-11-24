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

## Built so far (2026-11-14)
Ticked below. In short: 28 weapons and 22 moves as data; Warder, Aiel and Hunter
of the Horn can be created and played, and a channeller can carry one weapon;
light chains, heavy and low moves, thrown weapons and bows work; guard, parry,
guard break, sidestep, roll and duck work; Trollocs chop, sweep and thrust along a
line they commit to; weapons show in the hand; the HUD and the camp know about all
of it. Notes on what a tick does not cover:
- **Trolloc attacks follow the weapon carried** (`Sim.ARMS`, by id; the view gives
  the same Trolloc the same weapon): clubs chop, spears thrust or sweep.
- **Forms** are rows in `_forms` in `data/weapons.json`: eight sword forms with
  canon names, two for the spear, one each for staff, axe and knife. A fighter
  studies one at a time by fighting (stamina spent), sees them in the same tree
  screen as weaves (T in the camp), and uses them from the bar on a cooldown.
  What each form does is the game's invention.
- **After a parry** the next blow does half again as much, and so does any blow
  on an enemy that is down.
- **Thrown weapons and most arrows lie where they fell** and are picked up by
  walking over them.
- **The armoury** is a button on the sheet, not yet a rack you walk to.
- **The Warder:** with guard raised within 3.5 m of a channeller, the Warder takes
  blows meant for them; a Warder and a channeller within 15 m both recover
  stamina three times as fast. The cloak and the rest are not built.
- **Two rules were added that the plan did not have,** because without them a
  fighter died in under a minute: at most two enemies press one person at a time
  (`TUNE.gang`), and anyone left unhurt for six seconds slowly recovers health
  (`TUNE.rest_after`). Both apply to channellers too.
- **Animations are stand-ins** where the libraries have nothing: thrusts use a
  sword dash, staves and spears use sword cuts, bows use a pistol pose, the low
  sweep and the kick use a hook punch, the sidestep is a fast roll.
- **Missiles** fly and wound but do not stay stuck in what they hit and cannot be
  picked up; the weapons marked ammunition simply run out for the activity.
- Aiel buckler: it is drawn and it gives the Aiel spear its guard; there is no
  separate shield slot yet.

## To do

### 1. Foundations
- [x] `data/weapons.json`: weapons and the `_moves` table, with a `_doc`.
- [x] `Rules`: weapon damage, timing and cost from stats, skill, class and stamina.
- [x] `Profile`: `cls`, `sex`, stats (might, quickness, endurance), `skills` (xp
      per family), `kit` (what is carried); creation for the martial classes;
      migration for existing characters (class channeller, empty kit).
- [x] `Sim`: attack state machine (wind-up, strike, recovery, chain window, one
      buffered input), arcs and reach, heights.
- [x] `Sim`: guard, parry, guard break; sidestep and roll with untouchable frames;
      duck.
- [x] `Sim`: changing the weapon in hand; ammunition per activity.
- [x] `Session`: intents for attack, guard, duck, dodge, equip; refusals.
- [x] `Progression`: skill xp by family from blows and kills; non-channellers skip
      weave study; reports.
- [x] `Bot`: a fighter that closes, attacks, guards against a swing and steps out.
- [x] Tests: every weapon's moves resolve; guard, parry, dodge, duck against each
      enemy attack; a martial bot clears the training yard and the watch; co-op
      with a channeller and a fighter together.

### 2. Enemies that can be read
- [x] Trolloc attacks by weapon: chop (axe, club), sweep (scythe-sword), thrust
      (spear). Each with its own wind-up time, arc, reach and height.
- [x] The swing commits to a direction; a miss leaves the Trolloc open briefly.
- [x] `Walker`: a different visible motion for each attack kind.
- [x] The sim must know which weapon each Trolloc carries (today only the view
      does): choose it in the sim and tell the view.
- [x] Trollocs that guard against blades and must be broken or flanked (18 Nov: the
      bandleader turns 65% of a blade from the front; a heavy blow or a form breaks it).
- [x] Trolloc archers and javelin throwers, so a shield and a roll matter at range.
- [x] Myrddraal: fast, parries, black blade that festers (damage over time);
      linked Trollocs die with it.
- [x] Grabs that must be broken with a dodge (18 Nov: 12% of unguarded Trolloc hits
      seize you for up to 2 s; Space twists free for 15 breath and staggers it).
- [x] Hit reactions on the player that match the blow (stagger, knocked back,
      knocked down) and a get-up. (18 Nov: Trollocs with a spear or club can trip
      you, a low blow drawn as a yellow wedge; you go down, and Space rolls you up
      and away, guard rises you behind it, or you get up when it wears off. The
      fall is the death clip run fast and the rise the same clip backwards: the
      pack has no get-up.)

### 3. Weapons
Swords
- [x] Sword (one hand, the plain soldier's blade)
- [x] Hand-and-a-half sword (Borderlands)
- [x] Heron-mark blade (two hands; a blademaster's, earned not chosen: 21 Nov, offered after a win only at sword skill 6)
- [x] Short sword
- [x] Sabre (Saldaea; long sweeping cuts)
- [x] Practice sword of bound lathes (training yard; bruises only)
- [x] Power-wrought blade (never dulls; a reward: 21 Nov, renown 60; its blows do not weaken when you tire; pale, faintly shining)

Knives
- [x] Belt knife (everyone has one; the weapon of last resort)
- [x] Aiel long knife
- [x] Paired daggers
- [x] Throwing knives, a brace of eight (Mat, Thom, Faile)
- [x] Knives recovered from the dead and the ground after a throw
- [x] The ruby-hilted dagger of Shadar Logoth (a cursed reward: deadly, and it
      costs you). 21 Nov: renown 30; its wounds bleed three times as much; in your hand
      it drains 1.2 health a second (never below a third) and you do not rest-heal.

Spears and polearms
- [x] Aiel short spear with buckler; spare spears carried behind the buckler
- [x] Aiel javelins and thrown short spears
- [x] Boar spear (two hands, long, with a crossbar)
- [x] Pike (very long, slow; holds a line)
- [x] Halberd
- [x] Ashandarei (sword-bladed black spear: cuts and thrusts)
- [ ] Lance, once there are horses

Staves
- [x] Quarterstaff (Two Rivers; fast, sweeps, both ends)
- [x] Iron-shod staff

Axes, hammers, clubs
- [x] Half-moon axe with a back spike (Perrin's)
- [x] Woodsman's axe
- [x] Throwing axe (18 Nov: three, heavy, short, a hit staggers)
- [x] Smith's hammer; war hammer
- [x] Mace or cudgel

Bows and missiles
- [x] Two Rivers longbow (very long range, slow, needs might)
- [x] Aiel horn bow (short, quick)
- [x] Horse bow (Saldaea)
- [x] Crossbow with a crank (flat, hard-hitting, slow to span)
- [x] Sling (cheap, stuns)
- [~] Arrow kinds (18 Nov: fire arrows, drawn standing by a watch-fire or burning
      grass; they burn what they hit and catch the grass). Broadhead, bodkin: not yet. Was: broadhead, bodkin (through armour), fire arrows lit by a
      channeller's Fire
- [x] Quiver counts, picking arrows back up

Shields and the off hand
- [x] Aiel buckler (hide; light; parries well)
- [~] Round shield (18 Nov: "Sword and round shield", one kit item: guard 0.95,
      a little slower and heavier); Borderland kite shield not made.
- [~] Shield bash (18 Nov: the round shield's heavy blow, a short shove that
      staggers); dash behind the shield not made.
- [x] A second weapon in the off hand (sword and knife): 21 Nov, one kit item like the
      sword and shield: the knife stabs between the cuts (cut, stab, back-cut, stab) and
      helps the guard (0.85).

Bare hands
- [x] Aiel hand-and-foot fighting: strikes, kick, throw
- [~] Grapple break for everyone (Space, 18 Nov); shoving them: not yet

### 4. Moves
- [x] Light chain per family (cut, back-cut, finishing cut; jab, jab, thrust; and
      so on)
- [x] Heavy move per family (overhead, lunge, great sweep)
- [x] Low move per family (leg sweep that knocks down)
- [x] Running attack (20% harder) and attack out of a roll (asked for while rolling
      toward where you aim: it comes out of the roll 30% harder) (18 Nov)
- [x] Thrusts that pass through one body into the next
- [x] Haft and pommel strikes that stagger
- [x] Staff spin (the quarterstaff's heavy); spear set against a charge (18 Nov: stand
      still with a spear and whatever runs onto it from the front meets the point:
      120% of a jab, staggered, stopped; once each every 2 s)
- [~] Bleeding from cuts (18 Nov: an edged blow leaves a fifth of its damage again
      over four seconds); staggers from blunt blows (weapon impact, built); armour
      that turns cuts but not thrusts (18 Nov: the bandleader 30%, the Myrddraal 35%)
- [x] **Sword forms** as learned special moves on the bar with cooldowns, in a
      tree like the weave tree: Parting the Silk, The Boar Rushes Down the
      Mountain, Heron Wading in the Rushes, Apple Blossoms in the Wind, The
      Swallow Takes Flight, Arc of the Moon, Lightning of Three Prongs, The
      Kingfisher Takes a Silverback, The Courtier Taps His Fan, Sheathing the
      Sword (take a blow to give a killing one)
- [x] Aiel forms: the dance of spears (a form, built earlier); veiling before a kill (18 Nov: an Aiel
      is veiled in every fight, face bare in the camp)
- [x] Finishing blows on downed Trollocs

### 5. Defence
- [x] Guard, parry, guard break (see Foundations)
- [x] Sidestep, roll, duck (see Foundations)
- [x] Jump, for low sweeps (18 Nov: V; 0.55 s clear of the ground for 12 breath;
      a trip passes under. Bots jump a trip and roll up at once when tripped.)
- [x] Riposte after a parry
- [x] Deflecting arrows with a shield (18 Nov: a round shield held up turns
      whatever flies at it from the front; the buckler does not)
- [x] Getting up from a knockdown: roll away or rise guarding (18 Nov, above)

### 6. Seeing it
- [x] Add the Universal Animation Library 2 clips (CC0): three sword cuts, heavy
      combo, dash, block, shield, overhand throw, knockback, slide.
- [x] Weapons in the hand: generated meshes on the hand bone for every family;
      bow in the off hand; buckler on the forearm; sheathed when weaving.
- [x] A clip (or a stand-in) for every move, timed so the blade lands when the
      sim says it does.
- [x] Arrows, knives, javelins and stones in flight; stuck in what they hit (armsfx).
- [~] Trails on a swinging blade; sparks on a parry (both built, armsfx); blood or
      ichor on a hit (not built).
- [x] Sounds: swing, steel on steel, steel on flesh, bowstring, arrow strike,
      footfall of a roll.
- [x] Stand-ins to replace with real animation: spear thrust, staff work, bow
      draw, low sweep, two-handed grips, Aiel hand fighting. (21 Nov: written strokes,
      `ArmPose.WRITTEN`, looked up by weapon, then family, then move: two hands on a spear
      (thrust, jab, lunge, butt, low sweep) and on a staff or long hafted blade (cuts both
      ways, overhead, butt, sweep); the Aiel spear one-handed over and under the buckler;
      hand fighting with a lead-hand jab, a rear-hand cross, a front kick (the leg is
      driven too: a key's seventh value is the foot) and a sweeping kick; an archer turns
      side-on to draw. Built over the pack's clips, which still give the legs, as the sword
      forms are. The pack has no spear, staff, bow or kick clips; truly new clips would be
      made in Blender. `tools/strokes.sh weapon:move ...` shows them.)
- [x] (24 Nov) Strokes for every form past the sword's: spear (set, sweep, wall, and the
      dance and the stag from the spear strokes), staff (whirl, door; reeds and rafters from
      the staff strokes), axe (cleave, oak two-handed, hook, round), knife (flurry, slip,
      hamstring, shadows), hand (stone, hip; knuckles from jab and cross). A flurry restarts
      its stroke each blow, alternating with "<form>:b". Bow and thrown forms (24 Nov):
      missile moves with count, spread and pierce.
- [~] Camera: a slight pull-in when guarding (18 Nov, 0.8 m); lock-on to one enemy (optional, not done).

### 7. HUD and camp
- [x] Weapons on the bar beside weaves, with a drawn silhouette per family,
      ammunition count, and which is in hand.
- [x] Guard and stamina feedback: a flash on parry, a crack on guard break.
- [x] Creation: choose a class; for fighters, spend points on might, quickness,
      endurance and weapon families; choose a kit; looks that fit the class.
- [x] The sheet shows class, stats, weapon skills and kit.
- [x] An armoury in the camp (a rack you walk to) to change what you carry.
- [x] A forms tree beside the weave tree.
- [x] Controls shown in the camp and on first entering a fight.

### 8. Classes
- [x] **Warder:** (guarding a channeller and the bond's shared recovery are built;
      21 Nov: the cloak: standing still a second, enemies pass him over for anyone else
      unless he is within 3 m. 21 Nov: the bond is real: each Warder is bonded to one
      channeller on his side (`Sim._bond_all`, one without a Warder first); each senses the
      other on the HUD, through walls (a knot over them, or an arrow at the edge, redder as
      they are hurt, throbbing when struck); the faster recovery is the bonded pair's only;
      when she falls he fights on in fury for 12 s (blows a quarter harder, no tiring),
      and each is told when the other falls.) Kit of sword, bow, knife. Best guard. Bond to a channeller in
      the party: sense where they are, share stamina, gain when near them. The
      colour-shifting cloak: hard for enemies to target when still. Guarding a
      channeller mid-weave (blows aimed at them are drawn to the Warder).
- [x] **Aiel:** kit of spears and buckler, long knife, horn bow. Fastest, best
      sidestep, runs longest. No swords. Societies (Maidens, Stone Dogs, Red
      Shields, Thunder Walkers) as a small bonus each. Veil. (21 Nov: seven societies,
      `Rules.SOCIETIES`, chosen at creation: Far Dareis Mai (women only: faster, cheaper
      dodges), Stone Dogs (standing still, a fifth less from blows), Red Shields (parry
      window a third longer), Thunder Walkers (spears +10%), Knife Hands (knife and hand
      +12%), Water Seekers (breath back a fifth faster), Brothers of the Eagle (horn bow
      drawn a fifth faster). Women take the spear only as Maidens, as in the books.)
- [x] **Hunter of the Horn:** any weapon; kits from the Two Rivers (longbow,
      staff), the Band of the Red Hand (crossbow, pike, ashandarei), a gleeman's
      knives, a blacksmith's hammer and axe. (21 Nov: `Rules.KITS`, a card at creation
      that sets out the three weapons; taken whole, a level in each of their families.)
- [x] **Channellers with a weapon:** one weapon, skill ceiling 4 of 10, dodging
      costs more (built earlier). 21 Nov: from Tar Valon, a man starts with a sword and a
      woman with a belt knife.
- [x] Wolfbrother, the Old Blood's memories of battle, a gambler's luck: gifts
      for fighters, as Talents are for channellers. 21 Nov: one chosen at creation (free):
      Wolfbrother a tenth faster and a sixth harder on Shadowspawn; the Old Blood 8% harder
      blows and skill half again as fast; a gambler's luck turns aside one blow in seven
      and makes one of yours in ten land twice as hard (`Rules.GIFTS`).
- [ ] Dreamer (see `VISION.md`), later.

### 9. Balance and progression
- [ ] A fighter and a channeller of equal hours should each feel needed: the
      fighter holds what the channeller cannot afford to have reach them.
- [ ] Skill pacing per family; what each level gives.
- [~] Renown and activities that suit fighters (hold the breastwork, guard the
      Aes Sedai, a duel in the yard). (21 Nov: Guard the Aes Sedai, a doorway of its own:
      she seals a Waygate for seven minutes and cannot defend herself; enemies go for her
      above anyone; if she goes down it is lost. Bots keep by her. Not done: the duel in
      the yard.)
- [x] Sparring between a fighter and a channeller in Tel'aran'rhiod (dream moves and Will; blows and weaves scaled down between players).
- [x] Wounds that last until Healed (18 Nov: 30% of each hurt is a wound, up to 60%
      of health; rest cannot mend past it; Healing closes it), so a Healer matters.

## The weapon and form trees (23 Nov, user's ask)
- Two trees for fighters, drawn like the weave chart (glyphs, gold lines, a card), as
  columns by weapon kind: plain at the top, finest at the bottom. Camp: T.
- Weapon tree: each weapon row has `needs` (any one of), `study` and `skill`. Lines: short
  sword > sabre > sword > sword and shield / sword and knife > hand-and-a-half > Power-wrought
  / heron-mark (earned); belt knife > paired daggers / Aiel long knife > ruby-hilted dagger;
  boar spear / Aiel spears > halberd > pike > ashandarei; quarterstaff > iron-shod; cudgel >
  hammer > woodsman's axe > half-moon; horse / horn bow > crossbow > longbow; sling /
  throwing knives > javelins > throwing axes.
- One weapon of each kind is owned and carried: a new one replaces the old (study, a win's
  unlock, a round's pick). Old saves keep their best of each kind. Creation offers only the
  first of each line (and the calling's or Hunter kit's own); the armoury only what is owned.
- Forms: 28 now (every melee kind has a tree of 3-8). Bows and thrown weapons have none yet.
- Between rounds the chosen weapon or form is worked out by effort spent fighting, won or
  lost (`Progression._study_arms`); with nothing chosen, the cheapest open form. Skill is
  grown afresh each round, so skill gates apply only inside one; between rounds a form needs
  a weapon of its kind.

## Sources for weapons and forms
The names above are from the books (the sword forms from Rand's and Lan's fights,
the ashandarei and thrown knives from Mat, the Aiel kit from the Maidens and the
Stone Dogs, the longbow from the Two Rivers, crossbows from the Band of the Red
Hand). Numbers are the game's own.

## Changes of 14-15 Nov (Josh's tour notes)
What is written above about guarding, sidestep and roll is superseded:
- **Parry** is a press (right click), not a held guard: 0.45 s window, perfect in
  the last 0.14 s. A Warder's ward is a parry made beside the channeller.
- **One dodge** (Space): a roll the way you move, a step back when standing.
- **Blade streaks** show each blow's path; a **wedge on the ground** shows where an
  enemy's blow will land. Forms have their own streak, colour, spin or leap
  (`trail`, `tint`, `spin`, `leap`, `repeat`, `grip` on a move).
- Weapons have an `impact` (push, stagger). Spear thrusts use a couched grip.
- Bows are drawn with a pose and a bending string; the host counts the draw.
  Crossbows have no half shot and span themselves. A thrown weapon is gone from
  the hand until picked up.
The details and numbers are in BACKLOG.md (top section) and PLAYTEST.md 47 to 53.
