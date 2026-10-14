import CoreLocation
import Foundation

/// Depth at a point: from the bundled grid around Malta (offline, matches the contours),
/// otherwise from the EMODnet Bathymetry REST service.
enum DepthService {
    enum Result: Equatable {
        case depth(Double)        // metres below sea level, positive
        case land
        case noData               // sea, but EMODnet has land here so there is no depth
    }

    private struct Sample: Decodable { let avg: Double? }

    static func lookup(_ coordinate: CLLocationCoordinate2D) async throws -> Result? {
        if let grid = BathymetryGrid.malta, let sample = grid.sample(coordinate) {
            switch sample {
            case .depth(let d): return .depth(d)
            case .land: return .land
            case .noData: return .noData
            }
        }
        var components = URLComponents(string: "https://rest.emodnet-bathymetry.eu/depth_sample")!
        components.queryItems = [
            URLQueryItem(name: "geom", value: "POINT(\(coordinate.longitude) \(coordinate.latitude))"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        guard let value = try JSONDecoder().decode(Sample.self, from: data).avg else { return nil }
        // EMODnet uses elevation: negative is below sea level.
        return value < 0 ? .depth(-value) : .land
    }
}

extension DepthService.Result {
    var text: String {
        switch self {
        case .depth(let d) where d < 1: return "Less than 1 m deep"
        case .depth(let d): return d < 10 ? String(format: "%.1f m deep", d) : "\(Int(d.rounded())) m deep"
        case .land: return "On land"
        case .noData: return "No depth data this close to shore"
        }
    }
}
