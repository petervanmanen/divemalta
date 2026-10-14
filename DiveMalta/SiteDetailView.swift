import MapKit
import SwiftUI

struct SiteDetailView: View {
    let site: DiveSite
    @State private var seabed: String?

    private var entryText: String? {
        guard let entry = site.entry else { return nil }
        if entry == "shore", let access = site.shoreAccess { return "Shore (\(access.lowercased()))" }
        return entry.capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let maxDepth = site.maxDepth { row("Max depth", maxDepth, "arrow.down") }
                    if let typical = site.typicalDepth { row("Typical depth", typical, "arrow.down.to.line") }
                    if let level = site.level { row("Level", level, "person.badge.shield.checkmark") }
                    if let type = site.type { row("Type", type.capitalized, "tag") }
                    if let entry = entryText { row("Entry", entry, "figure.walk") }
                    if let difficulty = site.difficulty { row("Difficulty", difficulty, "gauge.medium") }
                    row("Seabed depth here", seabed ?? "…", "water.waves")
                }

                if let details = site.details {
                    Section("Description") { Text(details) }
                }
                if let conditions = site.conditions {
                    Section("Conditions") { Text(conditions) }
                }

                Section {
                    Button("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond") {
                        let item = MKMapItem(location: CLLocation(latitude: site.lat, longitude: site.lon), address: nil)
                        item.name = site.displayName
                        item.openInMaps()
                    }
                    if let website = site.website {
                        Link(destination: website) { Label("Website", systemImage: "safari") }
                    }
                    Link(destination: site.osmURL) { Label("View or edit on OpenStreetMap", systemImage: "map") }
                }

                if !site.sources.isEmpty {
                    Section {
                        ForEach(site.sources, id: \.self) { url in
                            Link(destination: url) {
                                Label(url.host() ?? url.absoluteString, systemImage: "link")
                            }
                        }
                    } header: {
                        Text("Sources")
                    } footer: {
                        Text("Check depths and conditions with a local dive centre before you dive.")
                    }
                }

                Section {
                    Text(String(format: "%.5f, %.5f", site.lat, site.lon))
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle(site.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: site.id) {
            seabed = await seabedText()
        }
    }

    private func seabedText() async -> String {
        do {
            switch try await DepthService.lookup(site.coordinate) {
            case .depth(let d): return DepthService.Result.depth(d).text
            // Shore sites (cave entrances, entry points) are often mapped on the coastline itself.
            case .land: return "On the shore"
            case .noData: return "No data this close to shore"
            case nil: return "No data"
            }
        } catch {
            return "Couldn't reach EMODnet"
        }
    }

    private func row(_ title: String, _ value: String, _ icon: String) -> some View {
        LabeledContent {
            Text(value)
        } label: {
            Label(title, systemImage: icon)
        }
    }
}
