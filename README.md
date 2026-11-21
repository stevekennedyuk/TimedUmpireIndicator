# Umpire Clicker

Umpire indicator and tournament clock for baseball and softball, by NetTek Ltd:
balls, strikes, outs, innings, runs, the no-new-innings and drop-dead timers,
and the run-ahead (mercy) rule.

| Folder | What it is |
|---|---|
| `iOS/` | iPhone, iPad and Apple Watch app (SwiftUI). Open `iOS/UmpireClicker.xcodeproj` in Xcode. See `iOS/README.md`. App Store screenshots script is in `iOS/AppStore/`. |
| `Android/` | Android phone/tablet and Wear OS app (Kotlin, Jetpack Compose). Open the `Android` folder in Android Studio. See `Android/README.md`. |
| `icon-source/` | Scripts that draw the app icon (`make_icon.py`) and the Android adaptive-icon layers (`make_android_icons.py`). |

Both platforms follow the same rules. `Android/shared` is a line-for-line port
of `iOS/Shared/Models`, with tests describing the behaviour; when a rule
changes, change it in both places.
