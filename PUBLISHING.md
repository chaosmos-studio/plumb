# Publishing Plumb on Google Play

Plumb's own values and progress. The account setup done once, and every answer that is the same for
every Chaosmos game, are in `STUDIO_PLAY_SETUP.md` in the Games folder (`~/Work/Weekend-Projects/Games/`).
Section numbers below point there.

## The app

| | |
| --- | --- |
| Package | `com.shravangoswami.plumb` |
| App name | Plumb: Marble Tilt Puzzle |
| Privacy policy | https://chaosmos.studio/plumb/privacy/ |
| Website (Store settings) | https://chaosmos.studio/plumb/support/ |
| Listing text | `assets/store/listing.md` |
| Graphics | `assets/store/` |
| Latest build | [v1.2.1](https://github.com/chaosmos-studio/plumb/releases/tag/v1.2.1) |
| AdMob app id | `ca-app-pub-3135321730568420~4276024954` |
| AdMob units | banner `.../4401816337`, interstitial `.../1199928764`, rewarded `.../9789874380` (all in `monetize.gd`) |
| Firebase | Android app in project `chaosmos-studio`, in `google-services.json` |
| Upload key | `release-keys/plumb-release.jks`, alias `plumb` (password in `plumb-key.properties`) |
| Upload key SHA-1 | `95:E9:15:AA:36:6D:9E:D9:66:B2:D0:3C:5A:EA:02:EB:F2:3F:01:6F` |
| Upload key SHA-256 | `2D:B4:C0:F5:8A:CA:DC:CE:73:B6:98:ED:60:66:5B:B8:C9:D1:CD:D3:4B:E0:40:18:69:5E:04:65:09:F1:E0:EB` |
| What makes it unique (2.9) | One swipe tilts the board and moves every marble at once. |

## Progress

- [x] Builds 1.0.0 to 1.2.1 on GitHub
- [x] Create the app (2.1)
- [x] Listing, store settings and App content (2.2 to 2.4)
- [x] Internal testing (2.5)
- [x] Supporter pack (2.6)
- [ ] The other shop products (2.6): Every level, Marble pack, Themes, Complete, keys, tips
- [x] Test purchase (2.7)
- [x] Closed test live with 1.2.1 (2.8, 2026-10-10)
- [ ] 12 testers opted in for 14 days (write the date): ____
- [ ] Applied for production (2.9), from 17 October
- [ ] Live on Play (2.10)
- [ ] Firebase key restricted with both SHA-1s (1.8)
- [ ] AdMob linked to the listing and Ready (3.1)

## Store listing (2.2)

| Field | Value |
| --- | --- |
| App name | Plumb: Marble Tilt Puzzle |
| Short description | Tilt the board and roll every marble into the hole of its own colour. |
| Full description | "Full description" in `assets/store/listing.md` |

Alt text for the phone shots, in order. Each tablet shot reuses the line of the phone shot with the same
name.

| File | Alt text |
| --- | --- |
| `01_play` | A level in play: coloured marbles, walls and matching holes, and the swipe that tilts the board. |
| `02_swipe` | One swipe moves everything: the same board before and after a tilt. |
| `03_hint` | The hint shows where each marble would land. |
| `04_won` | A solved level with three stars and a card to share. |
| `05_rules` | Four chapters' rules: colour gates, portals, bumpers and magnets. |
| `06_themes` | Colour themes and marble sets in light and dark. |
| `07_title` | The title screen with the Play button. |

## Store settings (2.3)

Category **Game > Puzzle**. Tags: Puzzle, Logic puzzle, Brain teaser, Casual, Physics-based.

## Products (2.6)

Monetize with Play > Products > **One-time products** > Create one-time product, once for each row
below. The product IDs must be exactly these, and they are permanent. Every product has the same settings:

| Field | Answer |
| --- | --- |
| Tags | Empty |
| Icon | None |
| Product tax category | Digital app sales |
| Age rating (US states) | The lowest, matching the game (Everyone) |
| Payment location restriction | No country / region restricted |
| Purchase option (next page) | ID `buy`, type Buy, multi-quantity purchases off |
| Availability | All countries and regions |
| Price | The Price column, entered with Set prices > Bulk edit. Play converts it for every other country. |
| Then | Activate |

| Product ID | Name | Price | Description |
| --- | --- | --- | --- |
| `supporter` | `Supporter pack` | US$2.99 | Turns off the ads in Plumb for good and makes every hint free. One purchase, yours to keep, and it helps me make the next game. Thank you for playing. |
| `all_levels` | `Every level` | US$1.99 | Opens every level at once, so you can play them in any order. Stars are still earned by solving. One purchase, yours to keep. |
| `looks` | `Marble pack` | US$1.99 | Five more marble sets: gems, planets, candy, pearls and yarn. Pick one any time in Settings. One purchase, yours to keep. |
| `themes` | `Themes pack` | US$1.99 | 15 colour themes in light & dark: Solarized, Gruvbox, Nord, Dracula, Tokyo Night, Catppuccin, One, Ocean, Forest, Rose, Grape, Everforest, Rosé Pine, Kanagawa & Mono. One purchase, yours to keep. |
| `complete` | `Complete pack` | US$6.99 | Everything in one: no ads, every hint free, every level open, the Marble pack and the Themes pack, for less than buying them apart. One purchase, yours to keep. |
| `level_key` | `Level key` | US$0.49 (INR 20) | Opens any one locked level for good. Tap a locked level to use it. Buy as often as you like. |
| `level_keys_5` | `5 level keys` | US$0.99 (INR 49) | Five keys, each opening any one locked level for good. Tap a locked level to use one. Buy as often as you like. |
| `tip_1` | `Small tip` | US$0.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |
| `tip_2` | `Tip` | US$1.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |
| `tip_5` | `Big tip` | US$4.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |
| `tip_10` | `Generous tip` | US$9.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |
| `tip_20` | `Very generous tip` | US$19.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |
| `tip_50` | `Huge thank you` | US$49.99 | A thank-you to the maker of this game. It opens nothing, but it helps make the next game and more levels. Tip as often as you like. |

For the Supporter pack, check the India price Play suggests: around INR 199 is your call. Then test the
products with the steps in 2.6 and 2.7.
