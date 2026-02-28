import Foundation
import CoreLocation

// MARK: - GBFS API Response Models

struct StationInformationResponse: Codable {
    let data: StationInformationData
}

struct StationInformationData: Codable {
    let stations: [StationInfo]
}

struct StationInfo: Codable, Identifiable {
    let station_id: String
    let name: String
    let lat: Double
    let lon: Double
    let capacity: Int?

    var id: String { station_id }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var location: CLLocation {
        CLLocation(latitude: lat, longitude: lon)
    }
}

struct StationStatusResponse: Codable {
    let data: StationStatusData
}

struct StationStatusData: Codable {
    let stations: [StationStatus]
}

struct StationStatus: Codable {
    let station_id: String
    let num_ebikes_available: Int?
    let num_bikes_available: Int?
    let num_docks_available: Int?
    let is_installed: Bool?
    let is_renting: Bool?

    var ebikes: Int { num_ebikes_available ?? 0 }
    var classicBikes: Int {
        (num_bikes_available ?? 0) - ebikes
    }
    var docks: Int { num_docks_available ?? 0 }
}

// MARK: - App Models

enum AppMode: String, Codable, CaseIterable {
    case nearby = "nearby"
    case favorites = "favorites"

    var label: String {
        switch self {
        case .nearby: return "Nearby"
        case .favorites: return "Favorites"
        }
    }
}

struct DisplayStation: Identifiable {
    let info: StationInfo
    let status: StationStatus
    let distance: CLLocationDistance? // meters

    var id: String { info.station_id }
    var name: String { info.name }
    var ebikes: Int { status.ebikes }
    var classicBikes: Int { status.classicBikes }
    var docks: Int { status.docks }

    var distanceText: String? {
        guard let d = distance else { return nil }
        if d < 1000 {
            return "\(Int(d))m"
        } else {
            return String(format: "%.1fkm", d / 1000)
        }
    }

    var walkTimeText: String? {
        guard let d = distance else { return nil }
        let minutes = Int(ceil(d / 80.0)) // ~80m/min walking speed
        return "~\(minutes) min"
    }

    var mapsURL: URL? {
        let query = "\(info.lat),\(info.lon)"
        return URL(string: "https://maps.apple.com/?ll=\(query)&q=\(info.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
}
