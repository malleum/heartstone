# Weaves, Talents and strength

The canon reference the game's rules are built from. Josh's research document of
13 Nov 2026 is the source and is treated as true; this file is that research plus
his later rulings, with the game's own choices marked. The rows the game actually
has are in `data/weaves.json`; how the rules use them is in `ARCHITECTURE.md`.

## How to read the tables
- **Canon:** flows stated in a book passage, cited by book and chapter.
- **Wiki:** flows from a wiki or compiler with no chapter cite, or the compiler's inference.
- **Game choice:** our pick where canon is silent.
- **Your lookup:** from Josh's own reading; passage not yet found to cite.
- **Book** is the earliest book with a citation (NS = New Spring = 0, a dash = none).
  It drives the spoiler setting, so it errs early only when Josh has said so.
- Weaves in **bold** are in the game today.

## The One Power in canon
- **Lean by sex:** men tend to be stronger in Earth and Fire, women in Air and Water;
  Spirit is even. It is a lean, not a rule: someone strong in Air may be all but
  unable to weave Fire, and Egwene is strong in Fire, Earth and Spirit.
- **Flows move and change the five elements;** they do not make them from nothing.
- **Holding several flows is hard:** two is far more than twice as hard as one. Few
  Aes Sedai hold more than three; Rand manages ten or more. This is the game's
  levelling curve, and a four- or five-Power weave is meant to wait until a
  character can hold four or five flows.
- **Tie off, invert, reverse:** tying off is common. Inverting hides a finished weave
  from other channellers and is rare. Reversing hides it while it is woven, and only
  the Forsaken seem to know it.
- **Cutting:** you can cut another channeller's weave only if you are stronger. A
  circle gets around that.
- **Linking:** women can start a link and men cannot. Thirteen women can link
  without a man, circles go up to seventy-two, and only the leader channels.
- **Some weaves differ by sex.** Gateways: women use Spirit to make two places
  alike; men use Spirit and Fire to bore a hole through the Pattern. Simple Healing:
  Spirit, Water and Air for women; Spirit, Fire and Earth for men (the men's flows
  are the Depository's inference).

## Strength: Robert Jordan's scale
The game shows and gates strength on the scale from *The Wheel of Time Companion*.
- **72 levels, 1 the strongest.** Men and women share them: the weakest man and the
  weakest woman are about equal.
- **Six men's levels above 1,** written ++6 (just above the strongest woman) up to
  ++1 (Rand, Lews Therin, Ishamael, Rahvin). Logain and Demandred are ++2.
- **The number in brackets is the older White Tower scale,** which ran 1 to 60 before
  Nynaeve, Egwene and Elayne forced twelve levels to be added on top. So 13(1) was
  the old ceiling (Moiraine, Siuan as Amyrlin, Elaida), and levels above it read
  12(+1) to 1(+12).
- **Women match men at the top anyway:** bulk strength is not the whole of it, and
  women are deft enough with the flows that the strongest woman can face the
  strongest man.

| Level | Who |
| --- | --- |
| ++1 | Rand, Lews Therin, Ishamael/Moridin, Rahvin |
| ++2 | Logain, Demandred, Sammael, Aginor |
| 1(+12) | Lanfear, Alivia, Semirhage |
| 3(+10) | Nynaeve at her potential (she starts at 9(+4)) |
| 5(+8) | Cadsuane |
| 8(+5) | Egwene; Elayne at her potential |
| 11(+2) | Aviendha |
| 13(1) | Moiraine before the Finn, Siuan as Amyrlin, Elaida, Romanda, Lelaine |
| 17(5) | Verin, Alanna |
| 19(7) | **Weakest who can open a gateway to walk through** |
| 35(23) | Siuan after being Healed |
| 57(45) | Sorilea |
| 66(54) | Moiraine after the Finn |
| 72(60) | Morgase |

**Travelling.** A gateway you can walk through needs **19(7)** or stronger, assuming
ordinary Talent for it (the Fandom wiki's reading of the Companion, which is Josh's
figure). The weakest channellers seen doing it in the books are about 22(10).
Below the minimum the weave forms and does nothing: Sorilea can show Cadsuane the
weave and cannot use it. Two things clear the gate: the **Talent for Travelling**
(Androl, among the weakest at the Black Tower, opens gateways a cart can pass) and
**linking**. Skimming is the same weave with a known destination, so it shares the
flows and the gate.
- Sources disagree by a level or two. Reactor's chart of the Companion marks the
  threshold beside 20(8) and 21(9), and a summary of the Thirteenth Depository's
  copy gives 16(4) and 23(11) as further gateway tiers and 31(19) as the level below
  which no gateway forms at all. The Fandom page could not be fetched by a tool, so
  19(7) has not been re-read at the source. If the Companion is to hand, check it.

**In the game** strength is stored as a magnitude and shown as a level: level 1 is
100 and each level down divides by 1.05 (Josh, 17 Nov; it was 1.033), so ++1 is about
134 and level 26 about 30. Those magnitudes are the game's invention; the Companion
gives ranks, not ratios. Power sets damage, healing and shields directly, and size,
reach and the length of burns, stuns and holds by its square root.

**Affinity** (Josh, 17 Nov): 0.1 a point (was 0.06), up to 1.4 per Power. A weave's
affinity is the average over its flows; it multiplies power by (0.5 + that), and also
quickens the weaving: ordinary (0.5) weaves at the written speed, strong ones in as
little as half the time, weak ones up to 20% slower.

**Growth (Josh's rulings).**
- **Strong before trained.** A channeller starts at most ten levels below their
  potential, as Nynaeve was already strong as a wilder (9(+4) against a potential
  of 3(+10)).
- **Women rise steadily, men in leaps.** The same practice earns the same total
  gain, but a woman passes through every level on the way and a man stays where he
  is and then jumps several at once.

**Stamina, not mana (Josh's design).** There is no pool that refills in seconds.
Stamina is deep and recovers very slowly. As it falls, every weave is weaker and
also cheaper, so a tired channeller can keep weaving small for a long time, and
past a point no longer has the strength for gated weaves such as a gateway. This
matches the books: channellers fight for hours, tire by degrees, and the exhausted
cannot make the weaves they could that morning.

## Weave tables

### Combat

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| **Fireball** | Fire | Thrown ball of fire; the textbook single-Power weave. | Fandom: Five Powers (flows); seen from book 1 | 1 | Wiki |
| **Lightning** | Fire + Air | Called lightning (Earth-lightning is a variant, flows unstated). | TFoH, To Caemlyn | 5 | Canon |
| Explosive lightning storm | Air + Water + Fire | Rand's storm of exploding lightning. | TPoD, A Time for Iron | 8 | Canon |
| **Arrows of Fire** | Earth + Fire | Superheated filaments from the fingertips. | KoD, Vows; Fandom | 11 | Canon |
| **Blossoms of Fire** | Earth + Air + Fire | Bursting flowers of fire; area damage. | KoD, Vows | 11 | Canon |
| **Deathgates** | Spirit + Fire + Earth | Rolling gateways that kill whatever they pass through. | KoD ch.19 / Vows | 11 | Canon |
| Exploding / pulverising | Fire + Earth | Blow objects apart or grind them to dust. | LoC, Lessons and Teachers | 6 | Canon |
| **Rolling ring of earth** | Earth + Fire | The earth wave that broke the Shaido at Dumai's Wells. | Depository (no chapter) | 6 | Wiki |
| **Heave the ground** | Earth | Earth threads driven down to throw the ground up. | AMoL, What Must Be Done; Moiraine heaves the ground against Trollocs in TEotW (user's ruling, 18 Nov: book 1 for the spoiler limit) | 1 | Canon |
| Red filaments & balls of fire | Fire + Air | Burning threads and fireballs. | TPoD, A Cup of Sleep | 8 | Canon |
| Weapons of Air | Air | Hardened Air to hit, cut, stab or slice. | ToM, Gateways | 13 | Canon |
| Bind / lift with Air | Air | Restrain, lift, carry; strength-limited. | LoC, Summoned in Haste | 6 | Canon |
| Rip / cut with Air & Fire | Fire + Air | Tearing a Myrddraal's head off; cutting clothes away. | Depository (no chapter) | — | Wiki |
| Pain | Spirit + Fire | Complex weave that inflicts agony. | ACoS; LoC, Threads Woven of Shadow | 6 | Canon |
| Killing weave | Fire + Earth + Water | Chesmal's quick kill. | KoD, House on Full Moon Street | 11 | Canon |
| **Balefire** | Fire + Earth + Water + Air + Spirit | Burns threads out of the Pattern; stronger balefire reaches further back. Fire + Air are from the books and more flows are implied; all five is our pick, mirroring the Flame of Tar Valon. | TGS ch.47 (your reading); ACoS, A Crown of Swords | 3 | Game choice |
| Flame of Tar Valon | Fire + Earth + Water + Air + Spirit | Balefire's opposite; creation and locking threads in place. | AMoL, one of the final chapters | 14 | Canon |

### Defence & control

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| **Shield (from the Source)** | Spirit | Cut a channeller off; can be tied. | TDR ch.54 | 3 | Canon |
| Severing | Spirit | A shield with a knife edge severs instead. | TSR, Into the Palace | 4 | Canon |
| **Dome of Air** | Air | Shelter from arrows and missiles. | LoC, Dumai's Wells | 6 | Canon |
| **Bonds of Air** | Air | Wrap and hold someone where they stand. | used throughout, from TEotW on (Moiraine); not in Josh's document | 1 | Canon (added by Claude) |
| Shield against lightning | Fire + Air | Barrier that turns lightning. | TFoH, To Caemlyn | 5 | Canon |
| Airtight barrier | Air + Fire + Earth | Keeps out anything short of balefire. | TPoD, A Cup of Sleep | 8 | Canon |
| Barrier against men | Spirit + Fire | Feels like a wall of flame to male channellers. | TFoH, Pale Shadows | 5 | Canon |
| Stop lightning / scatter clouds | Air + Fire + Water + Earth | Counter-weather. | KoD, Siege | 11 | Canon |
| Cushion of Air | Air | Breaks a fall. | AMoL, Not a Mistake to Ignore | 14 | Canon |
| Cut a weave (Fire) | Fire | Pure Fire cut; you must be stronger than the caster. | WH, Ideas of Importance | 9 | Canon |
| Cut a weave (Spirit) | Spirit + Fire + Earth | Rand cutting Lanfear's weave. | TFoH ch.52 | 5 | Canon |
| Cut a weave (Air) | Air + Fire | Cut and form barriers. | NS, When to Surrender | NS | Canon |
| Folded Light | Fire + Air | Bends light around you: invisibility. | TPoD, A Cup of Sleep | 8 | Canon |
| Illusion / Mirror of Mists | Air + Fire | Disguise a person or object. | TSR, Into the Palace | 4 | Canon |
| Mask the ability | Spirit | Hide that you can channel. | LoC, Weaves of the Power | 6 | Canon |
| Ward against eavesdropping | Fire + Air | Fire and Air with traces of Water. | KoD, The New Follower | 11 | Canon |
| Alarm ward | Spirit | Inverted wards warn of intruders. | NS, Pond Water; ToM, A Vow | NS | Canon |
| False trail | Air + Earth + Spirit | Moiraine fools Trollocs and Fades. | TEotW ch.18 | 1 | Canon |

### Movement

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| **Travelling: gateway (saidar)** | Spirit | Make two places alike; a gateway opens. Needs 19(7) or stronger without the Talent. | LoC ch.34 | 6 | Canon |
| **Travelling: gateway (saidin)** | Spirit + Fire | Bend the Pattern and bore a hole. Needs 19(7) or stronger without the Talent. | KoD ch.21 (flows); Rand Travels from LoC | 6 | Canon |
| Skimming (saidar) | Spirit | Gateway onto a platform in the void, to a known destination. Same flows and strength gate as Travelling. | Same flows as Travelling (your lookup) | 4 | Your lookup |
| Skimming (saidin) | Spirit + Fire | As above, men's version. | Same flows as Travelling (your lookup) | 4 | Your lookup |
| Bridge | Air + Fire | No weight limit; ~20 paces for men, longer for women. | ACoS, Ta'veren | 7 | Canon |
| Walking platforms of Air | Air | Stand or walk on hardened Air. | Depository (no chapter) | — | Wiki |

### Healing & support

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| **Simple Healing (saidar)** | Spirit + Water + Air | Battlefield Healing; draws on the patient. | TDR ch.15 | 3 | Canon |
| **Simple Healing (saidin)** | Spirit + Fire + Earth | Rough and hot; flows are the Depository's guess. | TPoD (flows inferred) | 8 | Wiki |
| Complex Healing | Fire + Earth + Water + Air + Spirit | Different weave per wound. | TFoH ch.35 | 5 | Canon |
| Healing stilling | Spirit + Fire | Bridge the cut. | LoC ch.29 | 6 | Canon |
| Delving | Spirit + Water + Air | Examine someone's health. | NS ch.2 | NS | Canon |
| Warder bond | Spirit | Requires touching the Warder. | NS, Epilogue | NS | Canon |
| Finder | Spirit | Track a marked person or item. | KoD ch.16 | 11 | Canon |
| Compulsion | Spirit + Water + Air | Spirit streaked with Water and Air. | TSR, Into the Palace | 4 | Canon |
| Cloud Dancing | Air + Water + Spirit | Weather. | Tar Valon Library | — | Wiki |
| Globe of light | Fire + Air | Light source. | LoC, Letters | 6 | Canon |
| Signal flare | Fire + Spirit | Aviendha's signal into the sky. | AMoL, At the Edge of Time | 14 | Canon |
| Column of light | Air + Fire + Water | A pillar of light into the sky. | AMoL, To Feel Wasted | 14 | Canon |
| Wind & clouds | Air + Water | Form clouds, move wind. | LoC, Prologue | 6 | Canon |
| Ice from the air | Water + Fire | Draw ice out of the air. | Depository (no chapter) | — | Wiki |
| Smother fire | Earth + Air | Put out fires. | TGS, The Death of Adrin | 12 | Canon |
| Caressing the Child | Spirit + Fire + Earth | Wise One weave. | CoT ch.14 | 10 | Canon |
| Make cuendillar | Earth + Fire + Air | Earth/Fire/Air net, then Earth + Fire. | CoT, Secrets | 10 | Canon |


## Rulings on disputed weaves
- **Balefire: all five Powers (game choice).** Two passages give Fire and Air plus
  more. In *The Gathering Storm* ch. 47 Rand weaves Fire and Air before balefire is
  ready to loose on Tam; in *A Crown of Swords* ("A Crown of Swords") he begins
  balefire, changes his mind and lets "every flow but Fire and Air fall away", so at
  least one more flow is in it. All five mirrors its opposite, the Flame of Tar
  Valon. One caution for a reread: Rand also throws Tam down with Air in that scene.
- **Gateways:** Spirit for women (Egwene, *Lord of Chaos* ch. 34), Spirit and Fire
  for men (Rand, *Knife of Dreams* ch. 21). "Earth, Fire, Spirit" Travelling comes
  from a homebrew D&D list, not the books.
- **Well grounded:** Arrows of Fire, Blossoms of Fire and Deathgates all have stated
  flows in *Knife of Dreams*, "Vows", and two compilers agree on each.
- **Names without flows:** the Fandom wiki's weave list is the longest but gives
  names only (Riven Earth, Protective Whirlwind, Making Fog, Spinning Earthfire).
  Role-play sites invent their own flows and are ignored.

## Game choices outside the tables
- **Hammer of Air** (Air): a short cone that knocks Trollocs back. The name is ours;
  it stands on Weapons of Air and Bind / lift with Air. Kept as the one cheap Air
  attack.
- **Dome of Air** is the game's held barrier (it was "Shield of Air" before).
- **Bonds of Air** was not in the document Josh sent. Binding with flows of Air is
  everywhere in the books, and the game needed a second weave worth holding, so
  it was added. Remove it if it should not be there.

### Holding and tying off (game choice, on canon rules)
- **A held weave lasts while you hold it.** It takes up its flows, and costs a
  little of its draw every second. Weaving it again lets it go. Dome of Air,
  Bonds of Air and the Shield from the Source are held.
- **This is what more flows are for.** With two flows you can hold a dome and
  throw fire, or hold bonds and throw fire, but not both and attack; with three
  you can.
- **Bonds of Air** hold one body each. A Trolloc stays held until you let go; a
  bandleader strains free after some seconds; another channeller can be held too.
- **A Shield** now lasts as long as it is held (it used to last four seconds),
  and a strong enough channeller forces it in time.
- **Tying off** is a technique: the weave holds itself for a while (25 seconds,
  longer with mastery of that weave) and your flows are free again. You cannot
  adjust or release a tied weave. It is learned by clearing the first watch at
  Tarwin's Gap. Key: G with the weave chosen.
- Everything you hold is lost if you run out of stamina, or die.
- **Lash of Water** (Water) and **Blade of Spirit** (Spirit) are ours. The tables
  have no single-Power attack in Water or Spirit, and every character starts with
  the simplest weave of their strongest Power, so those two Powers needed one.
  Blade of Spirit borrows from Severing's "knife edge". Replace them if a canon
  weave turns up.
- **Starting weaves:** Fire Fireball, Air Hammer of Air, Earth Heave the Ground,
  Water Lash of Water, Spirit Blade of Spirit. The one you start with ignores the
  spoiler setting (Heave the Ground is cited to book 14).

### The weave tree (game choice)
Study one weave at a time; channelling anything works it out, and having seen it
woven halves the work. "Work" is in the game's draw units: a bot channels about
12,000 an hour.

| Weave | Needs first | Work |
| --- | --- | --- |
| Fireball, Hammer of Air, Heave the Ground, Lash of Water, Blade of Spirit | nothing | 2,500 each |
| Dome of Air | Hammer of Air | 6,000 |
| Bonds of Air | Hammer of Air | 5,000 |
| Arrows of Fire | Fireball, Heave the Ground | 6,000 |
| Healing | Lash of Water, Blade of Spirit | 8,000 |
| Lightning | Fireball, Hammer of Air | 10,000 |
| Shield from the Source | Blade of Spirit | 10,000 |
| Rolling Ring | Heave the Ground, Fireball | 20,000 |
| Blossoms of Fire | Arrows of Fire, Hammer of Air | 30,000 |
| Gateway | Shield from the Source | 40,000 |
| Deathgate | Gateway, Arrows of Fire | 80,000 |
| Balefire | Lightning, Blossoms of Fire, Healing | 250,000 |

### What each Power does to those it strikes (game choice)
| Power | Effect | Weaves |
| --- | --- | --- |
| Fire | Burns for a few seconds; a blast beside you burns you too | Fireball, Arrows of Fire, Blossoms of Fire |
| Air | Little damage, a long throw backwards | Hammer of Air |
| Water | Knocks them off their feet for over two seconds | Lash of Water |
| Earth | Knocks them down briefly | Heave the Ground, Rolling Ring |
| Lightning (Fire + Air) | A short stun, then what survives is charged: it runs half again as fast for five seconds, and the next blow on it sends the charge leaping to its two nearest neighbours | Lightning |
| Spirit | Dazes: no attack and no pursuit for three seconds. A Myrddraal cannot step aside from it | Blade of Spirit |

### Gateway and Healing in play (game choice, on canon rules)
- **A gateway** is held like a dome: two doorways, one a step in front of you and
  one where you aimed (up to 70 paces). Whoever walks into either comes out of
  the other, friend or Shadowspawn. Weaving it again closes it; it can be tied
  off. It still needs strength 19(7) or the Talent.
- **Healing** must reach someone else: with nobody in reach of where you aim it
  is refused before it costs anything. A ring marks who it will reach. It ends a
  Myrddraal's festering wound.
- **Riven Earth and Making Fog were removed** (Josh, 2026-11-14): Fandom names with
  no flows, already covered by Heave the ground and Wind & clouds.

## Talents
Innate, so chosen at creation only (one or two; each costs points that could have
bought potential). **A Talent never unlocks a weave.** Anyone can learn Healing,
Travelling, Delving, Illusion or the weather weave; the Talent makes theirs far
better and, for Travelling, removes the strength gate.

| Talent | In-game effect (proposal) | Canon note |
| --- | --- | --- |
| Talent for Healing | Anyone can learn simple Healing (Spirit + Water + Air). The Talent makes you far better: stronger, cheaper heals and access to complex five-Power Healing. Never works on yourself. | Most common major Talent, but great skill is rare; you can't Heal yourself. |
| Talent for Travelling | Gateways and Skimming at any strength, much larger than your strength would allow, opened faster. Without it, Travelling and Skimming are ordinary weaves gated at 19(7) or stronger. | Androl: one of the weakest at the Black Tower, yet makes gateways big enough for a cart. |
| Talent for Cloud Dancing | Anyone who learns the weather weave (Air + Water + Spirit) can nudge local weather. The Talent makes you far better at it: bigger areas, faster changes, cheaper to hold. Rain douses fire, storms boost lightning, fog gives cover. | Air + Water + Spirit. |
| Talent for Delving | Anyone who learns Delving (Spirit + Water + Air) can read a person's health. The Talent makes it deeper and faster: reveals hidden wounds, poisons and Compulsion, and senses ore and metal in the earth. | Delving is a standard weave; Egwene's affinity for metals is the ore-finding side. |
| Earth-singing / metals affinity | Cheaper, stronger Earth; quakes and terrain. | Egwene has an affinity for metals. |
| Making cuendillar | Craft unbreakable gear or barricades. | Needs strength in Earth; Earth, Fire and Air net. |
| Making ter'angreal | Crafting system (Elayne). | Very rare. |
| Talent for Illusion | Anyone who learns the Illusion weave (Air + Fire) can cast it. The Talent makes yours far better: convincing up close, more detailed, cheaper to hold, so it works for decoys, disguises and ambushes where an ordinary one would be spotted. | Ordinary Illusion convinces at a distance but must be subtle up close; some channellers are exceptionally good at it. |
| Reading residues | See and track past weaves, follow an enemy's gateway. | Passive; gateway residue readable two days later. |
| Reading weaves | See what an enemy weave will do before it finishes: a counter/parry window. | Very rare (Aviendha). |
| Unweaving | Pick enemy weaves apart: risky and slow but decisive. | Wise Ones; mistakes can be fatal. |
| Listening to the Wind | Short warnings of incoming waves or weather. | Passive, mild precognition. |
| Seeing ta'veren | Spot elites or key NPCs. | Minor, rare. |
| Dreaming / dreamwalking | Tel'aran'rhiod missions and PvP sparring; the bridge to the Dreamer class. | A thing of Spirit; some Dreamers can't channel at all. |
| Foretelling | Rare cryptic hints about upcoming missions. | Can be hard to interpret. |


## Sources
- [The Thirteenth Depository — Weaves and Talents](https://13depository.blogspot.com/2002/02/weaves-and-talents.html) (Linda; the main chapter-cited survey)
- [Dragonmount — chapter-cited Spirit weaves, compiled from Encyclopaedia WoT and Wotmania](https://dev.dragonmount.com/forums/topic/30309-what-exactly-is-spirit-and-what-do-you-use-it-for/)
- [Tar Valon Library — The One Power](https://library.tarvalon.net/index.php?title=Fire)
- [Reactor: the Companion's strength chart of major channellers](https://reactormag.com/the-wheel-of-time-companion-strength-chart-of-major-channelers/) (the 72 levels, the men's ++ levels, the Travelling threshold)
- [The Thirteenth Depository — Robert Jordan's channeller strength ranking](http://13depository.blogspot.com/2016/12/robert-jordans-channeller-strength.html)
- [Fandom WoT Wiki — Strength in the One Power among Aes Sedai](https://wot.fandom.com/wiki/Strength_in_the_One_Power_among_Aes_Sedai) (Travelling minimums from the Companion)
- [Fandom WoT Wiki — Weave](https://wot.fandom.com/wiki/Weave) · [Five Powers](https://wot.fandom.com/wiki/Five_Powers) · [Arrows of Fire](https://wot.fandom.com/wiki/Arrows_of_Fire)
- [1999 Wheel of Time PC game walkthrough](https://www.cyberly.org/game-cheats/pc-walkthroughs/wheel-of-time.html) (balefire as Fire + Spirit — game, not book)
- [D&D Wiki homebrew weaves](https://dnd-wiki.org/wiki/3.5e_Weaves) (non-canon; shown only to explain disputes)

## Changes of 14-15 Nov (Josh's tour notes)
- No weave has a cooldown; `form` is the time it takes to weave, and a whole weave
  is held back until let go. See ARCHITECTURE.md.
- Lash of Water (invented) is a whip that hauls in, downs and soaks; soaked things
  are slowed and take more from lightning. Hammer of Air is unchanged.
- Arrows of Fire are piercing darts. Blossoms of Fire is a pillar that opens into a
  slow wheel of fire 10 to 30 ft across (Josh's description). The Rolling Ring rolls
  out as a wedge under 90 degrees wide, not a full circle (Josh's ruling for the game).

## Water from water (built 19 Nov; the design below, with these choices)
Built: `Map._waters` (per map: the training yard's horse pond, a stream and pool in
Tarwin's Gap, a pond outside the wagon ring, a river across the Wild Hunt's corner),
`Terrain.height` dips the ground to hold it, `Scenery.water` and `water.gdshader`
draw it, shallow water slows and soaks, deep cores are not walked (`Map.unblock`).
Torrent (`surge`, book 1, needs Lash of Water) and Wall of Water (`curtain`, book 6,
held; needs Lash and Hammer of Air). `Sim.WATER_REACH` 25 m: full strength near water,
half away from it. The wall curves round the caster when aimed within 4.5 m and
stands flat across the aim otherwise (no toggle key yet). Tests: `_water` in
`tests/run_tests.gd`. Left: a toggle key for the wall's shape, a wall weave of Air,
water seen in the doorway views, puddles reading on the ground at night, per-map
placement for the user to rule on.

## (Original design) water from water (19 Nov, the user's ask)
The user wants Water weaves that pull water from rivers, lakes and ponds on the
maps, one to attack and one to defend. A game design, not a canon table row: book
numbers below are proposals for the user to rule on (both kept at 6 or under so the
spoiler limit does not hide them).

**Map water.** `Map` gains water bodies: `{kind: pond|lake|river, shape: circle
{x, z, r} | polyline {points, width}, depth: shallow|deep}`. Shallow water slows
(like mire, 0.6) and soaks (`wet`); deep water is solid to walking, like a wall, and
pathing goes round it. `Scenery` draws a flat water surface (a small water shader:
dark, reflective, wind ripples from the `wind_vec` global) with a muddy shore.
Placement, to agree with the user: Tarwin's Gap, a stream down one side of the pass;
the wagon ring, a pond outside the ring; the training yard, a horse pond; the Wild
Hunt's open ground, a river across one corner. `Sim._water_near(pos, reach)` gives
the nearest water's distance and whether any is in reach.

**The rule both weaves share.** Water drawn from a body of water is plentiful: full
strength within 25 m of one. Away from water the weave pulls what it can from the air
and ground: half strength, smaller, shorter (a channeller far from water feels it).

**Attack: Torrent** (Water, with Air to carry it; proposed book 1, a cousin of the
Lash). Woven at a target in range: a surge rises from the nearest water's edge (or
from the ground at the channeller's feet, weakly, if none is in reach) and runs along
the ground to the aim as a travelling wave, like Heave the Ground's line: it knocks
down and pushes along its path, soaks everyone it touches (`wet`, so Lightning bites
harder), puts out burning ground and burning bodies, and leaves puddles behind it
(`Sim._puddle`). Damage below Fireball's; its worth is control. Visual: a rolling
crest of water with spray (the Lash's ribbons and drops, scaled up), the water body
visibly drawn down where it was taken from.

**Defence: Wall of Water** (Water and Air; proposed book 6). A held weave, tied off
like the Dome, with the same shape toggle the user wants for the Air wall: a flat
wall ahead or a quarter circle round the channeller. Not solid: arrows and thrown
weapons that cross it fall short, a fireball crossing it is put out (no burst),
burning things passing through stop burning, and enemies wading through are slowed
and soaked. Near water it is taller, wider and lasts longer. Visual: a standing
curtain of falling water (a scrolling transparent sheet with foam at the foot).

**Building it, data first.** Two rows in `data/weaves.json` with new kinds
(`surge`, `curtain`); the map water in `Map` per map; the sim pieces (`_water_near`,
the surge as a travelling line effect, the curtain as a held effect that missiles
test against, like the gateway's plane); the visuals in `weavefx`/`flowfx`; tests
(a torrent from a pond is stronger than one far from water; a wall stops an arrow
and drowns a fireball; deep water blocks walking); renders at night by the water.
