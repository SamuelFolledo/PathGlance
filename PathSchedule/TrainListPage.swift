import SwiftUI

/// One destination's trains: days stacked top to bottom, each under a pinned header with
/// the date and the column names.
struct TrainListPage: View {
    let origin: Station
    let target: Station
    let isSelected: Bool
    let now: Date
    let arrivals: [RealtimeArrival]
    let dayTypes: DayTypeLog
    let onSelectTrain: (TrainTime) -> Void
    let onPickDate: () -> Void

    @EnvironmentObject private var model: AppModel
    @State private var list = TrainList()
    @State private var topID: Double?
    @State private var isBuilt = false
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
            // The departure column plus as many arrival columns as fit, always keeping the
            // destination (the last one).
            let fit = max(1, Int((proxy.size.width - 32) / columnWidth) - 1)
            let columns = Array(list.columns.suffix(fit))
            let skipped = list.columns.count - columns.count

            VStack(spacing: 0) {
                // The date and column names stay put above the list and follow the day
                // that is scrolled to the top.
                if let day = list.day(containing: topID) {
                    dayBar(day, columns: columns)
                }
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
                                rowView(row, skipped: skipped)
                                    .id(row.id)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $topID, anchor: .top)
                .onScrollPhaseChange { _, phase in
                    // Once scrolling settles, the other destinations' lists follow this one.
                    if phase == .idle, isSelected, let topID {
                        model.listAnchor = TrainList.time(of: topID)
                    }
                }
            }
        }
        .task(id: buildKey) {
            guard let schedule = model.schedule else { return }
            list = TrainList.build(schedule: schedule, origin: origin, target: target, favorites: model.favoriteStops,
                                   arrivals: arrivals, issues: model.issues.active, dayTypes: dayTypes, now: now)
            if !isBuilt {
                isBuilt = true
                topID = list.rowID(for: model.listAnchor)
            }
        }
        .onChange(of: model.listAnchor) { _, anchor in
            if !isSelected { topID = list.rowID(for: anchor) }
        }
        .onChange(of: model.jumpCount) {
            withAnimation(isSelected ? .snappy : nil) { topID = list.rowID(for: model.listAnchor) }
        }
    }

    // MARK: Rows

    /// Fixed above the list: the day at the top (tap for the calendar), any holiday
    /// warning, and the column names.
    private func dayBar(_ day: TrainList.Day, columns: [Station]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onPickDate) {
                HStack(spacing: 6) {
                    Text(day.title)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "calendar")
                        .font(.footnote)
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

    /// Where one day ends and the next begins in the list.
    private func dayHeading(_ day: TrainList.Day) -> some View {
        Text(day.title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func rowView(_ row: TrainList.Row, skipped: Int) -> some View {
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
                .opacity(row.isPast ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .bottom) {
                Divider().padding(.leading, 16)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(train, cells: allCells))
            .accessibilityHint("Shows every stop")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func spoken(_ train: TrainTime, cells: [Date?]) -> String {
        var parts = ["Departs \(CompactTimes.clockWithPeriod(train.time))" + (train.isLive ? ", live" : "")]
        for (stop, arrival) in zip(list.columns, cells) {
            if let arrival { parts.append("\(stop.name) \(CompactTimes.clockWithPeriod(arrival))") }
        }
        return parts.joined(separator: ", ")
    }
}
