import Foundation

/// State shared between the app and the widget through the App Group container.
enum SharedStore {
    /// Must match the App Group in both .entitlements files.
    static let appGroup = "group.com.samuelfolledo.PathSchedule"
    static let widgetKind = "PathBoard"

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

    /// Show the alert mark on the lock screen for planned-work notices too. On by default.
    static var plannedWorkOnLockScreen: Bool {
        get { defaults.object(forKey: "plannedWorkOnLockScreen") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "plannedWorkOnLockScreen") }
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

    static var widgetStyle: WidgetStyle {
        get {
            WidgetStyle(
                density: defaults.string(forKey: "widgetDensity").flatMap(WidgetDensity.init(rawValue:)) ?? .compact,
                timeFormat: defaults.string(forKey: "widgetTimeFormat").flatMap(WidgetTimeFormat.init(rawValue:)) ?? .full,
                showArrival: defaults.bool(forKey: "showArrivalOnWidget")
            )
        }
        set {
            defaults.set(newValue.density.rawValue, forKey: "widgetDensity")
            defaults.set(newValue.timeFormat.rawValue, forKey: "widgetTimeFormat")
            defaults.set(newValue.showArrival, forKey: "showArrivalOnWidget")
        }
    }

    static var fontStyle: WidgetFontStyle {
        get { defaults.string(forKey: "fontStyle").flatMap(WidgetFontStyle.init(rawValue:)) ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: "fontStyle") }
    }
}
