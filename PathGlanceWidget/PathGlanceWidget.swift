import WidgetKit
import SwiftUI
import CoreLocation
import AppIntents

struct BoardEntry: TimelineEntry {
    let date: Date
    let board: Board?
    /// When this timeline was built, shown in the header.
    let fetchedAt: Date
    var message: String?
    var fontStyle: WidgetFontStyle = .standard
    var style = WidgetStyle()

    static var sample: BoardEntry {
        let now = Date()
        func times(_ minutes: [Double]) -> [Date] {
            minutes.map { now.addingTimeInterval($0 * 60) }
        }
        return BoardEntry(
            date: now,
            board: Board(station: .journalSquare, rows: [
                BoardRow(label: "33rd", target: .thirtyThirdStreet, times: times([4, 14, 24, 34, 44, 54, 64, 74])),
                BoardRow(label: "WTC", target: .worldTradeCenter, times: times([2, 8, 14, 20, 26, 32, 38, 44])),
            ]),
            fetchedAt: now
        )
    }
}

struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task {
            let result = await BoardProvider.build()
            completion(result.entries.first ?? .sample)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        Task {
            let result = await BoardProvider.build()
            completion(Timeline(entries: result.entries, policy: .after(result.reload)))
        }
    }

    private static func build() async -> (entries: [BoardEntry], reload: Date) {
        let now = Date()
        let fontStyle = SharedStore.fontStyle
        let style = SharedStore.widgetStyle
        guard var schedule = SharedStore.loadSchedule(now: now) else {
            let entry = BoardEntry(date: now, board: nil, fetchedAt: now, message: "Open PathGlance to download the timetable", fontStyle: fontStyle, style: style)
            return ([entry], now.addingTimeInterval(30 * 60))
        }

        let station = await currentStation()
        let useRealtime = SharedStore.useRealtime
        async let alertFetch = PathAlertFeed.fetch()
        let arrivals = useRealtime ? await RealtimeFeed.fetch() : []
        let alerts = await alertFetch

        // Learn which timetable today is running before the board is built from it.
        if !arrivals.isEmpty {
            var dayTypes = DayTypeLog.load()
            dayTypes.record(arrivals: arrivals, schedule: schedule, now: now)
            dayTypes.save()
            schedule.dayOverrides = dayTypes.overrides(around: now)
        }

        let targets = BoardRules.widgetTargets(from: station, hidden: SharedStore.hiddenTargets)
        var plan = BoardPlan(station: station, targets: targets, schedule: schedule, now: now)
        plan.style = style
        plan.apply(realtime: arrivals, now: now)

        var issues = IssueLog.load()
        if let alerts {
            issues.merge(alerts: alerts, now: now)
        }
        if useRealtime, !arrivals.isEmpty {
            let late = plan.groups
                .filter { $0.delay == .major }
                .map { (origin: station, target: $0.target, minutes: $0.delayMinutes) }
            issues.noteDetectedDelays(late, at: station, now: now)
        }
        issues.save()
        plan.apply(issues: issues.active, muted: SharedStore.mutedKinds)

        let entries = plan.refreshDates(from: now).map { date in
            BoardEntry(date: date, board: plan.board(at: date), fetchedAt: now, fontStyle: fontStyle, style: style)
        }
        // Reload regularly to pick up a new station and fresh predictions.
        // The app also reloads the widget whenever the station changes.
        let reload = now.addingTimeInterval(useRealtime ? 20 * 60 : 60 * 60)
        return (entries, reload)
    }

    /// Manual choice first, then whichever is newer: the widget's own location fix
    /// or the station the app last saved.
    @MainActor
    private static func currentStation() -> Station {
        if let manual = SharedStore.manualStation {
            return manual
        }
        let manager = CLLocationManager()
        if manager.isAuthorizedForWidgetUpdates,
           let location = manager.location,
           location.timestamp > (SharedStore.autoStationDate ?? .distantPast) {
            return Station.nearest(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        return SharedStore.autoStation ?? .journalSquare
    }
}

struct BoardView: View {
    let entry: BoardEntry

    var body: some View {
        Group {
            if let board = entry.board {
                BoardWidgetView(board: board, fetchedAt: entry.fetchedAt, fontStyle: entry.fontStyle, style: entry.style) { headerRow in
                    // The whole header row refreshes: station, live times and alerts are all
                    // read again. Inactive while the phone is locked; works once it is unlocked.
                    Button(intent: RefreshBoardIntent()) { headerRow }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Trains from \(board.station.name), updated \(CompactTimes.clockWithPeriod(entry.fetchedAt)). Refresh.")
                } tapArea: { line in
                    // Each line opens its own list of trains in the app.
                    if let target = line.target {
                        Link(destination: AppLink.line(from: board.station, to: target)) {
                            Color.clear.contentShape(.rect)
                        }
                    }
                }
            } else {
                Text(entry.message ?? "No schedule")
                    .font(entry.fontStyle.bodyFont(entry.style.density))
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct PathGlanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.widgetKind, provider: BoardProvider()) { entry in
            BoardView(entry: entry)
        }
        .configurationDisplayName("Next PATH trains")
        .description("Upcoming departures from the nearest PATH station.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
