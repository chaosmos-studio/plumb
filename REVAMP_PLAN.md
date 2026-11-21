# Plumb 2.0: the revamp plan

The build plan for Plumb's total revamp, direction B, Homecoming, approved by Shravan on 20 November 2026.
The decisions themselves are in the workspace's `docs/REVAMP.md`, and the studies behind them in `docs/UI_STUDY.md`, `docs/CASUAL_HITS_STUDY.md` and `docs/REFERENCE_GAMES.md`.
The concepts are `build/review/revamp2/` (round 2, the vivid colours) and `build/review/revamp/B-*.png` (round 1, the structure).
This file says how it gets built: the architecture, the data, the delivery format, the analytics, the motion, the sound, the art, the risks and the tests.
Work happens on the branch `sg/revamp`, in milestones M0 to M5, with a gate after each.

Status: **M0 approved by the lead on 20 November 2026, with the decisions in section 15. M1, the rolling-map spike, measured on the A142 the same day (`MATH.md` section 25) and waiting for the lead's review. Codex paints the street's art on bridge thread `plumb-art`.**

## 1. The game in one page

- **Two looks, one game.** The new look (called Street in code, never in the game) and today's look (Classic) share one save, one board engine, one set of services and one progress.
  A player picks a look on first launch from two live previews and can switch in Settings.
- **Street is Home.** The app opens on a street of houses that rolls toward the player like a turning world.
  Every level is a house with a round door, the next one lit.
  There is no title screen, no level grid, no chapters and no level count.
- **One tap per level.** Tap the lit door, the start card drops in, tap Play.
  A win needs no tap: the marbles go home, the windows light as stars, coins fly, the cast rolls to the next door, and the next card drops in.
- **A rhythm of rewards.** A parcel waits at every 5th door, and a new family moves into a new house at every 20th, behind a finish ribbon.
  Boosters are helpers that give information or comfort, never power.
  Coins come from play and buy hats, marble sets and decorations. The Supporter pack is the only thing sold for money in Street.
- **Adaptive and endless.** Each player has a rating, and the next board is picked from a pool to suit them.
  Difficulty never drops, and only the speed of the climb adapts. New boards arrive from Cloudflare without an app update, signed and checked, and the game works fully offline.
- **Classic stays as it is.** Today's title, level grid, chapters, Hard section, ending, shop and music keep working, on the same saved progress.

What does not change: the rules (`scripts/tilt/`), the solver and its par, the bits measure, the board view and its feel (`scenes/game/board_view.gd`), the faces, moods and memorial, the daily puzzle (the same board for everyone), the hint gate, the ads' pacing, consent, billing and Play Games.

## 2. Architecture

### 2.1 The split

The workspace rule for every revamp: the kit keeps only services, and each game builds its own screens from its own pieces.
Plumb is on kit v2, a copy in `kit/`.
New services are written as Plumb files first, with no Plumb names inside, and move into the skill's kit once 2.0 has shipped and proved them.
Edits to Plumb's copy of the kit stay small and are listed in 2.3, so they can be ported back.

**Services, shared by both looks:**

| Service | Where | What changes |
| --- | --- | --- |
| Saving and the cloud save | `autoload/save.gd`, `kit/play_games/cloud_save.gd` | Progress by board id (save layout 3), the street, the rating, coins, boosters, the look choice, new merge rules |
| Ads and their pacing, consent | `kit/monetize/ads.gd`, `pacing.gd`, `android/consent.gd` | `Ads.solved()` counts solves by id. Street calls the interstitial from the start card's Play (decision 7) |
| Billing, Supporter, restore | `kit/monetize/supporter.gd`, `shop.gd`, `android/play_billing.gd` | None in billing. Street's shop presents only the Supporter pack for money |
| The hint gate | `kit/monetize/hint_gate.gd` | None. Street passes its door number for the free-first-15 rule |
| The daily's logic | `kit/daily/daily.gd` | None. The board stays the same for everyone |
| Play Games | `kit/play_games/` | Achievements count solves, as now |
| Analytics | `kit/monetize/analytics.gd` | User properties, board id, difficulty and rating on level events, new events (section 5) |
| Updates and reviews | `kit/shell/play_core.gd`, `addons/play_core/PlayCore.java` | A check on every launch, no stale wait, flexible or immediate, state for the update card (section 7) |
| Sharing | `kit/shell/snapshot.gd`, `share_card.gd`, `kit/ui/qr.gd` | None |
| Safe areas, screen lock, transitions | `kit/ui/ui.gd`, `screen_lock.gd`, `autoload/screens.gd` | None |
| Audio | `autoload/audio.gd` | Buses, Street's layered score, ducking (section 9) |

**New services, Plumb's own for now:**

| Service | Where | Job |
| --- | --- | --- |
| `Pool` (autoload) | `autoload/pool.gd`, `scripts/street/board_meta.gd` | Every board by id: the main path, Hard, the bundled extras and the boards from the feed, with each board's difficulty, par, size, marbles and tiles |
| `Street` (autoload) | `autoload/street.gd` over pure scripts in `scripts/street/` | The player's street, the picker, the rating, rewards, coins and boosters |
| `Feed` (autoload) | `autoload/feed.gd` over `scripts/street/feed_check.gd` | Fetches, verifies, stores and merges new boards (section 6) |
| `AnalyticsUser` | `addons/analytics_user/AnalyticsUser.java`, built in like `PlayCore.java` | Firebase user properties, which the vendored Firebase plugin cannot set (it exposes only `initialize`, `log_event`, `set_consent` and collection on or off) |

`Pack` stays as Classic's view of the two fixed paths (the main path and Hard), now able to name each level's board id.

**Screens Plumb builds for Street** (section 3), all in `scenes/street/`: the map, the start card, the play screen's frame, the win sequence, the parcel, the milestone, the shop, Settings, the look chooser and the update card.

**Classic's screens stay the kit's and Plumb's own as they are today:** `scenes/shell/title`, `kit/shell/levels`, `scenes/game/game`, `kit/shell/result`, `kit/shell/settings`, `kit/monetize/shop`, `kit/shell/finale`, `kit/daily/daily_screen`.
They change only where the services under them change, plus one Look row in Classic's Settings and the update card in Classic's style.

### 2.2 Autoload order

`EventBus`, `Pool`, `Save`, `Pack`, `Street`, `Feed`, `Audio`, `Screens`.
`Pool` comes before `Save` because the save migration needs each main level's difficulty (section 4.6).
`Save._ready` keeps starting the kit's services in their order (`Supporter`, `Ads`, `Analytics`, `PlayCore`, `PlayGames`).
`tools/configure_project.gd` writes the order, and a test checks it.

### 2.3 Edits to Plumb's copy of the kit

Kept short so they port back to the skill's kit:

- `analytics.gd`: `user_property(name, value)` through `AnalyticsUser`, sent only while counting, and `board`, `path`, `look` added to the text parameters in `for_ga()`.
- `play_core.gd` and `PlayCore.java`: `checkUpdate` without the stale wait, the update's version code, priority, size and download progress, `startUpdate(immediate)`, and state for the card. `QUIET_SCENES` gains Street's map.
- `ads.gd`: `solved()` reads a count from `Save` instead of walking `Pack` by index, and `solved_here()` keeps the walk for `finale.gd` and `solved_all`.
- `cloud_save.gd`: `rules()` adds the game's own join rules (`Save.cloud_rules`), and an unknown rule goes to `Save.cloud_join`.
- `analytics.gd`: also `level_context`, `solve_measures` and `in_level()` for the level events, the rounded measures, and the new text parameters.
- `hint_gate.gd`, `daily.gd`, `play_billing.gd`: the board on `hint`, `daily_start` and `daily_end`, and `shop_buy` for money.
- `unlocks.gd`, `levels.gd`, `cheers.gd`, `share_card.gd`, `finale.gd`: unchanged in logic, since they reach progress through `Save.best(level)`, which now maps Classic's index to a board id.
- `settings.gd`: one Look row, through `game_options.gd` as today's Faces and Pets rows are added.

### 2.4 Patterns chosen

Per the workspace's GodotPrompter rule, each system names its pattern, the alternative weighed and the reason.

| System | Pattern | Alternative | Reason |
| --- | --- | --- | --- |
| Rolling map (2d-essentials, camera-system) | 2D: one pure projection function in `scripts/street/projection.gd`, a ground `MeshInstance2D` bent by a `canvas_item` vertex shader using the same formula, props as ordinary 2D nodes placed by the function each frame. No `Camera2D`: the scroll is the projection's `c` | A `Camera2D` over a flat painted strip with `Parallax2D` layers, or a 3D globe | It is what Shravan imagined and what Candy Crush's own map does, it reuses the 2D cast and board as they are, and the flat look is the same code with a very large radius (Reduce motion). The globe hides most levels and makes "forward" unclear |
| Draw order on the map (2d-essentials) | `y_sort_enabled` on the props layer, every prop's origin at its base | `z_index` set per frame from depth | A prop's projected base moves up the screen as it moves away, so screen y already orders depth and the engine sorts for free |
| Ground and sky (shader-basics) | One ground shader drawing grass, the road band, cobbles and edges from the strip coordinates, the road's path an analytic function of `s` shared with GDScript, and one sky gradient shader | Painted ground tiles per neighbourhood | Re-themeable by uniforms, no texture memory, and the road and the doors cannot drift apart because both read the same path function |
| Map text (godot-ui, responsive-ui) | Baloo 2 with multichannel signed distance field rendering for door numbers, drawn with the prop's scale | `Label` nodes, or `draw_string` at many sizes | Numbers scale with depth every frame. MSDF stays sharp at every scale without rasterising a glyph per size |
| App flow (state-machine) | An enum state machine in `scripts/street/flow.gd` (map, card, play, win, walk, gift, milestone), pure and tested, driven by the scenes | Node-based states | Seven states in one straight line with a few branches. Enter and exit work lives in the scenes, and the order is testable headless |
| Win sequence and other moments (tween-animation) | A list of awaited beats, each a `Tween`, with a hurry flag a tap sets, as `game.gd` already does for the party | `AnimationPlayer` timelines | Every beat depends on the board (stars, marbles, coins), the whole thing must skip cleanly, and the code is the lesson Shravan reads and tunes |
| Confetti, sparkles, coins (particles-vfx) | The existing `Flourish` bursts and sparkles, drawn in code, plus code-drawn coin and star flights | `GPUParticles2D` | Already shipped in 1.5.0, no material to warm on first use (The Dog Did It's first-use hitches came from cold materials), deterministic for screenshots |
| Events across the app (event-bus) | New typed signals on `EventBus`: `door_solved`, `coins_changed`, `booster_changed`, `look_changed`, `feed_updated`, `update_state` | Direct calls between scenes | The map, the coin pill, analytics and audio all react to the same few events without knowing each other |
| Saving (save-load) | `ConfigFile` as now, with a layout number, a pure migration function for each step, a backup before migrating | JSON or a `Resource` save | The file stays readable, an old or corrupt file degrades to defaults, the cloud save already joins `ConfigFile` keys, and a `Resource` save would run code on load |
| UI building (godot-ui, responsive-ui) | Code-built Controls with one Street `Theme` resource (fonts, styleboxes, a scale for Larger text), anchors and containers, safe-area margins from the kit | Hand-placed scenes | Matches how the kit and Plumb build UI today, one theme carries Larger text, and the stretch settings stay `canvas_items` with `expand` at 720x1280 |
| Music (audio-system) | `AudioStreamInteractive` switching map and level on the next bar, each an `AudioStreamSynchronized` of three stems, cues on their own player, Music and SFX buses with ducking | Two players crossfading | Bar-synced switches keep the music musical going in and out of a level, and stems let the music grow as the board empties |
| Picker and pool (procedural-generation) | A seeded, deterministic picker over a pre-scored pool, seeded by the player id and door number, with a fixed fallback order | Generating boards on the phone | The generator needs minutes to hours per board set (`MATH.md` section 16), and a pre-scored pool makes the picker fast and testable |

## 3. Screens and scenes

### 3.1 Scene list

| Scene | File | What it is |
| --- | --- | --- |
| Boot | `scenes/boot/boot.tscn` (the new main scene) | Reads the save and opens the chooser, Street's map or Classic's title. The studio beat plays over whichever comes first |
| Look chooser | `scenes/street/chooser.tscn` | Two live previews, almost no words (3.3) |
| Map (Home) | `scenes/street/map.tscn` | The rolling street, the cast, the coin pill, three round buttons (daily, shop, settings), a pin back to the current door, and the banner at its foot |
| Start card | `scenes/street/door_card.gd`, an overlay on the map | The door number on a ribbon, the board's marbles over their holes, par as footprints, three booster slots, Play. A tile's first board shows the tile large with its one line |
| Play | `scenes/street/play.tscn` | The board (the shared `BoardView` and a shared play core, 3.4), a hanging street sign with the door number, a moves pill (`3/8`), a row of faces that turn happy as each marble gets home, round Undo, Restart and Hint buttons |
| Win | `scenes/street/win.gd`, played over Play, then the map | The homecoming (section 8, moment 14) |
| Parcel | `scenes/street/gift.gd`, an overlay on the map | Every 5th door |
| Milestone | `scenes/street/milestone.gd`, an overlay on the map | Every 20th door, a new family's house |
| Shop | `scenes/street/shop.tscn` | The market stall with soft trays (concept `6-shop.png`) |
| Settings | `scenes/street/settings.tscn` | General and Accessibility (concept `7-settings.png`), with Help and account one level down |
| Update card | `scenes/street/update_card.gd` | The game's own card for a new version (section 7) |
| Daily | the kit's `kit/daily/daily.tscn` for 2.0 | Reached from the calendar button. A Street-styled daily is a later step (open question 10) |
| Hard | `scenes/street/map.tscn`, a side road | A hill road off the first milestone, holding the Hard levels in their fixed order (decision 6) |

About, Credits, How to play, Restore purchases, Support, Privacy choices and the guarded reset live under Settings > General > Help, built in Street's theme from the kit's sheets.

### 3.2 The flow

```
boot -> chooser (first launch only) -> map
map: tap lit door -> card -> Play -> play screen
play: win -> win sequence -> map: walk to the next door -> parcel or milestone if due -> next card
play: back -> map (a quit if moves were made)
map: tap a solved door -> card (a replay, which can raise its stars and never changes the rating)
map: tap a locked door -> the door wiggles, nothing opens
```

Street's flow state lives in `scripts/street/flow.gd`, so the order of moments is tested without scenes.

### 3.3 The look chooser

- Shown once, on the first launch of 2.0, to new players and to players updating, with no default (decision 3).
- Two cards side by side, each a live `SubViewport` running a small slice of its look: Street's map rolling slowly with the cast, Classic's seesaw title.
- The only words are none, or at most a tick on the chosen card. A tap picks: the chosen card grows to fill the screen and becomes the game, the other slides away.
- Saved as `Save.app_look` (`"street"` or `"classic"`), sent as the user property `app_look` and the event `look_choose`.
  The name is `app_look` because `Save.look` already means the marble set.
- Settings in both looks has a Look row with the same two pictures. Switching keeps all progress (4.5).

### 3.4 The play core

Today `scenes/game/game.gd` holds both the play logic (board, history, route, undo, restart, hint, the walk back from a dead end, the win and loss checks) and Classic's presentation.
The logic moves into `scenes/game/play_core.gd`, a node both play screens own, which emits `won`, `lost`, `moved` and `hinted`.
Classic's `game.gd` keeps its HUD, sheets and party and behaves exactly as now. Street's `play.gd` builds its own frame around the same core.
The split is the one refactor that touches Classic, and the existing smoke robot and tests must pass unchanged before and after it.

## 4. The data model

### 4.1 Board ids

Every board has a stable id, and progress is saved by id.

| Set | Ids | Source |
| --- | --- | --- |
| Main path | `main-0001` to `main-0520` | `levels/levels.json`, by position. Its digests are pinned by the tests and never change, so position is a stable id |
| Hard | `hard-0001` to `hard-0320` | `levels/hard.json`, by position (old index 180 is `hard-0001`) |
| Bundled extras | `x-0001` and on | `levels/pool.json`, new, made by the generator in M4 |
| Feed episodes | `ep0001-01` to `ep0001-20`, and on | Downloaded episodes (section 6) |
| Recycled | `<id>~<s><p>`, such as `main-0310~52` | A pool board turned by symmetry `s` (1 to 7) with its colours permuted by `p`, only when the pool is dry (4.3) |
| Daily | `daily-2026-11-20` | The daily bank, for analytics only |

A board can be retuned in place: a feed board with an existing id and a higher `rev` replaces it, and the player keeps the stars earned on that id.

Each board's metadata, computed once by a tool and never on the phone (`levels/meta.json` for the bundled sets, inside each episode for the feed): `d` (difficulty in bits, `MATH.md` section 5, the turning lock scaled as in section 16), `par`, `w`, `h`, `marble_count`, `colours`, `set` (the tiles it contains), `need` (the tile it was made to need), `positions` (the tie-break), `feel` (roomy or tight, from marbles per cell).
A test recomputes `meta.json` for a sample on every run and all of it in the slow pass.

### 4.2 The pool

`Pool` merges, by id: the main path, Hard, the bundled extras, then verified feed boards (a feed board replaces a bundled one only with a higher `rev`), minus retired ids.
A retired board leaves future picks only. A board already on a player's street stays playable, and the feed client never deletes an episode file that holds one (6.3).

The bundled pool must cover the climb densely enough for slow climbers, who need more boards at each difficulty than the main path has.
M4 adds a coverage report (boards per tile set and per quarter bit) and generates extras where a bucket is thin, roughly two to three per main level along the ramp, about 500 boards and 250 KB.

### 4.3 The picker

Pure, in `scripts/street/picker.gd`, seeded by the player id and the door number, so a door's board is reproducible in tests and never changes once picked (it is saved on the street).

**The climb position.** Each player has a climb position `p`, measured in levels of the main path, which acts as the curriculum: the tiles taught by `p` are the main path's chapters up to `p`, and the reference difficulty at `p` is the main path's difficulty there, made non-decreasing.
After a solve, `p` moves on by the pace `m`, between `PACE_MIN` (0.6) and `PACE_MAX` (2.5) levels a door.
A pace of 1 is today's main path. A fast player skips boards and meets the next tile sooner, a slow player meets more boards at each step.
`p` never goes back. Past the end of the main path the curriculum continues with remix episodes (two or three known tiles at once), and the target holds at the ceiling.

**The pace** comes from the rating gap, `m = 2^((μ - R(d_ref) - g0) / W)` clamped, where `R(d)` is a board's rating, `g0` the gap at which the player is expected to do as well as the target success `E*` (0.75), and `W` (200) the gap that doubles the pace.

**Never drops** (Shravan's rule, kept strictly in Street, decision 1). Street has no chapters, so it has no chapter-start dips.
The target for the next door is never below the last door's, a candidate's `d` is never below the last door's, and par never falls. There is no allowance.
The target climbs until it reaches the comfort ceiling, today's plateau band (par 12 to 13, 18.85 to 20.35 bits), and then holds flat at the band's top: it rises no further, and no board falls below the band's floor.
Classic keeps its current behaviour.

**Choosing.** Candidates: unplayed by this player, not retired, rules this client knows, tiles taught, `d` and par at or above the floor, the ceiling's board size limits, not the same layout bucket as the last few doors.
Each is costed by its distance from the target, whether it needs the newest tile while that tile is in its first run of doors, and whether its feel repeats the last door's (roomy and tight alternate, as `CASUAL_HITS_STUDY.md` suggests).
The cheapest wins, ties broken by the seeded generator.

**Fixed opening.** Doors 1 to 5 are always `main-0001` to `main-0005`, the opening picked to be remembered (`MATH.md` section 12).

**Fallbacks**, in order (as built in M4, see "M4 as built"): drop the feel and layout preferences, drop the tile-need preference, widen the window upward, then recycle: the least recently played board at or above the floor, turned by one of the eight symmetries with its colours permuted (`TiltNovelty.transform` already does the turning), so the game never runs out offline.
Each pick records which step chose it, for analytics (`pick` parameter).

**Tiles.** A tile's first board opens with the start card's teaching variant (the tile drawn large, its one line from `CHAPTERS.md`). No chapter card, no chapter count.

### 4.4 The rating

Glicko-1 per board attempt, in `scripts/street/rating.gd`, with the lesson in `MATH.md`.

- **A board's rating** is `R(d) = 1000 + 50 d` with a fixed deviation, so level 1 is about 1050 and level 160 about 1943. Real-play re-scores (6.4) change `d` and lower the deviation.
- **A player** starts at μ 1100 with deviation φ 350, so the first doors move the estimate quickly. φ shrinks with play and grows slowly over long absences.
- **The outcome** is a number from 0 to 1, not a plain win: a solve at par with no hint, booster or restart, at about the board's expected time, scores 1, and moves over par, hints, boosters, restarts and much longer times take it down to no less than 0.1.
  A quit after at least 3 moves or 30 seconds scores 0. Leaving at once costs nothing.
- **Replays** of past doors do not change the rating. Classic play does, so a player who switches looks arrives well estimated.
- **Glicko over Elo:** the deviation lets a new player's estimate settle in a handful of doors and an old one's stay steady. TrueSkill's team model is more than one player against one board needs.
- **Tested** against Glickman's worked example (1500 and 200 against three opponents comes to 1464 and 151.4) and on simulated players of known skill: the pace must track skill, never go below `PACE_MIN`, and never pick an easier board.

`rating_band` for analytics is μ rounded down to 100, as text.

### 4.5 Progress by id and the look switch

**The street** is the list of board ids on the player's doors, door 1 first, with each door's `d` at the time it was played (for the floor), plus `p`, the rating and the door counts that trigger rewards.

**Stars** are `best[id]`, one map for every board in either look, so a board solved in one look shows solved in the other.

**Classic** keeps its fixed paths by index, reading stars through `Pack.id_of(level)`.

**Switching looks:**

- **Classic to Street:** every main board solved in Classic past the street's highest main board is added to the street in order, and `p` rises to at least that board's position.
  So a Classic player at level 127 who switches sees doors 1 to 127 and continues at 128.
- **Street to Classic:** every main level up to the street's highest main board is opened in Classic (`opened`), so nothing they reached is locked. Classic's Play goes to its own first unsolved main level, as now.
- Both are pure functions with tests (`Street.absorb_classic`, `Street.open_in_classic`).

### 4.6 Save layout 3 and the migration

Still `user://plumb.cfg`, still a `ConfigFile`. New and changed keys:

| Section | Keys |
| --- | --- |
| `progress` | `layout` 3, `best` (id to stars), `opened_ids`, `tutorial_seen` |
| `street` | `doors` (ids), `door_d` (difficulty when played), `p`, `floor`, `mu`, `phi`, `rated_at`, `coins`, `boosters` (id to count), `booster_open` (ids), `gifts` (doors claimed), `homes` (milestones seen), `owned` (cosmetics), `worn` (a hat per cast member) |
| `player` | `id` (16 random hex characters, made on first launch, never personal), `since` |
| `settings` | `app_look`, `look_chosen`, `reduce_motion`, `colour_help`, `larger_text`, plus today's keys |
| `feed` | `serial`, `checked_at` |

**Migrating from layout 2** (`scripts/street/migrate.gd`, pure, run by `Save.upgrade` after `HardShelf`'s step, which still brings a layout 1 file to layout 2 first):

1. Copy the file to `user://plumb.layout2.cfg` once, before anything changes.
2. Stars: `stars[i] > 0` becomes `best["main-%04d" % (i + 1)]`. `hard[i] > 0` for `i >= 180` becomes `best["hard-%04d" % (i - 179)]`.
3. `opened` and `hard_opened` become ids in `opened_ids`. Unused level keys stay as they are.
4. The street: doors 1 to K are `main-0001` to `main-K`, where K is the furthest main level solved or opened. Gaps a player skipped with a key or the chapter gate stay as open, unlit doors to come back to. `p` is K and the floor is the hardest of those boards solved.
5. The rating starts from where they are: μ at the rating of board K plus 50, φ 200.
6. A welcome purse for players who were already playing, 5 coins a star (open question 16).
7. Owners of the marble pack or the complete pack own every marble set in Street's shop.
8. `layout` becomes 3. Running the migration again changes nothing.

The old keys are left in the file for one version, ignored, so a sideloaded older build still reads its own progress.

**The cloud save** joins by the same rule as today, both copies brought to layout 3 first: `best` keeps the higher stars per id, `opened_ids` and `owned` are unions, `doors` and the rating come from the copy with more solved doors, coins and boosters take the larger value per key (the generous side).

### 4.7 Rewards, coins and boosters

All numbers are constants at the top of `scripts/street/rewards.gd`, for Shravan to tune.

| When | What |
| --- | --- |
| Every win | 10 coins, 5 more per star, 5 more for a clean solve (no undo, restart or hint) |
| Par with no hint and no restart | A golden knocker on that door's house, which stays (the mark of mastery, never a penalty) |
| Door 5 | The first parcel: Footprints unlocked, 3 free |
| Door 10 | Parcel: Ghost marbles unlocked, 3 free |
| Door 15 | Parcel: Spare step unlocked, 3 free |
| Every 5th door after | A parcel: 60 coins and one booster or a hat, with a "double it" offer by video that doubles anyway when no video is ready |
| Every 20th door | A milestone: a new family moves into a new house, the finish ribbon breaks, 200 coins and 3 boosters |
| The daily solved | 30 coins |

**Boosters** (helpers, never power, given away freely, also 30 coins each in the shop):

- **Footprints:** the solver's first two tilts drawn faintly on the board as it opens, fading as each is taken.
- **Ghost marbles:** for one move, while the finger drags, faint copies of every marble show where that tilt would leave them. Letting go short of a swipe cancels.
- **Spare step:** one more move of leeway for three stars on this board. It never counts toward the golden knocker.

A board played with a booster or a hint scores a lower outcome for the rating (4.4), so help never pushes a player into harder boards.
The start card shows all three slots from door 1, locked ones with the door number they open at, so the next gift is always in view.

**The shop** sells hats (20), marble sets (40, the existing finishes from `looks.gd`), street decorations (60) and boosters (30) for coins, on soft trays with one quiet price pill each, and the Supporter pack for money in one row below.
No timers, no fake discounts, no offers between levels. Classic's shop stays as it is (decision 5).

## 5. Analytics

Firebase Analytics into GA4 property 558339480, under today's rules: counting only where Google's consent service says no consent is needed, never in debug builds, never for ads.
Level and other grouping parameters are sent as text, counts and measures as numbers (`game-analytics` skill).

### 5.1 User properties

Set through `AnalyticsUser.java` only while counting. GA4 allows 25 user-scoped dimensions, names of 24 characters and values of 36.

| Property | Values | Set when |
| --- | --- | --- |
| `app_look` | `street`, `classic` | On choosing and on each launch |
| `player_id` | 16 random hex characters | First launch, then each launch |
| `rating_band` | `1100`, `1200` and so on | After each rated attempt, when the band changes |
| `furthest_level` | the furthest door solved in Street, or the furthest main level in Classic, as text | After each first solve |
| `feed_serial` | the feed's serial, as text | After a feed update |

### 5.2 Events

New parameters on level events: `board` (id, text), `path` (`street`, `main`, `hard`, text), `difficulty` (bits, number), `rating` (μ, number), `pick` (which picker step chose it, text, Street only).

| Event | Parameters | Sent by |
| --- | --- | --- |
| `level_start` | `level`, `board`, `path`, `difficulty`, `rating`, `replay` | Both looks |
| `level_end` | as today (`level`, `success`, `stars`, `seconds`) plus `board`, `path`, `difficulty`, `rating`, `moves`, `par`, `hints`, `undos`, `restarts`, `boosters`, `coins` | Both looks, on a solve |
| `level_quit` | `level`, `board`, `path`, `difficulty`, `seconds`, `moves`, `hints`, `undos` | Both looks, leaving unsolved after a move or 30 s |
| `hint` | as today plus `board` | Both |
| `booster_use` | `booster`, `level`, `board` | Street |
| `booster_gain` | `booster`, `how` (`parcel`, `milestone`, `shop`), `count` | Street |
| `gift_open` | `gift` (`parcel`, `milestone`), `level`, `coins`, `doubled` | Street |
| `milestone` | `level`, `family` | Street |
| `shop_open`, `shop_offer` | as today | Both |
| `shop_buy` | `item`, `price`, `paid_with` (`coins`, `money`; GA4 reserves `currency`) | Both |
| `look_choose` | `look`, `how` (`first`, `settings`), `from` | Both |
| `setting` | `setting` (`reduce_motion`, `colour_help`, `larger_text`, `haptics`, `music`, `sounds`), `value` | Both |
| `update_card` | `update` (`shown`, `start`, `later`, `downloaded`, `restart`, `installed`), `version`, `mode` (`flexible`, `immediate`) | Both, replacing `update_offer` |
| `feed_sync` | `feed` (`ok`, `same`, `offline`, `bad_signature`, `bad_hash`, `bad_board`, `error`), `serial`, `added` | Both, at most once a launch |
| `daily_start`, `daily_end`, `streak_kept`, `share`, `screen_view`, `house_ad`, `review_ask`, `solved_*` | as today, the daily's with `board` | Both |

`level` in Street is the door number, so a funnel by door is a funnel of progress, and `board` tells which board each player met there.

### 5.3 Custom definitions to register

Through the GA4 Admin API with the `studio-ops` key, before the first build that sends them. Registration is not retroactive.

- **User scope:** `app_look`, `player_id`, `rating_band`, `furthest_level`, `feed_serial`.
- **Event scope (text):** `board`, `path`, `pick`, `booster`, `how`, `gift`, `family`, `look`, `from`, `setting`, `value`, `update`, `mode`, `version`, `feed`, `paid_with`, `replay`, and `ad_trouble`'s `kind`, `format` and `network`.
- **Metrics (numbers):** `difficulty`, `rating`, `moves`, `par`, `hints`, `undos`, `restarts`, `boosters`, `coins`, `price`, `added`, `count`.
- **Registered 21 November** with `tools/ga4_definitions.py --apply`: the property now has 26 event-scoped dimensions, 5 user-scoped and 14 metrics.

That is 17 more event-scoped dimensions (23 of the property's 50) and 11 more metrics (13 of 50).

### 5.4 Data Studio and Studio HQ

- **Data Studio, Plumb's players page** (`game-analytics/references/data-studio.md`):
  - player rows keyed by `player_id` instead of the approximate key
  - players by furthest level (the chart the docs said needed `furthest_level`)
  - players and stickiness by look
  - rating bands
  - a Boards table (starts, wins, quits, seconds, hints per board id), which is also the input to re-scoring
  - boosters, gifts and the shop
  - the update card's funnel
  The Levels blend gets a `Path` filter, since door numbers and Classic's levels share numbers.
- **Studio HQ:** the Plumb entry in `studio/hq/hq.toml` names its look property, and HQ's players source shows players and minutes per look and the update card's funnel beside its Updates view.
  HQ is being redesigned by another agent, so this is agreed through `docs/NOW.md` before it is written.
- **The privacy page** on the studio site names every new event and the random player id (game-website skill), and Play Console's Data safety answers are checked against them.

## 6. Level delivery

### 6.1 Where

A public, read-only bucket in the Chaosmos Cloudflare account behind `https://levels.chaosmos.studio/plumb/v1/` (R2 with a custom domain, server side later).
The manifest is cached for 5 minutes, episode files forever, since their names carry their hash.

### 6.2 The format

`manifest.json`, signed byte for byte, with its signature in `manifest.json.sig` (ECDSA P-256 over SHA-256, base64 DER):

```json
{
  "format": 1,
  "game": "plumb",
  "serial": 12,
  "issued": "2026-12-01T00:00:00Z",
  "rules": 3,
  "app": {"latest": 20003, "line": "Snowy lane is open", "picture": {"file": "app/20003.png", "bytes": 48211, "sha256": "..."}, "urgent_below": 20000},
  "episodes": [
    {"id": "ep0001", "file": "episodes/ep0001-3f2a9c1e.json", "bytes": 10240, "sha256": "...", "rules": 1, "boards": 20, "d": [18.9, 20.1], "tiles": ["stop", "gate"]}
  ],
  "retired": ["main-0310"],
  "rescore": {"file": "rescore/0007-a1b2c3d4.json", "bytes": 3100, "sha256": "..."}
}
```

An episode file:

```json
{
  "format": 1,
  "id": "ep0001",
  "boards": [
    {"id": "ep0001-01", "rev": 1, "rows": ["#...0..", "..."], "marbles": [[1, 4, 0]], "tiles": [[2, 0, "stop", 0]],
     "par": 12, "d": 18.92, "positions": 1840, "w": 7, "h": 8, "marble_count": 5, "colours": 3, "set": ["stop", "gate"], "need": "gate", "feel": "tight"}
  ]
}
```

Boards use the same fields `TiltBoard.from_dict` reads today, plus the metadata of 4.1.
`rules` is the rules version a board needs: a client that knows fewer rules skips that episode, and the update card can say a newer version has new pieces.
The rescore file maps board ids to re-scored difficulty and its deviation (6.4).

Levels are data, not code. Google Play's policy limits code downloaded outside Play, not content such as levels (`CASUAL_HITS_STUDY.md`).

### 6.3 The client

`autoload/feed.gd` (the network) over `scripts/street/feed_check.gd` (pure: bytes in, a verdict out).

1. **When:** a few seconds after the first screen shows, at most once every 12 hours, never during a level, never blocking anything.
2. **Fetch:** `HTTPRequest` with threads, a 10 second timeout, a body limit of 512 KB per file, TLS verified, HTTPS only in release builds.
3. **Verify:** the signature over the exact manifest bytes against one of two embedded public keys (the current one and the next, for rotation), `format` known, `game` is `plumb`, `serial` not below the stored one (no rollback), each file's size and SHA-256 as the signed manifest says, each board's fields and ranges (board at most 10 by 10, at most 8 marbles, par at most 30, known tiles), and ids unique.
   Checked on this machine on 20 November: Godot 4.7's `Crypto.verify` accepts ECDSA P-256 and RSA signatures made by Python's `cryptography` and rejects a flipped byte.
4. **Store:** `user://feed/`, each file written to a `.part` and renamed, so a killed app never leaves half a file.
   Files no longer listed are deleted, except an episode holding a board on the player's street.
5. **Merge:** `Pool` reloads the verified boards, applies `retired` to future picks and the rescores to `d`.
6. **Defence in depth:** before a feed board is served, the solver checks its par on a worker thread with a search limit, and a board that disagrees is dropped and reported (`feed_sync` with `bad_board`).
7. **Offline:** nothing depends on the feed. The bundled pool and recycling (4.3) never run out.
8. **The web build** leaves the feed off.

The signing key is made once, kept in `studio/release-keys/` and the encrypted vault, never in a repo. The publishing tool (`tools/publish_levels.py`, M4) signs the manifest and writes the bucket's files for the server step later.
Until the server exists, the client is tested against fixtures signed with a test key, and the smoke robot fetches from a local HTTP server in a debug build.

### 6.4 Re-scoring from real play

`tools/rescore.py` (M4) reads per-board numbers from GA4 (starts, wins, quits, seconds, hints, moves over par) and fits each board's played difficulty on the bits scale.
With few players, a board's new value moves from the solver's by `n / (n + n0)`, where `n` is its plays and `n0` (20) the plays needed to trust them halfway.
The result ships in the feed's rescore file. The picker uses it for future picks only, and the floor keeps the value a door had when it was played.

## 7. The update card

- **Every launch** asks Play (through `PlayCore.java`) whether a newer version is available, with no stale wait.
- **The card** shows in the game's own look, on the map or Classic's title only, never in a level, once per available version per day:
  a picture (from the feed, checked by hash, or a bundled one), one line of what is new (from the signed manifest), Update and a quiet Later.
- **Flexible by default:** the download runs while the player plays, with a progress ring on the post box on the map, then a one-tap Restart card when it is ready.
- **Immediate** when the running version is below the manifest's `urgent_below`, or Play's in-app update priority is 4 or more (which the release workflow will learn to set).
- **A badge** stays on the post box (Street) or by the gear (Classic) until the update is installed.
- **Measured** by the `update_card` events, HQ's Updates view and Data Studio's version charts.
- Replaces today's `STALE_DAYS` (2) and `QUIET_DAYS` (7).

## 8. The animation bible

Every action, reward and transition is animated, at 60 frames a second on the A142.

**The rules for all of it:**

- Squash on landings and contacts, anticipation before jumps, overshoot on appearances (`TRANS_BACK`), follow-through on things that hang (a damped swing).
- A tap answers within 0.1 s. Things enter in 0.25 to 0.45 s. Celebration beats are 0.3 to 0.6 s each.
- Idle motion is slow (2 to 6 s periods) and small.
- A tap anywhere hurries any celebration beat. Nothing waits for a tap.
- Every tween that could overlap kills the one before it on the same property.
- **Reduce motion:** the map flattens (a very large radius, same code), no camera moves or zooms, swings become fades, confetti a quarter, no screen shake, no flashing. The win becomes a fade to the lit house and then to the map, about 2 s.
- The timings below are starting values, all constants at the top of each script, tuned on the phone.

| # | Moment | Motion | Time | Sound and touch |
| --- | --- | --- | --- | --- |
| 1 | Launch | The studio beat, then its marbles drop onto the street and become the cast at the current door. The lit door's glow pulses (scale 1 to 1.04, period 1.6 s) | beat + 0.6 s | The beat's sting, then the map music on the next bar |
| 2 | Idle on the map | Cast blink every 2 to 5 s, follow the finger with their eyes, nudge each other, one does something small every 8 s. Bunting sways, lamps flicker softly, leaves drift, clouds creep | continuous | None |
| 3 | Scroll | The world rolls under the finger 1 to 1, flings with friction, rubber-bands at door 1. Far props rise over the crest, near ones grow and sink below the bottom edge | per frame | A soft rolling hum that follows speed |
| 4 | Pin home | When the current door is off screen, a pin with the cast's face slides in at the bottom. A tap rolls back with ease in and out | 0.25 s in, 0.6 s roll | Tap |
| 5 | Locked door | The door wiggles and its padlock jiggles | 0.3 s | A knock |
| 6 | Lit door tapped | The door squashes (0.9 then 1.1), the card drops from the top on two strings with overshoot, then swings to rest. The ribbon with the number pops, the marbles hop in one by one, the slots pop, Play breathes | drop 0.45 s, swing 0.8 s, stagger 0.06 s | Whoosh, a bell per marble, a light tick |
| 7 | Booster slot | Chosen: the bubble fills and a tick springs on. Locked: it wiggles and shows its door number | 0.4 s | A pop, or a soft no |
| 8 | Play | The card shrinks into the door, the map zooms into the door, the board's tray rises from below, the marbles pop in (`BoardView.intro`), the street sign swings down | 0.3 + 0.45 + 0.35 s | Map music turns to the level music on the next bar |
| 9 | Tilt and roll | As today: the tray tips, marbles roll a cell every 0.052 s, squash on walls, knock and clink | as today | As today |
| 10 | A marble home | As today (plop, bell, sparkles, ripple) and its face in the top row turns happy with a pop. The level music adds a layer as the board empties | 0.2 s | Bell, plop, a 10 ms tick |
| 11 | Moves pill | The number pops on each move. Past par it fades from teal to amber, with no shake | 0.12 s, 0.3 s | None |
| 12 | Undo, restart | The board rewinds (as today), the undo glyph spins back, restart tips the tray and resets | 0.25 s | As today |
| 13 | Helpers | Footprints fade in at half strength and dissolve as taken. Ghost marbles follow the drag | 0.3 s | A soft shimmer |
| 14 | The win (nothing to press) | a. The last marble's slow drop and the chord (as today, 0.7 s). b. The tray slides away, and each marble rolls across to its own colour's house, its door closing behind it. c. The level's house lights a window per star, and from each a star flies up and slams into place on the chord's notes (E6, G6, C7). Three stars: the marbles pop back out in party hats and cheer, confetti. Par with no hint: the golden knocker glints. d. Coins arc from the house to the coin pill, which counts up. e. The scene zooms out into the map, where that house now has its windows lit. f. The cast rolls along the road to the next door while the world rolls to keep it in the lower third, and lands with a squash. g. A parcel or milestone if due. h. The next card drops in | about 5.5 s untouched, each beat skippable | The win cue resolving on the bell chord, star notes, coin ticks, a cheer. Haptic ticks on the stars |
| 15 | Parcel | The cast stops at the parcel, which bounces until tapped (or opens itself after 3 s). The lid flies off, light rays turn, the contents rise and fly to their counters. "Double it" waits below | about 3 s | Parcel cue, a pop, coin ticks |
| 16 | Milestone | The finish ribbon across the road breaks as the cast rolls through, its halves flying apart. Fireworks over the roofs, the new family's house rises on its plot with a spring, the family rolls out and waves, coins shower | about 6 s, skippable | The theme's big statement (about 8 s) |
| 17 | New tile | The tile grows from the card's centre with a ring pulse | 0.5 s | A bright chime |
| 18 | Booster unlocked | Its bubble flies to the card's slot, the padlock drops off and bounces | 0.6 s | A sparkle |
| 19 | Shop | The stall slides up, its awning drops and bounces, trays slide in one by one. Buying: the pill counts down and the item flies to the cast (a hat lands with a squash, a marble set swaps with a puff). Too few coins: the price pill wiggles | 0.4 s, stagger 0.06 s | Coin ticks, a cash-free "ding" |
| 20 | Settings | The notice board drops like the card. The tab pill slides. Toggles slide with overshoot, tick and cross swap with a pop. Turning on Reduce motion flattens the map behind, live | 0.25 to 0.45 s | Soft clicks |
| 21 | Look chooser | Both previews bob gently out of phase. The chosen one grows to fill the screen, the other slides away | 0.5 s | A chime |
| 22 | Update card | Drops like the card. While downloading, a ring fills round the post box. When ready, the badge pulses | 0.45 s | A soft bell |
| 23 | Coin pill | Counts up with ticks, limited to 20 a second | per change | Ticks |
| 24 | Round buttons | Press to 0.92, release overshoots to 1.06 and settles, the shadow shrinks while pressed | 0.06 s and 0.18 s | Tap, 10 ms tick |
| 25 | Back from play | The board shrinks back into its door and the map zooms out | 0.4 s | Level music back to map music on the next bar |
| 26 | Down a pit | As today: the marble worries, screams and falls, the memorial (about a second, shorter after three, a tap skips it). Undo brings it back out of the pit with a plaster on | as today | As today, and the soft pit cue |
| 27 | Hint | The bulb lights and the hint arrow shows the tilt (as today). After 60 s without a hint the round Hint button wiggles and a ring pulses from it, at most three times (the kit's `HintNudge`, as today) | as today | As today |

Shaders and materials used on the map are drawn once offscreen while the map first opens, so no first-use compile lands in a scroll or a win.

## 9. Audio

**The key.** Plumb's bells are C major pentatonic (C5, E5, G5, A5) and a win resolves on C4, G4, E5, A5 and D6 (`MATH.md` section 19). The whole score is in C major, so the bells always fit.

**The pieces** (Street's. Classic keeps its pad and sounds):

| Piece | Character | Length | Stems |
| --- | --- | --- | --- |
| Map theme, "Homecoming" | Lilting 6/8, a tune for the cast | about 60 s loop | bed (pizzicato strings, bassoon, harp), melody (flute and clarinet), sparkle (glockenspiel, celesta, triangle) |
| Level track | The same theme, steadier and quieter, 4/4 | about 90 s loop | bed, pulse, melody. The melody enters and grows as marbles get home |
| Cues | Level start (2 s), win (3 to 5 s, ending on the bell chord), parcel (4 s), milestone (8 s), gift open, booster unlock, shop, update card, and a gentle cue for a marble down a pit, never a sad one | short | single files |

**In Godot:** `AudioStreamInteractive` holds the map and the level, switching on the next bar. Each is an `AudioStreamSynchronized` of its stems, whose volumes follow the board (`set_sync_stream_volume`).
The OGG files carry their BPM and bars so the switch lands on a bar. Cues play on their own player on the SFX bus while the music bus ducks by about 6 dB.
New buses: Music and SFX under Master, in `default_bus_layout.tres`. The sliders keep today's square law.

**Loudness:** the level bed sits about 11 LU under the sink bells, as today (about -22 LUFS). The map, where no bells play, may sit higher, about -19.

**Made legally, by us first:**

1. The score is written as code (MIDI from Python, the way `music-machine-reels` writes songs).
2. Rendered from VSCO 2 Community Edition (CC0) and Virtual Playing Orchestra 3 (commercial music allowed), short-note instruments first (pizzicato, harp, celesta, glockenspiel, woodwinds, light percussion), since they are what free samples do well.
3. Rendered with a small SFZ sample player in Python under `tools/music/` (decision 9: no `dnf` installs).
4. Samples are fetched instrument by instrument with a sparse checkout, each download's byte count checked (large downloads truncate here), kept in `studio/game-assets` and recorded in its `PROVENANCE.md` and Plumb's `CREDITS.md`.
5. Mixed and looped in Python, loops folded so the seam is sample-exact, exported as OGG.
6. Two or three versions of the theme go to Shravan on the phone's speaker before any stems are made. If none is good enough, the theme alone could be commissioned once the games earn.

## 10. Art

The rule: draw in code and shaders wherever that holds the concept's quality, since it is cheap and re-themeable. Codex paints what code would do poorly. Every painted image is reviewed at full size beside its concept before use, and `CREDITS.md` gets "made with the help of AI tools" and nothing more specific.

**Drawn in code:**

- sky gradient, sun, clouds
- the ground (grass, the road and its cobbles, edges) as one shader
- doors on every house (frame in a theme colour, wood, number, padlock, knocker, lit windows), so their states and numbers are code
- the marbles, faces, hats and memorial (existing)
- bunting, the finish ribbon, the parcel and its lid
- all cards, ribbons, pills, round glossy buttons and their filled glyphs (calendar, stall, gear, undo, restart, bulb, play, footprints, ghost)
- toggles and tabs
- the shop's awning, counter and trays
- confetti, coins, stars, light rays
- the board tray in Street's colours (a new `Palette` set: blue rim, pale blue tiles, slate walls)
- the colour-help shapes (triangle, square, star, diamond on marbles and holes)

**Painted by Codex** (thread `plumb-revamp`, briefs through `studio/agent-bridge/codex-thread send plumb-revamp <brief.md>`):

| Batch | Pieces | Notes |
| --- | --- | --- |
| M2 | House facades, 8 variants, without doors (the door's opening marked for code) | 512 px tall, transparent PNG, straight alpha, light from top left, the round 2 palette and outline |
| M2 | Trees (3), bushes (3), lamp post, picket fence piece, flower pot, bench, post box, signpost | Upright cut-outs, base at the bottom edge |
| M3 | Milestone houses, 4 to start (each a family's home: a bakery, a windmill, a clock tower, a tree house, for example), plus an empty plot with a sign | Larger, 768 px tall |
| M3 | The settings arch with its bow, the stall's backdrop if code falls short | |
| M5 | Neighbourhood sets (a canal, a harbour, a snowy lane) | Later content, not needed for 2.0 |

`tools/pack_atlas.py` packs the cut-outs into one or two 2048 px atlases, so the map's props batch into few draw calls.
M1 uses code-drawn placeholders only.

**Type:** Baloo 2 (OFL, rounded, close to the concepts' lettering, with Devanagari) for Street's numbers and titles, Outfit as now for small text. Recorded in `CREDITS.md`.

**The new families** need Shravan's taste before they are drawn (UI study). M3 shows him options as images first.

## 11. Performance

**Budgets on the A142** (Dimensity 7200 Pro, Mali-G610 MC4, 1084 by 2412):

- 60 frames a second while scrolling the map, playing and celebrating
- 95% of frames under 16.7 ms and none over 33 ms in a 30 s scripted scroll
- at most about 150 draw calls on the map, and under 20 for the four cast marbles (measured in M2 with the painted art: the whole map takes 9 to 17, and the cast adds none, since it batches with the street's atlas)
- memory set against Classic on the same build, not as a fixed number, since M1 found the engine alone holds most of the phone's PSS (about 520 MB with the stand-ins, 204 MB of it graphics): Street's video memory at most Classic's plus 48 MB on `tools/look_memory.gd`'s counters (M2: Classic 13 MB on its title and in play, Street 45 MB on the map and 42 MB in play), and on the A142 Street's total PSS at most Classic's plus 64 MB
- the map's first frame within 1.5 s of the studio beat ending

**How it is measured:** a dev build under the separate package `com.shravangoswami.plumb.dev` ("Plumb Dev", debug-signed, with Firebase off until its own Firebase app is made for the analytics work, decision 8), with a frame logger (frame times, process time, GPU time where the driver reports it, draw calls) writing a CSV that `adb exec-out run-as` pulls.
A scripted scroll (fling, coast, reverse, repeat) makes runs comparable. Screen recordings are made with `adb shell screenrecord` and deleted from the phone after pulling.
The live Plumb (`com.shravangoswami.plumb`) is never installed over, cleared or opened, and no other app is touched.

**Known costs to watch:** overdraw from painted cut-outs (trimmed meshes if needed), text at many scales (MSDF), first-use shader compiles (warmed), the refresh rate (the phone can run at 120 Hz, and pacing at 60 is checked in M1).

## 12. Risks

| Risk | What could happen | What we do |
| --- | --- | --- |
| The migration | A live player loses stars or progress, the worst outcome of the whole revamp | Pure function, fixture saves of every layout and shape (gaps, keys, gate-opened chapters, Hard stars, an old cloud copy), a backup file, idempotence, a real 1.5.1 to 2.0 upgrade on the dev package, a closed-track release first and a staged production rollout |
| Pool coverage | A slow climber or an early tile meets no fitting board | The coverage report and generated extras in M4, the fallback order, recycling by symmetry |
| "Never drops" at the ceiling | Strictly rising boards need enough par-13 boards near the band's top for every tile | Decision 1. The coverage report counts boards at the top of the band per tile, and episodes fill the gaps |
| Two looks | Twice the screens to test and keep alive | Shared services and play core, Classic frozen apart from the Look row and the update card, both smoke robots in every test run |
| Performance | The rolling map stutters on the A142 | M1 measures before any art, the budgets in section 11 |
| Analytics plumbing | User properties need a Java helper in the build | The same pattern as `PlayCore.java`, which ships today. Checked in DebugView before release |
| The signing key | A lost key stops updates to the pool, a leaked one lets someone sign boards | Two embedded public keys for rotation, the private key only in `release-keys` and the vault, boards still checked by the solver before play |
| Music quality | Free samples sound stiff on long notes | Write for short notes, Shravan's ear decides, commission the theme later if needed |
| Painted art | Codex's pieces drift from the concepts or from each other | Full-size reviews beside the concept, one palette and outline in every brief, an atlas test |
| Ads in a flow with nothing to press | An interstitial landing without a tap breaks AdMob's rules | The interstitial only after the Play tap on a card, with today's pacing. The banner on the map only (decision 7) |
| Cloud save | Two phones grow different streets | The copy with more solved doors wins the street, stars join per id, coins take the larger side |
| Update reach | 88% of players were still on 1.4.10 on 20 November, and the new card only ships with 2.0 | Nothing in-game can fix the old builds. Play's own auto-update and a Play "Events and offers" card for 2.0 |
| The shared phone | The A142 is locked or in use | Ask the lead. Desktop measurements never stand in for the phone's |
| Scope | The revamp is large | Milestones, each playable, each gated |

## 13. Tests

All headless tests run in `tests/run_tests.gd` (`godot --headless --path . -s res://tests/run_tests.gd`), as new `_test_*` functions, and every new test is seen failing once against broken code before it counts.

**Pure logic:**

- **Projection:** screen y rises with depth and stays below the horizon, scale in (0, 1], tap points map back to the strip, a huge radius equals a flat scroll.
- **The road and doors:** the path is smooth, doors never overlap and alternate sides.
- **Ids:** main and Hard ids round-trip with Classic's indices, and every id in the pool is unique.
- **Migration:**
  - layouts 1 and 2 to 3
  - every star lands on a board identical in content to the one it was won on
  - Hard, keys and gate-opened chapters carried over
  - the backup written
  - running it twice changes nothing
  - an old cloud copy joined both ways
- **Look switch:** Classic to Street and back keep every star and open everything reached.
- **The picker,** over thousands of simulated players of known skill:
  - never an easier board
  - tiles in order
  - no repeats
  - deterministic for a seed
  - the opening fixed
  - fallbacks used only when needed
  - recycled boards solve in the same par
- **The rating:** Glickman's worked example, the outcome order, the deviation shrinking.
- **Rewards:** parcels every 5, milestones every 20, booster unlocks at 5, 10 and 15, Spare step's stars, doubling without a video.
- **The feed:**
  - signatures from a test key accepted, a flipped byte rejected
  - rollback and oversize rejected
  - unknown rules skipped
  - bad boards rejected
  - retire and rescore applied
  - writes atomic
  - street boards kept when pruning
- **Analytics,** through the sink: every event's parameters, text for dimensions, numbers for metrics, user properties only while counting.
- **The update card:** flexible or immediate, once per version per day, never in a level.
- **Settings:** Reduce motion flattens the map, Colour help puts shapes on, Larger text scales the theme.

**Robots and pictures:**

- A Street smoke robot plays doors 1 to 25 through the real scenes (door, card, the solver's route, the win, a parcel, a milestone) and greps for `SCRIPT ERROR`. Classic's smoke robot keeps running unchanged.
- `tools/street_shots.gd` captures the map at doors 1, 5, 20, 100 and 500, the card, play, each win beat, the parcel, the milestone, the shop, Settings, the chooser, the update card, Reduce motion, Colour help and Larger text on `DISPLAY=:0`. Every PNG is looked at, beside its concept.

**On the phone:** frame logs and a recording for the map (M1), the full flow (M2 and M3), and a real upgrade from a 1.5.1 build to 2.0, both under the dev package (M4).

**Release:** DebugView on a build that counts (decision 8), the AAB's manifest checks as today, then the closed track.

## 14. Milestones

| Milestone | Builds | Gate |
| --- | --- | --- |
| M0 | This plan | The lead's review |
| M1 | The projection, the road and ground shader, placeholder doors and props, drag and fling, the frame logger, the dev package and its preset | Frame numbers from the A142 over wireless adb and a short recording |
| M2 | Boot, the chooser, the map as Home, the start card, Street's play screen on the shared play core, the win sequence, back to the map, layout 3 on the dev build, the first Codex batch | Both looks played end to end on the phone, Classic unchanged by its smoke robot and tests |
| M3 | Parcels, milestones, boosters, gifts, coins, the shop, Settings General and Accessibility, the families shown to Shravan | Robots and shots, a phone run |
| M4 | The picker, the rating, the pool and its extras, the feed client and fixtures, the full analytics and their GA4 definitions, the migration finished with every test | Simulated players, the migration suite, a real 1.5.1 to 2.0 upgrade on the dev package |
| M5 | The score, motion polish, the update card, performance, store and privacy updates, `CHANGELOG.md` 2.0.0 | A release candidate on the closed track only after the lead's and Shravan's OK |

Version 2.0.0 is Play's version code 20000.

### M3 as built (21 November)

- **Rewards** are pure rules in `scripts/street/rewards.gd` (MATH.md section 28), the purse and keepsakes in Save's `[street]` section (coins, helpers, opened gifts, knockers, things owned, hats worn).
- **The map** shows a coin pill in the sky's corner (a tap opens the shop), the golden knocker on doors won at par, and at every 20th door an empty plot whose sign carries the number, with the finish ribbon in front of it. After its milestone the family's house stands on the plot with its family in front (`StreetFamilies`, `StreetFolk`), the windmill's sails turning.
- **The parcel and the milestone** are overlays on the map (`StreetGift`, `StreetMilestone`, on `StreetMoment`) over Codex's gift backdrop and the win square. Their contents go in the save the moment they open, and one won but never opened opens the next time the street loads.
- **Helpers** are picked on the start card. Footprints shows the solver's first two tilts as the hint trail while the player follows them. Ghost marbles makes the next swipe wait for the finger to lift and shows faint marbles where it would leave them. Spare step adds a move of leeway for the stars only. Footprints and ghosts count as help for the knocker and the clean bonus.
- **The shop and Settings** are overlays too (`StreetShop`, `StreetSettings`), not scenes of their own, so the street stays loaded under them and closing them is instant. The shop sells hats (each worn by the cast member of its colour), the seven marble sets (one bought here is open in Classic as well, through `Looks.is_open`) and helpers, plus the Supporter row through the kit's own offer. Settings' General tab holds Sound, Music, Faces, Pets, phone tilt where the phone can feel it, the Street look and More (the kit's sheet: How to play, About, Credits, privacy, reset). Accessibility holds Reduce motion, Colour help (a shape per colour on marbles and holes, in both looks) and Haptic feedback.
- **The daily** pays its 30 coins once a day, when the street next loads after it is solved (the daily screen stays the kit's).
- **Left for later:** street decorations in the shop (no art or rules yet), Larger text, a wider shop for landscape screens (it fits the height today, so its trays are small on a turned phone), the welcome purse (question 16) and the cloud-save join for the new keys (M4).

### M4 as built (21 November)

- **Stars stay by position for the two fixed paths.** `best[id]` is kept only for boards off them (extras, feed and recycled boards, `progress/best`). A main or Hard board's id is its position (`main-0042` is `stars[41]`, `hard-0001` is `hard[180]`), so `Save.best_of(id)` and `Save.record_id(id)` read and write the same arrays Classic reads, and Classic and its kit code needed no change. The plan's `opened_ids` stays `opened` and `hard_opened` for the same reason.
- **The street** is one Dictionary in `[street] state` (doors, each door's difficulty, par and pick step, `p`, the target, the floor, μ, φ, when it was last rated and the doors solved), so the cloud save brings a street and its rating together. The floor is the hardest door so far, which is the last door's for a street the picker made and the hardest solved for a migrated one.
- **Glue, not autoloads, for the pool and the street.** `StreetPool.shared()` reads the bundled pool once, started on a worker thread at launch (`StreetPool.warm`), and `Street` (`scenes/street/street.gd`) is a static class over `Save`. Only `Feed` is a new autoload, after `Pack`.
- **The picker's fallback order** is feel and layout first, then the tile need, then the wider window. Widening first sent boards racing ahead of slow simulated players on a thin pool, and since no door may be easier than the last, a door too hard stays that hard.
- **Two more picker rules from the simulated players.** Par ratchets as d does, so each step up in par costs a candidate half a bit (`PAR_COST`), and a floor already ahead of the climb counts the rules of the main level it has reached as taught. Without them players below 1700 ran 3 to 5 bits above their target by door 60 and recycled from door 70. With them nobody recycles in 150 doors and players of 1900 and up stay on the target, but slower ones still ran 1 to 2.5 bits above it from door 60. The second round of extras closed that: every simulated player from 1100 to 1500 now stays within half a bit of the target through door 150. A third round along levels 131 to 180 brought strong players' jumps there from 1.4 to 2.2 bits down to about 1.
- **Extras:** 3 per main level from 6 to 180, then later rounds of 3 more for levels 30 to 130 and 131 to 180 where the simulated players ran short (`tools/generate_extras.gd`, 923 boards in `levels/pool.json`, 240 KB), each made in its level's chapter phase within -0.25 to +0.75 bits and new against every other board, measured into `levels/meta.json` with the rest. A later round only appends, so no id ever changes.
- **The migration** pays the welcome purse (5 coins a star, once), starts the street at the furthest level solved or opened, and copies the old file to `user://plumb.layout2.cfg` first. The parcels and milestones behind the player count as opened (the purse stands for them, and those families already live on the street), and the first three parcels' helpers come with it, 3 of each. The switch from Classic does the same for the doors it brings. Marble-pack owners already own every set in Street's shop through `Looks.is_open`, so step 7 needed nothing.
- **The cloud save** gained `CloudSave.rules()`, which merges the game's own rules (`Save.cloud_rules`), and hands rules it does not know to `Save.cloud_join`: both small, for porting back to the kit.
- **The feed** has no server yet. `tools/publish_levels.py` writes a signed bucket, the fixtures in `tests/fixtures/feed/` are signed with a test key (its private half `plumb-feed-test.pem` beside the others), and the signing keys `plumb-feed-1.pem` (in use) and `plumb-feed-2.pem` (next) are in `studio/release-keys`. A debug build looks at the feed only when told to (a `--feed=` argument or a `user://feed_on` file), so tests and robots never reach the network.
- **Analytics:** the level events carry the board, path, difficulty, rating, pick and replay through `Analytics.level_context`, and level_end how the solve went through `Analytics.solve_measures`. User properties go through `addons/analytics_user/AnalyticsUser.java`. `Ads.solved()` counts every board solved (pacing, the daily's gate, achievements), and `Ads.solved_here()` the section in play (the ending and `solved_all`).
- **Left for later:** the update card (M5), the Data Studio pages and HQ (5.4), and the privacy page's new events.

## 15. Decisions and open questions

### Decided by the lead, 20 November

1. **"Never drops" is kept strictly in Street** (4.3). The next door's target is never below the last door's and par never falls, with no allowance. At the comfort ceiling it holds flat at the top and never falls below the band's floor. Classic keeps its current behaviour.
2. **New tiles arrive by the climb**, not by door number.
3. **Updating players see the look chooser once**, with no default: two live previews and almost no words.
4. **Classic gets no adaptive levels.** It shares stars by id, and its play updates the rating.
5. **Street sells only the Supporter pack for money.** Classic's shop stays as it is, and buyers keep everything in both looks. Level keys, Every level and the themes pack are not shown in Street.
6. **Hard is a hill road** off the first milestone, its levels in their fixed order.
7. **Ads:** the banner on the map only, never in play. Interstitials keep today's rules (none before 12 solved levels, and the existing spacing), shown only after a Play tap on a start card. Every reward is free when no video is ready.
8. **The dev package gets its own Firebase app,** `com.shravangoswami.plumb.dev` in project `chaosmos-studio`, made with the Firebase CLI and its config fetched with `apps:sdkconfig`. Its SHA keys are not added to the shared Android API key's restrictions without telling the lead.
9. **No `dnf` installs.** The music is rendered with a small Python sample player.

### Still open

10. **The daily in Street.** Recommendation: the kit's daily screen for 2.0, reached from the calendar button, and a Street-styled daily with its calendar after.
11. **The wordmark and icon.** Recommendation: keep today's. The concepts' chunky PLUMB is not adopted unless Shravan asks.
12. **The families.** Decided by Shravan, 20 November: marble folk (`build/review/art/families-1.png`), round marbles like the cast in new colours, each family told apart by small props and the cast's faces. He gave creative freedom on the details. They are drawn in M3, after the M2 parity pass.
13. **The feed's address and key.** `levels.chaosmos.studio` on R2, and the signing key in `release-keys` and the vault.
14. **A dark look for Street.** Recommendation: light only in 2.0, with a dusk street (a tint and lit windows) after.
15. **Lanterns and a daily post-box letter** from the study are left out of 2.0, since the brief did not ask for them.
16. **A welcome purse** for players who were already playing, 5 coins a star.

## 16. Screen shapes: portrait first, wide composed

Shravan's rule, 20 November, for this revamp and every one after it: the game is designed for portrait, and it is landscape friendly in a very good way, so it looks good on a desktop too. A wide screen (a phone or tablet turned sideways, a Chromebook, a desktop or web window) gets its own composed layout, never a stretched or letterboxed portrait.

**The mechanism** (`scripts/street/layout.gd`, `StreetLayout`). The stretch stays `canvas_items` with `expand`, and its base turns with the window: 720 x 1280 when the window is tall or square, 1280 x 720 when it is wide. So a phone is 720 units across its short side either way, and a button is the same size in the hand. A squarer screen shows more than the base along one side (a turned tablet is 1280 x 960). Each screen asks `StreetLayout.wide(size)` and lays itself out, and every layout runs again on `size_changed`, so turning the phone or resizing a window keeps all state. The alternative, one portrait base with `expand`, was rejected: a landscape phone would see the design shrunk to about 56%. Classic keeps its own rule (a phone held in portrait, a large screen turning around a centred column), and `AppLook.use` switches between the two.

| Screen | Portrait | Wide |
| --- | --- | --- |
| Map | The rolling street fills the screen, buttons in a row along the foot | The street is a world 1280 units tall scaled to the screen's height, its bow eased so the edges sink as in portrait, bands of meadow trees out to its edges (`StreetPath.far_scenery`), the buttons in a column down the right edge |
| Start card | The concept's tall card | A wide card under the same ribbon: marbles, holes and par on the left, helpers and Play on the right |
| Play | Sign, moves and faces above the board, buttons below | The board a large square in the middle, the sign and the moves on the left rail, the faces standing up and the buttons in a column on the right rail |
| Win | The concept's composition | The same scene scaled to the height, the stars clear above the roofs |
| Chooser | Two cards side by side | Two cards sized by the height, side by side |

Whole-screen paintings come in a portrait and a wide version (`<name>_wide.png`, 2560 x 1440, with everything that matters inside the crop every wide shape shows). `StreetArt.backdrop` picks the one for the screen's shape.

**Input.** Touch, mouse and keyboard all work. The mouse acts as a finger (`emulate_touch_from_mouse`), and the wheel rolls the street. Arrow keys tilt the board and walk the street a door at a time, Enter opens the next door's card and plays it, and Esc goes back or closes.

**Export settings.** `display/window/handheld/orientation` stays Sensor (6), so the manifest locks nothing, and Street sets `ScreenLock.phones_turn` so phones turn too while Classic holds them in portrait. Godot's Android template writes `android:resizeableActivity="false"`. Android 12 and later ignore it on large screens (600 dp and up) and allow multi-window and free-form desktop windows anyway, and apps that target API 36, as Plumb does, can no longer restrict orientation or resizing on large screens. A phone in split screen is the one case it still blocks, and it is left as it is for 2.0.

**Tests.** `tools/street_shots.gd` renders every screen at 1080 x 2400 (portrait phone), 2400 x 1080 (landscape phone), 1920 x 1080 and 2560 x 1080 (desktop) and 2048 x 1536 (tablet), and every gate's pictures include a landscape one. `tests/run_tests.gd` checks the base rule and the meadow's bands.
