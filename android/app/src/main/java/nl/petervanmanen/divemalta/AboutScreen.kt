package nl.petervanmanen.divemalta

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch

/** Settings (your dive log folder), credits for the data, and the open-source licences (data/Licenses.txt + Android libraries). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(diveLog: DiveLog, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    val licences = remember { context.assets.open("data/Licenses.txt").bufferedReader().use { it.readText() } }
    val version = remember {
        context.packageManager.getPackageInfo(context.packageName, 0).let { "${it.versionName} (${it.longVersionCode})" }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp)) {
            Text("Dive Malta", style = MaterialTheme.typography.titleLarge)
            DiveLogSettings(diveLog)
            Heading("About")
            Text("Dive sites of Malta, Gozo and Comino with depth contours, on a map that works offline.")
            Text("Version $version", color = Color(0xFF6B7378), modifier = Modifier.padding(top = 4.dp))
            Spacer(Modifier.height(16.dp))
            Card { Text("Depths, levels and conditions are a guide only. Always check with a local dive centre and dive within your training.",
                Modifier.padding(16.dp)) }

            Heading("Data")
            Credit("Map data © OpenStreetMap contributors, ODbL") { uri.openUri("https://www.openstreetmap.org/copyright") }
            Credit("Map tiles: Protomaps") { uri.openUri("https://protomaps.com") }
            Credit("Bathymetry © EMODnet Bathymetry Consortium, CC BY 4.0") { uri.openUri("https://emodnet.ec.europa.eu/en/bathymetry") }
            Text("Dive site details researched from maltadives.com, Calypso Sub-Aqua Club and others; see each site.",
                Modifier.padding(vertical = 8.dp))

            Heading("Open-source licences")
            Text("Android app: AndroidX and Jetpack Compose (Apache License 2.0), MapLibre Native for Android " +
                "(BSD 2-Clause, text below).", Modifier.padding(bottom = 8.dp))
            Text(licences, fontFamily = FontFamily.Monospace, fontSize = 11.sp, lineHeight = 14.sp)
        }
    }
}

@Composable
private fun DiveLogSettings(diveLog: DiveLog) {
    val scope = rememberCoroutineScope()
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { tree ->
        if (tree != null) scope.launch { diveLog.choose(tree) }
    }
    Heading("My dives")
    Card {
        Column(Modifier.padding(vertical = 8.dp)) {
            val folder = diveLog.folderName
            if (folder != null || diveLog.isScanning) {
                Value("Folder", if (diveLog.isScanning) "Reading…" else folder.orEmpty())
                if (!diveLog.isScanning) {
                    Value("FIT files", "${diveLog.fitFileCount}")
                    Value("Dives", "${diveLog.dives.size}")
                    Value("Dives in Malta", "${diveLog.maltaDiveCount}")
                    Value("Dive sites visited", "${diveLog.visits.size}")
                }
                TextButton(onClick = { picker.launch(null) }, Modifier.padding(horizontal = 8.dp)) { Text("Choose another folder") }
                TextButton(onClick = { scope.launch { diveLog.scan() } }, enabled = !diveLog.isScanning,
                    modifier = Modifier.padding(horizontal = 8.dp)) { Text("Read folder again") }
                TextButton(onClick = { diveLog.forget() }, Modifier.padding(horizontal = 8.dp),
                    colors = ButtonDefaults.textButtonColors(contentColor = Color(0xFFD32F2F))) { Text("Stop using dive log") }
            } else {
                TextButton(onClick = { picker.launch(null) }, Modifier.padding(horizontal = 8.dp)) { Text("Choose folder") }
            }
            diveLog.error?.let {
                Text(it, color = Color(0xFFD32F2F), style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
            }
        }
    }
    Text("Choose a folder with FIT files from your dive computer, for example in Google Drive or Downloads. " +
        "Dives in Malta are matched to the nearest dive site (within ${DiveLog.MATCH_DISTANCE_M.toInt()} m of where " +
        "you started), or to a site named in the file name, like \"Cirkewwa right arch.fit\". Those sites get a green ring on the map. The files are only read on this device.",
        style = MaterialTheme.typography.bodySmall, color = Color(0xFF6B7378), modifier = Modifier.padding(8.dp))
}

@Composable
private fun Value(title: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        Text(title, Modifier.weight(1f))
        Text(value, color = Color(0xFF6B7378))
    }
}

@Composable
private fun Heading(text: String) = Text(text, style = MaterialTheme.typography.titleSmall, color = Color(0xFF6B7378),
    modifier = Modifier.padding(top = 20.dp, bottom = 4.dp))

@Composable
private fun Credit(text: String, onClick: () -> Unit) =
    TextButton(onClick = onClick, contentPadding = PaddingValues(0.dp)) { Text(text, Modifier.fillMaxWidth()) }
