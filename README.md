# Plumb

A minimalist marble-sorting puzzle. Swipe and the whole board tilts: every marble rolls until something
stops it, and a marble drops into a hole of its own colour. Clear the board in as few tilts as you can.

**Play the web preview: https://shravangoswami.com/plumb/** (swipe, or arrow keys / WASD; Z undo, R restart,
H hint). The preview updates on every push to `main`.

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
and `CREDITS.md` lists the one third-party asset (the font).

## Releasing

Android builds come from the **Release Android** workflow, started by hand from the Actions tab or with:

```
gh workflow run release-android.yml -f version_name=0.1.0                      # a prerelease
gh workflow run release-android.yml -f version_name=1.0.0 -f prerelease=false  # a full release
```

It runs the tests and the smoke robot, exports a signed AAB and APK through the Gradle build (target SDK 36,
arm64-v8a and armeabi-v7a), checks both, and publishes them on a GitHub release tagged `v<version_name>`.
The same two files are kept on the run as a workflow artifact. Google Play takes the AAB; the APK is for
installing straight on a phone.

`version_code` defaults to the run number + 100. Play rejects any code it has already seen, even on a test
track, so the workflow refuses a code that is not above every earlier release's, and a tag that exists.

Until the repository has an upload key, builds are signed with a throwaway key and the release notes say so:
fine for sideloading, not uploadable to Play. To switch to a real upload key, run once:

```
tools/make_upload_key.sh
```

It creates `~/.android-keys/plumb-upload.jks` with a random password kept beside it in
`plumb-upload.txt`, prints the certificate's SHA-256, and after asking, sets the `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_ALIAS` and `ANDROID_KEYSTORE_PASSWORD` secrets the workflow signs with. Back up
`~/.android-keys`: losing the upload key means a slow reset through Play support.
