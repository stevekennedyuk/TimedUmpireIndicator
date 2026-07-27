//
//  ContentView.swift
//  UmpireClicker (iOS companion)
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GameView()
                .tabItem { Label("Game", systemImage: "baseball") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
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
                    Text("Umpire from your iPhone on the Game tab, or use the companion Apple Watch app. Settings here set the defaults for new games and are pushed to the watch automatically. Completed games appear under History.")
                        .font(.callout)
                }
                Section("Keep the app on screen") {
                    Text("iPhone: while a game is running the app keeps the screen awake automatically — no setup needed.\n\nApple Watch: watchOS returns to the watch face after 2 minutes by default. To keep the Umpire app up for a whole game, on the watch go to Settings → General → Return to Clock → Umpire and choose \"After 1 hour\". You can also set \"Return to App\" so raising your wrist reopens the app.")
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
