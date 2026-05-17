//
//  InningRuns.swift
//  UmpireClicker
//
//  Per-inning line-score entry (top/bottom run totals).
//

import Foundation

public struct InningRuns: Codable, Equatable, Identifiable {
    public let inning: Int
    public var top: Int?
    public var bottom: Int?

    public var id: Int { inning }

    public init(inning: Int, top: Int? = nil, bottom: Int? = nil) {
        self.inning = inning
        self.top = top
        self.bottom = bottom
    }

    public func runs(for half: Half) -> Int? {
        half == .top ? top : bottom
    }
}

/// A snapshot of the score after a completed half-inning. Used by the
/// "ball game" drop-dead rule to revert the score to the most recent
/// inning where a team was actually ahead.
public struct ScoreSnapshot: Codable, Equatable {
    public let inning: Int
    public let half: Half
    public let awayScore: Int
    public let homeScore: Int

    public init(inning: Int, half: Half, awayScore: Int, homeScore: Int) {
        self.inning = inning
        self.half = half
        self.awayScore = awayScore
        self.homeScore = homeScore
    }

    public var leader: Leader {
        if awayScore > homeScore { return .away }
        if homeScore > awayScore { return .home }
        return .tied
    }
}

public enum GameEndReason: String, Codable {
    /// Regulation length reached with a winner (or extras concluded with a winner).
    case regulationComplete
    /// "No new innings" timer reached and the home team is ahead — game ends.
    case noNewInningsHomeAhead
    /// "Ball game" drop-dead timer reached. Score reverts to last inning a team led.
    case ballGameCutoff
    /// Umpire ended the game manually.
    case manual

    public var displayName: String {
        switch self {
        case .regulationComplete:     return "Final"
        case .noNewInningsHomeAhead:  return "Time / Home leading"
        case .ballGameCutoff:         return "Drop-dead"
        case .manual:                 return "Called"
        }
    }
}
