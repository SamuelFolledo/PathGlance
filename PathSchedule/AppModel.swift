import Foundation
import Combine
import WidgetKit
import BackgroundTasks

/// A list of trains opened from a widget line or the in-app preview.
struct LineRoute: Hashable, Identifiable {
    var origin: Station
    var target: Station

    var id: String { "\(origin.rawValue)-\(target.rawValue)" }
}

@MainActor
final class AppModel: ObservableObject {
    nonisolated static let refreshTaskID = "com.samuelfolledo.PathSchedule.refresh"

    @Published private(set) var schedule: ScheduleData?
    @Published private(set) var issues = IssueLog()
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?
    @Published var openLine: LineRoute?

    @Published var manualStation: Station? {
        didSet {
            SharedStore.manualStation = manualStation
            reloadWidgets()
        }
    }

    @Published var useRealtime: Bool {
        didSet {
            SharedStore.useRealtime = useRealtime
            reloadWidgets()
        }
    }

    @Published var plannedWorkOnLockScreen: Bool {
        didSet {
            SharedStore.plannedWorkOnLockScreen = plannedWorkOnLockScreen
            reloadWidgets()
        }
    }

    @Published var fontStyle: WidgetFontStyle {
        didSet {
            SharedStore.fontStyle = fontStyle
            reloadWidgets()
        }
    }

    init() {
        schedule = SharedStore.loadSchedule()
        issues = IssueLog.load()
        manualStation = SharedStore.manualStation
        useRealtime = SharedStore.useRealtime
        plannedWorkOnLockScreen = SharedStore.plannedWorkOnLockScreen
        fontStyle = SharedStore.fontStyle
    }

    /// Called whenever the app comes to the foreground.
    func becameActive() {
        LocationService.shared.refresh()
        // The widget may have learned today's timetable or logged issues since last time.
        schedule = SharedStore.loadSchedule()
        issues = IssueLog.load()
        // PATH changes timetables without notice, and the page is a small download.
        let stale = schedule.map { Date().timeIntervalSince($0.importedAt) > 24 * 60 * 60 } ?? true
        if stale {
            Task { await downloadSchedule() }
        }
        Task { await refreshIssues() }
        AppModel.scheduleBackgroundRefresh()
    }

    /// Reads the timetable from PATH's website. On failure the schedule already on the
    /// phone stays in use.
    func downloadSchedule() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let fresh = try await WebTimetableImporter.download()
            try SharedStore.save(fresh)
            TimetableArchive.record(fresh)
            schedule = SharedStore.loadSchedule()
            errorMessage = nil
            reloadWidgets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshIssues() async {
        guard let alerts = await PathAlertFeed.fetch() else { return }
        var log = IssueLog.load()
        let before = log.active.map(\.id)
        log.merge(alerts: alerts, now: Date())
        log.save()
        issues = log
        if log.active.map(\.id) != before {
            reloadWidgets()
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
    }

    // MARK: Background refresh

    /// Asks iOS to wake the app later for a timetable check. iOS picks the actual time.
    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs when iOS wakes the app in the background.
    nonisolated static func backgroundRefresh() async {
        scheduleBackgroundRefresh()
        if let fresh = try? await WebTimetableImporter.download(), (try? SharedStore.save(fresh)) != nil {
            TimetableArchive.record(fresh)
        }
        if let alerts = await PathAlertFeed.fetch() {
            var log = IssueLog.load()
            log.merge(alerts: alerts, now: Date())
            log.save()
        }
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
    }
}
