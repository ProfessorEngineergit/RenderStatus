import SwiftUI

/// The dropdown menu view displayed when clicking on the menubar icon
struct MenuBarView: View {
    @ObservedObject var fcpMonitor: FCPMonitor
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "film.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("RenderStatus")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                statusView
                
                if fcpMonitor.isRendering {
                    progressView
                }
            }
            
            Divider()
            
            // Actions
            if fcpMonitor.fcpStatus == .notRunning {
                Button {
                    launchFinalCutPro()
                } label: {
                    Label("Launch Final Cut Pro", systemImage: "play.circle")
                }
                .buttonStyle(.plain)
            }
            
            Button {
                fcpMonitor.checkFCPStatus()
            } label: {
                Label("Refresh Status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // About and Quit
            Button {
                showAbout()
            } label: {
                Label("About RenderStatus", systemImage: "info.circle")
            }
            .buttonStyle(.plain)
            
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 280)
    }
    
    // MARK: - Status View
    
    @ViewBuilder
    private var statusView: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(statusText)
                .font(.subheadline)
            
            Spacer()
        }
    }
    
    private var statusColor: Color {
        switch fcpMonitor.fcpStatus {
        case .rendering:
            return .green
        case .idle:
            return .yellow
        case .notRunning:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch fcpMonitor.fcpStatus {
        case .rendering:
            return "Final Cut Pro is rendering..."
        case .idle:
            return "Final Cut Pro is idle"
        case .notRunning:
            return "Final Cut Pro is not running"
        case .error:
            return "Unable to connect to Final Cut Pro"
        }
    }
    
    // MARK: - Progress View
    
    @ViewBuilder
    private var progressView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Render Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(fcpMonitor.progress))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: fcpMonitor.progress, total: 100)
                .progressViewStyle(.linear)
            
            if let estimatedTime = fcpMonitor.estimatedTimeRemaining {
                Text("Estimated time remaining: \(estimatedTime)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func launchFinalCutPro() {
        let url = URL(fileURLWithPath: "/Applications/Final Cut Pro.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    
    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                NSApplication.AboutPanelOptionKey.applicationName: "RenderStatus",
                NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
                NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                    string: "A menubar app to monitor Final Cut Pro render progress.",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            ]
        )
        // Bring the about panel to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(fcpMonitor: FCPMonitor())
}
