import SwiftUI

struct FirstRunWizardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var step = 0
    @State private var accessibilityGranted = AccessibilityService.isTrusted()

    let onComplete: () -> Void

    private let steps = ["Welcome", "Accessibility", "Ready"]

    var body: some View {
        VStack(spacing: 28) {
            stepIndicator

            Group {
                switch step {
                case 0: welcomeStep
                case 1: accessibilityStep
                default: readyStep
                }
            }
            .frame(minHeight: 220)

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(step == steps.count - 1 ? "Continue to Orbit" : "Next", action: advance)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: 420)
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 480)
        .onAppear {
            accessibilityGranted = AccessibilityService.isTrusted()
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { index in
                Circle()
                    .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 12) {
            Text("Welcome to Orbit")
                .font(.largeTitle.bold())
            Text("Orbit captures text from your active windows locally on this Mac — nothing is uploaded unless you enable Cloud AI.")
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(alignment: .leading, spacing: 8) {
                Label("If macOS blocks the app on first launch, right-click Orbit in Applications → Open.", systemImage: "lock.shield")
                Label("Or run in Terminal: xattr -cr /Applications/Orbit.app", systemImage: "terminal")
            }
            .font(.caption)
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            .frame(maxWidth: 420, alignment: .leading)
        }
    }

    private var accessibilityStep: some View {
        VStack(spacing: 12) {
            Text("Enable Accessibility")
                .font(.title2.bold())
            Text("Orbit needs Accessibility permission to read window text. Your data stays in ~/.orbit/ on this Mac.")
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            HStack(spacing: 8) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
                Text(accessibilityGranted ? "Accessibility is enabled" : "Accessibility not detected yet")
                    .font(.callout)
            }

            Button("Open System Settings") {
                AccessibilityService.openAccessibilitySettings()
                _ = AccessibilityService.isTrusted(prompt: true)
            }
            .buttonStyle(.bordered)

            Button("Check again") {
                accessibilityGranted = AccessibilityService.isTrusted()
            }
            .font(.caption)
            .buttonStyle(.link)
        }
    }

    private var readyStep: some View {
        VStack(spacing: 12) {
            Text("You're set up")
                .font(.title2.bold())
            Text("Create an account on the next screen to start capture. For AI chat, add an API key or install Ollama in Settings later.")
                .font(.subheadline)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
    }

    private func advance() {
        if step < steps.count - 1 {
            step += 1
            accessibilityGranted = AccessibilityService.isTrusted()
        } else {
            UserDefaults.standard.set(true, forKey: FirstRunKeys.completed)
            onComplete()
        }
    }
}

enum FirstRunKeys {
    static let completed = "orbit.firstRunCompleted"
}
