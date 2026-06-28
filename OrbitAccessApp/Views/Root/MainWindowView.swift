import SwiftUI

struct MainWindowView: View {
    @Environment(AppViewModel.self) private var model
    @AppStorage("sidebaneVisible") private var sidebaneVisible = true
    @AppStorage("insightVisible") private var insightVisible = true
    @AppStorage("chatIsFloating") private var chatIsFloating = false

    var body: some View {
        ZStack {
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

            if let issue = model.seriousIssue {
                OrbitIssueNotificationHost(issue: issue) {
                    Task { await model.retryDatabaseBootstrap() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
