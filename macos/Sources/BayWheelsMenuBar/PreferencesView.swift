import SwiftUI

struct PreferencesView: View {
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var gbfs = GBFSService.shared
    @State private var searchText = ""

    private var sortedStations: [StationInfo] {
        let all = Array(gbfs.stationInfos.values).sorted { $0.name < $1.name }
        if searchText.isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode picker
            Picker("Mode", selection: $prefs.mode) {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if prefs.mode == .nearby {
                nearbySettings
            } else {
                favoritesSettings
            }
        }
        .frame(width: 360, height: 480)
    }

    private var nearbySettings: some View {
        VStack(spacing: 16) {
            Text("Range: \(Int(prefs.range))m")
                .font(.headline)

            Picker("Range", selection: $prefs.range) {
                ForEach(Preferences.rangeOptions, id: \.self) { r in
                    Text("\(Int(r))m").tag(r)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Shows stations within \(Int(prefs.range))m of your current location.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

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
