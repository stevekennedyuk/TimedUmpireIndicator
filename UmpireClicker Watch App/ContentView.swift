//
//  ContentView.swift
//  UmpireClicker Watch App
//
//  Root view: paged TabView with Indicator / Timer / Line score / Setup.
//  Owns the GameState + GameTimer for the active game and pumps the
//  1-second tick that drives elapsed time + drop-dead detection.
//

import SwiftUI

struct ContentView: View {
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

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let sync = WatchSessionManager.shared

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
                settings: game.settings,
                onStart: startGame,
                onEndManually: endGameManually,
                onResetTimer: { timer.reset() }
            )
            .tag(3)
        }
        .tabViewStyle(.page)
        .onReceive(tick) { _ in
            timer.tick()
            guard hasStarted && !game.isComplete && !game.pendingRunsEntry else { return }
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
                showGameOver = true
                if game.settings.keepScore {
                    let record = game.buildRecord(durationSeconds: timer.elapsed)
                    sync.sendGameRecord(record)
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
            }
        }
        .confirmationDialog(
            "Drop-dead time",
            isPresented: $showDropDeadConfirm,
            titleVisibility: .visible
        ) {
            Button("End game", role: .destructive) {
                game.endAtDropDead()
            }
            Button("Play on") {
                game.dropDeadOverridden = true
            }
        } message: {
            if game.settings.keepScore {
                Text("\(GameTimer.format(timer.elapsed)) elapsed. End now (revert to last lead) or keep playing?")
            } else {
                Text("\(GameTimer.format(timer.elapsed)) elapsed. End the game or keep playing?")
            }
        }
    }

    private var teamBatting: String {
        game.half == .top ? game.settings.awayTeamName : game.settings.homeTeamName
    }

    // MARK: - Actions

    private func startGame(settings: GameSettings) {
        game = GameState(settings: settings)
        timer = GameTimer(
            noNewInningsMinutes: settings.noNewInningsMinutes,
            ballGameCutoffMinutes: settings.ballGameCutoffMinutes
        )
        timer.start()
        hasStarted = true
        selection = 0
    }

    private func endGameManually() {
        game.endManually()
    }
}

#Preview {
    ContentView()
}
