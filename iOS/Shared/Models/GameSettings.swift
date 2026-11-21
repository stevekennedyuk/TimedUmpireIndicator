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
    /// Per-inning run-ahead margins for softball, index 0 = inning 1 (7
    /// entries). 0 disables the rule for that inning; extra innings beyond
    /// the table reuse the last entry.
    public var runAheadMarginsSoftball: [Int]
    /// Per-inning run-ahead margins for baseball, index 0 = inning 1 (9
    /// entries). Same semantics as the softball table.
    public var runAheadMarginsBaseball: [Int]

    /// Default softball mercy table: 20+ at the 4th, 15+ from the 5th.
    public static let defaultRunAheadSoftball = [0, 0, 0, 20, 15, 15, 15]
    /// Default WBSC baseball mercy table: 15+ from the 5th, 10+ from the 7th.
    public static let defaultRunAheadBaseball = [0, 0, 0, 0, 15, 15, 10, 10, 10]

    public init(
        sport: Sport = .softball,
        noNewInningsMinutes: Int = 55,
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
        runAheadMarginsSoftball: [Int] = GameSettings.defaultRunAheadSoftball,
        runAheadMarginsBaseball: [Int] = GameSettings.defaultRunAheadBaseball
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
        self.runAheadMarginsSoftball = runAheadMarginsSoftball
        self.runAheadMarginsBaseball = runAheadMarginsBaseball
    }

    /// The margin table for a sport.
    public func runAheadMargins(for sport: Sport) -> [Int] {
        sport == .baseball ? runAheadMarginsBaseball : runAheadMarginsSoftball
    }

    /// The run-ahead margin that applies for a given (just-completed) inning,
    /// or nil when the rule is off or that inning's margin is 0. Innings
    /// beyond the table (extras) reuse the last entry.
    public func runAheadMargin(forInning inning: Int) -> Int? {
        guard runAheadEnabled, inning >= 1 else { return nil }
        let table = runAheadMargins(for: sport)
        guard !table.isEmpty else { return nil }
        let margin = table[min(inning, table.count) - 1]
        return margin > 0 ? margin : nil
    }

    /// Compact human summary of a sport's mercy table, compressing runs of
    /// equal margins — e.g. "20+@4 · 15+@5+" or "15+@5–6 · 10+@7+".
    /// Returns "Off" when no inning has a margin.
    public func runAheadSummary(for sport: Sport) -> String {
        let table = runAheadMargins(for: sport)
        var parts: [String] = []
        var i = 0
        while i < table.count {
            let margin = table[i]
            var j = i
            while j + 1 < table.count && table[j + 1] == margin { j += 1 }
            if margin > 0 {
                let from = i + 1
                let to = j + 1
                if to == table.count {
                    parts.append("\(margin)+@\(from)+")
                } else if from == to {
                    parts.append("\(margin)+@\(from)")
                } else {
                    parts.append("\(margin)+@\(from)–\(to)")
                }
            }
            i = j + 1
        }
        return parts.isEmpty ? "Off" : parts.joined(separator: " · ")
    }

    // Backward-compatible decoding for records persisted before these fields existed.
    enum CodingKeys: String, CodingKey {
        case sport, noNewInningsMinutes, ballGameCutoffMinutes
        case maxBalls, maxStrikes, maxOuts
        case awayTeamName, homeTeamName, enforceDropDead, keepScore, allowTies
        case autoCloseOnInactivity, inactivityTimeoutMinutes
        case useTimers, runAheadEnabled
        case runAheadMarginsSoftball, runAheadMarginsBaseball
    }

    /// Keys from the retired two-tier run-ahead model, decoded only to
    /// migrate previously persisted settings into the per-inning tables.
    private enum LegacyRunAheadKeys: String, CodingKey {
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

        // Per-inning tables, with migration from the retired two-tier model
        // (early/late margin + inning) for previously persisted settings.
        let legacy = try decoder.container(keyedBy: LegacyRunAheadKeys.self)
        func legacyTable(count: Int) throws -> [Int]? {
            guard let earlyMargin = try legacy.decodeIfPresent(Int.self, forKey: .runAheadEarlyMargin) else {
                return nil
            }
            let earlyInning = try legacy.decodeIfPresent(Int.self, forKey: .runAheadEarlyInning) ?? 4
            let lateMargin  = try legacy.decodeIfPresent(Int.self, forKey: .runAheadLateMargin) ?? 15
            let lateInning  = try legacy.decodeIfPresent(Int.self, forKey: .runAheadLateInning) ?? 5
            return (1...count).map { inning in
                if inning >= lateInning { return lateMargin }
                if inning >= earlyInning { return earlyMargin }
                return 0
            }
        }
        runAheadMarginsSoftball = try c.decodeIfPresent([Int].self, forKey: .runAheadMarginsSoftball)
            ?? (try legacyTable(count: 7))
            ?? Self.defaultRunAheadSoftball
        runAheadMarginsBaseball = try c.decodeIfPresent([Int].self, forKey: .runAheadMarginsBaseball)
            ?? (try legacyTable(count: 9))
            ?? Self.defaultRunAheadBaseball
    }

    public static let `default` = GameSettings()
}
