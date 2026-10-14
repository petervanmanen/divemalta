package nl.petervanmanen.divemalta

import android.content.Context
import org.json.JSONArray

/** A dive site, as written by shared/tools/make_data.py (data/malta-dive-sites.json). */
data class DiveSite(
    val id: String,          // "node/123", "way/456"
    val name: String?,
    val lat: Double,
    val lon: Double,
    val maxDepth: String?,   // "30m", "5-30m"
    val type: String?,       // wreck, cave, statue, ...
    val entry: String?,      // shore, boat
    val tags: Map<String, String>,
) {
    val displayName get() = name ?: "Dive site"

    // Our own research (shared/enrichment/sites.json), stored as dive:* tags.
    val level get() = tags["dive:level"]
    val typicalDepth get() = tags["dive:depth_avg"]
    val shoreAccess get() = tags["dive:shore_access"]
    val conditions get() = tags["dive:conditions"]
    val details get() = tags["description"] ?: tags["note"]
    val difficulty get() = tags["scuba_diving:difficulty"]
    val sources get() = tags["dive:sources"].orEmpty().split(" ").filter { it.startsWith("http") }
    val website get() = tags["website"] ?: tags["contact:website"] ?: tags["url"]
    val osmUrl get() = "https://www.openstreetmap.org/$id"

    /** "36m · wreck · shore entry · Advanced" */
    val summary: String?
        get() = listOfNotNull(maxDepth, type, entry?.let { "$it entry" }, level?.substringBefore(" "))
            .joinToString(" · ").ifEmpty { null }

    companion object {
        fun load(context: Context): List<DiveSite> {
            val text = context.assets.open("data/malta-dive-sites.json").bufferedReader().use { it.readText() }
            val array = JSONArray(text)
            return (0 until array.length()).map { i ->
                val o = array.getJSONObject(i)
                val tagsJson = o.getJSONObject("tags")
                DiveSite(
                    id = o.getString("id"),
                    name = o.optString("name").takeIf { !o.isNull("name") && it.isNotEmpty() },
                    lat = o.getDouble("lat"),
                    lon = o.getDouble("lon"),
                    maxDepth = o.optString("maxDepth").takeIf { !o.isNull("maxDepth") && it.isNotEmpty() },
                    type = o.optString("type").takeIf { !o.isNull("type") && it.isNotEmpty() },
                    entry = o.optString("entry").takeIf { !o.isNull("entry") && it.isNotEmpty() },
                    tags = tagsJson.keys().asSequence().associateWith { tagsJson.getString(it) },
                )
            }
        }
    }
}
