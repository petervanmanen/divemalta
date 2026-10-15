package nl.petervanmanen.divemalta

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * A dive site, from one file in shared/sites/. The build gathers all of them into
 * assets/data/malta-dive-sites.json (shared/tools/gather_sites.py).
 */
data class DiveSite(
    val id: String,              // OpenStreetMap id ("node/123"), or our own ("custom/…")
    val name: String,
    val lat: Double,
    val lon: Double,
    val type: String?,           // wreck, cave, reef, statue, ...
    val maxDepth: String?,       // "36m", "30m+"
    val typicalDepth: String?,
    val level: String?,          // "Advanced (Advanced Open Water)"
    val entry: String?,          // shore, boat
    val shoreAccess: String?,    // Easy, Medium, Hard
    val difficulty: String?,
    val details: String?,
    val conditions: String?,
    val website: String?,
    val sources: List<String>,
) {
    val displayName get() = name

    /** OpenStreetMap page, for sites that come from OSM. */
    val osmUrl get() = if (id.substringBefore("/") in setOf("node", "way", "relation"))
        "https://www.openstreetmap.org/$id" else null

    /** "36m · wreck · shore entry · Advanced" */
    val summary: String?
        get() = listOfNotNull(maxDepth, type, entry?.let { "$it entry" }, level?.substringBefore(" "))
            .joinToString(" · ").ifEmpty { null }

    companion object {
        fun load(context: Context): List<DiveSite> {
            val text = context.assets.open("data/malta-dive-sites.json").bufferedReader().use { it.readText() }
            val array = JSONArray(text)
            return (0 until array.length()).map { i -> from(array.getJSONObject(i)) }
        }

        private fun from(o: JSONObject): DiveSite {
            fun str(key: String) = if (o.isNull(key)) null else o.optString(key).ifEmpty { null }
            val sources = o.optJSONArray("sources")
            return DiveSite(
                id = o.getString("id"), name = o.getString("name"),
                lat = o.getDouble("lat"), lon = o.getDouble("lon"),
                type = str("type"), maxDepth = str("maxDepth"), typicalDepth = str("typicalDepth"),
                level = str("level"), entry = str("entry"), shoreAccess = str("shoreAccess"),
                difficulty = str("difficulty"), details = str("description"), conditions = str("conditions"),
                website = str("website"),
                sources = if (sources == null) emptyList() else (0 until sources.length()).map { sources.getString(it) },
            )
        }
    }
}
