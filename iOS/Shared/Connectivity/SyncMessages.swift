//
//  SyncMessages.swift
//  UmpireClicker
//
//  Shared keys + payload shapes used by WatchConnectivity messages between
//  the iPhone companion and the watch.
//

import Foundation

public enum SyncMessageKey {
    /// Sent from phone → watch when the user updates default settings.
    public static let settings = "settings"

    /// Sent from watch → phone when a game ends, carrying a `GameRecord`.
    public static let completedGame = "completedGame"

    /// Sent from watch → phone for live score/inning updates (optional UI).
    public static let liveState = "liveState"
}

/// Compact live-state payload streamed from the watch.
public struct LiveStatePayload: Codable, Equatable {
    public var inning: Int
    public var half: Half
    public var balls: Int
    public var strikes: Int
    public var outs: Int
    public var awayScore: Int
    public var homeScore: Int
    public var elapsedSeconds: TimeInterval
    public var noNewTriggered: Bool
    public var cutoffTriggered: Bool

    public init(
        inning: Int,
        half: Half,
        balls: Int,
        strikes: Int,
        outs: Int,
        awayScore: Int,
        homeScore: Int,
        elapsedSeconds: TimeInterval,
        noNewTriggered: Bool,
        cutoffTriggered: Bool
    ) {
        self.inning = inning
        self.half = half
        self.balls = balls
        self.strikes = strikes
        self.outs = outs
        self.awayScore = awayScore
        self.homeScore = homeScore
        self.elapsedSeconds = elapsedSeconds
        self.noNewTriggered = noNewTriggered
        self.cutoffTriggered = cutoffTriggered
    }
}
