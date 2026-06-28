import SwiftUI

struct DaemonStatusIndicator: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isDaemonOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(model.isDaemonOnline ? "Daemon running" : "Daemon offline")
                .font(.caption)
                .foregroundStyle(model.isDaemonOnline ? Color.primary : Color.red)
                .kerning(-0.1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
