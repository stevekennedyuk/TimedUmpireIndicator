package uk.nettek.umpire.wear

import android.app.AlarmManager
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import uk.nettek.umpire.shared.GameRecord
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.Session
import uk.nettek.umpire.shared.SessionFeedback
import uk.nettek.umpire.shared.ThresholdKind
import uk.nettek.umpire.shared.UmpireJson

class WearApp : Application() {
    lateinit var state: WearState
        private set

    override fun onCreate() {
        super.onCreate()
        state = WearState(this)
    }
}

/**
 * The watch session. Like the Apple Watch app, the last-used settings carry
 * from game to game, and settings sent from the phone replace them.
 */
class WearState(private val app: Application) : SessionFeedback {
    private val prefs = app.getSharedPreferences("umpire_watch", Context.MODE_PRIVATE)

    /** Last-used settings: what Setup shows and the next game starts with. */
    var settings: GameSettings by mutableStateOf(loadSettings())
        private set

    var revision by mutableIntStateOf(0)
        private set

    /** True while a game is live: the screen stays on, so the watch face doesn't take over. */
    var keepAwake by mutableStateOf(false)
        private set

    var inForeground = false

    /** Tests only: moves the session clock forward without waiting. */
    internal var clockSkewMs = 0L

    val session = Session(this, { settings }, { System.currentTimeMillis() + clockSkewMs })

    private val vibrator: Vibrator? = app.getSystemService(Vibrator::class.java)
    private val scope = MainScope()

    init {
        session.onChange = { revision++ }
        WatchAlerts.createChannel(app)
        scope.launch {
            while (true) {
                session.tick()
                delay(250)
            }
        }
    }

    private fun loadSettings(): GameSettings = prefs.getString("settings", null)
        ?.let { runCatching { UmpireJson.decodeFromString(GameSettings.serializer(), it) }.getOrNull() }
        ?.normalised() ?: GameSettings()

    private fun saveSettings(s: GameSettings) {
        settings = s.normalised()
        prefs.edit().putString("settings", UmpireJson.encodeToString(GameSettings.serializer(), settings)).apply()
    }

    fun startGame(s: GameSettings) {
        saveSettings(s)
        session.start(settings)
    }

    /** New defaults from the phone: keep them, and show them if no game is live. */
    fun receivePhoneSettings(s: GameSettings) {
        saveSettings(s)
        session.refreshIdle()
    }

    // ---- vibration

    private fun buzz(vararg pattern: Long) {
        runCatching { vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1)) }
    }

    fun tap(kind: Tap) = when (kind) {
        Tap.CLICK -> buzz(0, 25)
        Tap.UNDO -> buzz(0, 15, 60, 15)
        Tap.HALF_OVER -> buzz(0, 120, 80, 120)
    }

    enum class Tap { CLICK, UNDO, HALF_OVER }

    // ---- SessionFeedback

    override fun threshold(kind: ThresholdKind) = when (kind) {
        // Three firm taps at no-new; four long, hard ones at drop-dead.
        ThresholdKind.NO_NEW -> buzz(0, 300, 250, 300, 250, 300)
        ThresholdKind.CUTOFF -> buzz(0, 600, 250, 600, 250, 600, 250, 600)
    }

    override fun scheduleAlerts(noNewAt: Long?, cutoffAt: Long?) = WatchAlerts.schedule(app, noNewAt, cutoffAt)
    override fun cancelAlerts() = WatchAlerts.cancel(app)
    override fun cancelCutoffFollowUp() = WatchAlerts.cancelCutoffFollowUp(app)
    override fun gameActiveChanged(active: Boolean) { keepAwake = active }
    override fun gameRecorded(record: GameRecord) = WearSync.sendRecord(app, record)
}

// ---------------------------------------------------------------- background alerts

/** Vibrating notifications at no-new and drop-dead (plus a second drop-dead ping) for when the app isn't on screen. */
object WatchAlerts {
    private const val CHANNEL = "clock"
    private const val NO_NEW = 1
    private const val CUTOFF = 2
    private const val CUTOFF_REPEAT = 3

    fun createChannel(context: Context) {
        val channel = NotificationChannel(CHANNEL, "Tournament clock", NotificationManager.IMPORTANCE_HIGH).apply {
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 600, 250, 600, 250, 600)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun pending(context: Context, id: Int, title: String = "", text: String = ""): PendingIntent =
        PendingIntent.getBroadcast(
            context, id,
            Intent(context, AlertReceiver::class.java).putExtra("id", id).putExtra("title", title).putExtra("text", text),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun schedule(context: Context, noNewAt: Long?, cutoffAt: Long?) {
        cancel(context)
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        fun set(at: Long, intent: PendingIntent) {
            if (at <= System.currentTimeMillis() + 1000) return
            runCatching {
                if (exact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
                else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            }
        }
        noNewAt?.let { set(it, pending(context, NO_NEW, "No new innings", "Finish the current inning.")) }
        cutoffAt?.let {
            set(it, pending(context, CUTOFF, "Ball game — time!", "Drop-dead reached. Open Umpire."))
            set(it + 15_000, pending(context, CUTOFF_REPEAT, "Ball game — time!", "Drop-dead has passed."))
        }
    }

    fun cancel(context: Context) = listOf(NO_NEW, CUTOFF, CUTOFF_REPEAT).forEach { cancel(context, it) }
    fun cancelCutoffFollowUp(context: Context) = cancel(context, CUTOFF_REPEAT)

    private fun cancel(context: Context, id: Int) {
        context.getSystemService(AlarmManager::class.java)?.cancel(pending(context, id))
        context.getSystemService(NotificationManager::class.java).cancel(id)
    }

    fun post(context: Context, id: Int, title: String, text: String) {
        val open = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        runCatching { context.getSystemService(NotificationManager::class.java).notify(id, n) }
    }
}

class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val state = (context.applicationContext as WearApp).state
        if (state.inForeground) return // the app has already buzzed and flashed
        WatchAlerts.post(context, intent.getIntExtra("id", 0), intent.getStringExtra("title") ?: "", intent.getStringExtra("text") ?: "")
    }
}

// ---------------------------------------------------------------- phone ↔ watch

/** Finished kept-score games go to the phone's History; they wait in the Data Layer until it's reachable. */
object WearSync {
    const val SETTINGS_PATH = "/settings"
    const val GAME_PREFIX = "/game/"

    fun sendRecord(context: Context, record: GameRecord) {
        runCatching {
            val request = PutDataMapRequest.create(GAME_PREFIX + record.id).apply {
                dataMap.putString("json", UmpireJson.encodeToString(GameRecord.serializer(), record))
                dataMap.putLong("at", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
        }
    }
}

class WearListenerService : WearableListenerService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onDataChanged(events: DataEventBuffer) {
        val state = (application as WearApp).state
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED || event.dataItem.uri.path != WearSync.SETTINGS_PATH) continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            main.post {
                runCatching { UmpireJson.decodeFromString(GameSettings.serializer(), json) }
                    .onSuccess(state::receivePhoneSettings)
            }
        }
    }
}
