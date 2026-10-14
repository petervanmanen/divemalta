package nl.petervanmanen.divemalta

import android.content.Context
import java.io.File

/**
 * The map reads its tiles, style, fonts and GeoJSON from files, so the bundled assets/data folder
 * is copied to the app's files once per app version. Returns the style JSON with {ASSETS} pointing there.
 */
object MapAssets {
    fun prepareStyle(context: Context): String {
        val dir = File(context.filesDir, "data")
        val stamp = File(dir, ".version")
        val version = context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime.toString()
        if (!stamp.exists() || stamp.readText() != version) {
            dir.deleteRecursively()
            copyAssetDir(context, "data", dir)
            stamp.writeText(version)
        }
        return File(dir, "style.json").readText().replace("{ASSETS}", "file://${dir.absolutePath}")
    }

    private fun copyAssetDir(context: Context, assetPath: String, target: File) {
        val children = context.assets.list(assetPath).orEmpty()
        if (children.isEmpty()) {
            target.parentFile?.mkdirs()
            context.assets.open(assetPath).use { input -> target.outputStream().use { input.copyTo(it) } }
        } else {
            target.mkdirs()
            children.forEach { copyAssetDir(context, "$assetPath/$it", File(target, it)) }
        }
    }
}
