import SwiftUI

struct OnboardingContainerView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        SignUpView(onComplete: {
            model.completeSignUp()
        })
        .frame(minWidth: 520, minHeight: 560)
    }
}
