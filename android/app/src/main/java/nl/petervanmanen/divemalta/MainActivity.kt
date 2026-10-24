package nl.petervanmanen.divemalta

import android.content.pm.ApplicationInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import org.maplibre.android.MapLibre

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        MapLibre.getInstance(this)
        val scene = ScreenshotScene.from(intent.getStringExtra("screenshot"))
        // Debug builds: `--es diveLogFolder <path>` reads a test folder without the folder picker.
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        val diveLogFolder = if (debuggable) intent.getStringExtra("diveLogFolder") else null
        setContent { DiveMaltaApp(scene, diveLogFolder) }
    }
}
