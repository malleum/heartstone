#!/usr/bin/env bash
# Written strokes, four to a sheet, one row per moment: wound up, mid-way, the blow,
# the follow-through. With no arguments, the sword forms (renders/strokes_1.png, _2);
# or name them, "weapon:move" for a weapon's own (renders/strokes_<n>.png):
#   tools/strokes.sh boar_spear:spear_thrust quarterstaff:cut hands:kick aiel_spear:spear_jab
#   YAW=20 tools/strokes.sh        (YAW=160 for the back, YAW=90 side-on)
cd "$(dirname "$0")/.."
if [ $# -gt 0 ]; then all=("$@"); else all=(parting_the_silk boar_rushes apple_blossoms heron_wading swallow_flight courtier_fan arc_of_the_moon sheathing_the_sword); fi
n=$(( (${#all[@]} + 3) / 4 ))
for k in $(seq 1 $n); do
  set=$(IFS=,; echo "${all[*]:$(( (k-1)*4 )):4}")
  TEST=1 RES=1600x520 KEEP_EVERY=1 tools/render.sh renders/strokes$k 44 -- --mode=heroes --strokes --only=$set --quiet --dist=${DIST:-3.6} --yaw=${YAW:-20} --camy=1.4 --aty=1.15 --at=10 --land=0.5 --after=0.5 2>&1 | grep -i "error"
  (cd renders/strokes$k && montage f00000015.png f00000024.png f00000029.png f00000036.png -tile 1x4 -geometry +0+2 ../strokes_$k.png)
done
