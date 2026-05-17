# Umpire Clicker

A watchOS umpire indicator for baseball / softball with built-in tournament timers, plus an iPhone companion for settings and game history.

## What it does

**On the watch (primary tool)**

- Big tappable Balls / Strikes / Outs counters. Tap to increment, long-press to decrement. Auto-rolls a walk on 4 balls and a strike-out on 3 strikes.
- At the end of every half-inning (3rd out) a modal pops up so the umpire enters the runs scored that half. The line score updates from those entries — runs are never auto-credited from walks or HBPs.
- Score, inning and half (▲/▼) shown on the main screen.
- Per-inning line score on its own paged screen.
- Game clock with two configurable thresholds:
  - **No new innings** (default 50 min). Current inning finishes, but no new one starts.
  - **Drop-dead / ball game** (default 60 min). Game ends immediately.

**On the iPhone (companion)**

- Edit defaults: sport, timer thresholds, **enforce-drop-dead** toggle, team names, rule variants (max balls / strikes / outs). Tap **Send to Watch** to push them.
- History of completed games — final score, line score, end reason, duration.

## Tournament rules implemented

| Trigger | Effect |
| --- | --- |
| Bottom of regulation (7 softball / 9 baseball) ends with a leader | Final. |
| Top of regulation+ ends with home leading | Final — home doesn't need to bat. |
| Tied at end of regulation | Extra innings until a team leads at end of an inning, **or** a timer fires. |
| "No new innings" timer fires **and home is leading** | Final right now. |
| "No new innings" timer fires past regulation | Game ends at next inning boundary (tie allowed). |
| "Drop-dead" timer fires (default) | Watch prompts the umpire — **End game** (revert to last lead, official rule) or **Play on** (override). Once overridden, the cutoff is ignored for the rest of the game. |
| "Drop-dead" timer fires with **Enforce drop-dead = off** | Treated as advisory only; play continues, no prompt. The Timer view shows "Drop-dead advisory". |
| Umpire taps **End Game** | Manual / called game. |

## Opening the project

1. Open `UmpireClicker.xcodeproj` in **Xcode 15 or later** (requires iOS 17 / watchOS 10 — needed for `@Observable`).
2. Select the **UmpireClicker** scheme.
3. In the iOS target's Signing & Capabilities, set your **Team**. Xcode will offer to fix the bundle ID if it clashes — accept and it will rename the watch target's bundle ID too.
4. Run on a paired iPhone + Apple Watch, or on the simulator pair.

Default bundle IDs:

- iOS: `com.umpireclicker.UmpireClicker`
- Watch: `com.umpireclicker.UmpireClicker.watchkitapp`

Change these to your own reverse-DNS in **Build Settings → Packaging → Product Bundle Identifier** on each target. Keep the watch bundle ID as `<iOS-id>.watchkitapp`.

## Project layout

```
UmpireClicker/
├── UmpireClicker.xcodeproj/
├── UmpireClicker/                       (iOS app target)
│   ├── UmpireClickerApp.swift
│   ├── ContentView.swift
│   ├── HistoryStore.swift
│   ├── Views/                           SettingsView, HistoryView, GameDetailView
│   ├── Connectivity/                    PhoneSessionManager
│   ├── Assets.xcassets/
│   └── Preview Content/
├── UmpireClicker Watch App/             (watchOS app target)
│   ├── UmpireClickerApp.swift
│   ├── ContentView.swift
│   ├── Views/                           IndicatorView, TimerView, LineScoreView,
│   │                                    SetupView, RunsEntryView, GameOverView
│   ├── Connectivity/                    WatchSessionManager
│   ├── Assets.xcassets/
│   └── Preview Content/
├── Shared/                              (compiled into both targets)
│   ├── Models/                          Sport, GameSettings, InningRuns,
│   │                                    GameRecord, GameState, GameTimer
│   └── Connectivity/                    SyncMessages
└── README.md
```

## Watch UX cheat sheet

| Page (swipe between) | Purpose |
| --- | --- |
| **Indicator** | B/S/O counters, score, inning, timer strip at the bottom showing the current phase ("No New" / "Ball Game" / "OT") and countdown. Tap a cell to increment; long-press to undo. The ⏸ icon pauses/resumes the game clock (injury, rain delay). The ⏭ icon ends the half-inning early (walk-off, mercy, etc.). |
| **Timer** | Big phase-based countdown — "No New: MM:SS" until the no-new threshold, then "Ball Game: MM:SS" until drop-dead, then "OT: +MM:SS" if drop-dead is overridden. Prominent Pause/Resume button for injury or weather delays. |
| **Line score** | Per-inning runs for both teams. |
| **Setup** | Sport, timer durations, start/restart/end game. |

## Customising

- **App icon** — drop a 1024×1024 PNG into `UmpireClicker/Assets.xcassets/AppIcon.appiconset/` (iOS) and the equivalent watch icon set, then add it to the existing `Contents.json` `images` entry.
- **Accent color** — tweak the RGB in the two `AccentColor.colorset/Contents.json` files.
- **Rule variants** — `GameSettings` exposes `maxBalls`, `maxStrikes`, `maxOuts` for slow-pitch and other variants (e.g. 1-1 starting count would require a `startingBallCount`/`startingStrikeCount` extension — easy to add to `GameState`).

## Known limitations

- WatchConnectivity is best-effort. Completed games sync to the phone via `transferUserInfo`, which queues even when the phone is asleep, but the watch decides when to deliver. Live in-game state is not pushed.
- Runs are only entered at the end of each half-inning. For a walk-off (or any early end of a half), use the ⏭ button on the indicator strip to force runs entry without reaching three outs.
- No app-icon images are bundled; the asset catalogs include only the `Contents.json` so the project compiles without warnings. Add real icons before shipping.
