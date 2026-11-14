# Wheel of Time 3D: Canon Weaves & Abilities

Research reference for the 3D game · 13 Nov 2026 · prepared for Malleum. Josh maintains
this document; the game's rows are in `data/weaves.json`, and where the game has not
caught up with it yet is listed in `docs/ARCHITECTURE.md`.

## How to read this

Every weave carries a confidence tag. Balefire (the repo) made a lot up; this table is meant to show exactly where the books stop and we start.

- **Canon:** flows stated in a book passage, cited by book and chapter.
- **Wiki:** flows come from a wiki or compiler with no chapter cite, or are the compiler's own inference.
- **Unknown:** the books never give the flows.
- **Game choice:** our pick, where canon is silent.
- **Your lookup:** from your own reading of the books; I haven't found the passage to cite.

**Book** is the earliest book I found a citation in, numbered 1–14 (NS = New Spring, counted as 0; a dash means no book cite). It isn't guaranteed to be the true first appearance, but it's good enough to drive the spoiler setting: pick how far a player has read and later weaves disappear.

## The Five Powers in canon

- **Gender lean:** men tend to be stronger in Earth and Fire, women in Air and Water; Spirit is evenly split. The Tar Valon Library and the Fandom wiki agree on this.
- **Lean, not rule:** the *World of Robert Jordan* guide says someone strong in Air may be all but unable to weave Fire. Affinities are personal, which is why Egwene can be strong in Fire, Earth and Spirit.
- **Strength vs skill:** the weakest man and weakest woman are about equal, but men have more levels above that. Women are deft enough with the flows that the strongest woman can match the strongest man.
- **Flows manipulate, not create:** the Powers move and change the five elements rather than making them from nothing.
- **Holding several flows is hard:** working two flows is far more than twice as hard as one. Few Aes Sedai can hold more than three at once; Rand manages ten or more. This is the levelling curve, given to us by the books.
- **Tie off, invert, reverse:** tying off is a trick few women know. Inverting hides a finished weave from other channellers. Reversing inverts it while it's woven, and only the Forsaken seem to know that one.
- **Cutting:** you can cut another channeller's weave only if you're stronger. A circle gets around that.
- **Linking:** women can start a link and men can't. Thirteen women can link without a man, circles go up to seventy-two, and only the leader channels.

## Weave tables

### Combat

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| Fireball | Fire | Thrown ball of fire; the textbook single-Power weave. | Fandom: Five Powers | — | Wiki |
| Lightning | Fire + Air | Called lightning (Earth-lightning is a variant, flows unstated). | TFoH, To Caemlyn | 5 | Canon |
| Explosive lightning storm | Air + Water + Fire | Rand's storm of exploding lightning. | TPoD, A Time for Iron | 8 | Canon |
| Arrows of Fire | Earth + Fire | Superheated filaments from the fingertips. | KoD, Vows; Fandom | 11 | Canon |
| Blossoms of Fire | Earth + Air + Fire | Bursting flowers of fire; area damage. | KoD, Vows | 11 | Canon |
| Deathgates | Spirit + Fire + Earth | Rolling gateways that kill whatever they pass through. | KoD ch.19 / Vows | 11 | Canon |
| Exploding / pulverising | Fire + Earth | Blow objects apart or grind them to dust. | LoC, Lessons and Teachers | 6 | Canon |
| Rolling ring of earth | Earth + Fire | The earth wave that broke the Shaido at Dumai's Wells. | Depository (no chapter) | 6 | Wiki |
| Heave the ground | Earth | Earth threads driven down to throw the ground up. | AMoL, What Must Be Done | 14 | Canon |
| Red filaments & balls of fire | Fire + Air | Burning threads and fireballs. | TPoD, A Cup of Sleep | 8 | Canon |
| Weapons of Air | Air | Hardened Air to hit, cut, stab or slice. | ToM, Gateways | 13 | Canon |
| Bind / lift with Air | Air | Restrain, lift, carry; strength-limited. | LoC, Summoned in Haste | 6 | Canon |
| Rip / cut with Air & Fire | Fire + Air | Tearing a Myrddraal's head off; cutting clothes away. | Depository (no chapter) | — | Wiki |
| Pain | Spirit + Fire | Complex weave that inflicts agony. | ACoS; LoC, Threads Woven of Shadow | 6 | Canon |
| Killing weave | Fire + Earth + Water | Chesmal's quick kill. | KoD, House on Full Moon Street | 11 | Canon |
| Balefire | Fire + Earth + Water + Air + Spirit | Burns threads out of the Pattern; stronger balefire reaches further back. Fire + Air are from the books and more flows are implied; all five is our pick, mirroring the Flame of Tar Valon. | TGS ch.47 (your reading); ACoS, A Crown of Swords | 3 | Game choice |
| Flame of Tar Valon | Fire + Earth + Water + Air + Spirit | Balefire's opposite; creation and locking threads in place. | AMoL booksigning | 14 | Canon |

### Defence & control

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| Shield (from the Source) | Spirit | Cut a channeller off; can be tied. | TDR ch.54 | 3 | Canon |
| Severing | Spirit | A shield with a knife edge severs instead. | TSR, Into the Palace | 4 | Canon |
| Dome of Air | Air | Shelter from arrows and missiles. | LoC, Dumai's Wells | 6 | Canon |
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
| Travelling: gateway (saidar) | Spirit | Make two places alike; a gateway opens. Needs 19(7) or stronger without the Talent. | LoC ch.34 | 6 | Canon |
| Travelling: gateway (saidin) | Spirit + Fire | Bend the Pattern and bore a hole. Needs 19(7) or stronger without the Talent. | KoD ch.21 | 11 | Canon |
| Skimming (saidar) | Spirit | Gateway onto a platform in the void, to a known destination. Same flows and strength gate as Travelling. | Same flows as Travelling (your lookup) | 4 | Your lookup |
| Skimming (saidin) | Spirit + Fire | As above, men's version. | Same flows as Travelling (your lookup) | 4 | Your lookup |
| Bridge | Air + Fire | No weight limit; ~20 paces for men, longer for women. | ACoS, Ta'veren | 7 | Canon |
| Walking platforms of Air | Air | Stand or walk on hardened Air. | Depository (no chapter) | — | Wiki |

### Healing & support

| Weave | Flows | Effect | Cite | Book | Conf. |
| --- | --- | --- | --- | --- | --- |
| Simple Healing (saidar) | Spirit + Water + Air | Battlefield Healing; draws on the patient. | TDR ch.15 | 3 | Canon |
| Simple Healing (saidin) | Spirit + Fire + Earth | Rough and hot; flows are the Depository's guess. | TPoD (flows inferred) | 8 | Wiki |
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

## Corrections & disputes

**Gateways — you were right, and I was wrong.** I said Fire and Earth. In canon, women open a gateway with Spirit (Egwene, *Lord of Chaos* ch. 34) and men with Spirit and Fire (Rand, *Knife of Dreams* ch. 21). The methods differ too. Men bend the Pattern and bore a hole through it; women use Spirit to make the two places alike. The "Earth, Fire, Spirit" Travelling I probably absorbed comes from a homebrew D&D weave list, not the books.

**Balefire — Fire and Air, plus one more flow.** Two passages point the same way. In *The Gathering Storm* ch. 47, where Rand nearly balefires Tam through the access key, he weaves Fire and Air, Lews Therin mutters, and then balefire is ready to loose. In *A Crown of Swords* (chapter "A Crown of Swords"), Rand starts weaving balefire, changes his mind, and lets "every flow but Fire and Air fall away", so the weave holds Fire, Air and at least one more flow that's never named. **For the game:** all five Powers. Its opposite, the Flame of Tar Valon, uses all five, so balefire mirrors it, and that's consistent with Fire and Air plus more. One caution when you reread the Tam scene: Rand also uses flows of Air there to throw Tam to the floor, so it's worth confirming the Fire-and-Air sentence belongs to the balefire.

**Travelling — a weave with a strength gate, or a Talent.** Travelling is a weave most channellers can learn, but only if they're strong enough. *The Wheel of Time Companion* puts the minimum for a useful gateway (one you can walk through) at **19(7)**, assuming average Talent for it. The weakest channellers actually seen opening a reasonably sized gateway in the books are around **22(10)**. Below the minimum, the weave forms but doesn't work: the Tar Valon Library gives Sorilea as an example. Weak sisters get around it by linking in pairs. The **Talent for Travelling** is different: Androl, one of the weakest men at the Black Tower, makes gateways big enough for a cart. **For the game:** Travelling and Skimming are learnable weaves for any channeller at 19(7) or stronger, with gateway size scaling with strength. The Talent removes the minimum and makes gateways much larger. Linking with another channeller also clears the gate.

**Agreements worth noting.** Arrows of Fire is Earth + Fire on both the Fandom wiki and the Thirteenth Depository. Deathgates is Spirit, Fire and Earth in both the Depository and a separate Dragonmount compilation. The three big weaves from your vows chapter (*Knife of Dreams*, "Vows") all have stated flows: Arrows of Fire, Blossoms of Fire and Deathgates. That makes the holdout's signature arsenal unusually well grounded.

**What the Fandom wiki adds:** its weave list is the longest, but it gives names only (Riven Earth, Protective Whirlwind, Making Fog, Spinning Earthfire…). Flows come from the Depository and the chapter-cited Dragonmount list. Role-play sites like thefirstage.org invent their own flows and were ignored.

## Combined ability system

Talents, element proficiency and weave proficiency blend together, so they're designed as one system with three layers. Canon decides what is fixed at creation and what grows.

### The formula, in words

A weave's power = **current strength** × the **affinities** of the flows it uses (weighted by how much of each) × **weave mastery** × any **Talent** bonus.\
Casting needs a minimum affinity in *every* flow the weave uses. So Blossoms of Fire (Earth + Air + Fire) needs some competence in all three, which makes spreading affinities matter, as in balefire's joint weaves.\
Holding several flows at once is the scarce resource, following the books' "far more than twice as hard" rule.

### Set at creation

#### Saidin or saidar

Shapes default affinities (men Earth/Fire, women Air/Water, Spirit even) and changes how some weaves are built: gateways are Spirit + Fire for men and Spirit for women. Optional later: the taint.

#### Potential (strength ceiling)

Point-buy. Higher potential costs Talent points. In the books, current strength grows toward your potential with use, and that is your "small power upgrade" while levelling. Some weaves have strength gates: Travelling and Skimming need 19(7) or stronger unless you have the Talent.

#### Affinities

Distribute starting proficiency across the five. A specialist can be nearly unable to weave an off element, as canon allows.

#### Talents (1–2)

Innate. In canon they can't be learned, so they're picked here only. See the list below.

#### Look & attire

Body, face, hair, plus clothing by origin: Two Rivers wool, Cairhienin slashes, Aiel cadin'sor, Tower white or shawl colour, Asha'man black. Cosmetic, never stats.

### Grows with levelling

| Track | What improves | Canon basis |
| --- | --- | --- |
| Weave mastery (per weave) | Faster to form, cheaper to hold, more precise aim and shape. Learned by seeing it done, from teachers, enemy casts or ruins. | Channellers learn mostly by watching others weave. |
| Element proficiency | Small gains per element; unlocks harder weaves that use it. | Affinities are personal and differ by element. |
| Concurrent flows | 1 → 2 → 3 … the headline progression. 3+ is elite and 10 is Dragon-tier. | Few Aes Sedai hold more than 3; Rand holds 10+. |
| Strength | Slow growth toward your potential. | Growth toward potential over time. |
| Techniques | Tie off → invert → cut weaves → (endgame) reverse. Unlocked by quests, e.g. learning from a captive Forsaken. | Rand learned inverting from Asmodean; Elayne and Nynaeve from Moghedien. |
| Linking | Join and lead circles in co-op; the leader directs everyone's combined strength. | Only the leader channels; circles beat strength limits on cutting. |
| Angreal / sa'angreal | Loot: big temporary boost, with overdraw and burnout as the risk. | Amplifies how much of the Power you can safely draw. |

### Talents (creation picks)

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

### Other classes, same shape

#### Warder

Creation build, sword style, homeland.\
Levelling sword forms, the bond (sense your channeller, shared endurance), colour-shifting cloak. Uniquely good at guarding a casting channeller.

#### Aiel

Creation warrior society, clan.\
Levelling spear and buckler forms, bow, veiling, moving unseen, endurance.

#### Dreamer

Creation Dreaming Talent (may not channel).\
Levelling control in Tel'aran'rhiod: shaping, need-based travel, protecting dreams. Strongest in dream missions; supports elsewhere.

## Engine: Godot

- **Built-in 3D tools:** skeletal animation and blending, navigation meshes for Trolloc hordes, physics, and GPU particles and shaders for weaves. In three.js you'd assemble all of that from libraries.
- **Native desktop performance** fits a horde game on an 8 GB GPU better than the browser.
- **Built-in multiplayer** covers co-op for 1–5 friends.
- **Procedural Trollocs still work:** meshes and skeletons can be generated in code inside Godot.
- **You know it** from the plane game.
- **Cost:** we don't reuse balefire's TypeScript sim. We're re-deriving the weaves from canon anyway, and its design ideas carry over.

## Sources

- [The Thirteenth Depository — Weaves and Talents](https://13depository.blogspot.com/2002/02/weaves-and-talents.html) (Linda; the main chapter-cited survey)
- [Dragonmount — chapter-cited Spirit weaves, compiled from Encyclopaedia WoT and Wotmania](https://dev.dragonmount.com/forums/topic/30309-what-exactly-is-spirit-and-what-do-you-use-it-for/)
- [Tar Valon Library — The One Power](https://library.tarvalon.net/index.php?title=Fire)
- [Fandom WoT Wiki — Strength in the One Power among Aes Sedai](https://wot.fandom.com/wiki/Strength_in_the_One_Power_among_Aes_Sedai) (Travelling minimums from the Companion)
- [Fandom WoT Wiki — Weave](https://wot.fandom.com/wiki/Weave) · [Five Powers](https://wot.fandom.com/wiki/Five_Powers) · [Arrows of Fire](https://wot.fandom.com/wiki/Arrows_of_Fire)
- [1999 Wheel of Time PC game walkthrough](https://www.cyberly.org/game-cheats/pc-walkthroughs/wheel-of-time.html) (balefire as Fire + Spirit — game, not book)
- [D&D Wiki homebrew weaves](https://dnd-wiki.org/wiki/3.5e_Weaves) (non-canon; shown only to explain disputes)
