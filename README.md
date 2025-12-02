# RenderStatus

A native macOS menubar application that displays render progress from Final Cut Pro in real-time.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- 🎬 **Real-time Render Progress**: Displays Final Cut Pro's current render progress percentage directly in your menubar
- 📊 **Visual Progress Indicator**: Shows both percentage text and a progress bar in the dropdown menu
- 🔔 **Notifications**: Get notified when your render completes
- 🚀 **Lightweight**: Minimal resource usage with efficient polling
- 🎯 **Menubar-Only**: Runs entirely in your menubar without cluttering your dock

## Screenshots

When Final Cut Pro is rendering:
```
[🎬 45%] ← Menubar shows film icon with percentage
```

Dropdown Menu Features:
- Current status indicator (Rendering/Idle/Not Running)
- Detailed progress bar when rendering
- Estimated time remaining (when available)
- Quick launch Final Cut Pro button
- Refresh status option

## Requirements

- **macOS 13.0** (Ventura) or later
- **Xcode 15.0** or later (for building)
- **Final Cut Pro** (to monitor render progress)

## Installation

### Option 1: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/ProfessorEngineergit/RenderStatus.git
   cd RenderStatus
   ```

2. Open the project in Xcode:
   ```bash
   open RenderStatus.xcodeproj
   ```

3. Build and run the project:
   - Select the `RenderStatus` scheme
   - Press `⌘R` to build and run
   - Or go to Product → Run

4. (Optional) Archive for distribution:
   - Go to Product → Archive
   - Export the app for distribution

### Option 2: Download Release

Download the latest release from the [Releases](https://github.com/ProfessorEngineergit/RenderStatus/releases) page.

## Usage

1. **Launch the App**: After building or downloading, run RenderStatus. It will appear in your menubar with a film icon.

2. **Grant Permissions**: On first launch, you'll need to grant Automation permissions:
   - Go to **System Preferences → Privacy & Security → Automation**
   - Enable RenderStatus to control Final Cut Pro
   - You may also need to grant **Accessibility** access for full functionality

3. **Monitor Render Progress**:
   - When Final Cut Pro is rendering, you'll see the percentage in the menubar
   - Click the icon to see detailed progress information
   - The app automatically updates every 2 seconds

4. **Notifications**: When a render completes, you'll receive a notification (ensure notifications are enabled for RenderStatus in System Preferences).

## Permissions

RenderStatus requires the following permissions to function:

| Permission | Reason |
|------------|--------|
| **Automation** (Apple Events) | To communicate with Final Cut Pro and read render progress |
| **Notifications** (Optional) | To notify you when renders complete |

To grant permissions:
1. Open **System Preferences** → **Privacy & Security**
2. Under **Automation**, find RenderStatus and enable it for Final Cut Pro
3. Under **Notifications**, find RenderStatus and enable notifications

## Project Structure

```
RenderStatus/
├── RenderStatus.xcodeproj/
│   └── project.pbxproj
├── RenderStatus/
│   ├── RenderStatusApp.swift      # Main app entry point
│   ├── MenuBarView.swift          # UI for menubar dropdown
│   ├── FCPMonitor.swift           # Final Cut Pro monitoring logic
│   ├── Assets.xcassets/           # App icons and assets
│   ├── Info.plist                 # App configuration
│   └── RenderStatus.entitlements  # App permissions
└── README.md
```

## How It Works

RenderStatus uses AppleScript to communicate with Final Cut Pro through macOS's Apple Events system. The app employs a multi-layered detection strategy to reliably capture render progress information.

### Detection Overview

The app continuously monitors Final Cut Pro using a timer-based polling mechanism that runs every 2 seconds. Each polling cycle performs the following steps:

1. **Check if Final Cut Pro is running**: Uses `NSWorkspace` to check if the app with bundle ID `com.apple.FinalCut` is active
2. **Query for render progress**: Executes multiple AppleScript-based detection methods
3. **Parse progress data**: Extracts percentage values using regex pattern matching
4. **Update the UI**: Refreshes the menubar display with the current progress

### Detection Methods

RenderStatus uses three fallback methods to detect render progress, trying each in sequence until one succeeds:

#### 1. Primary Method: Window Names & Background Tasks

The primary detection method uses AppleScript via the System Events application to:

- **Scan all window names**: Iterates through all Final Cut Pro windows looking for percentage values in window titles (e.g., "Rendering - 45%")
- **Check Background Tasks window**: Specifically queries the "Background Tasks" window which Final Cut Pro opens during rendering:
  - Examines the `value` and `description` properties of all UI elements
  - Looks for strings containing the "%" character

```applescript
tell application "System Events"
    tell process "Final Cut Pro"
        set windowList to name of every window
        repeat with windowName in windowList
            if windowName contains "%" then
                return windowName as text
            end if
        end repeat
    end tell
end tell
```

*Note: This is a simplified example. The actual implementation includes additional error handling and checks for the Background Tasks window.*

#### 2. Alternative Method: Progress Indicators & Menus

If the primary method doesn't find progress information, this method:

- **Queries progress indicator elements**: Searches for native `AXProgressIndicator` elements in all windows and reads their `value` property (0.0-1.0 range)
- **Checks Window and View menus**: Scans menu items in the menubar for percentage strings that might indicate render status

#### 3. UI Elements Method: Static Text & Deep Scanning

As a final fallback, this method performs a deeper scan:

- **Static text elements**: Checks the `value` property of all static text UI elements in every window
- **Group elements**: Recursively searches within group containers for static text elements
- **Progress indicators via role**: Uses the Accessibility API to find elements with `role = "AXProgressIndicator"` and reads their values

### Progress Parsing

Once text containing progress information is found, it's parsed using pre-compiled regular expressions:

- **Percentage pattern**: `(\d+(?:\.\d+)?)\s*%` - Matches numbers followed by a percent sign (e.g., "45%", "67.5%")
- **Time remaining patterns**: Multiple patterns to extract estimated completion time:
  - `(\d+:\d+(?::\d+)?)\s*(?:remaining|left)` - Time in HH:MM:SS or MM:SS format (e.g., "1:30:00 remaining", "05:30 left")
  - `(\d+h?\s*\d*m?\s*\d*s?)\s*(?:remaining|left)` - Natural time format (e.g., "2h 30m remaining", "45m left")
  - `about\s+(\d+\s*(?:minutes?|mins?|hours?|hrs?|seconds?|secs?))` - Approximate time (e.g., "about 5 minutes")

### Render Completion Detection

The app tracks state changes to detect when a render completes:

1. Maintains a `wasRendering` flag to track the previous state
2. When transitioning from rendering → not rendering, triggers a completion notification
3. Sends a macOS notification via `UNUserNotificationCenter` to alert the user

### Performance Considerations

- **Async execution**: AppleScript calls run on a background thread (`DispatchQueue.global`) to prevent UI blocking
- **Overlapping prevention**: A flag prevents multiple simultaneous status checks
- **Pre-compiled regex**: Regular expressions are compiled once at class initialization for efficiency
- **Common run loop mode**: The timer is added to `.common` mode to continue updating even during menu interactions

## Troubleshooting

### App doesn't show render progress

1. **Check permissions**: Ensure Automation permissions are granted
2. **Restart the app**: Quit and relaunch RenderStatus
3. **Verify FCP is rendering**: Make sure Final Cut Pro is actually rendering (not just idle)

### Permission denied errors

1. Go to System Preferences → Privacy & Security → Automation
2. Remove RenderStatus from the list
3. Relaunch RenderStatus and re-grant permissions

### App doesn't appear in menubar

1. Check if the app is running in Activity Monitor
2. Try building and running from Xcode again
3. Ensure macOS 13.0 or later is installed

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and modern macOS APIs
- Uses native macOS MenuBarExtra for seamless integration
- Inspired by the need to monitor long renders without constantly checking Final Cut Pro
