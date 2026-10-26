package nl.petervanmanen.divemalta

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.systemGestureExclusion
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.List
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Layers
import androidx.compose.material.icons.outlined.LayersClear
import androidx.compose.material.icons.outlined.LocationSearching
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.VerticalAlignBottom
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

val Accent = Color(0xFF0A84FF)
/** Sites you dived (the green of their ring on the map). */
val Visited = Color(0xFF30D158)
private val Glass = Color(0xE6F2FBFD)

@Composable
fun DiveMaltaApp(scene: ScreenshotScene?, diveLogFolder: String? = null) {
    val context = LocalContext.current
    MaterialTheme(colorScheme = lightColorScheme(primary = Accent)) {
        // Loaded in the background so the first frame isn't held up (the depth grid is 3.4 MB).
        var sites by remember { mutableStateOf(emptyList<DiveSite>()) }
        var grid by remember { mutableStateOf<BathymetryGrid?>(null) }
        LaunchedEffect(Unit) {
            withContext(Dispatchers.IO) {
                val loadedSites = DiveSite.load(context)
                withContext(Dispatchers.Main) { sites = loadedSites }
                val loadedGrid = BathymetryGrid.load(context)
                withContext(Dispatchers.Main) { grid = loadedGrid }
            }
        }
        val map = remember { MaltaMap(context) }
        val diveLog = remember {
            DiveLog(context).apply { debugFolder = diveLogFolder?.let { java.io.File(it) } }   // debug builds only (MainActivity)
        }
        LaunchedEffect(sites) { diveLog.setSites(sites) }

        var showSplash by remember { mutableStateOf(scene == null || scene == ScreenshotScene.SPLASH) }
        var showContours by rememberSaveable { mutableStateOf(true) }
        var selected by remember { mutableStateOf<DiveSite?>(null) }
        var showList by remember { mutableStateOf(false) }
        var showAbout by remember { mutableStateOf(false) }
        var following by remember { mutableStateOf(false) }
        var probe by remember { mutableStateOf<Pair<Double, Double>?>(null) }
        var outside by remember { mutableStateOf(false) }
        var toast by remember { mutableStateOf<String?>(null) }
        var mapReady by remember { mutableStateOf(false) }

        // Copy the map data to files and load the style, then start the map.
        LaunchedEffect(Unit) {
            val style = withContext(Dispatchers.IO) { MapAssets.prepareStyle(context) }
            map.onSelectSite = { id -> selected = sites.firstOrNull { it.id == id } }
            map.onTapMap = { probe = null }
            map.onProbe = { lat, lon -> probe = lat to lon }
            map.onOutsideMap = { outside = it }
            map.onStopFollowing = { following = false }
            map.onUserOutsideMap = { toast = "You're outside Malta. This app only has the map of Malta, Gozo and Comino." }
            map.start(style, scene) { mapReady = true }
        }
        LaunchedEffect(mapReady, showContours) { if (mapReady) map.setContours(showContours) }
        LaunchedEffect(mapReady, probe) { if (mapReady) map.setProbe(probe?.first, probe?.second) }
        LaunchedEffect(mapReady, following) { if (mapReady) map.setFollowing(following) }
        LaunchedEffect(mapReady, diveLog.visits) { if (mapReady) map.setVisited(diveLog.visits.keys) }
        LaunchedEffect(toast) { if (toast != null) { delay(3000); toast = null } }
        LaunchedEffect(Unit) {
            if (scene == null) { delay(2500); showSplash = false }
        }
        // Screenshot scenes.
        LaunchedEffect(mapReady, sites) {
            if (!mapReady || scene == null || sites.isEmpty()) return@LaunchedEffect
            delay(1000)
            when (scene) {
                ScreenshotScene.SITE -> selected = sites.firstOrNull { it.id == ScreenshotScene.SITE_ID }
                ScreenshotScene.LIST -> showList = true
                ScreenshotScene.DEPTH -> probe = ScreenshotScene.PROBE_LAT to ScreenshotScene.PROBE_LON
                ScreenshotScene.SETTINGS -> showAbout = true
                else -> {}
            }
        }

        val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            following = result.values.any { it }
        }
        fun toggleFollowing() {
            if (following) { following = false; return }
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (granted) following = true
            else permission.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
        }

        MapLifecycle(map)
        // Your dive log: read at start and again when you come back to the app, for newly exported dives.
        // App Store-style screenshots show the app without one, unless a test folder is given.
        if (scene == null || diveLog.debugFolder != null) DiveLogRefresh(diveLog)
        Box(Modifier.fillMaxSize()) {
            AndroidView(factory = { map.view }, modifier = Modifier.fillMaxSize())

            // Buttons, top right. With gesture navigation the screen edge belongs to the system's back
            // gesture, which swallowed taps on these buttons on some phones: keep them away from the edge
            // and claim their area from the gesture (systemGestureExclusion).
            Surface(
                shape = RoundedCornerShape(22.dp), color = Glass, shadowElevation = 4.dp,
                modifier = Modifier.align(Alignment.TopEnd).safeDrawingPadding().padding(top = 8.dp, end = 20.dp)
                    .systemGestureExclusion(),
            ) {
                Column {
                    IconButton(onClick = { showContours = !showContours }) {
                        Icon(if (showContours) Icons.Outlined.Layers else Icons.Outlined.LayersClear,
                            if (showContours) "Hide depth contours" else "Show depth contours", tint = Accent)
                    }
                    IconButton(onClick = { showList = true }) {
                        Icon(Icons.AutoMirrored.Outlined.List, "Dive sites", tint = Accent)
                    }
                    IconButton(onClick = { toggleFollowing() }) {
                        Icon(if (following) Icons.Filled.MyLocation else Icons.Outlined.LocationSearching,
                            "Show my location", tint = Accent)
                    }
                    IconButton(onClick = { showAbout = true }) {
                        Icon(Icons.Outlined.Settings, "Settings and about", tint = Accent)
                    }
                }
            }

            // Search, top left, clear of the buttons.
            SearchBar(sites, diveLog.visits,
                Modifier.align(Alignment.TopStart).safeDrawingPadding().padding(top = 8.dp, start = 20.dp, end = 88.dp)) { site ->
                following = false; selected = site; map.focus(site.lat, site.lon)
            }

            // Outside-the-map banner and toast, top, below the search bar.
            Column(
                Modifier.align(Alignment.TopCenter).safeDrawingPadding().padding(top = 64.dp, start = 72.dp, end = 72.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                AnimatedVisibility(outside, enter = slideInVertically() + fadeIn(), exit = slideOutVertically() + fadeOut()) {
                    Surface(shape = RoundedCornerShape(16.dp), color = Glass, shadowElevation = 4.dp) {
                        Column(Modifier.padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Outside the map", fontWeight = FontWeight.SemiBold)
                            Text("This app only contains the map of Malta, Gozo and Comino.",
                                style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
                            Spacer(Modifier.height(8.dp))
                            Button(onClick = { following = false; map.showMalta() }) { Text("Back to Malta") }
                        }
                    }
                }
                AnimatedVisibility(toast != null, enter = slideInVertically() + fadeIn(), exit = slideOutVertically() + fadeOut()) {
                    Surface(shape = RoundedCornerShape(24.dp), color = Glass, shadowElevation = 4.dp,
                        modifier = Modifier.clickable { toast = null }) {
                        Text(toast.orEmpty(), Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium, textAlign = TextAlign.Center)
                    }
                }
            }

            // Depth card / hint and credits, bottom.
            Column(
                Modifier.align(Alignment.BottomCenter).fillMaxWidth().safeDrawingPadding().padding(bottom = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                val p = probe
                if (p != null) {
                    val depth = grid?.sample(p.first, p.second).let { if (grid == null) "Looking up depth…" else it.text() }
                    ProbeCard(p.first, p.second, depth) { probe = null }
                } else {
                    Surface(shape = RoundedCornerShape(50), color = Glass, shadowElevation = 2.dp) {
                        Text("Touch and hold the sea to see its depth", Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            style = MaterialTheme.typography.bodySmall)
                    }
                }
                Spacer(Modifier.height(6.dp))
                Text("© OpenStreetMap contributors · Protomaps · Bathymetry © EMODnet", fontSize = 10.sp,
                    color = Color(0xFF5F6B70),
                    modifier = Modifier.background(Color(0xB3FFFFFF), RoundedCornerShape(50)).padding(horizontal = 6.dp))
            }

            selected?.let { site ->
                LaunchedEffect(site.id) { map.focus(site.lat, site.lon).takeIf { scene == null } }
                SiteSheet(site, grid, diveLog.visits[site.id].orEmpty()) { selected = null }
            }
            if (showList) SiteList(sites, diveLog.visits, onDismiss = { showList = false }) { site ->
                showList = false; following = false; selected = site; map.focus(site.lat, site.lon)
            }
            if (showAbout) AboutScreen(diveLog) { showAbout = false }

            AnimatedVisibility(showSplash, enter = fadeIn(), exit = fadeOut()) {
                Splash(Modifier.clickable { showSplash = false })
            }
        }
    }
}

/** Search field on the map, with the best matching sites below it while you type. */
@Composable
private fun SearchBar(sites: List<DiveSite>, visits: Map<String, List<DiveLog.Dive>>, modifier: Modifier,
                      onPick: (DiveSite) -> Unit) {
    var text by remember { mutableStateOf("") }
    var focused by remember { mutableStateOf(false) }
    val focusManager = LocalFocusManager.current
    val suggestions = remember(text, sites) { if (text.isBlank()) emptyList() else SiteSearch.results(text, sites).take(6) }
    fun pick(site: DiveSite) { text = ""; focusManager.clearFocus(); onPick(site) }

    Column(modifier) {
        Surface(shape = RoundedCornerShape(50), color = Glass, shadowElevation = 4.dp) {
            Row(Modifier.height(48.dp).padding(start = 14.dp, end = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.Search, null, tint = Color(0xFF5F6B70))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (text.isEmpty()) Text("Search dive sites", color = Color(0xFF6B7378))
                    BasicTextField(text, { text = it },
                        Modifier.fillMaxWidth().onFocusChanged { focused = it.isFocused },
                        singleLine = true, textStyle = MaterialTheme.typography.bodyLarge, cursorBrush = SolidColor(Accent),
                        // Site names aren't dictionary words.
                        keyboardOptions = KeyboardOptions(KeyboardCapitalization.None, autoCorrectEnabled = false,
                            imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(onSearch = { suggestions.firstOrNull()?.let(::pick) }))
                }
                if (text.isNotEmpty() || focused) {
                    IconButton(onClick = { text = ""; focusManager.clearFocus() }) {
                        Icon(Icons.Filled.Cancel, "Clear search", tint = Color(0xFF8E9599))
                    }
                }
            }
        }
        AnimatedVisibility(focused && text.isNotEmpty(), enter = fadeIn(), exit = fadeOut()) {
            Surface(shape = RoundedCornerShape(20.dp), color = Glass, shadowElevation = 4.dp,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                Column {
                    if (suggestions.isEmpty()) {
                        Text("No dive sites match \"$text\"", Modifier.padding(14.dp), color = Color(0xFF6B7378))
                    }
                    suggestions.forEachIndexed { i, site ->
                        Row(Modifier.fillMaxWidth().clickable { pick(site) }.padding(horizontal = 14.dp, vertical = 9.dp),
                            verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(site.displayName, color = Accent)
                                site.summary?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Color(0xFF6B9FC4)) }
                            }
                            if (visits[site.id] != null) {
                                Icon(Icons.Filled.CheckCircle, "Dived", tint = Visited, modifier = Modifier.size(18.dp))
                            }
                        }
                        if (i < suggestions.lastIndex) HorizontalDivider(Modifier.padding(start = 14.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun ProbeCard(lat: Double, lon: Double, text: String, onClose: () -> Unit) {
    Surface(shape = RoundedCornerShape(16.dp), color = Glass, shadowElevation = 4.dp,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.VerticalAlignBottom, null, tint = Color(0xFFFF9500), modifier = Modifier.size(28.dp))
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(text, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text("%.5f, %.5f · EMODnet, OSM coastline and our own depths".format(lat, lon),
                    style = MaterialTheme.typography.bodySmall, color = Color(0xFF5F6B70))
            }
            IconButton(onClick = onClose) { Icon(Icons.Filled.Close, "Close", tint = Color(0xFF5F6B70)) }
        }
    }
}

/** Reads the dive log folder when the app starts and every time it comes back to the foreground. */
@Composable
private fun DiveLogRefresh(diveLog: DiveLog) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.RESUMED) { diveLog.scan() }
    }
}

/** Forward the activity lifecycle to the MapLibre view. */
@Composable
private fun MapLifecycle(map: MaltaMap) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        map.view.onCreate(null)
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> map.view.onStart()
                Lifecycle.Event.ON_RESUME -> map.view.onResume()
                Lifecycle.Event.ON_PAUSE -> map.view.onPause()
                Lifecycle.Event.ON_STOP -> map.view.onStop()
                else -> {}
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            map.view.onDestroy()
        }
    }
}
