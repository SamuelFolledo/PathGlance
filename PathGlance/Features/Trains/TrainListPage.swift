import SwiftUI
import UIKit

/// One destination's trains: the column names fixed on top, the days stacked in a card
/// below. The rows come from `TrainListCache`, worked out off the main thread.
struct TrainListPage: View {
    let origin: Station
    let target: Station
    let isSelected: Bool
    let now: Date
    let arrivals: [RealtimeArrival]
    let dayTypes: DayTypeLog
    let onSelectTrain: (TrainTime, [TrainTime]) -> Void
    /// Called with the day at the top of the list and whether it has been scrolled on.
    let onHeader: (TrainListHeader) -> Void
    let onRefresh: () async -> Void

    @Environment(\.openURL) private var openURL

    @EnvironmentObject private var model: AppModel
    @State private var list: TrainList?
    @State private var topID: Double?
    /// Goes up each time the list is moved from here, so the rows take the new position.
    @State private var moves = 0
    /// How many times a tap to hide each column has been turned down. Each one is a shake.
    @State private var refusals: [Station: Int] = [:]
    @ScaledMetric(relativeTo: .subheadline) private var columnWidth: CGFloat = 76

    /// What the tab's header should show, while this is the list on screen.
    private var header: TrainListHeader? {
        guard isSelected, let list, let day = list.day(containing: topID) else { return nil }
        return TrainListHeader(title: day.title, isAhead: list.isAhead(top: topID, now: now), day: day.id, note: day.note)
    }

    /// What the rows are built from; a change rebuilds them.
    private struct BuildKey: Hashable {
        var origin: Station
        var target: Station
        var favorites: [Station]
        var imported: Date?
        var minute: Int
        var arrivalCount: Int
        var firstArrival: Date?
        var issueIDs: [String]
    }

    private var buildKey: BuildKey {
        BuildKey(origin: origin, target: target, favorites: model.columnStops,
                 imported: model.schedule?.importedAt,
                 minute: Int(now.timeIntervalSince1970 / 60),
                 arrivalCount: arrivals.count,
                 firstArrival: arrivals.first?.arrival,
                 issueIDs: model.issues.active.map(\.id))
    }

    var body: some View {
        GeometryReader { proxy in
            if let list {
                // The departure column plus as many arrival columns as fit, always keeping
                // the destination (the last one).
                // A hidden destination column is simply not drawn; hidden favorites are
                // already left out of the list's columns.
                let hidesTarget = model.hiddenColumns.contains(target)
                let visible = hidesTarget ? Array(list.columns.dropLast()) : list.columns
                let fit = max(1, Int((proxy.size.width - 32) / columnWidth) - 1)
                let skipped = max(0, visible.count - fit)

                let isAhead = list.isAhead(top: topID, now: now)
                VStack(spacing: 0) {
                    columnNames(columns: Array(visible.dropFirst(skipped)), canHide: AppModel.canHideColumn(visible: visible.count))
                    // Equatable: scrolling changes `topID` many times a second, and the
                    // rows must not be laid out again for that.
                    TrainRows(list: list, origin: origin, target: target, skipped: skipped, hidesTarget: hidesTarget, moves: moves,
                              showsPeriod: model.showsPeriod, hasHiddenColumns: !model.hiddenColumns.isEmpty, topID: $topID,
                              onSelectTrain: { onSelectTrain($0, list.trains) },
                              onMenu: handle,
                              onSettle: { if isSelected { model.listAnchor = TrainList.time(of: $0) } },
                              onRefresh: onRefresh)
                        .equatable()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(.rect(topLeadingRadius: Theme.Radius.card, topTrailingRadius: Theme.Radius.card))
                        // Scrolled: the rows fade out under the header, with no hard bar.
                        .overlay(alignment: .top) {
                            LinearGradient(colors: [Color(.systemGroupedBackground), Color(.systemGroupedBackground).opacity(0)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 28)
                                .opacity(isAhead ? 1 : 0)
                                .animation(.snappy, value: isAhead)
                                .allowsHitTesting(false)
                        }
                }
            } else {
                ProgressView("Loading trains")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: header, initial: true) { _, header in
            if let header { onHeader(header) }
        }
        .task(id: buildKey) {
            guard let schedule = model.schedule else { return }
            let isFirst = list == nil
            let built = await model.trainLists.list(schedule: schedule, origin: origin, target: target, favorites: model.columnStops,
                                                    arrivals: arrivals, issues: model.issues.active, dayTypes: dayTypes, now: now)
            guard !Task.isCancelled else { return }
            list = built
            if isFirst { move(to: model.listAnchor, in: built) }
        }
        .onChange(of: model.listAnchor) { _, anchor in
            if !isSelected { move(to: anchor, in: list) }
        }
        .onChange(of: model.jumpCount) {
            move(to: model.listAnchor, in: list, animated: isSelected)
        }
    }

    /// Puts the first train at or after `time` at the top. The list on screen scrolls
    /// there; the others just take the position.
    private func move(to time: Date, in list: TrainList?, animated: Bool = false) {
        guard let id = list?.rowID(for: time) else { return }
        withAnimation(animated ? .smooth(duration: 0.45) : nil) {
            topID = id
            moves += 1
        }
    }

    /// Hides a stop's column, unless that would leave your station's column on its own:
    /// one column of times says where a train leaves and nothing about where it gets to.
    private func hide(_ stop: Station) {
        let hidesTarget = model.hiddenColumns.contains(target)
        let visible = (list?.columns.count ?? 0) - (hidesTarget ? 1 : 0)
        if AppModel.canHideColumn(visible: visible) {
            model.hiddenColumns.insert(stop)
        } else {
            refuse(stop)
        }
    }

    /// The name shakes and the phone gives its error tap: this column is not going anywhere.
    private func refuse(_ stop: Station) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        withAnimation(.linear(duration: 0.4)) { refusals[stop, default: 0] += 1 }
    }

    /// What a row's long-press menu asked for.
    private func handle(_ action: TrainRowAction) {
        switch action {
        case .hideColumn(let stop): hide(stop)
        case .unfavorite(let stop): model.toggleFavorite(stop)
        case .showHiddenColumns: model.hiddenColumns = []
        case .togglePeriod: model.showsPeriod.toggle()
        case .editFavorites: model.editFavorites()
        case .report(let train):
            if let url = reportURL(train) { openURL(url) }
        }
    }

    /// An email to the developer, filled in with which train it is about.
    private func reportURL(_ train: TrainTime) -> URL? {
        let when = "\(PathFormat.dayWithYear(train.time)) \(CompactTimes.clockWithPeriod(train.time))"
        return AppInfo.email(
            subject: "\(AppInfo.name): schedule issue, \(origin.name) to \(target.name)",
            body: "What was wrong:\n",
            details: [
                "Train: \(when) from \(origin.name) to \(target.name)\(train.isLive ? " (live time)" : "")",
                "Timetable: \(model.schedule?.feedVersion ?? "unknown")",
            ]
        )
    }

    /// The widest a time gets, for sizing the columns.
    private var sampleTime: String { TrainColumn<Text>.sampleTime(showsPeriod: model.showsPeriod) }

    /// Columns hidden with a tap on their name that this list would otherwise show.
    private var hiddenStops: [Station] {
        guard !model.hiddenColumns.isEmpty, let schedule = model.schedule else { return [] }
        return TrainList.columns(schedule: schedule, origin: origin, target: target, favorites: model.favoriteStops)
            .filter(model.hiddenColumns.contains)
    }

    /// Fixed above the list: the column names as plain text. Tapping a name hides that
    /// stop's column; the hidden ones wait in a line above, and a tap brings one back.
    /// The first column, your own station, always stays. The date is in the tab's header
    /// (`TrainsView`).
    private func columnNames(columns: [Station], canHide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            let hidden = hiddenStops
            if !hidden.isEmpty {
                HStack(spacing: 6) {
                    Label("Hidden", systemImage: "eye.slash")
                    ForEach(hidden) { stop in
                        Button {
                            withAnimation(.snappy) { _ = model.hiddenColumns.remove(stop) }
                        } label: {
                            Text(stop.shortName)
                                .strikethrough()
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill), in: .capsule)
                                .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show the \(stop.name) column")
                        .accessibilityIdentifier("showColumn-\(stop.rawValue)")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            HStack(spacing: 0) {
                TrainColumn(header: origin.shortName, sample: sampleTime, place: .first) {
                    Text(origin.shortName)
                        .padding(.vertical, 6)
                }
                ForEach(columns) { stop in
                    Spacer(minLength: 4)
                    TrainColumn(header: stop.shortName, sample: sampleTime, place: stop == columns.last ? .last : .middle) {
                        Button {
                            if canHide {
                                withAnimation(.snappy) { _ = model.hiddenColumns.insert(stop) }
                            } else {
                                refuse(stop)
                            }
                        } label: {
                            Text(stop.shortName)
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                                .modifier(Shake(shakes: CGFloat(refusals[stop, default: 0])))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(stop.name)
                        .accessibilityHint(canHide ? "Hides this column" : "The last column next to your station always shows")
                        .accessibilityIdentifier("column-\(stop.rawValue)")
                    }
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Theme.Spacing.contentSide)
        .padding(.top, 2)
    }
}

/// What the Trains header shows for the list on screen.
struct TrainListHeader: Equatable {
    /// "Today · Sun, Nov 22"
    var title: String
    /// Scrolled on past the next train: the station title makes way for the date.
    var isAhead: Bool
    /// `yyyymmdd` of that day.
    var day: Int
    /// A holiday or learned-timetable warning about it, shown as a banner.
    var note: String?
}

/// What a train row's long-press menu can ask for.
enum TrainRowAction {
    case hideColumn(Station)
    case unfavorite(Station)
    case showHiddenColumns
    case togglePeriod
    case editFavorites
    case report(TrainTime)
}

/// The scrolling rows of a train list. Redrawn only when the list itself changes.
private struct TrainRows: View, Equatable {
    let list: TrainList
    let origin: Station
    let target: Station
    /// Leading columns left out because they do not fit.
    let skipped: Int
    /// The destination's column was hidden with a tap on its name.
    let hidesTarget: Bool
    /// Changes when the list was moved in code, which must reach the scroll view.
    let moves: Int
    /// AM and PM after each time.
    let showsPeriod: Bool
    let hasHiddenColumns: Bool
    @Binding var topID: Double?
    let onSelectTrain: (TrainTime) -> Void
    let onMenu: (TrainRowAction) -> Void
    let onSettle: (Double) -> Void
    let onRefresh: () async -> Void

    static func == (lhs: TrainRows, rhs: TrainRows) -> Bool {
        lhs.list.version == rhs.list.version && lhs.skipped == rhs.skipped && lhs.hidesTarget == rhs.hidesTarget && lhs.moves == rhs.moves
            && lhs.showsPeriod == rhs.showsPeriod && lhs.hasHiddenColumns == rhs.hasHiddenColumns
            && lhs.origin == rhs.origin && lhs.target == rhs.target
    }

    private func clock(_ date: Date) -> String {
        showsPeriod ? CompactTimes.clockWithPeriod(date) : CompactTimes.clock(date)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(list.days) { day in
                    dayHeading(day)
                        .id(day.headerID)
                    if day.rows.isEmpty {
                        Text("No trains to \(target.name) on this day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(Theme.Spacing.contentSide)
                    }
                    ForEach(day.rows) { row in
                        rowView(row)
                            .id(row.id)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $topID, anchor: .top)
        .onScrollPhaseChange { _, phase in
            // Once scrolling settles, the other destinations' lists follow this one.
            if phase == .idle, let topID { onSettle(topID) }
        }
        .refreshable { await onRefresh() }
    }

    /// Where one day ends and the next begins. Today's is in the accent color.
    private func dayHeading(_ day: TrainList.Day) -> some View {
        Text(day.title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(day.isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func rowView(_ row: TrainList.Row) -> some View {
        switch row.kind {
        case .routeChange(let name):
            HStack(spacing: Theme.Spacing.sm) {
                Rectangle().fill(.tint).frame(height: 1)
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                    .fixedSize()
                Rectangle().fill(.tint).frame(height: 1)
            }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.vertical, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("From here, trains run \(name)")
        case .train(let train, let allCells):
            let cells = Array((hidesTarget ? Array(allCells.dropLast()) : allCells).dropFirst(skipped))
            let delay = TimeInterval(train.isLate ? train.delayMinutes * 60 : 0)
            Button {
                onSelectTrain(train)
            } label: {
                let stops = Array((hidesTarget ? Array(list.columns.dropLast()) : list.columns).dropFirst(skipped))
                let sample = TrainColumn<Text>.sampleTime(showsPeriod: showsPeriod)
                HStack(alignment: .top, spacing: 0) {
                    TrainColumn(header: origin.shortName, sample: sample, place: .first) {
                        TrainTimeText(time: train.time, lateBy: delay, clock: clock, isDeparture: true)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, arrival in
                        // The last column is pushed to the right edge.
                        let isLast = index == cells.count - 1
                        Spacer(minLength: 4)
                        TrainColumn(header: index < stops.count ? stops[index].shortName : "", sample: sample, place: isLast ? .last : .middle) {
                            if let arrival {
                                TrainTimeText(time: arrival, lateBy: delay, clock: clock, isDeparture: false, isTrailing: isLast)
                            } else {
                                Text("—")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Theme.Spacing.contentSide)
                .padding(.vertical, 10)
                // The live dot sits in the margin, level with the middle of the row, so
                // the times line up with the rows that have none.
                .overlay(alignment: .leading) {
                    if train.isLive {
                        // Green: a live time, on schedule. Yellow: a live time, running late.
                        StatusDot(color: train.isLate ? .yellow : .green, label: train.isLate ? "Live, running late" : "Live")
                            .padding(.leading, (Theme.Spacing.contentSide - Theme.Size.dot) / 2)
                    }
                }
                .contentShape(.rect)
                // A train that has gone is still there to look at, a little greyed.
                .opacity(row.isPast ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                Divider().padding(.leading, Theme.Spacing.contentSide)
            }
            .contextMenu { menu(train) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(train, cells: allCells, isPast: row.isPast))
            .accessibilityHint("Shows every stop")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// The long-press menu: what can be done about this train and about the columns.
    @ViewBuilder
    private func menu(_ train: TrainTime) -> some View {
        Button {
            onSelectTrain(train)
        } label: {
            Label("Show every stop", systemImage: "list.bullet")
        }
        let stops = list.columns.filter { $0 != target }
        if !stops.isEmpty {
            Section("Columns") {
                ForEach(stops) { stop in
                    Button {
                        onMenu(.hideColumn(stop))
                    } label: {
                        Label("Hide \(stop.name)", systemImage: "eye.slash")
                    }
                }
                ForEach(stops) { stop in
                    Button(role: .destructive) {
                        onMenu(.unfavorite(stop))
                    } label: {
                        Label("Unfavorite \(stop.name)", systemImage: "star.slash")
                    }
                }
            }
        }
        Section {
            if hasHiddenColumns {
                Button {
                    onMenu(.showHiddenColumns)
                } label: {
                    Label("Show hidden columns", systemImage: "eye")
                }
            }
            Button {
                onMenu(.togglePeriod)
            } label: {
                Label(showsPeriod ? "Hide AM and PM" : "Show AM and PM", systemImage: "clock")
            }
            Button {
                onMenu(.editFavorites)
            } label: {
                Label("Favorite stops", systemImage: "star")
            }
        }
        Section {
            Button {
                onMenu(.report(train))
            } label: {
                Label("Report a schedule issue", systemImage: "envelope")
            }
        }
    }

    private func spoken(_ train: TrainTime, cells: [Date?], isPast: Bool) -> String {
        var parts = [(isPast ? "Departed " : "Departs ") + CompactTimes.clockWithPeriod(train.time)
                     + (train.isLive ? (train.isLate ? ", live, \(train.delayMinutes) minutes late" : ", live") : "")]
        for (stop, arrival) in zip(list.columns, cells) {
            if let arrival { parts.append("\(stop.name) \(CompactTimes.clockWithPeriod(arrival))") }
        }
        return parts.joined(separator: ", ")
    }
}

/// One time in a train row. When the train is late, the timetable time is struck through
/// and the live time sits under it in yellow.
struct TrainTimeText: View {
    /// The time the train is now due.
    let time: Date
    /// How far behind the timetable that is. Zero for on time.
    let lateBy: TimeInterval
    let clock: (Date) -> String
    /// The first column is heavier than the arrival columns.
    let isDeparture: Bool
    /// In the last column, which is set against the right edge.
    var isTrailing = false

    var body: some View {
        if lateBy > 0 {
            VStack(alignment: isTrailing ? .trailing : .leading, spacing: 0) {
                Text(clock(time.addingTimeInterval(-lateBy)))
                    .font(isDeparture ? .subheadline : .footnote)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Text(clock(time))
                    .font(isDeparture ? .body.weight(.semibold) : .callout)
                    .foregroundStyle(.yellow)
            }
        } else {
            Text(clock(time))
                .font(isDeparture ? .body.weight(.semibold) : .callout)
                .foregroundStyle(isDeparture ? .primary : .secondary)
        }
    }
}

/// One column of the train list, in the header and in every row. Each is exactly as wide
/// as the widest thing it can hold, so the header and the rows line up, and the space left
/// over is shared equally between the columns however many there are.
struct TrainColumn<Content: View>: View {
    enum Place { case first, middle, last }

    /// The column's name in the header.
    let header: String
    /// The widest time a row can show.
    let sample: String
    let place: Place
    @ViewBuilder let content: Content

    private var alignment: Alignment {
        switch place {
        case .first: return .topLeading
        case .middle: return .top
        case .last: return .topTrailing
        }
    }

    var body: some View {
        ZStack(alignment: alignment) {
            // Never seen: these only give the column its width.
            Group {
                Text(header)
                    .font(.footnote.weight(.semibold))
                Text(sample)
                    .font(place == .first ? .body.weight(.semibold) : .callout)
                    .monospacedDigit()
            }
            .lineLimit(1)
            .hidden()
            .accessibilityHidden(true)
            content
        }
    }

    /// "10:00 PM", or "10:00" without the period: no time is wider.
    static func sampleTime(showsPeriod: Bool) -> String {
        // 10:00 PM in New York.
        let late = Date(timeIntervalSinceReferenceDate: 3 * 60 * 60)
        return showsPeriod ? CompactTimes.clockWithPeriod(late) : CompactTimes.clock(late)
    }
}
