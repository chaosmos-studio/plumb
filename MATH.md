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

- In `board.gd`, reverse the sort and play level 11, where two marbles start side by side: lines of
  marbles leave gaps. The solver still works, but par changes, which `tests/run_tests.gd` will report.

`tilt()` is also the hot path of everything else: the generator makes millions of tilts. Its
front-first order is an insertion sort over a few marbles, and the cell ahead is found by adding a
stride, which makes a tilt on an eight-marble board 17 µs instead of 44. The level set it generates is
byte-identical either way, which is the proof that no roll changed.

## 2. Par is a breadth-first search, and it doubles as the hint

`TiltSolver` explores tilts level by level: all positions one tilt away, then two, and so on. The first
solved position it meets is therefore a shortest solution. Its length is par, and its first move is the
hint. The search stores only where the live marbles are (walls, holes and pits never change), sorted,
as a string key, so two positions that differ only in which identical marble is where count as one.

The state space is far smaller than it looks. After any tilt, most marbles rest against a wall or
another marble, so few positions are reachable at all. Measured on the shipped set: the hardest level
needs 984 positions before the search meets par, the average is 122, and re-solving all 120 levels
takes 0.6 seconds. Counting free cells would suggest billions.

A position with a marble down a pit is never expanded: it can only be escaped by undo, which the search
does not model.

### Things to try

- `TiltSolver.DEFAULT_LIMIT` caps the search. Set it to 200 and ask for hints on late levels: some
  return nothing. That is why the game passes a larger limit for hints than the generator uses.

## 3. Levels by rejection: propose, solve, keep or throw away

`TiltGenerator` does not build levels. It proposes random ones for a phase (a board size, walls at a
density, pits, one hole per colour, marbles) and keeps a proposal only if the solver proves it solvable
with a par inside the phase's window. Most proposals are thrown away: in the last phase, eight marbles
and three pits on a 7x8 board, 98.5% of random boards have no solution inside the window. A cheap flood
fill (`_open`) throws out over a quarter of those, the ones where open floor does not even join a marble
to its hole, before the solver sees them.

Rejection sampling needs no idea of what makes a level hard. What it does need is a measure of the
levels it keeps (section 5), a rule for when two of them are the same (section 4), and a way to pick,
from everything it kept, a run that climbs (section 6).

The generator owns its RNG and shuffles with its own Fisher-Yates, so the level set depends on the seed
alone: `tools/generate_levels.gd -- seed=2026` always writes the same file, byte for byte. Runs of the
shipped seed take about two and a half minutes on a machine running other jobs, nearly half of it in the
last phase.

---

## 4. When two levels are the same level

A board turned a quarter or seen in a mirror is the same puzzle: the grid has eight symmetries (four
rotations, four reflections), and every direction maps with it. A board with its colours swapped is the
same puzzle too. `TiltNovelty.canonical()` writes the board out under all eight, relabels colours in the
order they first appear, and keeps the smallest string, so two boards share it exactly when one is the
other turned, flipped or recoloured. The old level set had no such exact repeats. Its problem was near
repeats, which a player notices just as much.

Near means few cells apart. Each cell is reduced to what it is, ignoring colour: floor, wall, pit, hole
or marble. The distance between two boards of one size is the fewest cells in which they differ over
the eight views of one of them. Ignoring colour errs toward calling boards the same. Two rules use it:

- **Layout.** Two boards must differ in at least 30% of their cells: 5 of 16 on a 4x4 board, 8 of 25,
  9 of 30, 11 of 36, 13 of 42, 15 of 49 and 17 of 56. A share rather than a count, because two cells
  are a big change on a 4x4 board and a speck on a 7x8 one.
- **Route.** If one board's shortest solution, turned into the other's frame, also clears the other at
  the same par, the two must differ in at least half their cells. Short solutions come in very few
  shapes: up to symmetry there is one one-tilt solution and two two-tilt ones (a turn, or there and
  back). Two sparse boards that both solve with "right, then down" play identically even when their
  walls differ, which is exactly why the old levels 2 and 3 felt like one level.

`TiltNovelty.clash()` applies both. The generator checks every candidate against every level already
kept and against its own pool, so the pool is pairwise new and any run chosen from it is too.
`tests/run_tests.gd` checks all 7,140 pairs of shipped levels with the same code.

Measured on the old set: no exact repeats, 37 pairs closer than 30% of their cells, and 53 pairs that
clash under the full rule, all within the first 66 levels. Levels 2 and 3 differed in 2 of 16 cells,
levels 11 and 13 in 2 of 25. The new set has none: its closest pairs sit between 30% and 35% apart.

### Things to try

- Raise `ROUTE_SHARE` to 0.6 and regenerate: the one-marble phases run out of new boards, and the
  generator's report shows their pools shrinking against the attempt cap.

---

## 5. Difficulty you can measure: bits of luck

Take a player who tilts at random, choosing evenly among the tilts that move something. Let p be the
chance that they clear the board in exactly par tilts. The level's score is

    bits = -log2(p)

the bits of luck a blind guess needs: each bit halves the chance. It is also what the game scores,
since three stars means par. A level where one tilt in three wins is worth 1.6 bits; the last level of
the new set is worth 18.1, a chance of about one in 280,000.

p is computed exactly, not sampled, on the graph the solver already builds (`TiltDifficulty.of`). A walk
that wins in par tilts must stand, after d tilts, on a position first reached at depth d: if it ever
fell behind, the rest of par would be too short. So the chance is carried forward layer by layer. Each
position shares its chance evenly among its moving tilts; chance that flows to a position first seen one
layer deeper is kept, chance that flows back, sideways or into a pit is lost, and whatever reaches a
cleared board at depth par is p. It is the solver's own breadth-first search, finished to the end of its
last layer, and measuring all 120 levels takes 0.7 seconds. A Monte Carlo player would need millions of
games to see a one-in-280,000 event at all.

Why it is the right proxy:

- **Par is the backbone.** Along a single route with k moving tilts at each step, bits is the sum of
  log2(k): par times the log of the branching. Across the new set bits runs from 1.0 to 1.8 per move of
  par, and its correlation with par is 0.995.
- **At one par, it sees the rest.** A level with more tempting wrong tilts scores higher; one with more
  routes to par scores lower. More marbles mean fewer tilts that move nothing and fewer routes that work
  for all of them at once: in the old set, par-4 levels averaged 3.6 bits with one marble, 5.1 with two
  and 6.5 with four.
- **Pits count as the game counts them.** A tilt into a pit is one more wrong tilt, no worse than any
  other, because undo gives the move back. A pit makes a level harder when it turns a tilt that did
  nothing into one that loses, or cuts a route. `risk`, the chance lost to pits, tells whether a pit is
  in play at all; every pit level ships with one that is. In two of the old pit levels, 52 and 56, no
  tilt could reach a pit before par.

The alternatives are weaker. Par alone has 13 values for 120 levels and sees nothing but length. The
count of positions searched spans more than an order of magnitude at one par (24 to 450 among the new
par-11 levels) and grows with marbles far faster than a level gets harder. It does serve as the
tie-break: bits values sit on a lattice of sums of log2 of 1 to 4, so several levels can share one, and
at equal bits the level with more positions closer than par, more for a planner to rule out, is the
harder one (`TiltDifficulty.easier_than`).

---

## 6. Filling a ramp that never dips

Twelve phases in `generator.gd` fix what a board holds. From phase to phase only growth is allowed:
4x4 with one marble, then two marbles sharing a hole on 5x5, two colours on 5x6, three marbles, pits on
6x6, three colours on 6x7, and so on up to 7x8 with four colours, eight marbles and three pits.

The single marble gets three levels and no more: one tilt, then two where the marble has to stop
against something first. One marble is solved the moment it is seen, so a run of them teaches nothing
new. An earlier schedule spent eight levels on it and reached a second colour only at level 17, long
enough for a player to decide the game was dull. Now two marbles arrive at level 4 and two colours at 9,
and the levels that freed go one each to the eight phases from three marbles on.

The ramp gives every level a target par and a target in bits, along one curve:

    t = (i / 119)^0.75        par = 1 + 12 t        bits = 1.6 + 16.4 t

A power below 1 climbs faster early, which the tutorial levels need, and flattens later.

Each phase gathers a pool: up to six candidates per level it ships, from at most 1,500 proposals per
level. A candidate joins only if it solves inside the phase's par window, sits within a bit of the
phase's stretch of the ramp, is no easier than the last level kept, has a pit in play when the phase has
pits, and replays nothing. Then a dynamic program picks the run: with the pool sorted by difficulty, it
chooses the phase's count of candidates in that order with par never falling, minimising

    Σ 2 (par - par target)² + (bits - bits target)²  +  0.5 for each repeated bits value

in O(pool² × count) steps. A phase's first level aims where the level before it aimed, so a second
marble, a second colour or the first pit arrives without a step up: levels 4, 9 and 28, which is where
the tutorial captions land.

Measured before and after:

|                                    | old set                   | new set |
|------------------------------------|---------------------------|---------|
| par falls from one level to next   | 7 (at 11, 21, 36, 51, 71, 91, 106) | 0 |
| easier than the level before       | 53                        | 0       |
| biggest single rise                | 3.9 bits (level 99)       | 0.6     |
| longest run at one bits value      | 3                         | 5       |
| a marble taken away                | at 51 and 91              | never   |
| near repeats                       | 53 pairs                  | 0       |

Levels at each par:

| par     | 1 | 2 | 3 | 4 | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 | 13 |
|---------|---|---|---|---|----|----|----|----|----|----|----|----|----|
| old set | 1 | 6 | 9 | 9 | 24 | 15 | 12 | 12 | 8  | 10 | 6  | 3  | 5  |
| new set | 1 | 6 | 8 | 8 | 8  | 11 | 11 | 11 | 12 | 10 | 13 | 13 | 8  |

Bits at levels 1, 11, 21 and so on to 111, then 120:

    old set  1.6  3.6  3.6  6.8  7.2  7.2  7.6  6.6 12.9 10.9 11.9 16.7  17.7
    new set  1.6  4.2  6.2  7.3  8.8 10.3 11.3 12.5 13.9 14.9 15.9 17.1  18.1

The old tiers' marble counts went 1, 1, 2, 2, 4, 3, 6, 4, 8. The new phases' only grow: 1, 1, 2, 2, 3,
3, 4, 4, 5, 6, 6, 8.

### Things to try

- Set `RAMP_POWER` to 1.0 and regenerate: the first twenty levels climb more slowly and the last ones
  faster.
- Set `PAR_WEIGHT` to 0: par follows only from bits, and plateaus turn uneven. An early version of this
  generator did exactly that and ran par 10 for 21 levels.
- Set `POOL` to 3: the generator runs faster and the runs of equal bits tend to get longer, because
  the program has fewer distinct values to step through.

---

## 7. Stars with a leeway that grows

Three stars means par. Two stars allows `max(2, ceil(par / 2))` extra moves (`scripts/stars.gd`),
because two extra moves on a par-2 board is a different solve, while four extra on a par-13 board is
still a good one. Par still runs from 1 to 13, so the leeway runs from 2 to 7 as before; what changed is
that it now grows steadily, since par never falls from one level to the next.

## 8. The title seesaw: one dimension of physics

The toy on the title is the one place with real physics, and it needs only one dimension: a position
along the bar per marble. Each frame, gravity along a bar tilted by `angle` accelerates each marble by
`g sin(angle)`, a little damping bleeds energy, and two marbles closer than a diameter are pushed apart
and trade speeds, which is what equal balls do in a head-on collision. The ends bounce with 40% of the
speed.

### Things to try

- `Seesaw.ROCK` is the tilt amplitude in radians. At 0.3 the marbles slam from end to end; at 0.04
  they barely drift.
