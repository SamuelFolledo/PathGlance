import SwiftUI

/// Everything that changes what the lock screen widget shows, as folding groups of
/// radio and check rows. Shown in a sheet from the Trains tab's preview and from Settings.
/// Press and hold any row for what it does.
struct LockScreenOptionsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoldSection(title: "Font", value: model.fontStyle.name, isOpen: true) {
                ForEach(WidgetFontStyle.allCases) { style in
                    RadioRow(isSelected: model.fontStyle == style) {
                        model.fontStyle = style
                    } label: {
                        // Each font is named in itself, with a sample line.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.name)
                                .font(style.font(size: 17, weight: .semibold))
                            Text("33rd? 7:16, 7:30, 7:50")
                                .font(style.font(size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("font-\(style.rawValue)")
                }
            }
            FoldSection(title: "Size", value: model.widgetStyle.density.name) {
                ForEach(WidgetDensity.allCases) { density in
                    RadioRow(isSelected: model.widgetStyle.density == density) {
                        model.widgetStyle.density = density
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(density.name)
                            Text(density.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            FoldSection(title: "Times", value: model.widgetStyle.timeFormat.name) {
                ForEach(WidgetTimeFormat.allCases) { format in
                    RadioRow(isSelected: model.widgetStyle.timeFormat == format) {
                        model.widgetStyle.timeFormat = format
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.name)
                            Text(format.example)
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .infoPopover(format.name,
                                 format == .full ? "Every time is written out." : "The hour is dropped when it repeats, which fits one more train on each line.")
                }
            }
            FoldSection(title: "Trains per line", value: model.widgetStyle.maxTimes >= Board.mostPerLine ? "As many as fit" : "Up to \(model.widgetStyle.maxTimes)") {
                Stepper(value: $model.widgetStyle.maxTimes, in: 1...Board.mostPerLine) {
                    Text(model.widgetStyle.maxTimes >= Board.mostPerLine ? "As many as fit" : "Up to \(model.widgetStyle.maxTimes)")
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Divider() }
                .accessibilityIdentifier("maxTimesStepper")
                .infoPopover("Trains per line",
                             "The most train times a line shows.",
                             "Fewer show when fewer fit: the text is never shrunk to squeeze more in.",
                             "A station with one line fills both rows with as many as fit, whatever this is set to.")
            }
            FoldSection(title: "Lines shown", value: linesSummary) {
                LinesShownRows()
            }
            FoldSection(title: "Extras", value: "") {
                CheckRow(isOn: model.widgetStyle.showArrival) {
                    model.widgetStyle.showArrival.toggle()
                } label: {
                    Text("Arrival time of the next train")
                }
                .infoPopover("Arrival time", "Adds when the first train on each line reaches its destination.", "Shown as 7:16→7:35.")
                CheckRow(isOn: model.useRealtime) {
                    model.useRealtime.toggle()
                } label: {
                    Text("Adjust with real-time arrivals")
                }
                .infoPopover("Real-time arrivals", "The first time or two on each line is replaced with PATH's live prediction.", "Later times stay as scheduled.", "The widget refreshes every 20 minutes with this on, every 60 without.")
            }
            FoldSection(title: "Muted issues", value: model.mutedKinds.isEmpty ? "None" : "\(model.mutedKinds.count)") {
                MutedKindRows()
            }
        }
    }

    private var linesSummary: String {
        model.hiddenTargets.isEmpty ? "All" : "\(BoardRules.terminals.count - model.hiddenTargets.count) of \(BoardRules.terminals.count)"
    }
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Station.allCases) { station in
                CheckRow(isOn: model.favoriteStops.contains(station)) {
                    model.toggleFavorite(station)
                } label: {
                    Text(station.name)
                }
                .accessibilityIdentifier("favorite-\(station.rawValue)")
            }
        }
        .infoPopover("Favorite stops",
                     "Each favorite gets a column of arrival times in the train list.",
                     "A stop only shows when trains to the chosen destination call there on the way.",
                     "The destination itself always has a column.")
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
