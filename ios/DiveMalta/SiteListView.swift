import SwiftUI

struct SiteListView: View {
    let sites: [DiveSite]
    let onPick: (DiveSite) -> Void
    @Environment(DiveLog.self) private var diveLog
    @State private var search = ""

    private var filtered: [DiveSite] {
        guard !search.isEmpty else { return sites }
        return sites.filter { $0.displayName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { site in
                Button {
                    onPick(site)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.displayName).foregroundStyle(.primary)
                            if let summary = site.summary {
                                Text(summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let dives = diveLog.visits[site.id] {
                            Label("\(dives.count)", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .accessibilityLabel(dives.count == 1 ? "Dived once" : "Dived \(dives.count) times")
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty { ContentUnavailableView.search(text: search) }
            }
            .searchable(text: $search, prompt: "Search dive sites")
            .navigationTitle("\(sites.count) dive sites")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
