import Foundation

struct FindByAppFunction: AIFunction {
    let id = "find-by-app"
    let title = "Find by App"
    let icon = "app.badge"
    let section: SidebaneSection = .search

    func execute(_ context: AIFunctionContext) async {
        await MainActor.run {
            context.searchStore.activateFindByApp()
            context.searchStore.query = "find in app: "
        }
    }
}
