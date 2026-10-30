import SwiftUI

/// Settings (your dive log folder), credits for the data and photo, and the open-source licences (Licenses.txt).
struct AboutView: View {
    @Environment(DiveLog.self) private var diveLog
    @State private var choosingFolder = false
    private let licences: String = Bundle.main.url(forResource: "Licenses", withExtension: "txt", subdirectory: "data")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    var body: some View {
        NavigationStack {
            List {
                diveLogSection

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
            .navigationTitle("Dive Malta")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    Task { await diveLog.choose(folder: url) }
                }
            }
        }
    }

    private var diveLogSection: some View {
        Section {
            if let folder = diveLog.folderName {
                LabeledContent {
                    if diveLog.isScanning { ProgressView() } else { Text(folder) }
                } label: {
                    Label("Folder", systemImage: "folder")
                }
                if !diveLog.isScanning {
                    LabeledContent("FIT files", value: "\(diveLog.fitFileCount)")
                    LabeledContent("Dives", value: "\(diveLog.dives.count)")
                    LabeledContent("Dives in Malta", value: "\(diveLog.maltaDiveCount)")
                    LabeledContent("Dive sites visited", value: "\(diveLog.visits.count)")
                }
                Button("Choose Another Folder", systemImage: "folder.badge.gearshape") { choosingFolder = true }
                Button("Read Folder Again", systemImage: "arrow.clockwise") { Task { await diveLog.scan() } }
                    .disabled(diveLog.isScanning)
                Button("Stop Using Dive Log", systemImage: "xmark.circle", role: .destructive) { diveLog.forget() }
            } else {
                Button("Choose Folder", systemImage: "folder.badge.plus") { choosingFolder = true }
            }
            if let error = diveLog.error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        } header: {
            Text("My dives")
        } footer: {
            Text("Choose a folder with FIT files from your dive computer, for example in iCloud Drive. Dives in Malta are matched to the nearest dive site (within \(Int(DiveLog.matchDistance)) m of where you started), or to a site named in the file name, like \"Cirkewwa right arch.fit\". Those sites get a green ring on the map. The files are only read on this device.")
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
