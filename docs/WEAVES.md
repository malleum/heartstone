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
100 and each level down divides by 1.033, so 72 is about 10 and ++1 about 121. Those
magnitudes are the game's invention; the Companion gives ranks, not ratios.

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
| Heave the ground | Earth | Earth threads driven down to throw the ground up. | AMoL, What Must Be Done | 14 | Canon |
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
