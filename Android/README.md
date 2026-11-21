# Umpire – Android and Wear OS

The Android phone/tablet app and the Wear OS watch app. They follow the iOS
apps in `../iOS` screen for screen and rule for rule.

## Open and run

1. Install Android Studio (Ladybug or newer).
2. **File ▸ Open** and choose this `Android` folder. Let Gradle sync.
3. Pick the `app` configuration for a phone or tablet, or `wear` for a watch,
   and press Run.

From a terminal: `./gradlew :app:assembleDebug :wear:assembleDebug`

## Modules

| Module | What it is |
| --- | --- |
| `shared` | The rules engine and clock: `GameSettings`, `GameState`, `GameTimer`, plus `Session` — the per-second game loop (threshold alerts, drop-dead prompt, no-new ending, idle auto-close) that iOS has inside both `GameView` and the watch `ContentView`. Plain Kotlin, no Android. The twin of `iOS/Shared/Models`. |
| `app` | Phone and tablet app (Jetpack Compose, Material 3): Game, History, Settings and About tabs, like the iPhone. Min Android 8.0. |
| `wear` | Wear OS app: Indicator, Timer, Line score and Setup pages, like the Apple Watch. Min Wear OS 3. Umpires on its own; no phone needed during a game. |

## Same as iOS

- Count rules, runs entry on the 3rd out, regulation (7 / 9), extra innings,
  undo (30 steps, across count resets and half/inning changes).
- No-new and drop-dead timers, enforce/advisory drop-dead, "Play on", the
  allow-ties revert, untimed mode, idle auto-close after no-new.
- Run-ahead: one margin per inning per sport (0 = off), extras reuse the last
  entry, Home ahead after the top half ends it at N½. Defaults: softball
  20+ at the 4th, 15+ from the 5th; WBSC baseball 15+ from the 5th, 10+ from the 7th.
- Threshold alerts: burst of vibration plus a full-screen flash in the app;
  exact-alarm notifications (with a second drop-dead ping 15 s later) when the
  app isn't on screen.
- Phone settings: the Settings tab is the default; per-game changes in New
  game carry into the next game and expire after the idle limit.

## Different from iOS (because Android can)

- **The watch keeps its screen on during a game**, so it never drops back to
  the watch face. (On Apple Watch this needs the Return to Clock setting.)
- Swipe-to-dismiss is off in the watch app, so a right swipe on the first page
  can't close it mid-game; use the side button to leave.

## Phone ↔ watch

Wearable Data Layer, like WatchConnectivity on iOS:

- **Send to watch** (Settings tab) copies the defaults to the watch (`/settings`).
- Each kept-score game finished on the watch goes to the phone's History (`/game/<id>`).

Both apps **must have the same application ID (`uk.nettek.umpireclickertimer`)
and be signed with the same key.** Debug builds from one computer already are.

## Checking layouts without a device

The real screens are drawn to PNG files by unit tests:

    ./gradlew :shared:test              # rules engine and session (37 tests)
    ./gradlew :app:testDebugUnitTest    # → app/build/screens  (phone, small phone, tablet)
    ./gradlew :wear:testDebugUnitTest   # → wear/build/screens (round 192, round 225, square 180)

## Versions

`build.gradle.kts` in this folder holds `appVersionName` (follows iOS, now
1.6) and `appVersionCode` for both apps. The watch app's version code is
100000 + the phone's, because Play needs a different code for each. Same policy
as iOS: the project always holds the **next unused** code; raise it straight
after an upload.

## Play Store notes

- Upload the phone and watch bundles to the same Play listing (the watch one
  under the Wear OS form factor).
- The apps use `USE_EXACT_ALARM` so the no-new and drop-dead alerts fire on
  the second. Play asks for a declaration: the core function is a timer.
- Notifications permission is asked for when the first timed game starts.
- No data leaves the device except between your own phone and watch. No
  accounts, no analytics, no adverts.

## Not yet checked on real hardware

Builds, lint, engine tests and screen renders pass. Still to try on a device
or emulator: phone ↔ watch sync, background alerts with the screen off,
vibration strength, and the watch staying awake for a full game.
