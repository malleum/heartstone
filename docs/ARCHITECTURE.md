# Heartstone architecture

Written so a fresh session can pick up cold. Decisions carry their reasons; if a
reason stops being true, the decision is open again.

## What the game is
Co-op PvE for 1-6 friends: you play a channeller (later Warder, Aiel, Dreamer) in the
Wheel of Time world. Private game, so canon names are used freely.

- **One persistent character per player.** Every activity pays into the same slow
  progression. Nothing resets between activities and there is no per-run levelling.
  This is the user's firmest requirement (2026-11-13): not a roguelite.
- **Camp hub, then activities:** training, wave holdouts (Tarwin's Gap first), linear
  missions, and sparring in Tel'aran'rhiod (PvP with the same character). Activities
  unlock by renown and earlier clears, with a light plot thread through missions.
- **Not open world.** Considered and rejected twice: content cost with no payoff.
- **Art: stylised low-poly**, not realism (decided 2026-11-13 after the spike in
  `docs/trolloc-test-log.md`). Shadowspawn are procedural; humans use a sourced base
  mesh and animations with procedural colour/clothing. The feel of channelling comes
  from weave effects, not character fidelity.

## Layers (dependencies point downward only)
```
view    src/game/   nodes: camera, creatures, weave effects, HUD        (to build)
net     src/net/    Session: host-authoritative transport
rules   src/core/   Rules, Profile, Progression, Sim, Bot: no nodes at all
data    data/       weaves.json, enemies.json, activities.json
gen     src/gen/, src/anim/   procedural creatures and locomotion
```
- **Rules have no nodes and no rendering.** Why: the host can referee headlessly,
  tests can play whole holdouts with a bot, and balance can be measured instead of
  guessed. The view only mirrors `Sim` state and events.
- **Data over code.** Adding a weave, enemy or activity is a JSON row. `kind` on a
  weave selects one of a small set of sim behaviours (projectile, burst, ring, line,
  beam, strike, cone, mover, barrier, heal, sever, utility). A new *kind* is code; a
  new weave of an existing kind is not.
- **All tuning numbers are in `Rules.TUNE`.**

## The character (src/core/profile.gd)
A plain Dictionary saved as JSON under `user://profiles/`.
- Fixed at creation (20 points shared): saidin/saidar, potential (strength ceiling),
  affinities in the five Powers, 0-2 Talents, origin and look. More potential means
  fewer Talents, as in `weaves.md`.
- Grows forever: strength (toward potential), affinity per Power (toward an aptitude
  ceiling), mastery per weave, flows held at once, weaves known, renown.

## The formula (src/core/rules.gd)
`power = strength x (0.5 + flow-weighted affinity) x (1 + 5% x mastery) x Talent`.
A weave's base numbers are written for power 10 and scale linearly.
Casting needs: the weave learned, within the spoiler limit, any required Talent, a
minimum affinity in every flow, enough free flow slots, and endurance.
- **Flow slots** = total threads in the weave. Capacity starts at 2 and grows with
  lifetime channelling. This is the headline progression from the books ("few Aes
  Sedai hold more than three"). It gates the big weaves (Blossoms of Fire needs 3)
  and lets you hold a shield while attacking.
- **Spoiler setting** is `book_limit` on the profile versus `book` on each weave.

## Progression (src/core/progression.gd)
One function, `Progression.award(profile, tally, activity, success)`, called when
any activity ends. Growth is use-based, following canon: weaving a weave masters it,
weaving a Power improves it, strength creeps toward potential, weaves are learned by
seeing them woven (activity `teaches`). Measured pacing with a bot (tools/test.sh):
3 flows at ~5 h, 4 at ~20 h, 5 at ~40 h; strength near potential by ~20 h.
- Known issue: renown is farmable by replaying a cleared activity (25% each time).
  Fine while renown only gates content; revisit before it buys anything.

## Networking (src/net/session.gd)
Host-authoritative, like balefire. Clients send intent (movement, cast requests);
the host steps the one `Sim` and broadcasts snapshots (unreliable) and events
(reliable). Single-player is the same path with the host as sole player.
- Profiles live on their owner's machine. The host borrows them to run the rules and
  returns each player's tally; each client awards and saves locally.
- No anti-cheat by design: friends only.
- Not done yet: client-side interpolation/prediction, lobby UI, reconnect, NAT
  traversal (use a VPN such as Tailscale or port-forward 24680/udp for now).

## Creatures (src/gen, src/anim)
See `docs/trolloc-test-log.md`. Summary: SDF "clay" + surface nets, weights and
colour derived from primitives, armour as offset shells, procedural gait with planted
feet. 250 Trollocs render at 170+ fps, so performance is not a constraint.

## Humans (src/gen/human_rig.gd)
Hybrid, decided after the spike: the skeleton and 46 animation clips come from
Quaternius' Universal Animation Library (CC0); the body, face and origin clothing
are generated by `Creature` directly onto that skeleton's joints, so no retargeting
is needed and every clip works on every generated character. The mannequin mesh is
discarded. Fingers are not skinned individually (hands follow the hand bone).

## View (src/game)
`game.gd` is the main scene. It owns a `Session`, sends intent, and mirrors
snapshots and events: players are `HumanRig`s driven by clips, enemies are `Walker`s
that chase their sim position with their own planted-foot gait, weaves are
`Weavefx` placeholders. `--auto` lets the bot play, which is how it is rendered and
checked without a human (`tools/render.sh renders/game 400 -- --auto`).

## Next steps, in order
1. Camp hub: activity board from `Rules.available`, character creation screen,
   join-a-friend. Until then, pick with `--activity=` and `--name=`.
2. Weave effects and game feel (hit-stop, shake, sound): the core fantasy lives here.
3. Trolloc attack animation and a stylised pass (faceted shading, kit variety).
4. Client interpolation; foot IK for humans on slopes.
5. Tarwin's Gap map, then missions and the plot thread.
