import SwiftUI
import Combine

/// The live times every preview on the Widget tab draws from, fetched once for all of them.
@MainActor
final class PreviewFeed: ObservableObject {
    @Published private(set) var arrivals: [RealtimeArrival] = []
    @Published private(set) var now = Date()
    @Published private(set) var isRefreshing = false

    func refresh() async {
        isRefreshing = true
        now = Date()
        arrivals = await RealtimeFeed.fetch()
        isRefreshing = false
    }

    /// The board the widgets would draw right now from `station`.
    func board(model: AppModel, station: Station, style: WidgetStyle) -> Board? {
        guard let schedule = model.schedule else { return nil }
        var plan = BoardPlan(station: station, targets: BoardRules.widgetTargets(from: station, hidden: model.hiddenTargets),
                             schedule: schedule, now: now)
        plan.style = style
        plan.apply(realtime: arrivals, now: now)
        plan.apply(issues: model.issues.active, muted: model.mutedKinds)
        return plan.board(at: now)
    }
}

/// The rectangular lock screen widget, drawn in the app by the same view the widget uses
/// and at the widget's real size, then enlarged. That makes it accurate: the same number
/// of times fit here as on the lock screen. (The widget uses fixed type sizes, so neither
/// the phone's text size setting nor the app's text size slider changes it.)
///
/// It behaves like the widget too: the top row refreshes it, a line opens that
/// destination's trains. A change of look fades through.
struct WidgetPreviewCard: View {
    /// The look to draw: the one being edited, or a preset's own.
    let look: WidgetLook
    /// Only the chosen card is a control; its neighbours are pictures.
    var isInteractive = true
    var maxScale: CGFloat = 2.1

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var feed: PreviewFeed

    /// The rectangular lock screen widget's size in points: a little larger on the widest phones.
    static var widgetSize: CGSize {
        UIScreen.main.bounds.width >= 430 ? CGSize(width: 172, height: 76) : CGSize(width: 160, height: 72)
    }

    private var board: Board? {
        feed.board(model: model, station: model.station(nearest: location.station), style: look.style)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = WidgetPreviewCard.widgetSize
            let scale = min(proxy.size.width / size.width, maxScale)
            content
                .frame(width: size.width, height: size.height, alignment: .leading)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: WidgetPreviewCard.widgetSize.height * maxScale)
        .animation(Theme.Motion.content, value: look)
        .animation(Theme.Motion.content, value: board)
    }

    @ViewBuilder
    private var content: some View {
        if let board {
            BoardWidgetView(board: board, fetchedAt: feed.now, fontStyle: look.font, style: look.style) { headerRow in
                if isInteractive {
                    Button {
                        Task { await feed.refresh() }
                    } label: {
                        headerRow.opacity(feed.isRefreshing ? 0.4 : 1)
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
}

/// The round lock screen widget, drawn by the widget's own view at its real size and
/// then enlarged.
struct RoundPreviewCard: View {
    let look: RoundLook
    var scale: CGFloat = 1.6

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var feed: PreviewFeed

    /// The round lock screen widget's width in points: a little larger on the widest phones.
    static var widgetSize: CGFloat {
        UIScreen.main.bounds.width >= 430 ? 76 : 72
    }

    private var face: RoundFace? {
        feed.board(model: model, station: model.station(nearest: location.station), style: WidgetStyle())
            .flatMap { RoundFace.make(board: $0, content: look.content, line: model.roundLine, now: feed.now) }
    }

    var body: some View {
        let size = RoundPreviewCard.widgetSize
        RoundWidgetView(face: face, look: look)
            .frame(width: size, height: size)
            .background(.white.opacity(0.12), in: .circle)
            .scaleEffect(scale)
            .frame(width: size * scale, height: size * scale)
            .animation(Theme.Motion.content, value: look)
            .animation(Theme.Motion.content, value: face)
    }
}
