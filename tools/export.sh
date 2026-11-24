#!/usr/bin/env bash
# Build the standalone game into dist/ (committed, so it can be pulled and played on a
# machine with no dev setup). Run before asking for a hands-on test, not every commit.
#   tools/export.sh
# dist/heartstone is the launcher: Godot's official export template is a generic Linux
# binary, which NixOS cannot run directly, so the launcher wraps it in the flake's FHS
# environment there and runs it directly everywhere else.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v godot >/dev/null || [[ -z ${GODOT_EXPORT_TEMPLATES:-} ]]; then
  exec nix develop -c "$0" "$@"
fi
# Godot only looks for templates under its data dir; point it at the Nix store copy
# without touching the real one.
data=$(mktemp -d)
mkdir -p "$data/godot" dist
ln -s "$GODOT_EXPORT_TEMPLATES" "$data/godot/export_templates"
# The data stays beside the executable here (dist/heartstone.pck): built in, the file
# came within a few MB of what GitHub takes. Releases embed it (the "Linux" preset).
# Stamp the build (its commit and that commit's time), so the game can say which
# side of a version mismatch is out of date. No tag: only releases update themselves.
printf '{"tag": "", "commit": "%s", "date": %s}\n' "$(git rev-parse --short HEAD)" "$(git log -1 --format=%ct)" > build.json
godot --headless --import >/dev/null 2>&1 || true
XDG_DATA_HOME=$data godot --headless --export-release "Linux (dist)" dist/heartstone.x86_64 2>&1 | grep -E "ERROR|WARNING|savepack|Export" | grep -v "X11 Display" || true
git rev-parse --short HEAD > dist/BUILD 2>/dev/null || true
date -u +%Y-%m-%dT%H:%MZ >> dist/BUILD
ls -la dist
