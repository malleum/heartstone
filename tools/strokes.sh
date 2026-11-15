#!/usr/bin/env bash
# The written sword forms, four to a sheet, one row per moment: wound up, mid-way,
# the blow, the follow-through. Writes renders/strokes_1.png and strokes_2.png.
#   YAW=20 tools/strokes.sh        (YAW=160 for the back)
cd "$(dirname "$0")/.."
all=(parting_the_silk boar_rushes apple_blossoms heron_wading swallow_flight courtier_fan arc_of_the_moon sheathing_the_sword)
for k in 1 2; do
  set=$(IFS=,; echo "${all[*]:$(( (k-1)*4 )):4}")
  TEST=1 RES=1600x520 KEEP_EVERY=1 tools/render.sh renders/strokes$k 44 -- --mode=heroes --strokes --only=$set --quiet --dist=${DIST:-3.6} --yaw=${YAW:-20} --camy=1.4 --aty=1.15 --at=10 --land=0.5 --after=0.5 2>&1 | grep -i "error"
  (cd renders/strokes$k && montage f00000015.png f00000024.png f00000029.png f00000036.png -tile 1x4 -geometry +0+2 ../strokes_$k.png)
done
