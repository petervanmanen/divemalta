package nl.petervanmanen.divemalta

import kotlin.math.max

/**
 * Reads just enough of a Garmin FIT activity file to tell whether it is a dive, and where, when and
 * how deep. FIT is a binary format of definition messages (the layout of a message type) and data
 * messages (values in that layout); see the FIT protocol in Garmin's FIT SDK. Same rules as the iOS
 * app (ios/DiveMalta/FitFile.swift).
 *
 * Used messages and fields:
 * - session (18): start_time (2), start_position_lat/long (3, 4), sport (5), sub_sport (6)
 * - sport (12): sport (0), sub_sport (1)
 * - record (20): position_lat/long (0, 1), depth (92, mm)
 */
object FitFile {
    data class Dive(
        val startMillis: Long?,   // UTC
        val latitude: Double,
        val longitude: Double,
        val maxDepth: Double?,    // metres
    )

    class ParseException(message: String) : Exception(message)

    /** sport "diving"; sub sports single gas, multi gas, gauge, apnea, apnea hunting and CCR diving. */
    private const val DIVING_SPORT = 53
    private val DIVING_SUB_SPORTS = setOf(53, 54, 55, 56, 57, 63)
    /** FIT times count seconds from 31 December 1989 00:00 UTC. */
    private const val FIT_EPOCH_SECONDS = 631_065_600L

    /** The dive in this file, or null when it isn't a dive or has no position. */
    fun dive(bytes: ByteArray): Dive? {
        var sport: Int? = null
        var subSport: Int? = null
        var start: Long? = null
        var sessionPosition: Pair<Int, Int>? = null
        var firstPosition: Pair<Int, Int>? = null
        var maxDepth = 0L

        forEachMessage(bytes) { global, value ->
            when (global) {
                18 -> {
                    value(5)?.let { sport = it.toInt() }
                    value(6)?.let { subSport = it.toInt() }
                    if (start == null) value(2)?.let { start = it and 0xFFFFFFFFL }
                    if (sessionPosition == null) {
                        val lat = value(3); val lon = value(4)
                        if (lat != null && lon != null) sessionPosition = lat.toInt() to lon.toInt()
                    }
                }
                12 -> {
                    value(0)?.let { sport = it.toInt() }
                    value(1)?.let { subSport = it.toInt() }
                }
                20 -> {
                    // A dive computer only has GPS at the surface: at the start and end of the dive.
                    if (firstPosition == null) {
                        val lat = value(0); val lon = value(1)
                        if (lat != null && lon != null) firstPosition = lat.toInt() to lon.toInt()
                    }
                    value(92)?.let { maxDepth = max(maxDepth, it) }
                }
            }
        }

        val isDive = sport == DIVING_SPORT || subSport in DIVING_SUB_SPORTS
        val position = sessionPosition ?: firstPosition
        if (!isDive || position == null) return null
        val degrees = 180.0 / (1L shl 31)
        return Dive(
            startMillis = start?.let { (it + FIT_EPOCH_SECONDS) * 1000 },
            latitude = position.first * degrees, longitude = position.second * degrees,
            maxDepth = if (maxDepth > 0) maxDepth / 1000.0 else null,
        )
    }

    private class Field(val number: Int, val size: Int, val baseType: Int)
    private class Definition(val global: Int, val bigEndian: Boolean, val fields: List<Field>, val developerSize: Int)

    /**
     * Calls [body] for every session, sport and record message with its global message number and a
     * lookup for its integer field values (null when the field is absent or holds FIT's "invalid" value).
     */
    private fun forEachMessage(b: ByteArray, body: (Int, (Int) -> Long?) -> Unit) {
        fun u8(i: Int) = b[i].toInt() and 0xFF
        var pos = 0
        // A file can hold several FIT segments one after the other (header, records, 2-byte CRC).
        while (pos + 12 <= b.size) {
            val headerSize = u8(pos)
            if (headerSize < 12 || String(b, pos + 8, 4, Charsets.US_ASCII) != ".FIT") {
                if (pos == 0) throw ParseException("not a FIT file")
                return
            }
            val dataSize = readUInt(b, pos + 4, 4, false).toInt()
            var p = pos + headerSize
            val end = minOf(p + dataSize, b.size)
            val definitions = HashMap<Int, Definition>()

            while (p < end) {
                val header = u8(p); p += 1
                val local: Int
                if (header and 0x80 != 0) {
                    local = (header shr 5) and 0x03            // compressed timestamp header: always data
                } else {
                    local = header and 0x0F
                    if (header and 0x40 != 0) {                // definition message
                        if (p + 5 > end) throw ParseException("truncated")
                        val bigEndian = u8(p + 1) == 1
                        val global = readUInt(b, p + 2, 2, bigEndian).toInt()
                        val count = u8(p + 4); p += 5
                        if (p + 3 * count > end) throw ParseException("truncated")
                        val fields = (0 until count).map { i -> Field(u8(p + 3 * i), u8(p + 3 * i + 1), u8(p + 3 * i + 2) and 0x1F) }
                        p += 3 * count
                        var developerSize = 0
                        if (header and 0x20 != 0) {            // developer fields: skipped, only their size counts
                            if (p >= end) throw ParseException("truncated")
                            val devCount = u8(p); p += 1
                            if (p + 3 * devCount > end) throw ParseException("truncated")
                            developerSize = (0 until devCount).sumOf { u8(p + 3 * it + 1) }
                            p += 3 * devCount
                        }
                        definitions[local] = Definition(global, bigEndian, fields, developerSize)
                        continue
                    }
                }

                val def = definitions[local] ?: throw ParseException("data before its definition")
                val start = p
                p += def.fields.sumOf { it.size } + def.developerSize
                if (p > end) throw ParseException("truncated")
                // Only these message types are needed; skip the rest without decoding.
                if (def.global != 12 && def.global != 18 && def.global != 20) continue
                body(def.global) { number ->
                    var offset = start
                    var result: Long? = null
                    for (field in def.fields) {
                        if (field.number == number) { result = value(b, offset, field, def.bigEndian); break }
                        offset += field.size
                    }
                    result
                }
            }
            pos = end + 2
        }
    }

    /** An integer field's value, or null for non-integer types and FIT's invalid values. */
    private fun value(b: ByteArray, offset: Int, field: Field, bigEndian: Boolean): Long? {
        // enum, sint8, uint8, sint16, uint16, sint32, uint32, uint8z, uint16z, uint32z
        val signed = when (field.baseType) {
            1, 3, 5 -> true
            0, 2, 4, 6, 10, 11, 12 -> false
            else -> return null
        }
        if (field.size != 1 && field.size != 2 && field.size != 4) return null   // arrays aren't needed
        val raw = readUInt(b, offset, field.size, bigEndian)
        val bits = field.size * 8
        if (field.baseType >= 10) return if (raw == 0L) null else raw          // "z" types: 0 = invalid
        if (signed) {
            if (raw == (1L shl (bits - 1)) - 1) return null
            val shift = 64 - bits
            return (raw shl shift) shr shift
        }
        return if (raw == (1L shl bits) - 1) null else raw
    }

    private fun readUInt(b: ByteArray, offset: Int, size: Int, bigEndian: Boolean): Long {
        var v = 0L
        for (i in 0 until size) {
            val byte = b[offset + if (bigEndian) i else size - 1 - i].toLong() and 0xFF
            v = (v shl 8) or byte
        }
        return v
    }
}
