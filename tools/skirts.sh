#!/usr/bin/env bash
# The gowns standing and walking, two sheets' worth: renders/skirt_idle, renders/skirt_walk.
cd "$(dirname "$0")/.."
L=${LOOKS:-two_rivers_f,novice,accepted,wise_one,cairhien_f,domani_f}
TEST=1 RES=1600x900 KEEP_EVERY=10 tools/render.sh renders/skirt_idle 21 -- --mode=heroes --looks=$L --quiet --dist=4.6 2>&1 | grep -i "error"
TEST=1 RES=1600x900 KEEP_EVERY=6 tools/render.sh renders/skirt_walk 43 -- --mode=heroes --looks=$L --quiet --dist=4.6 --clip=${CLIP:-Walk} --yaw=${YAW:-60} 2>&1 | grep -i "error"
