#!/usr/bin/env bash
# One bench creature's face, front and three-quarter, side by side: renders/face_<name>.jpg
#   tools/face.sh draghkar --species=draghkar
cd "$(dirname "$0")/.."
if ! command -v godot >/dev/null; then exec nix develop -c "$0" "$@"; fi
name=$1; shift
for t in 0 50; do TEST=1 KEEP_EVERY=10 RES=1600x900 tools/render.sh "renders/face_${name}_$t" 11 -- --mode=lineup --n=1 --face=0.8 --turn=$t "$@" 2>&1 | grep -E "SCRIPT ERROR|Parse"; done
montage "renders/face_${name}_0/f00000010.png" "renders/face_${name}_50/f00000010.png" -tile 2x1 -gravity center -crop 900x900+0+0 +repage -geometry +2+0 "renders/face_$name.jpg"
