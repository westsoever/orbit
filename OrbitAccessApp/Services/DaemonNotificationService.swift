import Foundation
import UserNotifications

@MainActor
final class DaemonNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DaemonNotificationService()

    private var authorizationRequested = false

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func notifyDaemonStopped() {
        post(
            identifier: "com.orbit.daemon.stopped",
            title: "Orbit capture stopped",
            body: "Live capture and AI features are offline. Historical context is still available."
        )
    }

    func notifyDaemonStarted() {
        post(
            identifier: "com.orbit.daemon.started",
            title: "Orbit capture running",
            body: "The capture daemon is online and ready."
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func post(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
