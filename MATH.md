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
and the levels that freed go one each to the eight phases from three marbles on. Since the opening of
section 12, the single marble has one level and the second arrives at level 2.

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

**Every tile, not just the rule.** Needing the rule as a whole still lets single tiles do nothing: two
gates where one does the job, or a pad no route ever touches. A player noticed gates with no point, and
a scan of the first full set found 217 of the 420 levels from chapter 5 on carrying such a tile. So
`TiltGenerator.prune` takes each single-cell tile off in turn and leaves it off while par stays the same,
going round until nothing more comes off, since taking one off can make another matter. It never takes
the last tile of a needed rule, because without it par would change.

It has to happen inside the search, not after it. A tile that never changes the best route still blocks
wrong ones, so taking it off lowers bits (one level of the old set fell from 15.1 to 11.6), and a shipped
level would then measure easier than the one before it. A pass over the finished set could clean only 126
of the 217 without breaking section 6's order. Pruned in `_try`, a candidate is measured as it will ship,
and the run is built from clean boards. That costs yield: chapter 10 found 4 boards in 15,000 proposals.
So from chapter 5 every chapter tries `ATTEMPTS_TILED`, three times as many proposals per level, on the
worker processes of section 10. Chapters 1 to 4 place no tiles and come out byte for byte as before.

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
| 1 Roll home | 1-20 | 4x5 to 5x6 | 1-2 | 1-4 | 1.0-6.2 | 6.0 |
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

**Par first.** The first build of chapters 11 to 15 kept section 6's rule that par and bits each never
fall, and it climbed from par 14 at level 200 to par 19 by level 300. Chapter 13's second phase took two and
a half hours to find 51 boards in 15,000 that beat the last level on both, and with 200 levels still to make
every one would have had to need 19 moves or more. A random board for chapters 16 to 20 that needs at least
16 moves and needs its rule comes up two to nine times in a hundred, and its bits spread from 21 to 31.
Asking every level to beat the last one's bits as well as its par leaves each pool a sliver of the tail of
that spread, and the sliver shrinks every phase. So from chapter 11 levels ship in `TiltDifficulty.before`'s
order: par first, then bits. Par never falls, and within one par bits never fall, but when par steps up bits
may start lower again: a level that needs one more move comes after one that needs fewer, whatever its bits.
Every earlier level keeps both rules, which keeps this order too, so the tests check one order over all
500. The run picker still aims at the ramp, so it holds par as long as its pool has boards at that par harder
than the last, and steps up when it runs short.

**Keeping the climb slow.** Par first still climbs, and how fast depends on the pool. Within one par the
run picker takes the lowest bits above the last level's, so a phase climbs by about the spread of bits among
its boards at that par divided by how many there are; when that par runs out it steps up. With par allowed
up to 21, most of a pool came in at 20 and 21, so par would have stepped up nearly every chapter. So from
chapter 11 a phase pools only boards that need the last level's par or one move more (`CLOSE_FROM`), and
pools eight per level it ships rather than six. Its boards crowd the low end, par holds for about fifty
levels, and each search stops one move past the last par instead of searching to the phase's limit. Chapters
11 to 15 had not shipped, so they were made again this way, from level 200 on.

**Screening before measuring.** From chapter 11 a proposal is first solved by the plain search of section
2, which only finds par. Most proposals fall outside the phase's par window, and they no longer pay for the
measure of section 5, which carries every position's chance as it goes. The two searches count positions a
little differently, so the chapters made before keep the one way they were made.

**Pools on worker processes.** A pool is hundreds to thousands of proposals, each a breadth-first search of
up to 24,000 positions, one at a time. GDScript threads do not help: one thread proposes about 4 boards a
second here, and four, eight or twelve together manage about 8, since they spend their time waiting on each
other. Separate Godot processes share nothing and scale with the cores. So from chapter 11 a phase draws one
number from the generator's random stream, and batch b of 24 proposals is seeded from that number and b
alone. Worker processes take batches in turn and write each as a line of JSON; the main process merges them
strictly in batch order and stops the workers once the pool is full. Where or when a batch ran never shows:
the same seed writes the same file with one worker or twelve. Floats go through JSON at full precision,
because the run picker compares bits for equality.

### Things to try

- Put the beat in every board's key and time the search of a chapter 12 level: about twice the positions,
  and the same par.
- Turn a conveyor towards a wall and tilt: the tilt is refused, since a turn alone is no move.
- Set `BY_PAR_FROM` and `CLOSE_FROM` to 25 and generate with `resume=10`: par reaches 19 by level 300, and
  chapter 14's pools fill with boards measuring
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

---

## 12. The opening: five levels picked to be remembered

The ramp of section 6 knows one thing about a level: how hard it is. At its foot that is not enough.
Every board there is easy, and the first five levels decide whether a new player stays (a game wants nine
players in ten through them), so what matters is what each one shows: motion worth watching, a board that
looks made on purpose, and one small idea. `TiltShowcase` picks levels 1 to 5 for that once the rest of
chapter 1 is made. It draws on a random stream of its own, seeded from the level seed, so the 495 levels
after it come out the same whatever it picks.

**Slots and traits.** Each slot fixes its marbles and par and names traits that every route clearing the
board in par must show, not just the solver's, since a player may find another:

| Level | Marbles | Par | Traits | What the player sees |
| --- | --- | --- | --- | --- |
| 1 | 1 | 1 | long | one tilt, and a roll of at least three cells into the hole |
| 2 | 2 | 1 | together, busy | both marbles roll as a train and drop on the same tilt |
| 3 | 2 | 2 | apart, bank, busy | one drops, the other stops against a wall and turns the corner home |
| 4 | 2 | 2 | trap | the tilt that drops a marble at once strands the other, so par needs the other order |
| 5 | 2 | 2 | together, busy | both roll into line, then drop together on the last tilt |

"Busy" means every marble on the board rolls on every tilt. Two ideas did not survive the arithmetic:

- One marble stopping against the other, so it becomes the stopper, cannot happen at par 2 with one
  hole. After the first tilt the two touch along that tilt's axis, so they share a row (or column), and
  they shared it from the start, since a tilt never moves a marble across its row. The last tilt must
  drop both into the one hole. A tilt across that row moves them down two different columns, and only one
  passes the hole. A tilt back along the row can only find the hole where the same tilt from the start
  would have found it too, and the board would have been par 1. So level 4's idea is the order of the
  tilts instead.
- A trap level where every marble also rolls on every tilt: 20,000 proposals gave none. The marble that
  waits is the point of the trap.

**Symmetry has to be built in.** A random board is almost never symmetric. On a 5x5 board at 15% walls,
each of the ten pairs of cells a left to right mirror swaps matches with chance 0.15² + 0.85² ≈ 0.75, so
all ten match about one time in nineteen, and then the hole still has to land on the middle column. So a
proposal picks a symmetry group (none, a mirror, a half turn, both mirrors, and on square boards the
diagonals or the quarter turns), splits the cells into the group's orbits and makes whole orbits wall. The
hole goes on a cell the group leaves in place, and so does each marble half the time (`POSED`).

**The score.** Each part runs from 0 to 1:

    score = 3 symmetry + 1 pose + 2 cover + 1 reach + 1.5 roll - 6 × (wall share outside 8% to 16%)

- *symmetry*: the largest share of cells, walls and holes, that one mirror or turn leaves alone, times how
  strongly that symmetry reads (`SALIENCE`): a mirror left to right or top to bottom 1, a half or quarter
  turn 0.8, a diagonal mirror 0.6. On the first contact sheets, boards symmetric only about a diagonal
  looked as random as boards with no symmetry at all.
- *pose*: the same, with the cells the marbles start on counted too.
- *cover*: the share of floor the par routes roll over or rest on, the room the solution uses.
- *reach*: the share of floor any play from the start touches. Floor nothing can ever reach is wasted.
- *roll*: cells rolled on the par routes against the most they could be, every marble crossing the board
  on every tilt.
- *walls*: free inside the band. Without the lower edge the last levels came out with a single wall or
  none, which looked unfinished; past the upper edge a small board looks cluttered.

**The run.** The opening must keep every promise the test suite makes about the whole set, so a slot's
pool only takes boards that measure no harder than level 6 (par 2, 3.6 bits) and replay no level after
the opening (section 4). Then one board per slot, each no easier than the one before (section 5's order),
with no less room and no fewer marbles, and none a replay of another. The pick is a beam search: the 500
best partial openings by their total, each grown by every board of the next slot that may follow it. In the
total, slot k counts 0.8^k (`FUNNEL`): every player sees level 1 and fewer see each level after it, so a
better first board is worth a slightly worse fifth. A level as hard as the one before costs 0.1, only a
tie-break.

Two of the suite's rules shape the result more than the score does. No level may take away room, so a 5x5
first level would force five 5x5 levels, and the search finds no five of them that climb, fit under level
6 and repeat neither each other nor levels 6 to 8. And the cleanest boards resemble each other: the best
first level, a marble rolling the length of the middle row, comes within 5 cells of the level 2 that
shipped and 4 of level 3 once turned or mirrored, under section 4's 6 of 20, so it may not ship beside
them. The run starts on a plainer board, a roll down one edge past a bar of two walls, because every
opening built around the best first level costs more in the levels after it.

Measured, with the old opening beside it:

| Level | Old board | Old par, bits | Old score | New board | New par, bits | New score |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 4x4, 3 walls | 1, 1.6 | 4.9 | 4x5, 2 walls | 1, 1.0 | 6.4 |
| 2 | 4x4, 5 walls | 1, 1.6 | 3.0 | 5x4, 2 walls | 1, 1.6 | 6.7 |
| 3 | 4x4, 5 walls | 2, 2.6 | 4.1 | 4x5, 2 walls | 2, 2.6 | 6.6 |
| 4 | 5x5, 5 walls | 2, 3.0 | 4.3 | 4x5, 4 walls | 2, 3.2 | 6.1 |
| 5 | 5x5, 3 walls | 2, 3.2 | 5.5 | 4x5, 2 walls | 2, 3.6 | 6.6 |

Level 6 is 5x5 with 8 walls, par 2 and 3.6 bits, so level 5 meets it exactly. `tools/generate_levels.gd`
with `opening` makes the opening again in the level file already written and replaces only its text, every
other byte left as it was; a full run makes it once chapter 1 is done, and the two agree.

### Things to try

- Put `Vector2i(4, 4)` back in `SHAPES`: the run starts on a 4x4 board, which has no middle row or column
  for the hole to sit on, and its symmetry falls to 0.88.
- Set `LEAST` to 0: levels 4 and 5 come out with one wall each.
- Add "busy" to slot 4's traits: its pool comes back empty.
- Set `FUNNEL` to 0.5: level 1 gets the roll along the middle row, and the run pays for it with 5x5 boards
  for the rest, levels 3 and 5 over a point lower and plainly untidy.

---

## 13. A colour for every chapter: a stride round the hue circle

Each chapter's page of the level grid wears its own colour (the kit's `ChapterStyle`). Twenty-five
chapters need twenty-five colours that all differ, and the next chapter's should sit far from the last,
so a page turn reads as arriving somewhere new. Two easy answers fail:

- Step by 1/25 of a turn: every hue is different, but neighbours are nearly the same colour.
- Step by the golden angle, 0.618 of a turn, the usual way to scatter points round a circle: neighbours
  are far apart, but some distant chapters land close. Eight steps make 4.944 turns, so chapter 9 sits
  within 20 degrees of chapter 1. That is no accident: 8 is a Fibonacci number, and Fibonacci multiples
  of the golden ratio fall close to whole numbers.

The kit spreads n hues evenly instead, k/n of a turn for k = 0 to n - 1, starting at the game's accent,
and visits them with a stride s: chapter c takes hue (c·s mod n)/n. When gcd(s, n) = 1, the map
c -> c·s mod n is a bijection on {0, ..., n - 1}: s generates the additive group ℤₙ, so the walk visits
every hue exactly once before it comes back. Every chapter gets its own hue, at least 1/n of a turn from
any other, the widest spread n hues allow. The stride is the coprime s nearest 0.3·n, so consecutive
chapters sit about a third of a turn apart. For n = 25 that is s = 7, and the gap between chapters d
apart in play is 7d mod 25 steps of 14.4 degrees, read the short way round:

| d | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| steps | 7 | 11 | 4 | 3 | 10 | 8 | 1 |

So any two chapters within six of each other are at least 43 degrees apart, and the closest colours,
14.4 degrees apart, come seven chapters apart, with different motifs. Some pair must be that close: 25
hues on a circle leave no wider gap.

Hue alone does not make a colour readable on every background. The kit holds lightness and chroma in
OKHSL, whose lightness is perceptual: 0.46 to 0.52 on light themes, 0.70 to 0.78 on dark ones. Equal
OKHSL lightness means close to equal contrast whatever the hue, which is why one band passes 3:1, the
contrast WCAG asks of graphics, on every theme in light and dark. The tests check every chapter on every
theme, that the next hue is at least a quarter turn away, and that no two chapters share one.

### Things to try

- `ChapterStyle.STRIDE` to 0.5: for n = 25 the stride becomes 12 or 13, nearly opposite colours each page,
  which flickers.
- `ChapterStyle.STRIDE` to 0.04: the stride becomes 1, and turning a page only nudges the colour.

---

## 14. The chapter gate: seven in ten

Levels open one after another: a level opens once the one before it is solved. On its own that rule turns
one stubborn level into a wall, and a wall is where players leave. So a chapter's first level also opens
once 70% of the chapter before it is solved (the kit's `Unlocks.GATE`): ⌈0.7 × 20⌉ = 14 of 20.

Other puzzle games give two reference points. Cut the Rope opens its second box at 30 of the first box's
75 stars, 40%. Baba Is You's later expansion asks for 5 of its 7 worlds, 71%. Stars are not what opens
levels here, solves are, and each chapter teaches one rule that later chapters mix, so the gate sits at
the high end: a chapter is mostly played before the next rule arrives. Within a chapter difficulty climbs,
so the last six levels are its hardest, and those are exactly the ones a player may leave for later.

On the climb the gate never makes the game easier. Difficulty never falls across a chapter boundary there
(section 8), so the next chapter's first level is at least as hard as the last chapter's last. Stepping
ahead trades a stuck level for a fresh rule, not for an easier board. On the plateau (section 16) each
chapter starts again at the floor, so the next chapter's first level may be up to the band easier than the
last chapter's last. A key or a short video opens any one level as well, for
a player who wants a particular one now.

### Things to try

- `Unlocks.GATE` to 1.0: the old rule, every chapter shut until the one before it is finished.
- `Unlocks.GATE` to 0.4: the Cut the Rope share, eight levels into a chapter and the next one opens.

---

## 15. A QR code made by hand, and a slider that sounds even

**The code.** A reel ends on a code that a phone can scan to reach the game's store listing. The kit
makes it itself (`Qr`), so no image file is exported and any link works. A QR code is a square of
modules that carries bytes, and it is built in four steps.

1. **Data.** A 4-bit mode (0100, bytes), the length in 8 bits (16 from version 10 up), the bytes, a
   terminator, zeros to a whole byte, then the pad bytes 0xEC and 0x11 in turn until the version is full.
   The version is the smallest that holds the text. The 70 bytes of a Play listing link need version 8 at
   level H, 49 modules a side.
2. **Error correction.** The codewords are split into blocks, and each block gets Reed-Solomon check
   bytes. Read the block as a polynomial over GF(2⁸), the field of 256 elements whose arithmetic is taken
   modulo x⁸ + x⁴ + x³ + x² + 1, and append the remainder of dividing it by
   g(x) = ∏ᵢ₌₀ⁿ⁻¹ (x − αⁱ) with α = 2. A remainder of n bytes lets a reader find and fix n/2 bad
   bytes. Level H spends enough that about 30% of the code can be lost, which is the room the app icon
   takes in the middle.
3. **Placement.** Three finder eyes in the corners, the timing rows, the alignment patterns, and the format
   and version bits come first. The codeword bits then snake up and down two columns at a time from the
   right, around everything already placed.
4. **Masking.** Each of eight masks flips the data modules on a pattern, such as (x + y) mod 2 = 0. The
   mask with the lowest penalty wins. Long runs of one colour cost, as do 2 by 2 blocks, shapes that look
   like a finder eye, and a dark share far from half, so a scanner never takes data for the frame.

The kit's codes match OpenCV's encoder module for module, mask included, and they decode.

**The slider.** Loudness is heard on a log scale: 10 dB down sounds about half as loud. A slider mapped
straight to amplitude changes little over its top half and then everything in its last stretch. So
`Save.volume_db` squares the slider's place v before it becomes decibels: 20 log₁₀(v²) = 40 log₁₀ v. The
middle of the slider is -12 dB, about half as loud, a quarter of the way is -24 dB, and the end falls away
to silence.

### Things to try

- Make `Save.volume_db` return `linear_to_db(volume)`: the middle of the slider is only -6 dB, and the
  slider seems to do nothing until near the end.
- Give `Qr.rows` a link twice as long: it moves up to version 12, 65 modules a side, and its modules
  shrink on the end card.

---

## 16. The comfort ceiling and the Hard shelf

Sections 6 to 10 built a ramp that never falls, and it kept that promise to the last level: par 1 to 12 over
levels 1 to 160, 12 to 14 over 161 to 180, then 14 to 21 from chapter 10 on, on 8x8 boards from chapter 11,
with a new tile every chapter. Shravan played it and found the game "extremely difficult, unplayable" from about level 180,
while he loved the early levels for being easy and tricky. Two real players had gone past level 25 when this
was written, too few to say where people stop, so his playtest placed the cut.

**A ceiling, not a longer ramp.** A ramp climbs because each level should ask a little more than the last.
But that has a top. Past it a level stops being a puzzle you read and becomes a search you cannot hold in
your head, and a phone screen sets that top as much as the rules do. Call it the comfort ceiling. Below it
the ramp does its job. At it, a new chapter should bring a new idea, its tile, and not more difficulty. So
from chapter 10 the main path holds a plateau at level 160's difficulty, and the old climb is kept whole, as
the Hard levels, for players who want it.

**The floor and the band.** Level 160 measures par 12 and 18.85 bits: a player tilting at random clears it
in 12 tilts about once in 470,000 tries. That is the floor. From level 181 no level has a lower par or fewer
bits (`TiltGenerator.PLATEAU_LEVEL`). The band above it is one move of par and 1.5 bits, a factor of 2.8 in
that chance (`PLATEAU_PARS`, `PLATEAU_BITS`). A plateau board is also no larger than level 160's 7x8 and
holds no more than its five marbles (`phase_of`), since a bigger board is harder to read whatever it
measures. Level 181 is easier than level 180 (par 14, 20.85 bits): that one step down is the point.

**What the plateau does to the dynamic program.** Section 6's run picker keeps its pools, its cost and its
`RUN` limit of five equal levels in a row. Six things change:

- **Order holds within a chapter only.** A chapter has no level before it to stay above, so each chapter
  starts again from the floor, which is where a new tile is best taught. Inside a chapter, par then bits
  never fall (section 10's order), so the only falls on the main path are at chapter starts.
- **One run per chapter.** Each phase still pools on its own, its boards to its own spec, but none is run
  until the chapter's last phase: then one run is picked through all the pools at once, each level drawn
  from its own phase's pool (`allowed` in `_run`). Picked phase by phase, a first phase could end high in
  the band and leave the second too little room above it. In the first build, chapter 15's first phase
  ended at par 13 and 19.7 bits, its second phase found 74 boards between that and the ceiling in 45,000
  proposals, and no run of ten could be picked from them. Seen whole, the program ends the first phase
  where the second can still climb.
- **The pool's window is the band.** A candidate joins only between the floor and the floor plus the band,
  so no fall can be larger than the band, and every search stops at par 13, the most the band allows.
- **The aims climb half the band in each chapter** (`PLATEAU_RISE`), from the floor at a chapter's first
  level to half a move and 0.75 bits above it at its last. The program pays the squared distance to those
  aims as before, so a chapter climbs gently, the way the early game does, and then the next rule arrives.
- **The turning lock is measured against three tilts.** With one way always locked, a random player has at
  most three tilts on offer, so a tilt can ask at most log2(3) = 1.58 bits of luck instead of 2, and par 12
  or 13 can barely reach 18.85 bits: the first try at chapter 24 found no board in the band in 19,000
  proposals. The old lock levels show the same, about 1.14 bits a move against level 160's 1.57. So chapter
  24's floor and band are scaled by log2(3) / log2(4) = 0.79 (`TiltGenerator.bits_scale`), 14.94 to 16.13
  bits, with par still 12 or 13. The tests compare the falls into and out of it in the same scaled measure.
  Chapter 25 mixes rules and keeps the plain floor, so a mixed board with a lock joins it only if it
  reaches the four-way floor.
- **No level may replay a Hard level.** The Hard levels are reserved (`TiltGenerator.reserve`) and every
  candidate is checked against them as well as against the levels made, with section 4's rule. A route can
  replay only a level of the same par, and every Hard level needs 14 moves or more, so the Hard levels are
  compared by layout alone and never solved during the run.

**Measured.** The main path around the cut, by section 5's measure:

| Level | Par | Bits | Board |
| --- | --- | --- | --- |
| 160 | 12 | 18.85 | 7x8, 5 marbles |
| 180 | 14 | 20.85 | 7x8, 5 marbles |
| 181 | 12 | 18.85 | 7x7, 5 marbles |
| 200 | 13 | 19.73 | 7x8, 5 marbles |
| 300 | 13 | 19.85 | 7x8, 5 marbles |
| 400 | 13 | 19.68 | 7x8, 5 marbles |
| 500 | 13 | 19.62 | 7x8, 5 marbles |

All 320 plateau levels need par 12 (205 of them) or 13 (115), and every one sits between 18.85 and 20.1
bits, except the turning lock's, at 15.0 to 16.1 in its scaled measure. Chapter 10's first ten boards
are 7x7, as its first phase always was, and the rest 7x8. The Hard levels they replace needed par 14 to 21.

**What it costs to make.** One chapter at a time (`resume`), on 12 worker processes for chapters 10 to 13
and 15 from 14 on, the plateau took 5.7 hours of generator time, from 5 minutes for chapter 19 to 50 for
chapter 16. Chapter 10 searches each proposal up to 12,000 positions and ran about 180 proposals a second.
From chapter 11 a chapter searches up to 30,000 or 40,000, and they ran 5 to 60 a second. Blinking walls
were the slowest, since the beat doubles every search (section 10).

**Naive players.** `TiltNaive` plays every plateau level twice without planning: greedily, always taking the
tilt that drops the most marbles and then leaves the rest nearest their holes, and at random, 40 times. Greed
clears 2 of the 320 in par, and no random player clears any. On chapter 1 greed clears 12 of 20 and random
play 14, so the test does tell a level that needs thought from one that does not. The tests allow fewer
than one plateau level in ten for each.

**The Hard shelf.** Before the plateau was made, `tools/generate_levels.gd -- shelve` copied the old levels
181 to 500 into `levels/hard.json`, exactly as they shipped, and the tests hold them to that, and levels 1 to
180 too, with a SHA-256 of their JSON.
`Pack` keeps them as a second section that shares levels 1 to 180 with the main path, so inside, each Hard
level keeps its old index, which its saves and `hard.json` use, and each chapter its colour, card and caption.
The Levels screen shows only Hard's own chapters. A player sees Hard counted on its own, chapters 1 to 16 and
levels 1 to 320 (`Pack.number`, `Pack.chapter_number`, read through the kit's `Shown`), since a Hard that opened
on level 181 would feel like something was skipped, and its chapter 10 would clash with the main path's. Hard
is open from the start: its first level is always open, and inside it levels open as on the main path, one
after another, a chapter at seven in ten of the one before (section 14), or any one with a key or a video.
Analytics names Hard levels "h1" to "h320", and Play Games' levelCompleted event, whose level is a number,
gets 1001 to 1320, so a quit point in Hard never counts as the main path's level of that number.

**Moving a save.** A save now carries a layout number (`HardShelf.LAYOUT`, 2), and one without it was made
before the Hard levels. It moves on once, as it loads (`HardShelf.migrate`):

- Stars on levels 1 to 180 stay where they are.
- Stars won on old levels 181 to 500 move to Hard at the same number, since that is where those boards
  went, and the main path's new boards there start with none.
- A level from 181 on that a key or a video opened is opened in Hard, where its board is.
- On the main path, the first level of every chapter from 10 up to the furthest one the player had reached
  opens, so no one is shut out of a chapter they could play before. A chapter counts as reached when any of
  its levels was open under the old rules of section 14. The rest of each chapter opens one level after
  another, as always.

A copy from the cloud made by an older version moves on the same way before it is joined (`CloudSave.merge`),
so stars from an old phone can only ever land on the boards they were won on. The test suite builds an old
save, loads it, plays both sections on it, and joins an old cloud copy into it.

### Things to try

- Set `PLATEAU_BITS` to 3.0 and make chapters 10 to 25 again (`resume=9`): the pools take boards from a
  band twice as wide, and each chapter aims to climb twice as far from the floor before the next falls back.
- Set `PLATEAU_RISE` to 0: every level aims at the floor, and only the `RUN` limit makes the levels move.
- Set `PLATEAU_LEVEL` to 120: the floor drops to chapter 6's end, par 10, and the plateau gets easier still.
- `climb` makes every chapter on the ramp again, the way the Hard levels were made.

---

## 17. Faces: where the eyes look, and what the board makes a marble feel

Each marble colour is a character (`scripts/feel/cast.gd`): Rosie the red one, bold, with brows and freckles,
Steve the teal one with the reel's googly eyes, one bigger than the other, Pip the amber one, all eyes and
blushes, and Lulu the violet one, half asleep under long lashes. A stone is a sleeping rock with no name. Faces
are drawn in flat shapes on top of every marble set, and the node is never turned as a marble rolls, so a face
is always upright.

**What a marble feels** is decided in `Mood` from what the board reports: its speed every frame, and the
events of a tilt. The strongest wins, in this order: a fall down a pit, going home, a party, worry, the surprise
of a bounce (section 22), a bump, rolling, rest. Each feeling is a target for a handful of numbers (how open the lids are, the size of the eyes
and pupils, the brows, the smile, how open the mouth is, happy shut eyes, where the eyes look), and the drawn
numbers ease toward the target every frame by `1 - e^(-k dt)`. That form gives the same motion at 30 or 120
frames a second, which a fixed step per frame would not. Lids ease three times as fast as the rest, because a
blink or a squint is quick and a change of mood is not.

Speed is smoothed over about a tenth of a second before it is read. A roll is a chain of one-cell steps, and on
the frame between two steps a marble stands still: read raw, the face would flick back to rest in the middle of
every roll.

**Worry** comes from the move itself. `TiltBoard.tilt` has already said which marble falls and on which step,
so the view tells it to worry three steps before. It is only ever shown on a tilt the player has made, never
before one, so a face gives away nothing about which way is safe.

**Where the eyes look.** A look is a direction with a reach from 0 (straight ahead) to 1 (the rim). Looking at
a point a distance `d` away, measured in marble radii, the reach is

    reach = d / (d + 0.8)

so a near thing draws a small glance and a far one nearly a full one, and the reach never quite touches the rim.
Each eye aims from its own centre, so for a point close to the face the two pupils turn toward each other, as real
eyes converge. The pupil then moves inside the eye white, an ellipse with semi-axes `a` and `b`, and stops a
pupil's radius `p` short of its rim. Along a unit direction `u` an ellipse with semi-axes `a' = a - p` and
`b' = b - p` meets its rim at

    1 / sqrt((uₓ / a')² + (u_y / b')²)

which is how far the pupil may go (`Gaze.inside`).

The look moves by a critically damped spring, `x'' = -2ω x' - ω² (x - target)`. Critical damping is the
fastest a spring gets there without overshooting, and eyes do not overshoot. It is solved exactly rather than
stepped: with `y = x - target` and `c = v + ω y`,

    y(t) = (y + c t) e^(-ω t)        v(t) = (c - ω (y + c t)) e^(-ω t)

so a long frame on a slow phone can never make it wobble or blow up. `ω` is 30, which gets a glance 90% of the
way in a fifth of a second.

The eyes follow the finger while it drags across the board, before the drag is long enough to tilt, so the
marbles look where the player is about to send them. Marbles that a tilt does not move glance its way. At rest a
marble now and then looks over at the nearest hole of its own colour, as Steve does in the reel.

**Squash.** A marble that hits something squashes to 0.84 by 1.14 in 50 ms and springs back over 220 ms. The
product is 0.96, close to 1, so the marble keeps about its area and reads as soft rather than shrinking. Fifty
milliseconds is three frames, about the shortest change a player sees as an impact: shorter and it is missed,
longer and it reads as slow. The spring back is four times as long, which is the follow through. A marble going
home hops a fifth of a cell in 90 ms, comes down in the same, and drops in over 180 ms. With the squint on the
same bump, the face and the body move together.

### Things to try

- `Gaze.SNAP` to 8: the eyes drift lazily after the finger.
- `Gaze.SOFT` to 0: every glance goes all the way to the rim, which looks startled.
- `Mood.EASE` to 60: faces snap from one feeling to the next and lose their softness.
- `BoardView.WORRY_STEPS` to 0: the marble only worries on the cell it falls from.

---

## 18. A flat disc that reads as a ball

A marble is drawn as a disc, and two things make it read as a ball: the light on it, and a pattern that turns
as it rolls.

**The light** (`Spin.light`). The ball's surface at a point `(x, y)` of the unit disc faces along
`n = (x, y, sqrt(1 - x² - y²))`. The light comes from the upper left and in front, `L`, and a surface is lit by
the cosine of the angle between them, `max(n · L, 0)` (Lambert's law). With a floor of ambient light,

    brightness = 0.25 + 0.75 max(n · L, 0)

Near the lower right rim the tray throws some light back up, which is what makes the shadow side of a real ball
glow at its edge: `(1 - n_z)² max(n̂_xy · B, 0)`, strongest at the rim and facing the bounce `B`. The colour of
each set is taken to be the ball at the brightness of its middle, 0.72, so the light is drawn as a layer over it:
black, with opacity rising as brightness falls below 0.72, and white, rising as it climbs above. It is the same
for every colour and every set, so it is computed once into one 128 pixel texture and each marble draws it with a
single call over its own finish, before its face. The finish's own highlight sits where light reflects toward the
player, the half vector `normalize(L + V)`, which for this light is 0.28 and 0.35 of the radius up and left of
the middle.

**The roll** (`Spin.roll`). Seen from above, a ball rolling a distance `s` along `d` turns by `s / r` about the
axis in the board at right angles to `d`: with x to the right, y down the screen and z out of it, that axis is
`(-d_y, d_x, 0)`. Rolling right turns the top of the ball right. Each frame the turn is composed onto the ball's
orientation, a 3D rotation, and re-orthonormalised so rounding never lets it drift into a shear. Spots fixed on
the ball are turned by it and drawn where they face the player (`z > 0`), smaller and fainter toward the rim,
where they are seen edge on.

A marble rolls a cell in 52 ms, about three frames, and a true roll turns it `1 / 0.36 = 2.8` radians a cell, 51
degrees a frame. A pattern that jumps 51 degrees a frame is past what an eye follows: it flickers, or it seems to
turn backwards, the wagon wheel effect. So the pattern turns at 40% of a true roll (`Spin.SHARE`), about 20
degrees a frame, and still reads as a roll. On the title's seesaw, seen from the side, the ball turns in the
screen's plane instead, at the true rate, since it rolls slowly.

The pattern shows only while the ball moves, faded in by its speed. A marble at rest looks exactly as its set
draws it, so the paid sets keep their look, and the pattern never shows stopped at an odd angle. Each set turns
something of its own: Classic and Pearls light spots, Glass a vane inside, Gems glints, Planets storms, Candy
sprinkles and Yarn its strands.

### Things to try

- `Spin.SHARE` to 1.0: the true roll. Watch a long roll at full speed: the spots strobe.
- `Spin.BOUNCE_LIGHT` to 0: the shadow side goes flat, and the marble looks like a sticker again.
- `Spin.TRUE_AT` to 0.5: every marble comes out lighter than its colour.

---

## 19. A win you can hear and feel

Every sound is made in `tools/make_sfx.py` from sines and seeded noise.

**Going home.** Each marble still rings its bell, and a glass plop now comes with it: a short tick of two
partials at 2.35 and 3.71 kHz, out of tune with each other as struck glass is, then a drop whose pitch rises
from 480 to 900 Hz. A drop of water makes that rising note: the air bubble it traps shrinks, and a smaller
bubble rings higher. Sparkles and a ripple in the marble's colour go out from the hole, and the phone ticks for
10 ms at a third of its strength.

**The last marble** slows down: its last cells play at 65% and then 32% of normal speed, and it drops in more
slowly. Only the board's own animation slows (`Tween.set_speed_scale`), not the game's clock
(`Engine.time_scale`), so no timer, ad pacing or sheet is touched. As it drops, the bells resolve into the
chord: C4 and G4 open at the bottom, then E5, A5 and D6, rolled upward 45 ms apart. The sink bells are C5, E5,
G5 and A5, all notes of this chord, so it follows whichever marble is last. The spacing follows the overtone
series, wide at the bottom and closer at the top: two notes a third apart low down sound muddy, and at C4 and G4
the bottom is a fifth. A phone's speaker gives little below a few hundred hertz, so the chord goes no lower
than C4, 262 Hz.

The win sheet waits for all of it: it rises 0.7 s after the winning tilt, where it used to rise after 0.3, and
on three stars with faces on one marble from each hole pops back out in a party hat with confetti first, which
adds 0.9 s (`game.gd`, `WIN_PAUSE` and `PARTY_TIME`). An undo or a restart in that time takes the win back and
no sheet comes. The stars on the sheet then land on E6, G6 and C7, climbing the same chord, at the pitch ratios
`2^(-3/12) = 0.841`, 1 and `2^(5/12) = 1.335` of the star's own G6.

**Rolling.** While marbles move, a bed of rolling sound plays: noise between 90 and 700 Hz, ringing in two
wooden resonances at 230 and 470 Hz, with small grain ticks at random about forty times a second and a slight
flutter. It loops, and its loudness follows the board: the sum of every marble's speed, in cells a second, over
a single marble's full speed, under a square root. Sounds that are not in step add in power, not in amplitude,
so four marbles rolling together sound about twice as loud as one (+6 dB), not four times. A faster roll also
plays a little higher, as a real one does. The bed rises in about 30 ms and dies away over about 110, so a roll
starts on the beat and ends softly.

**Stopping.** A marble that stops against a wall knocks softly (partials at 310, 760 and 1620 Hz, as wood),
one that stops against another marble clinks (2.78, 4.53 and 6.9 kHz, as glass), a few milliseconds apart, so a
line coming to rest sounds like one. The new knock plays about 4 dB under the clack it replaces.

Loudness, measured as the loudest 400 ms of each clip at the gain the game plays it (the momentary loudness of
EBU R 128, so a short clip measures lower than it sounds):

| Sound | At its gain |
| --- | --- |
| a sink bell | -15 LUFS |
| the old win jingle, no longer played on a level | -15 |
| a star | -20 |
| the chord | -22 |
| the plop | -30 |
| the old stop clack it replaces | -33 |
| rolling, one marble at full speed | -34 |
| a knock | -37 |
| a clink | -39 |

### Things to try

- `BoardView.SLOW_LAST` to (1, 1): the last marble drops in at full speed, and the chord comes a beat early.
- `Audio.ROLLING_FALL` to 60: the rolling stops dead when the marbles do.
- In `make_sfx.py`, voice the chord C4, E4, G4: the low third sounds thick on a phone.

---

## 20. The memorial: one pass of grey

With faces on, a marble down a pit gets a short memorial in the spirit of the studio's reel: the screen turns
black and white, the marble's photo stands framed with a candle and a flower, its name below, and then the
colour snaps back and the pit banner rises with Undo. It lasts 1.15 s for the first three in a session and
0.55 s after that (`Mood.memorial_length`), and a tap or any key ends it at once, an undo or a restart going
straight on to do their work. A player trying a level for the tenth time is never held up.

The grey is one shader pass over what is already on the screen (`grey.gdshader`), a full-screen rectangle that
reads the screen texture, which the GL Compatibility renderer supports. A grey that keeps brightness has to be
the luminance, a sum of linear light: `Y = 0.2126 R + 0.7152 G + 0.0722 B`, how much each of the screen's
primaries adds to the brightness the eye sees (Rec. 709). The canvas holds sRGB values, which are not linear, so each channel is decoded,
`((c + 0.055) / 1.055)^2.4`, summed, and encoded back. Done on the raw values instead, a saturated colour comes
out too dark. The same pass dims the edges a little, so the eye goes to the middle. A light theme's board gone
grey is still light, and on it the first memorial's white name all but vanished, so the card stands on a dark
plaque and its words are outlined. Shaders compile the first
time they are drawn, which on a cheap phone can stall a frame, so the play screen draws this one once,
unseen, when it opens.

### Things to try

- `Mood.MEMORIAL_FULL_COUNT` to 0: every memorial is the short one.
- In `grey.gdshader`, sum the raw values instead of the decoded ones and compare the red marble's grey.

---

## 21. Walls that sleep

With Pets on, each wall is an animal asleep in a loaf, a cat or a dog (`scenes/game/loaf.gd`, its family and
coats in `scripts/feel/litter.gd`): the same rounded block with the same darker lip along its bottom, with ears,
shut eyes and a nose, and a tail curled round the front for a cat or a snout and floppy ears for a dog. Cats and
dogs take turns level by level, so the board looks new every time. Pets is its own setting, off by default and
apart from Faces: some players want calm, plain walls, so the extra character is something a player turns on.

**Still a wall first.** Every coat is worked out from the wall's own colour in the theme now: grey is the wall
itself, dark is 13% darker, pale 20% lighter, warm 36% of the way to a ginger (a tan for a dog), and patched
pale with ginger and dark patches. That keeps every animal within a step of the wall. A dark coat on a dark
theme's board moves toward the floor, though: in one of the colour themes it came out at 1.98:1, under the 2:1
the plain wall must meet. So a coat that would come closer to the floor than 2.2:1 steps back toward the wall,
a tenth at a time, until it does not (`Litter.fur`). The theme decides whether that is darker or lighter, and
the tests check every coat in every theme, light and dark. The sleeping faces are drawn in a line a step lighter
than a dark coat and a step darker than a light one (`Loaf.INK_TURN`), so they read on both without standing out
from the wall. A dog's tail stays tucked away until it wags: poking up at rest, it read as an aerial. A coat is
picked for a cell from a hash of the cell and the level, so neighbours mostly differ and a board looks like a
litter.

**Only a woken animal is drawn again.** Each animal is its own node, drawn once. When a marble stops against
one it wakes: eyes open, a cat flicks an ear and trills, a dog wags and huffs, and it falls back asleep after
0.8 s. Only that node draws again while it moves, and it stops processing when it is still. Now and then, as the
board tips, one animal on that side stirs without waking. With Pets off, the board draws its plain blocks as
before and makes no animals at all, and turning it on or off mid-level swaps them at once.

### Things to try

- `Litter.DARKER` to 0.5: dark cats on a light board come close to the pits.
- `Litter.family_for` returning a family by chapter (`Pack.chapter_of`) instead of by level: twenty boards in a
  row of cats.

---

## 22. The bouncy block: back the way it came, once a tilt

Shravan's idea: blocks a marble bounces off, going back to where it came from. The rule for players is one
sentence: a marble that rolls into a bouncy block goes straight back the way it came, until something stops it.

**In the step loop of section 1.** A bouncy block is a cell no marble ever enters (`TiltBoard.Tile.BOUNCE`). When
the next cell along a marble's heading is a bouncy block, the marble turns to the opposite heading and, in the
same pass, tries the cell behind it as any move would. So the step it bounces on is the step it moves away, and a
marble already resting against a block when the tilt starts goes back too. Everything else is the old loop:
front first, one cell a step, a marble stopping when its next cell is taken or shut.

- **Once a tilt.** A marble that has bounced in this tilt meets every bouncy block as a wall (`bounced` in
  `tilt`). A player can follow one bounce, and two blocks facing each other no longer pass a marble to and fro.
  With section 9's loop guard it means every tilt ends. The bounce lives only inside a tilt, so the solver's key
  needs nothing new, and its search never loops.
- **Meeting other marbles.** The front marble moves first, so when it bounces, the marbles behind it have not
  moved in this step yet. Its way back is the cell it came from: if the marble behind still sits there, it stops
  against it, and the one behind stops against it in turn, so a train that runs into a block packs up against
  it. One rolling behind with a gap meets it halfway: the bounced marble takes the free cell first, and the one
  behind stops against it.
- **The way back is any roll.** A marble going back drops into its own hole, falls into a pit, stops on a pad,
  takes paint, is turned by a bumper, goes through a portal, is held by a one-way gate against its way, jumps
  from a spring over the cell behind it, and a cracked cell it leaves gives way. A stone bounces as a marble does.
- **No move.** A tilt where a marble bounces but nothing can move, a marble pressed between the block and a line
  of others, changes nothing and does not count, like any tilt that moves nothing.
- **Without the rule** (section 8), the blocks become floor. A level needs its blocks either way: to send a
  marble back where nothing else would stop it, or to stop it where floor would let it run on.

`tests/run_tests.gd` checks each case on a board of one row, and that a board the block turns from one tilt into
three needs it.

**How it looks and sounds.** A soft lime jelly filling its cell (`Jelly`, `Palette.JELLY`), rounder than a wall,
with a gloss on top and no lip, so it never reads as a wall or a sleeping animal. The marble rolls up against it,
the jelly gives along the hit and swells across it, ringing out over 0.6 seconds as a damped spring,
`cos(2π f s) e^(-6.7 s)` after s seconds with f = 5 wobbles a second (`Jelly.WOBBLE_RATE`), and a soft boing plays: a note that springs down in pitch from 520 Hz to 190 Hz and wobbles
as it settles, over a muffled thump. It draws on its own random stream in `tools/make_sfx.py`, so every other
sound stayed byte for byte. With faces on, the marble looks startled: eyes wide, small pupils, brows up and a
round mouth (`Mood.surprise`), above a bump and below worry. The tests hold the lime at 2.5:1 against the floor
in every theme, light and dark, and a tenth of a turn of hue away from every marble of every look.

**Where it goes: chapter 10, made last.** The new chapter sits at the start of the plateau (section 16), where
players meet it just after level 180, and no player had stars there yet. Made there in the usual order, it would
have changed every chapter after it, since the generator is one random stream and every level is checked against
the ones before. So a chapter marked `after_hard` is made after all the others (`TiltGenerator.making_order`),
from the random state the last of them left, and is written in its place. The chapters made before it keep their
boards, their order and their saved random states, now a chapter later, and the tests pin all three. A full run
from the seed still writes the same file. The level file keeps its random states in the order the chapters are
made, and `resume` counts chapters made.

- **Hard** has no bouncy chapter: `Pack` gives the Hard section the main path's chapters without the ones marked
  `after_hard`, so Hard is exactly as it was, its 25 chapters and their colours included.
- **Old saves** move on as in section 16, with every old chapter from 10 on one later: the bouncy blocks' first
  level opens with every chapter up to the furthest reached (`HardShelf.ADDED`).
- **Colours.** Section 13's stride for 26 chapters is 7, so every main chapter's colour moved a little. Hard
  keeps 25 and its colours.
- **The daily puzzle** keeps marbles, walls and colours only. A player can play it from chapter 1 on, long before
  the block is taught.

**Measured.** On 8 worker processes the chapter took 17 minutes of generator time: its first phase pooled 80
boards from 10,008 proposals and its second 80 from 9,480. Its levels need par 12 (19 of them) or 13 (the last)
at 18.87 to 19.75 bits, the first ten on 7x7 boards and the rest on 7x8, with one to three blocks each. Every
one of the 20 shortest solutions bounces, one to six times. Neither naive player of section 16 clears any of
them in par.

### Things to try

- `Jelly.GIVE` to 0.45 and `Jelly.WOBBLE_RATE` to 3: a slow, deep wobble, more water balloon than jelly.
- In `TiltBoard.tilt`, take the `bounced` check off: two blocks facing each other pass a marble back and forth
  until section 9's loop guard stops it, on the first cell it reaches again heading the same way.
- `Mood.SURPRISE_TIME` to 0.2: the startled look is gone before the marble stops rolling back.

---

## 23. A party for every win

A solved board was quiet: the last marble's chord, then the sheet. Now every win is a small party
(`scenes/celebrate/celebration.gd`, its pieces in `flourish.gd`), all drawn in code with tweens and short-lived
nodes, so it costs nothing until it plays:

- **The board.** As the chord rings, two confetti cannons fire up from the tray's lower corners, the board hops
  and lands with a bounce, and one word of praise pops over it with a wobble: Perfect, Flawless or Brilliant for
  three stars, Great, Nice or Smooth for two, Solved or Done for one. It is also the sheet's heading. With faces
  on, three stars bring the marbles back out of their holes in party hats, and they jump twice. 1.6 s in all.
- **The sheet.** Each star slams in from 2.4 times its size with a burst of confetti and a shake of the row, on
  the win chord's notes (section 19), the phone ticking harder each time. The star total counts up under them, the
  chapter's bar fills in its colour, and Next wiggles every 1.7 s until it is pressed. The kit lands
  the stars through `Result.award`, so another game can do the same its own way.
- **A finished chapter.** The board dims, a dot for each of the chapter's levels lights round a ring, one every 45
  ms, and the number in the middle runs through those levels' numbers as a player sees them (`Shown`: 181 to 200,
  or Hard's own 1 to 20), then lands on the chapter's number, with a pop and the word CHAPTER over it, as the
  cannons fire again and the bells play a ta-da. Counting through the levels says what was finished, and the word
  says what the last number means, so it can never be read as a level.
- **Never in the way.** A tap anywhere during the party or the chapter's moment skips straight to the sheet, and
  an undo or a restart takes the win back. Every sound plays at or under the old win jingle (section 19).
- **Around it.** On Levels a newly opened level pops open with confetti, solved levels shine now and then, and
  the next one breathes in a gold ring. Screens change under a red circle that grows from the middle and shrinks
  away. On Home, Play wiggles and confetti puffs up from the seesaw every five seconds.

**Tried.** Three directions were built side by side and recorded the same way: this one, Party; Glow, a calm
luxury where a band of light swept the board, the holes bloomed in their colours and the stars opened with halos
over a warm chord; and Toybox, where tiles lifted in a ripple from the last hole, stars dropped in like marbles
into cups and screens slid like drawers. Shravan picked Party, for the confetti, and the other two were taken out.

### Things to try

- `Celebration.BOARD_TIME` to 0.8: the sheet comes up while the confetti is still falling.
- In `chapter_moment`, set `fill` to 2.0: the count through the levels slows enough to read every number.

## 24. Dead ends: the hint walks back first

A dead end is a position with every marble still on the board that can never be won. It happens on almost every
level. Most often a helper marble went home too early, and the one left has nothing to stop against where it needs
to stop. Or a marble crossed something that only lets it through one way. Nothing on screen says so, so a player
keeps tilting until they ask for a hint.

To count them, take every position reachable from a level's start (a breadth-first search with no goal), then walk
backwards from the won positions along the same tilts. Anything that walk never reaches is a dead end:

| Level | Positions reachable | Dead ends |
| --- | --- | --- |
| 2 | 14 | 12 |
| 175 | 3,555 | 0 |
| 181, the first bouncy block | 7,460 | 1,517, about one in five |
| 190 | 732 | 396, more than half |
| 201, cracked floor | 112 | 58 |

The hint used to answer a dead end with "No way home from here. Undo or restart", which left the player to guess how
far back the mistake was. Now `TiltSolver.way_back` runs the same search (section 2) on the boards kept for undo,
newest first, and the first one with a way home is where the game takes the player, with "Dead end. Took back 2
tilts", before the hint is given from there. Like an undo, it is free. It costs one hint search for each tilt it
takes back, each held to the hint's own 30,000 positions.

Following the hint can never lead into a dead end. A shortest way home from a position is still a way home after
its first tilt, so every hint keeps the player on a winnable path.

### Things to try

- In `_walk_back`, return false at the top: the old "Undo or restart" comes back, and level 190 shows how often it
  appears.
- Pass `HINT_SEARCH / 10` to `way_back`: on late levels some winnable boards give up the search, so the walk goes
  further back than it needs to.

---

## 25. The rolling street

Plumb 2.0's Home is a street that rolls toward the player like a small planet (`REVAMP_PLAN.md`). It is drawn in 2D
with one small projection, `StreetProjection`, rather than a 3D camera, so the houses, the cast and their faces stay
ordinary 2D drawings, always upright.

**The street is a strip.** Every point on it has `s`, how far along the street it is, and `x`, how far across from the
middle, both in design pixels. Doors stand every 390 pixels of `s`, on alternate sides (`StreetPath`). Scrolling only
changes one number, `c`, the `s` at the bottom of the screen.

**The strip lies over a drum.** Wrap the strip over a drum of radius R, seen from the side. A point `s - c` along it sits
at the angle θ = (s - c) / R over the drum, and it shows at

    y = near_y - R sin θ        depth z = R (1 - cos θ)        scale k = F / (F + z)        x_screen = mid_x + x k

At θ = 0, the bottom edge, a point is full size. As θ grows the point climbs the screen ever more slowly, since sin θ
flattens, and shrinks, since its depth grows. At θ = π/2 it reaches the horizon, R pixels above the bottom edge, and
there it stops: the drum's surface turns away from the viewer. That slowing climb is the whole look. Near things
spread out, far things crowd toward a horizon that never moves, and scrolling turns the drum so the next doors rise
over it. Each constant has one visible effect: R is how tight the little world is, and F (the focal length) how
quickly things shrink with depth. A last touch, a bow, sinks points toward the sides by `bow (x k)²`, so the street
reads as a planet and not a log.

**Flat when R is huge.** For a very large R, sin θ is θ and cos θ is 1, so y = near_y - (s - c) and k = 1: a plain
scroll. Reduce motion uses exactly this, with no second drawing path.

**The ground never moves.** The ground is a mesh of rows evenly spaced down the screen, each placed once by the
projection, and its corners hold their strip coordinates (`s - c` and `x`). Scrolling changes no vertex. The ground
shader adds `c` back and paints the grass and the road at `s`, the road's centre being the same sum of two sines the
doors stand beside (`StreetPath.road_x`, its constants passed in as uniforms). The road and the doors cannot drift
apart, since both read one function.

**Rising over the crest.** Things a little past the horizon (θ up to π/2 + 0.4) are placed too, and drawn before the
ground. Their foot is then below the horizon line, hidden by the ground drawn over it, and only the part above the
crest shows. As the drum turns, a house rises over the hill top first and then walks forward. Everything nearer is
drawn after the ground and sorted by screen height, which here is the same as sorting by depth.

**The street under a finger.** To make the street follow a finger exactly, the map remembers the strip point under
the finger as it goes down, `s0 = c + R asin((near_y - y) / R)`, and while it drags keeps that point under it:
`c = s0 - R asin((near_y - y) / R)`. Near the horizon a pixel of finger movement turns the drum a long way, so the
grab is held at θ = 1.25.

**Measured on the A142** (Nothing Phone (2a), Mali-G610, 60 Hz, M1 on 20 November 2026, stand-in art drawn from one
baked atlas): over three rounds of flings, a steady roll and rests, SurfaceFlinger presented the street at 60 frames a
second with no missed refresh in 4,084 frames, in 8 to 18 draw calls. With the four cast marbles drawn by `Marble`,
which draws its shapes one by one, draw calls rose to 32 to 179 and 13 of 4,308 frames missed one refresh. The
stand-ins first drew in code, shape by shape, at 541 draw calls a screen. Baked into one texture they batch, which
is why the painted art comes as cut-outs packed into an atlas.

**A radius chosen for the title.** The PLUMB title sits in the sky and must only ever have blue sky behind it
(Shravan, 21 November), while the street keeps rolling like a little round world. Nothing on the drum rises higher
than the crest, and at the crest a thing of height `h` reaches `h · k(π/2)` above the horizon, where `k(π/2)` is the
scale at the horizon. So the map picks, for each screen, the largest radius whose horizon still sits low enough:

    horizon_y - max(HILLS_RISE, TALLEST · k(π/2)) ≥ title's foot + TITLE_CLEAR

A larger radius raises the horizon, so the right radius is found by halving the range until the two sides meet
(`_radius_for` in `map.gd`). A taller phone gets a larger, gentler world, a short one a tighter one, and on every screen
houses come up over the horizon, grow as they travel down and leave through the screen's foot. Nothing fades.

**A camera tilted down at the street.** The drum alone shrinks things only near the horizon, since its depth grows
with the square of the distance along it. The concepts show the next door about three quarters the size of the one at
rest, and the one after about half. So the depth also grows in step with the distance, `depth = R (1 - cos θ) + tilt ·
s_rel`, as it does for a camera looking down at a slope: with TILT 0.6, each door is drawn smaller than the one before
by a steady share. The scale is then multiplied by a `gain` chosen so the door at rest is drawn at exactly its painted
size, and the road, the houses and the cast are all sized against that door. The drum's radius grows with the
screen's height, so a 16:9 phone keeps the same sky as a 20:9 one.

**The road winds past every door.** Its big swing is a sine one door long each way, timed to peak just in front of
each door on that door's side: `road_x = SWAY_A sin(2π s / (2 DOOR_GAP) + phase)`. So the road passes the front of
every house, as in the concept, and the cast stands on it there. On a bend the road is measured square to itself
(`across / √(1 + slope²)`), so it is as wide on a bend as on a straight.

### Things to try

- `RADIUS` in `scenes/street/map.gd` to 700: a tight little planet with a low horizon. To 100000: the flat scroll of
  Reduce motion.
- `TILT` to 0: the bare drum, where the next doors stay almost as big as the one at rest. To 1.5: a steep camera,
  the far doors tiny.
- `FOCAL` to 400: things shrink much faster with depth, as through a wide lens.
- `BOW` to 0: the street becomes a log rolling toward you instead of a planet.
- `StreetPath.SWAY_A` to 0: the road runs almost straight up the middle.

## 26. A card on a string, a hop home, and a picture that stretches

Three small ideas carry Street's start card and its win (`scenes/street/door_card.gd`, `homecoming.gd`, `art.gd`).

**The card swings on a spring.** A tapped door's card drops from the top and then swings about a point far above the
screen, as if it hung on a string. The swing is a damped spring, stepped once a frame:

    spin  += (-STIFFNESS · angle - DAMPING · spin) · dt
    angle += spin · dt

The first term pulls the card back toward hanging straight, harder the further it leans. The second drags on its
speed, so each swing is smaller than the last. With STIFFNESS 90 the card would swing back and forth about
√90 ≈ 9.5 radians a second, a full swing in about two thirds of a second. DAMPING 7 against that speed gives a
damping ratio of 7 / (2 · 9.5) ≈ 0.37: well below 1, so it overshoots and settles after two or three visible swings.
At a ratio of 1 it would ease straight down with no swing at all. Updating `spin` first and then moving `angle` with
the new `spin` keeps the motion steady even when a frame runs long.

**A hop is a parabola.** A marble hopping from `a` to `b` slides along the straight line between them while rising and
falling by `HOP · 4t(1 - t)`. That product is 0 at the start and the end and peaks at exactly 1 halfway, so the hop's
top is HOP pixels above the line, whatever the distance.

**Nine slices.** The card's frame, its inner panel and the pills are each one painting that must fit many sizes.
Codex marks four margins on each (`nine` in its JSON). The four corners are drawn as painted. The top and bottom
edges stretch sideways only, the left and right edges only up and down, and the middle both ways. So the rim, the
flowers and the rounded ends keep their shape at any size. A nine-patch draws its margins at their pixel size, so
`StreetArt.draw_nine` draws in the painting's own pixels and scales the whole patch, which keeps a rim as thick,
relative to the screen, as Codex painted it.

### Things to try

- `SWING_DAMPING` in `door_card.gd` to 2: the card keeps swinging for seconds. To 19: it settles with no swing.
- `SWING_STIFFNESS` to 30: a slower, heavier swing, as on a longer string.
- `HOP` in `homecoming.gd` to 400: the marbles leap home over the roofs.

## 27. Tap anything: the wobble

In Street, a tap on anything (a house, a tree, the sun, a marble, a button) makes it wobble like a jelly, as in
Candy Crush. One small script makes every wobble, `scripts/street/jiggle.gd`.

**One number on a spring.** The wobble is a single number, the squash `s`: 0 at rest, positive for wider and shorter,
negative for narrower and taller. It hangs on the same damped spring as the start card (section 26), stepped each
frame:

    v += (-STIFFNESS · s - DAMPING · v) · dt
    s += v · dt

A tap does not move `s` at all. It gives it a speed, `v += KICK`, the way a flick sets a ruler twanging. The spring
then carries it out, back through rest and out the other way, each swing smaller than the last.

**How it feels comes from two numbers.** STIFFNESS 400 sets how fast it wobbles: √400 = 20 radians a second, about
three wobbles a second. DAMPING 18 sets how fast it calms: each wobble's size shrinks as e^(−9t), half again
every 0.08 s, so each bounce is about a fifth of the one before and it is still within half a second. The damping
ratio, 18 / (2 · 20) = 0.45, is the jelly: at 1 it would ease back without a single bounce, and near 0 it would
wobble for seconds.

**The area stays the same.** Squash something and it should bulge, as a ball of dough does, not shrink. So the width
is `1 + s` and the height `1 / (1 + s)`: their product, the area, is always exactly 1.

**A rock, a quarter of a beat late.** The tilt follows the squash's speed `v`, not the squash itself. A sine's speed is
a cosine, a quarter of a wobble out of step, so the piece leans most while it passes through its rest shape and
stands straight at the widest and tallest moments. That lean is what makes it look loose rather than mechanical.

**Steady at any frame rate.** A long frame is stepped in slices of 1/120 s, so a phone that stutters wobbles exactly
as one that does not. A test checks that one slow frame and twelve quick ones land on the same squash.

**Idle life uses plain sines** instead, each with its own phase from the thing's number so nothing moves in step:
trees and bushes lean (`StreetProp.SWAY`), the cast breathes (a squash of 2.5% at 1.7 radians a second, the area
kept the same way), buttons breathe, and the sun turns. Reduce motion stops all of it, and a tap then answers with a
short fade instead of a wobble.

### Things to try

- `DAMPING` in `jiggle.gd` to 8: a long, floppy jelly. To 40: one firm squash with no bounce.
- `STIFFNESS` to 150: a slow, heavy wobble, like a water balloon.
- `KICK` to 8: a tap that nearly flattens it.
- `TILT` to 0: it bounces straight up and down, and loses most of its life.
