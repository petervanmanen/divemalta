package nl.petervanmanen.divemalta

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.DirectionsWalk
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SiteSheet(site: DiveSite, grid: BathymetryGrid, onDismiss: () -> Unit) {
    val uri = LocalUriHandler.current
    val context = LocalContext.current
    val seabed = when (val s = grid.sample(site.lat, site.lon)) {
        // Shore sites (cave entrances, entry points) are often mapped on the coastline itself.
        BathymetryGrid.Sample.Land -> "On the shore"
        BathymetryGrid.Sample.NoData -> "No data this close to shore"
        else -> s.text()
    }
    val entry = site.entry?.let { e ->
        val access = site.shoreAccess
        if (e == "shore" && access != null) "Shore (${access.lowercase()})" else e.replaceFirstChar { it.uppercase() }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState()) {
        Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp)) {
            Text(site.displayName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Card {
                site.maxDepth?.let { Row(Icons.Outlined.ArrowDownward, "Max depth", it) }
                site.typicalDepth?.let { Row(Icons.Outlined.VerticalAlignBottom, "Typical depth", it) }
                site.level?.let { Row(Icons.Outlined.VerifiedUser, "Level", it) }
                site.type?.let { t -> Row(Icons.Outlined.Sell, "Type", t.replaceFirstChar { it.uppercase() }) }
                entry?.let { Row(Icons.AutoMirrored.Outlined.DirectionsWalk, "Entry", it) }
                site.difficulty?.let { Row(Icons.Outlined.Speed, "Difficulty", it) }
                Row(Icons.Outlined.Water, "Seabed depth here", seabed)
            }
            site.details?.let { Section("Description") { Text(it, Modifier.padding(16.dp)) } }
            site.conditions?.let { Section("Conditions") { Text(it, Modifier.padding(16.dp)) } }
            Spacer(Modifier.height(12.dp))
            Card {
                LinkRow(Icons.Outlined.Directions, "Directions") {
                    val url = "https://www.google.com/maps/dir/?api=1&destination=${site.lat},${site.lon}"
                    context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
                }
                site.website?.let { w -> LinkRow(Icons.Outlined.Language, "Website") { uri.openUri(w) } }
                site.osmUrl?.let { osm -> LinkRow(Icons.Outlined.Map, "View or edit on OpenStreetMap") { uri.openUri(osm) } }
            }
            if (site.sources.isNotEmpty()) {
                Section("Sources") {
                    site.sources.forEach { s -> LinkRow(Icons.Outlined.Link, s.toUri().host ?: s) { uri.openUri(s) } }
                }
                Text("Check depths and conditions with a local dive centre before you dive.",
                    style = MaterialTheme.typography.bodySmall, color = Color(0xFF6B7378), modifier = Modifier.padding(8.dp))
            }
            Text("%.5f, %.5f".format(site.lat, site.lon), style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium, modifier = Modifier.padding(8.dp))
        }
    }
}

@Composable
private fun Row(icon: ImageVector, title: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = Accent, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(14.dp))
        Text(title, Modifier.padding(end = 16.dp))
        Text(value, color = Color(0xFF6B7378), textAlign = TextAlign.End, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun LinkRow(icon: ImageVector, title: String, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Icon(icon, null, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(14.dp))
        Text(title, Modifier.weight(1f))
    }
}

@Composable
private fun Section(title: String, content: @Composable ColumnScope.() -> Unit) {
    Text(title, style = MaterialTheme.typography.titleSmall, color = Color(0xFF6B7378),
        modifier = Modifier.padding(start = 8.dp, top = 16.dp, bottom = 6.dp))
    Card(content = content)
}
