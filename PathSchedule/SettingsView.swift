import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    var body: some View {
        NavigationStack {
            List {
                LockScreenSettings()
                stationSection
                scheduleSection
                Section {
                    NavigationLink("Timetables") {
                        TimetableArchiveView()
                    }
                    NavigationLink("Learned day types") {
                        DayTypeLogView()
                    }
                } header: {
                    Text("Archive")
                } footer: {
                    Text("Every timetable downloaded, and what live arrivals have shown about holiday service. Past issues are in the Issues tab.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var stationSection: some View {
        Section {
            Picker("From", selection: $model.manualStation) {
                Text("Nearest station").tag(Station?.none)
                ForEach(Station.allCases) { station in
                    Text(station.name).tag(Station?.some(station))
                }
            }
            if model.manualStation == nil {
                LabeledContent("Detected", value: location.station?.name ?? "Unknown")
                LabeledContent("Location access", value: authorizationText)
                if location.authorization == .notDetermined || location.authorization == .authorizedWhenInUse {
                    Button(location.authorization == .notDetermined ? "Allow location" : "Allow in background (Always)") {
                        location.requestPermission()
                    }
                }
            }
        } header: {
            Text("Station")
        } footer: {
            Text("The station the widget and the Trains tab start from.")
        }
    }

    private var scheduleSection: some View {
        Section {
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
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Read from the timetables on PATH's website. Checked about once a day, in the background and whenever you open the app.")
        }
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

/// Everything that changes what the lock screen widget shows. Used in the Settings tab
/// and in the sheet opened from the preview on the Trains tab.
struct LockScreenSettings: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section {
            NavigationLink {
                FontPickerView()
            } label: {
                LabeledContent("Font") {
                    Text(model.fontStyle.name)
                        .font(model.fontStyle.font(size: 17))
                }
            }
            NavigationLink {
                FavoriteTargetsView()
            } label: {
                LabeledContent("Destinations", value: model.favoriteTargets.isEmpty
                               ? "Automatic"
                               : model.favoriteTargets.map(\.lineLabel).joined(separator: ", "))
            }
            Toggle("Show arrival time of next train", isOn: $model.showArrivalOnWidget)
            Toggle("Adjust with real-time arrivals", isOn: $model.useRealtime)
            Toggle("Alert mark for planned work", isOn: $model.plannedWorkOnLockScreen)
        } header: {
            Text("Lock screen")
        } footer: {
            Text("Arrival time adds when the first train on each line reaches its destination, as in 7:16→:35. Real-time replaces the first time or two with PATH's live prediction. The alert mark appears for open PATH alerts; elevator notices never show it.")
        }
    }
}

/// Each font is named in itself, with a sample widget line.
struct FontPickerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            ForEach(WidgetFontStyle.allCases) { style in
                Button {
                    model.fontStyle = style
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.name)
                                .font(style.font(size: 20, weight: .semibold))
                            Text("33rd? 7:16 :30 :50 8:00 :10")
                                .font(style.font(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.fontStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The destinations the widget prefers, in order.
struct FavoriteTargetsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                if model.favoriteTargets.isEmpty {
                    Text("Automatic: each station shows its usual two lines.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.favoriteTargets) { station in
                    Text(station.name)
                }
                .onMove { model.favoriteTargets.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { model.favoriteTargets.remove(atOffsets: $0) }
                Menu {
                    ForEach(Station.allCases.filter { !model.favoriteTargets.contains($0) }) { station in
                        Button(station.name) { model.favoriteTargets.append(station) }
                    }
                } label: {
                    Label("Add destination", systemImage: "plus")
                }
            } footer: {
                Text("The widget lists the first two of these that trains from your current station reach. It can be an end of the line or any stop on the way. Where fewer than two apply, the station's usual lines fill in.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Destinations")
        .navigationBarTitleDisplayMode(.inline)
    }
}
