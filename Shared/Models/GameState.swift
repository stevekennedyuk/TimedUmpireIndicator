//
//  GameState.swift
//  UmpireClicker
//
//  Active in-game state and the rules engine that drives end-of-game logic.
//

import Foundation
import Observation

@MainActor
@Observable
public final class GameState {
    // MARK: - Configuration

    public var settings: GameSettings

    // MARK: - Identity

    public let id: UUID
    public let startedAt: Date

    // MARK: - Current pitch / count

    public var balls: Int = 0
    public var strikes: Int = 0
    public var outs: Int = 0

    // MARK: - Inning state

    public var inning: Int = 1
    public var half: Half = .top

    // MARK: - Score

    public var awayScore: Int = 0
    public var homeScore: Int = 0

    /// Per-inning line score (one entry per inning, with optional top/bottom).
    public var lineScore: [InningRuns] = []

    /// Score-after-each-half snapshots, used to revert on drop-dead.
    public var halfHistory: [ScoreSnapshot] = []

    // MARK: - End-of-half flow

    /// `true` immediately after a third out, while waiting for the umpire to
    /// confirm the runs scored during that half-inning.
    public var pendingRunsEntry: Bool = false

    // MARK: - End of game

    public var isComplete: Bool = false
    public var endReason: GameEndReason?
    public var endedAt: Date?

    /// Once `true`, the drop-dead (ball-game) timer will not auto-end the game
    /// or prompt again. Set by the umpire choosing "Play on" at the drop-dead
    /// prompt, or implied when settings.enforceDropDead is false.
    public var dropDeadOverridden: Bool = false

    // MARK: - Init

    public init(
        settings: GameSettings = .default,
        id: UUID = UUID(),
        startedAt: Date = .now
    ) {
        self.settings = settings
        self.id = id
        self.startedAt = startedAt
    }

    // MARK: - Pitch counting

    /// Increment the ball count. On the 4th ball the count resets (walk).
    /// Runs from the walk are recorded by the umpire at the end of the half.
    public func incrementBall() {
        guard canEdit else { return }
        balls += 1
        if balls >= settings.maxBalls {
            balls = 0
            strikes = 0
        }
    }

    public func decrementBall() {
        guard canEdit else { return }
        balls = max(0, balls - 1)
    }

    /// Increment the strike count. On the 3rd strike the count resets and an
    /// out is recorded.
    public func incrementStrike() {
        guard canEdit else { return }
        strikes += 1
        if strikes >= settings.maxStrikes {
            balls = 0
            strikes = 0
            incrementOut()
        }
    }

    public func decrementStrike() {
        guard canEdit else { return }
        strikes = max(0, strikes - 1)
    }

    /// Increment the out count. On the third out the half-inning ends and
    /// the app prompts the umpire for runs scored.
    public func incrementOut() {
        guard canEdit else { return }
        outs += 1
        if outs >= settings.maxOuts {
            // Reset count, leave outs at max for display, flag run entry
            balls = 0
            strikes = 0
            pendingRunsEntry = true
        }
    }

    public func decrementOut() {
        guard canEdit else { return }
        if pendingRunsEntry {
            pendingRunsEntry = false
        }
        outs = max(0, outs - 1)
    }

    /// Manually clear the count without recording an out (e.g. an erroneous tap).
    public func resetCount() {
        guard canEdit else { return }
        balls = 0
        strikes = 0
    }

    /// Force the current half-inning to end (e.g. walk-off in the bottom of
    /// the final inning, or any early end of half). Triggers runs entry.
    public func forceEndOfHalf() {
        guard !isComplete && !pendingRunsEntry else { return }
        pendingRunsEntry = true
    }

    private var canEdit: Bool {
        !isComplete && !pendingRunsEntry
    }

    // MARK: - Half-inning rollover

    /// Record the runs scored during the half-inning that just completed and
    /// advance to the next half. Pass the current timer state so end-of-game
    /// rules can fire.
    public func confirmRunsForCompletedHalf(
        _ runs: Int,
        noNewInningsTriggered: Bool,
        cutoffTriggered: Bool
    ) {
        guard pendingRunsEntry else { return }

        let normalisedRuns = max(0, runs)
        upsertLineScore(inning: inning, half: half, runs: normalisedRuns)

        switch half {
        case .top:    awayScore += normalisedRuns
        case .bottom: homeScore += normalisedRuns
        }

        halfHistory.append(
            ScoreSnapshot(
                inning: inning,
                half: half,
                awayScore: awayScore,
                homeScore: homeScore
            )
        )

        // Reset for next half
        balls = 0
        strikes = 0
        outs = 0
        pendingRunsEntry = false

        // Evaluate end-of-game conditions BEFORE advancing — they're about
        // the half that just finished. Drop-dead applies unless overridden.
        if cutoffTriggered && !dropDeadOverridden && settings.enforceDropDead {
            applyDropDead()
            return
        }
        if evaluateEndOfGame(noNewInningsTriggered: noNewInningsTriggered) {
            return
        }

        advanceHalf()
    }

    private func upsertLineScore(inning: Int, half: Half, runs: Int) {
        if let idx = lineScore.firstIndex(where: { $0.inning == inning }) {
            var entry = lineScore[idx]
            switch half {
            case .top:    entry.top = runs
            case .bottom: entry.bottom = runs
            }
            lineScore[idx] = entry
        } else {
            var entry = InningRuns(inning: inning)
            switch half {
            case .top:    entry.top = runs
            case .bottom: entry.bottom = runs
            }
            lineScore.append(entry)
        }
    }

    private func advanceHalf() {
        switch half {
        case .top:
            half = .bottom
        case .bottom:
            half = .top
            inning += 1
        }
    }

    // MARK: - End-of-game evaluation

    /// Returns `true` if the game ended.
    @discardableResult
    private func evaluateEndOfGame(noNewInningsTriggered: Bool) -> Bool {
        guard let last = halfHistory.last else { return false }
        let regulation = settings.sport.regulationInnings

        // 1. Walk-off / regulation complete in the BOTTOM of the inning.
        //    After bot of regulation+ — if a team leads, game over.
        if last.half == .bottom && last.inning >= regulation && last.leader != .tied {
            endGame(.regulationComplete)
            return true
        }

        // 2. Visiting team finished top of regulation+ and HOME already leads
        //    → home doesn't need to bat. Game over.
        if last.half == .top && last.inning >= regulation && last.leader == .home {
            endGame(.regulationComplete)
            return true
        }

        // 3. "No new innings" timer hit at any point + home is currently ahead → game over.
        if noNewInningsTriggered && last.leader == .home {
            endGame(.noNewInningsHomeAhead)
            return true
        }

        // 4. "No new innings" past regulation: can't start a new inning, so a
        //    tied game at end of bot-of-regulation ends as a tie.
        if noNewInningsTriggered
            && last.half == .bottom
            && last.inning >= regulation
        {
            endGame(.regulationComplete)
            return true
        }

        return false
    }

    /// Apply the drop-dead rule: revert score to the most recent half-inning
    /// at the end of which a team was ahead.
    public func applyDropDead() {
        if let idx = halfHistory.lastIndex(where: { $0.leader != .tied }) {
            let snap = halfHistory[idx]
            awayScore = snap.awayScore
            homeScore = snap.homeScore
            truncateLineScore(after: snap)
            halfHistory = Array(halfHistory.prefix(through: idx))
        } else {
            // No team was ever ahead — call it scoreless.
            awayScore = 0
            homeScore = 0
            lineScore.removeAll()
            halfHistory.removeAll()
        }
        endGame(.ballGameCutoff)
    }

    private func truncateLineScore(after snap: ScoreSnapshot) {
        var result: [InningRuns] = []
        for entry in lineScore {
            if entry.inning < snap.inning {
                result.append(entry)
            } else if entry.inning == snap.inning {
                var trimmed = entry
                if snap.half == .top {
                    trimmed.bottom = nil
                }
                result.append(trimmed)
            } // else: drop
        }
        lineScore = result
    }

    /// End the game manually (e.g. lightning, forfeit).
    public func endManually() {
        endGame(.manual)
    }

    /// End the game because the "no new innings" timer fired with the home
    /// team ahead. Called from the timer tick.
    public func endForNoNewInningsHomeLeads() {
        endGame(.noNewInningsHomeAhead)
    }

    private func endGame(_ reason: GameEndReason) {
        guard !isComplete else { return }
        isComplete = true
        endReason = reason
        endedAt = .now
    }

    // MARK: - Helpers

    public var leader: Leader {
        if awayScore > homeScore { return .away }
        if homeScore > awayScore { return .home }
        return .tied
    }

    public var displayInning: String {
        "\(half.symbol) \(inning)"
    }

    /// Build an immutable record for the history log.
    public func buildRecord(durationSeconds: TimeInterval) -> GameRecord {
        GameRecord(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt ?? .now,
            sport: settings.sport,
            awayTeamName: settings.awayTeamName,
            homeTeamName: settings.homeTeamName,
            awayScore: awayScore,
            homeScore: homeScore,
            lineScore: lineScore,
            endReason: endReason ?? .manual,
            durationSeconds: durationSeconds,
            noNewMinutes: settings.noNewInningsMinutes,
            cutoffMinutes: settings.ballGameCutoffMinutes
        )
    }
}
