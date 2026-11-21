package uk.nettek.umpire.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.delay
import uk.nettek.umpire.AppState
import uk.nettek.umpire.shared.GameEndReason
import uk.nettek.umpire.shared.InningRuns
import uk.nettek.umpire.shared.ThresholdKind

val LocalApp = staticCompositionLocalOf<AppState> { error("No AppState") }

/**
 * Subscribe this composable to session changes. The engine objects (GameState,
 * GameTimer) are mutable and keep their identity, so Compose would otherwise
 * skip redrawing anything that only receives them as parameters.
 */
// Returns a value on purpose: a Unit-returning composable gets its own restart
// scope, and the read would then only redraw itself, not the caller.
@Composable
fun observeSession(): Int = LocalApp.current.revision

// The same meanings as the iOS colours.
val BallsGreen = Color(0xFF34C759)
val StrikesYellow = Color(0xFFFFCC00)
val OutsRed = Color(0xFFFF3B30)
val AmberOrange = Color(0xFFFF9500)
val PausedYellow = Color(0xFFFFD60A)
val RunRuleBlue = Color(0xFF0A84FF)
val IdlePurple = Color(0xFFAF52DE)

@Composable
fun AppTheme(content: @Composable () -> Unit) {
    val scheme = if (isSystemInDarkTheme()) {
        darkColorScheme(primary = RunRuleBlue, secondary = BallsGreen, error = OutsRed)
    } else {
        lightColorScheme(primary = Color(0xFF0060C0), secondary = Color(0xFF1E8E3E), error = Color(0xFFC62828))
    }
    MaterialTheme(colorScheme = scheme, content = content)
}

val Secondary: Color @Composable get() = MaterialTheme.colorScheme.onSurfaceVariant
private val CardShape = RoundedCornerShape(16.dp)

fun reasonColor(reason: GameEndReason?): Color = when (reason) {
    GameEndReason.BALL_GAME_CUTOFF -> OutsRed
    GameEndReason.NO_NEW_INNINGS_HOME_AHEAD -> AmberOrange
    GameEndReason.REGULATION_COMPLETE -> BallsGreen
    GameEndReason.INACTIVITY -> IdlePurple
    GameEndReason.RUN_AHEAD -> RunRuleBlue
    GameEndReason.MANUAL, null -> Color.Gray
}

/** A rounded grouped card, like the iOS .quaternary panels. */
@Composable
fun Panel(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Surface(modifier.fillMaxWidth(), shape = CardShape, color = MaterialTheme.colorScheme.surfaceVariant) {
        Column(Modifier.padding(16.dp), content = content)
    }
}

/** Big tap target: tap adds, long-press subtracts. */
@Composable
fun BigCountCell(label: String, value: Int, pips: Int, color: Color, modifier: Modifier = Modifier, onIncrement: () -> Unit, onDecrement: () -> Unit) {
    Column(
        modifier
            .clip(RoundedCornerShape(14.dp))
            .background(color.copy(alpha = 0.15f))
            .combinedClickable(onClick = onIncrement, onLongClick = onDecrement)
            .semantics { contentDescription = "$label: $value. Tap to add, long-press to subtract" }
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, color = color, fontWeight = FontWeight.Bold, fontSize = 13.sp, letterSpacing = 1.sp)
        Text("$value", fontSize = 56.sp, fontWeight = FontWeight.Black, lineHeight = 60.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(pips) { i ->
                Box(Modifier.size(8.dp).clip(CircleShape).background(if (i < value) color else color.copy(alpha = 0.25f)))
            }
        }
    }
}

/** Away / Home line score with a run total; "–" for halves not yet played. */
@Composable
fun LineScoreGrid(lineScore: List<InningRuns>, away: Int, home: Int, upTo: Int = lineScore.maxOfOrNull { it.inning } ?: 0) {
    val innings = (1..maxOf(1, upTo)).toList()
    val cell = 28.dp
    Row(Modifier.horizontalScroll(rememberScrollState())) {
        Column {
            Spacer(Modifier.padding(vertical = 10.dp))
            Text("Away", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 4.dp).width(56.dp))
            Text("Home", fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 4.dp).width(56.dp))
        }
        for (i in innings) {
            val e = lineScore.firstOrNull { it.inning == i }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("$i", color = Secondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 4.dp))
                RunCell(e?.top, cell)
                RunCell(e?.bottom, cell)
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("R", color = AmberOrange, fontSize = 12.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 4.dp))
            Text("$away", fontWeight = FontWeight.Bold, modifier = Modifier.width(cell).padding(vertical = 4.dp), textAlign = TextAlign.Center)
            Text("$home", fontWeight = FontWeight.Bold, modifier = Modifier.width(cell).padding(vertical = 4.dp), textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun RunCell(runs: Int?, width: Dp) {
    Text(
        runs?.toString() ?: "–",
        color = if ((runs ?: 0) > 0) MaterialTheme.colorScheme.onSurface else Secondary,
        modifier = Modifier.width(width).padding(vertical = 4.dp),
        textAlign = TextAlign.Center,
    )
}

/** Title + footnote + switch row for settings forms. */
@Composable
fun SwitchRow(title: String, note: String?, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable { onChange(!checked) }.padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title)
            if (note != null) Text(note, color = Secondary, fontSize = 13.sp)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

/** "Label …  value  [−] [+]" stepper. */
@Composable
fun StepperRow(label: String, value: Int, range: IntRange, step: Int = 1, display: (Int) -> String = { "$it" }, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f))
        Text(display(value), fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 12.dp),
            color = if (value == 0 && display(0) == "Off") Secondary else MaterialTheme.colorScheme.onSurface)
        FilledTonalIconButton(onClick = { onChange((value - step).coerceIn(range)) }, enabled = value > range.first) {
            Text("−", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
        FilledTonalIconButton(onClick = { onChange((value + step).coerceIn(range)) }, enabled = value < range.last) {
            Text("+", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(
        text.uppercase(), color = Secondary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.5.sp,
        modifier = Modifier.padding(start = 4.dp, top = 20.dp, bottom = 6.dp),
    )
}

/** A simple drawn baseball (the core icon set has none). */
@Composable
fun BaseballIcon(size: Dp, color: Color) {
    Canvas(Modifier.size(size)) {
        val w = this.size.width
        val stroke = Stroke(width = w * 0.07f)
        drawCircle(color, radius = w * 0.46f, style = stroke)
        drawArc(color, 300f, 120f, false, Offset(-w * 0.55f, w * 0.05f), Size(w * 0.9f, w * 0.9f), style = stroke)
        drawArc(color, 120f, 120f, false, Offset(w * 0.65f, w * 0.05f), Size(w * 0.9f, w * 0.9f), style = stroke)
    }
}

/**
 * Full-screen pulsing flash when a timer threshold is crossed — impossible to
 * miss in sunlight. Tap to dismiss; clears itself after six seconds.
 */
@Composable
fun ThresholdFlash(kind: ThresholdKind, onDismiss: () -> Unit) {
    val pulse by rememberInfiniteTransition(label = "flash").animateFloat(
        0.55f, 0.95f, infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "alpha",
    )
    LaunchedEffect(kind) {
        delay(6_000)
        onDismiss()
    }
    val cutoff = kind == ThresholdKind.CUTOFF
    // Its own window, so it sits above any dialog that's up (the drop-dead
    // decision appears at the same moment as the cutoff flash).
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
    Box(
        Modifier.fillMaxSize()
            .background((if (cutoff) OutsRed else AmberOrange).copy(alpha = pulse))
            .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (cutoff) "⏹" else "⚠", color = Color.White, fontSize = 64.sp)
            Text(if (cutoff) "TIME!" else "NO NEW", color = Color.White, fontSize = 64.sp, fontWeight = FontWeight.Black)
            Text(if (cutoff) "BALL GAME" else "INNINGS", color = Color.White, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold)
            Text("Tap to dismiss", color = Color.White.copy(alpha = 0.85f), modifier = Modifier.padding(top = 12.dp))
        }
    }
    }
}

/** Tabular figures, so the clock digits don't jiggle as they change. */
val TabularDigits = TextStyle(fontFeatureSettings = "tnum")
