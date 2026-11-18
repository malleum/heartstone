#!/usr/bin/env bash
# Characters caught mid-blow and mid-weave, close up and side-on, no HUD: one sheet
# per class (six blows each) and one of channellers weaving (each weave as it is
# made and as it is loosed). Writes renders/poses_<name>.jpg; pass a name to do one.
#   tools/poses.sh [warder|aiel|hunter|weaves]
cd "$(dirname "$0")/.."
command -v godot >/dev/null || exec nix develop -c "$0" "$@"
cam=(--camyaw=${YAW:-80} --camdist=${DIST:-3.2} --campitch=${PITCH:--8})
fighter() {   # name kit
  local out=renders/poses_$1
  rm -rf "$out"
  KEEP_EVERY=1 RES=960x720 tools/render.sh "$out" 520 -- --auto --name=Pose --class=$1 --kit=$2 --forms --stand --clean --log "${cam[@]}" --spawn=trolloc:2@3 2>&1 | grep -E "^BLOW|SCRIPT ERROR" > "$out.log"
  # The frame where the blade is on its way in: the wind-up is over, the blow not
  # yet landed (file names run about four frames behind the game's count).
  python3 -I - "$out" <<'P'
import re, sys, os, subprocess
out = sys.argv[1]
seen, picks = set(), []
for l in open(out + ".log"):
    m = re.match(r"BLOW (\d+) (\w+) wind=([\d.]+)", l)
    if not m: continue
    f = int(m[1]) + int(float(m[3]) * 30 * 0.6) + 4
    if os.path.exists("%s/f%08d.png" % (out, f)) and (m[2] not in seen or len(picks) < 3):
        seen.add(m[2]); picks.append("%s/f%08d.png" % (out, f))
    if len(picks) == 6: break
if not picks: sys.exit("no blows in " + out)
subprocess.run(["montage", *picks, "-tile", "3x2", "-geometry", "640x480+2+2", out + ".jpg"])
P
  rm -rf "$out"
}
weaver() {    # weave
  local out=renders/poses_w_$1
  rm -rf "$out"
  KEEP_EVERY=1 RES=960x720 tools/render.sh "$out" 300 -- --auto --name=Pose --strength=6 --only=$1 --stand --clean --log "${cam[@]}" --spawn=dummy:2@10 2>&1 | grep -E "^EV|SCRIPT ERROR" > "$out.log"
  python3 -I - "$out" <<'P'
import re, sys, os
out = sys.argv[1]
ev = [(int(m[1]), m[2]) for m in (re.match(r"EV (\d+) (\w+)", l) for l in open(out + ".log")) if m]
forms = [f for f, e in ev if e == "form"]
if not forms: sys.exit(0)
F = next((f for f in forms if f >= 60), forms[0])
C = next((f for f, e in ev if f > F and e in ("cast", "loose", "hold")), F + 30)
for name, f in (("a", int(F + 0.6 * (C - F)) + 4), ("b", C + 6)):
    src = "%s/f%08d.png" % (out, f)
    if os.path.exists(src): os.replace(src, "%s_%s.png" % (out, name))
P
  rm -rf "$out"
}
want=${1:-all}
[[ $want == all || $want == warder ]] && fighter warder sword,throwing_knives,belt_knife
[[ $want == all || $want == aiel ]] && fighter aiel aiel_spear,javelins,aiel_knife
[[ $want == all || $want == hunter ]] && fighter hunter quarterstaff,longbow,sling
if [[ $want == all || $want == weaves ]]; then
  ws=(fireball lightning water_lash heave_the_ground hammer_of_air blade_of_spirit)
  for w in "${ws[@]}"; do weaver $w; done
  shots=(); for w in "${ws[@]}"; do shots+=(renders/poses_w_${w}_a.png renders/poses_w_${w}_b.png); done
  ls "${shots[@]}" 2>/dev/null | xargs -r -I{} echo {} | xargs montage -tile 4x3 -geometry 480x360+2+2 renders/poses_weaves.jpg
  rm -f renders/poses_w_*
fi
ls renders/poses_*.jpg
