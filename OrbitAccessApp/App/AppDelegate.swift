import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerAIFunctions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .openMainWindow,
            object: nil
        )
    }

    @MainActor
    func configureStatusBar(viewModel: AppViewModel) {
        let controller = StatusBarController()
        controller.setup(viewModel: viewModel)
        statusBarController = controller
    }

    @objc private func openMainWindow() {
        Task { @MainActor in
            statusBarController?.openMainWindow()
        }
    }

    private func registerAIFunctions() {
        let registry = AIFunctionRegistry.shared
        registry.register(SemanticSearchFunction())
        registry.register(FindByAppFunction())
        for agent in AgentType.allCases {
            registry.register(AgentPromptFunction(agentType: agent))
        }
    }
}
