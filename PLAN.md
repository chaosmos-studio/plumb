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
- Monetization: ads and a Supporter pack in the Android build only, never touching difficulty (section 5).

### What this is not

Not a physics game: marbles move on the grid, one cell per step, so the solver and the player see the
same rules. No timers, no lives, no energy. No hand-made levels.

## 2. Core mechanics

- **Tilt** (swipe, arrow keys or WASD): every marble rolls one cell per step in that direction until a
  wall, the edge or another marble stops it. Marbles move front first, so a line rolls as a train.
- **Holes** accept any number of marbles of their colour, the moment one rolls over them. Marbles roll
  straight over holes of other colours.
- **Pits** (square voids) swallow any marble and lose the level. Undo is one tap.
- **Tiles** from chapter 5 on, one new per chapter (`CHAPTERS.md`, `MATH.md` section 8): a stop pad halts a
  marble that rolls onto it; a one-way gate lets marbles through in its own direction only; a ringed
  hole, a plug, takes one marble and closes; a colour gate lets only its own colour through; paint turns a
  marble its colour; cracked floor gives way into a pit once a marble rolls off it.
- **Undo** steps back one tilt and gives the move back. **Restart** returns to the start. **Hint**
  points the way the solver would tilt next, from wherever the board is now.
- A tilt that moves nothing is not a move: the tray twitches and nothing is counted.

## 3. Difficulty

Levels come in chapters of 20, one page of the Levels screen each (`CHAPTERS.md`). The first four teach
the game itself: an opening of five levels picked to be remembered (`MATH.md` section 12), a long roll home,
two marbles dropping on one tilt, a bank off a wall, a tempting tilt that costs par and two marbles dropping
together on the last tilt, then a second and third colour, pits, and four colours on 7x7 by level 80.
Each chapter after that brings one tile, taught by a card and a caption on its first level, and every
one of its levels needs that tile: the same board without it solves in a different par, or not at all.
Phases inside each chapter (`scripts/tilt/generator.gd`) fix the board size, colours, marbles, wall
density, pits, tiles and a par window. A random board is kept only if the solver proves it solvable
inside the window.

Difficulty is measured, not guessed. The score is the bits of luck a player tilting at random needs to
clear the board in par (`scripts/tilt/difficulty.gd`, `MATH.md` section 5). Each phase pools candidates
and keeps the run that follows a ramp in both par and bits, pinned to the 500 levels planned, so that
neither ever falls from one level to the next, chapter starts included, and no more than five levels in a
row share a score. Levels 1 to 180 climb that ramp from par 1 and 1.0 bits to par 14 and 20.9 bits.

The ramp stops at a comfort ceiling (`MATH.md` section 16). Shravan's playtest found the climb unplayable
from about level 180, so from chapter 10 the main path holds a plateau at level 160's difficulty, par 12 and
18.85 bits: no level from 181 on measures less, none more than one move and 1.5 bits above, on boards no
larger than level 160's 7x8 with no more than its five marbles. The turning lock leaves three tilts where
other boards have four, so its chapter's bits are measured against three. Each chapter starts again from that floor
with its new tile and climbs through half the band, so the only falls are at chapter starts, and never by
more than the band. Level 181 is easier than 180 on purpose.

The old climb from level 181 on is kept, board for board, as the Hard levels (`levels/hard.json`), open
from the start through a Main and Hard switch on the Levels screen. Hard keeps chapters 10 to 25 with
their cards and captions, its levels keep their numbers, and its progress is kept apart. A save from
before the plateau moves its stars on the old boards to Hard and opens on the main path the first level of
every chapter the player had reached.

No level repeats another. Compared over the eight rotations and mirrors with colour ignored, two boards
of one size must differ in 30% of their cells, or in half of them when one solution clears both
(`scripts/tilt/novelty.gd`, `MATH.md` section 4).

The fairness invariants, all checked from the boards by `tests/run_tests.gd` on every run: every shipped
level, main and Hard, solves in exactly its stated par under the current rules, and no level of either set
replays another. Levels 1 to 180 and the Hard levels are exactly as they shipped before the plateau,
and on that climb none is easier than the one before, par never falls and no more than five in a row are
equally hard. From 181 the main path stays inside the band over level 160, never falls within a chapter,
never falls by more than the band, has no more than five in a row equally hard, and every level needs its
chapter's rule. Neither a random nor a greedy player clears one plateau level in ten in par. Within a
chapter no level takes away room, a colour, a marble or a pit, and every pit level has a pit in play. A rule
change can never silently break the level set.

## 4. Screens

- **Title**: the wordmark, a seesaw of marbles rolling back and forth, their faces looking down the slope and
  squinting when they knock together, Play (continues at the first unsolved level), Levels, the star total.
- **Levels**: twenty tiles a page with the stars each has earned; the next level in the accent colour;
  later levels locked. A Main and Hard switch in the title's place shows either set, Hard from chapter 10.
  Play on the title always goes on along the main path.
- **Play**: level and par, the board, Undo and Restart, Hint, one line of guidance on the levels that
  introduce something, the result card (stars, moves against par, Next), and a pit banner (Undo).
  With faces on (the default), the marbles are characters (`MATH.md` section 17): Rosie (red), Steve (teal),
  Pip (amber) and Lulu (violet), a sleeping rock for a stone, each drawn upright on every marble set. They
  blink and look where the finger drags, go wide-eyed rolling, squint on a bump, worry on the way to a pit,
  scream as they fall, hop for joy going home and pop back out in party hats on three stars. A marble down a
  pit gets a black-and-white memorial with its name, a candle and a flower (about a second, shorter after the
  first three in a session, skipped by a tap) before the pit banner, and the only place a name is written.
  With Pets on, walls are sleeping cats or dogs, by turns level by level, that wake when a marble stops
  against them. Pets is off by default: some players want calm, plain walls, so the extra character is opt-in.
- **Settings**, a gear on every screen: sound, music, vibration, Faces, Pets, the theme (Auto, Light or Dark),
  How to play, Support the game, About, Credits, Privacy choices (only where the consent message requires
  them), and a guarded reset. Faces off gives the plain marbles, with no emotions or memorial. The two are
  separate: animals with faces off are allowed, the walls being a look of their own.
- **The guide** on level 1, once, and again from How to play: the goal and the help buttons on two
  cards, then the swipe itself, drawn by a ghost finger in the direction the solver would tilt next.
  Skip ends it at any point.
- **The ending**, after the last level is solved for the first time: a note from Shravan, signed, and a
  support line under it: the Supporter pack in the Android build, GitHub Sponsors on the web, and a
  thank-you for a Supporter.
- **Daily puzzle**, from the title once the first chapter is solved: one board a day for everyone, timed,
  turning over at midnight UTC-7 with Play Games' daily leaderboard. Its boards use only marbles, walls
  and up to three colours, and grow from a 6 by 6, par 5 to 7 Monday to an 8 by 8, par 9 to 12 Sunday
  (`tools/generate_daily.gd`). A calendar plays past days, after a video unless the Supporter pack is owned.
  The streak counts days solved on the day, and a missed day of the last week can be kept with a video or
  a Streak keeper (20 INR, bought as often as wanted).
- **Play Games**: the Daily puzzle, Stars and Longest streak leaderboards, eleven achievements, and the
  save kept in the player's Google account. On only once the game's Play Games project exists.

Plumb is designed in its warm paper light; its dark theme is the same room at dusk, with walls lighter
than the floor so walls, floor and pits still read as three heights.

## 5. Monetization

Built (kit/monetize/, shared by all three games). The rule is that nothing irritates: no ad during play,
over the board or before a new player has settled in, and the game never waits on one. Everything is in
the Android build only; the web build and desktop runs have no ads and no pack, and every call there
answers "not available" at once. The numbers are constants in `kit/monetize/pacing.gd` (`AdPacing`),
tested on their edges in `tests/run_tests.gd`.

- **While AdMob is off** (`GameMonetize.ADMOB` false, since 2026-10-18, until the AdMob account is
  approved): the studio's house ads stand in. The banner shows the studio's other games in the same
  places, there are no interstitials, and every video offer becomes "Try a quick game", a tiny playable
  board of another game that closes any time and gives the reward anyway. Everything below still holds.
- **Banner**: one anchored adaptive AdMob banner at the foot of the Levels screen and of the play screen,
  never over the board and never on a guided level. It appears once 3 levels are solved and steps aside
  while any sheet or the ending is open. The pager lifts clear of it with a 32 px gap, and the play
  screen's bottom row and caption with a 48 px gap, holding that room from the first frame so the board
  never moves when the ad loads (AdMob's accidental-click rules).
- **Between levels**: an interstitial only when a solved level is left with Next level, and only once 12
  levels are solved in all, 4 levels have been solved this session since the last one, 4 minutes have
  passed since any full-screen ad and 3 since the app started. Never after level 1's guide, on the ending,
  after a failure or mid-level. If none is loaded, Next simply goes on.
- **Reviews and updates**: Google Play's own review card, with nothing of ours before it, at a few
  milestones on Next level (it takes the interstitial's place) and as the ending closes. Play decides
  whether it shows. About and the ending keep a Rate button that opens the Play page. A new version
  downloads in the background once Play has asked, and the title or the level grid offers to restart into
  it, never mid-level. Both through `addons/play_core/` and `kit/shell/play_core.gd`.
- **Hints**: free and unlimited on the first 15 levels. After that, 3 free a day (by the phone's calendar,
  back at local midnight), shown as a badge on the hint button; then the button shows a play mark and asks
  "Watch a short video for a hint?" (Watch, Not now). If no video can play (offline, no fill, consent
  refused) the hint comes anyway with a short note. A hint the board cannot give (a marble down a pit, no
  way home) costs nothing.
- **Consent**: Google's UMP message runs at launch before the Mobile Ads SDK starts, and Settings offers
  Privacy choices where it says they are required. Requests are rated PG at most and are not tagged
  child-directed (the audience is 13+). Debug builds always use Google's test units.
- **The Supporter pack**: one non-consumable Play Billing product, `supporter`, priced by the owner in Play
  Console. It turns off the banner and the ads between levels and makes every hint free; it is also the
  thank-you (the ending and About thank Supporters). Purchases are acknowledged, restored at every launch
  and from Restore purchase, and kept in the save so the pack holds offline. A Supporter's app never loads
  an ad or shows the consent message.
- **Sponsoring**: GitHub Sponsors, in the web build only (Settings, the ending). Google Play's Payments
  policy forbids pointing players to a way to pay outside its billing, so the Android build never links to
  it, and its About links only to the site's Privacy and Support pages, which carry no sponsor links.

The ids live in `monetize.gd` (`GameMonetize`): the AdMob app id, the banner, interstitial and rewarded
units, and the product id. They are the real AdMob ids; debug builds load Google's test units instead. The
project setting `admob/general/android/app_id` must stay equal to the app id, and a test checks it. Still
the owner's to do: the `supporter` product in Play Console with license testers, and linking the AdMob app
to the Play listing once it is live.

## 6. Project architecture

```
autoload/    event_bus, save (progress on both sets, settings, the Supporter pack, today's hints), pack (the
             main path and the Hard levels), audio, screens (fades)
scripts/     hard_shelf.gd (moves a save from before the Hard levels on), stars, palette
scripts/tilt board.gd (rules), tilt_move.gd, solver.gd (BFS), difficulty.gd (bits of luck),
             novelty.gd (replays), generator.gd (phases, the ramp and the plateau), showcase.gd (the
             opening), naive.gd (a random and a greedy player, for the tests)
scripts/kit  palette, ui (code-built theme), stars (scoring), star_icon
scripts/feel cast.gd (the characters), mood.gd (what a face shows), gaze.gd (where eyes look), spin.gd (the
             roll and the light on a ball), litter.gd (the wall animals' families and coats)
scenes/game  game.gd (play screen), board_view.gd, marble, face, loaf (wall animals), memorial and its
             grey.gdshader, sparkle, ripple, hint_arrow
scenes/shell title.gd, seesaw.gd, levels.gd
levels/      levels.json (the main path) and hard.json (the Hard levels), written by
             tools/generate_levels.gd, never hand-edited
kit/         the shared UI kit: ui/, shell/ (levels, settings, about, credits, finale), tools/ (capture,
             store, film), monetize/ (pacing, ads, supporter, hint gate; android/ holds the AdMob and
             Play Billing backends, loaded on Android only)
addons/      the AdMob plugin (Poing Studios 5.1.0, with its Android binaries) and GodotGooglePlayBilling
             3.1.0, both used by the Android build only
monetize.gd  the ad unit and product ids; credits.gd the About, Credits and ending words; brand.gd the look
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
  own toggle are done. Then the marbles came alive (November 2026): character faces driven by the board and
  the memorial behind a Faces setting (on by default), sleeping animals for walls behind a Pets setting (off by
  default), and for everyone, faces or not,
  shading that makes every set read as a ball, a pattern that turns as it rolls, a rolling sound that
  follows the board's speed, soft knocks and clinks, a glass plop with every bell, the last marble slowing
  into its hole as the bells resolve into a chord, stars on the chord's notes, sparkles and soft vibration
  ticks (`MATH.md` sections 17 to 21). Still to do: a tray light that follows the tilt.
- **M3 - Content**: 500 levels in 25 chapters, one new rule each (`CHAPTERS.md`), shipped in waves. 1.1,
  chapters 1 to 10 with stop pads, one-way gates, plugs, colour gates, paint and cracked floor: built.
  1.2 to 1.4, chapters 11 to 25: designed. Daily puzzles from a date seed may follow.
- **M4 - Monetization**: the Levels banner, paced interstitials on Next level, rewarded hints past the
  free ones, UMP consent, and the Supporter pack through Play Billing. Built and tested headless (unit
  tests and the smoke robot against a stand-in ad network); a CI dry run proves the Android build carries
  both plugins. Still to do: real AdMob ids, the Play product, and a check on a real phone with test ads.
- **M5 - Store prep and ship**: Android preset and AAB are done; the closed test with 12 testers for 14
  days, and the Play Console's ads and data safety answers for AdMob and billing, remain.

## 8. What would kill this

- Levels that feel random rather than designed. Watch the retention curve for where players stop;
  if it is inside one phase, that stretch of the ramp is too steep.
- Levels with an obvious "just keep swiping" solution. The bits score is exactly how often random
  swiping finds par, so if playtests show it, raise the ramp's floor rather than guess.
