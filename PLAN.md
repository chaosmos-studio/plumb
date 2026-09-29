# Tilt - game design and build plan

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
  Baloo 2 (OFL). See `CREDITS.md`.
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

Nine tiers in `scripts/tilt/generator.gd`: board size, colours, marbles per colour, wall density, pits,
and a par window. A random board is kept only if the solver proves it solvable with a par inside the
window, so difficulty is the par curve (1 at level 1, 13 by level 120), not a guess. Within a tier,
levels are sorted by par.

The fairness invariant: every shipped level solves in exactly its stated par under the current rules.
`tests/run_tests.gd` re-solves all 120 on every run, so a rule change can never silently break the
level set.

## 4. Screens

- **Title**: the wordmark, a seesaw of marbles rolling back and forth, Play (continues at the first
  unsolved level), Levels, a sound toggle, the star total.
- **Levels**: twenty tiles a page with the stars each has earned; the next level in the accent colour;
  later levels locked.
- **Play**: level and par, the board, Undo and Restart, Hint, one line of guidance on the levels that
  introduce something, the result card (stars, moves against par, Next), and a pit banner (Undo).

## 5. Monetization

Later, and only in ways that never touch difficulty:

- Hints become rewarded: a few free per day, more for a rewarded ad.
- An interstitial every few levels, capped, never mid-level.
- A one-time "remove ads" purchase.

## 6. Project architecture

```
autoload/    event_bus, save (progress, settings), pack (the level set), audio, screens (fades)
scripts/tilt board.gd (rules), tilt_move.gd, solver.gd (BFS), generator.gd (tiers)
scripts/kit  palette, ui (code-built theme), stars (scoring), star_icon
scenes/game  game.gd (play screen), board_view.gd, marble, ripple, hint_arrow
scenes/shell title.gd, seesaw.gd, levels.gd
levels/      levels.json, written by tools/generate_levels.gd, never hand-edited
tools/       generate_levels.gd, make_sfx.py, make_icons.py, smoke (a robot player), shots (screenshots)
web/         the loading page and icons for the web build
```

The kit (`autoload/`, `scripts/kit/`, `scenes/shell/`, the smoke and shots harnesses, the web shell and
the deploy workflow) is shared with the other two mini games; only the rules, the board view and the
generator are Tilt's own.

## 7. Milestones

- **M0 - Is it fun**: rules, solver, generated levels, the play screen. Done.
- **M1 - The full loop**: title, level select, stars, progress, sounds, web preview. Done.
- **M2 - Feel pass**: marble trails, tray light that follows the tilt, a gentle ambient music bed.
- **M3 - Content**: new tile types generated the same way (one-way arrows, ice, sticky floor) past
  level 120, and daily puzzles from a date seed.
- **M4 - Monetization**: rewarded hints, capped interstitials, remove ads.
- **M5 - Store prep and ship**: Android preset, AAB, closed test with 12 testers for 14 days.

## 8. What would kill this

- Levels that feel random rather than designed. Watch the retention curve for where players stop;
  if it is inside one tier, that tier's par window is wrong.
- Levels with an obvious "just keep swiping" solution. If playtests show it, filter candidates that a
  random walk solves in under twice par.
