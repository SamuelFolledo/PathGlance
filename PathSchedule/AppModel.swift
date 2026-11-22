import SwiftUI
import Combine
import WidgetKit
import BackgroundTasks

enum AppTab: Hashable {
    case trains, issues, settings
}

@MainActor
final class AppModel: ObservableObject {
    nonisolated static let refreshTaskID = "com.samuelfolledo.PathSchedule.refresh"
    /// How far the Trains tab reaches either side of today.
    nonisolated static let daysBack = 7
    nonisolated static let daysAhead = 14

    /// The text sizes the slider in Settings steps through. The app starts one step above
    /// the system's standard size.
    static let textSizes: [DynamicTypeSize] = [.small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1]
    nonisolated static let defaultTextSizeStep = 3

    var textSize: DynamicTypeSize {
        AppModel.textSizes[min(max(textSizeStep, 0), AppModel.textSizes.count - 1)]
    }

    @Published private(set) var schedule: ScheduleData?
    @Published private(set) var issues = IssueLog()
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?

    // MARK: Navigation

    @Published private(set) var tab: AppTab = .trains
    /// Goes up when the tab already showing is tapped again: its list returns to the top
    /// and any sheet over it closes.
    @Published private(set) var resetCount: [AppTab: Int] = [:]

    // What the Trains tab is showing.
    /// Set when a widget line is tapped while the widget is at another station than the
    /// app would pick. Cleared as soon as the user chooses a station.
    @Published private(set) var visitingStation: Station?
    @Published var browseTarget: Station?
    /// Train lists already worked out, reused when switching back and forth.
    let trainLists = TrainListCache()
    /// The time at the top of the train list. Every destination's list keeps to it, so
    /// switching destination stays on the same day and hour.
    @Published var listAnchor = Date()
    /// Goes up when the lists should move to `listAnchor` (a jump to a date, back to now).
    @Published private(set) var jumpCount = 0
    /// Goes up when the favorite stops sheet should open on the Trains tab.
    @Published private(set) var favoritesRequests = 0

    // MARK: Preferences

    @Published var manualStation: Station? {
        didSet { SharedStore.manualStation = manualStation; reloadWidgets() }
    }

    @Published var useRealtime: Bool {
        didSet { SharedStore.useRealtime = useRealtime; reloadWidgets() }
    }

    /// Kinds of issue that are silenced: listed, but not counted and not on the widget.
    @Published var mutedKinds: Set<IssueKind> {
        didSet { SharedStore.mutedKinds = mutedKinds; reloadWidgets() }
    }

    /// Text size across the app, as a step on `AppModel.textSizes`.
    @Published var textSizeStep: Int {
        didSet { UserDefaults.standard.set(textSizeStep, forKey: "textSizeStep") }
    }

    /// A question waiting for the user's answer (`ask`).
    @Published var guide: Guide?

    @Published var fontStyle: WidgetFontStyle {
        didSet { SharedStore.fontStyle = fontStyle; reloadWidgets() }
    }

    @Published var widgetStyle: WidgetStyle {
        didSet { SharedStore.widgetStyle = widgetStyle; reloadWidgets() }
    }

    /// Stops that get an arrival-time column in the Trains tab.
    @Published var favoriteStops: [Station] {
        didSet { SharedStore.favoriteStops = favoriteStops }
    }

    /// Destinations turned off on the widget and in the destination tabs.
    @Published var hiddenTargets: Set<Station> {
        didSet { SharedStore.hiddenTargets = hiddenTargets; reloadWidgets() }
    }

    init() {
        schedule = SharedStore.loadSchedule()
        issues = IssueLog.load()
        manualStation = SharedStore.manualStation
        useRealtime = SharedStore.useRealtime
        mutedKinds = SharedStore.mutedKinds
        textSizeStep = UserDefaults.standard.object(forKey: "textSizeStep") as? Int ?? AppModel.defaultTextSizeStep
        fontStyle = SharedStore.fontStyle
        widgetStyle = SharedStore.widgetStyle
        favoriteStops = SharedStore.favoriteStops
        hiddenTargets = SharedStore.hiddenTargets
        // "-startTab issues" on the command line opens on that tab, for screenshots and UI tests.
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "issues": tab = .issues
        case "settings": tab = .settings
        default: break
        }
    }

    /// Selecting the tab already showing resets it.
    func select(_ newTab: AppTab) {
        if newTab == tab {
            resetCount[newTab, default: 0] += 1
            if newTab == .trains {
                visitingStation = nil
                jump(to: Date())
            }
        } else {
            tab = newTab
        }
    }

    /// The station everything starts from: one the widget sent us to, else the one the
    /// user chose, else the nearest, else Journal Square.
    func station(nearest: Station?) -> Station {
        visitingStation ?? manualStation ?? nearest ?? .journalSquare
    }

    /// Chooses the "from" station and remembers it. `nil` follows the nearest station.
    func chooseStation(_ station: Station?) {
        visitingStation = nil
        manualStation = station
    }

    /// Shows today's trains from `origin` towards `target`, as when a widget line is tapped.
    func open(origin: Station, target: Station) {
        visitingStation = origin == (manualStation ?? LocationService.shared.station ?? .journalSquare) ? nil : origin
        browseTarget = target
        tab = .trains
        jump(to: Date())
    }

    /// Opens the favorite stops sheet, from wherever the station menu was used.
    func editFavorites() {
        tab = .trains
        favoritesRequests += 1
    }

    /// Open issues that count towards the Issues badge: the ones whose kind is not muted.
    var badgeIssues: [Issue] {
        issues.active.filter { !mutedKinds.contains($0.kind) }
    }

    func setMuted(_ kind: IssueKind, _ muted: Bool) {
        if muted { mutedKinds.insert(kind) } else { mutedKinds.remove(kind) }
    }

    // MARK: Guides

    /// Explains what an action will do and waits for a yes. If the user has ticked
    /// "Don't show this again" for it before, the action just runs.
    func ask(_ guide: Guide) {
        if guide.canBeSilenced, Guide.isSilenced(guide.id) {
            guide.action()
        } else {
            self.guide = guide
        }
    }

    /// Puts every preference back the way a fresh install has it. The timetable, the
    /// issue log and what the app has learned about holidays are kept.
    func restoreDefaults() {
        SharedStore.restoreDefaults()
        Guide.showAllAgain()
        UserDefaults.standard.removeObject(forKey: "textSizeStep")
        manualStation = SharedStore.manualStation
        useRealtime = SharedStore.useRealtime
        mutedKinds = SharedStore.mutedKinds
        fontStyle = SharedStore.fontStyle
        widgetStyle = SharedStore.widgetStyle
        favoriteStops = SharedStore.favoriteStops
        hiddenTargets = SharedStore.hiddenTargets
        textSizeStep = AppModel.defaultTextSizeStep
        visitingStation = nil
    }

    /// Moves every train list to `date`.
    func jump(to date: Date) {
        listAnchor = date
        jumpCount += 1
    }

    func toggleFavorite(_ station: Station) {
        if let index = favoriteStops.firstIndex(of: station) {
            favoriteStops.remove(at: index)
        } else {
            favoriteStops.append(station)
        }
    }

    func setTarget(_ station: Station, shown: Bool) {
        if shown { hiddenTargets.remove(station) } else { hiddenTargets.insert(station) }
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
