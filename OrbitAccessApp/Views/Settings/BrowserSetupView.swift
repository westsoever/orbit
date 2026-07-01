import AppKit
import SwiftUI

struct BrowserSetupView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browser capture (Tier 2)")
                .font(.headline)

            Text("For Chrome, Arc, or Brave: load the bundled Orbit browser companion extension to capture tab URLs and titles.")
                .font(.caption)
                .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            if let path = browserExtensionPath {
                Text(path)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open chrome://extensions/ and enable Developer mode")
                Text("2. Load unpacked → select the folder above")
                Text("3. If AX capture is empty, visit chrome://accessibility/")
            }
            .font(.caption2)
            .foregroundStyle(Color.orbitSecondaryText(for: colorScheme))

            HStack(spacing: 12) {
                if let path = browserExtensionPath {
                    Button("Reveal extension folder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                Button("Open Chrome extensions") {
                    if let url = URL(string: "https://www.google.com/chrome/extensions/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .buttonStyle(.link)
            }
        }
    }

    private var browserExtensionPath: String? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/browser-extension")
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled.path
        }
        let dev = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("orbit/browser-extension")
        if FileManager.default.fileExists(atPath: dev.path) {
            return dev.path
        }
        return nil
    }
}
