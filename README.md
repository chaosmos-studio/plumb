# Tilt

A minimalist marble-sorting puzzle. Swipe and the whole board tilts: every marble rolls until something
stops it, and a marble drops into a hole of its own colour. Clear the board in as few tilts as you can.

**Play the web preview: https://shravangoswami.com/tilt/** (swipe, or arrow keys / WASD; Z undo, R restart,
H hint). The preview updates on every push to `main`.

Godot 4.7, GL Compatibility, 2D, portrait, Android first. 120 levels, every one generated and proven
solvable by the solver, with the solver's shortest route as par.

## Run it

```
godot --path .                                          # play on the desktop
godot --headless --path . -s res://tests/run_tests.gd   # rules, solver, scoring, and a re-solve of every level
godot --headless --path . res://tools/smoke.tscn        # a robot plays six levels through the real screens
DISPLAY=:0 godot --path . --resolution 720x1280 res://tools/shots.tscn   # screenshots of every screen
```

## Regenerate

```
godot --headless --path . -s res://tools/generate_levels.gd   # levels/levels.json (about 90 s)
python3 tools/make_sfx.py                                     # assets/audio/sfx (numpy, ffmpeg)
python3 tools/make_icons.py                                   # web/ icons and assets/branding/icon.png (Pillow)
```

`PLAN.md` is the design and the roadmap, `MATH.md` explains the rules, the solver and the generator,
and `CREDITS.md` lists the one third-party asset (the font).
