import Foundation
import Combine

@MainActor
class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let mode = "baywheels-mode"
        static let range = "baywheels-range"
        static let favorites = "baywheels-favorites"
        static let favoriteOrder = "baywheels-favorite-order"
        static let gbfsRoot = "baywheels-gbfs-root"
        static let showStatusIcon = "baywheels-show-status-icon"
    }

    @Published var mode: AppMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Keys.mode)
        }
    }

    /// Whether to show the bicycle icon in the status bar.
    @Published var showStatusIcon: Bool {
        didSet {
            defaults.set(showStatusIcon, forKey: Keys.showStatusIcon)
        }
    }

    static let defaultGBFSRoot = "https://gbfs.lyft.com/gbfs/2.3/bay/en"

    /// GBFS root URL (without trailing slash).
    @Published var gbfsRoot: String {
        didSet {
            let trimmed = gbfsRoot.hasSuffix("/") ? String(gbfsRoot.dropLast()) : gbfsRoot
            if trimmed != gbfsRoot { gbfsRoot = trimmed }
            defaults.set(gbfsRoot, forKey: Keys.gbfsRoot)
        }
    }

    /// Range in meters for nearby mode.
    @Published var range: Double {
        didSet {
            defaults.set(range, forKey: Keys.range)
        }
    }

    /// Set of favorite station IDs.
    @Published var favorites: Set<String> {
        didSet {
            defaults.set(Array(favorites), forKey: Keys.favorites)
        }
    }

    /// Ordered list of favorite station IDs.
    @Published var favoriteOrder: [String] {
        didSet {
            defaults.set(favoriteOrder, forKey: Keys.favoriteOrder)
        }
    }

    static let rangeOptions: [Double] = [200, 500, 750, 1000, 1500, 2000]

    private init() {
        let modeStr = defaults.string(forKey: Keys.mode) ?? AppMode.nearby.rawValue
        self.mode = AppMode(rawValue: modeStr) ?? .nearby
        self.showStatusIcon = defaults.object(forKey: Keys.showStatusIcon) as? Bool ?? true
        self.gbfsRoot = defaults.string(forKey: Keys.gbfsRoot) ?? Preferences.defaultGBFSRoot
        self.range = defaults.double(forKey: Keys.range).nonZero ?? 500
        self.favorites = Set(defaults.stringArray(forKey: Keys.favorites) ?? [])
        self.favoriteOrder = defaults.stringArray(forKey: Keys.favoriteOrder) ?? []
    }

    func toggleFavorite(_ stationId: String) {
        if favorites.contains(stationId) {
            favorites.remove(stationId)
            favoriteOrder.removeAll { $0 == stationId }
        } else {
            favorites.insert(stationId)
            favoriteOrder.append(stationId)
        }
    }

    func isFavorite(_ stationId: String) -> Bool {
        favorites.contains(stationId)
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
