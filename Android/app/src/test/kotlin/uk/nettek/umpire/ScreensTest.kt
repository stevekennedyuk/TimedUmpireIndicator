package uk.nettek.umpire

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import uk.nettek.umpire.shared.GameSettings

/**
 * Draws the app's real screens to PNG files in app/build/screens, so layouts
 * can be checked without a device. Run: ./gradlew :app:testDebugUnitTest
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
abstract class ScreensBase(private val tag: String) {
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
        val app = (rule.activity.application as UmpireApp).state
        val s = app.session
        fun ui(block: () -> Unit) = rule.runOnUiThread(block)
        fun minutes(m: Int) = ui { repeat(m) { app.clockSkewMs += 60_000; s.act { registerActivity() }; s.tick() } }

        shot("1_start")

        rule.onNodeWithText("▶  Start game").performClick()
        shot("2_setup")
        rule.onNodeWithText("Cancel").performClick()

        ui {
            app.startGame(GameSettings())
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(2)
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(1)
            s.act { repeat(3) { incrementOut() } }; s.confirmRuns(0)
            s.act { incrementBall(); incrementBall(); incrementStrike(); incrementOut() }
        }
        minutes(31)
        shot("3_live")

        ui { s.act { incrementOut(); incrementOut() } }
        shot("4_runs_entry")
        ui { s.confirmRuns(0) }   // Away still leads 2–1, so no-new doesn't end it

        minutes(24)
        shot("5_no_new_flash")
        ui { s.dismissFlash() }
        shot("6_ball_game_phase")

        minutes(5)
        ui { s.dismissFlash() }
        shot("7_drop_dead")

        ui { s.endAtDropDead() }
        shot("8_game_over")
        ui { s.acknowledgeGameOver() }

        rule.onNodeWithText("History").performClick()
        shot("9_history")
        rule.onNodeWithText("Settings").performClick()
        shot("10_settings")
    }
}

@Config(sdk = [34], qualifiers = "w411dp-h891dp-xxhdpi")
class PhoneScreens : ScreensBase("phone")

@Config(sdk = [34], qualifiers = "w360dp-h640dp-xhdpi")
class SmallPhoneScreens : ScreensBase("small")

@Config(sdk = [34], qualifiers = "w1280dp-h800dp-land-hdpi")
class TabletScreens : ScreensBase("tablet")
