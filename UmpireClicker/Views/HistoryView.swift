//
//  HistoryView.swift
//  UmpireClicker (iOS companion)
//

import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No games yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Completed games from the watch will appear here.")
                    )
                } else {
                    List {
                        ForEach(store.records) { record in
                            NavigationLink {
                                GameDetailView(record: record)
                            } label: {
                                HistoryRow(record: record)
                            }
                        }
                        .onDelete { offsets in
                            store.delete(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !store.records.isEmpty {
                    EditButton()
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let record: GameRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                Spacer()
                Text(record.sport.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                scorePill(name: record.awayTeamName, score: record.awayScore, isWinner: record.awayScore > record.homeScore)
                Text("–").foregroundStyle(.secondary)
                scorePill(name: record.homeTeamName, score: record.homeScore, isWinner: record.homeScore > record.awayScore)
                Spacer()
                Text(record.endReason.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(reasonColor(record.endReason).opacity(0.18), in: Capsule())
                    .foregroundStyle(reasonColor(record.endReason))
            }
        }
        .padding(.vertical, 2)
    }

    private func scorePill(name: String, score: Int, isWinner: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name).font(.caption)
            Text("\(score)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(isWinner ? .green : .primary)
        }
    }

    private func reasonColor(_ r: GameEndReason) -> Color {
        switch r {
        case .regulationComplete:    return .green
        case .noNewInningsHomeAhead: return .orange
        case .ballGameCutoff:        return .red
        case .manual:                return .gray
        }
    }
}

#Preview {
    HistoryView()
        .environment(HistoryStore.preview)
}
