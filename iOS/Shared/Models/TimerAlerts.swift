//
//  TimerAlerts.swift
//  UmpireClicker (Shared)
//
//  In-app haptics only work while the app is frontmost. Once the watch
//  returns to the clock face (or the phone locks), the app is suspended and
//  its timers stop — so the threshold buzz must come from the system instead.
//  This helper schedules local notifications for the two tournament-timer
//  thresholds: the system delivers them at the right moment with a wrist tap
//  / phone vibration and sound, whether or not the app is running. While the
//  app IS frontmost the system suppresses the banners, and the in-app haptics
//  cover it — so there's no double alert.
//

import Foundation
import UserNotifications

public enum TimerAlerts {
    private static let noNewID   = "timer.noNewInnings"
    private static let cutoffID  = "timer.cutoff"
    private static let cutoff2ID = "timer.cutoff.repeat"

    /// Ask for permission to alert. Safe to call repeatedly — the system only
    /// prompts the first time.
    public static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule alerts for thresholds that are still in the future. Cancels
    /// any previously scheduled ones first, so this is safe to call on
    /// start and on resume alike.
    /// - Parameters:
    ///   - noNewIn: seconds until the no-new-innings threshold (skip if nil or past).
    ///   - cutoffIn: seconds until the drop-dead threshold (skip if nil or past).
    public static func schedule(noNewIn: TimeInterval?, cutoffIn: TimeInterval?) {
        cancelAll()
        let center = UNUserNotificationCenter.current()

        if let t = noNewIn, t > 1 {
            let content = UNMutableNotificationContent()
            content.title = "No new innings"
            content.body = "Time limit reached — finish the current inning."
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: noNewID,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: t, repeats: false)))
        }

        if let t = cutoffIn, t > 1 {
            let content = UNMutableNotificationContent()
            content.title = "Ball game — time!"
            content.body = "Drop-dead time reached. Open Umpire to end the game."
            content.sound = .default
            center.add(UNNotificationRequest(
                identifier: cutoffID,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: t, repeats: false)))

            // Follow-up ping shortly after, so the hard deadline is
            // unmissable even if the first tap goes unnoticed.
            let again = UNMutableNotificationContent()
            again.title = "Ball game — time!"
            again.body = "Drop-dead time has passed."
            again.sound = .default
            center.add(UNNotificationRequest(
                identifier: cutoff2ID,
                content: again,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: t + 15, repeats: false)))
        }
    }

    /// Cancel all pending threshold alerts (game ended, paused, or torn down).
    public static func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [noNewID, cutoffID, cutoff2ID])
    }

    /// Cancel just the drop-dead follow-up ping (the umpire has already
    /// responded to the deadline, e.g. chose "Play on" or ended the game).
    public static func cancelCutoffFollowUp() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [cutoff2ID])
    }
}
