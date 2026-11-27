import Foundation

/// State shared between the app and the widget through the App Group container.
enum SharedStore {
    /// Must match the App Group in both .entitlements files.
    static let appGroup = "group.com.samuelfolledo.PathGlance"
    static let widgetKind = "PathBoard"
    static let roundWidgetKind = "PathRound"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // MARK: Files

    static func fileURL(_ name: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(name)
    }

    static func read<Value: Decodable>(_ type: Value.Type, from name: String) -> Value? {
        guard let url = fileURL(name), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Best effort: the logs written this way can be rebuilt, so a failed write is dropped.
    static func write<Value: Encodable>(_ value: Value, to name: String) {
        guard let url = fileURL(name), let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Schedule

    /// The stored timetable, with the day-type overrides learned so far applied.
    static func loadSchedule(now: Date = Date()) -> ScheduleData? {
        guard var schedule = read(ScheduleData.self, from: "schedule.json") else { return nil }
        schedule.dayOverrides = DayTypeLog.load().overrides(around: now)
        return schedule
    }

    static func save(_ schedule: ScheduleData) throws {
        guard let url = fileURL("schedule.json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder().encode(schedule)
        try data.write(to: url, options: .atomic)
    }

    // MARK: Station

    /// Station picked by hand in the app. `nil` means follow location.
    static var manualStation: Station? {
        get { defaults.string(forKey: "manualStation").flatMap(Station.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "manualStation") }
    }

    /// Last station the app worked out from location.
    static var autoStation: Station? {
        defaults.string(forKey: "autoStation").flatMap(Station.init(rawValue:))
    }

    static var autoStationDate: Date? {
        defaults.object(forKey: "autoStationDate") as? Date
    }

    static func setAutoStation(_ station: Station, at date: Date = Date()) {
        defaults.set(station.rawValue, forKey: "autoStation")
        defaults.set(date, forKey: "autoStationDate")
    }

    // MARK: Options

    /// Adjust the first few times with the Port Authority real-time feed. On by default.
    static var useRealtime: Bool {
        get { defaults.object(forKey: "useRealtime") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "useRealtime") }
    }

    /// Kinds of issue the user has silenced: still listed in the app, but not counted on
    /// the Issues badge and not shown on the widget. Elevator notices start out muted.
    static let defaultMutedKinds: Set<IssueKind> = [.elevator]

    static var mutedKinds: Set<IssueKind> {
        get {
            guard let stored = defaults.stringArray(forKey: "mutedIssueKinds") else { return defaultMutedKinds }
            return Set(stored.compactMap(IssueKind.init(rawValue:)))
        }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: "mutedIssueKinds") }
    }

    /// Every setting kept here, for "Restore defaults".
    static let preferenceKeys = ["manualStation", "useRealtime", "mutedIssueKinds", "favoriteStops", "hiddenTargets",
                                 "widgetDensity", "widgetTimeFormat", "showArrivalOnWidget", "widgetMaxTimes", "fontStyle",
                                 "roundContent", "roundFont", "roundLine", "lineOrder"]

    /// What "Restore defaults" can be told to leave alone.
    enum Kept: String, CaseIterable, Sendable {
        case favoriteStops, mutedIssues, presets

        /// The keys here that hold it.
        var keys: Set<String> {
            switch self {
            case .favoriteStops: return ["favoriteStops"]
            case .mutedIssues: return ["mutedIssueKinds"]
            case .presets: return ["widgetDensity", "widgetTimeFormat", "showArrivalOnWidget", "widgetMaxTimes", "fontStyle",
                                   "roundContent", "roundFont", "roundLine"]
            }
        }
    }

    static func restoreDefaults(keeping kept: Set<Kept> = []) {
        let spared = kept.reduce(into: Set<String>()) { $0.formUnion($1.keys) }
        for key in preferenceKeys where !spared.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }

    /// The lines in the order the user prefers them, every terminal once. It orders the
    /// destination tabs, the widget's rows and the round widget's first line.
    static var lineOrder: [Station] {
        get { BoardRules.completed((defaults.stringArray(forKey: "lineOrder") ?? []).compactMap(Station.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue), forKey: "lineOrder") }
    }

    /// Stops the user cares about. The Trains tab shows a column of arrival times for each.
    static var favoriteStops: [Station] {
        get { (defaults.stringArray(forKey: "favoriteStops") ?? []).compactMap(Station.init(rawValue:)) }
        set { defaults.set(newValue.map(\.rawValue), forKey: "favoriteStops") }
    }

    /// Destinations the user has turned off, on the widget and in the app's tabs.
    static var hiddenTargets: Set<Station> {
        get { Set((defaults.stringArray(forKey: "hiddenTargets") ?? []).compactMap(Station.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: "hiddenTargets") }
    }

    /// The look the widget draws with: what was last saved in the app.
    static var widgetLook: WidgetLook {
        get { WidgetLook(font: fontStyle, style: widgetStyle) }
        set {
            fontStyle = newValue.font
            widgetStyle = newValue.style
        }
    }

    static var widgetStyle: WidgetStyle {
        get {
            WidgetStyle(
                density: defaults.string(forKey: "widgetDensity").flatMap(WidgetDensity.init(rawValue:)) ?? .compact,
                timeFormat: defaults.string(forKey: "widgetTimeFormat").flatMap(WidgetTimeFormat.init(rawValue:)) ?? .full,
                showArrival: defaults.bool(forKey: "showArrivalOnWidget"),
                maxTimes: defaults.object(forKey: "widgetMaxTimes") as? Int ?? Board.mostPerLine
            )
        }
        set {
            defaults.set(newValue.density.rawValue, forKey: "widgetDensity")
            defaults.set(newValue.timeFormat.rawValue, forKey: "widgetTimeFormat")
            defaults.set(newValue.showArrival, forKey: "showArrivalOnWidget")
            defaults.set(newValue.maxTimes, forKey: "widgetMaxTimes")
        }
    }

    static var fontStyle: WidgetFontStyle {
        get { defaults.string(forKey: "fontStyle").flatMap(WidgetFontStyle.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: "fontStyle") }
    }

    // MARK: Round widget

    /// The look the round widget draws with: what was last saved in the app.
    static var roundLook: RoundLook {
        get {
            RoundLook(content: defaults.string(forKey: "roundContent").flatMap(RoundContent.init(rawValue:)) ?? .minutes,
                      font: defaults.string(forKey: "roundFont").flatMap(WidgetFontStyle.init(rawValue:)) ?? .standard)
        }
        set {
            defaults.set(newValue.content.rawValue, forKey: "roundContent")
            defaults.set(newValue.font.rawValue, forKey: "roundFont")
        }
    }

    /// The line the round widget follows. `nil` is the station's first line shown.
    static var roundLine: Station? {
        get { defaults.string(forKey: "roundLine").flatMap(Station.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: "roundLine") }
    }
}
