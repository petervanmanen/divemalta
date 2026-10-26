import CoreLocation
import SwiftUI

struct ContentView: View {
    @State private var sites: [DiveSite]
    @State private var diveLog: DiveLog
    @Environment(\.scenePhase) private var scenePhase
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

    init() {
        let sites = DiveSite.loadBundled()
        _sites = State(initialValue: sites)
        _diveLog = State(initialValue: DiveLog(sites: sites))
    }

    var body: some View {
        MapView(
            sites: sites,
            showContours: showContours,
            visited: Set(diveLog.visits.keys),
            focus: focus,
            followUser: followUser,
            probe: probe?.coordinate,
            resetToken: resetToken,
            onSelectSite: { selected = $0 },
            onProbe: { lookUpDepth(at: $0) },
            onTapMap: { probe = nil },
            onOutsideMalta: { outside = $0 },
            onStopFollowing: { followUser = false },
            onUserOutsideMap: { showToast("You're outside Malta. This app only has the map of Malta, Gozo and Comino.") }
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) { controls }
        .overlay { BesideFold(alignment: .topLeading) {
            SearchBar(sites: sites) { pick($0) }
                .padding(.leading, 20)
                .padding(.trailing, 80)   // clear of the buttons
                .padding(.top, 8)
        } }
        .overlay { BesideFold(alignment: .bottom) { bottomBar } }
        .overlay { BesideFold(alignment: .top) {
            if outside {
                OutsideBanner {
                    followUser = false
                    resetToken += 1
                }
                .padding(.horizontal, 72)
                .padding(.top, 64)   // below the search bar
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        } }
        .animation(.default, value: outside)
        .overlay { BesideFold(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(in: .capsule)
                    .padding(.horizontal, 72)
                    .padding(.top, 64)   // below the search bar
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { self.toast = nil }
            }
        } }
        .animation(.default, value: toast)
        .sheet(item: $selected) { site in
            SiteDetailView(site: site)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .task { await setUpScreenshot() }
        // Your dive log: read at start and again when you come back to the app, for newly exported dives.
        .task { await diveLog.scan() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await diveLog.scan() } }
        }
        // Load the 3.4 MB depth grid in the background now, instead of on the main thread the first
        // time a site page or depth lookup needs it.
        .task(priority: .utility) { await Task.detached(priority: .utility) { _ = BathymetryGrid.malta }.value }
        .sheet(isPresented: $showList) {
            SiteListView(sites: sites) { site in
                showList = false
                pick(site)
            }
        }
        .environment(diveLog)   // for the site page, list and settings
    }

    private var controls: some View {
        // No spacing: each button's tap area runs up to the next one (4 × 53 = the old 44 pt buttons
        // with 12 pt gaps).
        VStack(spacing: 0) {
            Button {
                showContours.toggle()
            } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .symbolVariant(showContours ? .none : .slash)
                    .frame(width: 48, height: 53)
                    .contentShape(.rect)   // the whole button, not just the thin icon lines
            }
            .accessibilityLabel(showContours ? "Hide depth contours" : "Show depth contours")

            Button {
                showList = true
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 48, height: 53)
                    .contentShape(.rect)   // the whole button, not just the thin icon lines
            }
            .accessibilityLabel("Dive sites")

            Button {
                followUser.toggle()
            } label: {
                Image(systemName: followUser ? "location.fill" : "location")
                    .frame(width: 48, height: 53)
                    .contentShape(.rect)   // the whole button, not just the thin icon lines
            }
            .accessibilityLabel("Show my location")

            Button {
                showAbout = true
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 48, height: 53)
                    .contentShape(.rect)   // the whole button, not just the thin icon lines
            }
            .accessibilityLabel("Settings and about")
        }
        .font(.title3)
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .glassEffect(in: .rect(cornerRadius: 22))
        .padding(.trailing, 20)
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
        case .settings: showAbout = true
        case .splash, .map, .contours: break
        }
    }

    /// Shows a site chosen from the search bar or the list: the map goes there and its page opens.
    private func pick(_ site: DiveSite) {
        followUser = false
        focus = site
        selected = site
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

/// Search field on the map, with the best matching sites below it while you type.
private struct SearchBar: View {
    let sites: [DiveSite]
    let onPick: (DiveSite) -> Void
    @Environment(DiveLog.self) private var diveLog
    @State private var text = ""
    @FocusState private var focused: Bool

    private var suggestions: [DiveSite] {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? [] : Array(SiteSearch.results(text, in: sites).prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search dive sites", text: $text)
                    .focused($focused)
                    .autocorrectionDisabled()   // site names aren't dictionary words
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { if let first = suggestions.first { pick(first) } }
                if !text.isEmpty || focused {
                    Button {
                        text = ""
                        focused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 48)
            .glassEffect(in: .capsule)

            if focused && !text.isEmpty {
                suggestionList
            }
        }
        .animation(.default, value: suggestions.map(\.id))
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if suggestions.isEmpty {
                Text("No dive sites match \"\(text)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(14)
            }
            ForEach(suggestions) { site in
                Button { pick(site) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.displayName).foregroundStyle(.primary)
                            if let summary = site.summary {
                                Text(summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if diveLog.visits[site.id] != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel("Dived")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if site.id != suggestions.last?.id { Divider().padding(.leading, 14) }
            }
        }
        .glassEffect(in: .rect(cornerRadius: 20))
        .transition(.opacity)
    }

    private func pick(_ site: DiveSite) {
        text = ""
        focused = false
        onPick(site)
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
