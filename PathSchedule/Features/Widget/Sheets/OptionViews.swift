import SwiftUI

/// A check row per destination. Turning one off removes it from the widget and from the
/// destination tabs; a station left with one line gives it both widget rows.
struct LinesShownRows: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ForEach(BoardRules.terminals) { station in
            CheckRow(isOn: !model.hiddenTargets.contains(station)) {
                if model.hiddenTargets.contains(station) {
                    model.setTarget(station, shown: true)
                } else {
                    // Hiding a line changes the widget and the tabs, so it is explained first.
                    model.ask(Guide(
                        id: "hide-line",
                        title: "Hide trains to \(station.name)?",
                        points: [
                            "They leave the lock screen widget and the destination tabs.",
                            "A station left with one line gives it both widget rows, with more times.",
                            "A station whose only line this is still shows it.",
                        ],
                        confirm: "Hide"
                    ) { model.setTarget(station, shown: false) })
                }
            } label: {
                Text("Trains to \(station.name)")
            }
            .infoPopover("Trains to \(station.name)",
                         "Off: these trains leave the widget and the destination tabs.",
                         "If a station is left with one line, that line gets both widget rows and shows more times.",
                         "A station whose only line is turned off still shows it.")
            .accessibilityIdentifier("line-\(station.rawValue)")
        }
    }
}

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
                    model.ask(Guide(
                        id: "clear-favorites",
                        title: "Clear all favorite stops?",
                        points: [
                            "The train list goes back to two columns: your station and the destination.",
                            "You can pick favorites again at any time.",
                        ],
                        confirm: "Clear",
                        isDestructive: true
                    ) {
                        model.favoriteStops = []
                        model.hiddenColumns = []
                    })
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
