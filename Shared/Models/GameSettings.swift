//
//  GameSettings.swift
//  UmpireClicker
//
//  Per-game configuration. Defaults live on the iPhone companion;
//  the watch reads these at game start.
//

import Foundation

public struct GameSettings: Codable, Equatable {
    public var sport: Sport
    public var noNewInningsMinutes: Int
    public var ballGameCutoffMinutes: Int
    public var maxBalls: Int
    public var maxStrikes: Int
    public var maxOuts: Int
    public var awayTeamName: String
    public var homeTeamName: String
    /// If true (default), the drop-dead timer firing prompts to end the game
    /// (with the standard revert-to-last-lead rule). If false, the timer is
    /// purely advisory — the umpire decides when to call it.
    public var enforceDropDead: Bool
    /// If true (default), the app tracks runs, innings, the line score and
    /// all end-of-game-by-score rules. If false, the app is a pure timed
    /// umpire indicator: balls / strikes / outs plus the game clock, with no
    /// scoreboard, line score, runs entry or score-based game end.
    public var keepScore: Bool
    /// If true (default), the game may end in a tie (round-robin play). If
    /// false (finals), a tie is not allowed: when the cutoff forces a revert
    /// and the target inning is tied, the app walks back to the last completed
    /// inning at which one team was ahead.
    public var allowTies: Bool
    /// If true (default), once the game reaches the cut-off / overtime phase
    /// and there is no umpire interaction for `inactivityTimeoutMinutes`, the
    /// app auto-ends the game, releases its session and returns to Setup.
    public var autoCloseOnInactivity: Bool
    /// Minutes of no interaction (while in cut-off / overtime) before the
    /// inactivity auto-close fires. Default 20.
    public var inactivityTimeoutMinutes: Int
    /// If true (default), the tournament clock thresholds (no-new-innings and
    /// drop-dead cutoff) are active, with their alerts and end-of-game rules.
    /// If false the game is untimed: elapsed time is still shown and recorded,
    /// but there are no thresholds, no timer alerts, and no time-based ends —
    /// the game finishes by innings, run-ahead rule, or the umpire.
    public var useTimers: Bool
    /// If true, the run-ahead (mercy) rule ends the game early on a blowout.
    public var runAheadEnabled: Bool
    /// Early tier: margin required from `runAheadEarlyInning` onwards.
    public var runAheadEarlyMargin: Int
    /// Inning from which the early-tier margin applies (completed innings).
    public var runAheadEarlyInning: Int
    /// Late tier: (smaller) margin required from `runAheadLateInning` onwards
    /// (default 15 from the 5th inning).
    public var runAheadLateMargin: Int
    /// Inning from which the late-tier margin applies (completed innings).
    public var runAheadLateInning: Int

    public init(
        sport: Sport = .softball,
        noNewInningsMinutes: Int = 50,
        ballGameCutoffMinutes: Int = 60,
        maxBalls: Int = 4,
        maxStrikes: Int = 3,
        maxOuts: Int = 3,
        awayTeamName: String = "Away",
        homeTeamName: String = "Home",
        enforceDropDead: Bool = true,
        keepScore: Bool = true,
        allowTies: Bool = true,
        autoCloseOnInactivity: Bool = true,
        inactivityTimeoutMinutes: Int = 20,
        useTimers: Bool = true,
        runAheadEnabled: Bool = true,
        runAheadEarlyMargin: Int = 20,
        runAheadEarlyInning: Int = 4,
        runAheadLateMargin: Int = 15,
        runAheadLateInning: Int = 5
    ) {
        self.sport = sport
        self.noNewInningsMinutes = noNewInningsMinutes
        self.ballGameCutoffMinutes = ballGameCutoffMinutes
        self.maxBalls = maxBalls
        self.maxStrikes = maxStrikes
        self.maxOuts = maxOuts
        self.awayTeamName = awayTeamName
        self.homeTeamName = homeTeamName
        self.enforceDropDead = enforceDropDead
        self.keepScore = keepScore
        self.allowTies = allowTies
        self.autoCloseOnInactivity = autoCloseOnInactivity
        self.inactivityTimeoutMinutes = inactivityTimeoutMinutes
        self.useTimers = useTimers
        self.runAheadEnabled = runAheadEnabled
        self.runAheadEarlyMargin = runAheadEarlyMargin
        self.runAheadEarlyInning = runAheadEarlyInning
        self.runAheadLateMargin = runAheadLateMargin
        self.runAheadLateInning = runAheadLateInning
    }

    /// The run-ahead margin that applies for a given (completed) inning, or
    /// nil when the rule is off / the inning is too early. Uses the smallest
    /// margin whose inning threshold has been reached.
    public func runAheadMargin(forInning inning: Int) -> Int? {
        guard runAheadEnabled else { return nil }
        if inning >= runAheadLateInning { return runAheadLateMargin }
        if inning >= runAheadEarlyInning { return runAheadEarlyMargin }
        return nil
    }

    // Backward-compatible decoding for records persisted before these fields existed.
    enum CodingKeys: String, CodingKey {
        case sport, noNewInningsMinutes, ballGameCutoffMinutes
        case maxBalls, maxStrikes, maxOuts
        case awayTeamName, homeTeamName, enforceDropDead, keepScore, allowTies
        case autoCloseOnInactivity, inactivityTimeoutMinutes
        case useTimers, runAheadEnabled
        case runAheadEarlyMargin, runAheadEarlyInning
        case runAheadLateMargin, runAheadLateInning
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sport                 = try c.decode(Sport.self,  forKey: .sport)
        noNewInningsMinutes   = try c.decode(Int.self,    forKey: .noNewInningsMinutes)
        ballGameCutoffMinutes = try c.decode(Int.self,    forKey: .ballGameCutoffMinutes)
        maxBalls              = try c.decode(Int.self,    forKey: .maxBalls)
        maxStrikes            = try c.decode(Int.self,    forKey: .maxStrikes)
        maxOuts               = try c.decode(Int.self,    forKey: .maxOuts)
        awayTeamName          = try c.decode(String.self, forKey: .awayTeamName)
        homeTeamName          = try c.decode(String.self, forKey: .homeTeamName)
        enforceDropDead       = try c.decodeIfPresent(Bool.self, forKey: .enforceDropDead) ?? true
        keepScore             = try c.decodeIfPresent(Bool.self, forKey: .keepScore) ?? true
        allowTies             = try c.decodeIfPresent(Bool.self, forKey: .allowTies) ?? true
        autoCloseOnInactivity = try c.decodeIfPresent(Bool.self, forKey: .autoCloseOnInactivity) ?? true
        inactivityTimeoutMinutes = try c.decodeIfPresent(Int.self, forKey: .inactivityTimeoutMinutes) ?? 20
        useTimers             = try c.decodeIfPresent(Bool.self, forKey: .useTimers) ?? true
        runAheadEnabled       = try c.decodeIfPresent(Bool.self, forKey: .runAheadEnabled) ?? true
        runAheadEarlyMargin   = try c.decodeIfPresent(Int.self, forKey: .runAheadEarlyMargin) ?? 20
        runAheadEarlyInning   = try c.decodeIfPresent(Int.self, forKey: .runAheadEarlyInning) ?? 4
        runAheadLateMargin    = try c.decodeIfPresent(Int.self, forKey: .runAheadLateMargin) ?? 15
        runAheadLateInning    = try c.decodeIfPresent(Int.self, forKey: .runAheadLateInning) ?? 5
    }

    public static let `default` = GameSettings()
}
