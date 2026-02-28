import SwiftUI
import AppKit
import MapKit

struct StationMapView: NSViewRepresentable {
    var userLocation: CLLocationCoordinate2D?
    var radius: Double
    var stations: [StationInfo]
    var statuses: [String: StationStatus]
    var showCounts: Bool = true

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
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

        // Station annotations within visible area (3x radius).
        let userLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let showRadius = radius * 3

        for station in stations {
            let dist = userLoc.distance(from: station.location)
            guard dist <= showRadius else { continue }

            let ebikes = statuses[station.station_id]?.ebikes ?? 0
            let annotation = StationAnnotation(
                coordinate: station.coordinate,
                title: station.name,
                ebikes: ebikes,
                inRange: dist <= radius,
                showCount: showCounts
            )
            map.addAnnotation(annotation)
        }

        // Fit map to show the radius circle with padding.
        let viewRadius = max(radius * 1.8, 300)
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: viewRadius * 2,
            longitudinalMeters: viewRadius * 2
        )
        map.setRegion(region, animated: context.coordinator.hasSetRegion)
        context.coordinator.hasSetRegion = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var hasSetRegion = false

        private let radiusFillColor = NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.08)
        private let radiusStrokeColor = NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.5)

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
            view.canShowCallout = true

            // Draw station marker.
            let size: CGFloat = station.showCount
                ? (station.inRange ? 28 : 22)
                : (station.inRange ? 10 : 7)
            let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                if station.showCount {
                    // Full marker with eBike count.
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
                } else {
                    // Simple dot.
                    let color: NSColor = station.inRange
                        ? NSColor(red: 0.3, green: 0.6, blue: 0.35, alpha: 1)
                        : NSColor(red: 0.28, green: 0.24, blue: 0.55, alpha: 0.5)
                    color.setFill()
                    NSBezierPath(ovalIn: rect).fill()
                }
                return true
            }

            view.image = image
            view.frame.size = NSSize(width: size, height: size)
            return view
        }
    }
}

// MARK: - Station Annotation

class StationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let ebikes: Int
    let inRange: Bool
    let showCount: Bool

    init(coordinate: CLLocationCoordinate2D, title: String, ebikes: Int, inRange: Bool, showCount: Bool = true) {
        self.coordinate = coordinate
        self.title = title
        self.ebikes = ebikes
        self.inRange = inRange
        self.showCount = showCount
    }
}
