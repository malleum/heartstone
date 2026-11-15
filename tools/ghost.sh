#!/usr/bin/env bash
# The controls, end to end: a scripted pair of hands (src/game/ghost.gd) presses
# real keys and mouse buttons in the game and the camp, and this checks the game
# did what a person would expect. Needs the GPU (it runs through tools/render.sh),
# so it is separate from tools/test.sh. Usage: tools/ghost.sh
cd "$(dirname "$0")/.."
out=$(mktemp -d)
KEEP_EVERY=900 tools/render.sh renders/ghost_arms 960 -- --activity=camp_training --name=GhostW --class=warder --kit=sword,horse_bow,belt_knife --forms --ghost=arms >"$out/arms" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_weaves 520 -- --activity=camp_training --name=GhostC --aff=fire --weaves=fireball,dome_of_air,bonds_of_air --tie --flows=3 --ghost=weaves >"$out/weaves" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_camp 600 -- --who=Bot --ghost=camp >"$out/camp" 2>&1
fail=0
want() { grep -qE "$2" "$out/$1" || { echo "  FAIL ($1): no '$2'"; fail=1; }; }
for w in "blow cut" "blow backcut" "blow finisher" "blow overhead" "blow leg_sweep" "blow loose" "blow throw" "blow parting_the_silk" "dodge $" "dodge roll" "equip horse_bow"; do want arms "GHOST [0-9]+ $w"; done
want arms "status guard=true"; want arms "duck=true"
for w in "cast fireball" "hold dome_of_air" "tie dome_of_air" "refused not ready" "refused no one there to hold" "dodge"; do want weaves "GHOST [0-9]+ $w"; done
for w in "tree=true" "menu=true" "sheet=false" "pos=\([0-9.]+, 0.0, -2"; do want camp "$w"; done
if grep -hE "SCRIPT ERROR" -A2 "$out"/arms "$out"/weaves "$out"/camp; then fail=1; fi
[[ $fail -eq 0 ]] && echo "GHOST RESULT: ok" || echo "GHOST RESULT: FAILED"
rm -rf "$out"
