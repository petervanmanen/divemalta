import CoreLocation
import SwiftUI

struct ContentView: View {
    @State private var sites = DiveSite.loadBundled()
    @AppStorage("showContours") private var showContours = true
    @State private var selected: DiveSite?
    @State private var focus: DiveSite?
    @State private var showList = false
    @State private var showAbout = false
    @State private var followUser = false
    @State private var probe: Probe?
    @State private var outside = false
    @State private var toast: String?
    @State private var resetToken = 0

    var body: some View {
        MapView(
            sites: sites,
            showContours: showContours,
            focus: focus,
            followUser: followUser,
            probe: probe?.coordinate,
            resetToken: resetToken,
            onSelectSite: { selected = $0 },
            onProbe: { lookUpDepth(at: $0) },
            onOutsideMalta: { outside = $0 },
            onStopFollowing: { followUser = false },
            onUserOutsideMap: { showToast("You're outside Malta. This app only has the map of Malta, Gozo and Comino.") }
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) { controls }
        .overlay(alignment: .bottom) { bottomBar }
        .overlay(alignment: .top) {
            if outside {
                OutsideBanner {
                    followUser = false
                    resetToken += 1
                }
                .padding(.horizontal, 72)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: outside)
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(in: .capsule)
                    .padding(.horizontal, 72)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { self.toast = nil }
            }
        }
        .animation(.default, value: toast)
        .sheet(item: $selected) { site in
            SiteDetailView(site: site)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .task { await setUpScreenshot() }
        .sheet(isPresented: $showList) {
            SiteListView(sites: sites) { site in
                showList = false
                followUser = false
                focus = site
                selected = site
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                showContours.toggle()
            } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .symbolVariant(showContours ? .none : .slash)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(showContours ? "Hide depth contours" : "Show depth contours")

            Button {
                showList = true
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dive sites")

            Button {
                followUser.toggle()
            } label: {
                Image(systemName: followUser ? "location.fill" : "location")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Show my location")

            Button {
                showAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("About and credits")
        }
        .font(.title3)
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .glassEffect(in: .rect(cornerRadius: 22))
        .padding(.trailing, 12)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let probe {
                ProbeCard(probe: probe) { self.probe = nil }
                    .padding(.horizontal, 12)
            } else {
                Text("Touch and hold the sea to see its depth")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect()
            }
            Text("© OpenStreetMap contributors · Protomaps · Bathymetry © EMODnet")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .background(.thinMaterial, in: .capsule)
        }
        .padding(.bottom, 4)
    }

    /// Puts the app in a fixed state for App Store screenshots (only with `-screenshot <scene>`).
    private func setUpScreenshot() async {
        guard let scene = ScreenshotScene.current else { return }
        showContours = true
        try? await Task.sleep(for: .seconds(1))   // let the map load first
        switch scene {
        case .site: selected = sites.first { $0.id == ScreenshotScene.siteID }
        case .list: showList = true
        case .depth: lookUpDepth(at: ScreenshotScene.probe)
        case .splash, .map, .contours: break
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if toast == text { toast = nil }
        }
    }

    private func lookUpDepth(at coordinate: CLLocationCoordinate2D) {
        let current = Probe(coordinate: coordinate)
        probe = current
        Task {
            let result: Probe.State
            do {
                result = try await DepthService.lookup(coordinate).map(Probe.State.value) ?? .noData
            } catch {
                result = .failed
            }
            // Ignore answers for a probe that was replaced or closed in the meantime.
            if probe?.id == current.id { probe?.state = result }
        }
    }
}

struct Probe: Identifiable {
    enum State { case loading, value(DepthService.Result), noData, failed }
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    var state: State = .loading
}

private struct ProbeCard: View {
    let probe: Probe
    let close: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.to.line")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                switch probe.state {
                case .loading: Text("Looking up depth…")
                case .value(let result): Text(result.text).font(.headline)
                case .noData: Text("No depth data here")
                case .failed: Text("Couldn't reach EMODnet")
                }
                Text(String(format: "%.5f, %.5f · EMODnet, OSM coastline and our own depths",
                            probe.coordinate.latitude, probe.coordinate.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close")
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

/// Shown when the view has been panned off the bundled map.
private struct OutsideBanner: View {
    let backToMalta: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Label("Outside the map", systemImage: "map")
                .font(.headline)
            Text("This app only contains the map of Malta, Gozo and Comino.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Back to Malta", action: backToMalta)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
