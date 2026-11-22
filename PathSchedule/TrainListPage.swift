import SwiftUI

/// One destination's trains: the date and column names fixed on top, the days stacked
/// below. The rows come from `TrainListCache`, worked out off the main thread.
struct TrainListPage: View {
    let origin: Station
    let target: Station
    let isSelected: Bool
    let now: Date
    let arrivals: [RealtimeArrival]
    let dayTypes: DayTypeLog
    let onSelectTrain: (TrainTime, [TrainTime]) -> Void
    let onPickDate: () -> Void
    let onRefresh: () async -> Void

    @EnvironmentObject private var model: AppModel
    @State private var list: TrainList?
    @State private var topID: Double?
    /// Goes up each time the list is moved from here, so the rows take the new position.
    @State private var moves = 0
    @ScaledMetric(relativeTo: .subheadline) private var columnWidth: CGFloat = 76

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
        BuildKey(origin: origin, target: target, favorites: model.favoriteStops,
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
                let fit = max(1, Int((proxy.size.width - 32) / columnWidth) - 1)
                let skipped = max(0, list.columns.count - fit)

                VStack(spacing: 0) {
                    if let day = list.day(containing: topID) {
                        dayBar(day, columns: Array(list.columns.dropFirst(skipped)))
                    }
                    // Equatable: scrolling changes `topID` many times a second, and the
                    // rows must not be laid out again for that.
                    TrainRows(list: list, origin: origin, target: target, skipped: skipped, moves: moves, topID: $topID,
                              onSelectTrain: { onSelectTrain($0, list.trains) },
                              onSettle: { if isSelected { model.listAnchor = TrainList.time(of: $0) } },
                              onRefresh: onRefresh)
                        .equatable()
                }
            } else {
                ProgressView("Loading trains")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: buildKey) {
            guard let schedule = model.schedule else { return }
            let isFirst = list == nil
            let built = await model.trainLists.list(schedule: schedule, origin: origin, target: target, favorites: model.favoriteStops,
                                                    arrivals: arrivals, issues: model.issues.active, dayTypes: dayTypes, now: now)
            guard !Task.isCancelled else { return }
            list = built
            if isFirst { move(to: model.listAnchor, in: built) }
        }
        .onChange(of: model.listAnchor) { _, anchor in
            if !isSelected { move(to: anchor, in: list) }
        }
        .onChange(of: model.jumpCount) {
            move(to: model.listAnchor, in: list)
        }
    }

    /// Puts the first train at or after `time` at the top. Not animated: a jump can cross
    /// days of rows that are not laid out yet, and an animated scroll through them stalls.
    private func move(to time: Date, in list: TrainList?) {
        guard let id = list?.rowID(for: time) else { return }
        topID = id
        moves += 1
    }

    /// Fixed above the list: the day at the top (tap for the calendar), any holiday
    /// warning, and the column names. Today is in the accent color.
    private func dayBar(_ day: TrainList.Day, columns: [Station]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onPickDate) {
                HStack(spacing: 8) {
                    Text(day.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(day.isToday ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(day.title). Choose a date")
            .accessibilityIdentifier("dayBar")
            if let note = day.note {
                Label(note, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 0) {
                Text(origin.shortName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(columns) { stop in
                    Text(stop.shortName)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(stop.name)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// The scrolling rows of a train list. Redrawn only when the list itself changes.
private struct TrainRows: View, Equatable {
    let list: TrainList
    let origin: Station
    let target: Station
    /// Leading columns left out because they do not fit.
    let skipped: Int
    /// Changes when the list was moved in code, which must reach the scroll view.
    let moves: Int
    @Binding var topID: Double?
    let onSelectTrain: (TrainTime) -> Void
    let onSettle: (Double) -> Void
    let onRefresh: () async -> Void

    static func == (lhs: TrainRows, rhs: TrainRows) -> Bool {
        lhs.list.version == rhs.list.version && lhs.skipped == rhs.skipped && lhs.moves == rhs.moves
            && lhs.origin == rhs.origin && lhs.target == rhs.target
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
                            .padding(16)
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
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func rowView(_ row: TrainList.Row) -> some View {
        switch row.kind {
        case .routeChange(let name):
            HStack(spacing: 8) {
                Rectangle().fill(.tint).frame(height: 1)
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .fixedSize()
                Rectangle().fill(.tint).frame(height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("From here, trains run \(name)")
        case .train(let train, let allCells):
            let cells = Array(allCells.dropFirst(skipped))
            let late = train.isLive && list.delay != .none
            Button {
                onSelectTrain(train)
            } label: {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(CompactTimes.clockWithPeriod(train.time))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(late ? Color.yellow : Color.primary)
                        if train.isLive {
                            Text(late ? "Live · late" : "Live")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(late ? .yellow : .green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, arrival in
                        Text(arrival.map(CompactTimes.clockWithPeriod) ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(.rect)
                .opacity(row.isPast ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            // A train that has gone is shown for reference only.
            .disabled(row.isPast)
            .overlay(alignment: .bottom) {
                Divider().padding(.leading, 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(train, cells: allCells, isPast: row.isPast))
            .accessibilityHint(row.isPast ? "" : "Shows every stop")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func spoken(_ train: TrainTime, cells: [Date?], isPast: Bool) -> String {
        var parts = [(isPast ? "Departed " : "Departs ") + CompactTimes.clockWithPeriod(train.time) + (train.isLive ? ", live" : "")]
        for (stop, arrival) in zip(list.columns, cells) {
            if let arrival { parts.append("\(stop.name) \(CompactTimes.clockWithPeriod(arrival))") }
        }
        return parts.joined(separator: ", ")
    }
}
