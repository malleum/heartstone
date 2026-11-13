# Procedural character spike: iteration log

Approach: every creature is signed-distance "clay" (a smooth union of bone-tagged
primitives) meshed with surface nets. Skin weights, colours and ambient occlusion are
derived from the primitives, armour is an offset shell of the body field, and all
motion is procedural (planted feet + two-bone IK). Nothing is an authored asset.

## Round 1: pipeline proof
- SDF field, surface nets mesher, skeleton, five head recipes, flat-ground line-up.
- Worked first time technically: ~0.8 s per creature in GDScript on a worker thread.
- Looked like balloon bodybuilders in an A-pose: stacked-ball torsos, tiny heads,
  far too bright (colour tables were being read as linear, not sRGB).

## Round 2: locomotion
- Walker: foot plant state machine, swing arcs to predicted landing spots on the
  terrain height function, pelvis hung between the feet, IK legs, layered spine/arms.
- Added a numeric foot-slide audit (skinned toe joint vs. its plant point).
- First walk dragged planted feet 346 mm: the stride was longer than the leg could
  reach. Fix: cap stride by leg geometry. Drift is now 0.0 mm for hoofed and footed legs.
- Arms were held forward zombie-style; now hang under gravity and counter-swing.

## Round 3: armour, weapons, proportions
- Shell layers (mail hauberk, hide kilt, belt, baldric, bracers, greaves), rigid props
  (spiked pauldrons, scythe-sword, axe, spear, spiked club), mail/plate/leather shader.
- Torso rebuilt as one continuous trunk; wider shoulders, longer arms, darker palette.
- Biggest single jump in "reads as a Trolloc". Bugs seen in renders and fixed: kilt and
  bracer masks swallowing the hands in bind pose.
- Still wrong: 84k triangles per creature, flat lighting, heads unreviewed up close.
