import MapLibre
import SwiftUI

/// MapLibre map drawn entirely from the bundled MaltaMap.bundle (OpenStreetMap vector tiles, depth
/// contours and dive sites; see tools/style/make_style.mjs), so it works offline. Always north up,
/// no tilting.
struct MapView: UIViewRepresentable {
    let sites: [DiveSite]
    var showContours: Bool
    /// Set by the caller to fly to a site (e.g. picked from the list).
    var focus: DiveSite?
    var followUser: Bool
    var probe: CLLocationCoordinate2D?
    /// Bumped by the caller to fly back to Malta.
    var resetToken: Int
    var onSelectSite: (DiveSite) -> Void
    var onProbe: (CLLocationCoordinate2D) -> Void
    /// The view has been panned away from the bundled map (true) or is back (false).
    var onOutsideMalta: (Bool) -> Void
    /// Called when following stops on its own: the user panned, or their location is outside the map.
    var onStopFollowing: () -> Void
    /// The user's location is outside the bundled map, so the map doesn't go there.
    var onUserOutsideMap: () -> Void

    /// What the bundled map covers.
    static let bounds = MLNCoordinateBounds(sw: .init(latitude: 35.75, longitude: 14.10),
                                            ne: .init(latitude: 36.12, longitude: 14.65))
    static let malta = MLNCoordinateBounds(sw: .init(latitude: 35.78, longitude: 14.18),
                                           ne: .init(latitude: 36.09, longitude: 14.58))

    static func contains(_ c: CLLocationCoordinate2D) -> Bool {
        (bounds.sw.latitude...bounds.ne.latitude).contains(c.latitude)
            && (bounds.sw.longitude...bounds.ne.longitude).contains(c.longitude)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: Self.styleURL())
        map.delegate = context.coordinator
        map.allowsRotating = false
        map.allowsTilting = false
        map.compassView.isHidden = true
        map.logoView.isHidden = true
        map.attributionButton.isHidden = true   // credits are shown by ContentView
        map.minimumZoomLevel = 9
        map.maximumZoomLevel = 18
        map.showsUserLocation = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        // Leave double taps to the map's zoom gesture.
        for recognizer in map.gestureRecognizers ?? [] {
            if let double = recognizer as? UITapGestureRecognizer, double.numberOfTapsRequired == 2 {
                tap.require(toFail: double)
            }
        }
        map.addGestureRecognizer(tap)

        let press = UILongPressGestureRecognizer(target: context.coordinator,
                                                 action: #selector(Coordinator.longPress(_:)))
        press.minimumPressDuration = 0.4
        map.addGestureRecognizer(press)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        let c = context.coordinator
        c.parent = self
        c.applyContours(map)

        if let focus, focus.id != c.lastFocusID {
            c.lastFocusID = focus.id
            map.setCenter(focus.coordinate, zoomLevel: 15, animated: true)
        } else if focus == nil {
            c.lastFocusID = nil
        }

        if resetToken != c.resetToken {
            c.resetToken = resetToken
            map.userTrackingMode = .none
            map.setVisibleCoordinateBounds(Self.malta, edgePadding: UIEdgeInsets(top: 40, left: 10, bottom: 60, right: 10),
                                           animated: true, completionHandler: nil)
        }

        if followUser != c.following {
            c.following = followUser
            if followUser {
                if c.locationManager.authorizationStatus == .notDetermined {
                    c.locationManager.requestWhenInUseAuthorization()
                }
                c.startFollowing(map)
            } else {
                c.waitingForLocation = false
                map.setUserTrackingMode(.none, animated: false, completionHandler: nil)
            }
        }

        c.showProbe(probe, on: map)
    }

    /// The bundled style with "{ASSETS}" pointing at MaltaMap.bundle, written to Caches.
    private static func styleURL() -> URL? {
        guard let assets = Bundle.main.url(forResource: "MaltaMap", withExtension: "bundle"),
              let template = try? String(contentsOf: assets.appendingPathComponent("style.json"), encoding: .utf8)
        else { return nil }
        let base = assets.absoluteString.hasSuffix("/") ? String(assets.absoluteString.dropLast()) : assets.absoluteString
        let style = template.replacingOccurrences(of: "{ASSETS}", with: base)
        let url = URL.cachesDirectory.appendingPathComponent("malta-style.json")
        try? style.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @MainActor
    final class Coordinator: NSObject, @MainActor MLNMapViewDelegate {
        var parent: MapView
        let locationManager = CLLocationManager()
        var lastFocusID: String?
        var following = false
        var resetToken = 0
        private var contoursShown: Bool?
        private var outside = false
        /// Following was asked for before the first location fix came in.
        var waitingForLocation = false

        /// Only follow the user when they are inside the bundled map; otherwise tell the UI and stay put.
        func startFollowing(_ map: MLNMapView) {
            guard let user = map.userLocation?.location?.coordinate else {
                waitingForLocation = true
                return
            }
            waitingForLocation = false
            if MapView.contains(user) {
                map.setUserTrackingMode(.follow, animated: true, completionHandler: nil)
            } else {
                stopFollowingOutside(map)
            }
        }

        private func stopFollowingOutside(_ map: MLNMapView) {
            following = false
            map.setUserTrackingMode(.none, animated: false, completionHandler: nil)
            // This can run inside updateUIView, where SwiftUI drops state changes; tell the UI right after.
            let parent = parent
            Task { @MainActor in
                parent.onStopFollowing()
                parent.onUserOutsideMap()
            }
        }
        private var placed = false
        private let probePin = MLNPointAnnotation()

        init(_ parent: MapView) {
            self.parent = parent
            probePin.title = "Depth"
        }

        func applyContours(_ map: MLNMapView) {
            guard let style = map.style, contoursShown != parent.showContours else { return }
            contoursShown = parent.showContours
            for id in ["contours", "contour-labels"] {
                style.layer(withIdentifier: id)?.isVisible = parent.showContours
            }
        }

        func showProbe(_ coordinate: CLLocationCoordinate2D?, on map: MLNMapView) {
            let shown = map.annotations?.contains { $0 === probePin } ?? false
            if let coordinate {
                probePin.coordinate = coordinate
                if !shown { map.addAnnotation(probePin) }
            } else if shown {
                map.removeAnnotation(probePin)
            }
        }

        // MARK: Gestures

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: map)
            let rect = CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44)
            let features = map.visibleFeatures(in: rect, styleLayerIdentifiers: ["sites", "site-clusters"])
            guard let feature = features.first else { return }
            if feature.attribute(forKey: "point_count") != nil {
                map.setCenter(feature.coordinate, zoomLevel: min(map.zoomLevel + 2, 16), animated: true)
            } else if let id = feature.attribute(forKey: "id") as? String,
                      let site = parent.sites.first(where: { $0.id == id }) {
                parent.onSelectSite(site)
            }
        }

        @objc func longPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let map = gesture.view as? MLNMapView else { return }
            parent.onProbe(map.convert(gesture.location(in: map), toCoordinateFrom: map))
        }

        // MARK: MLNMapViewDelegate

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            contoursShown = nil
            applyContours(mapView)
            // Fit Malta once the view has its real size.
            if !placed {
                placed = true
                mapView.setVisibleCoordinateBounds(MapView.malta, edgePadding: UIEdgeInsets(top: 40, left: 10, bottom: 60, right: 10),
                                                   animated: false, completionHandler: nil)
            }
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            updateOutside(mapView)
        }

        func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
            guard following, let user = userLocation?.location?.coordinate else { return }
            if waitingForLocation {
                startFollowing(mapView)
            } else if !MapView.contains(user) {
                // Left the map while following.
                stopFollowingOutside(mapView)
            }
        }

        func mapView(_ mapView: MLNMapView, didChange mode: MLNUserTrackingMode, animated: Bool) {
            if mode == .none, following {
                following = false
                parent.onStopFollowing()
            }
        }

        /// Tell the UI when the view has been panned off the area the bundled map covers.
        private func updateOutside(_ map: MLNMapView) {
            let now = !MapView.contains(map.centerCoordinate)
            if now != outside {
                outside = now
                parent.onOutsideMalta(now)
            }
        }
    }
}
