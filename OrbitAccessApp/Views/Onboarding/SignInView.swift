import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let onComplete: () -> Void
    let onSwitchToSignUp: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(.largeTitle.bold())
                Text("Sign in with the email you used on this Mac.")
                    .font(.subheadline)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
            }
            .frame(maxWidth: 360)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)
            .frame(maxWidth: 360)

            Button("Create a new account") {
                onSwitchToSignUp()
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(32)
    }

    private var canSubmit: Bool {
        email.contains("@") && email.count >= 3
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await UserSessionService.shared.signIn(email: email)
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
