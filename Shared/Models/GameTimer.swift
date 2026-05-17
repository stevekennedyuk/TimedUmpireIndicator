//
//  GameTimer.swift
//  UmpireClicker
//
//  Wall-clock game timer with two tournament thresholds:
//  - "No new innings" — once this fires, the current inning finishes but
//    no new inning starts; if the home team is ahead the game ends now.
//  - "Ball game" cutoff (drop-dead) — game ends immediately; score reverts
//    to the most recent inning a team led.
//

import Foundation
import Observation

@MainActor
@Observable
public final class GameTimer {
    public var noNewInningsMinutes: Int
    public var ballGameCutoffMinutes: Int

    public private(set) var startedAt: Date?
    public private(set) var pausedAt: Date?

    /// Elapsed time. Refreshed by `tick()` (called from a 1-second Timer on the watch).
    public var elapsed: TimeInterval = 0

    public init(noNewInningsMinutes: Int = 50, ballGameCutoffMinutes: Int = 60) {
        self.noNewInningsMinutes = noNewInningsMinutes
        self.ballGameCutoffMinutes = ballGameCutoffMinutes
    }

    public var isRunning: Bool { startedAt != nil && pausedAt == nil }
    public var isPaused: Bool { pausedAt != nil }

    public var noNewInningsTime: TimeInterval { TimeInterval(noNewInningsMinutes * 60) }
    public var ballGameCutoffTime: TimeInterval { TimeInterval(ballGameCutoffMinutes * 60) }

    public var isNoNewInningsTriggered: Bool { elapsed >= noNewInningsTime }
    public var isCutoffTriggered: Bool { elapsed >= ballGameCutoffTime }

    public var timeUntilNoNew: TimeInterval { max(0, noNewInningsTime - elapsed) }
    public var timeUntilCutoff: TimeInterval { max(0, ballGameCutoffTime - elapsed) }

    /// Which timer threshold the active countdown is heading toward.
    public enum Phase: String {
        case noNew    = "No New"
        case ballGame = "Ball Game"
        case overtime = "OT"
    }

    public var phase: Phase {
        if isCutoffTriggered          { return .overtime }
        if isNoNewInningsTriggered    { return .ballGame }
        return .noNew
    }

    /// Time remaining in the current phase.
    /// - In `noNew`: seconds until the no-new-innings threshold.
    /// - In `ballGame`: seconds until the drop-dead threshold.
    /// - In `overtime` (only reachable when the umpire overrode drop-dead):
    ///   seconds *past* the drop-dead threshold.
    public var activeCountdown: TimeInterval {
        switch phase {
        case .noNew:    return timeUntilNoNew
        case .ballGame: return timeUntilCutoff
        case .overtime: return max(0, elapsed - ballGameCutoffTime)
        }
    }

    /// "MM:SS" string for the current phase, prefixed with "+" while in overtime.
    public var activeCountdownText: String {
        let formatted = GameTimer.format(activeCountdown)
        return phase == .overtime ? "+\(formatted)" : formatted
    }

    public func start() {
        guard startedAt == nil else { return }
        startedAt = .now
        pausedAt = nil
    }

    public func pause() {
        guard isRunning else { return }
        pausedAt = .now
    }

    public func resume() {
        guard let pausedAt, let startedAt else { return }
        let pausedFor = Date.now.timeIntervalSince(pausedAt)
        self.startedAt = startedAt.addingTimeInterval(pausedFor)
        self.pausedAt = nil
    }

    public func tick(now: Date = .now) {
        guard let startedAt else { return }
        if let pausedAt {
            elapsed = pausedAt.timeIntervalSince(startedAt)
        } else {
            elapsed = now.timeIntervalSince(startedAt)
        }
    }

    public func reset() {
        startedAt = nil
        pausedAt = nil
        elapsed = 0
    }

    public static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
