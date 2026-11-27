import SwiftUI
import CoreLocation

/// The popover for choosing the "from" station, the same wherever it opens: the Trains
/// title, the station button beside the tab bar, and Settings. With location access it
/// offers the nearest station; without, the choice made here is remembered. The star on
/// each station makes it a favorite stop without closing the menu.
struct StationMenu: View {
    @Binding var isShowing: Bool

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    private var hasLocation: Bool {
        location.authorization == .authorizedAlways || location.authorization == .authorizedWhenInUse
    }

    private var followsNearest: Bool {
        model.manualStation == nil && model.visitingStation == nil
    }

    private var current: Station {
        model.station(nearest: location.station)
    }

    /// Changing the station also changes the widget, so the first time it is explained.
    private func choose(_ station: Station?) {
        isShowing = false
        let name = station?.name ?? "the nearest station"
        model.ask(Guide(
            id: "change-station",
            title: "Start from \(name)?",
            points: [
                "The Trains tab and the lock screen widget will both show trains from \(name).",
                station == nil ? "The station follows your location from now on." : "It stays on this station until you choose another or go back to Nearest.",
            ],
            confirm: "Change"
        ) { model.chooseStation(station) })
    }

    var body: some View {
        PopoverMenu {
            // Following your location and picking a station are two different things,
            // so each has its own section.
            if hasLocation {
                PopoverSectionTitle(title: "Nearest to you")
                PopoverRadioRow(title: location.station?.name ?? "Nearest station", detail: "Follows you", isOn: followsNearest) {
                    choose(nil)
                }
                .accessibilityIdentifier("station-nearest")
                Divider().padding(.vertical, Theme.Spacing.xs)
            } else if location.authorization == .notDetermined {
                PopoverSectionTitle(title: "Nearest to you")
                PopoverActionRow(title: "Use my location", symbol: "location") {
                    isShowing = false
                    location.requestPermission()
                }
                Divider().padding(.vertical, Theme.Spacing.xs)
            }
            PopoverSectionTitle(title: hasLocation ? "Always from" : "From")
            ForEach(Station.allCases) { station in
                // The station in use is marked, whether it was picked or is the nearest.
                // The star makes it a favorite stop, with its own column of arrival times.
                // It is its own button: the menu stays open and the station is not changed.
                let isFavorite = model.favoriteStops.contains(station)
                PopoverRadioRow(title: station.name, isOn: station == current,
                                accessory: PopoverAccessory(symbol: isFavorite ? "star.fill" : "star", isOn: isFavorite,
                                                            label: isFavorite ? "Remove \(station.name) from favorite stops" : "Add \(station.name) to favorite stops",
                                                            identifier: "star-\(station.rawValue)") {
                    model.toggleFavorite(station)
                }, identifier: "station-\(station.rawValue)") {
                    choose(station)
                }
            }
            if !model.favoriteStops.isEmpty {
                Divider().padding(.vertical, Theme.Spacing.xs)
                PopoverActionRow(title: "Clear favorite stops", symbol: "star.slash", isDestructive: true) {
                    isShowing = false
                    model.clearFavorites()
                }
                .accessibilityIdentifier("menuClearFavorites")
            }
        }
    }
}
