//
//  Sport.swift
//  UmpireClicker
//
//  Sport variants supported by the umpire indicator.
//

import Foundation

public enum Sport: String, Codable, CaseIterable, Identifiable {
    case softball
    case baseball

    public var id: String { rawValue }

    /// Regulation length of a complete game in innings.
    public var regulationInnings: Int {
        switch self {
        case .softball: return 7
        case .baseball: return 9
        }
    }

    public var displayName: String {
        switch self {
        case .softball: return "Softball"
        case .baseball: return "Baseball"
        }
    }
}

public enum Half: String, Codable, CaseIterable {
    case top
    case bottom

    public var displayName: String {
        self == .top ? "Top" : "Bot"
    }

    public var fullName: String {
        self == .top ? "Top" : "Bottom"
    }

    public var symbol: String {
        self == .top ? "▲" : "▼"
    }
}

public enum Leader: String, Codable {
    case away
    case home
    case tied
}
