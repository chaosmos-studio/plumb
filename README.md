# Plumb

A minimalist marble-sorting puzzle. Swipe and the whole board tilts: every marble rolls until something
stops it, and a marble drops into a hole of its own colour. Clear the board in as few tilts as you can.

**Website: https://shravangoswami.com/plumb/** (the blog, support, privacy policy, and more), built from
`website/`. **Play in the browser: https://shravangoswami.com/plumb/play/** (swipe, or arrow keys / WASD;
Z undo, R restart, H hint). The web build updates on every push to `main`, and the site on every change to
`website/`.

Godot 4.7, GL Compatibility, 2D, portrait, Android first. 120 levels, every one generated and proven
solvable by the solver, with the solver's shortest route as par. No level repeats another, and none is
easier than the one before it.

## Run it

```
godot --path .                                          # play on the desktop
godot --headless --path . -s res://tests/run_tests.gd   # rules, solver, scoring, and a re-solve of every level
godot --headless --path . res://tools/smoke.tscn        # a robot plays six levels through the real screens
DISPLAY=:0 godot --path . --resolution 720x1280 res://tools/shots.tscn   # screenshots of every screen
```

## Regenerate

```
godot --headless --path . -s res://tools/generate_levels.gd   # levels/levels.json (2 to 3 minutes)
python3 tools/make_sfx.py                                     # assets/audio/sfx (numpy, ffmpeg)
python3 tools/make_icons.py                                   # web/ icons and assets/branding/icon.png (Pillow)
python3 tools/make_font.py                                    # the seam-free static font (fonttools, skia-pathops)
```

`PLAN.md` is the design and the roadmap, `MATH.md` explains the rules, the solver and the generator,
and `CREDITS.md` lists what is third-party: the font, and the AdMob and Play billing plugins of the Android
build.

## Releasing

`CHANGELOG.md` is the one file to edit. To ship an update:

1. Add a section at the top of `CHANGELOG.md`: a `## 1.0.1` heading, then one `- ` line per change,
   written for players. The comment at the top of the file has the rules.
2. Commit and push.
3. Run **Release Android**: Actions, Release Android, Run workflow. It needs no inputs.

That section names everything. The version is the tag (`v1.0.1`) and the build's version name, Play's
version code is major * 10000 + minor * 100 + patch (1.0.0 is 10000, 1.0.1 is 10001), and the notes
become the GitHub release notes and Play's "What's new". The game reads the same file, so Settings and
About show the same version, on Android and in the browser.

```
gh workflow run release-android.yml                          # release the changelog's newest version
gh workflow run release-android.yml -f dry_run=true          # build and check only
gh workflow run release-android.yml -f play_track=internal   # release, and upload to internal testing
```

The run reads the changelog with the same rules as the game's tests, runs the tests and the smoke robot,
exports a signed AAB and APK through the Gradle build (target SDK 36, arm64-v8a and armeabi-v7a), checks
both, and publishes a full GitHub release, marked Latest, titled `Plumb 1.0.1`, with the AAB, the APK
and `play-release-notes.txt` attached. Its body has the player notes, then the build (package, version
code, target SDK, the signer's SHA-256 and which key signed it), then Play's "What's new" in the
`<en-US>` form the Play Console release notes box takes. A dry run keeps the same files as a workflow
artifact but makes no tag, no release and no upload.

Play never accepts a version code twice, even for a rebuild, so every new upload gets a new section with
at least the patch number bumped. The run stops before building if the tag exists, if the code is not
above every earlier release's, if the heading is not a plain x.y.z, if the section has no notes, or if
the notes are over Play's 500 characters. `godot --headless --path . -s res://tests/run_tests.gd` catches
the same mistakes before you push.

**Uploading to Google Play from the run.** `play_track` is `none` by default. Set it to `internal`,
`alpha` (closed testing), `beta` (open testing) or `production` to also send the AAB and its notes to
that track; production goes up as a draft, so you still press the last button in Play Console. It needs
the upload key and a `PLAY_SERVICE_ACCOUNT_JSON` secret, and each app's very first AAB has to be uploaded
by hand in Play Console. The one-time setup is in the workspace's `MINI_GAMES_PUBLISHING.md`, section 4.6.

Builds are signed with the game's upload key, `plumb-release.jks` (alias `plumb`), kept outside the repo in the
workspace's `release-keys/` folder beside `plumb-key.properties`. The repository holds it as the
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` and `ANDROID_KEYSTORE_PASSWORD` secrets, and the
`UPLOAD_KEY_SHA256` variable pins releases to it, so a run with any other key stops. Keep a backup of both
files: losing the upload key means a slow reset through Play support. Without the secrets, builds fall back
to a throwaway key: fine for sideloading, not uploadable to Play.
