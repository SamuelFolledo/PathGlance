import SwiftUI
import Combine
import WidgetKit
import BackgroundTasks

enum AppTab: Hashable {
    case trains, issues, widget
}

/// How builds before per-preset edits stored their one custom look.
struct OldCustomPreset<Look: Codable>: Codable {
    var look: Look
    var savedAt = Date()
}

@MainActor
final class AppModel: ObservableObject {
    nonisolated static let refreshTaskID = "com.samuelfolledo.PathGlance.refresh"
    /// How far the Trains tab reaches either side of today.
    nonisolated static let daysBack = 7
    nonisolated static let daysAhead = 14

    /// The text sizes the layouts are made for, smallest first.
    static let textSizes: [DynamicTypeSize] = [.small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1]
    /// The app draws one step above the phone's text size: that is the look it was
    /// designed at. The slider in Settings adds to or takes from that.
    nonisolated static let baseTextSizeBoost = 1
    nonisolated static let textSizeOffsets = -3...3

    /// The size the app draws at: the phone's own size, moved by the app's boost and the
    /// user's offset, kept within the sizes the layouts are made for.
    nonisolated static func textSize(system: DynamicTypeSize, offset: Int) -> DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        let sizes: [DynamicTypeSize] = [.small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1]
        let lowest = all.firstIndex(of: sizes[0]) ?? 0
        let highest = all.firstIndex(of: sizes[sizes.count - 1]) ?? all.count - 1
        let start = min(max(all.firstIndex(of: system) ?? lowest, lowest), highest)
        return all[min(max(start + baseTextSizeBoost + offset, lowest), highest)]
    }

    /// "Standard", "+1", "−2": the offset as the Settings sheet names it.
    nonisolated static func textSizeName(offset: Int) -> String {
        offset == 0 ? "Standard" : (offset > 0 ? "+\(offset)" : "−\(-offset)")
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

    /// Live arrivals are always used: the first train or two on each line is PATH's prediction.
    let useRealtime = true

    /// Kinds of issue that are silenced: listed, but not counted and not on the widget.
    @Published var mutedKinds: Set<IssueKind> {
        didSet { SharedStore.mutedKinds = mutedKinds; reloadWidgets() }
    }

    /// Steps added to (or taken from) the phone's text size across the app. 0 follows
    /// the phone.
    @Published var textSizeOffset: Int {
        didSet { UserDefaults.standard.set(textSizeOffset, forKey: "textSizeOffset") }
    }

    /// A question waiting for the user's answer (`ask`).
    @Published var guide: Guide?

    /// The legend on the Widget tab has been closed with its X. It stays away until
    /// "Restore defaults", or "Widget legend" under About, brings it back.
    @Published var legendHidden: Bool {
        didSet { UserDefaults.standard.set(legendHidden, forKey: "widgetLegendHidden") }
    }

    // MARK: Widget look

    /// The look being edited in the Widget tab. The widget itself keeps `savedLook`
    /// until Save is tapped.
    @Published var look: WidgetLook
    /// What the widget is drawing with.
    @Published private(set) var savedLook: WidgetLook
    /// The rectangle preset showing in the carousel. The widget keeps `presets.selected`
    /// until Save is tapped.
    @Published private(set) var presetID: String
    /// The rectangle preset the widget is on, and the edits saved to each preset.
    @Published private(set) var presets: PresetBook<WidgetLook> {
        didSet { AppModel.store(presets, id: "widgetPresetID", edits: "widgetPresetEdits") }
    }

    var fontStyle: WidgetFontStyle {
        get { look.font }
        set { look.font = newValue }
    }

    var widgetStyle: WidgetStyle {
        get { look.style }
        set { look.style = newValue }
    }

    /// The same four for the round widget. Each shape has its own presets and edits.
    @Published var roundLook: RoundLook
    @Published private(set) var savedRoundLook: RoundLook
    @Published private(set) var roundPresetID: String
    @Published private(set) var roundPresets: PresetBook<RoundLook> {
        didSet { AppModel.store(roundPresets, id: "roundPresetID", edits: "roundPresetEdits") }
    }

    /// The line the round widget follows. `nil` is the first line shown.
    @Published var roundLine: Station? {
        didSet { SharedStore.roundLine = roundLine; reloadWidgets() }
    }

    var hasUnsavedLook: Bool {
        look != savedLook || roundLook != savedRoundLook || presetID != presets.selected || roundPresetID != roundPresets.selected
    }

    private static func store<Look>(_ book: PresetBook<Look>, id: String, edits: String) {
        UserDefaults.standard.set(book.selected, forKey: id)
        UserDefaults.standard.set(try? JSONEncoder().encode(book.edits), forKey: edits)
    }

    private static func storedEdits<Look: Codable>(_ key: String) -> [String: Look] {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Look].self, from: $0) } ?? [:]
    }

    /// The custom look an older build kept under `key`, wrapped with the date it was saved.
    private static func oldCustom<Look: Codable>(_ key: String) -> Look? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(OldCustomPreset<Look>.self, from: $0) }?.look
    }

    private static func builtInLook(_ id: String) -> WidgetLook {
        WidgetPreset.builtIn.first { $0.id == id }?.look ?? WidgetLook()
    }

    private static func builtInRoundLook(_ id: String) -> RoundLook {
        RoundPreset.builtIn.first { $0.id == id }?.look ?? RoundLook()
    }

    /// What a rectangle preset looks like now: the one in hand as it is being edited,
    /// any other with the edits last saved to it.
    func look(forPreset id: String) -> WidgetLook {
        id == presetID ? look : presets.look(id, builtIn: AppModel.builtInLook(id))
    }

    func roundLook(forPreset id: String) -> RoundLook {
        id == roundPresetID ? roundLook : roundPresets.look(id, builtIn: AppModel.builtInRoundLook(id))
    }

    /// Whether a preset differs from the way it is built.
    func isEdited(preset id: String, shape: WidgetShape) -> Bool {
        switch shape {
        case .rectangle: return look(forPreset: id) != AppModel.builtInLook(id)
        case .round: return roundLook(forPreset: id) != AppModel.builtInRoundLook(id)
        }
    }

    /// Turns the carousel to another preset. Edits to the one left behind that were not
    /// saved are dropped: it goes back to how it was last saved.
    func selectPreset(_ id: String, shape: WidgetShape) {
        switch shape {
        case .rectangle:
            guard id != presetID, WidgetPreset.builtIn.contains(where: { $0.id == id }) else { return }
            presetID = id
            look = presets.look(id, builtIn: AppModel.builtInLook(id))
        case .round:
            guard id != roundPresetID, RoundPreset.builtIn.contains(where: { $0.id == id }) else { return }
            roundPresetID = id
            roundLook = roundPresets.look(id, builtIn: AppModel.builtInRoundLook(id))
        }
    }

    /// Whether the preset in hand has anything to restore.
    func canRestorePreset(_ shape: WidgetShape) -> Bool {
        isEdited(preset: shape == .rectangle ? presetID : roundPresetID, shape: shape)
    }

    /// Puts the preset in hand back to how it is built. Like any other edit, it reaches
    /// the widget on Save and is undone by Cancel.
    func restorePreset(_ shape: WidgetShape) {
        switch shape {
        case .rectangle: look = AppModel.builtInLook(presetID)
        case .round: roundLook = AppModel.builtInRoundLook(roundPresetID)
        }
    }

    /// Drops the edits not yet saved: the previews go back to what the widgets show.
    func revertLook() {
        presetID = presets.selected
        look = savedLook
        roundPresetID = roundPresets.selected
        roundLook = savedRoundLook
    }

    /// Sends the edited looks to the widgets, and keeps each with its preset.
    func saveLook() {
        presets.save(look, for: presetID, builtIn: AppModel.builtInLook(presetID))
        roundPresets.save(roundLook, for: roundPresetID, builtIn: AppModel.builtInRoundLook(roundPresetID))
        savedLook = look
        savedRoundLook = roundLook
        SharedStore.widgetLook = look
        SharedStore.roundLook = roundLook
        reloadWidgets()
    }

    /// Reads both shapes' presets, taking over what an older build left: its look that
    /// matches no preset, and its one custom look, become edits on the first preset.
    private static func loadPresets() -> (rectangle: PresetBook<WidgetLook>, round: PresetBook<RoundLook>) {
        let defaults = UserDefaults.standard
        let rectangle = PresetBook.resolve(
            saved: SharedStore.widgetLook, storedID: defaults.string(forKey: "widgetPresetID"), storedEdits: storedEdits("widgetPresetEdits"),
            custom: oldCustom("customWidgetPreset"), builtIn: WidgetPreset.builtIn.map { (id: $0.id, look: $0.look) }, fallback: WidgetPreset.builtIn[0].id)
        let round = PresetBook.resolve(
            saved: SharedStore.roundLook, storedID: defaults.string(forKey: "roundPresetID"), storedEdits: storedEdits("roundPresetEdits"),
            custom: oldCustom("customRoundPreset"), builtIn: RoundPreset.builtIn.map { (id: $0.id, look: $0.look) }, fallback: RoundPreset.builtIn[0].id)
        defaults.removeObject(forKey: "customWidgetPreset")
        defaults.removeObject(forKey: "customRoundPreset")
        store(rectangle, id: "widgetPresetID", edits: "widgetPresetEdits")
        store(round, id: "roundPresetID", edits: "roundPresetEdits")
        return (rectangle, round)
    }

    // MARK: Train list preferences

    /// Favorite stops whose column is hidden for now, without unfavoriting them.
    @Published var hiddenColumns: Set<Station> {
        didSet { UserDefaults.standard.set(hiddenColumns.map(\.rawValue), forKey: "hiddenColumns") }
    }

    /// Show AM and PM after times in the train list.
    @Published var showsPeriod: Bool {
        didSet { UserDefaults.standard.set(showsPeriod, forKey: "showsPeriod") }
    }

    /// The favorite stops that currently get a column.
    var columnStops: [Station] {
        favoriteStops.filter { !hiddenColumns.contains($0) }
    }

    /// Writes a time the way the train list is set to: "7:05 PM" or "7:05".
    func clock(_ date: Date) -> String {
        showsPeriod ? CompactTimes.clockWithPeriod(date) : CompactTimes.clock(date)
    }

    /// Banners put away with their X, by id, with the day (`yyyymmdd`) it was done.
    /// They stay away for the rest of that day.
    @Published private(set) var dismissedBanners: [String: Int] {
        didSet { UserDefaults.standard.set(dismissedBanners.mapValues { $0 as NSNumber }, forKey: "dismissedBanners") }
    }

    /// Made-up issues for screenshots and UI tests ("-sampleBanners YES"). Never saved.
    private(set) var sampleIssues: [Issue] = []
    /// One more made-up issue that names no line or station, for the Issues tab only.
    private(set) var sampleUnplaced: [Issue] = []

    /// Open issues as the Issues tab lays them out, with the made-up ones when asked for.
    var boardIssues: [Issue] { issues.active + sampleIssues + sampleUnplaced }

    /// Sections that start folded on a fresh install.
    nonisolated static let defaultFoldedSections: Set<String> = ["settings-lines"]

    /// Sections the user has folded away, by name. Remembered between launches.
    @Published var foldedSections: Set<String> {
        didSet { UserDefaults.standard.set(Array(foldedSections), forKey: "foldedSections") }
    }

    /// Stops that get an arrival-time column in the Trains tab.
    @Published var favoriteStops: [Station] {
        didSet { SharedStore.favoriteStops = favoriteStops }
    }

    /// Destinations turned off on the widget and in the destination tabs.
    @Published var hiddenTargets: Set<Station> {
        didSet { SharedStore.hiddenTargets = hiddenTargets; reloadWidgets() }
    }

    /// The lines in the order the user prefers. It orders the destination tabs, the
    /// widget's rows and the round widget's first line.
    @Published var lineOrder: [Station] {
        didSet {
            guard lineOrder != oldValue else { return }
            SharedStore.lineOrder = lineOrder
            reloadWidgets()
        }
    }

    init() {
        schedule = SharedStore.loadSchedule()
        issues = IssueLog.load()
        manualStation = SharedStore.manualStation
        mutedKinds = SharedStore.mutedKinds
        // The older absolute step ("textSizeStep") is dropped: the app now follows the phone.
        let offset = UserDefaults.standard.object(forKey: "textSizeOffset") as? Int ?? 0
        textSizeOffset = min(max(offset, AppModel.textSizeOffsets.lowerBound), AppModel.textSizeOffsets.upperBound)
        look = SharedStore.widgetLook
        savedLook = SharedStore.widgetLook
        roundLook = SharedStore.roundLook
        savedRoundLook = SharedStore.roundLook
        let books = AppModel.loadPresets()
        presets = books.rectangle
        presetID = books.rectangle.selected
        roundPresets = books.round
        roundPresetID = books.round.selected
        legendHidden = UserDefaults.standard.bool(forKey: "widgetLegendHidden")
        roundLine = SharedStore.roundLine
        hiddenColumns = Set((UserDefaults.standard.stringArray(forKey: "hiddenColumns") ?? []).compactMap(Station.init(rawValue:)))
        showsPeriod = UserDefaults.standard.object(forKey: "showsPeriod") as? Bool ?? true
        var folded = UserDefaults.standard.stringArray(forKey: "foldedSections").map(Set.init) ?? AppModel.defaultFoldedSections
        // Sections added since start folded once, for people who already have a saved set.
        if !UserDefaults.standard.bool(forKey: "foldedNewSectionsOnce") {
            folded.formUnion(AppModel.defaultFoldedSections)
            UserDefaults.standard.set(true, forKey: "foldedNewSectionsOnce")
        }
        foldedSections = folded
        let today = PathTime.ymd(of: Date())
        dismissedBanners = ((UserDefaults.standard.dictionary(forKey: "dismissedBanners") as? [String: Int]) ?? [:]).filter { $0.value == today }
        if UserDefaults.standard.bool(forKey: "sampleBanners") {
            sampleIssues = Issue.samples(now: Date())
            sampleUnplaced = [Issue.unplacedSample(now: Date())]
        }
        favoriteStops = SharedStore.favoriteStops
        hiddenTargets = SharedStore.hiddenTargets
        lineOrder = SharedStore.lineOrder
        // "-startTab issues" on the command line opens on that tab, for screenshots and UI tests.
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "issues": tab = .issues
        case "settings", "widget": tab = .widget
        default: break
        }
        if Guide.showsWelcomeAtLaunch() { guide = .welcome }
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

    // MARK: Banners

    /// Open, unmuted issues that name `station` or a line from it to `target`, with why.
    /// The station's own come first. Issues the text does not place stay on the Issues tab.
    func relevantIssues(station: Station, target: Station?) -> [(issue: Issue, relevance: IssueRelevance)] {
        let matched = badgeIssues.compactMap { issue in
            IssueMatcher.relevance(of: issue, station: station, target: target).map { (issue: issue, relevance: $0) }
        }
        let samples = sampleIssues.map { (issue: $0, relevance: IssueRelevance.line) }
        return (matched + samples).sorted { $0.relevance == .station && $1.relevance != .station }
    }

    func isBannerDismissed(_ id: String, now: Date) -> Bool {
        dismissedBanners[id] == PathTime.ymd(of: now)
    }

    /// Puts a banner away until tomorrow.
    func dismissBanner(_ id: String, now: Date) {
        let today = PathTime.ymd(of: now)
        dismissedBanners = dismissedBanners.filter { $0.value == today }.merging([id: today]) { _, new in new }
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

    /// Brings the legend on the Widget tab back, and the tab to its top so it is in view.
    func showLegend() {
        legendHidden = false
        tab = .widget
        resetCount[.widget, default: 0] += 1
    }

    /// Shows the welcome note again, whether or not it has been silenced.
    func showWelcome() {
        guide = .welcome
    }

    /// Puts every preference back the way a fresh install has it, except what is in
    /// `kept`. The timetable, the issue log and what the app has learned about holidays
    /// are never touched.
    func restoreDefaults(keeping kept: Set<SharedStore.Kept> = []) {
        SharedStore.restoreDefaults(keeping: kept)
        Guide.showAllAgain()
        var keys = ["textSizeStep", "textSizeOffset", "showsPeriod", "foldedSections", "dismissedBanners", "askedForAlways", "widgetLegendHidden"]
        if !kept.contains(.presets) { keys += ["widgetPresetID", "widgetPresetEdits", "roundPresetID", "roundPresetEdits"] }
        if !kept.contains(.favoriteStops) { keys.append("hiddenColumns") }
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        manualStation = SharedStore.manualStation
        mutedKinds = SharedStore.mutedKinds
        look = SharedStore.widgetLook
        savedLook = SharedStore.widgetLook
        roundLook = SharedStore.roundLook
        savedRoundLook = SharedStore.roundLook
        roundLine = SharedStore.roundLine
        if !kept.contains(.presets) {
            presets = PresetBook(selected: WidgetPreset.builtIn[0].id)
            roundPresets = PresetBook(selected: RoundPreset.builtIn[0].id)
        }
        presetID = presets.selected
        roundPresetID = roundPresets.selected
        legendHidden = false
        if !kept.contains(.favoriteStops) { hiddenColumns = [] }
        showsPeriod = true
        foldedSections = AppModel.defaultFoldedSections
        dismissedBanners = [:]
        favoriteStops = SharedStore.favoriteStops
        hiddenTargets = SharedStore.hiddenTargets
        lineOrder = SharedStore.lineOrder
        textSizeOffset = 0
        visitingStation = nil
        reloadWidgets()
    }

    /// Whether hiding one more column would leave the train list with fewer than two:
    /// the user's own station and at least one arrival column always show.
    nonisolated static func canHideColumn(visible: Int) -> Bool {
        visible > 1
    }

    /// Moves every train list to `date`.
    func jump(to date: Date) {
        listAnchor = date
        jumpCount += 1
    }

    func toggleFavorite(_ station: Station) {
        if let index = favoriteStops.firstIndex(of: station) {
            favoriteStops.remove(at: index)
            hiddenColumns.remove(station)
        } else {
            favoriteStops.append(station)
        }
    }

    /// Asks first, then drops every favorite stop and its column.
    func clearFavorites() {
        ask(Guide(
            id: "clear-favorites",
            title: "Clear all favorite stops?",
            points: [
                "The train list goes back to two columns: your station and the destination.",
                "You can pick favorites again at any time, with the star beside a station.",
            ],
            confirm: "Clear",
            isDestructive: true
        ) {
            self.favoriteStops = []
            self.hiddenColumns = []
        })
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
        WidgetCenter.shared.reloadAllTimelines()
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
        WidgetCenter.shared.reloadAllTimelines()
    }
}
