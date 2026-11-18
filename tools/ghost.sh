#!/usr/bin/env bash
# The controls, end to end: a scripted pair of hands (src/game/ghost.gd) presses
# real keys and mouse buttons in the game and the camp, and this checks the game
# did what a person would expect. Needs the GPU (it runs through tools/render.sh),
# so it is separate from tools/test.sh. Usage: tools/ghost.sh
cd "$(dirname "$0")/.."
command -v godot >/dev/null || exec nix develop -c "$0" "$@"
out=$(mktemp -d)
KEEP_EVERY=900 tools/render.sh renders/ghost_arms 960 -- --activity=camp_training --name=GhostW --class=warder --kit=sword,horse_bow,belt_knife --forms --ghost=arms >"$out/arms" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_weaves 520 -- --activity=camp_training --name=GhostC --aff=fire --only=fireball,dome_of_air,bonds_of_air --tie --flows=3 --ghost=weaves >"$out/weaves" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_dream 520 -- --activity=dream_spar --name=GhostD --class=warder --ghost=dream >"$out/dream" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_camp 600 -- --who=Bot --ghost=camp >"$out/camp" 2>&1
KEEP_EVERY=900 tools/render.sh renders/ghost_flow 520 -- --ghost=flow >"$out/flow" 2>&1
# A server on this machine, and the camp going through it: store a character, ask
# who is playing, walk through a doorway into a fight the server hosts.
HEARTSTONE_WORD=tinker timeout 120 godot --headless --path . -s src/net/server.gd -- --port=24699 >"$out/srv" 2>&1 &
srv=$!
sleep 2
KEEP_EVERY=900 tools/render.sh renders/ghost_online 420 -- --ghost=online --server=127.0.0.1:24699 >"$out/online" 2>&1
kill $srv 2>/dev/null
fail=0
want() { grep -qE "$2" "$out/$1" || { echo "  FAIL ($1): no '$2'"; fail=1; }; }
for w in "blow cut" "blow backcut" "blow finisher" "blow overhead" "blow leg_sweep" "blow loose" "blow throw" "blow parting_the_silk" "dodge $" "equip horse_bow"; do want arms "GHOST [0-9]+ $w"; done
want arms "status guard=true"; want arms "duck=true"
for w in "cast fireball" "hold dome_of_air" "tie dome_of_air" "ready fireball" "refused no one there to hold" "dodge"; do want weaves "GHOST [0-9]+ $w"; done
for w in "dream dream_spear" "dream dream_wall" "dream dream_pit" "shift $" "deny $"; do want dream "GHOST [0-9]+ $w"; done
want dream "GHOST 26[0-9] (dream dream_chains|refused)"; [ "$(grep -cE 'GHOST [0-9]+ shift' "$out/dream")" -ge 3 ] || { echo "  FAIL (dream): fewer than three steps"; fail=1; }
for w in "menu=true" "sheet=false" "pos=\([-0-9.]+, 0.0, -([2-9]|1[0-9])"; do want camp "$w"; done
# The camp's screens: make a character, change kit and looks, choose a study, make
# a second character, walk through a doorway into the game.
for w in "created: Ghost Maiden cls=aiel" "loadout: kit=\[\"" "appearance: look=" "unlock: .* owed=0" "second: Ghost Weaver power=saidin" "entered camp_training as Ghost Weaver"; do want flow "GHOST flow $w"; done
want online "GHOST online sync: Ghost Net is kept on"; want online "GHOST flow entered camp_training as Ghost Net \(joined a host\)"
want srv "SERVER keeps Ghost Net"; want srv "SERVER begins camp_training for Ghost Net"
if grep -hE "SCRIPT ERROR|^ERROR" -A2 "$out"/arms "$out"/weaves "$out"/camp "$out"/flow "$out"/online; then fail=1; fi
[[ $fail -eq 0 ]] && echo "GHOST RESULT: ok" || echo "GHOST RESULT: FAILED"
rm -rf "$out"
