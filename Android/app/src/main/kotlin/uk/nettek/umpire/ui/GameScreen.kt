package uk.nettek.umpire.ui

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import uk.nettek.umpire.shared.DropDeadPreview
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.GameState
import uk.nettek.umpire.shared.GameTimer
import uk.nettek.umpire.shared.Half
import uk.nettek.umpire.shared.Sport
import uk.nettek.umpire.shared.formatClock

/** The full umpire experience: scoreboard, big B/S/O cells, clock, end controls. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameScreen() {
    val app = LocalApp.current
    app.revision // recompose on every session change
    val session = app.session
    val game = session.game
    var showSetup by remember { mutableStateOf(false) }
    var showEndConfirm by remember { mutableStateOf(false) }

    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Umpire") },
                    navigationIcon = {
                        if (session.isLive) {
                            TextButton(onClick = { session.act { undoLast() } }, enabled = game.canUndo) { Text("↶ Undo") }
                        }
                    },
                    actions = {
                        if (session.isLive) {
                            TextButton(onClick = { showEndConfirm = true }) { Text("End", color = MaterialTheme.colorScheme.error) }
                        }
                    },
                )
            },
        ) { padding ->
            Box(Modifier.padding(padding).fillMaxSize()) {
                if (session.hasStarted) ActiveGame(game, session.timer) else IdleStart { showSetup = true }
            }
        }

        // ---- dialogs, in the order iOS presents them
        if (showSetup) {
            GameSetupDialog(app.setupDefaults(), onCancel = { showSetup = false }) { s ->
                showSetup = false
                if (s.useTimers && Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                app.startGame(s)
            }
        }
        if (session.isLive && game.pendingRunsEntry) {
            RunsEntryDialog(game.inning, game.half) { session.confirmRuns(it) }
        }
        if (session.isLive && game.pendingRegulationEnd) {
            RegulationEndDialog(game.settings.sport.regulationInnings,
                onEnd = { session.act { confirmRegulationEnd() } },
                onExtras = { session.act { continueToExtraInnings() } })
        }
        if (session.isLive && session.showDropDead) {
            DropDeadDialog(game, session.timer,
                onEnd = { session.endAtDropDead(it) },
                onPlayOn = { session.playOn() })
        }
        if (showEndConfirm && session.isLive) {
            AlertDialog(
                onDismissRequest = { showEndConfirm = false },
                title = { Text("End the game?") },
                confirmButton = {
                    TextButton(onClick = { showEndConfirm = false; session.act { endManually() } }) {
                        Text("End game", color = MaterialTheme.colorScheme.error)
                    }
                },
                dismissButton = { TextButton(onClick = { showEndConfirm = false }) { Text("Cancel") } },
            )
        }
        if (session.showGameOver) {
            GameOverDialog(game, session.timer.elapsed) { session.acknowledgeGameOver() }
        }
        session.flash?.let { ThresholdFlash(it) { session.dismissFlash() } }
    }
}

@Composable
private fun IdleStart(onStart: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BaseballIcon(64.dp, MaterialTheme.colorScheme.primary)
        Spacer(Modifier.height(24.dp))
        Text("Ready to umpire", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        Text(
            "Start a game to track balls, strikes, outs, innings and the tournament clock.",
            color = Secondary, textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        Button(onClick = onStart, modifier = Modifier.widthIn(max = 420.dp).fillMaxWidth().height(52.dp)) {
            Text("▶  Start game", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun ActiveGame(game: GameState, timer: GameTimer) {
    observeSession()
    val app = LocalApp.current
    val s = game.settings
    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), contentAlignment = Alignment.TopCenter) {
        // Capped width keeps a tablet from stretching it edge to edge.
        Column(Modifier.widthIn(max = 700.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (s.keepScore) Scoreboard(game) else InningOnly(game)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                fun tap(dec: Boolean, block: GameState.() -> Unit) = { app.tapFeedback(dec); app.session.act(block) }
                BigCountCell("BALLS", game.balls, maxOf(1, s.maxBalls - 1), BallsGreen, Modifier.weight(1f),
                    tap(false) { incrementBall() }, tap(true) { decrementBall() })
                BigCountCell("STRIKES", game.strikes, maxOf(1, s.maxStrikes - 1), StrikesYellow, Modifier.weight(1f),
                    tap(false) { incrementStrike() }, tap(true) { decrementStrike() })
                BigCountCell("OUTS", game.outs, maxOf(1, s.maxOuts - 1), OutsRed, Modifier.weight(1f),
                    tap(false) { incrementOut() }, tap(true) { decrementOut() })
            }
            ClockCard(s, timer)
            if (s.keepScore && game.lineScore.isNotEmpty()) {
                Panel {
                    Text("Line score", color = Secondary, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    LineScoreGrid(game.lineScore, game.awayScore, game.homeScore)
                }
            }
            if (s.keepScore) {
                OutlinedButton(onClick = { app.session.act { forceEndOfHalf() } }, modifier = Modifier.fillMaxWidth()) {
                    Text("⏭  End half-inning")
                }
            }
        }
    }
}

@Composable
private fun Scoreboard(game: GameState) {
    observeSession()
    Panel {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TeamScore("Away", game.awayScore, game.half == Half.TOP, Modifier.weight(1f))
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(game.half.symbol, fontSize = 20.sp, color = if (game.half == Half.TOP) BallsGreen else RunRuleBlue)
                Text("Inning ${game.inning}", fontWeight = FontWeight.SemiBold)
            }
            TeamScore("Home", game.homeScore, game.half == Half.BOTTOM, Modifier.weight(1f))
        }
    }
}

@Composable
private fun TeamScore(name: String, score: Int, batting: Boolean, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(name, fontWeight = FontWeight.SemiBold, color = if (batting) MaterialTheme.colorScheme.onSurface else Secondary)
        Text("$score", fontSize = 52.sp, fontWeight = FontWeight.Bold, lineHeight = 56.sp)
        Text(if (batting) "AT BAT" else " ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun InningOnly(game: GameState) {
    observeSession()
    Panel {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("${game.half.symbol} ${game.half.fullName}", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
            Text("Inning ${game.inning}", fontWeight = FontWeight.SemiBold, fontSize = 20.sp)
        }
    }
}

@Composable
private fun ClockCard(s: GameSettings, timer: GameTimer) {
    observeSession()
    val app = LocalApp.current
    val color = when {
        timer.isPaused -> PausedYellow
        !s.useTimers -> Secondary
        timer.phase == GameTimer.Phase.NO_NEW -> Secondary
        timer.phase == GameTimer.Phase.BALL_GAME -> AmberOrange
        else -> OutsRed
    }
    val label = when {
        timer.isPaused -> "Paused"
        s.useTimers -> timer.phase.label
        else -> "Elapsed"
    }
    Panel {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, color = color, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Text(
                if (s.useTimers) timer.activeCountdownText else formatClock(timer.elapsed),
                color = color, fontSize = 40.sp, fontWeight = FontWeight.Black, style = TabularDigits,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (s.useTimers) "Elapsed ${formatClock(timer.elapsed)}" else "", color = Secondary, fontSize = 13.sp, modifier = Modifier.weight(1f))
            OutlinedButton(onClick = { app.session.togglePause() }, enabled = timer.startedAt != null) {
                Text(if (timer.isPaused) "▶ Resume" else "❚❚ Pause")
            }
        }
    }
}

// ---------------------------------------------------------------- dialogs

/** A full-width dialog body with a title, used by the modal sheets below. */
@Composable
private fun SheetDialog(dismissible: Boolean = false, onDismiss: () -> Unit = {}, content: @Composable () -> Unit) {
    Dialog(
        onDismissRequest = { if (dismissible) onDismiss() },
        properties = DialogProperties(dismissOnBackPress = dismissible, dismissOnClickOutside = dismissible, usePlatformDefaultWidth = false),
    ) {
        Surface(Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(16.dp), shape = RoundedCornerShape(24.dp)) {
            content()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameSetupDialog(defaults: GameSettings, onCancel: () -> Unit, onStart: (GameSettings) -> Unit) {
    var s by remember { mutableStateOf(defaults) }
    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize()) {
            Column {
                Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = onCancel) { Text("Cancel") }
                    Text("New game", Modifier.weight(1f), textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                    TextButton(onClick = { onStart(s) }, enabled = !(s.useTimers && s.ballGameCutoffMinutes <= s.noNewInningsMinutes)) {
                        Text("Start", fontWeight = FontWeight.Bold)
                    }
                }
                Column(
                    Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)
                        .widthIn(max = 700.dp).align(Alignment.CenterHorizontally),
                ) {
                    SectionTitle("Sport")
                    SportPicker(s.sport) { s = s.copy(sport = it) }
                    SectionTitle("Mode")
                    SwitchRow("Keep score", null, s.keepScore) { s = s.copy(keepScore = it) }
                    if (s.keepScore) {
                        SwitchRow("Allow ties (round-robin)", null, s.allowTies) { s = s.copy(allowTies = it) }
                        SwitchRow("Run-ahead rule", s.runAheadSummary(s.sport), s.runAheadEnabled) { s = s.copy(runAheadEnabled = it) }
                    }
                    SwitchRow("Use timers", if (s.useTimers) "Tournament clock rules apply" else "Untimed — ends by innings, run-ahead or umpire", s.useTimers) {
                        s = s.copy(useTimers = it)
                    }
                    if (s.useTimers) {
                        SectionTitle("Tournament timers")
                        TimerFields(s) { s = it }
                        SectionTitle("Auto-close")
                        AutoCloseFields(s) { s = it }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SportPicker(sport: Sport, onChange: (Sport) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        Sport.entries.forEachIndexed { i, sp ->
            SegmentedButton(sport == sp, { onChange(sp) }, SegmentedButtonDefaults.itemShape(i, Sport.entries.size)) {
                Text(sp.displayName)
            }
        }
    }
}

@Composable
fun TimerFields(s: GameSettings, onChange: (GameSettings) -> Unit) {
    StepperRow("No new innings", s.noNewInningsMinutes, 10..180, 5, { "$it min" }) { onChange(s.copy(noNewInningsMinutes = it)) }
    StepperRow("Drop-dead", s.ballGameCutoffMinutes, 10..240, 5, { "$it min" }) { onChange(s.copy(ballGameCutoffMinutes = it)) }
    SwitchRow(
        "Enforce drop-dead",
        if (s.enforceDropDead) "Prompts the umpire to end the game when the timer fires."
        else "Timer is purely advisory — the umpire decides when to call it.",
        s.enforceDropDead,
    ) { onChange(s.copy(enforceDropDead = it)) }
    if (s.ballGameCutoffMinutes <= s.noNewInningsMinutes) {
        Text("Drop-dead must be greater than the No-new-innings time.", color = MaterialTheme.colorScheme.error, fontSize = 13.sp)
    }
}

@Composable
fun AutoCloseFields(s: GameSettings, onChange: (GameSettings) -> Unit) {
    SwitchRow(
        "Auto-close when idle",
        if (s.autoCloseOnInactivity) "Once past no-new, ends the game after a period with no taps."
        else "The game stays open until the umpire ends it.",
        s.autoCloseOnInactivity,
    ) { onChange(s.copy(autoCloseOnInactivity = it)) }
    if (s.autoCloseOnInactivity) {
        StepperRow("Idle limit", s.inactivityTimeoutMinutes, 5..60, 5, { "$it min" }) { onChange(s.copy(inactivityTimeoutMinutes = it)) }
    }
}

@Composable
private fun RunsEntryDialog(inning: Int, half: Half, onConfirm: (Int) -> Unit) {
    var runs by remember(inning, half) { mutableIntStateOf(0) }
    SheetDialog {
        Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text("${if (half == Half.TOP) "Away" else "Home"} — ${half.fullName} $inning", fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
            Text("Runs scored this half-inning", color = Secondary)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                FilledTonalIconButton(onClick = { if (runs > 0) runs-- }, enabled = runs > 0, modifier = Modifier.height(56.dp).widthIn(56.dp)) {
                    Text("−", fontSize = 30.sp, fontWeight = FontWeight.Bold)
                }
                Text("$runs", fontSize = 72.sp, fontWeight = FontWeight.Bold, modifier = Modifier.widthIn(min = 100.dp), textAlign = TextAlign.Center)
                FilledTonalIconButton(onClick = { runs++ }, modifier = Modifier.height(56.dp).widthIn(56.dp)) {
                    Text("+", fontSize = 30.sp, fontWeight = FontWeight.Bold)
                }
            }
            Button(onClick = { onConfirm(runs) }, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Text("Confirm", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun ChoiceDialog(title: String, message: String, content: @Composable () -> Unit) {
    SheetDialog {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 20.sp)
            Text(message, color = Secondary)
            Spacer(Modifier.height(4.dp))
            content()
        }
    }
}

@Composable
private fun DestructiveButton(text: String, onClick: () -> Unit) {
    Button(onClick, Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)) { Text(text) }
}

@Composable
private fun RegulationEndDialog(innings: Int, onEnd: () -> Unit, onExtras: () -> Unit) {
    ChoiceDialog("End of regulation", "$innings innings complete. End the game, or play extra innings if it's tied?") {
        DestructiveButton("End game", onEnd)
        OutlinedButton(onExtras, Modifier.fillMaxWidth()) { Text("Extra innings") }
    }
}

@Composable
private fun DropDeadDialog(game: GameState, timer: GameTimer, onEnd: (Boolean?) -> Unit, onPlayOn: () -> Unit) {
    observeSession()
    val s = game.settings
    val elapsed = formatClock(timer.elapsed)
    val message = when {
        !s.keepScore -> "$elapsed elapsed. End the game or keep playing?"
        game.homeWinsOnCutoff -> "$elapsed elapsed. Home lead while batting — the score stands."
        else -> "$elapsed elapsed. The current inning is incomplete, so the score reverts to the last completed inning."
    }
    fun label(p: DropDeadPreview, prefix: String) =
        "$prefix Away ${p.away}–${p.home} Home" + (p.inning?.let { " (end $it)" } ?: "")
    ChoiceDialog("Cut-off reached", message) {
        when {
            !s.keepScore -> DestructiveButton("End game") { onEnd(null) }
            game.homeWinsOnCutoff -> DestructiveButton("End — Home win") { onEnd(null) }
            else -> {
                val preferred = game.dropDeadPreview(s.allowTies)
                DestructiveButton(label(preferred, "End")) { onEnd(s.allowTies) }
                val alt = game.dropDeadPreview(!s.allowTies)
                if (alt.away != preferred.away || alt.home != preferred.home) {
                    OutlinedButton({ onEnd(!s.allowTies) }, Modifier.fillMaxWidth()) {
                        Text(label(alt, if (s.allowTies) "No tie —" else "Allow tie —"))
                    }
                }
            }
        }
        OutlinedButton(onPlayOn, Modifier.fillMaxWidth()) { Text("Play on") }
    }
}

@Composable
private fun GameOverDialog(game: GameState, elapsed: Double, onDone: () -> Unit) {
    observeSession()
    SheetDialog {
        Column(Modifier.padding(24.dp).verticalScroll(rememberScrollState()), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Game over", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
            ReasonBadge(game.endReason)
            if (game.settings.keepScore) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    FinalScore("Away", game.awayScore, game.awayScore > game.homeScore)
                    Text("–", fontSize = 28.sp)
                    FinalScore("Home", game.homeScore, game.homeScore > game.awayScore)
                }
                Text(
                    when { game.awayScore == game.homeScore -> "Tie game"; game.awayScore > game.homeScore -> "Away win"; else -> "Home win" },
                    color = Secondary,
                )
            } else {
                Text("Game ended", fontSize = 20.sp)
            }
            Text("Game time: ${formatClock(elapsed)}", color = Secondary, fontSize = 13.sp)
            if (game.settings.keepScore && game.lineScore.isNotEmpty()) {
                LineScoreGrid(game.lineScore, game.awayScore, game.homeScore)
            }
            Button(onDone, Modifier.fillMaxWidth().height(52.dp)) { Text("Done", fontSize = 17.sp) }
        }
    }
}

@Composable
fun ReasonBadge(reason: uk.nettek.umpire.shared.GameEndReason?) {
    val color = reasonColor(reason)
    Text(
        (reason?.displayName ?: "Final").uppercase(),
        color = color, fontSize = 12.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(color.copy(alpha = 0.18f)).padding(horizontal = 10.dp, vertical = 3.dp),
    )
}

@Composable
private fun FinalScore(name: String, score: Int, win: Boolean) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(name, color = if (win) MaterialTheme.colorScheme.onSurface else Secondary)
        Text("$score", fontSize = 48.sp, fontWeight = FontWeight.Bold, color = if (win) MaterialTheme.colorScheme.onSurface else Secondary)
    }
}

