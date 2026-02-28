import SwiftUI
import Combine

@main
struct BayWheelsMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Preferences window, opened via menu item.
        Window("Bay Wheels — Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// MARK: - AppDelegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()

    private let gbfs = GBFSService.shared
    private let locationService = LocationService.shared
    private let prefs = Preferences.shared
    private let store = StationStore.shared

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — this is a menu bar–only app.
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemTitle(0)

        // Start services.
        gbfs.startPolling(interval: 30)
        locationService.startUpdating()

        // React to store changes.
        store.$totalEbikes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.updateStatusItemTitle(count)
            }
            .store(in: &cancellables)

        store.$displayStations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Also rebuild menu when mode or error changes.
        prefs.$mode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        gbfs.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Rebuild immediately when location arrives.
        locationService.$location
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        rebuildMenu()
    }

    // MARK: - Status Item

    private func updateStatusItemTitle(_ count: Int) {
        guard let button = statusItem.button else { return }

        let attachment = NSTextAttachment()
        if let img = NSImage(systemSymbolName: "bicycle", accessibilityDescription: "eBikes") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            attachment.image = img.withSymbolConfiguration(config)
        }

        let attrStr = NSMutableAttributedString()
        attrStr.append(NSAttributedString(attachment: attachment))
        attrStr.append(NSAttributedString(string: " \(count)",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)]))

        button.attributedTitle = attrStr
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        // Header
        let modeLabel = prefs.mode == .nearby
            ? "Nearby (\(Int(prefs.range))m)"
            : "Favorites"
        let header = NSMenuItem(title: "\(store.totalEbikes) eBikes — \(modeLabel)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        let headerFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        header.attributedTitle = NSAttributedString(string: header.title,
            attributes: [.font: headerFont])
        menu.addItem(header)

        // Error
        if let error = gbfs.error {
            let errorItem = NSMenuItem(title: "⚠ \(error)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        // No location warning in nearby mode
        if prefs.mode == .nearby && locationService.location == nil {
            if locationService.authorizationStatus == .denied ||
               locationService.authorizationStatus == .restricted {
                let noLoc = NSMenuItem(title: "Location access denied", action: nil, keyEquivalent: "")
                noLoc.isEnabled = false
                menu.addItem(noLoc)
                let openSettings = NSMenuItem(title: "Open Location Settings…", action: #selector(openLocationSettings), keyEquivalent: "")
                openSettings.target = self
                menu.addItem(openSettings)
            } else {
                let noLoc = NSMenuItem(title: "Waiting for location…", action: nil, keyEquivalent: "")
                noLoc.isEnabled = false
                menu.addItem(noLoc)
            }
        }

        // Station list
        if store.displayStations.isEmpty {
            let empty: String
            switch prefs.mode {
            case .nearby:
                empty = "No stations in range"
            case .favorites:
                empty = prefs.favorites.isEmpty
                    ? "No favorites — add in Preferences"
                    : "Loading..."
            }
            let emptyItem = NSMenuItem(title: empty, action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for station in store.displayStations {
                let item = stationMenuItem(station)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Mode submenu
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu()
        for mode in AppMode.allCases {
            let mi = NSMenuItem(title: mode.label, action: #selector(changeMode(_:)), keyEquivalent: "")
            mi.target = self
            mi.representedObject = mode
            mi.state = (mode == prefs.mode) ? .on : .off
            modeSubmenu.addItem(mi)
        }
        modeItem.submenu = modeSubmenu
        menu.addItem(modeItem)

        // Range submenu (only in nearby mode)
        if prefs.mode == .nearby {
            let rangeItem = NSMenuItem(title: "Range", action: nil, keyEquivalent: "")
            let rangeSubmenu = NSMenu()
            for r in Preferences.rangeOptions {
                let ri = NSMenuItem(title: "\(Int(r))m", action: #selector(changeRange(_:)), keyEquivalent: "")
                ri.target = self
                ri.representedObject = r
                ri.state = (r == prefs.range) ? .on : .off
                rangeSubmenu.addItem(ri)
            }
            rangeItem.submenu = rangeSubmenu
            menu.addItem(rangeItem)
        }

        menu.addItem(.separator())

        // Last updated
        if let updated = gbfs.lastUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            let ago = formatter.localizedString(for: updated, relativeTo: Date())
            let updatedItem = NSMenuItem(title: "Updated \(ago)", action: nil, keyEquivalent: "")
            updatedItem.isEnabled = false
            menu.addItem(updatedItem)
        }

        // Refresh
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Bay Wheels", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func stationMenuItem(_ station: DisplayStation) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: #selector(openStation(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = station.mapsURL

        // Build attributed title: "StationName    3 eBikes · 200m ~3 min"
        let title = NSMutableAttributedString()

        // Station name (truncated)
        let nameStr = station.name.count > 30
            ? String(station.name.prefix(28)) + "…"
            : station.name
        title.append(NSAttributedString(string: nameStr,
            attributes: [.font: NSFont.systemFont(ofSize: 13)]))

        title.append(NSAttributedString(string: "  "))

        // eBike count
        let countColor: NSColor = station.ebikes > 0 ? .systemGreen : .secondaryLabelColor
        title.append(NSAttributedString(string: "\(station.ebikes)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: countColor
            ]))

        // Distance + walk time
        if let distText = station.distanceText {
            var detail = " · \(distText)"
            if let walkText = station.walkTimeText {
                detail += " \(walkText)"
            }
            title.append(NSAttributedString(string: detail,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]))
        }

        item.attributedTitle = title

        if prefs.isFavorite(station.info.station_id),
           let star = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Favorite") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            item.image = star.withSymbolConfiguration(config)
        }

        return item
    }

    // MARK: - Actions

    @objc private func changeMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? AppMode else { return }
        prefs.mode = mode
    }

    @objc private func changeRange(_ sender: NSMenuItem) {
        guard let range = sender.representedObject as? Double else { return }
        prefs.range = range
    }

    @objc private func openStation(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func refreshNow() {
        gbfs.fetch()
    }

    @objc private func openLocationSettings() {
        locationService.openLocationSettings()
    }

    @objc private func openPreferences() {
        // Open the SwiftUI preferences window.
        NSApp.setActivationPolicy(.regular)
        if let window = NSApp.windows.first(where: { $0.title.contains("Preferences") }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Trigger the window to open via the scene.
            if #available(macOS 13.0, *) {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)

        // Return to accessory mode when window closes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: nil,
                queue: .main
            ) { _ in
                if NSApp.windows.filter({ $0.isVisible }).isEmpty {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
