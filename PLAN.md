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
  play, Support the game, About, Credits, Privacy choices (only where the consent message requires them),
  and a guarded reset.
- **The guide** on level 1, once, and again from How to play: the goal and the help buttons on two
  cards, then the swipe itself, drawn by a ghost finger in the direction the solver would tilt next.
  Skip ends it at any point.
- **The ending**, after the last level is solved for the first time: a note from Shravan, signed, and a
  support line under it: the Supporter pack in the Android build, GitHub Sponsors on the web, and a
  thank-you for a Supporter.

Plumb is designed in its warm paper light; its dark theme is the same room at dusk, with walls lighter
than the floor so walls, floor and pits still read as three heights.

## 5. Monetization

Built (kit/monetize/, shared by all three games). The rule is that nothing irritates: no ad during play,
over the board or before a new player has settled in, and the game never waits on one. Everything is in
the Android build only; the web build and desktop runs have no ads and no pack, and every call there
answers "not available" at once. The numbers are constants in `kit/monetize/pacing.gd` (`AdPacing`),
tested on their edges in `tests/run_tests.gd`.

- **Banner**: one anchored adaptive AdMob banner at the foot of the Levels screen, and nowhere else. It
  appears once 3 levels are solved, steps aside while any sheet is open, and the pager lifts clear of it
  with a 32 px gap (at least 24, for AdMob's accidental-click rules).
- **Between levels**: an interstitial only when a solved level is left with Next level, and only once 12
  levels are solved in all, 4 levels have been solved this session since the last one, 4 minutes have
  passed since any full-screen ad and 3 since the app started. Never after level 1's guide, on the ending,
  after a failure or mid-level. If none is loaded, Next simply goes on.
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
units, and the product id. They are Google's test ids until the owner creates the real ones in AdMob; the
project setting `admob/general/android/app_id` must stay equal to the app id, and a test checks it. Still
the owner's to do: the AdMob app and units, the consent message in AdMob's Privacy and messaging, the
`supporter` product in Play Console with license testers, and app-ads.txt at the domain's root.

## 6. Project architecture

```
autoload/    event_bus, save (progress, settings, the Supporter pack, today's hints), pack (the level set),
             audio, screens (fades)
scripts/tilt board.gd (rules), tilt_move.gd, solver.gd (BFS), difficulty.gd (bits of luck),
             novelty.gd (replays), generator.gd (phases and the ramp)
scripts/kit  palette, ui (code-built theme), stars (scoring), star_icon
scenes/game  game.gd (play screen), board_view.gd, marble, ripple, hint_arrow
scenes/shell title.gd, seesaw.gd, levels.gd
levels/      levels.json, written by tools/generate_levels.gd, never hand-edited
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
  own toggle are done. Still to do: a tray light that follows the tilt.
- **M3 - Content**: new tile types generated the same way (one-way arrows, ice, sticky floor) past
  level 120, and daily puzzles from a date seed.
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
