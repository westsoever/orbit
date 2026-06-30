import SwiftUI

struct SignUpView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var useCloudAccount = false
    @State private var acceptedPrivacy = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Welcome to Orbit")
                    .font(.largeTitle.bold())
                Text("Your context stays on this Mac. Create an account to start capture.")
                    .font(.subheadline)
                    .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)

                TextField("Display name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)

                Toggle("Link cloud account (optional)", isOn: $useCloudAccount)
                    .font(.subheadline)

                if useCloudAccount {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    Text("Used for cross-device identity via Orbit Cloud AI relay. Context is never uploaded.")
                        .font(.caption)
                        .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))
                }
            }
            .frame(maxWidth: 360)

            Toggle(isOn: $acceptedPrivacy) {
                Text("I agree to local context capture under the Orbit privacy policy.")
                    .font(.caption)
            }
            .frame(maxWidth: 360)

            if let privacyURL = OrbitPaths.privacyPolicyURL() {
                Link("Read privacy policy", destination: privacyURL)
                    .font(.caption)
            }

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
                    Text("Create account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)
            .frame(maxWidth: 360)
        }
        .padding(32)
    }

    private var canSubmit: Bool {
        acceptedPrivacy &&
            email.contains("@") &&
            !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (!useCloudAccount || password.count >= 8)
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                _ = try await UserSessionService.shared.signUp(
                    email: email,
                    displayName: displayName,
                    password: useCloudAccount ? password : nil
                )
                onComplete()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
