//
//  SettingsView.swift
//  UmpireClicker (iOS companion)
//
//  Edit the default settings + push them to the watch on save.
//

import SwiftUI

struct SettingsView: View {
    @Environment(PhoneSessionManager.self) private var session

    @AppStorage("settings_sport")        private var sportRaw: String = Sport.softball.rawValue
    @AppStorage("settings_noNew")        private var noNew: Int = 50
    @AppStorage("settings_cutoff")       private var cutoff: Int = 60
    @AppStorage("settings_enforceDD")    private var enforceDropDead: Bool = true
    @AppStorage("settings_keepScore")    private var keepScore: Bool = true
    @AppStorage("settings_allowTies")    private var allowTies: Bool = true
    @AppStorage("settings_autoClose")    private var autoClose: Bool = true
    @AppStorage("settings_idleTimeout")  private var idleTimeout: Int = 20
    @AppStorage("settings_maxBalls")     private var maxBalls: Int = 4
    @AppStorage("settings_maxStrikes")   private var maxStrikes: Int = 3
    @AppStorage("settings_maxOuts")      private var maxOuts: Int = 3
    @AppStorage("settings_useTimers")    private var useTimers: Bool = true
    @AppStorage("settings_runAhead")     private var runAhead: Bool = true
    @AppStorage("settings_raEarlyMargin") private var raEarlyMargin: Int = 20
    @AppStorage("settings_raEarlyInning") private var raEarlyInning: Int = 4
    @AppStorage("settings_raLateMargin")  private var raLateMargin: Int = 15
    @AppStorage("settings_raLateInning")  private var raLateInning: Int = 5

    @State private var lastSentAt: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Toggle(isOn: $keepScore) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep score")
                            Text(keepScore
                                 ? "Tracks runs, innings, line score and end-of-game rules."
                                 : "Indicator only — balls / strikes / outs plus the game clock.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if keepScore {
                        Toggle(isOn: $allowTies) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allow ties")
                                Text(allowTies
                                     ? "Round-robin — a game may end tied."
                                     : "Finals — no tie; reverts to the last decided inning.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Toggle(isOn: $useTimers) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use timers")
                            Text(useTimers
                                 ? "Tournament clock rules apply (no-new-innings and drop-dead)."
                                 : "Untimed — the game ends by innings, the run-ahead rule, or the umpire.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if keepScore {
                    Section("Run-ahead rule") {
                        Toggle(isOn: $runAhead) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Run-ahead ends game")
                                Text(runAhead
                                     ? "A big enough lead ends the game at the completion of a half-inning."
                                     : "Blowouts play on until the innings or clock end the game.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if runAhead {
                            Stepper("Lead of \(raEarlyMargin)+", value: $raEarlyMargin, in: 5...50)
                            Stepper("…from inning \(raEarlyInning)", value: $raEarlyInning, in: 1...9)
                            Stepper("Lead of \(raLateMargin)+", value: $raLateMargin, in: 5...50)
                            Stepper("…from inning \(raLateInning)", value: $raLateInning, in: 1...9)
                            Text("Default: 20+ at completion of the 4th inning, 15+ from the 5th on. Checked only when a full inning completes — if Home surges ahead while batting, End half-inning and enter the runs to finish it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Sport") {
                    Picker("Sport", selection: $sportRaw) {
                        ForEach(Sport.allCases) { s in
                            Text(s.displayName).tag(s.rawValue)
                        }
                    }
                }

                if useTimers {
                    Section("Tournament timers") {
                    Stepper("No new innings: \(noNew) min", value: $noNew, in: 10...180, step: 5)
                    Stepper("Drop-dead: \(cutoff) min", value: $cutoff, in: 10...240, step: 5)
                    Toggle(isOn: $enforceDropDead) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enforce drop-dead")
                            Text(enforceDropDead
                                 ? "Prompts the umpire to end the game when the timer fires."
                                 : "Timer is purely advisory — the umpire decides when to call it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if cutoff <= noNew {
                        Text("Drop-dead must be greater than the No-new-innings time.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    }

                    Section("Auto-close") {
                    Toggle(isOn: $autoClose) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-close when idle")
                            Text(autoClose
                                 ? "Once past the cut-off, ends the game and closes the session after a period with no interaction."
                                 : "The app stays open until the umpire ends the game.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if autoClose {
                        Stepper("Idle limit: \(idleTimeout) min", value: $idleTimeout, in: 5...60, step: 5)
                    }
                    }
                }

                Section("Rules") {
                    Stepper("Balls per walk: \(maxBalls)", value: $maxBalls, in: 2...6)
                    Stepper("Strikes per K: \(maxStrikes)", value: $maxStrikes, in: 2...4)
                    Stepper("Outs per half-inning: \(maxOuts)", value: $maxOuts, in: 1...4)
                }

                Section {
                    Button {
                        sync()
                    } label: {
                        Label("Send to Watch", systemImage: "applewatch.radiowaves.left.and.right")
                    }
                    .disabled(!session.isWatchReachable && !session.isWatchAppInstalled)
                    if let lastSentAt {
                        Text("Last sent \(lastSentAt.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var currentSettings: GameSettings {
        GameSettings(
            sport: Sport(rawValue: sportRaw) ?? .softball,
            noNewInningsMinutes: noNew,
            ballGameCutoffMinutes: cutoff,
            maxBalls: maxBalls,
            maxStrikes: maxStrikes,
            maxOuts: maxOuts,
            awayTeamName: "Away",
            homeTeamName: "Home",
            enforceDropDead: enforceDropDead,
            keepScore: keepScore,
            allowTies: allowTies,
            autoCloseOnInactivity: autoClose,
            inactivityTimeoutMinutes: idleTimeout,
            useTimers: useTimers,
            runAheadEnabled: runAhead,
            runAheadEarlyMargin: raEarlyMargin,
            runAheadEarlyInning: raEarlyInning,
            runAheadLateMargin: raLateMargin,
            runAheadLateInning: raLateInning
        )
    }

    private func sync() {
        session.sendSettings(currentSettings)
        lastSentAt = .now
    }
}

#Preview {
    SettingsView()
        .environment(PhoneSessionManager.shared)
}
