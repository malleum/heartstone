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

## Round 4: heads up close
- First close-up was damning: buried eyes, a teddy-bear bear, smooth butterscotch horns,
  straps aliasing into sausages.
- Eyes moved forward with larger sockets and brighter irises; snarling open jaws with
  tooth rows and fangs; ridged horn shading; straps made wide and thin.
- Better, not solved: the bear still reads friendly, eyes are small.

## Round 5: horde
- LOD knob (grid cell multiplier), 16 generated variants shared by all skeletons,
  gait maths optionally spread over worker threads, fps bench mode.
- 200 Trollocs: 4.3 ms/frame (233 fps) at 720p, 4.6 ms (219 fps) at 1080p. See the
  table in the final report. Performance is not the constraint.

## Round 6: humans
- Parametric face (11 sliders), five hair styles, beard/stubble, sex-dependent build,
  origin wardrobe as data (Two Rivers, Aiel, Aes Sedai, Cairhien, Warder, Domani):
  shells for coats/trousers/boots, a solid bell skirt, painted trim and stripes.
- First pass: skin showing through coat sides and skirts (masks), zombie eye sockets,
  puffy limbs, helmet hair. Fixed masks, slimmed limbs, finer head grid (3.7 mm),
  bigger eye openings, fuller nose, lower hairline, longer neck, shoes.
- Faces improved from "zombie" to "clay puppet" and stopped there. Two rounds of
  tuning moved them very little: this is the limit of sculpting faces from a few
  dozen blended primitives.

## Round 7: independent review and last fixes
- A fresh subagent that saw only the renders scored Trollocs 5/10 as shippable horde
  enemies and humans 3/10 (2/10 in creator close-up).
- Acted on its cheapest fixes: curled fingers and arms at the sides, near-black mail
  with a cool rim light on paler ground, a stronger hit-react, a limp death that lies
  flat (the corpse used to sit up holding its weapon aloft), no ridges on beaks/teeth.
- Not fixed: identical kilt-and-pauldron kit on most Trollocs, smooth "clay" surfaces
  with no hard edges, stiff death (no ragdoll), human faces.

## Where it plateaued
- Shape language: SDF blends make everything soft. Good for flesh and fur, wrong for
  plate, blades and cloth folds.
- Faces: fine for beasts at gameplay distance, not for human close-ups.
- Motion: locomotion is solid; anything acted (attacks, deaths, casting) needs either
  authored clips or a much richer procedural layer.
