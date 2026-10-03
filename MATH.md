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

This section is the 120-level set of 1.0, where the idea was worked out. Since 1.1 the phases sit in
chapters and the ramp runs over 500 levels (section 8), but the pools and the dynamic program are the
same.

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

## 8. Chapters: a rule every level has to need

From chapter 5 on, each chapter adds one tile (`scripts/tilt/board.gd`, `CHAPTERS.md`): stop pads, one-way
gates, plugs, colour gates, paint and cracked floor. Each one is a small change to section 1's step loop,
which is why the simulation stays front first and one cell per step:

- a marble may enter a cell only if `enterable` says so: not a wall, a gate only along its own direction,
  a colour gate only in its own colour;
- a marble that enters a stop pad is marked halted and skipped for the rest of the tilt, so the ones
  behind it stop against it as they would against a wall;
- paint changes a marble's colour as it enters, so the hole check that follows uses the new colour;
- a plug that takes a marble becomes floor, and cracked floor becomes a pit once a marble has rolled
  off it.

The last two change the board itself, not just where the marbles are, so section 2's solver key needs
them. Both changes are permanent, so the set of them is the whole difference: the key is the sorted
marbles, then the sorted list of changes. Two boards with the marbles in the same places but one crack
gone are different positions, and the search keeps them apart.

**A level must need its chapter's rule.** A random board with a stop pad on it will often solve just as
well without the pad, and a level like that teaches nothing. So every candidate in a chapter is solved a
second time with that chapter's tiles turned back into plain floor (or its plugs into ordinary holes), and
kept only if that plain board's par is different. Rules come in two kinds, and the test catches both:

- a rule that helps (a stop pad, paint) shows by the plain board getting harder or unsolvable;
- a rule that restricts (a gate, a plug, cracked floor) shows by the plain board getting easier.

An early version kept a candidate only when the plain board got harder, which suits stop pads but almost
never passes for plugs: taking a plug away only ever gives the marbles more room. Chapter 7 stalled at
4 candidates from 15,000 proposals.

The second search only has to look `par` moves deep: finding a shorter solution, or proving there is
none of length par, settles it. Breadth-first order makes that bound free (stop expanding at depth par),
and it keeps the second search no bigger than the first. A search that hits its state limit first proves
nothing either way, so that candidate is turned down rather than counted as needing its rule.

**The window moves with the levels.** Section 6's pool takes candidates within a bit of the ramp, but
par and bits may never fall, so once the levels run ahead of the ramp (by level 120 they sit at 14.3 bits
against a target of 13.65) the window's upper edge comes down to meet the last level and the pool
starves. Now a phase that starts ahead shifts its whole window up by how far ahead it is. The dynamic
program still aims at the ramp itself, so it keeps choosing the lowest candidates it can, and the levels
drift back toward the curve whenever the pools allow.

Aiming at a ramp below the levels has a side effect: the cheapest run is the lowest candidate over and
over, and chapter 7 came out as ten levels at exactly 15.1 bits. Four fixes were tried:

- Aim at the ramp raised by the same amount as the window. Each phase then aims a little above where the
  last one ended, the `FLAT` cost for a repeat (0.5) is more than an overshoot of 0.7 bits costs, and the
  overshoots compound: by level 110 the levels were 3.5 bits above the ramp and still climbing.
- Keep aiming at the ramp, and allow no more than 3 levels in a row on one bits value. Small boards come
  in few distinct values, so every forced step was a jump of up to 0.6 bits, the early chapters ran far
  ahead, and chapter 4 had nothing left to climb to.
- Keep aiming at the ramp, and make a plateau dearer the longer it runs: extending a run of `m` equal
  levels costs `FLAT × m`, so a run of five costs 0.5 + 1 + 1.5 + 2 = 5. The climb was even, but too
  steep: par 12 and 18.8 bits by level 150, and chapter 8 had nothing left to climb to either.
- Keep aiming at the ramp, a flat `FLAT` per repeat, and `RUN` = 5 as a hard limit: no more than five
  levels in a row on one bits value. The program's state becomes (candidate, how many levels in a row end
  on its value), as in Apsis's play order, and the run carries over phase boundaries. Each forced step is
  the smallest the pool offers. This is the one kept: all 200 levels climb with no run longer than five.

**The ramp runs over 500 levels**, the whole planned game, not the chapters made so far. Section 6's curve
is now

    t = (i / 499)^0.55        par = 1 + 15 t        bits = 1.6 + 26.4 t

so the 200 levels made today aim exactly where they will sit in the finished game, and adding the next
chapters later leaves them, and every player's stars on them, as they are.

The shipped 200, measured (bits from the generator's own measure, rounded):

| Chapter | Levels | Boards | Marbles | Par | Bits | Ramp at the chapter's end |
| --- | --- | --- | --- | --- | --- | --- |
| 1 Roll home | 1-20 | 4x4 to 5x6 | 1-2 | 1-4 | 1.6-6.2 | 6.0 |
| 2 Three colours | 21-40 | 5x6, 6x6 | 3 | 4-6 | 6.2-8.6 | 8.1 |
| 3 Pits | 41-60 | 6x6 | 3-4 | 6-7 | 8.6-10.5 | 9.8 |
| 4 Four colours | 61-80 | 6x7, 7x7 | 4-5 | 7-8 | 10.9-13.1 | 11.2 |
| 5 Stop pads | 81-100 | 6x7, 7x7 | 4-5 | 8-9 | 13.2-14.5 | 12.4 |
| 6 One-way gates | 101-120 | 6x7, 7x7 | 4-5 | 9-10 | 14.5-15.5 | 13.6 |
| 7 Plugs | 121-140 | 7x7 | 5 | 10-11 | 15.7-17.1 | 14.7 |
| 8 Colour gates | 141-160 | 7x7, 7x8 | 5 | 11-13 | 17.3-18.7 | 15.7 |
| 9 Paint | 161-180 | 7x7, 7x8 | 5 | 13 | 18.7-20.4 | 16.6 |
| 10 Cracked floor | 181-200 | 7x7, 7x8 | 5 | 14 | 20.7-22.8 | 17.5 |

The first four chapters follow the ramp closely. From chapter 5 the levels run ahead of it, by about
five bits at level 200, because a board that needs its tile is harder than a plain one of the same size.
They still never fall, and no more than 5 in a row share a value. That leaves a gentler climb, about 5 bits
over 300 levels, for the chapters to come, which suits boards that are already as large as a phone shows
well.

### Things to try

- Comment out the `needs` check in `add_phase` and regenerate chapter 5: count how many of its levels
  still solve in par with the pads ignored.
- Give a phase `"crack": 6` and watch the pools: past a few cracks most boards lose a marble to a pit
  on every route, and the pool fills slowly. Even at 3 cracks, about four in five proposals are
  unsolvable.
- Set `ahead` to 0 in `add_phase` and regenerate: some phase past level 120 cannot fill its run.
- Set `RUN` to 10 and regenerate: the plateaus come back wherever the levels are ahead of the ramp.

---

## 9. Turns, jumps and boards that change

Chapters 11 to 15 bring rules section 1's step loop could not hold as it was: a stone, a portal, a bumper,
a switch with its hatch, and a key with its locks.

**Headings.** Until a bumper, every marble rolled the tilt's way, so "front first" was one sort and one
pass per step. A bumper turns a marble a quarter, so each marble now carries its own heading, and a step is
repeated passes: any marble whose next cell along its heading is free moves, a marble moving into a cell
another has just left included, until a pass moves nothing. With every heading the same this is exactly the
old loop, since the marble in front always goes first, and the 200 levels of 1.1 re-solve to the same par.
A "/" bumper maps (dx, dy) to (-dy, -dx) and a "\" to (dy, dx).

**Portals.** A marble rolling into a portal lands on its twin in the same step and rolls on from there, the
same way. A portal whose twin is taken is shut, like a wall, so two marbles can never meet in one cell.
Bumpers and portals together can send a marble round a loop forever, so a marble that comes back to a cell
it has already been on in this tilt, heading the same way, stops there. The test suite builds such a loop
from four bumpers round a wall.

**Switches are read when a tilt starts.** A hatch is open for a whole tilt if something rests on its switch
as the tilt begins. Deciding it step by step would make the answer depend on the order marbles move in
within a step, which a player cannot see. Read at the start, it is a rule about where things are, which is
all the solver's key holds, so no new state is needed.

**Stones** are kept with the marbles in a colour no hole has (`TiltBoard.STONE`): every rule that moves a
marble moves a stone, no hole ever matches it, and the win counts marbles only. A stone that rolls into a
pit fills it, and the pit becomes floor for good. Like cracked floor, a used key and its opened locks, that
is a lasting change, so the solver's key carries it: changes are now kept as `cell × 4 + kind`.

**What "without the rule" means** for each (`TiltGenerator.without`): stones taken off the board; portals,
bumpers turned to plain floor; switches taken with their hatches, so every door is simply open; keys taken
with their locks. The level must then play differently, as in section 8.

**Deeper search for deeper puzzles.** At par 15 to 18 the number of positions grows past section 8's limit
of 12,000 often enough that pools starve, so a chapter may set its own (`"search"`, 20,000 from chapter 11).
Chapters 1 to 10 keep the limit they were made with: a larger one would admit candidates they turned down,
and change levels players have already played.

**Making a wave without remaking the ones before.** The generator is one random stream from the seed, so
making chapter 11 used to mean making chapters 1 to 10 again first, about 25 minutes, and every later wave
longer still. Now the level file keeps the generator's random state at the end of every chapter
(`rng_states`), and `resume=10` keeps chapters 1 to 10 as they are, measures them again for the run picker
and the likeness test, restores the state, and goes on: the same file as a full run, in a fraction of the
time. The states are kept as strings, because JSON numbers are doubles and a 64-bit state does not fit in
their 53 bits of mantissa.

### Things to try

- Delete the loop guard in `TiltBoard._arrive` and run the tests: the four-bumper loop never ends.
- Make hatches follow their switch step by step, and see how often a level's par changes when two marbles
  swap places in `order`.

---

## 10. Chapters 16 to 25: when the board stops, and what comes after

Chapters 16 to 25 bring blinking walls, conveyors, springs, wrap edges, magnets, numbered marbles, glass
posts, ice holes and a turning lock, then a chapter that mixes every rule so far. Most of them are about
time: something happens on every tilt, or once the board has stopped, or only to a marble at rest.

**A tilt now has an end.** Section 1's loop rolls marbles until a pass moves nothing. Three rules act at
that moment, in order. First, a marble resting on a conveyor that does not already head its way is turned
to it, and the loop runs again; a turn on its own changes nothing, so a conveyor pointing into a wall is no
move. Then a marble resting on its own ice hole drops in, and so does a numbered marble waiting on its hole
whose turn has come. Last, glass that a marble struck shatters into floor. A tilt that only shatters glass,
or only drops a marble, still counts as a move (`TiltMove.settled`), since the board is different after it.

**The beat.** A blinking wall is up when its value equals the board's beat, and the beat flips after every
tilt that changed something, so a tilt into a wall does not count. A wall never rises under a marble: one
resting on it as the tilt starts keeps it down for that tilt, which is read at the start like a switch
(section 9). The beat is state, so the solver's key carries it, but only on boards with a blinking wall:
everywhere else it would split every position in two for nothing and double the search.

**Springs and wrap edges** change where "the next cell" is: a marble leaving a spring goes two cells, over
whatever is between, and a step off a wrapping edge comes back in at the far side (`TiltBoard.cell_along`).
A marble on a row that wraps and holds nothing to stop it would roll round forever, so on such a board the
loop guard starts with each marble's own cell and heading: one that comes all the way round stops where it
began. The reachability check of section 3 assumes marbles stay on floor between walls, so boards with
either are left to the solver.

**Numbered marbles** drop only in turn: a marble numbered n rolls over its hole like floor while any lower
number is still on the board. Numbers are part of a marble, so the key holds (cell, colour, number).

**Revised while building.** The plan put colour mixing at chapter 23 and moving holes at 24. Mixing needs
colours that mix, and the marble sets are planets, gems and candy as well as paint: there is no telling a
player what a gem and a planet make. Moving holes would have made every hole a body that rolls, through
every rule and the drawing, for one chapter. Both went back to the reserve. Ice holes, which ask for a
precise stop, took chapter 23. Chapter 24 was to be the reserve's locked direction, and the numbers turned
it into a turning lock. With one way locked for good, every marble moves along one axis in one sense only,
so a tilt that carries a marble past its hole can never be undone: of 150 random boards none could be
solved in 16 moves or more, even with marbles placed where their holes stayed in reach. A lock that turns a
quarter clockwise after every tilt that changes something brings every way back in turn, so a board stays
solvable, and the puzzle becomes timing: which way is open now, and which next. Its direction is state, so
the key carries it, as it carries the beat.

**Par first.** By chapter 13 the levels need 17 moves and measure about 27 bits, and its second phase took
two and a half hours to find 51 boards in 15,000 that beat the last level on both. A random board for
chapters 16 to 20 that needs at least 16 moves and needs its rule comes up two to nine times in a hundred,
and its bits spread from 21 to 31, mostly below 27. Asking every level to beat the last one's bits as well as
its par leaves each pool a sliver of the tail of that spread, and the sliver shrinks every phase. So from
chapter 14 levels ship in `TiltDifficulty.before`'s order: par first, then bits. Par never falls, and within
one par bits never fall, but when par steps up bits may start lower again: a level that needs one more move
comes after one that needs fewer, whatever its bits. Every earlier level keeps both rules, which keeps this
order too, so the tests check one order over all 500. The run picker still aims at the ramp, so it holds par
as long as its pool has boards at that par harder than the last, and steps up when it runs short.

**Keeping the climb slow.** Par first still climbs, and how fast depends on the pool. Within one par the
run picker takes the lowest bits above the last level's, so a phase climbs by about the spread of bits among
its boards at that par divided by how many there are; when that par runs out it steps up. In chapters 14
and 15 par held for about 30 levels, and in chapter 16's first try, with par allowed up to 21, most of the
pool came in at 20 and 21: par would have stepped up every chapter and reached the high twenties by level
500, past what the search can reach. So from chapter 16 a phase pools only boards that need the last
level's par or one move more (`CLOSE_FROM`), and pools eight per level it ships rather than six. Its boards
crowd the low end, par holds longer, and each search stops one move past the last par instead of searching
to the phase's limit.

**Screening before measuring.** From chapter 14 a proposal is first solved by the plain search of section
2, which only finds par. Most proposals fall outside the phase's par window, and they no longer pay for the
measure of section 5, which carries every position's chance as it goes. The two searches count positions a
little differently, so the chapters made before keep the one way they were made.

**Pools on worker processes.** A pool is hundreds to thousands of proposals, each a breadth-first search of
up to 24,000 positions, one at a time. GDScript threads do not help: one thread proposes about 4 boards a
second here, and four, eight or twelve together manage about 8, since they spend their time waiting on each
other. Separate Godot processes share nothing and scale with the cores. So from chapter 12 a phase draws one
number from the generator's random stream, and batch b of 24 proposals is seeded from that number and b
alone. Worker processes take batches in turn and write each as a line of JSON; the main process merges them
strictly in batch order and stops the workers once the pool is full. Where or when a batch ran never shows:
the same seed writes the same file with one worker or twelve. Floats go through JSON at full precision,
because the run picker compares bits for equality.

### Things to try

- Put the beat in every board's key and time the search of a chapter 12 level: about twice the positions,
  and the same par.
- Turn a conveyor towards a wall and tilt: the tilt is refused, since a turn alone is no move.
- Set `BY_PAR_FROM` to 25 and generate chapter 14 with `resume=13`: its pools fill with boards measuring
  less than the last level, which the old order cannot use, and the phase runs out of attempts.

---

## 11. The title seesaw: one dimension of physics

The toy on the title is the one place with real physics, and it needs only one dimension: a position
along the bar per marble. Each frame, gravity along a bar tilted by `angle` accelerates each marble by
`g sin(angle)`, a little damping bleeds energy, and two marbles closer than a diameter are pushed apart
and trade speeds, which is what equal balls do in a head-on collision. The ends bounce with 40% of the
speed.

### Things to try

- `Seesaw.ROCK` is the tilt amplitude in radians. At 0.3 the marbles slam from end to end; at 0.04
  they barely drift.
