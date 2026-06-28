import SwiftUI

struct SearchDropdownMenu: View {
    @Environment(AppViewModel.self) private var model
    @State private var lastSelection: String?

    private var triggerTitle: String {
        if let lastSelection {
            return "Search · \(lastSelection)"
        }
        return "Search"
    }

    var body: some View {
        SidePaneDropdownTrigger(title: triggerTitle, icon: "magnifyingglass") {
            Button("Semantic Search") {
                lastSelection = "Semantic"
                Task { await SemanticSearchFunction().execute(model.aiContext()) }
            }
            Button("Find by App") {
                lastSelection = "App"
                Task { await FindByAppFunction().execute(model.aiContext()) }
            }
            Button("Find by Time") {
                lastSelection = "Time"
                model.searchStore.activateFindByTime()
            }
        }
    }
}
