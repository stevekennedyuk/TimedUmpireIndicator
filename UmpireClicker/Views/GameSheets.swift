//
//  GameSheets.swift
//  UmpireClicker (iOS)
//
//  Modal sheets used by the iOS GameView: pre-game setup, runs entry at the
//  end of a half, and the game-over summary. Team names are fixed Away / Home,
//  so there are no name fields here.
//

import SwiftUI

// MARK: - Setup

struct GameSetupSheet: View {
    let settings: GameSettings
    let onStart: (GameSettings) -> Void
    let onCancel: () -> Void

    @State private var sport: Sport = .softball
    @State private var noNew = 55
    @State private var cutoff = 60
    @State private var enforceDropDead = true
    @State private var keepScore = true
    @State private var allowTies = true
    @State private var autoClose = true
    @State private var idleTimeout = 20
    @State private var useTimers = true
    @State private var runAhead = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Sport") {
                    Picker("Sport", selection: $sport) {
                        ForEach(Sport.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Mode") {
                    Toggle("Keep score", isOn: $keepScore)
                    if keepScore {
                        Toggle("Allow ties (round-robin)", isOn: $allowTies)
                        Toggle(isOn: $runAhead) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Run-ahead rule")
                                Text("\(settings.runAheadEarlyMargin)+ ahead from inning \(settings.runAheadEarlyInning) · \(settings.runAheadLateMargin)+ from inning \(settings.runAheadLateInning)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Toggle(isOn: $useTimers) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use timers")
                            Text(useTimers ? "Tournament clock rules apply" : "Untimed — ends by innings, run-ahead or umpire")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if useTimers {
                    Section("Tournament timers") {
                        Stepper("No new innings: \(noNew) min", value: $noNew, in: 10...180, step: 5)
                        Stepper("Drop-dead: \(cutoff) min", value: $cutoff, in: 10...240, step: 5)
                        Toggle("Enforce drop-dead", isOn: $enforceDropDead)
                        if cutoff <= noNew {
                            Text("Drop-dead must be greater than the No-new-innings time.")
                                .font(.footnote).foregroundStyle(.red)
                        }
                    }
                    Section("Auto-close") {
                        Toggle("Auto-close when idle", isOn: $autoClose)
                        if autoClose {
                            Stepper("Idle limit: \(idleTimeout) min", value: $idleTimeout, in: 5...60, step: 5)
                        }
                    }
                }
            }
            .navigationTitle("New game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        var s = settings
                        s.sport = sport
                        s.noNewInningsMinutes = noNew
                        s.ballGameCutoffMinutes = cutoff
                        s.enforceDropDead = enforceDropDead
                        s.keepScore = keepScore
                        s.allowTies = allowTies
                        s.autoCloseOnInactivity = autoClose
                        s.inactivityTimeoutMinutes = idleTimeout
                        s.useTimers = useTimers
                        s.runAheadEnabled = runAhead
                        s.awayTeamName = "Away"
                        s.homeTeamName = "Home"
                        onStart(s)
                    }
                    .disabled(useTimers && cutoff <= noNew)
                }
            }
            .onAppear {
                sport = settings.sport
                noNew = settings.noNewInningsMinutes
                cutoff = settings.ballGameCutoffMinutes
                enforceDropDead = settings.enforceDropDead
                keepScore = settings.keepScore
                allowTies = settings.allowTies
                autoClose = settings.autoCloseOnInactivity
                idleTimeout = settings.inactivityTimeoutMinutes
                useTimers = settings.useTimers
                runAhead = settings.runAheadEnabled
            }
        }
    }
}

// MARK: - Runs entry

struct RunsEntrySheet: View {
    let inning: Int
    let half: Half
    let teamBatting: String
    let onConfirm: (Int) -> Void

    @State private var runs = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("\(teamBatting) — \(half == .top ? "Top" : "Bottom") \(inning)")
                    .font(.headline)
                Text("Runs scored this half-inning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 32) {
                    Button { if runs > 0 { runs -= 1 } } label: {
                        Image(systemName: "minus.circle.fill").font(.system(size: 44))
                    }
                    .disabled(runs == 0)
                    Text("\(runs)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 100)
                    Button { runs += 1 } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 44))
                    }
                }
                Button {
                    onConfirm(runs)
                } label: {
                    Text("Confirm").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Runs")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }
}

// MARK: - Game over

struct GameOverSheet: View {
    let game: GameState
    let elapsed: TimeInterval
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(game.endReason?.displayName.uppercased() ?? "FINAL")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(reasonColor)
                    if game.settings.keepScore {
                        HStack(spacing: 16) {
                            finalScore("Away", game.awayScore, win: game.awayScore > game.homeScore)
                            Text("–").font(.title)
                            finalScore("Home", game.homeScore, win: game.homeScore > game.awayScore)
                        }
                        Text(headline).font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text("Game ended").font(.title3)
                    }
                    Text("Game time: \(GameTimer.format(elapsed))")
                        .font(.footnote).foregroundStyle(.secondary)
                    if game.settings.keepScore, !game.lineScore.isEmpty {
                        Divider()
                        lineScoreGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Game over")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
            .interactiveDismissDisabled()
        }
    }

    private func finalScore(_ name: String, _ score: Int, win: Bool) -> some View {
        VStack {
            Text(name).font(.subheadline).foregroundStyle(win ? .primary : .secondary)
            Text("\(score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(win ? .primary : .secondary)
        }
    }

    private var headline: String {
        if game.awayScore == game.homeScore { return "Tie game" }
        let winner = game.awayScore > game.homeScore ? "Away" : "Home"
        return "\(winner) win"
    }

    private var reasonColor: Color {
        switch game.endReason {
        case .ballGameCutoff:        return .red
        case .noNewInningsHomeAhead: return .orange
        case .regulationComplete:    return .green
        case .inactivity:            return .purple
        case .runAhead:              return .blue
        case .manual, .none:         return .gray
        }
    }

    private var lineScoreGrid: some View {
        let innings = game.lineScore.map(\.inning)
        return Grid(horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                ForEach(innings, id: \.self) { Text("\($0)").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                Text("R").font(.caption.weight(.bold)).foregroundStyle(.orange)
            }
            GridRow {
                Text("Away").font(.callout.weight(.semibold))
                ForEach(game.lineScore) { Text("\($0.top ?? 0)").font(.callout).monospacedDigit() }
                Text("\(game.awayScore)").font(.callout.weight(.bold)).monospacedDigit()
            }
            GridRow {
                Text("Home").font(.callout.weight(.semibold))
                ForEach(game.lineScore) { Text("\($0.bottom ?? 0)").font(.callout).monospacedDigit() }
                Text("\(game.homeScore)").font(.callout.weight(.bold)).monospacedDigit()
            }
        }
    }
}
