import Foundation

@MainActor
class GBFSService: ObservableObject {
    static let shared = GBFSService()

    private var stationInfoURL: URL {
        URL(string: "\(Preferences.shared.gbfsRoot)/station_information.json")!
    }
    private var stationStatusURL: URL {
        URL(string: "\(Preferences.shared.gbfsRoot)/station_status.json")!
    }

    @Published var stationInfos: [String: StationInfo] = [:]
    @Published var stationStatuses: [String: StationStatus] = [:]
    @Published var lastUpdated: Date?
    @Published var error: String?

    private var timer: Timer?
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func startPolling(interval: TimeInterval = 30) {
        fetch()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetch()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func fetch() {
        Task {
            do {
                async let infoData = session.data(from: stationInfoURL)
                async let statusData = session.data(from: stationStatusURL)

                let (infoResult, statusResult) = try await (infoData, statusData)

                let decoder = JSONDecoder()
                let infoResponse = try decoder.decode(StationInformationResponse.self, from: infoResult.0)
                let statusResponse = try decoder.decode(StationStatusResponse.self, from: statusResult.0)

                var infos: [String: StationInfo] = [:]
                for station in infoResponse.data.stations {
                    infos[station.station_id] = station
                }

                var statuses: [String: StationStatus] = [:]
                for status in statusResponse.data.stations {
                    statuses[status.station_id] = status
                }

                self.stationInfos = infos
                self.stationStatuses = statuses
                self.lastUpdated = Date()
                self.error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
