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
    @State private var showRegulationEnd = false
    @State private var hasStarted = false
    @State private var noNewAlertFired = false
    @State private var cutoffAlertFired = false
    @State private var thresholdFlash: ThresholdFlashKind?

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
        .overlay {
            if let kind = thresholdFlash {
                ThresholdFlashView(kind: kind) {
                    thresholdFlash = nil
                }
            }
        }
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

            // Threshold alerts: an unmissable repeated haptic burst plus a
            // full-screen colour flash. No-new = triple notification tap on
            // amber; drop-dead = quadruple failure buzz on red.
            if !noNewAlertFired && timer.isNoNewInningsTriggered {
                noNewAlertFired = true
                thresholdFlash = .noNew
                playHapticBurst(.notification, times: 3)
            }
            if !cutoffAlertFired && timer.isCutoffTriggered {
                cutoffAlertFired = true
                thresholdFlash = .cutoff
                playHapticBurst(.failure, times: 4)
                // Umpire is looking at the app — the scheduled follow-up ping
                // would be redundant noise.
                TimerAlerts.cancelCutoffFollowUp()
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
            if isPending {
                showRunsEntry = true
            } else {
                // Cleared without confirmation (e.g. undo) — close the sheet.
                showRunsEntry = false
            }
        }
        .onChange(of: game.pendingRegulationEnd) { _, isPending in
            if isPending {
                showRegulationEnd = true
            } else {
                showRegulationEnd = false
            }
        }
        .onChange(of: timer.isPaused) { _, paused in
            guard hasStarted && !game.isComplete else { return }
            if paused {
                // Wall-clock notifications would fire at the wrong moment
                // while the game clock is stopped.
                TimerAlerts.cancelAll()
            } else {
                TimerAlerts.schedule(
                    noNewIn: timer.isNoNewInningsTriggered
                        ? nil
                        : TimeInterval(game.settings.noNewInningsMinutes * 60) - timer.elapsed,
                    cutoffIn: timer.isCutoffTriggered
                        ? nil
                        : TimeInterval(game.settings.ballGameCutoffMinutes * 60) - timer.elapsed
                )
            }
        }
        .onChange(of: game.isComplete) { _, ended in
            if ended {
                timer.pause()
                TimerAlerts.cancelAll()
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
            "End of regulation",
            isPresented: $showRegulationEnd,
            titleVisibility: .visible
        ) {
            Button("End game", role: .destructive) {
                game.confirmRegulationEnd()
            }
            Button("Extra innings") {
                game.continueToExtraInnings()
            }
        } message: {
            Text("\(game.settings.sport.regulationInnings) innings complete. End the game, or play extra innings if it's tied?")
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
                TimerAlerts.cancelCutoffFollowUp()
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

    /// Play a haptic several times in quick succession — a single tap is easy
    /// to miss on the field, a burst is not.
    private func playHapticBurst(_ kind: WKHapticType, times: Int) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                WKInterfaceDevice.current().play(kind)
            }
        }
    }

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
        // Background-safe threshold alerts: the system delivers these with a
        // wrist tap even when the watch has returned to the clock face.
        TimerAlerts.requestAuthorization()
        TimerAlerts.schedule(
            noNewIn: TimeInterval(settings.noNewInningsMinutes * 60),
            cutoffIn: TimeInterval(settings.ballGameCutoffMinutes * 60)
        )
    }

    /// Tear the active game down to an idle state: stop the clock, release the
    /// game/timer objects, close any sheets, and return to the Setup tab so
    /// watchOS can suspend and reclaim the app. The persisted settings are
    /// kept so the next game starts from the same configuration.
    private func teardownToIdle() {
        timer.reset()
        TimerAlerts.cancelAll()
        showRunsEntry = false
        showGameOver = false
        showDropDeadConfirm = false
        showRegulationEnd = false
        hasStarted = false
        noNewAlertFired = false
        cutoffAlertFired = false
        thresholdFlash = nil
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

// MARK: - Threshold flash

/// Which tournament-timer threshold just fired.
enum ThresholdFlashKind {
    case noNew
    case cutoff
}

/// Full-screen pulsing colour flash shown the moment a timer threshold is
/// crossed — impossible to miss even in bright sunlight. Tap to dismiss, or
/// it clears itself after a few seconds.
struct ThresholdFlashView: View {
    let kind: ThresholdFlashKind
    let dismiss: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            (kind == .cutoff ? Color.red : Color.orange)
                .opacity(pulse ? 0.95 : 0.55)
                .ignoresSafeArea()
            VStack(spacing: 4) {
                Image(systemName: kind == .cutoff ? "stop.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .black))
                Text(kind == .cutoff ? "TIME!" : "NO NEW")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                Text(kind == .cutoff ? "BALL GAME" : "INNINGS")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                Text("Tap to dismiss")
                    .font(.system(size: 10))
                    .opacity(0.85)
                    .padding(.top, 4)
            }
            .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                dismiss()
            }
        }
    }
}

#Preview {
    ContentView()
}
