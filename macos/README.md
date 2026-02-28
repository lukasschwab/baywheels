# Bay Wheels Menu Bar

A macOS menu bar app that shows eBike availability at Bay Wheels stations.

## Features

- **Status bar icon** with live eBike count (bicycle icon + number)
- **Two modes:**
  - **Nearby** — shows stations within a configurable range of your location
  - **Favorites** — shows a curated list of stations you've selected
- **Click any station** in the dropdown to open it in Apple Maps
- **30-second auto-refresh** from the GBFS API
- **Distance and walk time** shown for each station
- **Preferences window** with mode toggle, range picker, and station search for managing favorites

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+
- Location permission (prompted on first launch)

## Build & Run

```bash
# Build, bundle, sign, and run:
make run

# Or step by step:
make build    # swift build -c release
make bundle   # create .app bundle with Info.plist
make sign     # ad-hoc codesign with entitlements
open "Bay Wheels.app"
```

## Architecture

```
Sources/BayWheelsMenuBar/
├── BayWheelsMenuBarApp.swift   # @main entry, AppDelegate, status bar + menu
├── Models.swift                # GBFS data models, DisplayStation
├── GBFSService.swift           # Fetches station info + status, polls every 30s
├── LocationService.swift       # CoreLocation wrapper
├── StationStore.swift          # Combines data, location, prefs → display list
├── Preferences.swift           # UserDefaults-backed settings
├── PreferencesView.swift       # SwiftUI preferences window
└── Info.plist                  # App metadata, location usage description
```

The app runs as an accessory (no Dock icon). The `LSUIElement` key in Info.plist
and `NSApp.setActivationPolicy(.accessory)` in code ensure this. When the
Preferences window is open, the app temporarily shows in the Dock.
