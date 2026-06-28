import Foundation

enum DaemonControlState: Equatable {
    case offline
    case starting
    case running
    case stopping
    case error(String)
}

enum DaemonManagerError: LocalizedError {
    case orbitBinaryNotFound
    case startFailed(status: Int32)
    case stopFailed(status: Int32)
    case startTimeout

    var errorDescription: String? {
        switch self {
        case .orbitBinaryNotFound:
            return "Could not find the orbit command. Activate the project venv or set ORBIT_ROOT."
        case .startFailed(let status):
            return "Failed to start Orbit daemon (exit \(status))."
        case .stopFailed(let status):
            return "Failed to stop Orbit daemon (exit \(status))."
        case .startTimeout:
            return "Orbit daemon did not come online in time."
        }
    }
}

final class DaemonManager {
    private let bridge: OrbitBridgeClient
    private(set) var controlState: DaemonControlState = .offline

    init(bridge: OrbitBridgeClient) {
        self.bridge = bridge
    }

    func resolveOrbitBinary() throws -> URL {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var candidates: [URL] = []
        if let root = ProcessInfo.processInfo.environment["ORBIT_ROOT"] {
            candidates.append(URL(fileURLWithPath: root).appendingPathComponent(".venv/bin/orbit"))
        }
        candidates.append(home.appendingPathComponent("gitall/orbit/.venv/bin/orbit"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/orbit"))

        for url in candidates where fm.isExecutableFile(atPath: url.path) {
            return url
        }

        if let path = Self.which("orbit") {
            return URL(fileURLWithPath: path)
        }

        throw DaemonManagerError.orbitBinaryNotFound
    }

    func start() async throws {
        guard controlState != .starting else { return }

        if await bridge.checkStatus() {
            controlState = .running
            return
        }

        controlState = .starting
        defer {
            if controlState == .starting {
                controlState = .offline
            }
        }

        let binary = try resolveOrbitBinary()
        let process = Process()
        process.executableURL = binary
        process.arguments = ["start", "--detach", "--no-embed", "--no-statusbar"]
        var env = ProcessInfo.processInfo.environment
        if env["ORBIT_ROOT"] == nil, let root = Self.inferOrbitRoot(from: binary) {
            env["ORBIT_ROOT"] = root
        }
        process.environment = env

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            controlState = .error(DaemonManagerError.startFailed(status: process.terminationStatus).localizedDescription)
            throw DaemonManagerError.startFailed(status: process.terminationStatus)
        }

        if await waitForOnline(timeoutSeconds: 10) {
            controlState = .running
            return
        }

        controlState = .error(DaemonManagerError.startTimeout.localizedDescription)
        throw DaemonManagerError.startTimeout
    }

    @MainActor
    func stop() async throws {
        guard controlState != .stopping else { return }
        controlState = .stopping
        defer {
            if controlState == .stopping {
                controlState = .offline
            }
        }

        if await bridge.checkStatus() {
            do {
                try await bridge.requestShutdown()
                if await waitForOffline(timeoutSeconds: 10) {
                    controlState = .offline
                    return
                }
            } catch {
                // Fall through to CLI stop.
            }
        }

        let binary = try resolveOrbitBinary()
        let process = Process()
        process.executableURL = binary
        process.arguments = ["stop"]
        var env = ProcessInfo.processInfo.environment
        if env["ORBIT_ROOT"] == nil, let root = Self.inferOrbitRoot(from: binary) {
            env["ORBIT_ROOT"] = root
        }
        process.environment = env

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            controlState = .error(DaemonManagerError.stopFailed(status: process.terminationStatus).localizedDescription)
            throw DaemonManagerError.stopFailed(status: process.terminationStatus)
        }

        _ = await waitForOffline(timeoutSeconds: 5)
        controlState = .offline
    }

    @MainActor
    func syncControlState(isOnline: Bool, isCaptureActive: Bool) {
        switch controlState {
        case .starting, .stopping:
            break
        case .error:
            if isOnline {
                controlState = isCaptureActive ? .running : .running
            }
        case .offline, .running:
            controlState = isOnline ? .running : .offline
        }
    }

    private func waitForOnline(timeoutSeconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await bridge.checkStatus() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return await bridge.checkStatus()
    }

    private func waitForOffline(timeoutSeconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if !(await bridge.checkStatus()) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return !(await bridge.checkStatus())
    }

    private static func which(_ name: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }

    private static func inferOrbitRoot(from binary: URL) -> String? {
        // .venv/bin/orbit -> repo root
        let venvBin = binary.deletingLastPathComponent()
        guard venvBin.lastPathComponent == "bin", venvBin.deletingLastPathComponent().lastPathComponent == ".venv" else {
            return nil
        }
        return venvBin.deletingLastPathComponent().deletingLastPathComponent().path
    }
}
