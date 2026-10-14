package nl.petervanmanen.divemalta

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Opening screen: sunset over the cliffs of Gozo. Photo by the app's author, all rights reserved. */
@Composable
fun Splash(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize()) {
        Image(painterResource(R.drawable.splash), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(
            0f to Color.Black.copy(alpha = 0.45f), 0.35f to Color.Transparent,
            0.65f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.6f))))
        val shadow = Shadow(Color.Black.copy(alpha = 0.4f), blurRadius = 12f)
        Column(Modifier.align(Alignment.TopCenter).padding(top = 110.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Dive Malta", style = TextStyle(fontSize = 44.sp, fontWeight = FontWeight.Bold, color = Color.White, shadow = shadow))
            Spacer(Modifier.height(6.dp))
            Text("Dive sites of Malta, Gozo and Comino",
                style = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Color.White, shadow = shadow))
        }
    }
}
