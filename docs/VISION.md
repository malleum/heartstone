# Heartstone: the vision

Heartstone is *cuendillar*, the unbreakable stone. It is a private 3D Wheel of Time
game for Josh and one to five friends, so canon names are used freely.

## The fantasy
Insomniac's Spider-Man makes you feel like Spider-Man. Heartstone should make you
feel like a **channeller**: Rand at Dumai's Wells, Egwene holding a line, the "Vows"
chapter of *Knife of Dreams* where one channeller tears through waves of Trollocs
with Arrows of Fire and Blossoms of Fire.

A channeller's feel comes mostly from **effects**, not from thousands of hand-made
animations: glowing flows, fire bursting, lightning arcing, the ground tearing open,
Trolloc lines burning away. That is shaders, particles, light, sound and camera work,
which code can produce. One good set of casting animations plus excellent weave
effects carries the fantasy. Spend the art budget there.

## One character, growing slowly
This is the firmest requirement.

- **One persistent character per player.** Every activity pays into the same slow
  progression. Nothing resets. It is not a roguelite: no levelling that happens in
  fifteen minutes and is wiped.
- Choices at creation matter (saidin or saidar, potential, affinities in the Five
  Powers, Talents, origin and look) and so does growth afterwards.
- Growth follows canon and is use-based: weaving a weave masters it, weaving a Power
  improves it, strength creeps toward potential, weaves are learned by seeing them
  woven.
- **Flows are the spine.** How many flows you can hold at once grows over tens of
  hours ("few Aes Sedai hold more than three"). Going from two flows to three should
  change how you play: holding a shield while attacking, then weaving the big
  multi-flow weaves.
- The weave list and its canon research live in `weaves.md`, which Josh maintains.
  Prefer 15 to 20 weaves that each feel distinct over 60 recolours.

## One connected game
A hub (the camp) and several kinds of activity that share one character and one set
of systems. You pick what to do from the camp, for fun or for progress.

1. **Holdouts:** wave defence on hand-built maps. Tarwin's Gap first, then Dumai's
   Wells-style battles. Built first because it delivers the fantasy fastest.
2. **Linear missions**, Resident Evil 4-style: escorts, defend the gateway, assault a
   Darkfriend manor, Waygate runs. These carry a light plot thread.
3. **Tel'aran'rhiod missions**, later.
4. **Sparring in Tel'aran'rhiod:** PvP between friends with the same characters.

**Not open world.** Small and dense beats big and hollow. A camp, a handful of
maps, and missions that give a sense of going somewhere.

## Casting by drawing (wanted, not built)
Josh's idea: instead of picking a finished weave from a list, you choose the Powers
you are going to weave (say Fire and Air) and then draw a shape on the screen; the
flows plus the shape decide the weave. It fits the fiction, since a weave is flows
laid in a pattern, and it would make knowing a weave a skill of the hands as well as
a row on a sheet. Open questions for when it is built: whether drawing happens in
real time under pressure or slows the world, how forgiving recognition is, and
whether number keys stay as a fallback. The current select-and-click casting is the
stand-in until then; the rules layer only needs a weave id, so either input can
drive it.

## Co-op
Online co-op for 1 to 6 players; PvE is the focus. Friends should matter
mechanically: linking, Healing that cannot target yourself, a Warder guarding a
channeller mid-weave.

## Classes
Channeller first. Warder, Aiel warrior and Dreamer come later, and only once the
channeller is fun by itself.

## Enemies
Trollocs in hordes (mismatched beast-human hybrids: boar, wolf, ram, hawk, bear),
Myrddraal as eyeless, sinuous elites, then Draghkar, Darkhounds and Darkfriend
channellers.

## Look
Stylised, not realistic and not blocky. Animations get the time they need to look
right. Shadowspawn are generated in code, which suits their canon variety. Player
characters use sourced CC0 models, because the player looks at them all game.

## Spoiler setting
Friends are at different points in the books. Each profile has a book limit and
weaves from later books are hidden. Fleshing this out is a far-future problem.

## Deliberately out, for now
Open world, Tel'aran'rhiod missions, the other classes, the taint, crafting Talents,
and PvP beyond simple sparring. Each is a project of its own; the game has to be fun
with one class on one map first.

## Lineage
The previous game, `malleum/balefire`, was a top-down Wheel of Time roguelite. What
carried over: a deterministic simulation, host-authoritative co-op, weaves as data
rows, and generating content from tables of numbers. What did not: its invented
weaves and its per-run levelling.
