import SwiftUI
import AppKit
import MapKit

struct StationMapView: NSViewRepresentable {
    var userLocation: CLLocationCoordinate2D?
    var radius: Double
    var stations: [StationInfo]
    var statuses: [String: StationStatus]
    var favorites: Set<String> = []
    var showCounts: Bool = true

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.isZoomEnabled = false
        return map
    }

    /// Build a snapshot of the inputs that affect the map, for diffing.
    private func mapSnapshot() -> MapSnapshot {
        MapSnapshot(
            lat: userLocation?.latitude,
            lon: userLocation?.longitude,
            radius: radius,
            stationIDs: Set(stations.map(\.station_id)),
            ebikeCounts: Dictionary(uniqueKeysWithValues: stations.map {
                ($0.station_id, statuses[$0.station_id]?.ebikes ?? 0)
            }),
            favorites: favorites,
            showCounts: showCounts
        )
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        let snapshot = mapSnapshot()
        guard snapshot != context.coordinator.lastSnapshot else { return }
        context.coordinator.lastSnapshot = snapshot

        // Remove old overlays and annotations (keep user location).
        map.removeOverlays(map.overlays)
        let oldAnnotations = map.annotations.filter { !($0 is MKUserLocation) }
        map.removeAnnotations(oldAnnotations)

        guard let center = userLocation else {
            // Default to SF Bay Area.
            let sfRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
                latitudinalMeters: 8000, longitudinalMeters: 8000
            )
            map.setRegion(sfRegion, animated: false)
            return
        }

        // Radius circle.
        let circle = MKCircle(center: center, radius: radius)
        map.addOverlay(circle)

        // Station annotations.
        let userLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)

        for station in stations {
            let dist = userLoc.distance(from: station.location)
            let ebikes = statuses[station.station_id]?.ebikes ?? 0
            let annotation = StationAnnotation(
                coordinate: station.coordinate,
                title: station.name,
                ebikes: ebikes,
                inRange: dist <= radius,
                isFavorite: favorites.contains(station.station_id),
                showCount: showCounts
            )
            map.addAnnotation(annotation)
        }

        // Set region only on first render; let the user pan/zoom freely after.
        if !context.coordinator.hasSetRegion {
            let viewRadius = max(radius * 1.8, 300)
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: viewRadius * 2,
                longitudinalMeters: viewRadius * 2
            )
            map.setRegion(region, animated: false)
            context.coordinator.hasSetRegion = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetRegion = false
        var lastSnapshot: MapSnapshot?

        private let radiusFillColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.55, green: 0.5, blue: 0.85, alpha: 0.12)
                : NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.08)
        }
        private let radiusStrokeColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.6, green: 0.55, blue: 0.9, alpha: 0.6)
                : NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.5)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = radiusFillColor
                renderer.strokeColor = radiusStrokeColor
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let station = annotation as? StationAnnotation else { return nil }

            let id = "station"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)

            view.annotation = annotation
            view.canShowCallout = false
            view.toolTip = station.title

            if station.isFavorite {
                // Yellow star for favorites.
                let size: CGFloat = 14
                let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
                    let inset = rect.insetBy(dx: 1, dy: 1)
                    let star = starPath(in: inset)
                    NSColor.systemYellow.setFill()
                    star.fill()
                    NSColor.black.withAlphaComponent(0.6).setStroke()
                    star.lineWidth = 1
                    star.stroke()
                    return true
                }
                view.image = image
                view.frame.size = NSSize(width: size, height: size)
            } else if station.showCount {
                // Full marker with eBike count.
                let size: CGFloat = station.inRange ? 28 : 22
                let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                    let bgColor: NSColor = station.inRange
                        ? NSColor(red: 0.3, green: 0.6, blue: 0.35, alpha: 1)
                        : NSColor.clear
                    let textColor: NSColor = station.inRange
                        ? .white
                        : NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 1)

                    if station.inRange {
                        bgColor.setFill()
                        NSBezierPath(ovalIn: rect).fill()
                    }

                    let text = "\(station.ebikes)" as NSString
                    let fontSize: CGFloat = station.inRange ? 13 : 11
                    let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: textColor
                    ]
                    let textSize = text.size(withAttributes: attrs)
                    let textRect = CGRect(
                        x: (rect.width - textSize.width) / 2,
                        y: (rect.height - textSize.height) / 2,
                        width: textSize.width,
                        height: textSize.height
                    )
                    text.draw(in: textRect, withAttributes: attrs)
                    return true
                }
                view.image = image
                view.frame.size = NSSize(width: size, height: size)
            } else {
                // Simple dot.
                let size: CGFloat = station.inRange ? 10 : 7
                let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                    let color: NSColor = station.inRange
                        ? NSColor(red: 0.3, green: 0.6, blue: 0.35, alpha: 1)
                        : NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.5)
                    color.setFill()
                    NSBezierPath(ovalIn: rect).fill()
                    return true
                }
                view.image = image
                view.frame.size = NSSize(width: size, height: size)
            }

            return view
        }
    }
}

// MARK: - Map Snapshot (for diffing)

struct MapSnapshot: Equatable {
    let lat: Double?
    let lon: Double?
    let radius: Double
    let stationIDs: Set<String>
    let ebikeCounts: [String: Int]
    let favorites: Set<String>
    let showCounts: Bool
}

// MARK: - Station Annotation

class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let ebikes: Int
    let inRange: Bool
    let isFavorite: Bool
    let showCount: Bool

    init(coordinate: CLLocationCoordinate2D, title: String, ebikes: Int, inRange: Bool, isFavorite: Bool = false, showCount: Bool = true) {
        self.coordinate = coordinate
        self.title = title
        self.ebikes = ebikes
        self.inRange = inRange
        self.isFavorite = isFavorite
        self.showCount = showCount
    }
}

// MARK: - Star Path

private func starPath(in rect: CGRect) -> NSBezierPath {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let outerRadius = min(rect.width, rect.height) / 2
    let innerRadius = outerRadius * 0.4
    let points = 5
    let path = NSBezierPath()

    for i in 0..<(points * 2) {
        let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
        // Start from top (-90°), go clockwise.
        let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
        let point = CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
        if i == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }
    path.close()
    return path
}
