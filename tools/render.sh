#!/usr/bin/env bash
# Render a scene off-screen on the real GPU and save frames as PNG.
#
#   tools/render.sh <out-dir> [frames] [-- game args...]
#   tools/render.sh renders/lineup 1 -- --mode=lineup
#
# Frames land in <out-dir>/f00000000.png ... (Godot movie writer, fixed 30 fps,
# so results are deterministic and independent of real frame rate).
# Env: RES=1280x720  SCENE=res://path.tscn  KEEP_EVERY=n (delete other frames)
#      LAST=1 (keep only the final frame, as <out-dir>/last.png: use for stills)
#      NOMOVIE=1 (run realtime, no frame dump: use for fps measurements)
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v godot >/dev/null || ! command -v sway >/dev/null; then
  exec nix develop -c "$0" "$@"
fi

out=${1:?usage: render.sh <out-dir> [frames] [-- game args]}; shift
frames=1
if [[ ${1:-} =~ ^[0-9]+$ ]]; then frames=$1; shift; fi
[[ ${1:-} == -- ]] && shift

# --- headless compositor -----------------------------------------------------
# Godot needs a real display to render; --headless disables rendering entirely.
# A headless sway gives it a Wayland surface backed by the GPU that nobody sees.
rt=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
dpyfile=$rt/heartstone-sway.display
sway_up() { [[ -f $dpyfile && -S $rt/$(cat "$dpyfile") ]]; }
if ! sway_up; then
  rm -f "$dpyfile"
  cmd="env -u WAYLAND_DISPLAY -u DISPLAY WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 sway -c $PWD/tools/sway-headless.conf"
  if [[ -n ${TMUX:-} ]]; then
    tmux new-window -d -n heartstone-sway "$cmd"
  else
    setsid nohup $cmd >"$rt/heartstone-sway.log" 2>&1 &
  fi
  for _ in $(seq 50); do sway_up && break; sleep 0.1; done
  sway_up || { echo "headless sway failed to start" >&2; exit 1; }
fi
export WAYLAND_DISPLAY=$(cat "$dpyfile")

# class_name lookups come from the editor's import cache; refresh it when scripts change.
cache=.godot/global_script_class_cache.cfg
if [[ ! -f $cache || -n $(find src -name '*.gd' -newer $cache -print -quit) ]]; then
  godot --headless --path . --import >/dev/null 2>&1 || true
  touch $cache
fi

# --- render ------------------------------------------------------------------
res=${RES:-1280x720}
args=(--path . --display-driver wayland --rendering-method forward_plus --resolution "$res")
if [[ -z ${NOMOVIE:-} ]]; then
  mkdir -p "$out"; rm -f "$out"/f*.png "$out"/f.wav
  args+=(--write-movie "$out/f.png" --fixed-fps 30 --quit-after "$frames")
fi
[[ -n ${SCENE:-} ]] && args+=("$SCENE")
# Script errors can leave Godot alive after the last frame: never wait forever.
timeout "${TIMEOUT:-240}" godot "${args[@]}" -- "$@" 2>&1 | grep -vE "^(Godot Engine|\$)|FIFO protocol|xdg-toplevel-icon|wayland_thread.cpp|^-+\$|render time:|Encoding time:|recorded in|Movie Maker mode" || true

if [[ -z ${NOMOVIE:-} ]]; then
  rm -f "$out/f.wav"
  if [[ -n ${KEEP_EVERY:-} ]]; then
    i=0; for f in "$out"/f*.png; do (( i++ % KEEP_EVERY == 0 )) || rm "$f"; done
  fi
  if [[ -n ${LAST:-} ]]; then
    last=$(ls "$out"/f*.png | tail -n 1)
    for f in "$out"/f*.png; do [[ $f == "$last" ]] || rm "$f"; done
    mv "$last" "$out/last.png"; echo "$out/last.png"; exit 0
  fi
  ls "$out"/f*.png | tail -n 1
fi
