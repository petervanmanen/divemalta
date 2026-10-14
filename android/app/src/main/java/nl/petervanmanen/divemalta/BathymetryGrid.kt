package nl.petervanmanen.divemalta

import android.content.Context
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * The bundled depth grid written by shared/tools/make_data.py: EMODnet Bathymetry resampled to
 * ~38 m, with land and sea from the OpenStreetMap coastline. Values are decimetres below sea level
 * (negative), rows north to south; special values mark land and "no data".
 */
class BathymetryGrid private constructor(
    private val cols: Int, private val rows: Int,
    private val lon0: Double, private val lat0: Double, private val step: Double,
    private val land: Short, private val noData: Short,
    private val values: ShortArray,
) {
    sealed interface Sample {
        data class Depth(val metres: Double) : Sample
        data object Land : Sample
        data object NoData : Sample   // sea, but EMODnet has land here so there is no depth
    }

    fun sample(lat: Double, lon: Double): Sample? {
        val x = (lon - lon0) / step
        val y = (lat0 - lat) / step
        if (x < -0.5 || y < -0.5 || x > cols - 0.5 || y > rows - 0.5) return null
        val nearest = value(y.roundToInt(), x.roundToInt())
        if (nearest == land) return Sample.Land
        if (nearest == noData) return Sample.NoData
        val c0 = floor(x).toInt(); val r0 = floor(y).toInt()
        val corners = listOf(value(r0, c0), value(r0, c0 + 1), value(r0 + 1, c0), value(r0 + 1, c0 + 1))
        if (corners.any { it == land || it == noData }) return Sample.Depth(-nearest / 10.0)
        val fx = x - c0; val fy = y - r0
        val top = corners[0] * (1 - fx) + corners[1] * fx
        val bottom = corners[2] * (1 - fx) + corners[3] * fx
        return Sample.Depth(-(top * (1 - fy) + bottom * fy) / 10.0)
    }

    private fun value(r: Int, c: Int): Short =
        values[r.coerceIn(0, rows - 1) * cols + c.coerceIn(0, cols - 1)]

    companion object {
        fun load(context: Context): BathymetryGrid {
            val header = JSONObject(context.assets.open("data/malta-depth.json").bufferedReader().use { it.readText() })
            val bytes = context.assets.open("data/malta-depth.bin").use { it.readBytes() }
            val shorts = ShortArray(bytes.size / 2)
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
            return BathymetryGrid(
                header.getInt("cols"), header.getInt("rows"),
                header.getDouble("lon0"), header.getDouble("lat0"), header.getDouble("step"),
                header.getInt("land").toShort(), header.getInt("noData").toShort(), shorts,
            )
        }
    }
}

/** The text shown for a depth lookup. */
fun BathymetryGrid.Sample?.text(): String = when (this) {
    is BathymetryGrid.Sample.Depth -> when {
        metres < 1 -> "Less than 1 m deep"
        metres < 10 -> "%.1f m deep".format(metres)
        else -> "${metres.roundToInt()} m deep"
    }
    BathymetryGrid.Sample.Land -> "On land"
    BathymetryGrid.Sample.NoData -> "No depth data this close to shore"
    null -> "No depth data"
}
