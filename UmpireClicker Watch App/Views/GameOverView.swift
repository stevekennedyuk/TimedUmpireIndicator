//
//  GameOverView.swift
//  UmpireClicker Watch App
//

import SwiftUI

struct GameOverView: View {
    let awayName: String
    let homeName: String
    let awayScore: Int
    let homeScore: Int
    let reason: GameEndReason
    let lineScore: [InningRuns]
    let elapsed: TimeInterval
    var keepScore: Bool = true
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(reason.displayName.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(reasonColor)

                if keepScore {
                    HStack(spacing: 8) {
                        teamScore(name: awayName, score: awayScore, isWinner: awayScore > homeScore)
                        Text("–")
                        teamScore(name: homeName, score: homeScore, isWinner: homeScore > awayScore)
                    }

                    Text(headline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Game ended")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Game time: \(GameTimer.format(elapsed))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if keepScore && !lineScore.isEmpty {
                    Divider()
                    miniLineScore
                }

                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
    }

    private func teamScore(name: String, score: Int, isWinner: Bool) -> some View {
        VStack(spacing: 0) {
            Text(name)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWinner ? .green : .primary)
        }
    }

    private var headline: String {
        if awayScore == homeScore { return "Tied game" }
        return awayScore > homeScore
            ? "\(awayName) win"
            : "\(homeName) win"
    }

    private var reasonColor: Color {
        switch reason {
        case .ballGameCutoff:        return .red
        case .noNewInningsHomeAhead: return .orange
        case .regulationComplete:    return .green
        case .manual:                return .gray
        }
    }

    private var miniLineScore: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(" ").frame(width: 34, alignment: .leading)
                ForEach(lineScore) { entry in
                    Text("\(entry.inning)")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                Text("R")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 14)
            }
            row(name: awayName, total: awayScore) { $0.top }
            row(name: homeName, total: homeScore) { $0.bottom }
        }
    }

    private func row(name: String, total: Int, value: @escaping (InningRuns) -> Int?) -> some View {
        HStack(spacing: 2) {
            Text(name)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .frame(width: 34, alignment: .leading)
            ForEach(lineScore) { entry in
                Text(value(entry).map(String.init) ?? "·")
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 14)
            }
            Text("\(total)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .frame(width: 14)
        }
    }
}

#Preview {
    GameOverView(
        awayName: "Away",
        homeName: "Home",
        awayScore: 4,
        homeScore: 3,
        reason: .regulationComplete,
        lineScore: [
            InningRuns(inning: 1, top: 0, bottom: 1),
            InningRuns(inning: 2, top: 2, bottom: 0),
            InningRuns(inning: 3, top: 1, bottom: 2),
            InningRuns(inning: 4, top: 0, bottom: 0),
            InningRuns(inning: 5, top: 0, bottom: 0),
            InningRuns(inning: 6, top: 1, bottom: 0),
            InningRuns(inning: 7, top: 0, bottom: 0)
        ],
        elapsed: 53 * 60
    ) {}
}
