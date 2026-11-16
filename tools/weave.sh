#!/usr/bin/env bash
# One weave at three moments (being woven, loosed, landing) on one sheet, as the
# bot casts it: renders/weave_<id>.jpg.
#   tools/weave.sh fireball [game args...]        FR=frames (default 300)
#   DEMO=14 tools/weave.sh balefire               for weaves the bot will not choose:
#       woven outright 14 m ahead at frame 100, five moments after it.
cd "$(dirname "$0")/.."
if ! command -v godot >/dev/null; then exec nix develop -c "$0" "$@"; fi
id=$1; shift
out=renders/weave_$id
rm -rf "$out"
if [[ -n ${DEMO:-} ]]; then
  KEEP_EVERY=1 RES=1280x720 tools/render.sh "$out" 200 -- --auto --name=Review --stand --strength=1 --only=fireball --camyaw=${YAW:-50} --camdist=${DIST:-5} "--demo=$id:$DEMO" "${@:---spawn=dummy:4@12}" 2>&1 | grep -E "SCRIPT ERROR|Parse"
  (cd "$out" && montage f00000104.png f00000108.png f00000114.png f00000124.png f00000140.png f00000170.png -tile 3x2 -geometry 960x540+2+2 ../weave_$id.jpg)
  exit
fi
KEEP_EVERY=1 RES=1280x720 tools/render.sh "$out" "${FR:-300}" -- --auto --name=Review --log --strength=1 "--only=$id" --stand --camyaw=${YAW:-50} --camdist=${DIST:-5} "${@:---spawn=dummy:3@12}" 2>&1 | grep -E "^EV|SCRIPT ERROR|Parse" > "$out.log"
grep -E "SCRIPT|Parse" "$out.log"
python3 - "$id" "$out" <<'P'
import re,sys,os,subprocess
id,out=sys.argv[1:]
ev=[(int(m[1]),m[2]) for m in (re.match(r'EV (\d+) (\w+)',l) for l in open(out+'.log')) if m]
forms=[f for f,e in ev if e=='form']
if not forms: sys.exit('the bot never wove '+id+': try DEMO=14')
F=next((f for f in forms if f>=110),forms[0])
C=next((f for f,e in ev if f>F and e in('cast','loose','hold','gate_open')),F+30)
B=next((f for f,e in ev if f>=C and e=='blast'),None)
# (Frame numbers in the file names run about four behind the game's.)
pick=[int(F+0.5*(C-F))+4, int(F+0.95*(C-F))+4, C+7, (B+6) if B else C+12, (B+10) if B else C+18, (B+20) if B else C+30]
fs=['%s/f%08d.png'%(out,p) for p in pick if os.path.exists('%s/f%08d.png'%(out,p))]
subprocess.run(['montage',*fs,'-tile','3x2','-geometry','960x540+2+2','renders/weave_%s.jpg'%id])
P
