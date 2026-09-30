# Plumb - game design and build plan

The living design document: what we are building, how the code is organised, and the order we build it
in. When a decision changes, update this file. Shared working rules live in the workspace `CLAUDE.md`;
the systems lessons live in `MATH.md` next to this file.

## 1. Vision

A board of coloured marbles and matching holes. Swipe and the whole board tilts: every marble rolls at
once until something stops it, and a marble that rolls over a hole of its own colour drops in. Clear
the board in as few tilts as you can. It is a sort puzzle, the part of the market where small studios
still earn (see the workspace research of 2026-09-26), with a hook sort puzzles lack: one gesture moves
everything, so every move is a small chain of consequences to read before you make it.

### Design pillars

1. **One gesture, every marble.** The player never picks up a piece. Planning is about where
   everything ends up, which is what makes a four-direction game deep.
2. **Every level is proven.** Levels come from a generator and a solver. The solver's shortest route
   is the level's par, three stars means you found it, and the hint is the solver's next move.
3. **Quiet and tactile.** Warm paper, soft shapes, a tray that tips, marbles that squash on walls, and
   a bell per colour, so any clear sounds like a chord.

### Target and constraints

- Platform: Android first (Google Play), portrait. The web build on GitHub Pages is the preview.
- Engine: Godot 4.7, GL Compatibility renderer, 2D.
- Audience: all ages.
- Art and audio: drawn and synthesised in code (`tools/make_sfx.py`, `tools/make_icons.py`). One font,
  Outfit (OFL), in two static weights. See `CREDITS.md`.
- Monetization: section 5, built last.

### What this is not

Not a physics game: marbles move on the grid, one cell per step, so the solver and the player see the
same rules. No timers, no lives, no energy. No hand-made levels.

## 2. Core mechanics

- **Tilt** (swipe, arrow keys or WASD): every marble rolls one cell per step in that direction until a
  wall, the edge or another marble stops it. Marbles move front first, so a line rolls as a train.
- **Holes** accept any number of marbles of their colour, the moment one rolls over them. Marbles roll
  straight over holes of other colours.
- **Pits** (square voids) swallow any marble and lose the level. Undo is one tap.
- **Undo** steps back one tilt and gives the move back. **Restart** returns to the start. **Hint**
  points the way the solver would tilt next, from wherever the board is now.
- A tilt that moves nothing is not a move: the tray twitches and nothing is counted.

## 3. Difficulty

Thirteen phases in `scripts/tilt/generator.gd` fix the board size, colours, marbles, wall density, pits
and a par window, and from phase to phase each only grows: one marble on 4x4 at level 1, a second marble
sharing its hole at level 9, a second colour at 17, the first pit at 35, and four colours, eight marbles
and three pits on 7x8 from level 105. A random board is kept only if the solver proves it solvable
inside the window.

Difficulty is measured, not guessed. The score is the bits of luck a player tilting at random needs to
clear the board in par (`scripts/tilt/difficulty.gd`, `MATH.md` section 5). Each phase pools candidates
and keeps the run that follows a ramp in both par and bits, par 1 to 13 and 1.6 to 18.4 bits over the
120 levels, so neither ever falls from one level to the next. Each new mechanic arrives on a level no
harder than the one before it.

No level repeats another. Compared over the eight rotations and mirrors with colour ignored, two boards
of one size must differ in 30% of their cells, or in half of them when one solution clears both
(`scripts/tilt/novelty.gd`, `MATH.md` section 4).

The fairness invariants, all checked from the boards by `tests/run_tests.gd` on every run: every shipped
level solves in exactly its stated par under the current rules, no level replays another, none is easier
than the one before, par never falls, no level takes away room, a colour, a marble or a pit, and every
pit level has a pit in play. A rule change can never silently break the level set.

## 4. Screens

- **Title**: the wordmark, a seesaw of marbles rolling back and forth, Play (continues at the first
  unsolved level), Levels, the star total.
- **Levels**: twenty tiles a page with the stars each has earned; the next level in the accent colour;
  later levels locked.
- **Play**: level and par, the board, Undo and Restart, Hint, one line of guidance on the levels that
  introduce something, the result card (stars, moves against par, Next), and a pit banner (Undo).
- **Settings**, a gear on every screen: sound, music, vibration, the theme (Auto, Light or Dark), How to
  play, About, Credits, and a guarded reset.
- **The guide** on level 1, once, and again from How to play: the goal and the help buttons on two
  cards, then the swipe itself, drawn by a ghost finger in the direction the solver would tilt next.
  Skip ends it at any point.
- **The ending**, after the last level is solved for the first time: a note from Shravan, signed, and
  on the web a GitHub Sponsors button. Google Play has made apps remove links like it, so the Android
  build shows the note alone (`GameCredits.SPONSOR_ON_ANDROID`).

Plumb is designed in its warm paper light; its dark theme is the same room at dusk, with walls lighter
than the floor so walls, floor and pits still read as three heights.

## 5. Monetization

Later, and only in ways that never touch difficulty:

- Hints become rewarded: a few free per day, more for a rewarded ad.
- An interstitial every few levels, capped, never mid-level.
- A one-time "remove ads" purchase.

## 6. Project architecture

```
autoload/    event_bus, save (progress, settings), pack (the level set), audio, screens (fades)
scripts/tilt board.gd (rules), tilt_move.gd, solver.gd (BFS), difficulty.gd (bits of luck),
             novelty.gd (replays), generator.gd (phases and the ramp)
scripts/kit  palette, ui (code-built theme), stars (scoring), star_icon
scenes/game  game.gd (play screen), board_view.gd, marble, ripple, hint_arrow
scenes/shell title.gd, seesaw.gd, levels.gd
levels/      levels.json, written by tools/generate_levels.gd, never hand-edited
tools/       generate_levels.gd, make_sfx.py, make_icons.py, smoke (a robot player), shots (screenshots)
web/         the loading page and icons for the web build
```

The kit (`autoload/`, `scripts/kit/`, `scenes/shell/`, the smoke and shots harnesses, the web shell and
the deploy workflow) is shared with the other two mini games; only the rules, the board view and the
generator are Plumb's own.

## 7. Milestones

- **M0 - Is it fun**: rules, solver, generated levels, the play screen. Done.
- **M1 - The full loop**: title, level select, stars, progress, sounds, web preview. Done.
- **M2 - Feel pass**: marble trails, marbles popping in at level start, and an ambient music loop with its
  own toggle are done. Still to do: a tray light that follows the tilt.
- **M3 - Content**: new tile types generated the same way (one-way arrows, ice, sticky floor) past
  level 120, and daily puzzles from a date seed.
- **M4 - Monetization**: rewarded hints, capped interstitials, remove ads.
- **M5 - Store prep and ship**: Android preset, AAB, closed test with 12 testers for 14 days.

## 8. What would kill this

- Levels that feel random rather than designed. Watch the retention curve for where players stop;
  if it is inside one phase, that stretch of the ramp is too steep.
- Levels with an obvious "just keep swiping" solution. The bits score is exactly how often random
  swiping finds par, so if playtests show it, raise the ramp's floor rather than guess.
