package uk.nettek.umpire.shared

/**
 * Wall-clock game timer with the two tournament thresholds — the twin of
 * iOS/Shared/Models/GameTimer.swift:
 *  - "No new innings": the current inning finishes, no new one starts; if Home
 *    leads the game ends now.
 *  - "Ball game" drop-dead: the game ends; the score reverts to the last
 *    completed inning.
 * All times are epoch milliseconds, passed in so tests can drive the clock.
 */
class GameTimer(
    var noNewInningsMinutes: Int = 55,
    var ballGameCutoffMinutes: Int = 60,
) {
    var startedAt: Long? = null
        private set
    var pausedAt: Long? = null
        private set

    /** Elapsed milliseconds, refreshed by [tick]. */
    var elapsedMs: Long = 0
        private set

    val elapsed: Double get() = elapsedMs / 1000.0
    val isRunning: Boolean get() = startedAt != null && pausedAt == null
    val isPaused: Boolean get() = pausedAt != null

    val noNewInningsMs: Long get() = noNewInningsMinutes * 60_000L
    val ballGameCutoffMs: Long get() = ballGameCutoffMinutes * 60_000L

    val isNoNewInningsTriggered: Boolean get() = elapsedMs >= noNewInningsMs
    val isCutoffTriggered: Boolean get() = elapsedMs >= ballGameCutoffMs

    enum class Phase(val label: String, val shortLabel: String) {
        NO_NEW("No New", "NO NEW"),
        BALL_GAME("Ball Game", "CUTOFF"),
        OVERTIME("OT", "OT"),
    }

    val phase: Phase
        get() = when {
            isCutoffTriggered -> Phase.OVERTIME
            isNoNewInningsTriggered -> Phase.BALL_GAME
            else -> Phase.NO_NEW
        }

    /** Seconds left in the current phase; in overtime, seconds past drop-dead. */
    val activeCountdown: Double
        get() = when (phase) {
            Phase.NO_NEW -> (noNewInningsMs - elapsedMs).coerceAtLeast(0) / 1000.0
            Phase.BALL_GAME -> (ballGameCutoffMs - elapsedMs).coerceAtLeast(0) / 1000.0
            Phase.OVERTIME -> (elapsedMs - ballGameCutoffMs).coerceAtLeast(0) / 1000.0
        }

    /** "MM:SS", prefixed with "+" in overtime. */
    val activeCountdownText: String
        get() = formatClock(activeCountdown).let { if (phase == Phase.OVERTIME) "+$it" else it }

    /** Milliseconds until no-new / drop-dead, or null once passed. */
    val msUntilNoNew: Long? get() = (noNewInningsMs - elapsedMs).takeIf { it > 0 }
    val msUntilCutoff: Long? get() = (ballGameCutoffMs - elapsedMs).takeIf { it > 0 }

    fun start(now: Long) {
        if (startedAt != null) return
        startedAt = now
        pausedAt = null
    }

    fun pause(now: Long) {
        if (!isRunning) return
        tick(now)
        pausedAt = now
    }

    fun resume(now: Long) {
        val paused = pausedAt ?: return
        val started = startedAt ?: return
        startedAt = started + (now - paused)
        pausedAt = null
        tick(now)
    }

    fun tick(now: Long) {
        val started = startedAt ?: return
        elapsedMs = ((pausedAt ?: now) - started).coerceAtLeast(0)
    }

    fun reset() {
        startedAt = null
        pausedAt = null
        elapsedMs = 0
    }
}
