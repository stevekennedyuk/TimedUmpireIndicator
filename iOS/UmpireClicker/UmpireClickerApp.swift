//
//  UmpireClickerApp.swift
//  UmpireClicker (iOS companion)
//

import SwiftUI

@main
struct UmpireClickerApp: App {
    @State private var phoneSession = PhoneSessionManager.shared
    @State private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(phoneSession)
                .environment(historyStore)
                .onAppear {
                    phoneSession.attach(historyStore: historyStore)
                }
        }
    }
}
