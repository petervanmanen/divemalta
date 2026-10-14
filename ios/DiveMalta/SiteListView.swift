import SwiftUI

struct SiteListView: View {
    let sites: [DiveSite]
    let onPick: (DiveSite) -> Void
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.displayName).foregroundStyle(.primary)
                        if let summary = site.summary {
                            Text(summary).font(.caption).foregroundStyle(.secondary)
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
