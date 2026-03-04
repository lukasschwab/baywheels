import SwiftUI
import MapKit

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var gbfs = GBFSService.shared
    @ObservedObject var locationService = LocationService.shared
    @State private var searchText = ""

    private var sortedStations: [StationInfo] {
        let all = Array(gbfs.stationInfos.values).sorted { $0.name < $1.name }
        if searchText.isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle + status icon checkbox
            modeToggle
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Nearby settings
            nearbySettings

            Divider()

            // Favorites
            favoritesSettings

            Divider()

            // GBFS feed URL
            gbfsSettings
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 380, height: 660)
    }

    // MARK: - Mode Picker

    private var modeToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu Bar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            radioButton(
                "Show eBike count within range",
                mode: .nearby
            )
            radioButton(
                "Show eBike count at favorite stations",
                mode: .favorites
            )
            Toggle("Include bicycle icon", isOn: $prefs.showStatusIcon)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func radioButton(_ label: String, mode: AppMode) -> some View {
        Button {
            prefs.mode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: prefs.mode == mode ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(prefs.mode == mode ? Color.accentColor : Color.secondary)
                    .font(.system(size: 14))
                Text(label)
                    .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nearby Settings

    private var nearbySettings: some View {
        VStack(spacing: 8) {
            // Map
            StationMapView(
                userLocation: locationService.location?.coordinate,
                radius: prefs.range,
                stations: Array(gbfs.stationInfos.values),
                statuses: gbfs.stationStatuses,
                favorites: prefs.favorites,
                showCounts: false
            )
            .frame(height: 180)
            .cornerRadius(6)
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 12))

            // Slider
            VStack(spacing: 4) {
                HStack {
                    Text("Range")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(prefs.range))m")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $prefs.range,
                    in: 100...2000,
                    step: 50
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Favorites Settings

    private var favoritesSettings: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search stations...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Selected favorites (ordered)
            if !prefs.favoriteOrder.isEmpty && searchText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Favorites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(prefs.favoriteOrder, id: \.self) { id in
                        if let info = gbfs.stationInfos[id] {
                            stationRow(info, isFavorite: true)
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // All stations list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedStations) { station in
                        stationRow(station, isFavorite: prefs.isFavorite(station.station_id))
                    }
                }
            }
        }
    }

    // MARK: - GBFS Settings

    private var gbfsSettings: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("GBFS Feed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if prefs.gbfsRoot != Preferences.defaultGBFSRoot {
                    Button("Reset") {
                        prefs.gbfsRoot = Preferences.defaultGBFSRoot
                    }
                    .font(.caption)
                }
            }
            TextField(Preferences.defaultGBFSRoot, text: $prefs.gbfsRoot)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
        }
    }

    private func stationRow(_ station: StationInfo, isFavorite: Bool) -> some View {
        Button {
            prefs.toggleFavorite(station.station_id)
        } label: {
            HStack {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .frame(width: 20)
                Text(station.name)
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(isFavorite ? Color.accentColor.opacity(0.08) : .clear)
    }
}
