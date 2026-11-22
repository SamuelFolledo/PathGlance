import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    private var station: Station {
        model.manualStation ?? location.station ?? .journalSquare
    }

    var body: some View {
        NavigationStack {
            List {
                previewSection
                issuesSection
                stationSection
                scheduleSection
                lockScreenSection
                Section {
                    NavigationLink("Archive") {
                        ArchiveView()
                    }
                } footer: {
                    Text("Past issues, every timetable downloaded, and what the app has learned about holiday service.")
                }
            }
            .navigationTitle("PathSchedule")
            .navigationDestination(item: $model.openLine) { route in
                DeparturesView(route: route)
            }
            .refreshable {
                await model.refreshIssues()
            }
        }
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                BoardPreview(station: station, schedule: model.schedule, issues: model.issues.active,
                             includePlannedWork: model.plannedWorkOnLockScreen, date: context.date) { target in
                    model.openLine = LineRoute(origin: station, target: target)
                }
            }
        } header: {
            Text("Lock screen preview")
        } footer: {
            Text("Tap a line for every train until the end of tomorrow. A ? after a line means a short delay, ! a long one. Add the widget from the lock screen: touch and hold, Customize, Lock Screen, then pick PathSchedule.")
        }
    }

    private var issuesSection: some View {
        Section("Current issues") {
            if model.issues.active.isEmpty {
                Label("No issues reported", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.issues.active) { issue in
                IssueRow(issue: issue)
            }
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

    private var lockScreenSection: some View {
        Section {
            Picker("Font", selection: $model.fontStyle) {
                ForEach(WidgetFontStyle.allCases) { style in
                    Text(style.name).tag(style)
                }
            }
            Toggle("Adjust with real-time arrivals", isOn: $model.useRealtime)
            Toggle("Alert mark for planned work", isOn: $model.plannedWorkOnLockScreen)
        } header: {
            Text("Lock screen")
        } footer: {
            Text("Real-time replaces the first time or two on each line with PATH's live prediction. The alert mark appears beside the station name for open PATH alerts; elevator notices never show it.")
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

/// The same three lines the lock screen widget draws, from the timetable and open alerts.
private struct BoardPreview: View {
    let station: Station
    let schedule: ScheduleData?
    let issues: [Issue]
    let includePlannedWork: Bool
    let date: Date
    let open: (Station) -> Void

    private var board: Board? {
        guard let schedule else { return nil }
        var plan = BoardPlan(station: station, schedule: schedule, now: date)
        plan.apply(issues: issues, includePlannedWork: includePlannedWork)
        return plan.board(at: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let board {
                HStack(spacing: 4) {
                    Text("From \(station.shortName): \(CompactTimes.clockWithPeriod(date))")
                    if board.hasAlert {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                if board.lines.isEmpty {
                    Text("No upcoming trains")
                }
                ForEach(board.lines, id: \.self) { line in
                    Button {
                        if let target = line.target { open(target) }
                    } label: {
                        Text(line.text)
                            .foregroundStyle(line.delay == .none ? Color.primary : Color.yellow)
                    }
                    .buttonStyle(.plain)
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
