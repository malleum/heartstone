#!/usr/bin/env bash
# The pictures in the camp's doorways: each place a doorway can open onto, rendered
# once by the game itself (no HUD, nobody in it) and kept small in assets/postcards/.
# Rerun after a map changes. Usage: tools/postcards.sh [setup ...]
cd "$(dirname "$0")/.."
command -v godot >/dev/null || exec nix develop -c "$0" "$@"
mkdir -p assets/postcards
# setup name  activity  camera yaw (deg)  pitch (deg)
ALL="tarwins_day:holdout@tarwins_day:20:-6 tarwins_night:holdout@tarwins_night:20:-6 wagon_ring:holdout@wagon_ring:0:-8 wild_hunt:holdout@wild_hunt:0:-6 camp_training:camp_training:0:-8 dream_spar:dream_spar:0:-6 team_battle:team_battle:0:-6"
want=("$@")
for row in $ALL; do
	IFS=: read -r name act yaw pitch <<<"$row"
	if [[ ${#want[@]} -gt 0 && ! " ${want[*]} " =~ " $name " ]]; then continue; fi
	out=renders/postcard_$name
	rm -rf "$out"
	# (A bot that knows nothing, so no weave is in the picture; the doorway is tall,
	# so the middle of the frame is cut out at its shape, 1.9 by 3.3.)
	KEEP_EVERY=40 tools/render.sh "$out" 81 -- --activity=$act --auto --stand --clean --hideme --only=none --name=Postcard --camyaw=$yaw --campitch=$pitch --camdist=1.5 >/dev/null 2>&1
	magick "$out/f00000080.png" -gravity center -crop 415x720+0+0 +repage -resize 300x521 -quality 82 "assets/postcards/$name.jpg" && echo "postcard $name"
done
