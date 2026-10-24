import CoreLocation

/// Fixed app states for App Store screenshots, chosen with a launch argument:
/// `-screenshot splash|map|contours|site|list|depth|settings` (see tools/screenshots.sh; settings is
/// only for checking the settings screen).
/// Without the argument the app behaves normally.
enum ScreenshotScene: String {
    case splash, map, contours, site, list, depth, settings

    static let current: ScreenshotScene? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshot"), i + 1 < args.count else { return nil }
        return ScreenshotScene(rawValue: args[i + 1])
    }()

    /// Where the map starts; nil = all of Malta.
    var camera: (center: CLLocationCoordinate2D, zoom: Double)? {
        switch self {
        case .contours, .depth: return (.init(latitude: 36.0100, longitude: 14.3330), 12.8)  // Comino and Ċirkewwa
        case .site: return (.init(latitude: 35.8128, longitude: 14.4496), 14.6)             // Um El Faroud above the sheet
        default: return nil
        }
    }

    static let siteID = "node/663869707"   // Um El Faroud
    static let probe = CLLocationCoordinate2D(latitude: 36.0080, longitude: 14.3150)  // south-west of Cominotto
}
