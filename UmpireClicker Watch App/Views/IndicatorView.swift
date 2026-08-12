//
//  IndicatorView.swift
//  UmpireClicker Watch App
//
//  Primary clicker page — balls / strikes / outs / score / inning.
//

import SwiftUI
import WatchKit

struct IndicatorView: View {
    @Bindable var game: GameState
    @Bindable var timer: GameTimer

    var body: some View {
        VStack(spacing: 4) {
            if game.settings.keepScore {
                scoreRow
            } else {
                inningOnlyRow
            }

            HStack(spacing: 4) {
                CountCell(
                    label: "B",
                    value: game.balls,
                    pips: max(1, game.settings.maxBalls - 1),
                    color: .green,
                    onIncrement: {
                        game.incrementBall()
                        haptic(.click)
                    },
                    onDecrement: {
                        game.decrementBall()
                        haptic(.directionUp)
                    }
                )

                CountCell(
                    label: "S",
                    value: game.strikes,
                    pips: max(1, game.settings.maxStrikes - 1),
                    color: .yellow,
                    onIncrement: {
                        game.incrementStrike()
                        haptic(.click)
                    },
                    onDecrement: {
                        game.decrementStrike()
                        haptic(.directionUp)
                    }
                )

                CountCell(
                    label: "O",
                    value: game.outs,
                    pips: max(1, game.settings.maxOuts - 1),
                    color: .red,
                    onIncrement: {
                        game.incrementOut()
                        haptic(game.outs >= game.settings.maxOuts ? .notification : .click)
                    },
                    onDecrement: {
                        game.decrementOut()
                        haptic(.directionUp)
                    }
                )
            }

            timerBand
            controlsRow
        }
        .padding(.horizontal, 2)
        .navigationTitle("Umpire")
    }

    /// Large, high-contrast countdown — the tournament clock is what the
    /// umpire needs at a glance, so it gets the biggest type on the page.
    /// In an untimed game it shows plain elapsed time in neutral grey.
    private var timerBand: some View {
        HStack(spacing: 6) {
            Image(systemName: game.settings.useTimers ? timerIcon : "clock")
                .font(.system(size: 13, weight: .bold))
            if timer.isPaused {
                Text("PAUSED")
                    .font(.system(size: 11, weight: .heavy))
            } else {
                Text(game.settings.useTimers ? timer.phase.shortLabel : "TIME")
                    .font(.system(size: 11, weight: .heavy))
            }
            Spacer(minLength: 2)
            Text(game.settings.useTimers ? timer.activeCountdownText : GameTimer.format(timer.elapsed))
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(timer.isPaused ? .yellow : (game.settings.useTimers ? timerColor : .secondary))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(
            (timer.isPaused ? Color.yellow : (game.settings.useTimers ? bandBackground : .gray)).opacity(0.22),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var bandBackground: Color {
        switch timer.phase {
        case .noNew:    return .gray
        case .ballGame: return .orange
        case .overtime: return .red
        }
    }

    /// Undo / pause / end-half controls under the clock.
    private var controlsRow: some View {
        HStack {
            Button {
                game.undoLast()
                haptic(.directionDown)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(game.canUndo ? .orange : .gray)
            .disabled(!game.canUndo)
            .accessibilityLabel("Undo last action")

            Spacer()

            Button {
                if timer.isPaused { timer.resume() } else { timer.pause() }
                haptic(.click)
            } label: {
                Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(timer.isPaused ? .green : .yellow)
            .disabled(timer.startedAt == nil)
            .accessibilityLabel(timer.isPaused ? "Resume game clock" : "Pause game clock")

            Spacer()

            Button {
                game.forceEndOfHalf()
                haptic(.start)
            } label: {
                Image(systemName: "forward.end")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityLabel("End half-inning")
        }
        .padding(.horizontal, 6)
    }

    private var inningOnlyRow: some View {
        HStack {
            Spacer()
            HStack(spacing: 4) {
                Text(game.half.symbol)
                    .font(.caption2)
                Text("Inn \(game.inning)")
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
            Spacer()
        }
    }

    private var scoreRow: some View {
        HStack(alignment: .center, spacing: 4) {
            teamCell(name: game.settings.awayTeamName, score: game.awayScore, isBatting: game.half == .top, align: .leading)

            VStack(spacing: 0) {
                Text(game.half.symbol)
                    .font(.caption2)
                Text("\(game.inning)")
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))

            teamCell(name: game.settings.homeTeamName, score: game.homeScore, isBatting: game.half == .bottom, align: .trailing)
        }
    }

    private func teamCell(name: String, score: Int, isBatting: Bool, align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            Text(name)
                .font(.system(size: 9))
                .lineLimit(1)
                .foregroundStyle(isBatting ? .primary : .secondary)
            Text("\(score)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : .trailing)
    }

    private var timerIcon: String {
        switch timer.phase {
        case .noNew:    return "timer"
        case .ballGame: return "exclamationmark.triangle.fill"
        case .overtime: return "stop.circle.fill"
        }
    }

    private var timerColor: Color {
        switch timer.phase {
        case .noNew:    return .secondary
        case .ballGame: return .orange
        case .overtime: return .red
        }
    }

    private func haptic(_ kind: WKHapticType) {
        WKInterfaceDevice.current().play(kind)
    }
}

struct CountCell: View {
    let label: String
    let value: Int
    let pips: Int
    let color: Color
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 3) {
                ForEach(0..<pips, id: \.self) { i in
                    Circle()
                        .fill(i < value ? color : color.opacity(0.25))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onIncrement)
        .onLongPressGesture(minimumDuration: 0.5, perform: onDecrement)
    }
}

#Preview {
    IndicatorView(game: GameState(settings: .default), timer: GameTimer())
}
