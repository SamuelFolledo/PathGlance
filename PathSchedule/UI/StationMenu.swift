import SwiftUI
import CoreLocation

/// The list for choosing the "from" station, shared by the Trains title and the station
/// button beside the tab bar. With location access it offers the nearest station; without,
/// the choice made here is remembered. Also the way in to favorite stops.
struct StationMenu<MenuLabel: View>: View {
    let onEditFavorites: () -> Void
    @ViewBuilder let label: MenuLabel

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    private var hasLocation: Bool {
        location.authorization == .authorizedAlways || location.authorization == .authorizedWhenInUse
    }

    private var current: Station {
        model.station(nearest: location.station)
    }

    var body: some View {
        Menu {
            if hasLocation {
                Button {
                    model.chooseStation(nil)
                } label: {
                    Label("Nearest" + (location.station.map { " (\($0.name))" } ?? ""),
                          systemImage: model.manualStation == nil && model.visitingStation == nil ? "location.fill" : "location")
                }
            } else if location.authorization == .notDetermined {
                Button {
                    location.requestPermission()
                } label: {
                    Label("Use my location", systemImage: "location")
                }
            }
            Divider()
            ForEach(Station.allCases) { station in
                Button {
                    model.chooseStation(station)
                } label: {
                    // The station in use is ticked, whether it was picked or is the nearest.
                    if station == current {
                        Label(station.name, systemImage: "checkmark")
                    } else {
                        Text(station.name)
                    }
                }
            }
            Divider()
            Button(action: onEditFavorites) {
                Label("Favorite stops", systemImage: model.favoriteStops.isEmpty ? "star" : "star.fill")
            }
        } label: {
            label
        }
    }
}
