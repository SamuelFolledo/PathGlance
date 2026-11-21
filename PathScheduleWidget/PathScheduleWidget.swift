import WidgetKit
import SwiftUI
import CoreLocation

struct BoardEntry: TimelineEntry {
    let date: Date
    let board: Board?
    /// When this timeline was built, shown in the header.
    let fetchedAt: Date
    var message: String?

    static var sample: BoardEntry {
        let now = Date()
        func times(_ minutes: [Double]) -> [Date] {
            minutes.map { now.addingTimeInterval($0 * 60) }
        }
        return BoardEntry(
            date: now,
            board: Board(station: .journalSquare, lines: [
                BoardLine(label: "33rd", times: times([4, 14, 24, 34, 44])),
                BoardLine(label: "WTC", times: times([2, 8, 14, 20, 26])),
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
        guard let schedule = SharedStore.loadSchedule() else {
            let entry = BoardEntry(date: now, board: nil, fetchedAt: now, message: "Open PathSchedule to download the timetable")
            return ([entry], now.addingTimeInterval(30 * 60))
        }

        let station = await currentStation()
        var plan = BoardPlan(station: station, schedule: schedule, now: now)
        let useRealtime = SharedStore.useRealtime
        if useRealtime {
            let arrivals = await RealtimeFeed.fetch()
            plan.apply(realtime: arrivals, now: now)
        }

        let entries = plan.refreshDates(from: now).map { date in
            BoardEntry(date: date, board: plan.board(at: date), fetchedAt: now)
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
        VStack(alignment: .leading, spacing: 1) {
            if let board = entry.board {
                Text("From \(board.station.shortName): \(CompactTimes.clock(entry.fetchedAt))")
                    .fontWeight(.semibold)
                if board.lines.isEmpty {
                    Text("No upcoming trains")
                }
                ForEach(board.lines, id: \.self) { line in
                    if line.label.isEmpty {
                        Text(line.timesText)
                    } else {
                        Text("\(Text(line.label).fontWeight(.semibold)) \(line.timesText)")
                    }
                }
            } else {
                Text(entry.message ?? "No schedule")
                    .lineLimit(3)
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct PathScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.widgetKind, provider: BoardProvider()) { entry in
            BoardView(entry: entry)
        }
        .configurationDisplayName("Next PATH trains")
        .description("Upcoming departures from the nearest PATH station.")
        .supportedFamilies([.accessoryRectangular, .systemMedium])
    }
}
