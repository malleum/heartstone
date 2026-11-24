#!/usr/bin/env bash
# Headless tests: rules + progression, then a real co-op session over localhost
# (one referee host, two bot clients). Usage: tools/test.sh
cd "$(dirname "$0")/.."
command -v godot >/dev/null || exec nix develop -c "$0" "$@"
godot --headless --path . --import >/dev/null 2>&1
flt='^(Godot Engine|$)'
timeout 300 godot --headless --path . -s tests/run_tests.gd 2>&1 | grep -vE "$flt"
echo "== co-op over localhost"
out=$(mktemp -d)
timeout 200 godot --headless --path . -s tests/net_test.gd -- host 2 >"$out/host" 2>&1 &
sleep 1.5
timeout 200 godot --headless --path . -s tests/net_test.gd -- client one >"$out/c1" 2>&1 &
timeout 200 godot --headless --path . -s tests/net_test.gd -- client two >"$out/c2" 2>&1 &
wait
grep -hE 'NET|ERROR' "$out"/host "$out"/c1 "$out"/c2 | sed 's/^/  /'
# The host seeds the fight at random and two simple bots sometimes lose it; what
# is tested is the session: both clients joined, played to the end and were paid.
if [[ $(grep -hcE 'host over success=|client (one|two) done success=' "$out"/host "$out"/c1 "$out"/c2 | paste -sd+ | bc) -eq 3 ]]; then echo "NET RESULT: ok"; else echo "NET RESULT: FAILED"; fi
# One bot alone may well lose the watch; what is tested is that the fight runs to its end.
echo "== dedicated server: joining by word, two fights at once, who is playing, the character store"
HEARTSTONE_WORD=tinker timeout 240 godot --headless --path . -s src/net/server.gd -- --port=24699 >"$out/srv" 2>&1 &
srv=$!
sleep 2
timeout 200 godot --headless --path . -s tests/net_test.gd -- client three 127.0.0.1:24699 tinker reds >"$out/c3" 2>&1 &
c3=$!
timeout 200 godot --headless --path . -s tests/net_test.gd -- client four 127.0.0.1:24699 tinker blues camp_training >"$out/c5" 2>&1 &
c5=$!
sleep 2.5
timeout 30 godot --headless --path . -s tests/net_test.gd -- lobby 127.0.0.1:24699 tinker >"$out/l" 2>&1
timeout 60 godot --headless --path . -s tests/net_test.gd -- client stranger 127.0.0.1:24699 wrong >"$out/c4" 2>&1
timeout 60 godot --headless --path . -s tests/net_test.gd -- vault 127.0.0.1:24699 tinker >"$out/v" 2>&1
timeout 60 godot --headless --path . -s tests/net_test.gd -- dropper 127.0.0.1:24699 tinker >"$out/d" 2>&1
wait $c3 $c5
kill $srv 2>/dev/null
grep -hE 'SERVER|NET' "$out"/srv "$out"/c3 "$out"/c5 "$out"/c4 "$out"/v "$out"/l "$out"/d | cut -c1-200 | sed 's/^/  /'
if grep -q 'three done' "$out/c3" && grep -q 'four done' "$out/c5" && grep -q 'lobby 2 fights' "$out/l" && grep -q 'rejected: the server did not prove it knows the word' "$out/c4" && grep -q 'vault ok=true' "$out/v" && grep -q 'dropper back .* same=true' "$out/d" && [[ $(grep -c 'over, success=' "$out/srv") -eq 2 ]]; then echo "SERVER RESULT: ok"; else echo "SERVER RESULT: FAILED"; fi
rm -rf "$out"
