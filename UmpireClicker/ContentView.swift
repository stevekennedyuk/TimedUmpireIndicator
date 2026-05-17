//
//  ContentView.swift
//  UmpireClicker (iOS companion)
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

struct AboutView: View {
    @Environment(PhoneSessionManager.self) private var session

    var body: some View {
        NavigationStack {
            Form {
                Section("Watch") {
                    Label(session.isWatchReachable ? "Reachable" : "Not reachable",
                          systemImage: session.isWatchReachable ? "applewatch" : "applewatch.slash")
                    Label(session.isWatchAppInstalled ? "Watch app installed" : "Watch app not installed",
                          systemImage: session.isWatchAppInstalled ? "checkmark.circle" : "xmark.circle")
                }
                Section("How it works") {
                    Text("This iPhone app is the companion to the Umpire Clicker Watch app. Use the Settings tab to choose defaults (sport, timer thresholds, team names) — they're pushed to the watch automatically. Completed games sync back here for the History tab.")
                        .font(.callout)
                }
                Section("Tournament rules") {
                    Text("• \"No new innings\" timer: once this fires, no new inning will start; if the home team is leading at that moment the game ends.\n• \"Drop-dead\" (ball game) timer: when this fires the game ends immediately. The score reverts to the most recent inning at the end of which a team was leading.\n• Regulation: 7 innings (softball) or 9 (baseball). Tied games continue into extra innings until one team is ahead at the end of an inning — or a timer fires.")
                        .font(.callout)
                }
            }
            .navigationTitle("About")
        }
    }
}

#Preview {
    ContentView()
        .environment(PhoneSessionManager.shared)
        .environment(HistoryStore())
}
