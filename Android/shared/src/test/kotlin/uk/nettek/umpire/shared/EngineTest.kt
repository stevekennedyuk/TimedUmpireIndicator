package uk.nettek.umpire.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Rules from iOS/Shared/Models/GameState.swift, checked against the Kotlin port. */
class EngineTest {
    private var now = 1_000_000L
    private fun game(s: GameSettings = GameSettings()) = GameState(s, clock = { now })

    /** Play a half: three outs then enter runs. */
    private fun GameState.half(runs: Int, noNew: Boolean = false, cutoff: Boolean = false) {
        repeat(settings.maxOuts) { incrementOut() }
        assertTrue("runs entry should be pending", pendingRunsEntry)
        confirmRunsForCompletedHalf(runs, noNew, cutoff)
    }

    private fun GameState.inning(away: Int, home: Int) { half(away); half(home) }

    @Test fun fourthBallIsAWalkAndResetsTheCount() {
        val g = game()
        g.incrementStrike()
        repeat(3) { g.incrementBall() }
        assertEquals(3, g.balls)
        g.incrementBall()
        assertEquals(0, g.balls); assertEquals(0, g.strikes); assertEquals(0, g.outs)
    }

    @Test fun thirdStrikeIsAnOutAndEveryOutResetsTheCount() {
        val g = game()
        g.incrementBall(); g.incrementBall()
        repeat(3) { g.incrementStrike() }
        assertEquals(1, g.outs); assertEquals(0, g.balls); assertEquals(0, g.strikes)
        g.incrementBall(); g.incrementStrike(); g.incrementOut()
        assertEquals(2, g.outs); assertEquals(0, g.balls); assertEquals(0, g.strikes)
    }

    @Test fun thirdOutAsksForRunsAndLocksTheCount() {
        val g = game()
        repeat(3) { g.incrementOut() }
        assertTrue(g.pendingRunsEntry)
        g.incrementBall()
        assertEquals(0, g.balls)
        g.confirmRunsForCompletedHalf(2, false, false)
        assertEquals(2, g.awayScore); assertEquals(Half.BOTTOM, g.half); assertEquals(0, g.outs)
        assertEquals(listOf(InningRuns(1, top = 2)), g.lineScore)
    }

    @Test fun softballEndsAfterSeventhWithALeader() {
        val g = game()
        repeat(6) { g.inning(0, 0) }
        g.half(1); assertFalse(g.isComplete)
        g.half(0)
        assertTrue(g.isComplete); assertEquals(GameEndReason.REGULATION_COMPLETE, g.endReason)
    }

    @Test fun homeAheadAfterTopOfLastInningEndsIt() {
        val g = game()
        repeat(6) { g.inning(0, if (it == 0) 1 else 0) }
        g.half(0)
        assertTrue(g.isComplete); assertEquals(GameEndReason.REGULATION_COMPLETE, g.endReason)
    }

    @Test fun tieAtRegulationGoesToExtras() {
        val g = game()
        repeat(7) { g.inning(0, 0) }
        assertFalse(g.isComplete); assertEquals(8, g.inning)
        g.inning(1, 0)
        assertTrue(g.isComplete)
    }

    @Test fun baseballRegulationIsNine() {
        val g = game(GameSettings(sport = Sport.BASEBALL, runAheadEnabled = false))
        repeat(7) { g.inning(1, 0) }
        assertFalse(g.isComplete)
        g.inning(0, 0); g.half(0); assertFalse(g.isComplete)
        g.half(0); assertTrue(g.isComplete)
    }

    // ---------------------------------------------------------------- run-ahead

    @Test fun softballRunAheadAfterFourthBottom() {
        val g = game()
        repeat(3) { g.inning(0, 0) }
        g.half(20); assertFalse("top half: Away lead never ends it", g.isComplete)
        g.half(0)
        assertTrue(g.isComplete); assertEquals(GameEndReason.RUN_AHEAD, g.endReason)
    }

    @Test fun twentyNotEnoughBeforeTheFourth() {
        val g = game()
        g.inning(25, 0); g.inning(0, 0); g.inning(0, 0)
        assertFalse(g.isComplete)
    }

    @Test fun fifteenFromTheFifth() {
        val g = game()
        repeat(4) { g.inning(0, 0) }
        g.half(14); g.half(0); assertFalse(g.isComplete)
        g.half(1); g.half(0)
        assertTrue(g.isComplete); assertEquals(GameEndReason.RUN_AHEAD, g.endReason)
    }

    @Test fun homeLeadAfterTopHalfEndsAtFourAndAHalf() {
        val g = game()
        g.inning(0, 20); g.inning(0, 0); g.inning(0, 0)
        assertFalse("inning 3 margin is off", g.isComplete)
        g.half(0)
        assertTrue(g.isComplete); assertEquals(GameEndReason.RUN_AHEAD, g.endReason)
        assertEquals(Half.TOP, g.half); assertEquals(4, g.inning)
    }

    @Test fun zeroMarginTurnsTheRuleOffForThatInning() {
        val s = GameSettings().withRunAheadMargin(Sport.SOFTBALL, 4, 0)
        val g = game(s)
        repeat(3) { g.inning(0, 0) }
        g.inning(30, 0)
        assertFalse(g.isComplete)
    }

    @Test fun customTableAndExtrasReuseLastEntry() {
        val s = GameSettings(runAheadMarginsSoftball = listOf(0, 0, 25, 20, 15, 10, 5))
        assertEquals(25, s.runAheadMargin(3)); assertEquals(5, s.runAheadMargin(7))
        assertEquals(5, s.runAheadMargin(12)); assertNull(s.runAheadMargin(1))
        assertNull(s.copy(runAheadEnabled = false).runAheadMargin(4))
    }

    @Test fun wbscBaseballDefaults() {
        val s = GameSettings(sport = Sport.BASEBALL)
        assertNull(s.runAheadMargin(4)); assertEquals(15, s.runAheadMargin(5)); assertEquals(10, s.runAheadMargin(7))
        assertEquals("15+@5–6 · 10+@7+", s.runAheadSummary())
        assertEquals("20+@4 · 15+@5+", GameSettings().runAheadSummary())
        assertEquals("Off", GameSettings(runAheadMarginsSoftball = List(7) { 0 }).runAheadSummary())
    }

    // ---------------------------------------------------------------- timers

    @Test fun noNewWithHomeAheadEndsAtHalfEnd() {
        val g = game()
        g.half(0); g.half(1, noNew = true)
        assertTrue(g.isComplete); assertEquals(GameEndReason.NO_NEW_INNINGS_HOME_AHEAD, g.endReason)
    }

    @Test fun dropDeadRevertsToLastCompletedInning() {
        val g = game()
        g.inning(2, 1)            // 2–1
        g.inning(0, 1)            // 2–2
        g.half(3, cutoff = true)  // top 3 incomplete inning → revert to end of 2
        assertTrue(g.isComplete); assertEquals(GameEndReason.BALL_GAME_CUTOFF, g.endReason)
        assertEquals(2, g.awayScore); assertEquals(2, g.homeScore)
        assertEquals(2, g.lineScore.size)
    }

    @Test fun dropDeadFinalsWalkBackToALeader() {
        val g = game(GameSettings(allowTies = false))
        g.inning(2, 1); g.inning(0, 1)
        val preview = g.dropDeadPreview()
        assertEquals(DropDeadPreview(2, 1, 1, false), preview)
        assertEquals(DropDeadPreview(2, 2, 2, true), g.dropDeadPreview(allowTies = true))
        g.endAtDropDead()
        assertEquals(2, g.awayScore); assertEquals(1, g.homeScore); assertEquals(1, g.lineScore.size)
    }

    @Test fun homeBattingAheadAtCutoffScoreStands() {
        val g = game()
        g.inning(1, 0); g.half(0)
        g.incrementOut() // mid bottom 2, but score known only per half: give home a lead first
        assertFalse(g.homeWinsOnCutoff)
        val h = game()
        h.inning(0, 2); h.half(1)       // 1–2, bottom of 2nd in progress
        assertTrue(h.homeWinsOnCutoff)
        h.endAtDropDead()
        assertEquals(1, h.awayScore); assertEquals(2, h.homeScore)
    }

    // ---------------------------------------------------------------- undo

    @Test fun undoRevertsAMistakenWalk() {
        val g = game()
        repeat(3) { g.incrementBall() }
        g.incrementBall()
        assertEquals(0, g.balls)
        g.undoLast()
        assertEquals(3, g.balls)
    }

    @Test fun strikeoutIsOneUndoStep() {
        val g = game()
        repeat(2) { g.incrementStrike() }
        g.incrementStrike()
        assertEquals(1, g.outs)
        g.undoLast()
        assertEquals(0, g.outs); assertEquals(2, g.strikes)
    }

    @Test fun undoAcrossAHalfInningAdvance() {
        val g = game()
        g.half(3)
        assertEquals(Half.BOTTOM, g.half); assertEquals(3, g.awayScore)
        g.undoLast()                    // undo the runs entry
        assertTrue(g.pendingRunsEntry); assertEquals(0, g.awayScore); assertEquals(Half.TOP, g.half)
        g.undoLast()                    // undo the third out
        assertFalse(g.pendingRunsEntry); assertEquals(2, g.outs)
    }

    @Test fun noUndoOnceComplete() {
        val g = game()
        g.incrementBall(); g.endManually()
        assertFalse(g.canUndo)
    }

    // ---------------------------------------------------------------- indicator only

    @Test fun indicatorOnlyStopsAtEndOfRegulation() {
        val g = game(GameSettings(keepScore = false))
        repeat(13) { repeat(3) { g.incrementOut() } }
        assertEquals(7, g.inning); assertEquals(Half.BOTTOM, g.half)
        repeat(3) { g.incrementOut() }
        assertTrue(g.pendingRegulationEnd)
        g.continueToExtraInnings()
        assertEquals(8, g.inning)
        g.undoLast()
        assertTrue(g.pendingRegulationEnd)
        g.confirmRegulationEnd()
        assertTrue(g.isComplete)
    }

    // ---------------------------------------------------------------- settings

    @Test fun setupOverridesExpireAfterIdleGap() {
        val main = GameSettings()
        val last = GameSettings(noNewInningsMinutes = 10, ballGameCutoffMinutes = 15, inactivityTimeoutMinutes = 20)
        assertEquals(last, setupDefaults(main, last, now, now + 19 * 60_000))
        assertEquals(main, setupDefaults(main, last, now, now + 21 * 60_000))
        assertEquals(main, setupDefaults(main, null, 0, now))
    }

    @Test fun settingsSurviveJsonAndOldJsonLoads() {
        val s = GameSettings(sport = Sport.BASEBALL, useTimers = false)
        assertEquals(s, UmpireJson.decodeFromString(GameSettings.serializer(), UmpireJson.encodeToString(GameSettings.serializer(), s)))
        val old = UmpireJson.decodeFromString(GameSettings.serializer(), """{"sport":"softball","noNewInningsMinutes":50,"somethingNew":1}""")
        assertEquals(50, old.noNewInningsMinutes); assertTrue(old.useTimers)
        assertEquals(GameSettings.DEFAULT_RUN_AHEAD_SOFTBALL, old.runAheadMarginsSoftball)
    }

    @Test fun clockFormat() {
        assertEquals("00:00", formatClock(0.0))
        assertEquals("54:59", formatClock(3299.9))
        assertEquals("75:00", formatClock(4500.0))
    }
}
