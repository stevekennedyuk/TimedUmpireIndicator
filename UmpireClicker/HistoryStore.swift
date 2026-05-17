//
//  HistoryStore.swift
//  UmpireClicker (iOS companion)
//
//  Persists completed GameRecords to a JSON file in Application Support.
//

import Foundation
import Observation

@MainActor
@Observable
final class HistoryStore {
    var records: [GameRecord] = []

    private let fileURL: URL

    init(filename: String = "games.json") {
        let fm = FileManager.default
        let dir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let appDir = dir.appendingPathComponent("UmpireClicker", isDirectory: true)
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent(filename)
        load()
    }

    func add(_ record: GameRecord) {
        if let idx = records.firstIndex(where: { $0.id == record.id }) {
            records[idx] = record
        } else {
            records.insert(record, at: 0)
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([GameRecord].self, from: data) {
            records = decoded.sorted { $0.startedAt > $1.startedAt }
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static let preview: HistoryStore = {
        let s = HistoryStore(filename: "preview-games.json")
        s.records = [
            GameRecord(
                startedAt: .now.addingTimeInterval(-3600),
                endedAt: .now.addingTimeInterval(-180),
                sport: .softball,
                awayTeamName: "Sox",
                homeTeamName: "Jays",
                awayScore: 4,
                homeScore: 3,
                lineScore: [
                    InningRuns(inning: 1, top: 0, bottom: 1),
                    InningRuns(inning: 2, top: 2, bottom: 0),
                    InningRuns(inning: 3, top: 1, bottom: 2),
                    InningRuns(inning: 4, top: 0, bottom: 0),
                    InningRuns(inning: 5, top: 0, bottom: 0),
                    InningRuns(inning: 6, top: 1, bottom: 0),
                    InningRuns(inning: 7, top: 0, bottom: 0)
                ],
                endReason: .regulationComplete,
                durationSeconds: 53 * 60,
                noNewMinutes: 50,
                cutoffMinutes: 60
            )
        ]
        return s
    }()
}
