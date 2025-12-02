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
            // Show circular progress indicator when rendering
            if fcpMonitor.isRendering {
                CircularProgressView(progress: fcpMonitor.progress / 100)
                    .frame(width: 18, height: 18)
                
                Text("\(Int(fcpMonitor.progress))%")
                    .font(.system(size: 10, weight: .medium))
            } else {
                Image(systemName: statusIcon)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
    
    /// Icon based on FCP status
    private var statusIcon: String {
        switch fcpMonitor.fcpStatus {
        case .rendering:
            return "film.circle.fill"
        case .idle:
            return "film.circle"
        case .notRunning:
            return "film"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

/// Circular progress view for the menu bar
struct CircularProgressView: View {
    var progress: Double
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: 2)
                .opacity(0.3)
                .foregroundColor(.gray)
            
            // Progress arc
            Circle()
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundColor(progressColor)
                .rotationEffect(Angle(degrees: -90))
            
            // Center icon
            Image(systemName: "film.fill")
                .font(.system(size: 8))
                .foregroundColor(progressColor)
        }
    }
    
    /// Color based on progress
    private var progressColor: Color {
        if progress < 0.3 {
            return .orange
        } else if progress < 0.7 {
            return .yellow
        } else {
            return .green
        }
    }
}
