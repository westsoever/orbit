import Foundation

struct SemanticSearchFunction: AIFunction {
    let id = "semantic-search"
    let title = "Semantic Search"
    let icon = "magnifyingglass"
    let section: SidebaneSection = .search

    func execute(_ context: AIFunctionContext) async {
        await MainActor.run {
            context.searchStore.activateSemanticSearch()
            if !context.canUseLiveServices {
                context.searchStore.mode = .lexical
            }
        }
    }
}
