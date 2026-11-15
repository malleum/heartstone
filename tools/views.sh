#!/usr/bin/env bash
# Three views of one bench subject on one sheet: front close, behind, side.
#   tools/views.sh <name> [bench args...]      e.g. tools/views.sh fade --species=myrddraal
# Writes renders/<name>_sheet.png.
cd "$(dirname "$0")/.."
name=$1; shift
r() { TEST=1 RES=1280x720 KEEP_EVERY=10 tools/render.sh "renders/${name}_$1" 11 -- --mode=lineup --n=2 "--dist=$2" "--camy=$3" "--aty=$4" "--yaw=$5" "${@:6}" 2>&1 | grep -i "error"; }
r a 2.0 2.0 1.95 20 "$@"; r b 3.2 1.9 1.6 115 "$@"; r c 2.4 1.95 1.9 -80 "$@"
montage "renders/${name}_a/f00000010.png" "renders/${name}_b/f00000010.png" "renders/${name}_c/f00000010.png" -tile 1x3 -geometry +0+0 "renders/${name}_sheet.png"
