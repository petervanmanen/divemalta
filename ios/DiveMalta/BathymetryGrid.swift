import CoreLocation
import Foundation

/// The bundled depth grid written by shared/tools/make_data.py: EMODnet Bathymetry resampled to ~38 m, with
/// land and sea from the OpenStreetMap coastline.
final class BathymetryGrid: Sendable {
    enum Sample: Equatable {
        case depth(Double)  // metres, positive
        case land
        case noData         // sea, but EMODnet has land here so there is no depth
    }

    private struct Header: Decodable {
        let cols: Int, rows: Int
        let lon0: Double, lat0: Double, step: Double
        let land: Int16, noData: Int16
    }

    let cols: Int, rows: Int
    let lon0: Double, lat0: Double, step: Double   // centre of the north-west cell
    private let land: Int16, noData: Int16
    private let values: [Int16]                      // decimetres below sea level, negative; rows north to south

    static let malta = BathymetryGrid(resource: "malta-depth")

    init?(resource: String) {
        guard let headerURL = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: "data"),
              let dataURL = Bundle.main.url(forResource: resource, withExtension: "bin", subdirectory: "data"),
              let headerData = try? Data(contentsOf: headerURL),
              let header = try? JSONDecoder().decode(Header.self, from: headerData),
              let data = try? Data(contentsOf: dataURL),
              data.count == header.cols * header.rows * 2
        else { return nil }
        cols = header.cols; rows = header.rows
        lon0 = header.lon0; lat0 = header.lat0; step = header.step
        land = header.land; noData = header.noData
        values = data.withUnsafeBytes { raw in
            raw.bindMemory(to: Int16.self).map { Int16(littleEndian: $0) }
        }
    }

    /// Bounds of the grid, from the outer edges of the edge cells.
    var region: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        (lat0 - (Double(rows) - 0.5) * step, lat0 + step / 2,
         lon0 - step / 2, lon0 + (Double(cols) - 0.5) * step)
    }

    func contains(_ c: CLLocationCoordinate2D) -> Bool {
        let r = region
        return (r.minLat...r.maxLat).contains(c.latitude) && (r.minLon...r.maxLon).contains(c.longitude)
    }

    /// Land and no-data come from the nearest cell; depths are interpolated between the four
    /// surrounding cells when they are all sea.
    func sample(_ c: CLLocationCoordinate2D) -> Sample? {
        guard contains(c) else { return nil }
        let x = (c.longitude - lon0) / step, y = (lat0 - c.latitude) / step
        let nearest = value(Int(y.rounded()), Int(x.rounded()))
        if nearest == land { return .land }
        if nearest == noData { return .noData }

        let c0 = Int(x.rounded(.down)), r0 = Int(y.rounded(.down))
        let corners = [value(r0, c0), value(r0, c0 + 1), value(r0 + 1, c0), value(r0 + 1, c0 + 1)]
        guard corners.allSatisfy({ $0 != land && $0 != noData }) else { return .depth(-Double(nearest) / 10) }
        let fx = x - Double(c0), fy = y - Double(r0)
        let top = Double(corners[0]) * (1 - fx) + Double(corners[1]) * fx
        let bottom = Double(corners[2]) * (1 - fx) + Double(corners[3]) * fx
        return .depth(-(top * (1 - fy) + bottom * fy) / 10)
    }

    private func value(_ r: Int, _ c: Int) -> Int16 {
        values[min(max(r, 0), rows - 1) * cols + min(max(c, 0), cols - 1)]
    }
}
