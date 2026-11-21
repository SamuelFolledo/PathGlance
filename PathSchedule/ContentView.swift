import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var showingFileImporter = false

    private var station: Station {
        model.manualStation ?? location.station ?? .journalSquare
    }

    var body: some View {
        NavigationStack {
            List {
                previewSection
                stationSection
                scheduleSection
                optionsSection
            }
            .navigationTitle("PathSchedule")
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.zip]) { result in
                if case .success(let url) = result {
                    Task { await model.importSchedule(fromFile: url) }
                }
            }
        }
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                BoardPreview(station: station, schedule: model.schedule, date: context.date)
            }
        } header: {
            Text("Lock screen preview")
        } footer: {
            Text("Add it from the lock screen: touch and hold, Customize, Lock Screen, then pick PathSchedule in the widget row.")
        }
    }

    private var stationSection: some View {
        Section("Station") {
            Picker("Show trains from", selection: $model.manualStation) {
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
        }
    }

    private var scheduleSection: some View {
        Section {
            if let schedule = model.schedule {
                LabeledContent("Updated", value: schedule.importedAt.formatted(date: .abbreviated, time: .shortened))
                if schedule.isExpired() {
                    Label("This timetable has passed its end date. Times follow its regular weekly pattern until PATH publishes a new one.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
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
            Button("Import GTFS zip from Files") {
                showingFileImporter = true
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
            Text("Downloaded from PATH's published timetable and refreshed weekly when you open the app.")
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("Adjust with real-time arrivals", isOn: $model.useRealtime)
        } footer: {
            Text("Replaces the first time or two on each line with the Port Authority's live prediction when the widget refreshes.")
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

/// The same three lines the lock screen widget draws.
private struct BoardPreview: View {
    let station: Station
    let schedule: ScheduleData?
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("From \(station.shortName): \(CompactTimes.clock(date))")
                .fontWeight(.semibold)
            if let schedule {
                let board = BoardPlan(station: station, schedule: schedule, now: date).board(at: date)
                if board.lines.isEmpty {
                    Text("No upcoming trains")
                }
                ForEach(board.lines, id: \.self) { line in
                    Text(line.label.isEmpty ? line.timesText : "\(line.label) \(line.timesText)")
                }
            } else {
                Text("Download the schedule below")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.subheadline, design: .monospaced))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
        .environmentObject(LocationService.shared)
}
