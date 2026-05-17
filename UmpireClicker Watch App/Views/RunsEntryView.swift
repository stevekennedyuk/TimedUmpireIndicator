//
//  RunsEntryView.swift
//  UmpireClicker Watch App
//
//  Modal shown at the end of every half-inning so the umpire can enter
//  the runs scored.
//

import SwiftUI

struct RunsEntryView: View {
    let inning: Int
    let half: Half
    let teamBatting: String
    let onConfirm: (Int) -> Void

    @State private var runs: Int = 0

    var body: some View {
        VStack(spacing: 6) {
            Text("\(half.fullName) \(inning)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(teamBatting)
                .font(.caption.bold())
                .lineLimit(1)

            HStack(spacing: 14) {
                Button {
                    runs = Swift.max(0, runs - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(.gray)

                Text("\(runs)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 50)

                Button {
                    runs += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            Text(runs == 1 ? "run" : "runs")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Confirm") {
                onConfirm(runs)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(.horizontal, 6)
    }
}

#Preview {
    RunsEntryView(inning: 3, half: .top, teamBatting: "Away") { _ in }
}
