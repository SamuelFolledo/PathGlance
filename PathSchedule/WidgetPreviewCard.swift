import SwiftUI

/// The lock screen widget, drawn in the app by the same view the widget uses and at the
/// widget's real size, then enlarged to fill the row. That makes it accurate: the same
/// number of times fit here as on the lock screen. (The widget uses fixed type sizes, so
/// neither the phone's text size setting nor the app's text size slider changes it.)
///
/// Tapping it opens the widget's options. When an option changes what it shows, the change
/// is pointed out: words that are added appear green and settle, words that are removed
/// turn red and go.
struct WidgetPreviewCard: View {
    let onTap: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    /// The board before the last change, while the change is still being pointed out.
    @State private var previous: Board?
    @State private var settle: Task<Void, Never>?

    struct Piece: Hashable {
        enum Change { case none, added, removed }
        var text: String
        var change: Change = .none
    }

    /// The rectangular lock screen widget's size in points: a little larger on the widest phones.
    static var widgetSize: CGSize {
        UIScreen.main.bounds.width >= 430 ? CGSize(width: 172, height: 76) : CGSize(width: 160, height: 72)
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
        plan.apply(issues: model.issues.active, muted: model.mutedKinds)
        return plan.board(at: now)
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { proxy in
                let size = WidgetPreviewCard.widgetSize
                let scale = min(proxy.size.width / size.width, 2.2)
                content
                    .frame(width: size.width, height: size.height, alignment: .leading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: WidgetPreviewCard.widgetSize.height * min((UIScreen.main.bounds.width - 72) / WidgetPreviewCard.widgetSize.width, 2.2))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lock screen widget preview. " + (board?.lines.map(\.spokenText).joined(separator: ". ") ?? "No timetable yet"))
        .accessibilityHint("Opens the widget options")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("lockScreenPreview")
        .onChange(of: board) { old, _ in
            pointOutChange(from: old)
        }
        .task(id: station) {
            now = Date()
            if model.useRealtime { arrivals = await RealtimeFeed.fetch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let board {
            BoardWidgetView(board: board, fetchedAt: now, fontStyle: model.fontStyle, style: model.widgetStyle,
                            decorate: previous.map { old in { line, perLine, text in decorated(text, line: line, perLine: perLine, old: old) } },
                            header: { $0 }, tapArea: { _ in EmptyView() })
        } else {
            Text("Download the timetable to see the widget")
                .font(.system(size: 12))
        }
    }

    /// Keeps the old board around for a moment so the difference can be shown.
    private func pointOutChange(from old: Board?) {
        settle?.cancel()
        withAnimation(.snappy(duration: 0.25)) { previous = old }
        settle = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { previous = nil }
        }
    }

    /// One line's text with the words that differ from the same line of `old` colored.
    private func decorated(_ text: String, line: Int, perLine: Int, old: Board) -> AttributedString {
        let before = old.lines(perLine: perLine)
        let pieces = WidgetPreviewCard.merge(old: line < before.count ? before[line].text : "", new: text)
        var result = AttributedString()
        for (index, piece) in pieces.enumerated() {
            var part = AttributedString(piece.text + (index == pieces.count - 1 ? "" : " "))
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
