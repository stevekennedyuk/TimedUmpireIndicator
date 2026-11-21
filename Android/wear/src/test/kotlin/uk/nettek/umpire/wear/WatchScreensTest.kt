package uk.nettek.umpire.wear

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import uk.nettek.umpire.shared.GameSettings

/**
 * Draws the watch screens to PNG files in wear/build/screens, so layouts can be
 * checked without a watch. Run: ./gradlew :wear:testDebugUnitTest
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
abstract class WatchScreensBase(private val tag: String) {
    @get:Rule
    val rule = createAndroidComposeRule<MainActivity>()

    private fun shot(name: String) {
        rule.runOnUiThread { androidx.compose.runtime.snapshots.Snapshot.sendApplyNotifications() }
        org.robolectric.shadows.ShadowLooper.idleMainLooper()
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("build/screens/${tag}_$name.png")
    }

    @Test
    fun screens() {
        rule.mainClock.autoAdvance = false
        val state = (rule.activity.application as WearApp).state
        val s = state.session
        fun ui(block: () -> Unit) = rule.runOnUiThread(block)
        fun minutes(m: Int) = ui { repeat(m) { state.clockSkewMs += 60_000; s.act { registerActivity() }; s.tick() } }

        shot("1_setup")

        ui {
            state.startGame(GameSettings())
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(2)
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(1)
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(0)
            s.act { incrementBall(); incrementBall(); incrementStrike() }
        }
        minutes(31)
        shot("2_indicator")

        ui { s.act { repeat(3) { incrementOut() } } }
        shot("3_runs_entry")
        ui { s.confirmRuns(0) }

        minutes(24)
        shot("4_no_new_flash")
        ui { s.dismissFlash() }
        shot("5_ball_game")

        minutes(5)
        ui { s.dismissFlash() }
        shot("6_drop_dead")

        ui { s.endAtDropDead() }
        shot("7_game_over")

        ui {
            s.acknowledgeGameOver()
            state.startGame(GameSettings(keepScore = false, useTimers = false))
            s.act { incrementBall(); incrementStrike(); incrementStrike(); incrementOut() }
        }
        minutes(12)
        shot("8_untimed_indicator")
    }
}

@Config(sdk = [34], qualifiers = "w192dp-h192dp-round-watch-xhdpi")
class SmallRoundScreens : WatchScreensBase("round192")

@Config(sdk = [34], qualifiers = "w225dp-h225dp-round-watch-xhdpi")
class LargeRoundScreens : WatchScreensBase("round225")

@Config(sdk = [34], qualifiers = "w180dp-h180dp-notround-watch-xhdpi")
class SquareScreens : WatchScreensBase("square180")
