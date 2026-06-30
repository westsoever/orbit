import SwiftUI

struct SidebaneSearchPanel: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Search context…", text: Bindable(model.searchStore).query)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit { runSearch() }
                Button(action: runSearch) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.orbitAccent)
                }
                .buttonStyle(.plain)
                .disabled(model.searchStore.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: OrbitShape.radiusControl))
            .orbitHairlineBorder(cornerRadius: OrbitShape.radiusControl, colorScheme: colorScheme)

            if model.searchStore.isSearching {
                LoadingIndicator()
            } else if model.searchStore.searchTier == .lexical, !model.canUseLiveServices, model.searchStore.panelActive {
                Text("Keyword search (semantic search when Orbit is fully online).")
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            } else if let error = model.searchStore.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if model.searchStore.hits.isEmpty, model.searchStore.panelActive {
                Text("No results")
                    .font(.caption2)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            } else {
                ForEach(model.searchStore.hits.prefix(5)) { hit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(hit.appName) · \(hit.windowTitle ?? "untitled")")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(stripHTML(hit.snippetHtml))
                            .font(.caption2)
                            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func runSearch() {
        Task {
            await model.searchStore.search(
                canUseLiveServices: model.canUseLiveServices,
                canSearchLocally: model.canSearchLocally
            )
        }
    }

    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
