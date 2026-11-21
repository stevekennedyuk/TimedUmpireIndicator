package uk.nettek.umpire

import android.app.Application
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uk.nettek.umpire.shared.GameRecord
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.Session
import uk.nettek.umpire.shared.SessionFeedback
import uk.nettek.umpire.shared.ThresholdKind
import uk.nettek.umpire.shared.setupDefaults

class UmpireApp : Application() {
    lateinit var state: AppState
        private set

    override fun onCreate() {
        super.onCreate()
        state = AppState(this)
    }
}

/**
 * Owns the session, settings and History, and supplies the platform side:
 * vibration, background alerts and watch sync. Compose reads [revision] to
 * redraw whenever the session changes.
 */
class AppState(private val app: Application) : SessionFeedback {
    private val store = Store(app)

    /** The Settings tab: defaults for new games, and what's sent to the watch. */
    var mainSettings: GameSettings by mutableStateOf(store.mainSettings)
        private set
    var history: List<GameRecord> by mutableStateOf(store.loadHistory())
        private set

    /** Bumped on every session change; read it to recompose. */
    var revision by mutableIntStateOf(0)
        private set

    /** True while a game is live: the screen is kept on. */
    var keepAwake by mutableStateOf(false)
        private set

    /** When settings were last sent to the watch (null = not this run). */
    var lastSentAt: Long? by mutableStateOf(null)
        private set

    /** Set by the activity; alerts are only posted as notifications in the background. */
    var inForeground = false

    /** Tests only: moves the session clock forward without waiting. */
    internal var clockSkewMs = 0L

    val session = Session(this, { setupDefaults() }, { System.currentTimeMillis() + clockSkewMs })

    private val vibrator: Vibrator? = app.getSystemService(Vibrator::class.java)
    private val scope = MainScope()

    init {
        session.onChange = { revision++ }
        Alerts.createChannel(app)
        scope.launch {
            while (true) {
                session.tick()
                delay(250)
            }
        }
    }

    /**
     * Defaults for the New Game sheet: the last game's settings while games run
     * back to back (per-game overrides persist), reverting to the Settings tab
     * once the gap since the last game passes that game's idle limit.
     */
    fun setupDefaults(): GameSettings =
        setupDefaults(mainSettings, store.lastGameSettings, store.lastGameAt, System.currentTimeMillis())

    fun startGame(settings: GameSettings) {
        store.lastGameSettings = settings.normalised()
        store.lastGameAt = System.currentTimeMillis()
        session.start(settings)
    }

    fun updateMainSettings(settings: GameSettings) {
        mainSettings = settings.normalised()
        store.mainSettings = mainSettings
        session.refreshIdle()
    }

    fun sendSettingsToWatch() {
        WearSync.sendSettings(app, mainSettings)
        lastSentAt = System.currentTimeMillis()
    }

    fun addRecord(record: GameRecord) {
        history = (listOf(record) + history.filterNot { it.id == record.id }).sortedByDescending { it.startedAt }
        store.saveHistory(history)
    }

    fun deleteRecord(record: GameRecord) {
        history = history.filterNot { it.id == record.id }
        store.saveHistory(history)
    }

    // ---- vibration

    private fun buzz(vararg pattern: Long) {
        runCatching { vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1)) }
    }

    /** A click for each count tap; softer for long-press decrements. */
    fun tapFeedback(decrement: Boolean = false) {
        runCatching {
            vibrator?.vibrate(VibrationEffect.createOneShot(if (decrement) 15 else 25, if (decrement) 120 else 200))
        }
    }

    // ---- SessionFeedback

    override fun threshold(kind: ThresholdKind) = when (kind) {
        // Three firm pulses at no-new; four long, hard ones at drop-dead.
        ThresholdKind.NO_NEW -> buzz(0, 250, 200, 250, 200, 250)
        ThresholdKind.CUTOFF -> buzz(0, 500, 200, 500, 200, 500, 200, 500)
    }

    override fun scheduleAlerts(noNewAt: Long?, cutoffAt: Long?) = Alerts.schedule(app, noNewAt, cutoffAt)
    override fun cancelAlerts() = Alerts.cancel(app)
    override fun cancelCutoffFollowUp() = Alerts.cancelCutoffFollowUp(app)

    override fun gameActiveChanged(active: Boolean) {
        keepAwake = active
        // The override expiry is measured from the END of the last game.
        if (!active && store.lastGameAt > 0) store.lastGameAt = System.currentTimeMillis()
    }

    override fun gameRecorded(record: GameRecord) = addRecord(record)
}
