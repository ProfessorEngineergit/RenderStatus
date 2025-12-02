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
    
    /// Last error message for debugging
    @Published var lastError: String?
    
    /// Timer for periodic status checks
    private var timer: Timer?
    
    /// Update interval in seconds
    private let updateInterval: TimeInterval = 2.0
    
    /// Previous rendering state for detecting completion
    private var wasRendering: Bool = false
    
    /// Flag to prevent overlapping status checks
    private var isCheckingStatus: Bool = false
    
    /// Pre-compiled regex for percentage pattern
    private static let percentageRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*%"#)
    }()
    
    /// Pre-compiled regex patterns for time remaining
    private static let timeRemainingRegexes: [NSRegularExpression] = {
        let patterns = [
            #"(\d+:\d+(?::\d+)?)\s*(?:remaining|left)"#,
            #"(\d+h?\s*\d*m?\s*\d*s?)\s*(?:remaining|left)"#,
            #"about\s+(\d+\s*(?:minutes?|mins?|hours?|hrs?|seconds?|secs?))"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()
    
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
        // Stop any existing timer
        stopMonitoring()
        
        // Initial check
        performStatusCheck()
        
        // Set up periodic timer on main run loop
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performStatusCheck()
            }
        }
        
        // Add to common run loop mode to ensure it fires even during menu interactions
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Perform status check (called by timer and externally)
    private func performStatusCheck() {
        // Prevent overlapping checks
        guard !isCheckingStatus else { return }
        checkFCPStatus()
    }
    
    /// Check the current status of Final Cut Pro
    func checkFCPStatus() {
        isCheckingStatus = true
        defer { isCheckingStatus = false }
        
        // Clear previous error
        lastError = nil
        
        // Check if Final Cut Pro is running
        guard isFCPRunning() else {
            fcpStatus = .notRunning
            isRendering = false
            progress = 0
            estimatedTimeRemaining = nil
            return
        }
        
        // Try to get render progress using async task to avoid blocking UI
        Task {
            let renderInfo = await self.getRenderProgressAsync()
            self.updateStatus(with: renderInfo)
        }
    }
    
    /// Update status based on render info
    private func updateStatus(with renderInfo: (progress: Double?, timeRemaining: String?)) {
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
    
    /// Get render progress from Final Cut Pro using AppleScript (async version)
    private func getRenderProgressAsync() async -> (progress: Double?, timeRemaining: String?) {
        // Run AppleScript on background thread to avoid blocking UI
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = self?.executeRenderProgressScripts() ?? (nil, nil)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Execute all render progress detection scripts (runs on background thread)
    private func executeRenderProgressScripts() -> (progress: Double?, timeRemaining: String?) {
        // Try primary method first
        if let result = tryPrimaryProgressDetection(), result.progress != nil {
            return result
        }
        
        // Try alternative method
        if let result = tryAlternativeProgressDetection(), result.progress != nil {
            return result
        }
        
        // Try static text and UI elements method
        if let result = tryUIElementsProgressDetection(), result.progress != nil {
            return result
        }
        
        return (nil, nil)
    }
    
    /// Primary method: Check window names and Background Tasks
    private func tryPrimaryProgressDetection() -> (progress: Double?, timeRemaining: String?)? {
        let script = """
        tell application "System Events"
            if exists (process "Final Cut Pro") then
                tell process "Final Cut Pro"
                    set allResults to ""
                    
                    -- Get all window names
                    try
                        set windowList to name of every window
                        repeat with windowName in windowList
                            if windowName contains "%" then
                                return windowName as text
                            end if
                            set allResults to allResults & windowName & " | "
                        end repeat
                    end try
                    
                    -- Check for Background Tasks window
                    try
                        if exists (window "Background Tasks") then
                            tell window "Background Tasks"
                                set uiElements to entire contents
                                repeat with elem in uiElements
                                    try
                                        set elemValue to value of elem
                                        if elemValue is not missing value then
                                            set elemStr to elemValue as text
                                            if elemStr contains "%" then
                                                return elemStr
                                            end if
                                        end if
                                    end try
                                    try
                                        set elemDesc to description of elem
                                        if elemDesc is not missing value then
                                            set descStr to elemDesc as text
                                            if descStr contains "%" then
                                                return descStr
                                            end if
                                        end if
                                    end try
                                end repeat
                            end tell
                        end if
                    end try
                end tell
            end if
            return ""
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if error != nil {
                // Error occurred but we'll try alternative methods
                // Note: Can't set @Published property from background thread
            }
            
            if let resultString = result.stringValue, !resultString.isEmpty {
                return parseProgressFromString(resultString)
            }
        }
        
        return nil
    }
    
    /// Parse progress percentage from a string
    private func parseProgressFromString(_ string: String) -> (progress: Double?, timeRemaining: String?) {
        // Use pre-compiled regex for percentage pattern
        guard let regex = Self.percentageRegex,
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else {
            return (nil, nil)
        }
        
        let percentString = String(string[range])
        guard let percent = Double(percentString) else {
            return (nil, nil)
        }
        
        // Try to find time remaining
        let timeRemaining = parseTimeRemaining(from: string)
        return (percent, timeRemaining)
    }
    
    /// Parse time remaining from a string
    private func parseTimeRemaining(from string: String) -> String? {
        // Use pre-compiled regex patterns for time remaining
        for regex in Self.timeRemainingRegexes {
            if let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
               let range = Range(match.range(at: 1), in: string) {
                return String(string[range])
            }
        }
        
        return nil
    }
    
    /// Alternative method to detect rendering progress
    private func tryAlternativeProgressDetection() -> (progress: Double?, timeRemaining: String?)? {
        // Try using Accessibility API to check for progress indicators
        let script = """
        tell application "System Events"
            if exists (process "Final Cut Pro") then
                tell process "Final Cut Pro"
                    -- Check for progress indicators in all windows
                    try
                        repeat with w in windows
                            set progressInds to every progress indicator of w
                            repeat with indicator in progressInds
                                try
                                    set progressValue to value of indicator
                                    if progressValue is not missing value then
                                        return progressValue as text
                                    end if
                                end try
                            end repeat
                        end repeat
                    end try
                    
                    -- Check menubar Window menu for render status
                    try
                        set menuItems to name of every menu item of menu 1 of menu bar item "Window" of menu bar 1
                        repeat with menuItem in menuItems
                            if menuItem contains "%" then
                                return menuItem as text
                            end if
                        end repeat
                    end try
                    
                    -- Check menubar View menu for render status
                    try
                        set menuItems to name of every menu item of menu 1 of menu bar item "View" of menu bar 1
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
            
            if let resultString = result.stringValue, !resultString.isEmpty {
                // Try to parse as a number (progress indicator value is 0-1)
                if let value = Double(resultString), value >= 0, value <= 1 {
                    return (value * 100, nil)
                }
                return parseProgressFromString(resultString)
            }
        }
        
        return nil
    }
    
    /// Try to detect progress from UI elements like static text
    private func tryUIElementsProgressDetection() -> (progress: Double?, timeRemaining: String?)? {
        let script = """
        tell application "System Events"
            if exists (process "Final Cut Pro") then
                tell process "Final Cut Pro"
                    -- Check all static text elements for percentage
                    try
                        repeat with w in windows
                            set staticTexts to every static text of w
                            repeat with txt in staticTexts
                                try
                                    set txtValue to value of txt
                                    if txtValue is not missing value then
                                        set txtStr to txtValue as text
                                        if txtStr contains "%" then
                                            return txtStr
                                        end if
                                    end if
                                end try
                            end repeat
                            
                            -- Check groups recursively
                            try
                                set allGroups to every group of w
                                repeat with grp in allGroups
                                    set grpTexts to every static text of grp
                                    repeat with txt in grpTexts
                                        try
                                            set txtValue to value of txt
                                            if txtValue is not missing value then
                                                set txtStr to txtValue as text
                                                if txtStr contains "%" then
                                                    return txtStr
                                                end if
                                            end if
                                        end try
                                    end repeat
                                end repeat
                            end try
                        end repeat
                    end try
                    
                    -- Check the Share/Export progress
                    try
                        if exists (window 1) then
                            tell window 1
                                set allElements to entire contents
                                repeat with elem in allElements
                                    try
                                        set elemRole to role of elem
                                        if elemRole is "AXProgressIndicator" then
                                            set progressValue to value of elem
                                            if progressValue is not missing value then
                                                return (progressValue * 100) as text
                                            end if
                                        end if
                                    end try
                                end repeat
                            end tell
                        end if
                    end try
                end tell
            end if
            return ""
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if let resultString = result.stringValue, !resultString.isEmpty {
                // Try to parse as a number first (in case it's already scaled)
                if let value = Double(resultString) {
                    if value >= 0 && value <= 1 {
                        return (value * 100, nil)
                    } else if value > 0 && value <= 100 {
                        return (value, nil)
                    }
                }
                return parseProgressFromString(resultString)
            }
        }
        
        return nil
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
