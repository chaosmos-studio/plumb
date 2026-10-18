# Credits

Every third-party asset in the build and its licence. This file is a release blocker: a CC-BY line
missing here is a licence violation, not a typo. Sourcing notes live in the workspace `ASSETS.md`; raw
downloads live in the private `game-assets` repo checked out at `faceplant/assets_incoming`, whose
`PROVENANCE.md` has the full table.

Only CC0, CC-BY and SIL OFL (fonts) assets ship. Third-party code is MIT, apart from Google's SDKs in the
Android build, which come under Google's own terms. Note every modification (rescaled, recoloured, retimed).

## Fonts

| Asset | Author | Licence | Notes |
| --- | --- | --- | --- |
| Outfit (`assets/fonts/Outfit-Light.ttf` and `assets/fonts/Outfit-Medium.ttf`, and the light one again as `web/Outfit-Light.ttf` for the loading page) | The Outfit Project Authors | SIL Open Font License 1.1 (`assets/fonts/Outfit-OFL.txt`) | Modified: static weight-300 and weight-500 instances of the variable font with overlapping contours merged, written by `tools/make_font.py` from the unmodified source in `assets/fonts/source/`. The variable font's overlaps showed as faint seams across stems. The licence declares no Reserved Font Name. |

## Ads, purchases and analytics (Android build only)

The web build ships none of these plugins (the Web preset excludes `addons/`).

| Component | Author | Licence | Notes |
| --- | --- | --- | --- |
| Godot AdMob Plugin 5.1.0 (`addons/admob/`, with the Android binaries of `android-template-v4.7.0.zip` in `addons/admob/android/bin/`) | Poing Studios | MIT (`addons/admob/LICENSE`) | Unmodified, except that its `android/.gitignore` and `ios/.gitignore` are dropped so the binaries are committed, and `csharp/.gdignore` is added, as the plugin itself does in a GDScript project. Only the `ads` module is used, no mediation adapters. iOS gets only its `package.gd` marker, so the editor plugin never downloads iOS binaries. The Android presets leave out its samples, docs, C# code, skills, editor assets and mocks. |
| GodotGooglePlayBilling 3.1.0 (`addons/GodotGooglePlayBilling/`) | Godot Engine contributors (Godot Foundation, godot-sdk-integrations) | MIT | Unmodified. |
| Google Mobile Ads SDK (next-gen) 1.4.0, with the User Messaging Platform SDK | Google | Google's terms: the Google Mobile Ads SDK and AdMob terms | Fetched by Gradle at build time, not stored in the repo. |
| Google Play Billing Library 8.0.0 (`billing-ktx`) | Google | Android Software Development Kit License | Fetched by Gradle at build time, not stored in the repo. |
| Godotx Firebase 3.1.0 (`addons/godotx_firebase/`, with its Android libraries in `android/firebase_core/` and `android/firebase_analytics/`) | Paulo Coutinho (godot-x) | MIT (`addons/godotx_firebase/LICENSE`) | Unmodified. Only the Core and Analytics modules: no iOS, Crashlytics or Messaging parts. The Android presets leave its editor scripts out. |
| Google Analytics for Firebase 23.2.0, with Firebase Common 22.1.0 | Google | Google's terms: the Firebase and Google Analytics for Firebase terms | Fetched by Gradle at build time, not stored in the repo. |
| Google services Gradle plugin 4.4.4 | Google | Apache License 2.0 | Applied to the build by `addons/firebase_build/`, not shipped in the app. |
| Google Play In-App Review 2.0.2 and In-App Updates 2.1.0 | Google | Play Core Software Development Kit Terms of Service | Fetched by Gradle at build time, not stored in the repo. `addons/play_core/` adds them and its own small Java helper, `PlayCore.java`, which is original to this project. |

## Sound effects and music

All synthesised by `tools/make_sfx.py`, including the ambient music loop. None are third-party.

## Everything else

Code, generated art and synthesised audio are original to this project, apart from the plugins above.
