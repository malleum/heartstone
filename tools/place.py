"""Keep render windows from covering one another in the invisible compositor.

Every render's window opens floating at the middle of the output. Sway suspends a
window that another covers completely, and a suspended Godot keeps writing movie
frames while its fight stops stepping: a second render started alongside a first
froze the first (the controls test's lost tie). This moves each window that sits
over another into a free cell of the (large) output. Run by tools/render.sh in the
background, for a few seconds after a render starts; several can run at once,
since every copy makes the same choice from the same layout.
  python3 -I tools/place.py <sway socket> <seconds>
"""
import json, subprocess, sys, time

sock, secs = sys.argv[1], float(sys.argv[2])
CELL_W, CELL_H, COLS, ROWS = 2560, 1440, 2, 2   # output is 5120x2880 (sway-headless.conf)
cells = [(c * CELL_W, r * CELL_H) for r in range(ROWS) for c in range(COLS)]

def sway(*a):
    return subprocess.run(["swaymsg", "-s", sock, *a], capture_output=True, text=True).stdout

def windows(node, out):
    for n in node.get("floating_nodes", []) + node.get("nodes", []):
        if n.get("type") == "floating_con" and n.get("pid"):
            out.append(n)
        windows(n, out)
    return out

end = time.time() + secs
while time.time() < end:
    try:
        wins = sorted(windows(json.loads(sway("-t", "get_tree")), []), key=lambda w: w["id"])
    except (ValueError, KeyError):
        wins = []
    taken = {}
    for w in wins:
        at = (w["rect"]["x"], w["rect"]["y"])
        if at in cells and at not in taken:
            taken[at] = w["id"]
    for w in wins:
        at = (w["rect"]["x"], w["rect"]["y"])
        if taken.get(at) == w["id"]:
            continue
        free = [c for c in cells if c not in taken]
        if not free:
            break
        taken[free[0]] = w["id"]
        sway(f"[con_id={w['id']}]", "move", "position", str(free[0][0]), str(free[0][1]))
    time.sleep(0.5)
