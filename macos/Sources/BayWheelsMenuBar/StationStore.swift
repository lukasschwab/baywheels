import Foundation
import CoreLocation
import Combine

/// Combines GBFS data, location, and preferences into the display list.
@MainActor
class StationStore: ObservableObject {
    static let shared = StationStore()

    @Published var displayStations: [DisplayStation] = []
    @Published var totalEbikes: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private let gbfs = GBFSService.shared
    private let location = LocationService.shared
    private let prefs = Preferences.shared

    private init() {
        // React to changes in data, location, or preferences.
        Publishers.CombineLatest4(
            gbfs.$stationInfos,
            gbfs.$stationStatuses,
            location.$location,
            prefs.$mode
        )
        .combineLatest(prefs.$range, prefs.$favoriteOrder)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] combined in
            let ((infos, statuses, loc, mode), range, favoriteOrder) = combined
            self?.update(infos: infos, statuses: statuses, location: loc,
                        mode: mode, range: range, favoriteOrder: favoriteOrder)
        }
        .store(in: &cancellables)
    }

    private func update(
        infos: [String: StationInfo],
        statuses: [String: StationStatus],
        location: CLLocation?,
        mode: AppMode,
        range: Double,
        favoriteOrder: [String]
    ) {
        var stations: [DisplayStation] = []

        switch mode {
        case .nearby:
            guard let userLocation = location else {
                displayStations = []
                totalEbikes = 0
                return
            }

            for (id, info) in infos {
                guard let status = statuses[id] else { continue }
                guard status.is_installed == true, status.is_renting == true else { continue }

                let dist = userLocation.distance(from: info.location)
                if dist <= range {
                    stations.append(DisplayStation(info: info, status: status, distance: dist))
                }
            }
            stations.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }

        case .favorites:
            for id in favoriteOrder {
                guard let info = infos[id], let status = statuses[id] else { continue }
                let dist = location.map { $0.distance(from: info.location) }
                stations.append(DisplayStation(info: info, status: status, distance: dist))
            }
        }

        self.displayStations = stations
        self.totalEbikes = stations.reduce(0) { $0 + $1.ebikes }
    }
}
