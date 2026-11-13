#!/usr/bin/env bash
# Contact sheet from a frame sequence: tools/sheet.sh <dir> <every-nth> [cols] [crop WxH+X+Y]
set -euo pipefail
dir=$1; nth=${2:-6}; cols=${3:-4}; crop=${4:-}
files=(); i=0
for f in "$dir"/f0*.png; do (( i++ % nth == 0 )) && files+=("$f"); done
montage "${files[@]}" ${crop:+-crop "$crop" +repage} -tile "${cols}x" -geometry +2+2 -background '#222' -resize "${WIDTH:-1400}x" "$dir/sheet.png"
echo "$dir/sheet.png"
