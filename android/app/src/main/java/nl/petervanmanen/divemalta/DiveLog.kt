package nl.petervanmanen.divemalta

import android.content.Context
import android.content.Intent
import android.location.Location
import android.net.Uri
import android.provider.DocumentsContract
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import androidx.core.net.toUri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File

/**
 * Your own dives, read from the FIT files in a folder you choose (for example a Google Drive or
 * Downloads folder your dive computer's app exports to). Dives in Malta are matched to the nearest
 * dive site, which is then shown as visited. Everything stays on the phone. Same rules as the iOS
 * app (ios/DiveMalta/DiveLog.swift).
 */
class DiveLog(private val context: Context) {
    data class Dive(val file: String, val fit: FitFile.Dive)

    companion object {
        /**
         * A dive counts for a site when it starts within this distance of it. Dive computers get their
         * position at the surface, so this is where you got in (shore) or where the boat was.
         */
        const val MATCH_DISTANCE_M = 400f
        private const val PREFS = "dive-log"
        private const val KEY_FOLDER = "folder"
        private const val RETRY_DELAY_MS = 5_000L
        private const val MAX_RETRIES = 12
    }

    var folderName by mutableStateOf<String?>(null); private set
    var isScanning by mutableStateOf(false); private set
    var error by mutableStateOf<String?>(null); private set
    /** All dives found in the folder, also outside Malta, newest first. */
    var dives by mutableStateOf(emptyList<Dive>()); private set
    var fitFileCount by mutableIntStateOf(0); private set
    /** Dives per site id, newest first. */
    var visits by mutableStateOf(emptyMap<String, List<Dive>>()); private set
    /** Dives in Malta that aren't near any known site. */
    var unmatched by mutableStateOf(emptyList<Dive>()); private set

    val maltaDiveCount get() = visits.values.sumOf { it.size } + unmatched.size

    /** For testing on an emulator: `--es diveLogFolder <path on the device>` reads that folder directly (debug builds). */
    var debugFolder: File? = null

    private var sites = emptyList<DiveSite>()
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val cacheFile = File(context.filesDir, "dive-log-cache.json")
    private val scanLock = Mutex()

    fun setSites(sites: List<DiveSite>) {
        this.sites = sites
        match()
    }

    /** Remembers the folder (picked with the system folder picker) and reads it. */
    suspend fun choose(tree: Uri) {
        try {
            context.contentResolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: SecurityException) {
            error = "Couldn't keep access to this folder."
            return
        }
        // Give up the permission for a previous folder.
        prefs.getString(KEY_FOLDER, null)?.toUri()?.takeIf { it != tree }?.let { old ->
            runCatching { context.contentResolver.releasePersistableUriPermission(old, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        }
        prefs.edit { putString(KEY_FOLDER, tree.toString()) }
        cacheFile.delete()
        scan()
    }

    fun forget() {
        prefs.getString(KEY_FOLDER, null)?.toUri()?.let { old ->
            runCatching { context.contentResolver.releasePersistableUriPermission(old, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
        }
        prefs.edit { remove(KEY_FOLDER) }
        cacheFile.delete()
        folderName = null; error = null; dives = emptyList(); fitFileCount = 0
        match()
    }

    /**
     * Reads the folder again; called at start and whenever the app comes back to the foreground, so
     * newly exported dives show up. Files that haven't changed since the last scan come from the cache.
     * A cloud folder (Google Drive) may still be fetching its file list, or a file may not be readable
     * yet: then the folder is read again every few seconds (for up to a minute) until it's all in, so
     * new dives show up without reading the folder by hand.
     */
    suspend fun scan() {
        for (attempt in 0..MAX_RETRIES) {
            if (attempt > 0) delay(RETRY_DELAY_MS)
            val complete = scanOnce() ?: return
            if (complete) return
        }
    }

    /** One read of the folder: true when everything was read, false when some of it wasn't there yet, null when skipped. */
    private suspend fun scanOnce(): Boolean? {
        if (!scanLock.tryLock()) return null
        try {
            val debug = debugFolder
            val tree = prefs.getString(KEY_FOLDER, null)?.toUri()
            val source = when {
                debug != null -> FileSource(debug)
                tree != null -> TreeSource(context, tree)
                else -> return null
            }
            isScanning = true
            val result = withContext(Dispatchers.IO) { read(source) }
            folderName = result.folderName
            error = result.error
            fitFileCount = result.fitFiles
            dives = result.dives.sortedByDescending { it.fit.startMillis ?: Long.MIN_VALUE }
            match()
            return !result.incomplete
        } finally {
            isScanning = false
            scanLock.unlock()
        }
    }

    private fun match() {
        val visits = HashMap<String, MutableList<Dive>>()
        val unmatched = ArrayList<Dive>()
        val distance = FloatArray(1)
        for (dive in dives) {
            if (!MaltaMap.contains(dive.fit.latitude, dive.fit.longitude)) continue
            var best: DiveSite? = null
            var bestDistance = Float.MAX_VALUE
            for (site in sites) {
                Location.distanceBetween(dive.fit.latitude, dive.fit.longitude, site.lat, site.lon, distance)
                if (distance[0] < bestDistance) { bestDistance = distance[0]; best = site }
            }
            if (best != null && bestDistance <= MATCH_DISTANCE_M) visits.getOrPut(best.id) { ArrayList() }.add(dive)
            else unmatched.add(dive)
        }
        this.visits = visits
        this.unmatched = unmatched
    }

    // Reading the folder (on Dispatchers.IO)

    private class Entry(val key: String, val size: Long, val modified: Long, val open: () -> ByteArray?)

    private interface Source {
        val name: String?
        /** Every .fit file in the folder and its subfolders. */
        fun fitFiles(): List<Entry>
        /** After fitFiles(): whether the provider said it was still fetching part of the list. */
        val stillLoading: Boolean get() = false
    }

    /** A folder from the system folder picker (Storage Access Framework). */
    private class TreeSource(private val context: Context, private val tree: Uri) : Source {
        private val resolver = context.contentResolver
        override var stillLoading = false; private set
        override val name: String? = runCatching {
            val doc = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            resolver.query(doc, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        }.getOrNull()

        override fun fitFiles(): List<Entry> {
            val out = ArrayList<Entry>()
            val pending = ArrayDeque(listOf(DocumentsContract.getTreeDocumentId(tree) to ""))
            val columns = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            )
            while (pending.isNotEmpty()) {
                val (parent, path) = pending.removeFirst()
                val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
                resolver.query(children, columns, null, null, null)?.use { c ->
                    // Cloud providers answer with what they have and fetch the rest in the background.
                    if (c.extras.getBoolean(DocumentsContract.EXTRA_LOADING)) stillLoading = true
                    while (c.moveToNext()) {
                        val id = c.getString(0)
                        val name = c.getString(1) ?: continue
                        val relative = if (path.isEmpty()) name else "$path/$name"
                        if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                            pending.add(id to relative)
                        } else if (name.endsWith(".fit", ignoreCase = true)) {
                            val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                            out.add(Entry(relative, if (c.isNull(3)) -1 else c.getLong(3), if (c.isNull(4)) 0 else c.getLong(4)) {
                                runCatching { resolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
                            })
                        }
                    }
                }
            }
            return out
        }
    }

    /** A plain folder on the device, for testing (debug builds only). */
    private class FileSource(private val folder: File) : Source {
        override val name: String = folder.name
        override fun fitFiles() = folder.walkTopDown()
            .filter { it.isFile && it.name.endsWith(".fit", ignoreCase = true) }
            .map { f -> Entry(f.relativeTo(folder).path, f.length(), f.lastModified()) { runCatching { f.readBytes() }.getOrNull() } }
            .toList()
    }

    private class ReadResult(val folderName: String?, val dives: List<Dive>, val fitFiles: Int, val error: String?,
                             val incomplete: Boolean = false)

    private fun read(source: Source): ReadResult {
        val files = try {
            source.fitFiles()
        } catch (e: Exception) {   // SecurityException when the permission is gone, or a provider error
            return ReadResult(source.name, emptyList(), 0, "Couldn't read the dive log folder. Choose it again.")
        }
        val cache = runCatching { JSONObject(cacheFile.readText()) }.getOrNull() ?: JSONObject()
        val newCache = JSONObject()
        val dives = ArrayList<Dive>()
        var unread = 0
        for (file in files) {
            val cached = cache.optJSONObject(file.key)
            val entry = if (cached != null && file.size >= 0 && cached.optLong("size") == file.size &&
                cached.optLong("modified") == file.modified) {
                cached
            } else {
                val bytes = file.open() ?: run { unread++; continue }   // not readable now; scan() tries again
                val dive = runCatching { FitFile.dive(bytes) }.getOrNull()
                JSONObject().apply {
                    put("size", bytes.size.toLong()); put("modified", file.modified)
                    if (dive != null) put("dive", JSONObject().apply {
                        dive.startMillis?.let { put("start", it) }
                        put("lat", dive.latitude); put("lon", dive.longitude)
                        dive.maxDepth?.let { put("maxDepth", it) }
                    })
                }
            }
            newCache.put(file.key, entry)
            entry.optJSONObject("dive")?.let { d ->
                dives.add(Dive(file.key, FitFile.Dive(
                    startMillis = if (d.has("start")) d.getLong("start") else null,
                    latitude = d.getDouble("lat"), longitude = d.getDouble("lon"),
                    maxDepth = if (d.has("maxDepth")) d.getDouble("maxDepth") else null,
                )))
            }
        }
        runCatching { cacheFile.writeText(newCache.toString()) }
        return ReadResult(source.name, dives, files.size, null, incomplete = unread > 0 || source.stillLoading)
    }
}
