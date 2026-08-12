//
//  GameView.swift
//  UmpireClicker (iOS)
//
//  The full umpire experience on iPhone / iPad: a single scrollable screen
//  with the scoreboard, big balls/strikes/outs tap targets, the game clock,
//  and end-of-game controls — driving the same shared GameState / GameTimer
//  engine as the watch app. Team names are fixed Away / Home.
//

import SwiftUI

struct GameView: View {
    @Environment(HistoryStore.self) private var history
    @AppStorage("ios_lastSettings") private var storedSettingsData: Data = Data()

    @State private var game = GameState(settings: .default)
    @State private var timer = GameTimer()
    @State private var hasStarted = false
    @State private var showSetup = false
    @State private var showRunsEntry = false
    @State private var showGameOver = false
    @State private var showDropDead = false
    @State private var showEndConfirm = false
    @State private var showRegulationEnd = false
    @State private var noNewAlertFired = false
    @State private var cutoffAlertFired = false

    @State private var thresholdFlash: ThresholdFlashKind?

    /// Persistent haptic generator. Creating a temporary generator and firing
    /// it immediately can drop the haptic (the generator may be deallocated
    /// before playback), so we hold one for the life of the view.
    @State private var haptics = UINotificationFeedbackGenerator()

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var persistedSettings: GameSettings {
        (try? JSONDecoder().decode(GameSettings.self, from: storedSettingsData)) ?? .default
    }

    private func persist(_ s: GameSettings) {
        if let data = try? JSONEncoder().encode(s) { storedSettingsData = data }
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasStarted {
                    activeGame
                } else {
                    idleStart
                }
            }
            .navigationTitle("Umpire")
            .toolbar {
                if hasStarted {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            game.undoLast()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!game.canUndo)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("End", role: .destructive) { showEndConfirm = true }
                    }
                }
            }
        }
        .overlay {
            if let kind = thresholdFlash {
                ThresholdFlashView(kind: kind) {
                    thresholdFlash = nil
                }
            }
        }
        .onReceive(tick) { _ in
            timer.tick()
            guard hasStarted, !game.isComplete else { return }
            // Untimed game: no thresholds, alerts, cutoff or idle-close.
            guard game.settings.useTimers else { return }

            // Threshold alerts: repeated haptic burst plus a full-screen
            // colour flash — a single tap is easy to miss on the field.
            // (Haptics need a real iPhone; Simulator and iPad have no Taptic
            // Engine — the flash still shows there.)
            if !noNewAlertFired && timer.isNoNewInningsTriggered {
                noNewAlertFired = true
                thresholdFlash = .noNew
                playHapticBurst(.warning, times: 3)
            }
            if !cutoffAlertFired && timer.isCutoffTriggered {
                cutoffAlertFired = true
                thresholdFlash = .cutoff
                playHapticBurst(.error, times: 4)
                // Umpire is looking at the app — skip the redundant follow-up ping.
                TimerAlerts.cancelCutoffFollowUp()
            }

            guard !game.pendingRunsEntry else { return }
            if game.settings.autoCloseOnInactivity
                && timer.isNoNewInningsTriggered
                && game.secondsSinceActivity() >= TimeInterval(game.settings.inactivityTimeoutMinutes * 60) {
                game.endForInactivity(); return
            }
            if timer.isCutoffTriggered && !game.dropDeadOverridden && game.settings.enforceDropDead {
                if !showDropDead { showDropDead = true }
                return
            }
            if game.settings.keepScore && timer.isNoNewInningsTriggered && game.leader == .home {
                game.endForNoNewInningsHomeLeads()
            }
        }
        .onChange(of: game.pendingRunsEntry) { _, pending in
            if pending {
                showRunsEntry = true
            } else {
                // Cleared without confirmation (e.g. undo) — close the sheet.
                showRunsEntry = false
            }
        }
        .onChange(of: game.pendingRegulationEnd) { _, pending in
            if pending {
                showRegulationEnd = true
            } else {
                showRegulationEnd = false
            }
        }
        .onChange(of: timer.isPaused) { _, paused in
            guard hasStarted && !game.isComplete && game.settings.useTimers else { return }
            if paused {
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
            guard ended else { return }
            timer.pause()
            TimerAlerts.cancelAll()
            showRunsEntry = false
            if game.settings.keepScore {
                history.add(game.buildRecord(durationSeconds: timer.elapsed))
            }
            if game.endReason == .inactivity {
                teardownToIdle()
            } else {
                showGameOver = true
            }
        }
        .sheet(isPresented: $showSetup) {
            GameSetupSheet(settings: persistedSettings) { s in
                showSetup = false
                startGame(with: s)
            } onCancel: {
                showSetup = false
            }
        }
        .sheet(isPresented: $showRunsEntry) {
            RunsEntrySheet(
                inning: game.inning,
                half: game.half,
                teamBatting: game.half == .top ? "Away" : "Home"
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
            GameOverSheet(game: game, elapsed: timer.elapsed) {
                showGameOver = false
                teardownToIdle()
            }
        }
        .confirmationDialog("End of regulation", isPresented: $showRegulationEnd, titleVisibility: .visible) {
            Button("End game", role: .destructive) { game.confirmRegulationEnd() }
            Button("Extra innings") { game.continueToExtraInnings() }
        } message: {
            Text("\(game.settings.sport.regulationInnings) innings complete. End the game, or play extra innings if it's tied?")
        }
        .confirmationDialog("End the game?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End game", role: .destructive) { game.endManually() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(dropDeadTitle, isPresented: $showDropDead, titleVisibility: .visible) {
            dropDeadButtons
            Button("Play on") {
                game.registerActivity()
                game.dropDeadOverridden = true
                TimerAlerts.cancelCutoffFollowUp()
            }
        } message: {
            Text(dropDeadMessage)
        }
    }

    // MARK: - Idle / start

    private var idleStart: some View {
        VStack(spacing: 24) {
            Image(systemName: "baseball")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Ready to umpire")
                .font(.title2.bold())
            Text("Start a game to track balls, strikes, outs, innings and the tournament clock.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showSetup = true
            } label: {
                Label("Start game", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Active game (single scrollable screen)

    private var activeGame: some View {
        ScrollView {
            VStack(spacing: 16) {
                if game.settings.keepScore {
                    scoreboard
                } else {
                    inningOnly
                }
                countRow
                clockCard
                if game.settings.keepScore && !game.lineScore.isEmpty {
                    liveLineScore
                }
                if game.settings.keepScore {
                    Button {
                        game.forceEndOfHalf()
                    } label: {
                        Label("End half-inning", systemImage: "forward.end.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: 700)          // keeps iPad from stretching edge-to-edge
            .frame(maxWidth: .infinity)    // …while staying centred
            .padding()
        }
    }

    /// Live line score during the game — mirrors the watch's Line Score page.
    private var liveLineScore: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Line score")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        ForEach(game.lineScore.map(\.inning), id: \.self) {
                            Text("\($0)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text("R").font(.caption.weight(.bold)).foregroundStyle(.orange)
                    }
                    GridRow {
                        Text("Away").font(.callout.weight(.semibold))
                        ForEach(game.lineScore) { entry in
                            Text(entry.top.map(String.init) ?? "–")
                                .font(.callout).monospacedDigit()
                                .foregroundStyle((entry.top ?? 0) > 0 ? .primary : .secondary)
                        }
                        Text("\(game.awayScore)").font(.callout.weight(.bold)).monospacedDigit()
                    }
                    GridRow {
                        Text("Home").font(.callout.weight(.semibold))
                        ForEach(game.lineScore) { entry in
                            Text(entry.bottom.map(String.init) ?? "–")
                                .font(.callout).monospacedDigit()
                                .foregroundStyle((entry.bottom ?? 0) > 0 ? .primary : .secondary)
                        }
                        Text("\(game.homeScore)").font(.callout.weight(.bold)).monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scoreboard: some View {
        HStack(spacing: 12) {
            teamScore(name: "Away", score: game.awayScore, batting: game.half == .top)
            VStack(spacing: 2) {
                Text(game.half == .top ? "▲" : "▼")
                    .font(.title3)
                    .foregroundStyle(game.half == .top ? .green : .blue)
                Text("Inning \(game.inning)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            teamScore(name: "Home", score: game.homeScore, batting: game.half == .bottom)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func teamScore(name: String, score: Int, batting: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(batting ? .primary : .secondary)
            Text("\(score)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
            if batting {
                Text("AT BAT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inningOnly: some View {
        VStack(spacing: 2) {
            Text(game.half == .top ? "▲ Top" : "▼ Bottom")
                .font(.headline)
            Text("Inning \(game.inning)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var countRow: some View {
        HStack(spacing: 12) {
            BigCountCell(label: "BALLS", value: game.balls,
                         pips: max(1, game.settings.maxBalls - 1), color: .green,
                         increment: { game.incrementBall() },
                         decrement: { game.decrementBall() })
            BigCountCell(label: "STRIKES", value: game.strikes,
                         pips: max(1, game.settings.maxStrikes - 1), color: .yellow,
                         increment: { game.incrementStrike() },
                         decrement: { game.decrementStrike() })
            BigCountCell(label: "OUTS", value: game.outs,
                         pips: max(1, game.settings.maxOuts - 1), color: .red,
                         increment: { game.incrementOut() },
                         decrement: { game.decrementOut() })
        }
    }

    private var clockCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: game.settings.useTimers ? clockIcon : "clock")
                    .foregroundStyle(effectiveClockColor)
                Text(clockLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(timer.isPaused ? .yellow : effectiveClockColor)
                Spacer()
                Text(game.settings.useTimers ? timer.activeCountdownText : GameTimer.format(timer.elapsed))
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .foregroundStyle(timer.isPaused ? .yellow : effectiveClockColor)
            }
            HStack {
                if game.settings.useTimers {
                    Text("Elapsed \(GameTimer.format(timer.elapsed))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if timer.isPaused { timer.resume() } else { timer.pause() }
                } label: {
                    Label(timer.isPaused ? "Resume" : "Pause",
                          systemImage: timer.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(timer.startedAt == nil)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var clockLabel: String {
        if timer.isPaused { return "Paused" }
        return game.settings.useTimers ? timer.phase.rawValue : "Elapsed"
    }

    private var effectiveClockColor: Color {
        game.settings.useTimers ? clockColor : .secondary
    }

    private var clockIcon: String {
        switch timer.phase {
        case .noNew: return "timer"
        case .ballGame: return "exclamationmark.triangle.fill"
        case .overtime: return "stop.circle.fill"
        }
    }

    private var clockColor: Color {
        switch timer.phase {
        case .noNew: return .secondary
        case .ballGame: return .orange
        case .overtime: return .red
        }
    }

    // MARK: - Drop-dead dialog

    private var dropDeadTitle: String { "Cut-off reached" }

    private var dropDeadMessage: String {
        let elapsed = GameTimer.format(timer.elapsed)
        guard game.settings.keepScore else {
            return "\(elapsed) elapsed. End the game or keep playing?"
        }
        if game.homeWinsOnCutoff {
            return "\(elapsed) elapsed. Home lead while batting — the score stands."
        }
        return "\(elapsed) elapsed. The current inning is incomplete, so the score reverts to the last completed inning."
    }

    @ViewBuilder
    private var dropDeadButtons: some View {
        if !game.settings.keepScore {
            Button("End game", role: .destructive) { game.endAtDropDead() }
        } else if game.homeWinsOnCutoff {
            Button("End — Home win", role: .destructive) { game.endAtDropDead() }
        } else {
            let preferred = game.dropDeadPreview(allowTies: game.settings.allowTies)
            Button(label(preferred, "End"), role: .destructive) {
                game.endAtDropDead(allowTiesOverride: game.settings.allowTies)
            }
            let alt = game.dropDeadPreview(allowTies: !game.settings.allowTies)
            if alt.away != preferred.away || alt.home != preferred.home {
                Button(label(alt, game.settings.allowTies ? "No tie —" : "Allow tie —")) {
                    game.endAtDropDead(allowTiesOverride: !game.settings.allowTies)
                }
            }
        }
    }

    private func label(_ p: (away: Int, home: Int, inning: Int?, tied: Bool), _ prefix: String) -> String {
        let score = "Away \(p.away)–\(p.home) Home"
        if let inn = p.inning { return "\(prefix) \(score) (end \(inn))" }
        return "\(prefix) \(score)"
    }

    // MARK: - Lifecycle

    /// Play the haptic several times in quick succession — a burst is far
    /// harder to miss than a single tap.
    private func playHapticBurst(_ kind: UINotificationFeedbackGenerator.FeedbackType, times: Int) {
        haptics.prepare()
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.45) {
                haptics.notificationOccurred(kind)
            }
        }
    }

    private func startGame(with settings: GameSettings) {
        var carried = settings
        carried.awayTeamName = "Away"
        carried.homeTeamName = "Home"
        persist(carried)
        game = GameState(settings: carried)
        timer = GameTimer(
            noNewInningsMinutes: carried.noNewInningsMinutes,
            ballGameCutoffMinutes: carried.ballGameCutoffMinutes
        )
        timer.start()
        hasStarted = true
        noNewAlertFired = false
        cutoffAlertFired = false
        // Background-safe threshold alerts — delivered by the system with a
        // vibration even if the phone is locked or the app backgrounded.
        // Untimed games have no thresholds to alert on.
        if carried.useTimers {
            TimerAlerts.requestAuthorization()
            TimerAlerts.schedule(
                noNewIn: TimeInterval(carried.noNewInningsMinutes * 60),
                cutoffIn: TimeInterval(carried.ballGameCutoffMinutes * 60)
            )
        }
        // Keep the phone awake while a game is live — an umpire glances at
        // the screen constantly and must never watch it sleep mid-count.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func teardownToIdle() {
        timer.reset()
        TimerAlerts.cancelAll()
        showRunsEntry = false
        showGameOver = false
        showDropDead = false
        showRegulationEnd = false
        hasStarted = false
        noNewAlertFired = false
        cutoffAlertFired = false
        thresholdFlash = nil
        // Re-enable normal auto-lock now that no game is running.
        UIApplication.shared.isIdleTimerDisabled = false
        let fresh = persistedSettings
        game = GameState(settings: fresh)
        timer = GameTimer(
            noNewInningsMinutes: fresh.noNewInningsMinutes,
            ballGameCutoffMinutes: fresh.ballGameCutoffMinutes
        )
    }
}

// MARK: - Big tap target for iOS

struct BigCountCell: View {
    let label: String
    let value: Int
    let pips: Int
    let color: Color
    let increment: () -> Void
    let decrement: () -> Void

    /// Per-tap click feedback, matching the watch's tap haptics. Persistent so
    /// the haptic isn't dropped by early deallocation.
    @State private var tapHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 4) {
                ForEach(0..<pips, id: \.self) { i in
                    Circle()
                        .fill(i < value ? color : color.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            tapHaptic.prepare()
            tapHaptic.impactOccurred()
            increment()
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            tapHaptic.prepare()
            tapHaptic.impactOccurred(intensity: 0.6)
            decrement()
        }
        .accessibilityElement()
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint("Tap to add, long-press to subtract")
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
            VStack(spacing: 10) {
                Image(systemName: kind == .cutoff ? "stop.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 72, weight: .black))
                Text(kind == .cutoff ? "TIME!" : "NO NEW")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                Text(kind == .cutoff ? "BALL GAME" : "INNINGS")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                Text("Tap to dismiss")
                    .font(.callout)
                    .opacity(0.85)
                    .padding(.top, 12)
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
    GameView()
        .environment(HistoryStore.preview)
}
