# The tour: every mechanic, one station each

Start it with `heartstone --tour` (or `--tour=N` to begin at station N). Each station is a
throwaway character in front of one thing; nothing is saved. **N** next, **B** back,
**R** again, **F1** hides the card, **F10** to the camp. When something is wrong, say its
number ("#37: the pike thrust goes sideways").

Generated from `src/game/launch.gd` by `tools/tourdoc.py`.


## Weaves

| # | Station | Test | Notes |
|---|---|---|---|
| 1 | Fireball | Hold to weave, let go: it flies where you look and bursts. | The ring at the crosshair fills while you weave; the burst's circle shows on the ground. Fire leaves the grass burning. |
| 2 | Hammer of Air | A cone that throws them back and down. | Short reach, wide. They tumble and slide. Its ring and threads are flows: only you (a woman) see them; the dust it throws anyone sees. |
| 3 | Heave the Ground | A line of rock driven up along your aim. | Spikes nearest first, tallest in the middle; the ground stays torn a while. |
| 4 | Lash of Water | A whip that hauls them in and soaks them. | Soaked Trollocs are slowed; it leaves puddles that put fire out. |
| 5 | Blade of Spirit | A sliver that dazes: they stop attacking for a moment. | Spirit is never dodged (even by an Eyeless). The blade itself is flows; the daze motes anyone sees. |
| 6 | Dome of Air | A dome round you that soaks blows and arrows while held. | It takes flows (the dots top left) and breaks when it has soaked enough. Archers are shooting. |
| 7 | Bonds of Air | Aimed at one: it is held still while you hold the weave. | A thread runs from your hand to it. Two at once if you have the flows. |
| 8 | Lightning | Falls from the sky on the aim; soaked ones take more, and it arcs. | A white flash, arcs along the ground, a scorch. What survives is charged: the next hit leaps on. |
| 9 | Arrows of Fire | Fast darts, each through two bodies. | Thin white-hot streaks, almost no glow. |
| 10 | Rolling Ring of Earth and Fire | A wedge of fire and earth rolls out the way you face. | Read the wedge on the ground while you weave. Does the size feel right after the cut to two-thirds? |
| 11 | Blossoms of Fire | A pillar, then a wheel of fire turning outward: stay out of it. | It hurts you too if you stand in it. |
| 12 | Deathgate | A doorway of darkness that sweeps forward through them. | Slow to weave. Worth the wait? |
| 13 | Torrent | Only near water: a wave from the pond rolls over them. | You start beside the horse pond; weave at the Trollocs as they come. Away from water it will not weave. |
| 14 | Wall of Air | Solid while held: nothing walks or is thrown through, either way. | Your own fire stops on it too. T: flat ahead or round you; the wheel turns it while you weave. |
| 15 | Wall of Water | Arrows fall short and fire goes out in it; people wade through. | A falling sheet. Try your own fireball through it (it hisses out). |
| 16 | Balefire | Kills outright, and undoes what the dead did in their last moments. | Let a Trolloc wound your Warder, then balefire it: the wound is gone. Hold the button after it is woven to keep it burning and sweep it. |
| 17 | Healing | Aimed at a hurt friend in reach: their health and wounds come back. | It tires the one healed. You cannot Heal yourself. The dark end of the health bar is wounds: only Healing mends them. |
| 18 | Shield from the Source | On the Dreadlord: it cannot channel while you hold it. | It gathers fire and marks the ground red for lightning; shielded, it does neither. |
| 19 | Gateway (quick) | Tap: a gateway opens quickly where you look. Walk through. | Each side is a window onto the other. |

## Weaving

| # | Station | Test | Notes |
|---|---|---|---|
| 20 | Gateway, end by end | Hold until whole: let go sets the near end, click sets the far end. | T lays the end you are placing flat (aimed high: an opening in the sky to drop out of); the wheel turns it. Hammer a Trolloc into it: it dies. Fire goes through and comes out turned. |
| 21 | Placing walls | T switches flat ahead / round you; the wheel turns 15 degrees a notch. | The shape shows on the ground while you weave. The turn resets for each new weave. |
| 22 | Holding and tying off | Held weaves use flows; G ties off the chosen one, freeing the flow. | Dome, Bonds and the Shield. Is juggling flows interesting or fiddly? |
| 23 | Keeping a weave, two at once | Weave a fireball, then change slot: it is kept aside; its slot takes it back up. | Both weave at 60% while both are being made; a whole kept one costs a little each second. Its slot shows it is kept. |
| 24 | The weave chart and the bar | Tab: the chart. Drag slots on the bar to arrange them. | Is dragging easy, and do the slot marks (weaving, ready, kept) read? |
| 25 | A weak channeller | Strength 35: everything is smaller, shorter and slower. | Compare with the next station. |
| 26 | A very strong channeller | Strength 1: bigger bursts, longer burns, faster weaving. | The same three weaves. |
| 27 | Weaves change the ground | Fire burns the grass, water puddles, air blows fire out, earth throws down the breastwork. | Heave the Ground leaves rubble to shelter behind. |
| 28 | Seeing flows: a man beside a woman | You are a man: her weaving is invisible to you; her fire is not. | Your own weaving you see. Her Dome or Bonds: you see only what they do. |
| 29 | Seeing flows: a fighter | A Warder sees no weaving at all, only what weaves do. | Your channeller's fireballs fly from nothing; a Wall of Air would be invisible. |
| 30 | First person: weaving | Through your own eyes: the hands come up round the weave. | F5 switches back and forth any time (remembered). Is the bob too much? |

## Arms

| # | Station | Test | Notes |
|---|---|---|---|
| 31 | Cut, heavy blow, parry | Right click just before a blow lands: parry. At the last instant: perfect, they reel. | Left click cuts; hold for a heavy blow. The wedge on the ground is where their blow will fall. |
| 32 | Roll, step back, duck, jump | Space rolls (standing: steps back). Ctrl ducks a high swing. V jumps a low sweep (yellow wedge). | Caught by a sweep you go down: Space rolls up, right click rises behind your guard. |
| 33 | Throwing and gathering | F throws; what you threw stands where it fell: walk over it to pick it up. | Throwing knives, javelins, axes. |
| 34 | Sword and round shield | Hold right click facing archers: arrows glance off the shield. | The heavy blow is a shield bash that shoves. |
| 35 | Drawing a bow | Hold to draw (you turn to the aim); a half draw falls short. | Side-on stance, the string to the cheek. |
| 36 | First person: weapons | A blade held out ahead, a pole levelled; the bow drawn in view. | 1-3 change weapon. Do blows read from the eyes (the streaks)? |

## Weapons

| # | Station | Test | Notes |
|---|---|---|---|
| 37 | Sword, hand-and-a-half, sabre | Each swings and lands as it should; the bigger blade is slower and harder. | 1, 2, 3 to change. |
| 38 | Short sword, sword and knife, practice sword | Sword and knife: the knife stabs between cuts from the off hand. | The practice sword barely hurts. |
| 39 | Belt knife, paired daggers, Aiel long knife | Quick and short; the daggers flurry. |  |
| 40 | Throwing knives, throwing axes, javelins | Thrown arms in flight, stuck where they hit, gathered again. |  |
| 41 | Aiel spear, boar spear, pike | The Aiel spear one-handed over the buckler; the others two-handed thrusts. | The pike reaches furthest. |
| 42 | Halberd, ashandarei, quarterstaff | Two hands on the haft: cuts both ways, overheads, butt strikes. | The halberd throws them back; the staff trips. |
| 43 | Iron-shod staff, half-moon axe, woodsman's axe | Heavy chops; the axes hook. |  |
| 44 | Smith's hammer, cudgel, sling | The hammer reels them; the sling is quick and staggers. |  |
| 45 | Longbow, horn bow, horse bow | Compare the three draws and ranges. |  |
| 46 | Crossbow, bare hands | Crossbow: one click, one hard bolt, then it spans itself. Hands: jab, cross, kick. | The kick lifts the leg; the low blow is a sweeping kick. |
| 47 | Earned weapons | Heron-mark blade, Power-wrought blade (never dulls), the ruby dagger (bleeds; feeds on you). | Normally won: heron-mark at sword skill 6, Power-wrought at renown 60, the dagger at renown 30. Hold the dagger and watch your health. |

## Forms

| # | Station | Test | Notes |
|---|---|---|---|
| 48 | Sword forms, first four | Forms are the row beside the bar (the sword in hand): Z, X, then Shift 3 and 4 (R is the tour's): Parting the Silk, the Boar Rushes, Apple Blossoms, Heron Wading. | Each has its own path, streak and colour; Heron Wading is on one foot. Each has a cooldown. |
| 49 | Sword forms, last four | Shift 5 to 8: the Swallow, the Courtier's Fan, Arc of the Moon, Sheathing the Sword. |  |
| 50 | Spear forms | The Dance of Spears (three thrusts) and Set Against the Charge. |  |
| 51 | Whirling Staff, Hew, Flurry | Staff, axe and knife (paired daggers) forms. | Flurry is four quick wounds. |
| 52 | Bow forms | Longbow in hand, forms beside the bar (Z, X, Shift 3-6): Snap Shot (no draw), Two on the String, Through the Line (wait till they line up), Fire Arrow (bursts and burns), Hail of Shafts, the Heart Shot. | Through the Line should go through two or three in a row; the Heart Shot knocks one back. |
| 53 | Thrown forms | Throwing knives: Flick of the Wrist, a Fan of Steel (five at once), Hard and Low, the Gleeman's Juggle. Gather them up again after. | The fan should spread across a rank; the juggle stops when the knives run out. |

## Callings

| # | Station | Test | Notes |
|---|---|---|---|
| 54 | The Warder's bond | A knot marks your channeller, through walls; redder as she is hurt. | Out of sight it is an arrow at the screen's edge. If she goes down you rage: harder blows, no tiring, for 12 s. |
| 55 | The Warder's cloak and ward | Stand still a second: they go for her instead. Parry beside her: you take her blow. | You both recover faster near each other. |
| 56 | Aiel: a Maiden of the Spear | A little faster, and dodges cost less breath. | Veiled to fight. |
| 57 | Aiel: a Stone Dog | Standing your ground, a fifth less from every blow. | Compare standing still with moving. |
| 58 | Aiel: Brother of the Eagle | The horn bow drawn a fifth faster. |  |
| 59 | Hunter: the Band of the Red Hand | The kit whole: crossbow, ashandarei, short sword, a level up in each. |  |
| 60 | Gift: Wolfbrother | A tenth faster, harder on Shadowspawn. |  |
| 61 | Gift: a gambler's luck | "Lucky": one blow in seven misses you; one of yours in ten lands double. | Watch the notices. |

## Enemies

| # | Station | Test | Notes |
|---|---|---|---|
| 62 | Trollocs | Each weapon has its own two blows; a blow unguarded staggers or throws you. | Scythe-swords sweep, axes chop, spears thrust, clubs smash. Read the wedges. |
| 63 | Trolloc archers | They shoot from range: duck, roll, or shield. |  |
| 64 | A bandleader (brute) | Big and hard-hitting; its low sweep trips (jump it, V). |  |
| 65 | The Eyeless, blade to blade | It circles, lunges along the red line, or vanishes and comes out behind you. | Roll off the line or parry. Its wounds fester until Healed. |
| 66 | The Eyeless and the dark | As a channeller: the dark closes in as it comes near; its stare slows your weaving. | Half of what you throw misses it; Blade of Spirit does not. Look away from its gaze. |
| 67 | Darkhounds | They spring from far off along the red line; steel does half; weaves kill. | They mend when left alone. |
| 68 | A Draghkar | It lands and sings (the rings): hit it before the song ends, or break its sight. | Let it finish once to feel it. |
| 69 | A Dreadlord | Fire that bursts, red ground where lightning will fall. | Shield it, or out-weave it. |
| 70 | Darkfriends | Men with blades and bows, smaller than Trollocs, fighting like people. |  |
| 71 | A horde | Thirty Trollocs: does it stay smooth? | Rolling Ring and Blossoms into the crowd. |

## Dream

| # | Station | Test | Notes |
|---|---|---|---|
| 72 | Dream duel: moving and denying | Z X V T Y U H Shift: the shifts, deny, spear, chains, pit, wall. | Will (the pale bar) pays for everything. Deny, pressed as something reaches you, unmakes it. I opens all 24. |
| 73 | Dream duel: the wild things | Side-step, swap, arrows, boulder, ravens, cage, forget, shove. | Caged? Deny and wait. Swap trades places. |
| 74 | Dream duel: the strange ones | Pull, fire, storm, ring, mirror, mend, fade, haste. | The mirror turns things back. Fade: unseen. Haste: quicker. |
| 75 | Dream inventory | I: click an ability, then a slot, to put it on the bar. | Is it friendly enough? Are the bar's marks readable? |

## Fights

| # | Station | Test | Notes |
|---|---|---|---|
| 76 | A round, sped up | Tab: choices waiting (six levels in). Waves four times as fast. | Your fire hurts your Warder. Go down: you lie there till the wave ends, and he must be beside you then (watch the health bar's DOWN line). |
| 77 | Guard the Aes Sedai | She seals the Waygate (timer at the top); they go for her; if she falls it is lost. | Her mark points to her when she is out of sight. |
| 78 | Guard her as a channeller | A Dome over her, Bonds on what reaches her. |  |
| 79 | Two banners (team battle) | Blue rings yours, red theirs; kill theirs, stand over your own. | Bots fill out the numbers. |
| 80 | The wagon ring, sped up | From every side, with archers and an Eyeless. |  |
| 81 | The Wild Hunt, sped up | Darkhounds, a Draghkar, Dreadlords together. |  |
| 82 | The endless night, sped up | Waves without end, at night, eight levels in. | Last station: N goes back to the camp. Things to try there are in docs/TOUR.md. |

## Not in the tour

In the camp (walk there after the last station, or start the game normally):
- The doorways show a picture of the place they open on; the live view takes over as you come up.
- Stations on the open side: the armoury, the tailor (face shaping: width, jaw, chin, nose, cheeks, brow), the study (loadout). Walk up, press E.
- Making a character: Aiel societies and Hunter kits are at the top of the right panel; fighters' gifts below.
- Dream bar keys can be rebound in the camp.

Needs a second person:
- Linking into a circle (L): a woman leads, others near her offer.
- Tying someone with rope (hold K over them).
- A Darkfriend among us (the hidden traitor mode), and walking through a doorway together.
- Movement prediction over a real connection.
