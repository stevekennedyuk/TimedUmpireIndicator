package uk.nettek.umpire.shared

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// The twin of iOS/Shared/Models: Sport, InningRuns, GameSettings, GameRecord.
// When a rule changes on one platform, change it on the other too.

/** JSON used for storage and phone ↔ watch sync. Unknown keys are ignored so
 *  older builds can read settings written by newer ones. */
val UmpireJson = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    coerceInputValues = true
}

@Serializable
enum class Sport(val regulationInnings: Int, val displayName: String) {
    @SerialName("softball") SOFTBALL(7, "Softball"),
    @SerialName("baseball") BASEBALL(9, "Baseball"),
}

@Serializable
enum class Half(val symbol: String, val fullName: String) {
    @SerialName("top") TOP("▲", "Top"),
    @SerialName("bottom") BOTTOM("▼", "Bottom"),
}

enum class Leader { AWAY, HOME, TIED }

private fun leaderOf(away: Int, home: Int) = when {
    away > home -> Leader.AWAY
    home > away -> Leader.HOME
    else -> Leader.TIED
}

/** Per-inning line-score entry. Null = that half hasn't been recorded. */
@Serializable
data class InningRuns(val inning: Int, val top: Int? = null, val bottom: Int? = null) {
    fun runs(half: Half): Int? = if (half == Half.TOP) top else bottom
}

/** The score after a completed half-inning. Used by the drop-dead revert. */
@Serializable
data class ScoreSnapshot(val inning: Int, val half: Half, val awayScore: Int, val homeScore: Int) {
    val leader: Leader get() = leaderOf(awayScore, homeScore)
}

@Serializable
enum class GameEndReason(val displayName: String) {
    /** Regulation length reached with a winner (or extras concluded with a winner). */
    @SerialName("regulationComplete") REGULATION_COMPLETE("Final"),
    /** "No new innings" timer reached and the home team is ahead. */
    @SerialName("noNewInningsHomeAhead") NO_NEW_INNINGS_HOME_AHEAD("Time / Home leading"),
    /** Drop-dead timer reached. Score reverts to the last completed inning. */
    @SerialName("ballGameCutoff") BALL_GAME_CUTOFF("Drop-dead"),
    /** Umpire ended the game. */
    @SerialName("manual") MANUAL("Called"),
    /** Auto-ended after the idle period while in the cut-off / overtime phase. */
    @SerialName("inactivity") INACTIVITY("Auto-ended (idle)"),
    /** Run-ahead ("mercy") rule. */
    @SerialName("runAhead") RUN_AHEAD("Run rule"),
}

/**
 * Per-game configuration. Every field has a default, so settings saved by an
 * older build still load.
 */
@Serializable
data class GameSettings(
    val sport: Sport = Sport.SOFTBALL,
    val noNewInningsMinutes: Int = 55,
    val ballGameCutoffMinutes: Int = 60,
    val maxBalls: Int = 4,
    val maxStrikes: Int = 3,
    val maxOuts: Int = 3,
    val awayTeamName: String = "Away",
    val homeTeamName: String = "Home",
    /** True: the drop-dead timer prompts to end the game. False: advisory only. */
    val enforceDropDead: Boolean = true,
    /** True: runs, innings, line score and score-based endings. False: count + clock only. */
    val keepScore: Boolean = true,
    /** True: round-robin, a game may end tied. False: finals, the drop-dead revert avoids a tie. */
    val allowTies: Boolean = true,
    /** Once past no-new, end the game after this long with no umpire interaction. */
    val autoCloseOnInactivity: Boolean = true,
    val inactivityTimeoutMinutes: Int = 20,
    /** False = untimed: no thresholds, alerts, cutoff or idle-close. Elapsed time is still kept. */
    val useTimers: Boolean = true,
    /** Run-ahead (mercy) rule. */
    val runAheadEnabled: Boolean = true,
    /** Margin per inning for softball, index 0 = inning 1. 0 = rule off that inning;
     *  extra innings reuse the last entry. */
    val runAheadMarginsSoftball: List<Int> = DEFAULT_RUN_AHEAD_SOFTBALL,
    /** Margin per inning for baseball (WBSC defaults). */
    val runAheadMarginsBaseball: List<Int> = DEFAULT_RUN_AHEAD_BASEBALL,
) {
    fun runAheadMargins(sport: Sport): List<Int> =
        if (sport == Sport.BASEBALL) runAheadMarginsBaseball else runAheadMarginsSoftball

    /** The run-ahead margin for a just-completed inning, or null when the rule
     *  is off or that inning's margin is 0. Extra innings reuse the last entry. */
    fun runAheadMargin(inning: Int): Int? {
        if (!runAheadEnabled || inning < 1) return null
        val table = runAheadMargins(sport)
        if (table.isEmpty()) return null
        val margin = table[minOf(inning, table.size) - 1]
        return margin.takeIf { it > 0 }
    }

    /** Compact summary, e.g. "20+@4 · 15+@5+" or "15+@5–6 · 10+@7+". "Off" when empty. */
    fun runAheadSummary(sport: Sport = this.sport): String {
        val table = runAheadMargins(sport)
        val parts = mutableListOf<String>()
        var i = 0
        while (i < table.size) {
            val margin = table[i]
            var j = i
            while (j + 1 < table.size && table[j + 1] == margin) j++
            if (margin > 0) {
                val from = i + 1
                val to = j + 1
                parts += when {
                    to == table.size -> "$margin+@$from+"
                    from == to -> "$margin+@$from"
                    else -> "$margin+@$from–$to"
                }
            }
            i = j + 1
        }
        return if (parts.isEmpty()) "Off" else parts.joinToString(" · ")
    }

    /** A copy with one inning's margin changed for the given sport. */
    fun withRunAheadMargin(sport: Sport, inning: Int, margin: Int): GameSettings {
        val table = normalisedTable(runAheadMargins(sport), sport).toMutableList()
        table[inning - 1] = margin.coerceIn(0, 50)
        return if (sport == Sport.BASEBALL) copy(runAheadMarginsBaseball = table)
        else copy(runAheadMarginsSoftball = table)
    }

    /** Tables always hold one entry per regulation inning; a malformed one falls back to the default. */
    fun normalised(): GameSettings = copy(
        runAheadMarginsSoftball = normalisedTable(runAheadMarginsSoftball, Sport.SOFTBALL),
        runAheadMarginsBaseball = normalisedTable(runAheadMarginsBaseball, Sport.BASEBALL),
        awayTeamName = "Away",
        homeTeamName = "Home",
    )

    companion object {
        /** Softball: 20+ when the 4th completes, 15+ from the 5th. */
        val DEFAULT_RUN_AHEAD_SOFTBALL = listOf(0, 0, 0, 20, 15, 15, 15)
        /** WBSC baseball: 15+ from the 5th, 10+ from the 7th. */
        val DEFAULT_RUN_AHEAD_BASEBALL = listOf(0, 0, 0, 0, 15, 15, 10, 10, 10)

        private fun normalisedTable(table: List<Int>, sport: Sport): List<Int> =
            if (table.size == sport.regulationInnings) table.map { it.coerceIn(0, 50) }
            else if (sport == Sport.BASEBALL) DEFAULT_RUN_AHEAD_BASEBALL
            else DEFAULT_RUN_AHEAD_SOFTBALL
    }
}

/** A completed game, kept in History and sent watch → phone. Times are epoch milliseconds. */
@Serializable
data class GameRecord(
    val id: String,
    val startedAt: Long,
    val endedAt: Long,
    val sport: Sport,
    val awayTeamName: String = "Away",
    val homeTeamName: String = "Home",
    val awayScore: Int,
    val homeScore: Int,
    val lineScore: List<InningRuns>,
    val endReason: GameEndReason,
    val durationSeconds: Double,
    val noNewMinutes: Int,
    val cutoffMinutes: Int,
) {
    val leader: Leader get() = leaderOf(awayScore, homeScore)
}

/** What the drop-dead revert would produce, without changing the game. */
data class DropDeadPreview(val away: Int, val home: Int, val inning: Int?, val tied: Boolean)

/**
 * Game-setup defaults on the phone: per-game overrides carry into the next game
 * while games come back to back, and expire — reverting to the main settings —
 * once the gap since the last game passes that session's idle timeout.
 */
fun setupDefaults(main: GameSettings, lastGame: GameSettings?, lastGameAt: Long, now: Long): GameSettings {
    if (lastGame == null || lastGameAt <= 0) return main
    val idleMs = maxOf(1, lastGame.inactivityTimeoutMinutes) * 60_000L
    return if (now - lastGameAt <= idleMs) lastGame else main
}

/** "MM:SS" (minutes keep counting past 60, as on iOS). */
fun formatClock(seconds: Double): String {
    val total = maxOf(0, seconds.toLong())
    return "%02d:%02d".format(total / 60, total % 60)
}
