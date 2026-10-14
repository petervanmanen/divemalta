import CoreLocation
import Foundation

/// A dive site from OpenStreetMap, as written by shared/tools/make_data.py.
struct DiveSite: Identifiable, Decodable, Hashable {
    let id: String          // "node/123", "way/456"
    let name: String?
    let lat: Double
    let lon: Double
    let maxDepth: String?   // "30m", "5-30m"
    let type: String?       // wreck, wall, cave, reef, ...
    let entry: String?      // shore, boat
    let tags: [String: String]

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    var displayName: String { name ?? "Dive site" }

    /// "36m · wreck · shore entry · Advanced"
    var summary: String? {
        let levelWord = level?.split(separator: " ").first.map(String.init)
        let parts = [maxDepth, type, entry.map { "\($0) entry" }, levelWord].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var osmURL: URL { URL(string: "https://www.openstreetmap.org/\(id)")! }

    var website: URL? {
        (tags["website"] ?? tags["contact:website"] ?? tags["url"]).flatMap(URL.init(string:))
    }

    var difficulty: String? { tags["scuba_diving:difficulty"] }
    var details: String? { tags["description"] ?? tags["note"] }

    // Our own research (shared/enrichment/sites.json), stored as dive:* tags.
    var level: String? { tags["dive:level"] }
    var typicalDepth: String? { tags["dive:depth_avg"] }
    var shoreAccess: String? { tags["dive:shore_access"] }
    var conditions: String? { tags["dive:conditions"] }
    var sources: [URL] {
        (tags["dive:sources"] ?? "").split(separator: " ").compactMap { URL(string: String($0)) }
    }

    static func loadBundled() -> [DiveSite] {
        guard let url = Bundle.main.url(forResource: "malta-dive-sites", withExtension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let sites = try? JSONDecoder().decode([DiveSite].self, from: data)
        else { return [] }
        return sites
    }
}
