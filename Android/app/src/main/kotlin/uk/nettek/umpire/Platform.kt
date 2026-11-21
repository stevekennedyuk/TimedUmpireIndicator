package uk.nettek.umpire

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.serialization.builtins.ListSerializer
import uk.nettek.umpire.shared.GameRecord
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.UmpireJson
import java.io.File

// ---------------------------------------------------------------- tournament-clock alerts

/**
 * The no-new and drop-dead alerts for when the phone is locked or the app is in
 * the background — the twin of iOS TimerAlerts. Exact alarms post a high-priority
 * notification that vibrates; drop-dead gets a second ping 15 s later so the hard
 * deadline is unmissable. While the app is on screen it buzzes and flashes itself.
 */
object Alerts {
    const val CHANNEL = "clock"
    private const val NO_NEW = 1
    private const val CUTOFF = 2
    private const val CUTOFF_REPEAT = 3

    fun createChannel(context: Context) {
        val channel = NotificationChannel(CHANNEL, "Tournament clock", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "No-new-innings and drop-dead alerts"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
        }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun pending(context: Context, id: Int, title: String = "", text: String = ""): PendingIntent {
        val intent = Intent(context, AlertReceiver::class.java)
            .putExtra("id", id).putExtra("title", title).putExtra("text", text)
        return PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

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
        noNewAt?.let { set(it, pending(context, NO_NEW, "No new innings", "Time limit reached — finish the current inning.")) }
        cutoffAt?.let {
            set(it, pending(context, CUTOFF, "Ball game — time!", "Drop-dead time reached. Open Umpire to end the game."))
            set(it + 15_000, pending(context, CUTOFF_REPEAT, "Ball game — time!", "Drop-dead time has passed."))
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
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        // Fails quietly if notifications aren't allowed.
        runCatching { context.getSystemService(NotificationManager::class.java).notify(id, notification) }
    }
}

class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val state = (context.applicationContext as UmpireApp).state
        if (state.inForeground) return // the app has already buzzed and flashed
        Alerts.post(context, intent.getIntExtra("id", 0), intent.getStringExtra("title") ?: "", intent.getStringExtra("text") ?: "")
    }
}

// ---------------------------------------------------------------- storage

/** Settings (Settings tab), the last game's overrides, and History. */
class Store(context: Context) {
    private val prefs = context.getSharedPreferences("umpire", Context.MODE_PRIVATE)
    private val historyFile = File(context.filesDir, "games.json")

    var mainSettings: GameSettings
        get() = prefs.getString("main_settings", null)
            ?.let { runCatching { UmpireJson.decodeFromString(GameSettings.serializer(), it) }.getOrNull() }
            ?.normalised() ?: GameSettings()
        set(value) = prefs.edit().putString("main_settings", UmpireJson.encodeToString(GameSettings.serializer(), value)).apply()

    var lastGameSettings: GameSettings?
        get() = prefs.getString("last_game_settings", null)
            ?.let { runCatching { UmpireJson.decodeFromString(GameSettings.serializer(), it) }.getOrNull() }
        set(value) = prefs.edit().putString("last_game_settings", value?.let { UmpireJson.encodeToString(GameSettings.serializer(), it) }).apply()

    var lastGameAt: Long
        get() = prefs.getLong("last_game_at", 0)
        set(value) = prefs.edit().putLong("last_game_at", value).apply()

    private val listSerializer = ListSerializer(GameRecord.serializer())

    fun loadHistory(): List<GameRecord> = runCatching {
        UmpireJson.decodeFromString(listSerializer, historyFile.readText())
    }.getOrDefault(emptyList()).sortedByDescending { it.startedAt }

    fun saveHistory(records: List<GameRecord>) {
        runCatching {
            val tmp = File(historyFile.parentFile, "games.json.tmp")
            tmp.writeText(UmpireJson.encodeToString(listSerializer, records))
            tmp.renameTo(historyFile)
        }
    }
}

// ---------------------------------------------------------------- phone ↔ watch

/**
 * Wearable Data Layer, like WatchConnectivity on iOS: settings go phone → watch
 * (/settings); each kept-score game finished on the watch comes back (/game/<id>)
 * and is added to History. Items wait in the Data Layer until the other side is
 * reachable. Does nothing when there's no watch.
 */
object WearSync {
    const val SETTINGS_PATH = "/settings"
    const val GAME_PREFIX = "/game/"

    fun sendSettings(context: Context, settings: GameSettings) {
        runCatching {
            val request = PutDataMapRequest.create(SETTINGS_PATH).apply {
                dataMap.putString("json", UmpireJson.encodeToString(GameSettings.serializer(), settings))
                dataMap.putLong("at", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request)
        }
    }

    /** Calls back with the name of a connected watch, or null. */
    fun connectedWatch(context: Context, result: (String?) -> Unit) {
        runCatching {
            Wearable.getNodeClient(context).connectedNodes
                .addOnSuccessListener { nodes -> result(nodes.firstOrNull()?.displayName) }
                .addOnFailureListener { result(null) }
        }.onFailure { result(null) }
    }
}

class WearListenerService : WearableListenerService() {
    private val main = Handler(Looper.getMainLooper())

    override fun onDataChanged(events: DataEventBuffer) {
        val state = (application as UmpireApp).state
        for (event in events) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val uri = event.dataItem.uri
            if (uri.path?.startsWith(WearSync.GAME_PREFIX) != true) continue
            val json = DataMapItem.fromDataItem(event.dataItem).dataMap.getString("json") ?: continue
            main.post {
                runCatching { UmpireJson.decodeFromString(GameRecord.serializer(), json) }.onSuccess {
                    state.addRecord(it)
                    // Received and saved: clear it from the sync store.
                    Wearable.getDataClient(this).deleteDataItems(uri)
                }
            }
        }
    }
}
