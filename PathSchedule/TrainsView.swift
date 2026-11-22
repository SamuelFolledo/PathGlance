import SwiftUI

/// The home tab: the station as the title, then one panel with destination tabs and the
/// date fixed on top and the trains scrolling beneath, day after day. Swiping sideways
/// turns to the next destination at the same time of the same day.
struct TrainsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService

    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    @State private var dayTypes = DayTypeLog()
    @State private var sheet: Sheet?
    @State private var datePicker: DatePick?
    /// The page the sideways scroll is on.
    @State private var page: Station?

    private enum Sheet: Identifiable {
        case favorites
        /// One train's stops, with the day's other trains to step through.
        case stops(TrainTime, target: Station, trains: [TrainTime])

        /// One id per kind: stepping to the next train changes the sheet's content in place.
        var id: String {
            switch self {
            case .favorites: return "favorites"
            case .stops: return "stops"
            }
        }
    }

    private struct DatePick: Identifiable {
        let id = "date"
    }

    private var origin: Station {
        model.station(nearest: location.station)
    }

    private func destinations(_ schedule: ScheduleData) -> [Station] {
        BoardRules.destinations(from: origin, hidden: model.hiddenTargets, schedule: schedule)
    }

    private func selected(in destinations: [Station]) -> Station? {
        if let chosen = model.browseTarget, destinations.contains(chosen) { return chosen }
        return destinations.first
    }

    /// Scrolled well away from the present: time to offer a way back.
    private var isAway: Bool {
        abs(model.listAnchor.timeIntervalSince(now)) > 3 * 60 * 60
    }

    var body: some View {
        VStack(spacing: 8) {
            title
            if let schedule = model.schedule {
                panel(schedule)
            } else {
                emptyState
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            if isAway {
                Button {
                    model.jump(to: Date())
                } label: {
                    Label("Now", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                        .frame(height: 36)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .accessibilityLabel("Back to now")
                .accessibilityIdentifier("backToNow")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isAway)
        .appSheet(item: $sheet, title: sheetTitle) { sheet in
            switch sheet {
            case .favorites:
                FavoriteStopsView()
            case .stops(let train, let target, let trains):
                if let schedule = model.schedule {
                    StopsView(schedule: schedule, origin: origin, target: target, train: train, trains: trains) { other in
                        self.sheet = .stops(other, target: target, trains: trains)
                    }
                }
            }
        }
        .appSheet(item: $datePicker, style: .popup, title: { _ in "Go to date" }) { _ in
            DateJumpView(now: now, viewing: model.listAnchor) { date in
                datePicker = nil
                model.jump(to: date)
            }
        }
        .task(id: origin) {
            await reload()
        }
        .task {
            // Keep "now" and the live times fresh while the app is open.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                await reload()
            }
        }
        .onChange(of: model.resetCount[.trains]) {
            sheet = nil
            datePicker = nil
        }
        .onChange(of: model.favoritesRequests) {
            datePicker = nil
            sheet = .favorites
        }
    }

    private func sheetTitle(_ sheet: Sheet) -> String {
        switch sheet {
        case .favorites: return "Favorite stops"
        case .stops(let train, let target, _): return "\(CompactTimes.clockWithPeriod(train.time)) to \(target.shortName)"
        }
    }

    private func reload() async {
        now = Date()
        dayTypes = DayTypeLog.load()
        if model.useRealtime {
            arrivals = await RealtimeFeed.fetch()
        }
    }

    // MARK: Pieces

    /// "From Journal Square", centered. Tap for the station list and favorite stops.
    private var title: some View {
        StationMenu(onEditFavorites: model.editFavorites) {
            HStack(spacing: 4) {
                Text("From \(origin.name)")
                    .font(.title3.weight(.bold))
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("From \(origin.name). Change station")
        .accessibilityIdentifier("originMenu")
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Destination tabs fixed at the top of one surface, the lists paging beneath.
    private func panel(_ schedule: ScheduleData) -> some View {
        let destinations = destinations(schedule)
        let current = selected(in: destinations)

        return VStack(spacing: 0) {
            Picker("Destination", selection: Binding(
                get: { current ?? origin },
                set: { target in
                    model.browseTarget = target
                    withAnimation(.snappy) { page = target }
                }
            )) {
                ForEach(destinations) { station in
                    Text(station.lineLabel)
                        .accessibilityLabel(station.name)
                        .tag(station)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("destinationPicker")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(destinations, id: \.self) { target in
                        TrainListPage(origin: origin, target: target, isSelected: target == current, now: now,
                                      arrivals: arrivals, dayTypes: dayTypes,
                                      onSelectTrain: { train, trains in sheet = .stops(train, target: target, trains: trains) },
                                      onPickDate: { datePicker = DatePick() },
                                      onRefresh: {
                                          await reload()
                                          await model.refreshIssues()
                                      })
                            .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                // Only once the swipe has come to rest: changing the selection while the
                // page is still moving stops it and it springs back.
                if phase == .idle, let page, page != current { model.browseTarget = page }
            }
            .onChange(of: model.browseTarget) { _, target in
                // A widget line was tapped.
                if let target, target != page { page = target }
            }
            .onChange(of: origin) {
                page = selected(in: self.destinations(schedule))
            }
            .onAppear {
                if page == nil { page = current }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(topLeadingRadius: 24, topTrailingRadius: 24))
        .padding(.horizontal, 12)
        .ignoresSafeArea(edges: .bottom)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if model.isImporting {
                ProgressView("Downloading the timetable")
            } else {
                Text("No timetable yet.")
                    .foregroundStyle(.secondary)
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button("Download timetable") {
                Task { await model.downloadSchedule() }
            }
            .buttonStyle(.glassProminent)
            .disabled(model.isImporting)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Every stop one train makes, with its arrival time. The arrows, or a sideways swipe,
/// step to the train before or after it.
struct StopsView: View {
    let schedule: ScheduleData
    let origin: Station
    let target: Station
    let train: TrainTime
    /// The list this train came from, in order.
    let trains: [TrainTime]
    let show: (TrainTime) -> Void

    @EnvironmentObject private var model: AppModel

    private var index: Int? { trains.firstIndex(of: train) }

    private func step(_ offset: Int) {
        guard let index, trains.indices.contains(index + offset) else { return }
        show(trains[index + offset])
    }

    private func canStep(_ offset: Int) -> Bool {
        guard let index else { return false }
        return trains.indices.contains(index + offset)
    }

    var body: some View {
        let stops = schedule.stops(of: train, from: origin)
        let route = schedule.routeName(of: train, from: origin)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                stepButton(-1, symbol: "chevron.left", label: "Earlier train")
                Spacer()
                VStack(spacing: 2) {
                    Text(PathFormat.day(train.time))
                        .font(.subheadline.weight(.semibold))
                    Text((route.isEmpty ? "" : "To \(route)") + (train.isLive ? " · live" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stepButton(1, symbol: "chevron.right", label: "Later train")
            }
            .padding(.bottom, 8)
            stopRow(name: origin.name, time: train.time, isFavorite: false, isEnd: false, isOrigin: true)
            ForEach(stops, id: \.station) { stop in
                stopRow(name: stop.station.name, time: stop.time,
                        isFavorite: model.favoriteStops.contains(stop.station),
                        isEnd: stop.station == target, isOrigin: false)
            }
            if stops.isEmpty {
                Text("Stop times are not available for this train.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .contentShape(.rect)
        // Sideways only, so a vertical drag still scrolls or moves the sheet.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { drag in
                guard abs(drag.translation.width) > 60, abs(drag.translation.width) > abs(drag.translation.height) * 2 else { return }
                step(drag.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func stepButton(_ offset: Int, symbol: String, label: String) -> some View {
        Button {
            step(offset)
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!canStep(offset))
        .accessibilityLabel(label)
        .accessibilityIdentifier(offset < 0 ? "earlierTrain" : "laterTrain")
    }

    private func stopRow(name: String, time: Date, isFavorite: Bool, isEnd: Bool, isOrigin: Bool) -> some View {
        HStack {
            Image(systemName: isOrigin ? "circle.fill" : (isEnd ? "mappin.circle.fill" : "circle"))
                .font(.caption)
                .foregroundStyle(isOrigin || isEnd ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(name)
                .fontWeight(isOrigin || isEnd ? .semibold : .regular)
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
            Spacer()
            Text(CompactTimes.clockWithPeriod(time))
                .monospacedDigit()
                .foregroundStyle(isOrigin || isEnd ? .primary : .secondary)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }
}

/// A month calendar for jumping the list to another day. It opens on the day being
/// viewed, which is highlighted; today keeps its own mark.
struct DateJumpView: View {
    let now: Date
    let onPick: (Date) -> Void

    @State private var date: Date

    init(now: Date, viewing: Date, onPick: @escaping (Date) -> Void) {
        self.now = now
        self.onPick = onPick
        _date = State(initialValue: viewing)
    }

    private var range: ClosedRange<Date> {
        let calendar = PathTime.calendar
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -AppModel.daysBack, to: today) ?? today
        let last = calendar.date(byAdding: .day, value: AppModel.daysAhead + 1, to: today)?.addingTimeInterval(-1) ?? today
        return first...last
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Date", selection: $date, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.timeZone, PathTime.calendar.timeZone)
                .environment(\.calendar, PathTime.calendar)
                .onChange(of: date) { _, picked in
                    // Today lands on the next train; any other day on its first.
                    let isToday = PathTime.ymd(of: picked) == PathTime.ymd(of: now)
                    onPick(isToday ? Date() : PathTime.calendar.startOfDay(for: picked))
                }
            Button {
                onPick(Date())
            } label: {
                Label("Back to now", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.glass)
        }
    }
}
