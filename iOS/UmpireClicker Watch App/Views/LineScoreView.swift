//
//  LineScoreView.swift
//  UmpireClicker Watch App
//
//  Compact per-inning line-score table.
//

import SwiftUI

struct LineScoreView: View {
    @Bindable var game: GameState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                header
                Divider()
                row(name: game.settings.awayTeamName, half: .top, total: game.awayScore)
                row(name: game.settings.homeTeamName, half: .bottom, total: game.homeScore)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Line")
    }

    private var allInnings: [Int] {
        let highest = game.lineScore.map(\.inning).max() ?? game.inning
        return Array(1...Swift.max(1, highest))
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("")
                .frame(width: 36, alignment: .leading)
            ForEach(allInnings, id: \.self) { i in
                Text("\(i)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            }
            Spacer(minLength: 0)
            Text("R")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16)
        }
    }

    private func row(name: String, half: Half, total: Int) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .frame(width: 36, alignment: .leading)
            ForEach(allInnings, id: \.self) { i in
                Text(cellText(inning: i, half: half))
                    .font(.system(size: 11, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 12)
            }
            Spacer(minLength: 0)
            Text("\(total)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .frame(width: 16)
        }
    }

    private func cellText(inning: Int, half: Half) -> String {
        guard let entry = game.lineScore.first(where: { $0.inning == inning }) else { return "·" }
        guard let r = entry.runs(for: half) else { return "·" }
        return "\(r)"
    }
}

#Preview {
    LineScoreView(game: GameState())
}
