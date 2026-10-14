package nl.petervanmanen.divemalta

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SiteList(sites: List<DiveSite>, onDismiss: () -> Unit, onPick: (DiveSite) -> Unit) {
    var search by remember { mutableStateOf("") }
    val filtered = remember(search) {
        if (search.isBlank()) sites else sites.filter { it.displayName.contains(search.trim(), ignoreCase = true) }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Text("${sites.size} dive sites", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 20.dp))
        OutlinedTextField(search, { search = it }, Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            placeholder = { Text("Search dive sites") }, leadingIcon = { Icon(Icons.Outlined.Search, null) },
            singleLine = true, shape = MaterialTheme.shapes.extraLarge)
        LazyColumn(Modifier.fillMaxWidth()) {
            items(filtered, key = { it.id }) { site ->
                Column(Modifier.fillMaxWidth().clickable { onPick(site) }.padding(horizontal = 20.dp, vertical = 10.dp)) {
                    Text(site.displayName, color = Accent)
                    site.summary?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = Color(0xFF6B9FC4)) }
                }
                HorizontalDivider(Modifier.padding(start = 20.dp))
            }
            if (filtered.isEmpty()) item {
                Text("No dive sites match \"$search\"", Modifier.padding(24.dp), color = Color(0xFF6B7378))
            }
        }
    }
}
