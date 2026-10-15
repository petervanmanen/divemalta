import CoreLocation
import Foundation

/// A dive site, from one file in shared/sites/. The build gathers all of them into
/// data/malta-dive-sites.json (shared/tools/gather_sites.py).
struct DiveSite: Identifiable, Decodable, Hashable {
    let id: String              // OpenStreetMap id ("node/123"), or our own ("custom/…")
    let name: String
    let lat: Double
    let lon: Double
    let type: String?           // wreck, cave, reef, statue, ...
    let maxDepth: String?       // "36m", "30m+"
    let typicalDepth: String?
    let level: String?          // "Advanced (Advanced Open Water)"
    let entry: String?          // shore, boat
    let shoreAccess: String?    // Easy, Medium, Hard
    let difficulty: String?
    let details: String?
    let conditions: String?
    private let websiteString: String?
    private let sourceStrings: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, name, lat, lon, type, maxDepth, typicalDepth, level, entry, shoreAccess, difficulty, conditions
        case details = "description"
        case websiteString = "website"
        case sourceStrings = "sources"
    }

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    var displayName: String { name }

    /// "36m · wreck · shore entry · Advanced"
    var summary: String? {
        let levelWord = level?.split(separator: " ").first.map(String.init)
        let parts = [maxDepth, type, entry.map { "\($0) entry" }, levelWord].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// OpenStreetMap page, for sites that come from OSM.
    var osmURL: URL? {
        id.hasPrefix("node/") || id.hasPrefix("way/") || id.hasPrefix("relation/")
            ? URL(string: "https://www.openstreetmap.org/\(id)") : nil
    }

    var website: URL? { websiteString.flatMap(URL.init(string:)) }
    var sources: [URL] { (sourceStrings ?? []).compactMap(URL.init(string:)) }

    static func loadBundled() -> [DiveSite] {
        guard let url = Bundle.main.url(forResource: "malta-dive-sites", withExtension: "json", subdirectory: "data"),
              let data = try? Data(contentsOf: url),
              let sites = try? JSONDecoder().decode([DiveSite].self, from: data)
        else { return [] }
        return sites
    }
}
