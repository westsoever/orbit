import Foundation

enum ChatErrorFormatter {
    static func userMessage(for error: Error) -> String {
        if let bridgeError = error as? OrbitBridgeError {
            return message(for: bridgeError)
        }
        if let urlError = error as? URLError {
            return message(for: urlError)
        }
        let text = error.localizedDescription
        return friendlyServerMessage(text) ?? text
    }

    static func aiSetupMessage(for error: Error) -> String {
        if let preferencesError = error as? LLMPreferencesError {
            return preferencesError.localizedDescription
        }
        if error is CloudAIError {
            return cloudRegistrationMessage(for: error)
        }
        return userMessage(for: error)
    }

    static func relayRegistrationMessage(_ raw: String) -> String {
        friendlyServerMessage(raw) ?? raw
    }

    static func cloudRegistrationMessage(for error: Error) -> String {
        if let cloudError = error as? CloudAIError {
            return cloudError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut:
                return "Cloud AI service is unreachable. Start the relay (services/orbit-relay/run-local.sh) or set ORBIT_RELAY_URL."
            case .notConnectedToInternet:
                return "Cloud AI registration needs a network connection to reach the relay."
            default:
                return "Cloud AI registration failed: \(urlError.localizedDescription)"
            }
        }
        return userMessage(for: error)
    }

    static func isMissingCredentials(_ error: Error) -> Bool {
        let text: String
        if case OrbitBridgeError.serverMessage(let message) = error {
            text = message
        } else {
            text = error.localizedDescription
        }
        let lower = text.lowercased()
        return lower.contains("no ai credentials")
            || lower.contains("enable orbit cloud ai")
            || lower.contains("openrouter_api_key")
    }

    static func noChatAvailable(hasDatabase: Bool, hasDaemon: Bool) -> String {
        if !hasDatabase && !hasDaemon {
            return "Chat is unavailable while Orbit is still starting. Wait a moment for the database and background service to load."
        }
        if !hasDatabase {
            return "Chat is unavailable because the Orbit database is not ready yet. Retry from the notification in the bottom-left corner."
        }
        return "Chat is unavailable because Orbit's background service is not responding. Quit and reopen the app, or use Retry in the sidebar."
    }

    private static func message(for error: OrbitBridgeError) -> String {
        switch error {
        case .invalidResponse:
            return "Orbit returned an unexpected response. Quit and reopen the app to restart the background service."
        case .httpStatus(let code):
            switch code {
            case 503:
                return "Orbit could not answer right now. Check that AI is configured (Cloud AI, an API key in ~/.orbit/.env, or a local Ollama model)."
            case 502, 504:
                return "Orbit timed out while generating an answer. Try a shorter question or check your AI provider."
            default:
                return "Orbit returned an error (HTTP \(code)). Quit and reopen the app if this keeps happening."
            }
        case .serverMessage(let message):
            return friendlyServerMessage(message) ?? message
        case .daemonOffline:
            return "Orbit's background service is not responding. It starts automatically with the app — quit and reopen Orbit if this persists."
        }
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost:
            return "Cannot reach Orbit's background service yet. It should start automatically when you open the app — wait a moment and try again."
        case .timedOut:
            return "Orbit took too long to respond. The daemon may be busy — try again."
        case .notConnectedToInternet:
            return "Network error while talking to Orbit. The background service should be running on this Mac."
        default:
            return "Connection to Orbit failed: \(error.localizedDescription)"
        }
    }

    private static func friendlyServerMessage(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("No AI credentials configured") {
            return trimmed
        }

        switch trimmed {
        case "relay_disabled":
            return "Cloud AI is temporarily unavailable. Try again later or add your own API key in ~/.orbit/.env."
        case "upstream_unavailable":
            return "The AI provider is temporarily unavailable. Try again in a few minutes."
        case "registration_limit_exceeded":
            return "Cloud AI registration limit reached. Try again tomorrow or add your own API key in ~/.orbit/.env."
        case "invalid_invite":
            return "Cloud AI registration failed: invalid invite code."
        case "install_id_already_registered":
            return "This Mac is already registered for Cloud AI. Open ~/.orbit/cloud.json or disable Cloud AI in Settings and try again."
        case "database unavailable":
            return "Orbit database is unavailable. Restart the app or choose ~/.orbit/orbit.db again."
        default:
            if trimmed.contains("rate_limit") || trimmed.contains("Daily cloud AI limit") {
                return "Daily Cloud AI limit reached. Try again tomorrow or add OPENROUTER_API_KEY to ~/.orbit/.env."
            }
            if trimmed.contains("Cloud AI session expired") {
                return trimmed
            }
            if trimmed.contains("Connection refused")
                || trimmed.contains("Failed to establish a new connection")
                || trimmed.contains("Connection error") {
                return "Could not reach the local AI model. If you use Ollama, run `ollama serve` and `ollama pull llama3.1`, or enable Cloud AI."
            }
            if trimmed.contains("model") && trimmed.contains("not found") {
                return "The configured local model was not found in Ollama. Run `ollama pull llama3.1` or set ORBIT_LOCAL_LLM_MODEL in ~/.orbit/.env."
            }
            if trimmed == trimmed.uppercased(), trimmed.contains("_") {
                return "Orbit reported a problem: \(trimmed.replacingOccurrences(of: "_", with: " "))."
            }
            return nil
        }
    }
}
