import Foundation
import Combine
import AppKit
import UserNotifications

/// Represents the current status of Final Cut Pro
enum FCPStatus {
    case rendering
    case idle
    case notRunning
    case error
}

/// Monitors Final Cut Pro for render progress using AppleScript
@MainActor
class FCPMonitor: ObservableObject {
    /// Current render progress (0-100)
    @Published var progress: Double = 0
    
    /// Current status of Final Cut Pro
    @Published var fcpStatus: FCPStatus = .notRunning
    
    /// Whether rendering is currently in progress
    @Published var isRendering: Bool = false
    
    /// Estimated time remaining for the render (if available)
    @Published var estimatedTimeRemaining: String?
    
    /// Timer for periodic status checks
    private var timer: Timer?
    
    /// Update interval in seconds
    private let updateInterval: TimeInterval = 2.0
    
    /// Previous rendering state for detecting completion
    private var wasRendering: Bool = false
    
    init() {
        startMonitoring()
        requestNotificationPermission()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring Final Cut Pro
    func startMonitoring() {
        // Initial check
        checkFCPStatus()
        
        // Set up periodic timer
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFCPStatus()
            }
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Check the current status of Final Cut Pro
    func checkFCPStatus() {
        // Check if Final Cut Pro is running
        guard isFCPRunning() else {
            fcpStatus = .notRunning
            isRendering = false
            progress = 0
            estimatedTimeRemaining = nil
            return
        }
        
        // Try to get render progress
        let renderInfo = getRenderProgress()
        
        if let progressValue = renderInfo.progress {
            fcpStatus = .rendering
            isRendering = true
            progress = progressValue
            estimatedTimeRemaining = renderInfo.timeRemaining
            
            // Track if we just started rendering
            if !wasRendering {
                wasRendering = true
            }
        } else {
            // Check if we just finished rendering
            if wasRendering {
                wasRendering = false
                sendRenderCompleteNotification()
            }
            
            fcpStatus = .idle
            isRendering = false
            progress = 0
            estimatedTimeRemaining = nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if Final Cut Pro is currently running
    private func isFCPRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == "com.apple.FinalCut" ||
            app.localizedName == "Final Cut Pro"
        }
    }
    
    /// Get render progress from Final Cut Pro using AppleScript
    private func getRenderProgress() -> (progress: Double?, timeRemaining: String?) {
        // AppleScript to check Final Cut Pro's rendering status
        // This uses the window title which often contains render progress info
        let script = """
        tell application "System Events"
            if exists (process "Final Cut Pro") then
                tell process "Final Cut Pro"
                    set windowList to name of every window
                    repeat with windowName in windowList
                        if windowName contains "%" then
                            return windowName as text
                        end if
                    end repeat
                    
                    -- Check for Background Tasks window
                    if exists (window "Background Tasks") then
                        tell window "Background Tasks"
                            set uiElements to entire contents
                            repeat with elem in uiElements
                                try
                                    set elemDesc to description of elem
                                    if elemDesc contains "%" then
                                        return elemDesc as text
                                    end if
                                end try
                            end repeat
                        end tell
                    end if
                end tell
            end if
            return ""
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if error == nil, let resultString = result.stringValue, !resultString.isEmpty {
                return parseProgressFromString(resultString)
            }
        }
        
        // Try alternative method using FCP's built-in progress tracking
        return tryAlternativeProgressDetection()
    }
    
    /// Parse progress percentage from a string
    private func parseProgressFromString(_ string: String) -> (progress: Double?, timeRemaining: String?) {
        // Look for percentage pattern (e.g., "45%", "Rendering 45%", etc.)
        let percentagePattern = #"(\d+(?:\.\d+)?)\s*%"#
        
        if let regex = try? NSRegularExpression(pattern: percentagePattern),
           let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
           let range = Range(match.range(at: 1), in: string) {
            let percentString = String(string[range])
            if let percent = Double(percentString) {
                // Try to find time remaining
                let timeRemaining = parseTimeRemaining(from: string)
                return (percent, timeRemaining)
            }
        }
        
        return (nil, nil)
    }
    
    /// Parse time remaining from a string
    private func parseTimeRemaining(from string: String) -> String? {
        // Look for time patterns like "2:30 remaining", "1h 30m", etc.
        let timePatterns = [
            #"(\d+:\d+(?::\d+)?)\s*(?:remaining|left)"#,
            #"(\d+h?\s*\d*m?\s*\d*s?)\s*(?:remaining|left)"#,
            #"about\s+(\d+\s*(?:minutes?|mins?|hours?|hrs?|seconds?|secs?))"#
        ]
        
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
               let range = Range(match.range(at: 1), in: string) {
                return String(string[range])
            }
        }
        
        return nil
    }
    
    /// Alternative method to detect rendering progress
    private func tryAlternativeProgressDetection() -> (progress: Double?, timeRemaining: String?) {
        // Try using Accessibility API to check for progress indicators
        let script = """
        tell application "System Events"
            if exists (process "Final Cut Pro") then
                tell process "Final Cut Pro"
                    -- Check for progress indicators
                    set progressIndicators to every progress indicator of every window
                    repeat with indicator in progressIndicators
                        try
                            set progressValue to value of item 1 of indicator
                            if progressValue is not missing value then
                                return progressValue as text
                            end if
                        end try
                    end repeat
                    
                    -- Check menubar for render status
                    try
                        set menuItems to name of every menu item of menu 1 of menu bar item "Share" of menu bar 1
                        repeat with menuItem in menuItems
                            if menuItem contains "%" then
                                return menuItem as text
                            end if
                        end repeat
                    end try
                end tell
            end if
            return ""
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if error == nil, let resultString = result.stringValue, !resultString.isEmpty {
                // Try to parse as a number (progress indicator value is 0-1)
                if let value = Double(resultString), value >= 0, value <= 1 {
                    return (value * 100, nil)
                }
                return parseProgressFromString(resultString)
            }
        }
        
        return (nil, nil)
    }
    
    // MARK: - Notifications
    
    /// Request permission to send notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Send a notification when render completes
    private func sendRenderCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Render Complete"
        content.body = "Final Cut Pro has finished rendering."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
