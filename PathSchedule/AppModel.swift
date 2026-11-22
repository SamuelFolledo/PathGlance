import Foundation
import Combine
import WidgetKit
import BackgroundTasks

enum AppTab: Hashable {
    case trains, issues, settings
}

@MainActor
final class AppModel: ObservableObject {
    nonisolated static let refreshTaskID = "com.samuelfolledo.PathSchedule.refresh"

    @Published private(set) var schedule: ScheduleData?
    @Published private(set) var issues = IssueLog()
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?
    @Published var tab: AppTab = .trains

    // What the Trains tab is showing.
    /// `nil` follows the widget's station (pinned or nearest).
    @Published var browseOrigin: Station?
    @Published var browseTarget: Station?
    /// Days from today: -7 through 14.
    @Published var dayOffset = 0

    @Published var favoriteTargets: [Station] {
        didSet {
            SharedStore.favoriteTargets = favoriteTargets
            reloadWidgets()
        }
    }

    @Published var showArrivalOnWidget: Bool {
        didSet {
            SharedStore.showArrivalOnWidget = showArrivalOnWidget
            reloadWidgets()
        }
    }

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
        favoriteTargets = SharedStore.favoriteTargets
        showArrivalOnWidget = SharedStore.showArrivalOnWidget
        // "-startTab issues" on the command line opens on that tab, for screenshots.
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "issues": tab = .issues
        case "settings": tab = .settings
        default: break
        }
    }

    /// Shows today's trains from `origin` towards `target`, as when a widget line is tapped.
    func open(origin: Station, target: Station) {
        browseOrigin = origin
        browseTarget = target
        dayOffset = 0
        tab = .trains
    }

    /// Called whenever the app comes to the foreground.
    func becameActive() {
        LocationService.shared.refresh()
        // The widget may have learned today's timetable or logged issues since last time.
        schedule = SharedStore.loadSchedule()
        issues = IssueLog.load()
        // PATH changes timetables without notice, and the page is a small download.
        // A file from an older build has no ride times, so it is replaced too.
        let stale = schedule.map { Date().timeIntervalSince($0.importedAt) > 24 * 60 * 60 || $0.travel == nil } ?? true
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
