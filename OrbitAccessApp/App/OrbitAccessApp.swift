import SwiftUI

@main
struct OrbitAccessApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppViewModel()

    var body: some Scene {
        WindowGroup("Orbit", id: "main") {
            MainWindowView()
                .environment(model)
                .task {
                    await model.start()
                    appDelegate.configureStatusBar(viewModel: model)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 740)

        Window("Orbit Chat", id: "floating-chat") {
            FloatingChatView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
