import SwiftUI

struct MainWindowView: View {
    @Environment(AppViewModel.self) private var model
    @AppStorage("sidebaneVisible") private var sidebaneVisible = true
    @AppStorage("insightVisible") private var insightVisible = true
    @AppStorage("chatIsFloating") private var chatIsFloating = false

    var body: some View {
        ZStack(alignment: .top) {
            ThreePaneLayout(panes: [
            PaneDescriptor(id: "sidebane", position: .leading, preferredWidth: 220, isCollapsible: true) {
                SidebaneView()
                    .frame(width: sidebaneVisible ? 220 : 0)
                    .opacity(sidebaneVisible ? 1 : 0)
                    .clipped()
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: sidebaneVisible)
            },
            PaneDescriptor(id: "chat", position: .center, preferredWidth: 480) {
                Group {
                    if chatIsFloating {
                        FloatingChatPlaceholderView()
                    } else {
                        MainChatView()
                    }
                }
            },
            PaneDescriptor(id: "insight", position: .trailing, preferredWidth: 280, isCollapsible: true) {
                InsightSidebarView()
                    .frame(width: insightVisible ? 280 : 0)
                    .opacity(insightVisible ? 1 : 0)
                    .clipped()
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: insightVisible)
            },
        ])
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { sidebaneVisible.toggle() } label: {
                    Image(systemName: "sidebar.left")
                }
                .keyboardShortcut("\\", modifiers: .command)
            }
            ToolbarItem(placement: .automatic) {
                Button { insightVisible.toggle() } label: {
                    Image(systemName: "sidebar.right")
                }
                .keyboardShortcut("\\", modifiers: [.command, .option])
            }
        }

            VStack(spacing: 6) {
                if let error = model.bootstrapError {
                    statusBanner(error, actionTitle: "Select orbit.db") {
                        Task { await model.retryDatabaseBootstrap() }
                    }
                } else if !model.isDatabaseReady {
                    statusBanner("Select orbit.db to load context history.", actionTitle: "Select") {
                        Task { await model.retryDatabaseBootstrap() }
                    }
                } else if !model.isDaemonOnline {
                    statusBanner("Daemon offline — run `orbit start` for live search, chat, and tasks.")
                }
            }
            .padding(.top, 8)
        }
    }

    private func statusBanner(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
}
