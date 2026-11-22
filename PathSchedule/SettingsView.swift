import SwiftUI
import CoreLocation

/// Preferences as a plain list of switches and rows. Rows that hold a choice open a sheet.
/// There are no footnotes: press and hold any row for what it does.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable {
        case lockScreen, favorites, lines, muted, timetables, dayTypes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .lockScreen: return "Lock screen widget"
            case .favorites: return "Favorite stops"
            case .lines: return "Lines shown"
            case .muted: return "Muted issues"
            case .timetables: return "Timetables"
            case .dayTypes: return "Learned day types"
            }
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            List {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 0, trailing: 4))
                    .accessibilityAddTraits(.isHeader)
                    .id("top")
                Section {
                    WidgetPreviewCard { sheet = .lockScreen }
                        .infoPopover("Lock screen preview",
                                     "This is what the widget shows right now.",
                                     "Tap it to change its look.",
                                     "A change is pointed out: green for what is added, red for what goes.",
                                     "A ? after a line means a short delay, ! a long one.")
                    row("Widget options", value: "\(model.fontStyle.name), \(model.widgetStyle.density.name)", opens: .lockScreen)
                        .infoPopover("Widget options", "Font, size, how times are written, which lines show and the extras.")
                    Toggle("Real-time arrivals", isOn: $model.useRealtime)
                        .infoPopover("Real-time arrivals", "The first time or two on each line is replaced with PATH's live prediction.", "Later times stay as scheduled.")
                    Toggle("Arrival time of next train", isOn: $model.widgetStyle.showArrival)
                        .infoPopover("Arrival time", "Adds when the first train on each line reaches its destination.", "Shown as 7:16→7:35.")
                    row("Muted issues", value: model.mutedKinds.isEmpty ? "None" : model.mutedKinds.map(\.title).sorted().joined(separator: ", "), opens: .muted)
                        .infoPopover("Muted issues", "Kinds of issue that stay in the Issues tab but leave its badge and the widget.", "Elevator notices start out muted.")
                } header: {
                    Text("Lock screen")
                }

                Section("Trains") {
                    row("Favorite stops", value: model.favoriteStops.isEmpty ? "None" : model.favoriteStops.map(\.shortName).joined(separator: ", "), opens: .favorites)
                        .infoPopover("Favorite stops", "Each favorite gets a column of arrival times in the train list.", "A stop only shows when trains to the chosen destination call there.")
                    row("Lines shown", value: model.hiddenTargets.isEmpty ? "All" : "\(BoardRules.terminals.count - model.hiddenTargets.count) of \(BoardRules.terminals.count)", opens: .lines)
                        .infoPopover("Lines shown", "Turn off destinations you never use.", "They leave the widget and the destination tabs.")
                }

                Section("Station") {
                    Picker("From", selection: $model.manualStation) {
                        Text("Nearest station").tag(Station?.none)
                        ForEach(Station.allCases) { station in
                            Text(station.name).tag(Station?.some(station))
                        }
                    }
                    .infoPopover("From", "The station the widget and the Trains tab start from.", "Nearest follows your location.")
                    if model.manualStation == nil {
                        LabeledContent("Detected", value: location.station?.name ?? "Unknown")
                        LabeledContent("Location access", value: authorizationText)
                            .infoPopover("Location access", "While using: the station updates when the app or widget refreshes.", "Always: the station also updates in the background as you reach a station.")
                        if location.authorization == .notDetermined || location.authorization == .authorizedWhenInUse {
                            Button(location.authorization == .notDetermined ? "Allow location" : "Allow in background (Always)") {
                                location.requestPermission()
                            }
                        }
                    }
                }

                Section("Schedule") {
                    if let schedule = model.schedule {
                        LabeledContent("Checked", value: schedule.importedAt.formatted(date: .abbreviated, time: .shortened))
                        if let version = schedule.feedVersion {
                            LabeledContent("Timetable", value: version)
                        }
                    } else {
                        Text("No schedule downloaded yet.")
                    }
                    Button {
                        Task { await model.downloadSchedule() }
                    } label: {
                        HStack {
                            Text("Update schedule now")
                            if model.isImporting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.isImporting)
                    .infoPopover("Schedule", "Read from the timetables on PATH's website.", "Checked about once a day, in the background and when you open the app.", "If a check fails, the last good timetable stays in use.")
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Text size") {
                    HStack(spacing: 12) {
                        Text("A")
                            .font(.system(size: 13))
                            .accessibilityHidden(true)
                        Slider(value: Binding(get: { Double(model.textSizeStep) }, set: { model.textSizeStep = Int($0.rounded()) }),
                               in: 0...Double(AppModel.textSizes.count - 1), step: 1)
                            .accessibilityLabel("Text size")
                            .accessibilityValue("Step \(model.textSizeStep + 1) of \(AppModel.textSizes.count)")
                            .accessibilityIdentifier("textSizeSlider")
                        Text("A")
                            .font(.system(size: 24))
                            .accessibilityHidden(true)
                    }
                    .infoPopover("Text size", "Sets the size of text throughout the app.", "The lock screen widget has its own Size option.")
                }

                Section("Archive") {
                    row("Timetables", value: "", opens: .timetables)
                        .infoPopover("Timetables", "Every distinct timetable the app has downloaded.")
                    row("Learned day types", value: "", opens: .dayTypes)
                        .infoPopover("Learned day types", "Which timetable live arrivals matched on each day.", "This is how holidays are recognised.")
                }

                Section {
                    Button("Restore defaults", role: .destructive) {
                        // Always asks: it cannot be undone.
                        model.ask(Guide(
                            id: "restore-defaults",
                            title: "Restore defaults?",
                            points: [
                                "Every setting goes back to how a fresh install has it: station, widget options, favorite stops, lines shown, muted issues and text size.",
                                "Explanations you ticked \"Don't show this again\" on will show again.",
                                "The timetable, the issue history and what the app has learned about holidays are kept.",
                            ],
                            confirm: "Restore",
                            isDestructive: true,
                            canBeSilenced: false
                        ) { model.restoreDefaults() })
                    }
                    .accessibilityIdentifier("restoreDefaults")
                }
            }
            .onChange(of: model.resetCount[.settings]) {
                sheet = nil
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .appSheet(item: $sheet, title: \.title) { sheet in
            switch sheet {
            case .lockScreen: LockScreenOptionsView()
            case .favorites: FavoriteStopsView()
            case .lines: VStack(alignment: .leading, spacing: 0) { LinesShownRows() }
            case .muted: VStack(alignment: .leading, spacing: 0) { MutedKindRows() }
            case .timetables: TimetableArchiveView()
            case .dayTypes: DayTypeLogView()
            }
        }
    }

    private func row(_ title: String, value: String, opens target: Sheet) -> some View {
        OpenRow(title: title, value: value) { sheet = target }
            .accessibilityIdentifier("settings-\(target.rawValue)")
    }

    private var authorizationText: String {
        switch location.authorization {
        case .notDetermined: return "Not asked"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "While using"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
}
