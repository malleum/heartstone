#!/usr/bin/env python3
"""Write docs/TOUR.md from the tour table in src/game/launch.gd, so the numbers in the game
and on paper always agree. Run after changing the tour: python3 tools/tourdoc.py"""
import re, os
root = os.path.join(os.path.dirname(__file__), "..")
src = open(os.path.join(root, "src/game/launch.gd")).read()
rows = re.findall(r'\{sec = "([^"]*)", title = "([^"]*)", test = "((?:[^"\\]|\\.)*)", feel = "((?:[^"\\]|\\.)*)"', src)
out = ["# The tour: every mechanic, one station each", "",
       "Start it with `heartstone --tour` (or `--tour=N` to begin at station N). Each station is a",
       "throwaway character in front of one thing; nothing is saved. **N** next, **B** back,",
       "**R** again, **F1** hides the card, **F10** to the camp. When something is wrong, say its",
       "number (\"#37: the pike thrust goes sideways\").", "",
       "Generated from `src/game/launch.gd` by `tools/tourdoc.py`.", ""]
sec = None
for i, (s, title, test, feel) in enumerate(rows, 1):
    if s != sec:
        sec = s
        out += ["", "## " + s, "", "| # | Station | Test | Notes |", "|---|---|---|---|"]
    clean = lambda t: t.replace('\\"', '"').replace("\\n", " ").replace("|", "/")
    out.append("| %d | %s | %s | %s |" % (i, clean(title), clean(test), clean(feel)))
out += ["", "## Not in the tour", "",
        "In the camp (walk there after the last station, or start the game normally):",
        "- The doorways show a picture of the place they open on; the live view takes over as you come up.",
        "- Stations on the open side: the armoury, the tailor (face shaping: width, jaw, chin, nose, cheeks, brow), the study (loadout). Walk up, press E.",
        "- Making a character: Aiel societies and Hunter kits are at the top of the right panel; fighters' gifts below.",
        "- Dream bar keys can be rebound in the camp.",
        "",
        "Needs a second person:",
        "- Linking into a circle (L): a woman leads, others near her offer.",
        "- Tying someone with rope (hold K over them).",
        "- A Darkfriend among us (the hidden traitor mode), and walking through a doorway together.",
        "- Movement prediction over a real connection.", ""]
open(os.path.join(root, "docs/TOUR.md"), "w").write("\n".join(out))
print(len(rows), "stations")
