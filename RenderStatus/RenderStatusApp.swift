import SwiftUI

/// Main application entry point for RenderStatus
/// This app runs as a menubar-only application (no dock icon)
@main
struct RenderStatusApp: App {
    @StateObject private var fcpMonitor = FCPMonitor()
    
    var body: some Scene {
        // Use MenuBarExtra for macOS 13.0+ menubar applications
        MenuBarExtra {
            MenuBarView(fcpMonitor: fcpMonitor)
        } label: {
            MenuBarLabel(fcpMonitor: fcpMonitor)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The label displayed in the menubar
struct MenuBarLabel: View {
    @ObservedObject var fcpMonitor: FCPMonitor
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: fcpMonitor.isRendering ? "film.circle.fill" : "film.circle")
                .symbolRenderingMode(.hierarchical)
            
            if fcpMonitor.isRendering {
                Text("\(Int(fcpMonitor.progress))%")
                    .font(.system(size: 10, weight: .medium))
            }
        }
    }
}
