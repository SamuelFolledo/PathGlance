import SwiftUI

/// A check row per station. Each checked stop gets an arrival-time column in the train list.
struct FavoriteStopsView: View {
    @EnvironmentObject private var model: AppModel
    /// For UI tests: the list is on the Trains tab's sheet and on the Widget tab.
    var idPrefix = "favorite"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Station.allCases) { station in
                CheckRow(isOn: model.favoriteStops.contains(station)) {
                    model.toggleFavorite(station)
                } label: {
                    Text(station.name)
                }
                .infoPopover(station.name,
                             "Checked: \(station.name) gets a column of arrival times in the train list.",
                             "It only shows when trains to the chosen destination call there on the way.")
                .accessibilityIdentifier("\(idPrefix)-\(station.rawValue)")
            }
            if !model.favoriteStops.isEmpty {
                Button("Clear all", role: .destructive) {
                    model.clearFavorites()
                }
                .padding(.vertical, Theme.Spacing.md)
                .accessibilityIdentifier(idPrefix == "favorite" ? "clearFavorites" : "\(idPrefix)-clear")
            }
        }
    }
}

/// A check row per kind of issue. A checked kind is muted: still listed in the Issues tab,
/// but not counted on its badge and not shown on the widget.
struct MutedKindRows: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ForEach(IssueKind.allCases, id: \.self) { kind in
            CheckRow(isOn: model.mutedKinds.contains(kind)) {
                model.setMuted(kind, !model.mutedKinds.contains(kind))
            } label: {
                Label(kind.pluralTitle, systemImage: kind.symbolName)
            }
            .infoPopover("Mute \(kind.pluralTitle.lowercased())",
                         "Checked: these stay in the Issues tab but leave its badge and the lock screen widget.",
                         kind == .delay ? "Muting delays also hides the ? and ! marks." : "Elevator notices start out muted.")
            .accessibilityIdentifier("mute-\(kind.rawValue)")
        }
    }
}
