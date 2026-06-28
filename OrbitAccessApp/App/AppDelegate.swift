import AppKit

extension Notification.Name {
    static let orbitAccessActivate = Notification.Name("com.orbit.access.activate")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        _ = enforceSingleInstance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DaemonNotificationService.shared.configure()
        Task {
            await DaemonNotificationService.shared.requestAuthorizationIfNeeded()
        }
        registerAIFunctions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .openMainWindow,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .orbitAccessActivate,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.teardown()
        InstanceLock.release()
    }

    @MainActor
    func configureStatusBar(viewModel: AppViewModel) {
        guard statusBarController == nil else { return }
        let controller = StatusBarController()
        controller.setup(viewModel: viewModel)
        statusBarController = controller
    }

    @discardableResult
    private func enforceSingleInstance() -> Bool {
        if let bundleID = Bundle.main.bundleIdentifier {
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != currentPID }
            if let existing = others.first {
                existing.activate(options: [.activateAllWindows])
                DistributedNotificationCenter.default().post(name: .orbitAccessActivate, object: nil)
                NSApp.terminate(nil)
                return false
            }
        }

        if !InstanceLock.acquire() {
            DistributedNotificationCenter.default().post(name: .orbitAccessActivate, object: nil)
            NSApp.terminate(nil)
            return false
        }

        return true
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
