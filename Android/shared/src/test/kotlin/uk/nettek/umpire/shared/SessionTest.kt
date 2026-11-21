package uk.nettek.umpire.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The per-second rules iOS runs in GameView / the watch ContentView. */
class SessionTest {
    private var now = 1_000_000L
    private val events = mutableListOf<String>()
    private val records = mutableListOf<GameRecord>()

    private val feedback = object : SessionFeedback {
        override fun threshold(kind: ThresholdKind) { events += "threshold $kind" }
        override fun scheduleAlerts(noNewAt: Long?, cutoffAt: Long?) { events += "schedule ${noNewAt?.minus(now)} ${cutoffAt?.minus(now)}" }
        override fun cancelAlerts() { events += "cancel" }
        override fun cancelCutoffFollowUp() { events += "cancelFollowUp" }
        override fun gameActiveChanged(active: Boolean) { events += "active $active" }
        override fun gameRecorded(record: GameRecord) { records += record }
    }

    private fun session() = Session(feedback, { GameSettings() }, { now })
    private fun minutes(m: Int) { now += m * 60_000L }

    /** Pass time with the umpire tapping every minute, as in a real game. */
    private fun Session.play(m: Int) = repeat(m) { now += 60_000L; act { registerActivity() }; tick() }

    @Test fun startSchedulesBackgroundAlertsAndKeepsAwake() {
        val s = session()
        s.start(GameSettings(noNewInningsMinutes = 55, ballGameCutoffMinutes = 60))
        assertEquals(listOf("schedule 3300000 3600000", "active true"), events)
        assertTrue(s.isLive)
    }

    @Test fun untimedGameSchedulesNothingAndNeverPrompts() {
        val s = session()
        s.start(GameSettings(useTimers = false))
        minutes(500); s.tick()
        assertEquals(listOf("active true"), events)
        assertNull(s.flash); assertFalse(s.showDropDead); assertTrue(s.isLive)
        assertEquals("500:00", formatClock(s.timer.elapsed))
    }

    @Test fun thresholdsFireOnceEach() {
        val s = session()
        s.start(GameSettings())
        s.play(55); s.tick()
        assertEquals(ThresholdKind.NO_NEW, s.flash)
        s.play(5); s.tick()
        assertEquals(ThresholdKind.CUTOFF, s.flash)
        assertEquals(1, events.count { it == "threshold NO_NEW" })
        assertEquals(1, events.count { it == "threshold CUTOFF" })
        assertTrue("drop-dead prompt", s.showDropDead)
    }

    @Test fun playOnSilencesTheCutoff() {
        val s = session()
        s.start(GameSettings())
        s.play(61)
        s.playOn()
        s.play(1)
        assertFalse(s.showDropDead); assertTrue(s.isLive)
        assertEquals("+02:00", s.timer.activeCountdownText)
    }

    @Test fun advisoryDropDeadNeverPrompts() {
        val s = session()
        s.start(GameSettings(enforceDropDead = false))
        s.play(70)
        assertFalse(s.showDropDead)
    }

    @Test fun homeAheadAtNoNewEndsTheGameAndRecordsIt() {
        val s = session()
        s.start(GameSettings())
        s.act { repeat(3) { incrementOut() } }; s.confirmRuns(0)
        s.act { repeat(3) { incrementOut() } }; s.confirmRuns(2)
        s.play(55)
        assertTrue(s.game.isComplete)
        assertEquals(GameEndReason.NO_NEW_INNINGS_HOME_AHEAD, s.game.endReason)
        assertTrue(s.showGameOver)
        assertEquals(1, records.size); assertEquals(2, records[0].homeScore)
        assertEquals(55 * 60.0, records[0].durationSeconds, 0.001)
    }

    @Test fun idleAfterNoNewAutoClosesStraightToIdle() {
        val s = session()
        s.start(GameSettings(inactivityTimeoutMinutes = 20))
        s.play(55); assertTrue(s.isLive)                 // last tap at 55
        minutes(19); s.tick(); assertTrue(s.isLive)     // idle 19 min
        minutes(2); s.tick()                            // idle 21 min
        assertFalse(s.hasStarted); assertFalse(s.showGameOver)
        assertEquals(GameEndReason.INACTIVITY, records.single().endReason)
        assertEquals("active false", events.last())
    }

    @Test fun idleCloseCountsFromLastTapLikeIOS() {
        val s = session()
        s.start(GameSettings())
        minutes(55); s.tick()                           // nobody tapped for 55 min
        assertFalse(s.hasStarted)
    }

    @Test fun pauseCancelsAndResumeReschedulesRemainingTime() {
        val s = session()
        s.start(GameSettings())
        minutes(10); s.togglePause()
        minutes(30); s.togglePause()
        assertEquals(listOf("schedule 3300000 3600000", "active true", "cancel", "schedule 2700000 3000000"), events)
        s.tick(); assertEquals(600.0, s.timer.elapsed, 0.001)
    }

    @Test fun indicatorOnlyGamesAreNotRecorded() {
        val s = session()
        s.start(GameSettings(keepScore = false))
        s.act { endManually() }
        assertTrue(s.showGameOver); assertTrue(records.isEmpty())
        s.acknowledgeGameOver()
        assertFalse(s.hasStarted)
    }

    @Test fun dropDeadEndViaSession() {
        val s = session()
        s.start(GameSettings())
        s.act { repeat(3) { incrementOut() } }; s.confirmRuns(3)
        s.act { repeat(3) { incrementOut() } }; s.confirmRuns(1)
        s.play(60)
        assertTrue(s.showDropDead)
        s.endAtDropDead()
        assertFalse(s.showDropDead); assertTrue(s.showGameOver)
        assertEquals(GameEndReason.BALL_GAME_CUTOFF, records.single().endReason)
    }
}
