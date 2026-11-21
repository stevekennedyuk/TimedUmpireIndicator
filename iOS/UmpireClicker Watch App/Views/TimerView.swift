//
//  TimerView.swift
//  UmpireClicker Watch App
//
//  Phase-based countdown:
//    Phase 1 — "No New: MM:SS"    counts down to the no-new-innings threshold
//    Phase 2 — "Ball Game: MM:SS" counts down to the drop-dead threshold
//    Phase 3 — "OT: +MM:SS"       only reachable when drop-dead is overridden
//

import SwiftUI

struct TimerView: View {
    @Bindable var timer: GameTimer
    @Bindable var game: GameState

    var body: some View {
        VStack(spacing: 6) {
            Text(timer.isPaused ? "PAUSED" : phaseHeadline)
                .font(.caption2.bold())
                .foregroundStyle(timer.isPaused ? .yellow : phaseColor)

            Text(timer.activeCountdownText)
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(timer.isPaused ? .yellow : phaseColor)

            Text(timer.isPaused ? "Clock paused — injuries, weather, etc." : phaseSubtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !timer.isPaused {
                if timer.phase == .overtime && game.dropDeadOverridden {
                    Text("PLAY ON · cutoff overridden")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                } else if timer.isCutoffTriggered && !game.settings.enforceDropDead {
                    Text("Drop-dead advisory")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                }
            }

            // Prominent pause / resume control — primary action on this page.
            Button {
                if timer.isPaused { timer.resume() } else { timer.pause() }
            } label: {
                Label(
                    timer.isPaused ? "Resume" : "Pause",
                    systemImage: timer.isPaused ? "play.fill" : "pause.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(timer.isPaused ? .green : .orange)
            .disabled(timer.startedAt == nil)
            .controlSize(.small)

            // Start (only visible before the game clock has been started).
            if timer.startedAt == nil {
                Button {
                    timer.start()
                } label: {
                    Label("Start clock", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 4)
        .navigationTitle("Timer")
    }

    private var phaseHeadline: String {
        switch timer.phase {
        case .noNew:    return "NO NEW"
        case .ballGame: return "BALL GAME"
        case .overtime: return "OVERTIME"
        }
    }

    /// Tiny secondary line giving context for the countdown.
    private var phaseSubtitle: String {
        switch timer.phase {
        case .noNew:
            return "until no-new at \(timer.noNewInningsMinutes) min · drop-dead \(timer.ballGameCutoffMinutes) min"
        case .ballGame:
            return "until drop-dead at \(timer.ballGameCutoffMinutes) min"
        case .overtime:
            return "past drop-dead (\(timer.ballGameCutoffMinutes) min)"
        }
    }

    private var phaseColor: Color {
        switch timer.phase {
        case .noNew:    return .primary
        case .ballGame: return .orange
        case .overtime: return .red
        }
    }
}

#Preview("No New phase") {
    let t = GameTimer(noNewInningsMinutes: 50, ballGameCutoffMinutes: 60)
    t.elapsed = 5 * 60
    return TimerView(timer: t, game: GameState())
}

#Preview("Ball Game phase") {
    let t = GameTimer(noNewInningsMinutes: 50, ballGameCutoffMinutes: 60)
    t.elapsed = 52 * 60
    return TimerView(timer: t, game: GameState())
}
