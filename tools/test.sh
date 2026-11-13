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
if [[ $(grep -hc 'success=true' "$out"/host "$out"/c1 "$out"/c2 | paste -sd+ | bc) -eq 3 ]]; then echo "NET RESULT: ok"; else echo "NET RESULT: FAILED"; fi
rm -rf "$out"
