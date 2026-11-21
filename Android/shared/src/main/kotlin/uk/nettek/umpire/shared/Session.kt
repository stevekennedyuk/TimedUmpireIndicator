package uk.nettek.umpire.shared

/** Which tournament threshold just fired. */
enum class ThresholdKind { NO_NEW, CUTOFF }

/** The platform side of a session: buzzing, background alerts, history. All optional. */
interface SessionFeedback {
    /** A threshold was crossed while the app is running: burst-vibrate. */
    fun threshold(kind: ThresholdKind) {}
    /** Schedule background alerts at these epoch-ms times (null = none). Replaces any earlier ones. */
    fun scheduleAlerts(noNewAt: Long?, cutoffAt: Long?) {}
    fun cancelAlerts() {}
    /** The umpire has seen the cutoff: drop the follow-up ping. */
    fun cancelCutoffFollowUp() {}
    /** A game started (true) or the session went idle (false): keep the screen on while true. */
    fun gameActiveChanged(active: Boolean) {}
    /** A kept-score game finished: add it to History (phone) or send it to the phone (watch). */
    fun gameRecorded(record: GameRecord) {}
}

/**
 * One umpiring session: the active game, its clock, and the per-second rules
 * that iOS runs in GameView (phone) and ContentView (watch). Both Android apps
 * share this, so the timing rules are written once and covered by tests.
 *
 * Call [tick] about once a second. Read state after [onChange] fires.
 */
class Session(
    private val feedback: SessionFeedback = object : SessionFeedback {},
    /** Settings for the fresh, idle game shown after teardown. */
    private val idleSettings: () -> GameSettings = { GameSettings() },
    private val clock: () -> Long = System::currentTimeMillis,
) {
    var onChange: () -> Unit = {}

    var game: GameState = GameState(idleSettings(), clock = clock); private set
    var timer: GameTimer = newTimer(game.settings); private set
    var hasStarted = false; private set

    /** Full-screen flash to show, until dismissed (auto after a few seconds). */
    var flash: ThresholdKind? = null; private set
    /** The drop-dead decision dialog is up. */
    var showDropDead = false; private set
    /** The game-over summary is up; acknowledging it tears the session down. */
    var showGameOver = false; private set

    private var noNewAlertFired = false
    private var cutoffAlertFired = false
    private var completionHandled = false

    val isLive: Boolean get() = hasStarted && !game.isComplete

    private fun newTimer(s: GameSettings) = GameTimer(s.noNewInningsMinutes, s.ballGameCutoffMinutes)

    private fun changed() = onChange()

    // ---------------------------------------------------------------- lifecycle

    fun start(settings: GameSettings) {
        val s = settings.normalised()
        val now = clock()
        game = GameState(s, clock = clock)
        timer = newTimer(s).also { it.start(now) }
        hasStarted = true
        noNewAlertFired = false
        cutoffAlertFired = false
        completionHandled = false
        flash = null
        showDropDead = false
        showGameOver = false
        // Background-safe alerts for when the screen is off or the app is in the
        // background. Untimed games have no thresholds.
        if (s.useTimers) feedback.scheduleAlerts(now + timer.noNewInningsMs, now + timer.ballGameCutoffMs)
        feedback.gameActiveChanged(true)
        changed()
    }

    /** Back to idle with a fresh game (after the game-over summary, or idle auto-close). */
    fun teardown() {
        timer.reset()
        feedback.cancelAlerts()
        hasStarted = false
        noNewAlertFired = false
        cutoffAlertFired = false
        completionHandled = false
        flash = null
        showDropDead = false
        showGameOver = false
        // Tell the platform first: the phone refreshes its "last game" time here,
        // which the idle settings below depend on.
        feedback.gameActiveChanged(false)
        game = GameState(idleSettings(), clock = clock)
        timer = newTimer(game.settings)
        changed()
    }

    /** Refresh the idle game's settings (e.g. new defaults arrived) without disturbing a live game. */
    fun refreshIdle() {
        if (isLive) return
        if (!hasStarted) {
            game = GameState(idleSettings(), clock = clock)
            timer = newTimer(game.settings)
            changed()
        }
    }

    // ---------------------------------------------------------------- the clock

    fun tick() {
        val now = clock()
        timer.tick(now)
        if (!isLive) { changed(); return }
        val s = game.settings
        // Untimed: no thresholds, alerts, cutoff or idle-close — elapsed time only.
        if (!s.useTimers) { changed(); return }

        // Threshold alerts: a burst of vibration plus the full-screen flash, once each.
        if (!noNewAlertFired && timer.isNoNewInningsTriggered) {
            noNewAlertFired = true
            flash = ThresholdKind.NO_NEW
            feedback.threshold(ThresholdKind.NO_NEW)
        }
        if (!cutoffAlertFired && timer.isCutoffTriggered) {
            cutoffAlertFired = true
            flash = ThresholdKind.CUTOFF
            feedback.threshold(ThresholdKind.CUTOFF)
            feedback.cancelCutoffFollowUp() // the umpire is looking at it
        }

        if (!game.pendingRunsEntry) {
            when {
                // Idle auto-close, once past no-new.
                s.autoCloseOnInactivity && timer.isNoNewInningsTriggered &&
                    game.secondsSinceActivity(now) >= s.inactivityTimeoutMinutes * 60.0 ->
                    game.endForInactivity()
                // Drop-dead: ask the umpire.
                timer.isCutoffTriggered && !game.dropDeadOverridden && s.enforceDropDead ->
                    showDropDead = true
                // No-new with Home ahead ends the game.
                s.keepScore && timer.isNoNewInningsTriggered && game.leader == Leader.HOME ->
                    game.endForNoNewInningsHomeLeads()
            }
        }
        handleCompletion()
        changed()
    }

    fun togglePause() {
        if (timer.startedAt == null) return
        val now = clock()
        if (timer.isPaused) timer.resume(now) else timer.pause(now)
        if (isLive && game.settings.useTimers) {
            if (timer.isPaused) {
                // Wall-clock alerts would fire at the wrong moment while paused.
                feedback.cancelAlerts()
            } else {
                feedback.scheduleAlerts(
                    timer.msUntilNoNew?.let { now + it },
                    timer.msUntilCutoff?.let { now + it },
                )
            }
        }
        changed()
    }

    // ---------------------------------------------------------------- umpire actions

    /** Run a game action, then apply any game end it caused. */
    fun act(block: GameState.() -> Unit) {
        game.block()
        handleCompletion()
        changed()
    }

    fun confirmRuns(runs: Int) = act {
        confirmRunsForCompletedHalf(runs, timer.isNoNewInningsTriggered, timer.isCutoffTriggered)
    }

    fun dismissFlash() {
        flash = null
        changed()
    }

    /** "Play on" at the drop-dead prompt: the cutoff is ignored for the rest of the game. */
    fun playOn() {
        game.registerActivity()
        game.dropDeadOverridden = true
        showDropDead = false
        feedback.cancelCutoffFollowUp()
        changed()
    }

    fun endAtDropDead(allowTiesOverride: Boolean? = null) {
        showDropDead = false
        act { endAtDropDead(allowTiesOverride) }
    }

    /** The umpire has read the game-over summary. */
    fun acknowledgeGameOver() = teardown()

    private fun handleCompletion() {
        if (!game.isComplete || completionHandled) return
        completionHandled = true
        val now = clock()
        timer.pause(now)
        feedback.cancelAlerts()
        showDropDead = false
        if (game.settings.keepScore) feedback.gameRecorded(game.buildRecord(timer.elapsed))
        if (game.endReason == GameEndReason.INACTIVITY) {
            // Nobody is watching: don't hold a summary open.
            teardown()
        } else {
            showGameOver = true
        }
    }
}
