package uk.nettek.umpire.shared

import java.util.UUID

/**
 * Active in-game state and the rules engine — the twin of
 * iOS/Shared/Models/GameState.swift, rule for rule.
 *
 * [clock] returns the current epoch milliseconds (tests pass a fake).
 */
class GameState(
    var settings: GameSettings = GameSettings(),
    val id: String = UUID.randomUUID().toString(),
    private val clock: () -> Long = System::currentTimeMillis,
) {
    val startedAt: Long = clock()

    // Count
    var balls = 0; private set
    var strikes = 0; private set
    var outs = 0; private set

    // Inning
    var inning = 1; private set
    var half = Half.TOP; private set

    // Score
    var awayScore = 0; private set
    var homeScore = 0; private set
    var lineScore: List<InningRuns> = emptyList(); private set
    var halfHistory: List<ScoreSnapshot> = emptyList(); private set

    /** True after a third out (keep-score mode) until the umpire enters the half's runs. */
    var pendingRunsEntry = false; private set

    /** Indicator-only mode: bottom of regulation done; the umpire chooses end or extras. */
    var pendingRegulationEnd = false; private set

    // End of game
    var isComplete = false; private set
    var endReason: GameEndReason? = null; private set
    var endedAt: Long? = null; private set

    /** Set by "Play on" at the drop-dead prompt: the cutoff no longer ends the game. */
    var dropDeadOverridden = false

    // ---------------------------------------------------------------- inactivity

    var lastActivityAt: Long = clock(); private set

    fun registerActivity() {
        lastActivityAt = clock()
    }

    fun secondsSinceActivity(now: Long = clock()): Double = (now - lastActivityAt) / 1000.0

    // ---------------------------------------------------------------- undo

    private data class UndoSnapshot(
        val balls: Int, val strikes: Int, val outs: Int,
        val inning: Int, val half: Half,
        val awayScore: Int, val homeScore: Int,
        val lineScore: List<InningRuns>, val halfHistory: List<ScoreSnapshot>,
        val pendingRunsEntry: Boolean, val pendingRegulationEnd: Boolean,
    )

    private val undoStack = ArrayDeque<UndoSnapshot>()

    /** Stops nested mutators (3rd strike → out) pushing a second snapshot for one action. */
    private var undoGrouping = false

    private fun pushUndo() {
        if (undoGrouping) return
        undoStack.addLast(
            UndoSnapshot(
                balls, strikes, outs, inning, half, awayScore, homeScore,
                lineScore, halfHistory, pendingRunsEntry, pendingRegulationEnd,
            )
        )
        if (undoStack.size > 30) undoStack.removeFirst()
    }

    private inline fun grouped(block: () -> Unit) {
        pushUndo()
        val wasGrouping = undoGrouping
        undoGrouping = true
        try { block() } finally { undoGrouping = wasGrouping }
    }

    val canUndo: Boolean get() = undoStack.isNotEmpty() && !isComplete

    /** Revert the last umpire action exactly — even across a count reset or a half/inning advance. */
    fun undoLast() {
        if (isComplete) return
        val s = undoStack.removeLastOrNull() ?: return
        registerActivity()
        balls = s.balls; strikes = s.strikes; outs = s.outs
        inning = s.inning; half = s.half
        awayScore = s.awayScore; homeScore = s.homeScore
        lineScore = s.lineScore; halfHistory = s.halfHistory
        pendingRunsEntry = s.pendingRunsEntry
        pendingRegulationEnd = s.pendingRegulationEnd
    }

    // ---------------------------------------------------------------- pitch counting

    private val canEdit: Boolean get() = !isComplete && !pendingRunsEntry && !pendingRegulationEnd

    /** On the 4th ball the count resets (walk). */
    fun incrementBall() {
        if (!canEdit) return
        pushUndo()
        registerActivity()
        balls += 1
        if (balls >= settings.maxBalls) {
            balls = 0
            strikes = 0
        }
    }

    fun decrementBall() {
        if (!canEdit) return
        pushUndo()
        registerActivity()
        balls = maxOf(0, balls - 1)
    }

    /** On the 3rd strike the count resets and an out is recorded. */
    fun incrementStrike() {
        if (!canEdit) return
        grouped {
            registerActivity()
            strikes += 1
            if (strikes >= settings.maxStrikes) {
                balls = 0
                strikes = 0
                incrementOut()
            }
        }
    }

    fun decrementStrike() {
        if (!canEdit) return
        pushUndo()
        registerActivity()
        strikes = maxOf(0, strikes - 1)
    }

    /** A new batter is up after every out, so the count always resets. The third
     *  out ends the half: runs entry (keep score) or straight on (indicator only). */
    fun incrementOut() {
        if (!canEdit) return
        grouped {
            registerActivity()
            outs += 1
            balls = 0
            strikes = 0
            if (outs >= settings.maxOuts) {
                if (settings.keepScore) {
                    pendingRunsEntry = true
                } else {
                    outs = 0
                    if (half == Half.BOTTOM && inning >= settings.sport.regulationInnings) {
                        pendingRegulationEnd = true
                    } else {
                        advanceHalf()
                    }
                }
            }
        }
    }

    fun decrementOut() {
        if (!canEdit) return
        pushUndo()
        registerActivity()
        if (pendingRunsEntry) pendingRunsEntry = false
        outs = maxOf(0, outs - 1)
    }

    /** End the half early (walk-off, or any early end). */
    fun forceEndOfHalf() {
        if (isComplete || pendingRunsEntry || pendingRegulationEnd) return
        grouped {
            if (settings.keepScore) {
                pendingRunsEntry = true
            } else {
                balls = 0; strikes = 0; outs = 0
                if (half == Half.BOTTOM && inning >= settings.sport.regulationInnings) {
                    pendingRegulationEnd = true
                } else {
                    advanceHalf()
                }
            }
        }
    }

    /** Indicator-only: the umpire confirmed the game is over at the end of regulation. */
    fun confirmRegulationEnd() {
        if (!pendingRegulationEnd) return
        registerActivity()
        pendingRegulationEnd = false
        endGame(GameEndReason.REGULATION_COMPLETE)
    }

    /** Indicator-only: tied — play extra innings. */
    fun continueToExtraInnings() {
        if (!pendingRegulationEnd) return
        grouped {
            registerActivity()
            pendingRegulationEnd = false
            advanceHalf()
        }
    }

    // ---------------------------------------------------------------- half-inning rollover

    /** Record the runs for the half that just ended, apply the end-of-game rules, then advance. */
    fun confirmRunsForCompletedHalf(runs: Int, noNewInningsTriggered: Boolean, cutoffTriggered: Boolean) {
        if (!pendingRunsEntry) return
        grouped {
            registerActivity()
            val r = maxOf(0, runs)
            upsertLineScore(inning, half, r)
            if (half == Half.TOP) awayScore += r else homeScore += r
            halfHistory = halfHistory + ScoreSnapshot(inning, half, awayScore, homeScore)

            balls = 0; strikes = 0; outs = 0
            pendingRunsEntry = false

            // Run-ahead: the result stands on runs alone, so it's checked first.
            if (runAheadSatisfied(half, inning)) {
                endGame(GameEndReason.RUN_AHEAD)
                return@grouped
            }
            if (cutoffTriggered && !dropDeadOverridden && settings.enforceDropDead) {
                applyDropDead()
                return@grouped
            }
            if (evaluateEndOfGame(noNewInningsTriggered)) return@grouped
            advanceHalf()
        }
    }

    private fun upsertLineScore(inning: Int, half: Half, runs: Int) {
        val idx = lineScore.indexOfFirst { it.inning == inning }
        val entry = if (idx >= 0) lineScore[idx] else InningRuns(inning)
        val updated = if (half == Half.TOP) entry.copy(top = runs) else entry.copy(bottom = runs)
        lineScore = if (idx >= 0) lineScore.toMutableList().also { it[idx] = updated } else lineScore + updated
    }

    private fun advanceHalf() {
        if (half == Half.TOP) {
            half = Half.BOTTOM
        } else {
            half = Half.TOP
            inning += 1
        }
    }

    // ---------------------------------------------------------------- end-of-game rules

    /**
     * Run-ahead uses the just-completed inning's margin (0 = off that inning).
     * After the BOTTOM half either team can win by the margin; after the TOP half
     * only HOME can — they lead without needing to bat (the "4½ innings" finish).
     */
    private fun runAheadSatisfied(half: Half, inning: Int): Boolean {
        if (!settings.keepScore) return false
        val threshold = settings.runAheadMargin(inning) ?: return false
        if (kotlin.math.abs(awayScore - homeScore) < threshold) return false
        return half == Half.BOTTOM || leader == Leader.HOME
    }

    private fun evaluateEndOfGame(noNewInningsTriggered: Boolean): Boolean {
        val last = halfHistory.lastOrNull() ?: return false
        val regulation = settings.sport.regulationInnings

        // 1. Bottom of regulation+ finished with a leader.
        if (last.half == Half.BOTTOM && last.inning >= regulation && last.leader != Leader.TIED) {
            endGame(GameEndReason.REGULATION_COMPLETE); return true
        }
        // 2. Top of regulation+ finished with Home ahead — Home needn't bat.
        if (last.half == Half.TOP && last.inning >= regulation && last.leader == Leader.HOME) {
            endGame(GameEndReason.REGULATION_COMPLETE); return true
        }
        // 3. No-new has fired and Home leads.
        if (noNewInningsTriggered && last.leader == Leader.HOME) {
            endGame(GameEndReason.NO_NEW_INNINGS_HOME_AHEAD); return true
        }
        // 4. No-new past regulation: no new inning can start, so a tie stands.
        if (noNewInningsTriggered && last.half == Half.BOTTOM && last.inning >= regulation) {
            endGame(GameEndReason.REGULATION_COMPLETE); return true
        }
        return false
    }

    /** Snapshots at the end of each completed inning (bottom half recorded). */
    private fun completedInningSnapshots() = halfHistory.filter { it.half == Half.BOTTOM }

    private fun dropDeadTarget(allowTies: Boolean): ScoreSnapshot? {
        val snapshots = completedInningSnapshots()
        return if (allowTies) snapshots.lastOrNull()
        else snapshots.lastOrNull { it.leader != Leader.TIED } ?: snapshots.lastOrNull()
    }

    /**
     * Drop-dead: the inning in progress is incomplete, so revert to the last
     * COMPLETED inning. Finals (no ties) walk back to the last completed inning
     * with a leader; if none exists a tie is unavoidable.
     */
    fun applyDropDead(allowTies: Boolean? = null) {
        val snap = dropDeadTarget(allowTies ?: settings.allowTies)
        if (snap != null) {
            awayScore = snap.awayScore
            homeScore = snap.homeScore
            lineScore = lineScore.mapNotNull { e ->
                when {
                    e.inning < snap.inning -> e
                    e.inning == snap.inning -> if (snap.half == Half.TOP) e.copy(bottom = null) else e
                    else -> null
                }
            }
            val idx = halfHistory.indexOfLast { it.inning == snap.inning && it.half == snap.half }
            if (idx >= 0) halfHistory = halfHistory.take(idx + 1)
        } else {
            awayScore = 0; homeScore = 0
            lineScore = emptyList(); halfHistory = emptyList()
        }
        endGame(GameEndReason.BALL_GAME_CUTOFF)
    }

    /** What the revert WOULD produce, so the dialog can show it first. */
    fun dropDeadPreview(allowTies: Boolean? = null): DropDeadPreview {
        val snap = dropDeadTarget(allowTies ?: settings.allowTies)
            ?: return DropDeadPreview(0, 0, null, true)
        return DropDeadPreview(snap.awayScore, snap.homeScore, snap.inning, snap.leader == Leader.TIED)
    }

    /** Cutoff landed while Home is batting and ahead: the score stands. */
    val homeWinsOnCutoff: Boolean get() = half == Half.BOTTOM && leader == Leader.HOME

    /** The umpire confirmed ending at drop-dead. */
    fun endAtDropDead(allowTiesOverride: Boolean? = null) {
        if (isComplete) return
        if (!settings.keepScore) {
            endGame(GameEndReason.BALL_GAME_CUTOFF); return
        }
        if (homeWinsOnCutoff) {
            pendingRunsEntry = false
            endGame(GameEndReason.BALL_GAME_CUTOFF); return
        }
        applyDropDead(allowTiesOverride)
    }

    fun endManually() = endGame(GameEndReason.MANUAL)
    fun endForNoNewInningsHomeLeads() = endGame(GameEndReason.NO_NEW_INNINGS_HOME_AHEAD)
    fun endForInactivity() = endGame(GameEndReason.INACTIVITY)

    private fun endGame(reason: GameEndReason) {
        if (isComplete) return
        isComplete = true
        endReason = reason
        endedAt = clock()
    }

    // ---------------------------------------------------------------- helpers

    val leader: Leader
        get() = when {
            awayScore > homeScore -> Leader.AWAY
            homeScore > awayScore -> Leader.HOME
            else -> Leader.TIED
        }

    fun buildRecord(durationSeconds: Double) = GameRecord(
        id = id,
        startedAt = startedAt,
        endedAt = endedAt ?: clock(),
        sport = settings.sport,
        awayTeamName = settings.awayTeamName,
        homeTeamName = settings.homeTeamName,
        awayScore = awayScore,
        homeScore = homeScore,
        lineScore = lineScore,
        endReason = endReason ?: GameEndReason.MANUAL,
        durationSeconds = durationSeconds,
        noNewMinutes = settings.noNewInningsMinutes,
        cutoffMinutes = settings.ballGameCutoffMinutes,
    )
}
