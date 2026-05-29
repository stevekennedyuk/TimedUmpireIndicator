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
        keepScore: Bool = true
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
    }

    // Backward-compatible decoding for records persisted before these fields existed.
    enum CodingKeys: String, CodingKey {
        case sport, noNewInningsMinutes, ballGameCutoffMinutes
        case maxBalls, maxStrikes, maxOuts
        case awayTeamName, homeTeamName, enforceDropDead, keepScore
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
    }

    public static let `default` = GameSettings()
}
