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
    @AppStorage("settings_noNew")        private var noNew: Int = 55
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
    @AppStorage("settings_raSoftball")   private var raSoftballCSV: String = "0,0,0,20,15,15,15"
    @AppStorage("settings_raBaseball")   private var raBaseballCSV: String = "0,0,0,0,15,15,10,10,10"

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
                            let sport = Sport(rawValue: sportRaw) ?? .softball
                            ForEach(1...sport.regulationInnings, id: \.self) { inning in
                                Stepper(value: marginBinding(inning: inning, sport: sport), in: 0...50, step: 1) {
                                    HStack {
                                        Text("Inning \(inning)")
                                        Spacer()
                                        let v = margins(for: sport)[inning - 1]
                                        Text(v == 0 ? "Off" : "\(v)+")
                                            .monospacedDigit()
                                            .foregroundStyle(v == 0 ? .secondary : .primary)
                                    }
                                }
                            }
                            Text("Lead needed to end the game when that inning completes (0 = rule off for that inning). Extra innings use the last inning's value. Home ahead by the margin after the TOP half ends it at N½ — Home needn't bat. Table shown is for \(sport.displayName); each sport keeps its own.")
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
        .fromIOSDefaults()
    }

    private func margins(for sport: Sport) -> [Int] {
        let fallback = sport == .baseball
            ? GameSettings.defaultRunAheadBaseball
            : GameSettings.defaultRunAheadSoftball
        let csv = sport == .baseball ? raBaseballCSV : raSoftballCSV
        return Self.parseMargins(csv, count: sport.regulationInnings, fallback: fallback)
    }

    private func marginBinding(inning: Int, sport: Sport) -> Binding<Int> {
        Binding(
            get: { margins(for: sport)[inning - 1] },
            set: { newValue in
                var table = margins(for: sport)
                table[inning - 1] = max(0, newValue)
                let csv = table.map(String.init).joined(separator: ",")
                if sport == .baseball { raBaseballCSV = csv } else { raSoftballCSV = csv }
            }
        )
    }

    /// Parse a comma-separated margin table; falls back wholesale if the
    /// string doesn't contain exactly `count` integers.
    static func parseMargins(_ csv: String, count: Int, fallback: [Int]) -> [Int] {
        let values = csv.split(separator: ",").compactMap {
            Int($0.trimmingCharacters(in: .whitespaces))
        }
        guard values.count == count else { return fallback }
        return values.map { max(0, $0) }
    }

    private func sync() {
        session.sendSettings(currentSettings)
        lastSentAt = .now
    }
}

extension GameSettings {
    /// The iPhone Settings-tab values (the `settings_*` UserDefaults keys)
    /// assembled into a GameSettings. Single source of truth for defaults on
    /// iOS: the Settings tab edits these keys, the game-setup sheet starts
    /// from them (per-game changes don't write back), and Send to Watch
    /// pushes them. Fallbacks MUST match the @AppStorage defaults above.
    static func fromIOSDefaults(_ d: UserDefaults = .standard) -> GameSettings {
        func int(_ key: String, _ fallback: Int) -> Int {
            d.object(forKey: key) as? Int ?? fallback
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            d.object(forKey: key) as? Bool ?? fallback
        }
        func table(_ key: String, count: Int, fallback: [Int]) -> [Int] {
            guard let csv = d.string(forKey: key) else { return fallback }
            return SettingsView.parseMargins(csv, count: count, fallback: fallback)
        }
        return GameSettings(
            sport: Sport(rawValue: d.string(forKey: "settings_sport") ?? Sport.softball.rawValue) ?? .softball,
            noNewInningsMinutes: int("settings_noNew", 55),
            ballGameCutoffMinutes: int("settings_cutoff", 60),
            maxBalls: int("settings_maxBalls", 4),
            maxStrikes: int("settings_maxStrikes", 3),
            maxOuts: int("settings_maxOuts", 3),
            awayTeamName: "Away",
            homeTeamName: "Home",
            enforceDropDead: bool("settings_enforceDD", true),
            keepScore: bool("settings_keepScore", true),
            allowTies: bool("settings_allowTies", true),
            autoCloseOnInactivity: bool("settings_autoClose", true),
            inactivityTimeoutMinutes: int("settings_idleTimeout", 20),
            useTimers: bool("settings_useTimers", true),
            runAheadEnabled: bool("settings_runAhead", true),
            runAheadMarginsSoftball: table("settings_raSoftball", count: 7, fallback: GameSettings.defaultRunAheadSoftball),
            runAheadMarginsBaseball: table("settings_raBaseball", count: 9, fallback: GameSettings.defaultRunAheadBaseball)
        )
    }
}

#Preview {
    SettingsView()
        .environment(PhoneSessionManager.shared)
}
