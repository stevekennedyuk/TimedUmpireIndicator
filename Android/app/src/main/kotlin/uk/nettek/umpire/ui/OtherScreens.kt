package uk.nettek.umpire.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import uk.nettek.umpire.WearSync
import uk.nettek.umpire.shared.GameRecord
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.formatClock
import java.text.DateFormat
import java.util.Date

private enum class Tab(val title: String) { GAME("Game"), HISTORY("History"), SETTINGS("Settings"), ABOUT("About") }

/** Game / History / Settings / About, as on iPhone. */
@Composable
fun Root() {
    var tab by rememberSaveable { mutableStateOf(Tab.GAME) }
    Scaffold(
        bottomBar = {
            NavigationBar {
                Tab.entries.forEach { t ->
                    NavigationBarItem(
                        selected = tab == t,
                        onClick = { tab = t },
                        label = { Text(t.title) },
                        icon = {
                            when (t) {
                                Tab.GAME -> BaseballIcon(22.dp, MaterialTheme.colorScheme.onSurface)
                                Tab.HISTORY -> Icon(Icons.AutoMirrored.Filled.List, null)
                                Tab.SETTINGS -> Icon(Icons.Filled.Settings, null)
                                Tab.ABOUT -> Icon(Icons.Filled.Info, null)
                            }
                        },
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(bottom = padding.calculateBottomPadding()).fillMaxSize()) {
            when (tab) {
                Tab.GAME -> GameScreen()
                Tab.HISTORY -> HistoryScreen()
                Tab.SETTINGS -> SettingsScreen()
                Tab.ABOUT -> AboutScreen()
            }
        }
    }
}

private fun dateTime(millis: Long): String =
    DateFormat.getDateTimeInstance(DateFormat.MEDIUM, DateFormat.SHORT).format(Date(millis))

/** Title bar plus a scrolling, width-capped form body. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FormScreen(title: String, navigation: @Composable () -> Unit = {}, actions: @Composable () -> Unit = {}, body: @Composable ColumnScope.() -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text(title) }, navigationIcon = navigation, actions = { actions() }) }) { padding ->
        Box(Modifier.padding(padding).fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
            Column(Modifier.widthIn(max = 700.dp).padding(horizontal = 16.dp).padding(bottom = 32.dp), content = body)
        }
    }
}

// ---------------------------------------------------------------- History

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen() {
    val app = LocalApp.current
    var selectedId by rememberSaveable { mutableStateOf<String?>(null) }
    val selected = app.history.firstOrNull { it.id == selectedId }
    if (selected != null) {
        BackHandler { selectedId = null }
        GameDetail(selected, onBack = { selectedId = null }, onDelete = { app.deleteRecord(selected); selectedId = null })
        return
    }
    Scaffold(topBar = { TopAppBar(title = { Text("History") }) }) { padding ->
        if (app.history.isEmpty()) {
            Column(Modifier.padding(padding).fillMaxSize().padding(32.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text("No games yet", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                Text("Kept-score games from this phone and the watch appear here.", color = Secondary)
            }
        } else {
            LazyColumn(Modifier.padding(padding).fillMaxSize()) {
                items(app.history, key = { it.id }) { r ->
                    HistoryRow(r) { selectedId = r.id }
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun HistoryRow(r: GameRecord, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp)) {
        Row {
            Text(dateTime(r.startedAt), Modifier.weight(1f))
            Text(r.sport.displayName, color = Secondary, fontSize = 13.sp)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            ScorePill(r.awayTeamName, r.awayScore, r.awayScore > r.homeScore)
            Text("  –  ", color = Secondary)
            ScorePill(r.homeTeamName, r.homeScore, r.homeScore > r.awayScore)
            Spacer(Modifier.weight(1f))
            ReasonBadge(r.endReason)
        }
    }
}

@Composable
private fun ScorePill(name: String, score: Int, winner: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(name, fontSize = 13.sp)
        Text(" $score", fontWeight = FontWeight.Bold, fontSize = 17.sp, color = if (winner) BallsGreen else MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
private fun GameDetail(r: GameRecord, onBack: () -> Unit, onDelete: () -> Unit) {
    var confirmDelete by remember { mutableStateOf(false) }
    FormScreen(
        "Game",
        navigation = { TextButton(onClick = onBack) { Text("‹ History") } },
        actions = { TextButton(onClick = { confirmDelete = true }) { Text("Delete", color = MaterialTheme.colorScheme.error) } },
    ) {
        SectionTitle("Final")
        Panel {
            LabelValue(r.awayTeamName, "${r.awayScore}", r.awayScore > r.homeScore)
            LabelValue(r.homeTeamName, "${r.homeScore}", r.homeScore > r.awayScore)
            LabelValue("Outcome", r.endReason.displayName)
        }
        SectionTitle("Line score")
        Panel { LineScoreGrid(r.lineScore, r.awayScore, r.homeScore) }
        SectionTitle("Game")
        Panel {
            LabelValue("Sport", r.sport.displayName)
            LabelValue("Started", dateTime(r.startedAt))
            LabelValue("Duration", formatClock(r.durationSeconds))
            LabelValue("No-new", "${r.noNewMinutes} min")
            LabelValue("Drop-dead", "${r.cutoffMinutes} min")
        }
    }
    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete this game?") },
            confirmButton = { TextButton(onClick = onDelete) { Text("Delete", color = MaterialTheme.colorScheme.error) } },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun LabelValue(label: String, value: String, highlight: Boolean = false) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Text(label, Modifier.weight(1f))
        Text(value, fontWeight = FontWeight.SemiBold, color = if (highlight) BallsGreen else MaterialTheme.colorScheme.onSurface)
    }
}

// ---------------------------------------------------------------- Settings

@Composable
fun SettingsScreen() {
    val app = LocalApp.current
    val s = app.mainSettings
    fun set(new: GameSettings) = app.updateMainSettings(new)
    FormScreen("Settings") {
        SectionTitle("Mode")
        Panel {
            SwitchRow("Keep score",
                if (s.keepScore) "Tracks runs, innings, line score and end-of-game rules." else "Indicator only — balls / strikes / outs plus the game clock.",
                s.keepScore) { set(s.copy(keepScore = it)) }
            if (s.keepScore) {
                SwitchRow("Allow ties",
                    if (s.allowTies) "Round-robin — a game may end tied." else "Finals — no tie; reverts to the last decided inning.",
                    s.allowTies) { set(s.copy(allowTies = it)) }
            }
            SwitchRow("Use timers",
                if (s.useTimers) "Tournament clock rules apply (no-new-innings and drop-dead)." else "Untimed — the game ends by innings, the run-ahead rule, or the umpire.",
                s.useTimers) { set(s.copy(useTimers = it)) }
        }

        if (s.keepScore) {
            SectionTitle("Run-ahead rule")
            Panel {
                SwitchRow("Run-ahead ends game",
                    if (s.runAheadEnabled) "A big enough lead ends the game at the completion of a half-inning." else "Blowouts play on until the innings or clock end the game.",
                    s.runAheadEnabled) { set(s.copy(runAheadEnabled = it)) }
                if (s.runAheadEnabled) {
                    val margins = s.runAheadMargins(s.sport)
                    for (inning in 1..s.sport.regulationInnings) {
                        StepperRow("Inning $inning", margins[inning - 1], 0..50, 1, { if (it == 0) "Off" else "$it+" }) {
                            set(s.withRunAheadMargin(s.sport, inning, it))
                        }
                    }
                    Text(
                        "Lead needed to end the game when that inning completes (0 = rule off for that inning). Extra innings use the last inning's value. " +
                            "Home ahead by the margin after the TOP half ends it at N½ — Home needn't bat. Table shown is for ${s.sport.displayName}; each sport keeps its own.",
                        color = Secondary, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }

        SectionTitle("Sport")
        Panel { SportPicker(s.sport) { set(s.copy(sport = it)) } }

        if (s.useTimers) {
            SectionTitle("Tournament timers")
            Panel { TimerFields(s) { set(it) } }
            SectionTitle("Auto-close")
            Panel { AutoCloseFields(s) { set(it) } }
        }

        SectionTitle("Rules")
        Panel {
            StepperRow("Balls per walk", s.maxBalls, 2..6) { set(s.copy(maxBalls = it)) }
            StepperRow("Strikes per K", s.maxStrikes, 2..4) { set(s.copy(maxStrikes = it)) }
            StepperRow("Outs per half-inning", s.maxOuts, 1..4) { set(s.copy(maxOuts = it)) }
        }

        SectionTitle("Watch")
        Panel {
            Button(onClick = { app.sendSettingsToWatch() }, modifier = Modifier.fillMaxWidth()) { Text("Send to watch") }
            app.lastSentAt?.let {
                Text("Last sent ${DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(it))}", color = Secondary, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}

// ---------------------------------------------------------------- About

@Composable
fun AboutScreen() {
    val context = LocalContext.current
    var watch by remember { mutableStateOf<String?>(null) }
    var checks by remember { mutableIntStateOf(0) }
    LaunchedEffect(checks) { WearSync.connectedWatch(context) { watch = it } }
    FormScreen("About") {
        SectionTitle("Watch")
        Panel {
            Text(watch?.let { "Connected: $it" } ?: "No watch connected")
            TextButton(onClick = { checks++ }) { Text("Check again") }
        }
        SectionTitle("How it works")
        Panel {
            Text("Umpire from your phone on the Game tab, or use the Wear OS watch app. Settings here are the defaults for new games — tap Send to watch to copy them to the watch. Kept-score games from both appear under History.")
        }
        SectionTitle("Keep the app on screen")
        Panel {
            Text("Phone: while a game is running the app keeps the screen awake — no setup needed.\n\nWear OS: the watch app also keeps its screen on during a game, so it won't drop back to the watch face. If you do leave the app, the no-new and drop-dead alerts still arrive as vibrating notifications.")
        }
        SectionTitle("Tournament rules")
        Panel {
            Text(
                "• \"No new innings\" timer: once this fires, no new inning will start; if the home team is leading at that moment the game ends.\n" +
                    "• \"Drop-dead\" (ball game) timer: when this fires the game ends. The score reverts to the end of the last completed inning.\n" +
                    "• Run-ahead: a lead of that inning's margin ends the game when the inning completes, or after the top half if Home leads.\n" +
                    "• Regulation: 7 innings (softball) or 9 (baseball). Tied games continue into extra innings until one team leads at the end of an inning — or a timer fires.",
            )
        }
        Text("NetTek Ltd", color = Secondary, fontSize = 13.sp, modifier = Modifier.padding(top = 24.dp).align(Alignment.CenterHorizontally))
    }
}

