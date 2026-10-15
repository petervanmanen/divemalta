package nl.petervanmanen.divemalta

import android.content.Context
import java.io.File

/**
 * The bundled map style. Contours, dive sites, fonts and icons are read straight from the app's
 * assets/data folder (asset://). MapLibre 13.6 can't read PMTiles from assets yet (it needs random
 * access), so only malta.pmtiles is copied to the app's files, once per app version.
 */
object MapAssets {
    fun prepareStyle(context: Context): String {
        val tiles = File(context.filesDir, "malta.pmtiles")
        val stamp = File(context.filesDir, "malta.pmtiles.version")
        val version = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString()
        if (!tiles.exists() || !stamp.exists() || stamp.readText() != version) {
            File(context.filesDir, "data").deleteRecursively()   // the full copy older versions made
            val tmp = File(context.filesDir, "malta.pmtiles.tmp")
            context.assets.open("data/malta.pmtiles").use { input -> tmp.outputStream().use { input.copyTo(it) } }
            tmp.renameTo(tiles)
            stamp.writeText(version)
        }
        return context.assets.open("data/style.json").bufferedReader().use { it.readText() }
            .replace("pmtiles://{ASSETS}/malta.pmtiles", "pmtiles://file://${tiles.absolutePath}")
            .replace("{ASSETS}", "asset://data")
    }
}
