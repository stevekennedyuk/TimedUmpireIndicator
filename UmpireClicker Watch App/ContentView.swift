//
//  ContentView.swift
//  UmpireClicker Watch App
//
//  Root view: paged TabView with Indicator / Timer / Line score / Setup.
//  Owns the GameState + GameTimer for the active game and pumps the
//  1-second tick that drives elapsed time + drop-dead detection.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    /// The last-used settings, persisted across games and app launches so the
    /// umpire doesn't have to reconfigure between games. Encoded as JSON in
    /// UserDefaults. Updated whenever a game is started and whenever the phone
    /// pushes new defaults.
    @AppStorage("watch_lastSettings") private var storedSettingsData: Data = Data()

    @State private var game: GameState = GameState(settings: .default)
    @State private var timer: GameTimer = GameTimer(
        noNewInningsMinutes: GameSettings.default.noNewInningsMinutes,
        ballGameCutoffMinutes: GameSettings.default.ballGameCutoffMinutes
    )
    @State private var selection: Int = 3   // start on Setup tab
    @State private var showRunsEntry = false
    @State private var showGameOver = false
    @State private var showDropDeadConfirm = false
    @State private var hasStarted = false
    @State private var noNewAlertFired = false
    @State private var cutoffAlertFired = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let sync = WatchSessionManager.shared

    /// Decode the persisted settings, falling back to defaults the first time.
    private var persistedSettings: GameSettings {
        (try? JSONDecoder().decode(GameSettings.self, from: storedSettingsData)) ?? .default
    }

    private func persist(_ settings: GameSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            storedSettingsData = data
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            IndicatorView(game: game, timer: timer)
                .tag(0)

            TimerView(timer: timer, game: game)
                .tag(1)

            if game.settings.keepScore {
                LineScoreView(game: game)
                    .tag(2)
            }

            SetupView(
                hasStarted: hasStarted,
                gameIsComplete: game.isComplete,
                settings: persistedSettings,
                onStart: startGame,
                onEndManually: endGameManually,
                onResetTimer: { timer.reset() }
            )
            .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            // Seed the first game from the last-used settings so the Setup
            // screen and any quick-start reflect prior choices (including the
            // tie rule) rather than hard defaults.
            if !hasStarted {
                game.settings = persistedSettings
            }
        }
        .onChange(of: sync.lastReceivedSettings) { _, newValue in
            // When the phone pushes new defaults, persist them so they carry
            // forward, and apply to the idle game so Setup reflects them.
            guard let newValue else { return }
            persist(newValue)
            if !hasStarted || game.isComplete {
                game.settings = newValue
            }
        }
        .onReceive(tick) { _ in
            timer.tick()
            guard hasStarted && !game.isComplete else { return }

            // Haptic alerts: fire exactly once as each threshold is crossed.
            // No-new gets the attention pattern; drop-dead (when enforced)
            // gets the harder failure pattern so the two are distinguishable
            // by feel alone.
            if !noNewAlertFired && timer.isNoNewInningsTriggered {
                noNewAlertFired = true
                WKInterfaceDevice.current().play(.notification)
            }
            if !cutoffAlertFired && timer.isCutoffTriggered {
                cutoffAlertFired = true
                WKInterfaceDevice.current().play(.failure)
            }

            guard !game.pendingRunsEntry else { return }

            // Inactivity auto-close: once the game is in the cut-off / overtime
            // phase, end it after the configured idle period with no umpire
            // interaction, then tear down and return to Setup.
            if game.settings.autoCloseOnInactivity
                && timer.isNoNewInningsTriggered
                && game.secondsSinceActivity() >= TimeInterval(game.settings.inactivityTimeoutMinutes * 60)
            {
                game.endForInactivity()
                return
            }

            if timer.isCutoffTriggered
                && !game.dropDeadOverridden
                && game.settings.enforceDropDead
            {
                if !showDropDeadConfirm {
                    showDropDeadConfirm = true
                }
                return   // wait for the umpire's decision
            }
            if game.settings.keepScore
                && timer.isNoNewInningsTriggered
                && game.leader == .home
            {
                game.endForNoNewInningsHomeLeads()
            }
        }
        .onChange(of: game.pendingRunsEntry) { _, isPending in
            if isPending { showRunsEntry = true }
        }
        .onChange(of: game.isComplete) { _, ended in
            if ended {
                timer.pause()
                showRunsEntry = false
                if game.settings.keepScore {
                    let record = game.buildRecord(durationSeconds: timer.elapsed)
                    sync.sendGameRecord(record)
                }
                if game.endReason == .inactivity {
                    // Idle auto-close: don't hold a game-over sheet open with
                    // nobody watching. Record (above), then tear the session
                    // down and return to Setup so watchOS can suspend us.
                    teardownToIdle()
                } else {
                    showGameOver = true
                }
            }
        }
        .sheet(isPresented: $showRunsEntry) {
            RunsEntryView(
                inning: game.inning,
                half: game.half,
                teamBatting: teamBatting
            ) { runs in
                game.confirmRunsForCompletedHalf(
                    runs,
                    noNewInningsTriggered: timer.isNoNewInningsTriggered,
                    cutoffTriggered: timer.isCutoffTriggered
                )
                showRunsEntry = false
            }
        }
        .sheet(isPresented: $showGameOver) {
            GameOverView(
                awayName: game.settings.awayTeamName,
                homeName: game.settings.homeTeamName,
                awayScore: game.awayScore,
                homeScore: game.homeScore,
                reason: game.endReason ?? .manual,
                lineScore: game.lineScore,
                elapsed: timer.elapsed,
                keepScore: game.settings.keepScore
            ) {
                showGameOver = false
                // The game is over and acknowledged — tear down to idle so the
                // next game starts clean (fresh state, Away/Home names).
                teardownToIdle()
            }
        }
        .confirmationDialog(
            dropDeadTitle,
            isPresented: $showDropDeadConfirm,
            titleVisibility: .visible
        ) {
            if !game.settings.keepScore {
                // Indicator-only: simple end / play on.
                Button("End game", role: .destructive) {
                    game.endAtDropDead()
                }
            } else if game.homeWinsOnCutoff {
                // Home batting and ahead — score stands.
                Button("End — \(game.settings.homeTeamName) win", role: .destructive) {
                    game.endAtDropDead()
                }
            } else {
                // Revert needed. Offer the configured rule as primary, and the
                // opposite tie preference as an alternative.
                let preferred = game.dropDeadPreview(allowTies: game.settings.allowTies)
                Button(dropDeadResultLabel(preferred, prefix: "End"), role: .destructive) {
                    game.endAtDropDead(allowTiesOverride: game.settings.allowTies)
                }
                // Alternative: flip the tie rule, but only if it yields a
                // different result.
                let alt = game.dropDeadPreview(allowTies: !game.settings.allowTies)
                if alt.away != preferred.away || alt.home != preferred.home {
                    let altLabel = game.settings.allowTies
                        ? dropDeadResultLabel(alt, prefix: "No tie —")
                        : dropDeadResultLabel(alt, prefix: "Allow tie —")
                    Button(altLabel) {
                        game.endAtDropDead(allowTiesOverride: !game.settings.allowTies)
                    }
                }
            }
            Button("Play on") {
                game.registerActivity()
                game.dropDeadOverridden = true
            }
        } message: {
            Text(dropDeadMessage)
        }
    }

    // MARK: - Drop-dead dialog text

    private var dropDeadTitle: String {
        "Cut-off reached"
    }

    private var dropDeadMessage: String {
        let elapsed = GameTimer.format(timer.elapsed)
        guard game.settings.keepScore else {
            return "\(elapsed) elapsed. End the game or keep playing?"
        }
        if game.homeWinsOnCutoff {
            return "\(elapsed) elapsed. \(game.settings.homeTeamName) lead while batting — the score stands."
        }
        return "\(elapsed) elapsed. The current inning is incomplete, so the score reverts to the last completed inning."
    }

    private func dropDeadResultLabel(
        _ preview: (away: Int, home: Int, inning: Int?, tied: Bool),
        prefix: String
    ) -> String {
        let a = game.settings.awayTeamName
        let h = game.settings.homeTeamName
        let score = "\(a) \(preview.away)\u{2013}\(preview.home) \(h)"
        if let inn = preview.inning {
            return "\(prefix) \(score) (end \(inn))"
        }
        return "\(prefix) \(score)"
    }

    private var teamBatting: String {
        game.half == .top ? game.settings.awayTeamName : game.settings.homeTeamName
    }

    // MARK: - Actions

    private func startGame(settings: GameSettings) {
        // Persist the rules so they carry forward to the next game and survive
        // relaunch — but team names are per-game, so reset them to Away/Home
        // each time. The umpire can still type new names in Setup beforehand.
        var carried = settings
        carried.awayTeamName = "Away"
        carried.homeTeamName = "Home"
        persist(carried)

        game = GameState(settings: settings)
        timer = GameTimer(
            noNewInningsMinutes: settings.noNewInningsMinutes,
            ballGameCutoffMinutes: settings.ballGameCutoffMinutes
        )
        timer.start()
        hasStarted = true
        noNewAlertFired = false
        cutoffAlertFired = false
        selection = 0
    }

    /// Tear the active game down to an idle state: stop the clock, release the
    /// game/timer objects, close any sheets, and return to the Setup tab so
    /// watchOS can suspend and reclaim the app. The persisted settings are
    /// kept so the next game starts from the same configuration.
    private func teardownToIdle() {
        timer.reset()
        showRunsEntry = false
        showGameOver = false
        showDropDeadConfirm = false
        hasStarted = false
        noNewAlertFired = false
        cutoffAlertFired = false
        let fresh = persistedSettings
        game = GameState(settings: fresh)
        timer = GameTimer(
            noNewInningsMinutes: fresh.noNewInningsMinutes,
            ballGameCutoffMinutes: fresh.ballGameCutoffMinutes
        )
        selection = 3   // back to Setup
    }

    private func endGameManually() {
        game.endManually()
    }
}

#Preview {
    ContentView()
}
