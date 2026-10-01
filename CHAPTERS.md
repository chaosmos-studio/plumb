# Plumb to 500 levels: chapters

A design for review. Nothing here is built yet.

## The idea

500 levels as 25 chapters of 20. Each chapter brings one new rule. Its first level shows that rule alone on
a small, easy board, with a one-line caption. The next few levels explore it, and the rest of the chapter
mixes it with one or two rules the player already knows. Difficulty climbs inside a chapter and dips a
little at the start of the next, the sawtooth that keeps a long puzzle game fresh (Portal, Baba Is You,
Stephen's Sausage Roll all pace this way). A chapter is exactly one page of the Levels screen, so the page
can carry its name.

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

## The 25 chapters

Twenty-one new rules after the four the game already has, chosen for how well they read on a phone, how
well they combine, and what they cost. Chapter 25 brings no new rule and mixes everything: the finale.

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
| 10 | 181-200 | Cracked floor | pits, stop pads |
| 11 | 201-220 | Stones | pits, cracked floor |
| 12 | 221-240 | Portals | one-way gates |
| 13 | 241-260 | Bumpers | portals |
| 14 | 261-280 | Switches and doors | stones |
| 15 | 281-300 | Keys and locks | colour gates |
| 16 | 301-320 | Blinking walls | switches |
| 17 | 321-340 | Conveyors | bumpers |
| 18 | 341-360 | Springs | pits, cracked floor |
| 19 | 361-380 | Wrap edges | portals |
| 20 | 381-400 | Magnets | conveyors |
| 21 | 401-420 | Numbered marbles | plugs |
| 22 | 421-440 | Glass posts | stones |
| 23 | 441-460 | Colour mixing | paint pads, colour gates |
| 24 | 461-480 | Moving holes | stop pads |
| 25 | 481-500 | Finale: everything | all |

Held in reserve for later updates: locked direction, twin marbles, hole capacity, ice holes, mirror halves,
turnstiles, gravity cells, sticky floor, fragile marbles.

## What changes beyond the rules

- **The Levels screen** names each page after its chapter ("Chapter 12, Portals") and shows the chapter's
  number instead of 25 page dots.
- **A chapter card** opens the first level of each chapter: the rule's name and one line about it.
- **Captions** teach each rule on its first level, as the game does now for colours and pits.
- **Saves** keep stars for all 500 levels. The current 120 become chapters 1 to 6, regenerated so the
  schedule is one piece.
- **Generation** runs per chapter, so one chapter can be remade without touching the others. A full
  run grows from about 3 minutes to roughly half an hour.

## How it ships

In waves, each one a store update players can feel:

| Update | Chapters | Levels | New rules |
| --- | --- | --- | --- |
| 1.1 | 1 to 10 | 200 | stop pads, one-way gates, plugs, colour gates, paint pads, cracked floor |
| 1.2 | 11 to 15 | 300 | stones, portals, bumpers, switches, keys |
| 1.3 | 16 to 20 | 400 | blinking walls, conveyors, springs, wrap edges, magnets |
| 1.4 | 21 to 25 | 500 | numbered marbles, glass posts, colour mixing, moving holes, the finale |
