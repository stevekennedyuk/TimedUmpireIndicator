//
//  GameRecord.swift
//  UmpireClicker
//
//  Immutable record of a completed game, synced from watch → phone for history.
//

import Foundation

public struct GameRecord: Codable, Identifiable, Equatable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date
    public let sport: Sport
    public let awayTeamName: String
    public let homeTeamName: String
    public let awayScore: Int
    public let homeScore: Int
    public let lineScore: [InningRuns]
    public let endReason: GameEndReason
    public let durationSeconds: TimeInterval
    public let noNewMinutes: Int
    public let cutoffMinutes: Int

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        sport: Sport,
        awayTeamName: String,
        homeTeamName: String,
        awayScore: Int,
        homeScore: Int,
        lineScore: [InningRuns],
        endReason: GameEndReason,
        durationSeconds: TimeInterval,
        noNewMinutes: Int,
        cutoffMinutes: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sport = sport
        self.awayTeamName = awayTeamName
        self.homeTeamName = homeTeamName
        self.awayScore = awayScore
        self.homeScore = homeScore
        self.lineScore = lineScore
        self.endReason = endReason
        self.durationSeconds = durationSeconds
        self.noNewMinutes = noNewMinutes
        self.cutoffMinutes = cutoffMinutes
    }

    public var leader: Leader {
        if awayScore > homeScore { return .away }
        if homeScore > awayScore { return .home }
        return .tied
    }
}
