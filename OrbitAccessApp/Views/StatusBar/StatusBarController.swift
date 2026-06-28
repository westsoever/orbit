import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var viewModel: AppViewModel?

    func setup(viewModel: AppViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }
        button.title = statusGlyph
        button.action = #selector(togglePopover)
        button.target = self

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 220)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: StatusBarPopoverView().environment(viewModel)
        )

        startGlyphUpdates()
    }

    func teardown() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover = nil
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private var statusGlyph: String {
        guard let viewModel else { return "○" }
        if !viewModel.isDaemonOnline { return "×" }
        if viewModel.isCaptureActive { return "●" }
        return "○"
    }

    private func startGlyphUpdates() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.statusItem?.button?.title = self?.statusGlyph ?? "○"
            }
        }
    }

    func openMainWindow() {
        popover?.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.identifier?.rawValue == "main" {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }
}
