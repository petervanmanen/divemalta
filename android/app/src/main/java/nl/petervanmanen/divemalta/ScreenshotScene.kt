package nl.petervanmanen.divemalta

/**
 * Fixed app states for Play Store screenshots, chosen with an intent extra:
 * `adb shell am start -n nl.petervanmanen.divemalta/.MainActivity --es screenshot map` (see
 * android/tools/screenshots.sh). Without it the app behaves normally.
 */
enum class ScreenshotScene {
    SPLASH, MAP, CONTOURS, SITE, DEPTH, LIST,
    /** Only for checking the settings screen; not a Play Store screenshot. */
    SETTINGS;

    /** Where the map starts (lat, lon, zoom); null = all of Malta. */
    val camera: Triple<Double, Double, Double>?
        get() = when (this) {
            CONTOURS, DEPTH -> Triple(36.0100, 14.3330, 12.8)   // Comino and Ċirkewwa
            SITE -> Triple(35.8128, 14.4496, 14.6)              // Um El Faroud above the sheet
            else -> null
        }

    companion object {
        const val SITE_ID = "node/663869707"   // Um El Faroud
        const val PROBE_LAT = 36.0080
        const val PROBE_LON = 14.3150

        fun from(value: String?) = entries.firstOrNull { it.name.equals(value, ignoreCase = true) }
    }
}
