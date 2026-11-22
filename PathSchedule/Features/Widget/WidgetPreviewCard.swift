import SwiftUI

/// The lock screen widget, drawn in the app by the same view the widget uses and at the
/// widget's real size, then enlarged. That makes it accurate: the same number of times fit
/// here as on the lock screen. (The widget uses fixed type sizes, so neither the phone's
/// text size setting nor the app's text size slider changes it.)
///
/// It behaves like the widget too: the top row refreshes it, a line opens that
/// destination's trains. A change of look fades through.
struct WidgetPreviewCard: View {
    /// The look to draw. The Widget tab passes the one being edited; a preset row passes its own.
    let look: WidgetLook
    /// Presets are pictures, not controls.
    var isInteractive = true
    var maxScale: CGFloat = 2.1

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @State private var arrivals: [RealtimeArrival] = []
    @State private var now = Date()
    @State private var isRefreshing = false

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
        plan.style = look.style
        plan.apply(realtime: arrivals, now: now)
        plan.apply(issues: model.issues.active, muted: model.mutedKinds)
        return plan.board(at: now)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = WidgetPreviewCard.widgetSize
            let scale = min(proxy.size.width / size.width, maxScale)
            content
                .frame(width: size.width, height: size.height, alignment: .leading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: isInteractive ? .center : .leading)
        }
        .frame(height: WidgetPreviewCard.widgetSize.height * maxScale)
        .animation(Theme.Motion.content, value: look)
        .animation(Theme.Motion.content, value: board)
        .task(id: station) { await refresh() }
    }

    @ViewBuilder
    private var content: some View {
        if let board {
            BoardWidgetView(board: board, fetchedAt: now, fontStyle: look.font, style: look.style) { headerRow in
                if isInteractive {
                    Button {
                        Task { await refresh() }
                    } label: {
                        headerRow.opacity(isRefreshing ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Refresh the preview")
                    .accessibilityIdentifier("previewRefresh")
                } else {
                    headerRow
                }
            } tapArea: { line in
                if isInteractive, let target = line.target {
                    Button {
                        model.open(origin: board.station, target: target)
                    } label: {
                        Color.clear.contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows these trains")
                }
            }
        } else {
            Text("Download the timetable to see the widget")
                .font(.system(size: 12))
        }
    }

    private func refresh() async {
        isRefreshing = true
        now = Date()
        arrivals = await RealtimeFeed.fetch()
        isRefreshing = false
    }
}
