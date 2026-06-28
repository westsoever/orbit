import SwiftUI

struct SidebaneView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                if model.searchStore.panelActive {
                    SidebaneSearchPanel()
                }
                SearchDropdownMenu()
                AgentsDropdownMenu()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                SidebaneCaptureFooter()
                DaemonStatusIndicator()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
