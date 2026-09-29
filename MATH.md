# Plumb - the math and the ideas

Lessons for the systems with a non-obvious idea behind them. Read a section, open the constant it
names, change it, and run the game. Each section ends with things to try.

---

## 1. A tilt is a discrete simulation, front first

A tilt could be physics: forces, friction, collisions. It is not, on purpose. The board is a grid, and a
tilt is repeated steps: in each step every marble that can move one cell does, and the tilt ends on the
first step where nothing moves.

The subtle part is a line of marbles. If the back marble is checked first, the cell ahead is still full,
so it waits a step while the front one moves, and the line spreads out like cars at a green light.
Real marbles roll together. So `TiltBoard.tilt()` sorts marbles by how far along the direction of travel
they are and advances the front one first; by the time the back one is checked, the cell ahead has
emptied. One sort per tilt, and a line of marbles rolls as a train.

A marble that rolls over a hole of its own colour drops in during that step, which frees its cell for
the marble behind it in the same step: two marbles of one colour in a line both go in on one tilt.

### Things to try

- In `board.gd`, reverse the sort and play level 13: lines of marbles leave gaps. The solver still
  works, but par changes, which `tests/run_tests.gd` will report.

## 2. Par is a breadth-first search, and it doubles as the hint

`TiltSolver` explores tilts level by level: all positions one tilt away, then two, and so on. The first
solved position it meets is therefore a shortest solution. Its length is par, and its first move is the
hint. The search stores only where the live marbles are (walls, holes and pits never change), sorted,
as a string key, so two positions that differ only in which identical marble is where count as one.

The state space is far smaller than it looks. After any tilt, most marbles rest against a wall or
another marble, so few positions are reachable at all. Measured on the shipped set: the hardest level
needs 737 positions before the search meets par, the average is 82, and re-solving all 120 levels takes
under a second. Counting free cells would suggest billions.

A position with a marble down a pit is never expanded: it can only be escaped by undo, which the search
does not model.

### Things to try

- `TiltSolver.DEFAULT_LIMIT` caps the search. Set it to 200 and ask for hints on late levels: some
  return nothing. That is why the game passes a larger limit for hints than the generator uses.

## 3. Levels by rejection: propose, solve, keep or throw away

`TiltGenerator` does not build levels. It proposes random ones for a tier (walls at a density, pits,
one hole per colour, marbles) and keeps a proposal only if the solver proves it solvable with a par
inside the tier's window. Most proposals are thrown away. In the last tier it is the solver's time on
rejected boards that dominates the 86 seconds the whole set takes.

Rejection sampling needs no idea of what makes a level hard. The par window is the idea: too easy and
the solver finds it in fewer moves, too tangled and it exceeds the window or the search limit. Sorting
within a tier by par gives each tier a slope.

The generator owns its RNG and shuffles with its own Fisher-Yates, so the level set depends on the seed
alone: `tools/generate_levels.gd -- seed=2026` always writes the same file.

### Things to try

- Widen tier 8's window to `[6, 13]` and regenerate: the late game gets easier, because the solver
  finds short solutions to many dense boards.

## 4. Stars with a leeway that grows

Three stars means par. Two stars allows `max(2, ceil(par / 2))` extra moves (`scripts/kit/stars.gd`),
because two extra moves on a par-2 board is a different solve, while four extra on a par-13 board is
still a good one.

## 5. The title seesaw: one dimension of physics

The toy on the title is the one place with real physics, and it needs only one dimension: a position
along the bar per marble. Each frame, gravity along a bar tilted by `angle` accelerates each marble by
`g sin(angle)`, a little damping bleeds energy, and two marbles closer than a diameter are pushed apart
and trade speeds, which is what equal balls do in a head-on collision. The ends bounce with 40% of the
speed.

### Things to try

- `Seesaw.ROCK` is the tilt amplitude in radians. At 0.3 the marbles slam from end to end; at 0.04
  they barely drift.
