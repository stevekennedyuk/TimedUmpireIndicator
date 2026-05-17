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
    @AppStorage("settings_maxBalls")     private var maxBalls: Int = 4
    @AppStorage("settings_maxStrikes")   private var maxStrikes: Int = 3
    @AppStorage("settings_maxOuts")      private var maxOuts: Int = 3
    @AppStorage("settings_awayName")     private var awayName: String = "Away"
    @AppStorage("settings_homeName")     private var homeName: String = "Home"

    @State private var lastSentAt: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Sport") {
                    Picker("Sport", selection: $sportRaw) {
                        ForEach(Sport.allCases) { s in
                            Text(s.displayName).tag(s.rawValue)
                        }
                    }
                }

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

                Section("Rules") {
                    Stepper("Balls per walk: \(maxBalls)", value: $maxBalls, in: 2...6)
                    Stepper("Strikes per K: \(maxStrikes)", value: $maxStrikes, in: 2...4)
                    Stepper("Outs per half-inning: \(maxOuts)", value: $maxOuts, in: 1...4)
                }

                Section("Team names") {
                    TextField("Visiting team", text: $awayName)
                        .textInputAutocapitalization(.words)
                    TextField("Home team", text: $homeName)
                        .textInputAutocapitalization(.words)
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
            awayTeamName: awayName,
            homeTeamName: homeName,
            enforceDropDead: enforceDropDead
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
