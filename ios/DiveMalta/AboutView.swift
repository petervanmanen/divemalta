import SwiftUI

/// Credits for the data and photo, and the open-source licences (Licenses.txt).
struct AboutView: View {
    private let licences: String = Bundle.main.url(forResource: "Licenses", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Dive sites of Malta, Gozo and Comino with depth contours, on a map that works offline.")
                    LabeledContent("Version", value: version)
                }

                Section {
                    Text("Depths, levels and conditions are a guide only. Always check with a local dive centre and dive within your training.")
                        .font(.callout)
                }

                Section("Data") {
                    credit("Map data © OpenStreetMap contributors, ODbL",
                           "https://www.openstreetmap.org/copyright")
                    credit("Map tiles: Protomaps", "https://protomaps.com")
                    credit("Bathymetry © EMODnet Bathymetry Consortium, CC BY 4.0",
                           "https://emodnet.ec.europa.eu/en/bathymetry")
                    credit("Dive site details researched from maltadives.com, Calypso Sub-Aqua Club and others; see each site",
                           nil)
                }

                Section("Open-source licences") {
                    Text(licences)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("About Dive Malta")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func credit(_ text: String, _ link: String?) -> some View {
        if let link, let url = URL(string: link) {
            Link(destination: url) { Text(text).foregroundStyle(.tint) }
        } else {
            Text(text)
        }
    }
}
