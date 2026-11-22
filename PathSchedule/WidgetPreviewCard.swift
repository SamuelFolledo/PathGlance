import SwiftUI

/// What the lock screen widget shows right now, drawn in the app. Tapping it opens the
/// widget's options. When an option changes what it shows, the change is pointed out:
/// text that is added appears green and settles, text that is removed turns red and goes.
struct WidgetPreviewCard: View {
    let onTap: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    /// The lines on screen, each a run of pieces that may be marked as just added or removed.
    @State private var shown: [[Piece]] = []
    @State private var settle: Task<Void, Never>?

    struct Piece: Hashable {
        enum Change { case none, added, removed }
        var text: String
        var change: Change = .none
    }

    private var station: Station {
        model.station(nearest: location.station)
    }

    private var board: Board? {
        guard let schedule = model.schedule else { return nil }
        var plan = BoardPlan(station: station, targets: BoardRules.widgetTargets(from: station, hidden: model.hiddenTargets),
                             schedule: schedule, now: now)
        plan.style = model.widgetStyle
        plan.apply(realtime: model.useRealtime ? arrivals : [], now: now)
        plan.apply(issues: model.issues.active, includePlannedWork: model.plannedWorkOnLockScreen)
        return plan.board(at: now)
    }

    /// The widget's text, line by line: the header, then the train lines.
    private var lines: [String] {
        guard let board else { return ["Download the timetable to see the widget"] }
        let header = "From \(board.station.shortName): \(CompactTimes.clockWithPeriod(now)) ↻" + (board.hasAlert ? " ⚠" : "")
        return [header] + (board.lines.isEmpty ? ["No upcoming trains"] : board.lines.map(\.text))
    }

    var body: some View {
        let isCompact = model.widgetStyle.density == .compact
        let headerFont: Font = model.fontStyle.font(size: isCompact ? 12 : 13)
        let lineFont: Font = model.fontStyle.font(size: isCompact ? 18 : 21)
        let lineCount: Int = max(shown.count - 1, 1)
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                if let header = shown.first {
                    Text(attributed(header))
                        .font(headerFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                // The train lines are one block of text, as on the widget, so they share a size.
                Text(trainLines)
                .font(lineFont)
                .lineLimit(lineCount)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock screen widget preview. " + lines.joined(separator: ". "))
        .accessibilityHint("Opens the widget options")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("lockScreenPreview")
        .onAppear { shown = lines.map { WidgetPreviewCard.pieces($0) } }
        .onChange(of: lines) { old, new in
            show(change: old, to: new)
        }
        .task(id: station) {
            now = Date()
            if model.useRealtime { arrivals = await RealtimeFeed.fetch() }
        }
    }

    /// Shows the old and new text merged, with what changed marked, then settles on the new.
    private func show(change old: [String], to new: [String]) {
        settle?.cancel()
        let count = max(old.count, new.count)
        withAnimation(.snappy(duration: 0.25)) {
            shown = (0..<count).map { index in
                WidgetPreviewCard.merge(old: index < old.count ? old[index] : "", new: index < new.count ? new[index] : "")
            }.filter { !$0.isEmpty }
        }
        settle = Task {
            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                shown = new.map { WidgetPreviewCard.pieces($0) }
            }
        }
    }

    private var trainLines: AttributedString {
        var joined = AttributedString()
        for (index, line) in shown.dropFirst().enumerated() {
            if index > 0 { joined += AttributedString("\n") }
            joined += attributed(line)
        }
        return joined
    }

    private func attributed(_ line: [Piece]) -> AttributedString {
        var result = AttributedString()
        for (index, piece) in line.enumerated() {
            var part = AttributedString(piece.text + (index == line.count - 1 ? "" : " "))
            switch piece.change {
            case .added: part.foregroundColor = .green
            case .removed:
                part.foregroundColor = .red
                part.strikethroughStyle = .single
            case .none: break
            }
            result += part
        }
        return result
    }

    // MARK: Comparing text

    static func pieces(_ line: String) -> [Piece] {
        line.split(separator: " ").map { Piece(text: String($0)) }
    }

    /// The words of `old` and `new` in one run: words only in `old` marked removed, words
    /// only in `new` marked added, the rest plain.
    static func merge(old: String, new: String) -> [Piece] {
        let before = old.split(separator: " ").map(String.init)
        let after = new.split(separator: " ").map(String.init)
        let difference = after.difference(from: before)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        var result: [Piece] = []
        var i = 0
        var j = 0
        while i < before.count || j < after.count {
            if i < before.count, removed.contains(i) {
                result.append(Piece(text: before[i], change: .removed))
                i += 1
            } else if j < after.count, inserted.contains(j) {
                result.append(Piece(text: after[j], change: .added))
                j += 1
            } else if j < after.count {
                result.append(Piece(text: after[j]))
                i += 1
                j += 1
            } else {
                i += 1
            }
        }
        return result
    }
}
