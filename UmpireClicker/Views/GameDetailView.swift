//
//  GameDetailView.swift
//  UmpireClicker (iOS companion)
//

import SwiftUI

struct GameDetailView: View {
    let record: GameRecord

    var body: some View {
        Form {
            Section("Final") {
                LabeledContent("\(record.awayTeamName)") {
                    Text("\(record.awayScore)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(record.awayScore > record.homeScore ? .green : .primary)
                }
                LabeledContent("\(record.homeTeamName)") {
                    Text("\(record.homeScore)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(record.homeScore > record.awayScore ? .green : .primary)
                }
                LabeledContent("Outcome", value: record.endReason.displayName)
            }

            Section("Line score") {
                LineScoreGrid(record: record)
            }

            Section("Game") {
                LabeledContent("Sport", value: record.sport.displayName)
                LabeledContent("Started", value: record.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: GameTimer.format(record.durationSeconds))
                LabeledContent("No-new", value: "\(record.noNewMinutes) min")
                LabeledContent("Drop-dead", value: "\(record.cutoffMinutes) min")
            }
        }
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LineScoreGrid: View {
    let record: GameRecord

    private var innings: [Int] {
        let highest = record.lineScore.map(\.inning).max() ?? 0
        return Array(1...Swift.max(1, highest))
    }
    
    private enum Side { case top, bottom }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("").frame(width: 60, alignment: .leading)
                    ForEach(innings, id: \.self) { i in
                        Text("\(i)").font(.caption.bold()).frame(width: 22)
                    }
                    Text("R").font(.caption.bold()).frame(width: 22)
                }
                row(name: record.awayTeamName, total: record.awayScore, side: .top)
                row(name: record.homeTeamName, total: record.homeScore, side: .bottom)
            }
            .padding(.vertical, 4)
        }
    }

    private func row(name: String, total: Int, side: Side) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 60, alignment: .leading)
            ForEach(innings, id: \.self) { i in
                let entry = record.lineScore.first(where: { $0.inning == i })
                let runs: Int? = {
                    guard let entry = entry else { return nil }
                    switch side {
                    case .top: return entry.top
                    case .bottom: return entry.bottom
                    }
                }()
                Text(runs.map(String.init) ?? "·")
                    .font(.callout.monospacedDigit())
                    .frame(width: 22)
            }
            Text("\(total)")
                .font(.callout.bold().monospacedDigit())
                .frame(width: 22)
        }
    }
}

#Preview {
    NavigationStack {
        GameDetailView(record: HistoryStore.preview.records.first!)
    }
}
