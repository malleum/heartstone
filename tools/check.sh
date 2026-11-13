#!/usr/bin/env bash
# Syntax-check every script without rendering (headless is fine for this).
cd "$(dirname "$0")/.."
command -v godot >/dev/null || exec nix develop -c "$0" "$@"
godot --headless --path . --import >/dev/null 2>&1
for f in $(find src -name '*.gd'); do
  timeout 30 godot --headless --path . --check-only --script "res://$f" 2>&1 | grep -A1 -E 'SCRIPT ERROR|Parse Error' | grep -v '^--$'
done
echo "check done"
