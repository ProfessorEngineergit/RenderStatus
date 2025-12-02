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

RenderStatus uses AppleScript to communicate with Final Cut Pro through macOS's Apple Events system. It:

1. Checks if Final Cut Pro is running
2. Queries window titles and UI elements for render progress information
3. Parses progress percentages from the returned data
4. Updates the menubar display every 2 seconds

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
