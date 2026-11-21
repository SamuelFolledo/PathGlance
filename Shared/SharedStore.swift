import Foundation

/// State shared between the app and the widget through the App Group container.
enum SharedStore {
    /// Must match the App Group in both .entitlements files.
    static let appGroup = "group.com.samuelfolledo.PathSchedule"
    static let widgetKind = "PathBoard"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private static var scheduleURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("schedule.json")
    }

    static func loadSchedule() -> ScheduleData? {
        guard let url = scheduleURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScheduleData.self, from: data)
    }

    static func save(_ schedule: ScheduleData) throws {
        guard let url = scheduleURL else {
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
}
