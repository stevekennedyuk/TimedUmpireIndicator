package uk.nettek.umpire.wear

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.ToggleChip
import androidx.wear.compose.material.ToggleChipDefaults
import kotlinx.coroutines.delay
import uk.nettek.umpire.shared.DropDeadPreview
import uk.nettek.umpire.shared.GameEndReason
import uk.nettek.umpire.shared.GameSettings
import uk.nettek.umpire.shared.GameState
import uk.nettek.umpire.shared.GameTimer
import uk.nettek.umpire.shared.Half
import uk.nettek.umpire.shared.Sport
import uk.nettek.umpire.shared.ThresholdKind
import uk.nettek.umpire.shared.formatClock

private val Balls = Color(0xFF34C759)
private val Strikes = Color(0xFFFFCC00)
private val Outs = Color(0xFFFF3B30)
private val Amber = Color(0xFFFF9500)
private val PausedYellow = Color(0xFFFFD60A)
private val Blue = Color(0xFF0A84FF)
private val Purple = Color(0xFFAF52DE)
private val Secondary = Color(0xFF9898A0)
private val Panel = Color(0xFF222226)
private val Tabular = TextStyle(fontFeatureSettings = "tnum")

private val LocalWear = staticCompositionLocalOf<WearState> { error("No WearState") }

/** Read the change counter in the caller's scope (see the phone app's observeSession). */
@Composable
private fun observe(): Int = LocalWear.current.revision

class MainActivity : ComponentActivity() {
    private val state get() = (application as WearApp).state

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // Keep the screen on while a game is live, so the watch doesn't drop
            // back to the watch face mid-count (Apple Watch can't do this; Wear OS can).
            val view = LocalView.current
            val keepAwake = state.keepAwake
            DisposableEffect(keepAwake) {
                view.keepScreenOn = keepAwake
                onDispose { view.keepScreenOn = false }
            }
            CompositionLocalProvider(LocalWear provides state) {
                MaterialTheme { WearRoot() }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        state.inForeground = true
    }

    override fun onStop() {
        state.inForeground = false
        super.onStop()
    }
}

private object Page { const val INDICATOR = "indicator"; const val TIMER = "timer"; const val LINE = "line"; const val SETUP = "setup" }

@Composable
private fun WearRoot() {
    val state = LocalWear.current
    observe()
    val session = state.session
    val game = session.game
    val s = game.settings
    // The same pages as the Apple Watch app; Timer only when timed, Line score only when keeping score.
    val pages = buildList {
        add(Page.INDICATOR)
        if (s.useTimers) add(Page.TIMER)
        if (s.keepScore) add(Page.LINE)
        add(Page.SETUP)
    }
    val pager = rememberPagerState(initialPage = pages.lastIndex) { pages.size }
    var confirmEnd by remember { mutableStateOf(false) }
    // Follow the session: a new game opens on the Indicator, idle returns to Setup.
    LaunchedEffect(session.hasStarted) {
        pager.scrollToPage(if (session.hasStarted) 0 else pager.pageCount - 1)
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        HorizontalPager(pager, Modifier.fillMaxSize(), key = { pages.getOrNull(it) ?: it }) { i ->
            when (pages.getOrNull(i)) {
                Page.INDICATOR -> IndicatorPage(game, session.timer)
                Page.TIMER -> TimerPage(game, session.timer)
                Page.LINE -> LineScorePage(game)
                else -> SetupPage(onEnd = { confirmEnd = true })
            }
        }
        PageDots(pager, Modifier.align(Alignment.BottomCenter).padding(bottom = 4.dp))

        // ---- overlays, in the order the Apple Watch presents them
        when {
            session.showGameOver -> GameOverOverlay(game, session.timer.elapsed) { session.acknowledgeGameOver() }
            session.isLive && game.pendingRunsEntry -> RunsEntryOverlay(game.inning, game.half) { session.confirmRuns(it) }
            session.isLive && game.pendingRegulationEnd -> ChoiceOverlay(
                "End of regulation", "${s.sport.regulationInnings} innings complete. Extra innings if tied?",
            ) {
                item { WideChip("End game", Outs) { session.act { confirmRegulationEnd() } } }
                item { WideChip("Extra innings", null) { session.act { continueToExtraInnings() } } }
            }
            session.isLive && session.showDropDead -> DropDeadOverlay(game, session.timer)
            confirmEnd && session.isLive -> ChoiceOverlay("End the game?", null) {
                item { WideChip("End game", Outs) { confirmEnd = false; session.act { endManually() } } }
                item { WideChip("Cancel", null) { confirmEnd = false } }
            }
        }
        session.flash?.let { Flash(it) { session.dismissFlash() } }
    }
}

@Composable
private fun PageDots(pager: PagerState, modifier: Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        repeat(pager.pageCount) { i ->
            Box(Modifier.size(5.dp).clip(CircleShape).background(if (i == pager.currentPage) Color.White else Color(0xFF555555)))
        }
    }
}

/** Keeps content inside the visible area of a round screen. */
@Composable
private fun inset(fraction: Float): Dp {
    val config = LocalConfiguration.current
    return if (config.isScreenRound) (config.screenWidthDp * fraction).dp else 6.dp
}

// ---------------------------------------------------------------- Indicator

@Composable
private fun IndicatorPage(game: GameState, timer: GameTimer) {
    val state = LocalWear.current
    observe()
    val s = game.settings
    fun act(tap: WearState.Tap, block: GameState.() -> Unit) = { state.session.act(block); state.tap(tap) }
    Column(
        Modifier.fillMaxSize().padding(horizontal = inset(0.07f)).padding(top = inset(0.09f), bottom = inset(0.1f)),
        verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (s.keepScore) ScoreRow(game) else {
            Text("${game.half.symbol} Inn ${game.inning}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            CountCell("B", game.balls, maxOf(1, s.maxBalls - 1), Balls, Modifier.weight(1f),
                act(WearState.Tap.CLICK) { incrementBall() }, act(WearState.Tap.UNDO) { decrementBall() })
            CountCell("S", game.strikes, maxOf(1, s.maxStrikes - 1), Strikes, Modifier.weight(1f),
                act(WearState.Tap.CLICK) { incrementStrike() }, act(WearState.Tap.UNDO) { decrementStrike() })
            CountCell("O", game.outs, maxOf(1, s.maxOuts - 1), Outs, Modifier.weight(1f),
                { val last = game.outs + 1 >= s.maxOuts; state.session.act { incrementOut() }; state.tap(if (last) WearState.Tap.HALF_OVER else WearState.Tap.CLICK) },
                act(WearState.Tap.UNDO) { decrementOut() })
        }
        TimerBand(s, timer)
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            SmallButton("↶", if (game.canUndo) Amber else Secondary, "Undo last action", game.canUndo && state.session.isLive) {
                state.session.act { undoLast() }; state.tap(WearState.Tap.UNDO)
            }
            SmallButton(if (timer.isPaused) "▶" else "❚❚", if (timer.isPaused) Balls else PausedYellow,
                if (timer.isPaused) "Resume game clock" else "Pause game clock", state.session.isLive) {
                state.session.togglePause(); state.tap(WearState.Tap.CLICK)
            }
            SmallButton("⏭", Blue, "End half-inning", state.session.isLive) {
                state.session.act { forceEndOfHalf() }; state.tap(WearState.Tap.CLICK)
            }
        }
    }
}

@Composable
private fun ScoreRow(game: GameState) {
    observe()
    // The top of a round face is narrow: keep the team labels clear of the edge.
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp + inset(0.08f)), verticalAlignment = Alignment.CenterVertically) {
        TeamCell("AWAY", game.awayScore, game.half == Half.TOP, Modifier.weight(1f), Alignment.Start)
        Column(
            Modifier.clip(RoundedCornerShape(4.dp)).background(Color(0xFF3A3A3C)).padding(horizontal = 6.dp, vertical = 1.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(game.half.symbol, fontSize = 9.sp, color = if (game.half == Half.TOP) Balls else Blue)
            Text("${game.inning}", fontSize = 13.sp, fontWeight = FontWeight.Bold)
        }
        TeamCell("HOME", game.homeScore, game.half == Half.BOTTOM, Modifier.weight(1f), Alignment.End)
    }
}

@Composable
private fun TeamCell(name: String, score: Int, batting: Boolean, modifier: Modifier, align: Alignment.Horizontal) {
    Column(modifier, horizontalAlignment = align) {
        Text(name, fontSize = 9.sp, color = if (batting) Balls else Secondary, fontWeight = FontWeight.Bold)
        Text("$score", fontSize = 20.sp, fontWeight = FontWeight.Bold, lineHeight = 20.sp)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun CountCell(label: String, value: Int, pips: Int, color: Color, modifier: Modifier, onIncrement: () -> Unit, onDecrement: () -> Unit) {
    Column(
        modifier.clip(RoundedCornerShape(10.dp)).background(color.copy(alpha = 0.18f))
            .combinedClickable(onClick = onIncrement, onLongClick = onDecrement)
            .semantics { contentDescription = "$label $value. Tap to add, hold to subtract" }
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, color = color, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        Text("$value", fontSize = 24.sp, fontWeight = FontWeight.Black, lineHeight = 26.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            repeat(pips) { i -> Box(Modifier.size(4.dp).clip(CircleShape).background(if (i < value) color else color.copy(alpha = 0.25f))) }
        }
    }
}

/** The big countdown: what the umpire needs at a glance gets the biggest type. */
@Composable
private fun TimerBand(s: GameSettings, timer: GameTimer) {
    observe()
    val color = when {
        timer.isPaused -> PausedYellow
        !s.useTimers -> Secondary
        timer.phase == GameTimer.Phase.NO_NEW -> Color(0xFFD0D0D6)
        timer.phase == GameTimer.Phase.BALL_GAME -> Amber
        else -> Outs
    }
    val band = when {
        timer.isPaused -> PausedYellow
        !s.useTimers || timer.phase == GameTimer.Phase.NO_NEW -> Color.Gray
        timer.phase == GameTimer.Phase.BALL_GAME -> Amber
        else -> Outs
    }
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(band.copy(alpha = 0.22f)).padding(horizontal = 8.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            when { timer.isPaused -> "PAUSED"; s.useTimers -> timer.phase.shortLabel; else -> "TIME" },
            color = color, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f),
        )
        Text(if (s.useTimers) timer.activeCountdownText else formatClock(timer.elapsed),
            color = color, fontSize = 24.sp, fontWeight = FontWeight.Black, style = Tabular, maxLines = 1)
    }
}

@Composable
private fun SmallButton(glyph: String, color: Color, description: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.size(30.dp).clip(CircleShape).background(Color(0xFF2C2C2E))
            .clickable(enabled = enabled, onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Text(glyph, color = if (enabled) color else Color(0xFF555555), fontSize = 14.sp, fontWeight = FontWeight.Bold)
    }
}

// ---------------------------------------------------------------- Timer

@Composable
private fun TimerPage(game: GameState, timer: GameTimer) {
    val state = LocalWear.current
    observe()
    val s = game.settings
    val color = when {
        timer.isPaused -> PausedYellow
        timer.phase == GameTimer.Phase.NO_NEW -> Color.White
        timer.phase == GameTimer.Phase.BALL_GAME -> Amber
        else -> Outs
    }
    Column(
        Modifier.fillMaxSize().padding(horizontal = inset(0.1f)),
        verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(if (timer.isPaused) "Paused" else timer.phase.label, color = color, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        Text(timer.activeCountdownText, color = color, fontSize = 40.sp, fontWeight = FontWeight.Black, style = Tabular)
        Text("Elapsed ${formatClock(timer.elapsed)}", color = Secondary, fontSize = 12.sp)
        Spacer(Modifier.height(4.dp))
        Text("No new ${s.noNewInningsMinutes}′ · Drop-dead ${s.ballGameCutoffMinutes}′", color = Secondary, fontSize = 11.sp, textAlign = TextAlign.Center)
        if (!s.enforceDropDead && timer.isCutoffTriggered) Text("Drop-dead advisory", color = Amber, fontSize = 11.sp)
        Spacer(Modifier.height(6.dp))
        Button(
            onClick = { state.session.togglePause() }, enabled = state.session.isLive,
            colors = ButtonDefaults.secondaryButtonColors(), modifier = Modifier.size(ButtonDefaults.SmallButtonSize),
        ) { Text(if (timer.isPaused) "▶" else "❚❚", color = if (timer.isPaused) Balls else PausedYellow) }
    }
}

// ---------------------------------------------------------------- Line score

@Composable
private fun LineScorePage(game: GameState) {
    observe()
    val upTo = maxOf(game.inning, game.lineScore.maxOfOrNull { it.inning } ?: 1)
    ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        item { Text("Line score", fontWeight = FontWeight.Bold, fontSize = 14.sp) }
        item { LineRow("", "A", "H", Secondary, bold = true) }
        for (i in 1..upTo) {
            val e = game.lineScore.firstOrNull { it.inning == i }
            item { LineRow("$i", e?.top?.toString() ?: "–", e?.bottom?.toString() ?: "–", Color.White) }
        }
        item { LineRow("R", "${game.awayScore}", "${game.homeScore}", Amber, bold = true) }
    }
}

@Composable
private fun LineRow(label: String, away: String, home: String, color: Color, bold: Boolean = false) {
    val weight = if (bold) FontWeight.Bold else FontWeight.Normal
    Row(Modifier.width(120.dp)) {
        Text(label, color = if (bold) color else Secondary, fontWeight = weight, modifier = Modifier.weight(1f), fontSize = 14.sp)
        Text(away, color = color, fontWeight = weight, modifier = Modifier.weight(1f), textAlign = TextAlign.Center, fontSize = 14.sp)
        Text(home, color = color, fontWeight = weight, modifier = Modifier.weight(1f), textAlign = TextAlign.Center, fontSize = 14.sp)
    }
}

// ---------------------------------------------------------------- Setup

@Composable
private fun SetupPage(onEnd: () -> Unit) {
    val state = LocalWear.current
    observe()
    val session = state.session
    // Edits stay local until Start, like the Apple Watch Setup screen; they
    // re-sync whenever new settings arrive while no game is live.
    var s by remember(state.settings, session.isLive) { mutableStateOf(state.settings) }
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        item { Text("Setup", fontWeight = FontWeight.Bold) }
        item { Toggle("Keep score", if (s.keepScore) "Full scorekeeping" else "Count + clock only", s.keepScore) { s = s.copy(keepScore = it) } }
        item {
            Chip(
                onClick = { s = s.copy(sport = if (s.sport == Sport.SOFTBALL) Sport.BASEBALL else Sport.SOFTBALL) },
                label = { Text("Sport") }, secondaryLabel = { Text("${s.sport.displayName} · ${s.sport.regulationInnings} inn") },
                colors = ChipDefaults.secondaryChipColors(), modifier = Modifier.fillMaxWidth(),
            )
        }
        item { Toggle("Use timers", if (s.useTimers) "Tournament clock rules" else "Untimed game", s.useTimers) { s = s.copy(useTimers = it) } }
        if (s.useTimers) {
            item { Stepper("No new", s.noNewInningsMinutes, 10..180, 5, Amber) { s = s.copy(noNewInningsMinutes = it) } }
            item { Stepper("Drop-dead", s.ballGameCutoffMinutes, 10..240, 5, Outs) { s = s.copy(ballGameCutoffMinutes = it) } }
            item { Toggle("Enforce drop-dead", if (s.enforceDropDead) "Prompts at cutoff" else "Advisory only", s.enforceDropDead) { s = s.copy(enforceDropDead = it) } }
        }
        if (s.keepScore) {
            item { Toggle("Run-ahead rule", if (s.runAheadEnabled) s.runAheadSummary() else "Off", s.runAheadEnabled) { s = s.copy(runAheadEnabled = it) } }
            item { Toggle("Allow ties", if (s.allowTies) "Round-robin" else "Finals — no tie", s.allowTies) { s = s.copy(allowTies = it) } }
        }
        if (s.useTimers) {
            item { Toggle("Auto-close idle", if (s.autoCloseOnInactivity) "After no-new, ends if idle" else "Off", s.autoCloseOnInactivity) { s = s.copy(autoCloseOnInactivity = it) } }
            if (s.autoCloseOnInactivity) item { Stepper("Idle limit", s.inactivityTimeoutMinutes, 5..60, 5, Purple) { s = s.copy(inactivityTimeoutMinutes = it) } }
        }
        val valid = !(s.useTimers && s.ballGameCutoffMinutes <= s.noNewInningsMinutes)
        if (!valid) item { Text("Drop-dead must be after no-new", color = Outs, fontSize = 11.sp, textAlign = TextAlign.Center) }
        item {
            Chip(
                onClick = {
                    if (s.useTimers && Build.VERSION.SDK_INT >= 33) notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                    state.startGame(s)
                },
                enabled = valid,
                label = { Text(if (session.isLive) "Restart Game" else "Start Game", fontWeight = FontWeight.Bold) },
                colors = ChipDefaults.primaryChipColors(backgroundColor = Balls, contentColor = Color.Black),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        if (session.isLive) item { WideChip("End Game", Outs, onEnd) }
        item { Text("Regulation: ${s.sport.regulationInnings} innings", color = Secondary, fontSize = 11.sp) }
    }
}

@Composable
private fun Toggle(label: String, note: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    ToggleChip(
        checked = checked, onCheckedChange = onChange,
        label = { Text(label, maxLines = 1) },
        secondaryLabel = { Text(note, maxLines = 2, fontSize = 11.sp) },
        toggleControl = { Icon(ToggleChipDefaults.switchIcon(checked), if (checked) "On" else "Off") },
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun Stepper(label: String, value: Int, range: IntRange, step: Int, tint: Color, onChange: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Panel).padding(horizontal = 6.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        StepButton("−", value > range.first) { onChange((value - step).coerceIn(range)) }
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(label, fontSize = 11.sp, color = Secondary)
            Text("$value min", fontWeight = FontWeight.Bold, color = tint, style = Tabular)
        }
        StepButton("+", value < range.last) { onChange((value + step).coerceIn(range)) }
    }
}

@Composable
private fun StepButton(glyph: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.size(34.dp).clip(CircleShape).background(Color(0xFF3A3A3C)).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(glyph, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = if (enabled) Color.White else Color(0xFF666666)) }
}

@Composable
private fun WideChip(text: String, color: Color?, onClick: () -> Unit) {
    Chip(
        onClick = onClick,
        label = { Text(text, maxLines = 2, fontWeight = if (color != null) FontWeight.Bold else FontWeight.Normal) },
        colors = if (color != null) ChipDefaults.primaryChipColors(backgroundColor = color, contentColor = Color.White) else ChipDefaults.secondaryChipColors(),
        modifier = Modifier.fillMaxWidth(),
    )
}

// ---------------------------------------------------------------- overlays

/** Full-screen, opaque, swallows taps on the pages underneath. */
@Composable
private fun Overlay(content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Color.Black).clickable(remember { MutableInteractionSource() }, null) {},
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun ChoiceOverlay(title: String, message: String?, items: androidx.wear.compose.foundation.lazy.ScalingLazyListScope.() -> Unit) {
    Overlay {
        ScalingLazyColumn(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            item { Text(title, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center) }
            if (message != null) item { Text(message, color = Secondary, fontSize = 12.sp, textAlign = TextAlign.Center) }
            items()
        }
    }
}

@Composable
private fun DropDeadOverlay(game: GameState, timer: GameTimer) {
    val session = LocalWear.current.session
    observe()
    val s = game.settings
    val elapsed = formatClock(timer.elapsed)
    val message = when {
        !s.keepScore -> "$elapsed elapsed. End the game or keep playing?"
        game.homeWinsOnCutoff -> "$elapsed · Home leads batting: score stands"
        else -> "$elapsed · reverts to last full inning"
    }
    fun label(p: DropDeadPreview, prefix: String) = "$prefix ${p.away}–${p.home}" + (p.inning?.let { " (end $it)" } ?: "")
    ChoiceOverlay("Cut-off reached", message) {
        when {
            !s.keepScore -> item { WideChip("End game", Outs) { session.endAtDropDead() } }
            game.homeWinsOnCutoff -> item { WideChip("End — Home win", Outs) { session.endAtDropDead() } }
            else -> {
                val preferred = game.dropDeadPreview(s.allowTies)
                item { WideChip(label(preferred, "End"), Outs) { session.endAtDropDead(s.allowTies) } }
                val alt = game.dropDeadPreview(!s.allowTies)
                if (alt.away != preferred.away || alt.home != preferred.home) {
                    item { WideChip(label(alt, if (s.allowTies) "No tie —" else "Allow tie —"), null) { session.endAtDropDead(!s.allowTies) } }
                }
            }
        }
        item { WideChip("Play on", null) { session.playOn() } }
    }
}

@Composable
private fun RunsEntryOverlay(inning: Int, half: Half, onConfirm: (Int) -> Unit) {
    var runs by remember(inning, half) { mutableIntStateOf(0) }
    Overlay {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("${if (half == Half.TOP) "Away" else "Home"} · ${half.fullName} $inning", fontWeight = FontWeight.Bold, fontSize = 13.sp)
            Text("Runs this half", color = Secondary, fontSize = 11.sp)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StepButton("−", runs > 0) { runs-- }
                Text("$runs", fontSize = 40.sp, fontWeight = FontWeight.Black, modifier = Modifier.width(56.dp), textAlign = TextAlign.Center)
                StepButton("+", true) { runs++ }
            }
            Chip(
                onClick = { onConfirm(runs) }, label = { Text("Confirm", fontWeight = FontWeight.Bold) },
                colors = ChipDefaults.primaryChipColors(backgroundColor = Blue, contentColor = Color.White),
            )
        }
    }
}

@Composable
private fun GameOverOverlay(game: GameState, elapsed: Double, onDone: () -> Unit) {
    observe()
    val reason = game.endReason
    // A fixed, centred card (not a scrolling list) so Done is never clipped on a round face.
    Overlay {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text((reason?.displayName ?: "Final").uppercase(), color = reasonColor(reason), fontWeight = FontWeight.Bold, fontSize = 12.sp)
            if (game.settings.keepScore) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    FinalScore("AWAY", game.awayScore, game.awayScore > game.homeScore)
                    Text("–", fontSize = 20.sp)
                    FinalScore("HOME", game.homeScore, game.homeScore > game.awayScore)
                }
            } else {
                Text("Game ended", modifier = Modifier.padding(vertical = 8.dp))
            }
            Text("Game time ${formatClock(elapsed)}", color = Secondary, fontSize = 12.sp)
            Spacer(Modifier.height(4.dp))
            Chip(
                onClick = onDone, label = { Text("Done", fontWeight = FontWeight.Bold) },
                colors = ChipDefaults.primaryChipColors(backgroundColor = Blue, contentColor = Color.White),
            )
        }
    }
}

@Composable
private fun FinalScore(name: String, score: Int, win: Boolean) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(name, fontSize = 10.sp, color = Secondary)
        Text("$score", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = if (win) Color.White else Secondary)
    }
}

private fun reasonColor(r: GameEndReason?) = when (r) {
    GameEndReason.BALL_GAME_CUTOFF -> Outs
    GameEndReason.NO_NEW_INNINGS_HOME_AHEAD -> Amber
    GameEndReason.REGULATION_COMPLETE -> Balls
    GameEndReason.INACTIVITY -> Purple
    GameEndReason.RUN_AHEAD -> Blue
    GameEndReason.MANUAL, null -> Color.Gray
}

/** Full-screen pulsing flash at no-new / drop-dead. Tap to dismiss; clears itself after six seconds. */
@Composable
private fun Flash(kind: ThresholdKind, onDismiss: () -> Unit) {
    val pulse by rememberInfiniteTransition(label = "flash").animateFloat(
        0.55f, 0.95f, infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "alpha",
    )
    LaunchedEffect(kind) { delay(6_000); onDismiss() }
    val cutoff = kind == ThresholdKind.CUTOFF
    Box(
        Modifier.fillMaxSize().background((if (cutoff) Outs else Amber).copy(alpha = pulse))
            .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (cutoff) "TIME!" else "NO NEW", color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Black)
            Text(if (cutoff) "BALL GAME" else "INNINGS", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
            Text("Tap to dismiss", color = Color.White.copy(alpha = 0.85f), fontSize = 10.sp, modifier = Modifier.padding(top = 4.dp))
        }
    }
}
