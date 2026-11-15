# Plumb to 500 levels: chapters

The plan for Plumb's 500 levels, all 25 chapters built, and a 26th on the main path since (Bouncy blocks). How the chapters are generated, and why every level
needs its rule, is in `MATH.md` sections 8 to 10. As built, a switch holds its hatch open for a whole tilt if
something rests on it as the tilt starts, a portal whose twin is taken is shut, and conveyors, ice holes and
glass act once the board has stopped.

**Revised while building (2026-10-03).** Colour mixing and moving holes went back to the reserve: mixing
needs colours that mix, and the marble sets include planets, gems and candy; moving holes would have made
every hole a rolling body for one chapter. Ice holes, from the reserve, took chapter 23. The reserve's
locked direction was planned for 24, but a lock that never moves leaves almost no board solvable at par 16,
so it became a turning lock: one way is locked, and the lock turns a quarter clockwise after every tilt.
And from chapter 11, levels are ordered by par first, then bits (`MATH.md` section 10): par never falls,
bits never fall within one par, and bits may start lower when par steps up.

**The plateau and the Hard levels (2026-11-15).** Shravan played the game and found it unplayable from
about level 180, while he loved the early levels. So the main path stops climbing at a comfort ceiling
(`MATH.md` section 16): chapters 10 to 25 were made again at level 160's difficulty, par 12 and 18.85 bits,
each level at most one move and 1.5 bits above it (the turning lock's bits measured against its three
tilts), on boards no larger than 7x8 with five marbles. Every
chapter still brings its rule, with its card and caption on its first level, and every level still needs
it. The old levels 181 to 500 are kept as they were, as the Hard levels, open from the start. Levels 1 to
180 did not change.

**Bouncy blocks (2026-11-15).** Shravan's idea: a marble that rolls into a bouncy block goes straight back the
way it came, until something stops it, once a tilt (`MATH.md` section 22). It became chapter 10 on the main path,
where players meet it just after level 180, and the plateau's other chapters moved on one, boards unchanged, to
11 to 26. The main path has 520 levels in 26 chapters. The Hard levels did not change.

**The opening (2026-10-04).** Levels 1 to 5 are picked for what they show as well as how hard they are
(`MATH.md` section 12): a long roll home, two marbles dropping on one tilt, a bank off a wall, a tempting tilt
that costs par, and two marbles dropping together on the last tilt. They stay under level 6 in every measure,
and no level after them changed.

## The idea

500 levels as 25 chapters of 20, and room for more chapters after them. Each chapter brings one new rule.
Its first level makes that rule the thing to notice, with a one-line caption, and the rest of the chapter
explores it and mixes it with rules the player already knows. A chapter is exactly one page of the Levels
screen, so the page can carry its name.

**Difficulty climbs to a ceiling, then holds.** Over levels 1 to 180 every level is at least as hard as the
one before it, chapter starts included: the measured difficulty (par and bits, `MATH.md` section 5) rises
steadily. A chapter's first level there is not an easier board: the new rule is simple on its own, and the
rest of the board carries the difficulty the ramp asks for at that point. From level 181 the main path holds
a plateau at level 160's difficulty, never below it and never more than a narrow band above it. Each
chapter there starts again at the floor with its new rule and climbs gently through its levels, so the only
falls are at chapter starts, and never by more than the band. The Hard levels keep the old climb for players
who want it.

Every rule must keep the two promises the game already makes: the solver proves every level and finds par,
and no level repeats another. So each rule below is something the tilt solver can search and the generator
can place.

## The catalogue

Cost: S is a new cell type the solver and drawing pick up easily; M adds state to a board (the solver's key
grows); L changes how a tilt resolves.

| # | Rule | In one line | What it makes you think about | Where the idea comes from | Cost |
| --- | --- | --- | --- | --- | --- |
| 1 | Roll home | Every marble rolls until stopped and drops into its own colour | Stops, order of tilts | ThinkFun's Tilt, tilt mazes | built |
| 2 | Colours | Each marble needs its own colour's hole | Rolling some marbles past others' holes | sorting puzzles | built |
| 3 | Pits | A square pit swallows any marble and loses the level | Danger cells, safe routes | Labyrinth, every marble maze | built |
| 4 | Stop pads | A marble that rolls onto a pad stops on it | New places to park | Pokemon's ice puzzles and their stop rocks | S |
| 5 | One-way gates | A gate lets marbles through in one direction only | Routes that can't be undone | Chip's Challenge, Adventures of Lolo | S |
| 6 | Plugs | A hole closes once it takes a marble and becomes floor | Which marble goes first | 2048 and Threes, where a merge changes the board | S |
| 7 | Colour gates | A gate only lets its own colour through | Sorting marbles by where they can go | Hue puzzles, keycard doors | S |
| 8 | Paint pads | Rolling over a pad repaints the marble | Changing a marble to fit a hole | Splatoon's ink, Chroma puzzles | S |
| 9 | Cracked floor | A cracked cell becomes a pit after one marble crosses it | One-use paths | Zelda's cracked floors | M |
| 10 | Stones | Grey stones slide like marbles but never drop in; a stone that rolls into a pit fills it | Building your own bridge | Sokoban, Zelda's boulders into holes | M |
| 11 | Portals | A marble that rolls into a portal leaves from its twin, still rolling the same way | Rolling through walls | Portal, teleporter mazes | M |
| 12 | Bumpers | A diagonal bumper turns a marble 90 degrees | Bending a roll around a corner | pinball, Lazors | M |
| 13 | Switches and doors | A marble resting on a switch opens a door; leaving it closes it | Using a marble as a key you have to leave behind | Portal's buttons, Zelda floor switches | M |
| 14 | Keys and locks | Rolling over a key opens every lock of its colour for good | Detours that pay off later | Chip's Challenge keys | M |
| 15 | Blinking walls | Some walls are up on even tilts and down on odd ones | Counting tilts | Super Mario 3D World's on/off blocks | M |
| 16 | Conveyors | After a tilt, a marble on a conveyor is carried its way until stopped | Moves that keep going | Chip's Challenge force floors | M |
| 17 | Springs | A spring launches a marble over the next cell | Jumping walls and pits | pinball kickers, Mario's springs | M |
| 18 | Wrap edges | An open edge wraps a marble round to the far side | A board with no edge | Pac-Man, Asteroids | M |
| 19 | Magnets | A marble passing beside a magnet stops next to it | Stops in open floor | Magnetic puzzles, Kula World | M |
| 20 | Numbered marbles | Numbered marbles must drop in order: 1, then 2, then 3 | Order, not just routes | Simon, sequence puzzles | M |
| 21 | Glass posts | A glass post stops a marble once, then shatters | A stop you can spend | Breakout bricks | M |
| 22 | Colour mixing | Two marbles of different colours that meet merge into the mixed colour | Planning collisions | I Love Hue, paint mixing | L |
| 23 | Moving holes | Holes slide with the tilt too, stopping like marbles | Bringing the hole to the marble | Threes, sliding block puzzles | L |
| 24 | Locked direction | One tilt direction is unavailable on the board | Doing more with three moves | limited-move puzzles | S |
| 25 | Twin marbles | Two marbles joined by a rod move as one | Shapes, not points | Snakebird, Stephen's Sausage Roll | L |
| 26 | Hole capacity | A hole shows how many marbles it takes before it closes | Counting and sharing | bin packing puzzles | S |
| 27 | Ice holes | A hole only catches a marble that stops on it, not one rolling past | Precise stops | golf putting | S |
| 28 | Mirror halves | The board's right half tilts the opposite way to its left | Two puzzles with one move | Mirror games, Brothers | L |
| 29 | Turnstiles | A turnstile turns a quarter each time a marble pushes past | Doors that remember | Zelda and Lolo turnstiles | L |
| 30 | Gravity cells | A marble that stops on a gravity cell rolls on downward | One cell with its own tilt | Kula World, VVVVVV | M |
| 31 | Sticky floor | A marble that stops on glue stays there until another marble knocks it free | Marbles as tools | Lemmings blockers | L |
| 32 | Fragile marbles | A cracked marble breaks if it hits a wall at full roll | Gentle stops only | egg puzzles | M |
| 33 | Bouncy blocks | A marble that rolls into a bouncy block goes straight back the way it came, once a tilt | Turning a marble round where nothing stops it | Shravan's idea, pinball bumpers | built |

## The 25 chapters

Twenty-one new rules after the four the game already has, chosen for how well they read on a phone, how
well they combine, and what they cost. Chapter 25 brings no new rule: it mixes every rule so far, and new
chapters can follow it in later updates.

| Chapter | Levels | New rule | Mixed with |
| --- | --- | --- | --- |
| 1 | 1-20 | Roll home (one colour, one to three marbles) | |
| 2 | 21-40 | Colours, two then three | 1 |
| 3 | 41-60 | Pits | colours |
| 4 | 61-80 | Four colours, bigger boards | pits |
| 5 | 81-100 | Stop pads | pits |
| 6 | 101-120 | One-way gates | stop pads |
| 7 | 121-140 | Plugs | colours |
| 8 | 141-160 | Colour gates | plugs |
| 9 | 161-180 | Paint pads | colour gates |
| 10 | 181-200 | Bouncy blocks | pits, stop pads |
| 11 | 201-220 | Cracked floor | pits, stop pads |
| 12 | 221-240 | Stones | pits, cracked floor |
| 13 | 241-260 | Portals | one-way gates |
| 14 | 261-280 | Bumpers | portals |
| 15 | 281-300 | Switches and doors | stones |
| 16 | 301-320 | Keys and locks | colour gates |
| 17 | 321-340 | Blinking walls | switches |
| 18 | 341-360 | Conveyors | bumpers |
| 19 | 361-380 | Springs | pits, cracked floor |
| 20 | 381-400 | Wrap edges | portals |
| 21 | 401-420 | Magnets | conveyors |
| 22 | 421-440 | Numbered marbles | plugs |
| 23 | 441-460 | Glass posts | stones |
| 24 | 461-480 | Ice holes | stop pads |
| 25 | 481-500 | Turning lock | springs |
| 26 | 501-520 | Every rule so far, mixed (the bouncy block aside) | all |

The Hard levels keep the 25 chapters as they shipped, from chapter 10, Cracked floor, at levels 181 to 200, to
chapter 25, Every rule so far, at 481 to 500.

Held in reserve for later updates: colour mixing, moving holes, a lock that never turns, twin marbles, hole
capacity, mirror halves, turnstiles, gravity cells, sticky floor, fragile marbles.

## What changes beyond the rules

- **The Levels screen** names each page after its chapter ("Chapter 12, Portals") and shows the chapter's
  number instead of 25 page dots.
- **A chapter card** opens the first level of each chapter: the rule's name and one line about it.
- **Captions** teach each rule on its first level, as the game does now for colours and pits.
- **Saves** keep stars for all 500 levels. The 120 levels of 1.0 are regenerated as chapters 1 to 4
  and the first two new rules, chapters 5 and 6, so the schedule is one piece. Since the plateau they keep
  the Hard levels' stars apart, and a save from before it moves the stars won on old levels 181 to 500 to
  Hard (`MATH.md` section 16).
- **A Main and Hard switch** on the Levels screen shows either set. Hard starts at chapter 10, its levels
  keep their numbers, and Play on the title goes on along the main path.
- **Generation** runs per chapter, so one chapter can be remade without touching the others. A full
  run grows from about 3 minutes to roughly half an hour.

## How it ships

In waves, each one a store update players can feel:

| Update | Chapters | Levels | New rules |
| --- | --- | --- | --- |
| 1.1 | 1 to 10 | 200 | stop pads, one-way gates, plugs, colour gates, paint pads, cracked floor |
| 1.2 | 11 to 15 | 300 | stones, portals, bumpers, switches, keys |
| 1.3 | 16 to 20 | 400 | blinking walls, conveyors, springs, wrap edges, magnets |
| 1.4 | 21 to 25 | 500 | numbered marbles, glass posts, ice holes, a turning lock, every rule mixed |
