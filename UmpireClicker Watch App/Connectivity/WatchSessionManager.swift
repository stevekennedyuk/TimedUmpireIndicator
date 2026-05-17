//
//  WatchSessionManager.swift
//  UmpireClicker Watch App
//

import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    var lastReceivedSettings: GameSettings?
    var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendGameRecord(_ record: GameRecord) {
        guard WCSession.default.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(record)
            WCSession.default.transferUserInfo([SyncMessageKey.completedGame: data])
        } catch {
            // Swallow — connectivity is best-effort.
        }
    }

    func sendLiveState(_ payload: LiveStatePayload) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        WCSession.default.sendMessage([SyncMessageKey.liveState: data], replyHandler: nil) { _ in }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let data = message[SyncMessageKey.settings] as? Data,
              let settings = try? JSONDecoder().decode(GameSettings.self, from: data) else { return }
        Task { @MainActor in
            self.lastReceivedSettings = settings
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let data = userInfo[SyncMessageKey.settings] as? Data,
              let settings = try? JSONDecoder().decode(GameSettings.self, from: data) else { return }
        Task { @MainActor in
            self.lastReceivedSettings = settings
        }
    }
}
