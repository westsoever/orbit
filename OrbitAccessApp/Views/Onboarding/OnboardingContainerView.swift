import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppViewModel.self) private var model
    @State private var mode: AuthMode = .signIn
    @State private var showFirstRun = !UserDefaults.standard.bool(forKey: FirstRunKeys.completed)

    enum AuthMode {
        case signIn
        case signUp
    }

    var body: some View {
        Group {
            if showFirstRun {
                FirstRunWizardView {
                    showFirstRun = false
                }
            } else {
                authView
            }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    @ViewBuilder
    private var authView: some View {
        switch mode {
        case .signIn:
            SignInView(
                onComplete: { model.completeSignUp() },
                onSwitchToSignUp: { mode = .signUp }
            )
        case .signUp:
            SignUpView(
                onComplete: { model.completeSignUp() },
                onSwitchToSignIn: { mode = .signIn }
            )
        }
    }
}
