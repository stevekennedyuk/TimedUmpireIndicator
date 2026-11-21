//
//  PhoneSessionManager.swift
//  UmpireClicker (iOS companion)
//

import Foundation
import WatchConnectivity
import Observation

@MainActor
@Observable
final class PhoneSessionManager: NSObject {
    static let shared = PhoneSessionManager()

    var activationState: WCSessionActivationState = .notActivated
    var isWatchReachable: Bool = false
    var isWatchAppInstalled: Bool = false

    @ObservationIgnored
    private weak var historyStore: HistoryStore?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let s = WCSession.default
            s.delegate = self
            s.activate()
        }
    }

    func attach(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    func sendSettings(_ settings: GameSettings) {
        guard WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(settings) else { return }
        let payload: [String: Any] = [SyncMessageKey.settings: data]
        // Use transferUserInfo so it queues even when the watch is asleep.
        WCSession.default.transferUserInfo(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { _ in }
        }
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let reachable = session.isReachable
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.activationState = activationState
            self.isWatchReachable = reachable
            self.isWatchAppInstalled = installed
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isWatchReachable = reachable
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            self.isWatchAppInstalled = installed
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleGameRecord(from: userInfo)
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        handleGameRecord(from: message)
    }

    private nonisolated func handleGameRecord(from dict: [String: Any]) {
        guard let data = dict[SyncMessageKey.completedGame] as? Data,
              let record = try? JSONDecoder().decode(GameRecord.self, from: data) else { return }
        Task { @MainActor in
            self.historyStore?.add(record)
        }
    }
}
