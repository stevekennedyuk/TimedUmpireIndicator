//
//  SetupView.swift
//  UmpireClicker Watch App
//
//  Configure timer durations + sport, start a new game, end/abandon current.
//  Uses `List` so the Digital Crown can drive Stepper focus correctly
//  (avoids the "Crown Sequencer was set up without a view property" log).
//

import SwiftUI

struct SetupView: View {
    let hasStarted: Bool
    let gameIsComplete: Bool
    let settings: GameSettings
    let onStart: (GameSettings) -> Void
    let onEndManually: () -> Void
    let onResetTimer: () -> Void

    @State private var sport: Sport = .softball
    @State private var noNew: Int = 50
    @State private var cutoff: Int = 60
    @State private var enforceDropDead: Bool = true
    @State private var keepScore: Bool = true
    @State private var awayName: String = "Away"
    @State private var homeName: String = "Home"
    @State private var showEndConfirm = false
    @State private var didLoad = false

    var body: some View {
        List {
            Toggle(isOn: $keepScore) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Keep score")
                        .font(.caption2)
                    Text(keepScore ? "Full scorekeeping" : "Indicator + clock only")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.green)

            Picker("Sport", selection: $sport) {
                ForEach(Sport.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            .pickerStyle(.navigationLink)

            stepperRow(label: "No new (min)", value: $noNew, range: 10...180, step: 5, tint: .orange)
            stepperRow(label: "Drop-dead (min)", value: $cutoff, range: 10...240, step: 5, tint: .red)

            Toggle(isOn: $enforceDropDead) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Enforce drop-dead")
                        .font(.caption2)
                    Text(enforceDropDead ? "Prompts at cutoff" : "Advisory only")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.red)

            Button {
                var s = settings
                s.sport = sport
                s.noNewInningsMinutes = noNew
                s.ballGameCutoffMinutes = cutoff
                s.enforceDropDead = enforceDropDead
                s.keepScore = keepScore
                s.awayTeamName = awayName
                s.homeTeamName = homeName
                onStart(s)
            } label: {
                Label(hasStarted && !gameIsComplete ? "Restart Game" : "Start Game",
                      systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .listRowBackground(Color.clear)

            if hasStarted && !gameIsComplete {
                Button(role: .destructive) {
                    showEndConfirm = true
                } label: {
                    Label("End Game", systemImage: "flag.checkered")
                }
                .buttonStyle(.bordered)
                .listRowBackground(Color.clear)
            }

            Text("Regulation: \(sport.regulationInnings) innings")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
        .listStyle(.carousel)
        .navigationTitle("Setup")
        .onAppear {
            guard !didLoad else { return }
            sport = settings.sport
            noNew = settings.noNewInningsMinutes
            cutoff = settings.ballGameCutoffMinutes
            enforceDropDead = settings.enforceDropDead
            keepScore = settings.keepScore
            awayName = settings.awayTeamName
            homeName = settings.homeTeamName
            didLoad = true
        }
        .confirmationDialog("End the game?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Game", role: .destructive, action: onEndManually)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                Spacer()
                Text("\(value.wrappedValue)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(tint)
            }
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}

#Preview {
    SetupView(
        hasStarted: false,
        gameIsComplete: false,
        settings: .default,
        onStart: { _ in },
        onEndManually: {},
        onResetTimer: {}
    )
}
