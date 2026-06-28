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
        .commands {
            SidebarToggleCommands()
        }

        Window("Orbit Chat", id: "floating-chat") {
            FloatingChatView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

private struct SidebarToggleCommands: Commands {
    @AppStorage("sidebaneVisible") private var sidebaneVisible = true
    @AppStorage("insightVisible") private var insightVisible = true

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button("Toggle Left Sidebar") { sidebaneVisible.toggle() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Toggle Right Sidebar") { insightVisible.toggle() }
                .keyboardShortcut("b", modifiers: .command)
        }
    }
}
