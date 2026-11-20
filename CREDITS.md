# Credits

Every third-party asset in the build and its licence. This file is a release blocker: a CC-BY line
missing here is a licence violation, not a typo. Sourcing notes live in the workspace `docs/ASSETS.md`. Raw
downloads live in the private `game-assets` repo checked out at `studio/game-assets`, whose
`PROVENANCE.md` has the full table.

Only CC0, CC-BY and SIL OFL (fonts) assets ship. Third-party code is MIT, apart from Google's SDKs in the
Android build, which come under Google's own terms. Note every modification (rescaled, recoloured, retimed).

## Fonts

| Asset | Author | Licence | Notes |
| --- | --- | --- | --- |
| Outfit (`assets/fonts/Outfit-Light.ttf` and `assets/fonts/Outfit-Medium.ttf`, and the light one again as `web/Outfit-Light.ttf` for the loading page) | The Outfit Project Authors | SIL Open Font License 1.1 (`assets/fonts/Outfit-OFL.txt`) | Modified: static weight-300 and weight-500 instances of the variable font with overlapping contours merged, written by `tools/make_font.py` from the unmodified source in `assets/fonts/source/`. The variable font's overlaps showed as faint seams across stems. The licence declares no Reserved Font Name. |
| Baloo 2 (`assets/fonts/Baloo2.ttf`), the Street look's numbers and words | The Baloo 2 Project Authors (Ek Type) | SIL Open Font License 1.1 (`assets/fonts/Baloo2-OFL.txt`) | Unmodified variable font, the same file Faceplant ships. The game picks its weight-800 instance at run time. The licence declares no Reserved Font Name. |

## Ads, purchases and analytics (Android build only)

The web build ships none of these plugins (the Web preset excludes `addons/`).

| Component | Author | Licence | Notes |
| --- | --- | --- | --- |
| Intermission 0.1.0 (`addons/intermission/`, with its four Android libraries in `addons/intermission/bin/`) | Shravan Goswami (Chaosmos), [chaosmos-studio/godot-intermission](https://github.com/chaosmos-studio/godot-intermission) | MIT (`addons/intermission/LICENSE`) | Unmodified, the addon zip its CI built from commit `faedd07`. The Android presets leave out its two editor scripts. |
| Unity LevelPlay 9.8.0 (`mediation-sdk`), Ad Quality SDK 9.12.1, Unity Ads 4.22.0 with its LevelPlay adapter 5.17.0, and coherencelib 0.3.0 | Unity Technologies | Unity's terms, including its Advertising Additional Terms | Fetched by Gradle at build time, not stored in the repo. |
| Google Play services `play-services-ads-identifier` 18.3.0 and `play-services-appset` 16.1.0 | Google | Android Software Development Kit License | Asked for by LevelPlay. Fetched by Gradle at build time, not stored in the repo. |
| GodotGooglePlayBilling 3.1.0 (`addons/GodotGooglePlayBilling/`) | Godot Engine contributors (Godot Foundation, godot-sdk-integrations) | MIT | Unmodified. |
| Google Play Billing Library 8.0.0 (`billing-ktx`) | Google | Android Software Development Kit License | Fetched by Gradle at build time, not stored in the repo. |
| Godotx Firebase 3.1.0 (`addons/godotx_firebase/`, with its Android libraries in `android/firebase_core/` and `android/firebase_analytics/`) | Paulo Coutinho (godot-x) | MIT (`addons/godotx_firebase/LICENSE`) | Unmodified. Only the Core and Analytics modules: no iOS, Crashlytics or Messaging parts. The Android presets leave its editor scripts out. |
| Google Analytics for Firebase 23.2.0, with Firebase Common 22.1.0 | Google | Google's terms: the Firebase and Google Analytics for Firebase terms | Fetched by Gradle at build time, not stored in the repo. |
| Google services Gradle plugin 4.4.4 | Google | Apache License 2.0 | Applied to the build by `addons/firebase_build/`, not shipped in the app. |
| GodotPlayGameServices 3.4.0 (`addons/play_games/bin/`) | Jacob Ibáñez Sánchez and contributors (godot-sdk-integrations) | MIT (`addons/play_games/LICENSE`) | Built from its v3.4.0 tag without the uncaught exception handler it sets (upstream pull request 126), on Play Games Services v2 22.1.0 and with a small Game Stats addition of ours, by the Play Games plugin workflow in game-making-skills. Only its two Android libraries are kept. `addons/play_games/plugin.gd`, original to this project, adds them to Android builds. |
| Google Play Games Services v2 22.1.0 and Gson 2.11.0 | Google | Android Software Development Kit License, Apache 2.0 | Fetched by Gradle at build time, not stored in the repo, and only once the game has its Play Games project. |
| Google Play In-App Review 2.0.2 and In-App Updates 2.1.0 | Google | Play Core Software Development Kit Terms of Service | Fetched by Gradle at build time, not stored in the repo. `addons/play_core/` adds them and its own small Java helper, `PlayCore.java`, which is original to this project. |

## Sound effects and music

All synthesised by `tools/make_sfx.py`, including the ambient music loop. None are third-party.

## Everything else

Code, generated art and synthesised audio are original to this project, apart from the plugins above.
The Street look's painted art (`art/street/`, packed into `assets/street/` by `tools/pack_street.py`) is original
to this project too, made with the help of AI tools.
