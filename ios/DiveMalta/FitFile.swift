import Foundation

/// Reads just enough of a Garmin FIT activity file to tell whether it is a dive, and where, when
/// and how deep. FIT is a binary format of definition messages (the layout of a message type) and
/// data messages (values in that layout); see the FIT protocol in Garmin's FIT SDK.
///
/// Used messages and fields:
/// - session (18): start_time (2), start_position_lat/long (3, 4), sport (5), sub_sport (6)
/// - sport (12): sport (0), sub_sport (1)
/// - record (20): position_lat/long (0, 1), depth (92, mm)
enum FitFile {
    struct Dive: Codable, Hashable {
        var start: Date?
        var latitude: Double
        var longitude: Double
        var maxDepth: Double?   // metres
    }

    enum ParseError: Error { case notFit, truncated, undefinedMessage }

    /// sport "diving"; sub sports single gas, multi gas, gauge, apnea, apnea hunting and CCR diving.
    private static let divingSport = 53
    private static let divingSubSports: Set<Int> = [53, 54, 55, 56, 57, 63]
    /// FIT times count seconds from 31 December 1989 00:00 UTC.
    private static let fitEpoch = Date(timeIntervalSince1970: 631_065_600)

    /// The dive in this file, or nil when it isn't a dive or has no position.
    static func dive(in data: Data) throws -> Dive? {
        var sport: Int?, subSport: Int?, start: UInt32?
        var sessionPosition: (Int32, Int32)?, firstPosition: (Int32, Int32)?
        var maxDepth: UInt32 = 0

        try forEachMessage(in: data) { global, value in
            switch global {
            case 18:
                if let v = value(5) { sport = Int(v) }
                if let v = value(6) { subSport = Int(v) }
                if start == nil, let v = value(2) { start = UInt32(truncatingIfNeeded: v) }
                if sessionPosition == nil, let lat = value(3), let lon = value(4) {
                    sessionPosition = (Int32(truncatingIfNeeded: lat), Int32(truncatingIfNeeded: lon))
                }
            case 12:
                if let v = value(0) { sport = Int(v) }
                if let v = value(1) { subSport = Int(v) }
            case 20:
                // A dive computer only has GPS at the surface: at the start and end of the dive.
                if firstPosition == nil, let lat = value(0), let lon = value(1) {
                    firstPosition = (Int32(truncatingIfNeeded: lat), Int32(truncatingIfNeeded: lon))
                }
                if let v = value(92) { maxDepth = max(maxDepth, UInt32(truncatingIfNeeded: v)) }
            default:
                break
            }
        }

        guard sport == divingSport || subSport.map(divingSubSports.contains) == true,
              let (lat, lon) = sessionPosition ?? firstPosition
        else { return nil }
        let degrees = 180 / pow(2, 31) as Double
        return Dive(start: start.map { fitEpoch.addingTimeInterval(TimeInterval($0)) },
                    latitude: Double(lat) * degrees, longitude: Double(lon) * degrees,
                    maxDepth: maxDepth > 0 ? Double(maxDepth) / 1000 : nil)
    }

    private struct Field { let number: UInt8; let size: Int; let baseType: UInt8 }
    private struct Definition { let global: UInt16; let bigEndian: Bool; let fields: [Field]; let developerSize: Int }

    /// Calls `body` for every data message with its global message number and a lookup for its
    /// integer field values (nil when the field is absent or holds FIT's "invalid" value).
    private static func forEachMessage(in data: Data, _ body: (UInt16, (UInt8) -> Int64?) -> Void) throws {
        let bytes = [UInt8](data)
        var pos = 0
        // A file can hold several FIT segments one after the other (header, records, 2-byte CRC).
        while pos + 12 <= bytes.count {
            let headerSize = Int(bytes[pos])
            guard headerSize >= 12, bytes[pos + 8 ..< pos + 12].elementsEqual(Array(".FIT".utf8)) else {
                if pos == 0 { throw ParseError.notFit }
                return
            }
            let dataSize = Int(readUInt(bytes, pos + 4, 4, bigEndian: false))
            var p = pos + headerSize
            let end = min(p + dataSize, bytes.count)
            var definitions: [UInt8: Definition] = [:]

            while p < end {
                let header = bytes[p]; p += 1
                let local: UInt8
                if header & 0x80 != 0 {
                    local = (header >> 5) & 0x03            // compressed timestamp header: always data
                } else {
                    local = header & 0x0F
                    if header & 0x40 != 0 {                 // definition message
                        guard p + 5 <= end else { throw ParseError.truncated }
                        let bigEndian = bytes[p + 1] == 1
                        let global = UInt16(readUInt(bytes, p + 2, 2, bigEndian: bigEndian))
                        let count = Int(bytes[p + 4]); p += 5
                        guard p + 3 * count <= end else { throw ParseError.truncated }
                        let fields = (0 ..< count).map { i in
                            Field(number: bytes[p + 3 * i], size: Int(bytes[p + 3 * i + 1]),
                                  baseType: bytes[p + 3 * i + 2] & 0x1F)
                        }
                        p += 3 * count
                        var developerSize = 0
                        if header & 0x20 != 0 {             // developer fields: skipped, only their size counts
                            guard p < end else { throw ParseError.truncated }
                            let devCount = Int(bytes[p]); p += 1
                            guard p + 3 * devCount <= end else { throw ParseError.truncated }
                            developerSize = (0 ..< devCount).reduce(0) { $0 + Int(bytes[p + 3 * $1 + 1]) }
                            p += 3 * devCount
                        }
                        definitions[local] = Definition(global: global, bigEndian: bigEndian, fields: fields,
                                                        developerSize: developerSize)
                        continue
                    }
                }

                guard let def = definitions[local] else { throw ParseError.undefinedMessage }
                let start = p
                p += def.fields.reduce(0) { $0 + $1.size } + def.developerSize
                guard p <= end else { throw ParseError.truncated }
                // Only these message types are needed; skip the rest without decoding.
                guard [12, 18, 20].contains(def.global) else { continue }
                body(def.global) { number in
                    var offset = start
                    for field in def.fields {
                        if field.number == number {
                            return value(bytes, offset, field, bigEndian: def.bigEndian)
                        }
                        offset += field.size
                    }
                    return nil
                }
            }
            pos = end + 2
        }
    }

    /// An integer field's value, or nil for non-integer types and FIT's invalid values.
    private static func value(_ bytes: [UInt8], _ offset: Int, _ field: Field, bigEndian: Bool) -> Int64? {
        // enum, sint8, uint8, sint16, uint16, sint32, uint32, uint8z, uint16z, uint32z
        let signed: Bool
        switch field.baseType {
        case 1, 3, 5: signed = true
        case 0, 2, 4, 6, 10, 11, 12: signed = false
        default: return nil
        }
        guard [1, 2, 4].contains(field.size) else { return nil }   // arrays aren't needed
        let raw = readUInt(bytes, offset, field.size, bigEndian: bigEndian)
        let bits = UInt64(field.size * 8)
        if [10, 11, 12].contains(field.baseType) { return raw == 0 ? nil : Int64(raw) }   // "z" types: 0 = invalid
        if signed {
            if raw == (1 << (bits - 1)) - 1 { return nil }
            let shift = 64 - bits
            return Int64(bitPattern: raw << shift) >> Int64(shift)
        }
        return raw == (1 << bits) - 1 ? nil : Int64(raw)
    }

    private static func readUInt(_ bytes: [UInt8], _ offset: Int, _ size: Int, bigEndian: Bool) -> UInt64 {
        var v: UInt64 = 0
        for i in 0 ..< size {
            let b = UInt64(bytes[offset + (bigEndian ? i : size - 1 - i)])
            v = v << 8 | b
        }
        return v
    }
}
