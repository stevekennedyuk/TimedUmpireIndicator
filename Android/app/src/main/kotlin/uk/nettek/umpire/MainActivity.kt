package uk.nettek.umpire

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalView
import uk.nettek.umpire.ui.AppTheme
import uk.nettek.umpire.ui.LocalApp
import uk.nettek.umpire.ui.Root

class MainActivity : ComponentActivity() {
    private val state get() = (application as UmpireApp).state

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            // Keep the screen on while a game is live; normal auto-lock otherwise.
            val view = LocalView.current
            val keepAwake = state.keepAwake
            DisposableEffect(keepAwake) {
                view.keepScreenOn = keepAwake
                onDispose { view.keepScreenOn = false }
            }
            CompositionLocalProvider(LocalApp provides state) {
                AppTheme { Root() }
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
