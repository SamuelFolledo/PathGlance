import SwiftUI
import UIKit

/// How a sheet sits on its screen.
enum AppSheetStyle {
    /// From the bottom edge: about half height, pull up for full, pull down to close.
    case sheet
    /// A small card in the middle of the screen, for one quick choice (a date).
    case popup
}

extension View {
    /// Presents `content` over this view and nothing else. Attached to a tab's screen, the
    /// sheet covers that screen and runs on underneath the tab bar, which stays in view
    /// and in reach.
    ///
    /// Dragging works the way a system sheet does, and there is only ever one gesture: the
    /// content's own scroll drag (`SheetScrollBridge`). At half height it moves the sheet,
    /// up to full height or down to close. At full height it scrolls the content, and once
    /// the content is at its top a pull down takes the sheet with it. A drag never also
    /// taps what it started on. The grabber and title drag the sheet too; tapping the
    /// dimmed area, the X and VoiceOver's escape gesture close it.
    ///
    /// `subtitle` says under the title what the sheet is for. `accessory` puts a control
    /// beside the X.
    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        style: AppSheetStyle = .sheet,
        title: @escaping (Item) -> String,
        subtitle: @escaping (Item) -> String? = { _ in nil },
        accessory: @escaping (Item) -> AnyView? = { _ in nil },
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AppSheetModifier(item: item, style: style, title: title, subtitle: subtitle, accessory: accessory, sheetContent: content))
    }
}

private struct AppSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let style: AppSheetStyle
    let title: (Item) -> String
    let subtitle: (Item) -> String?
    let accessory: (Item) -> AnyView?
    let sheetContent: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(item != nil)
            .overlay {
                ZStack {
                    if let item {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .contentShape(.rect)
                            .onTapGesture { close() }
                            .accessibilityHidden(true)
                            .transition(.opacity)
                        AppSheetCard(style: style, title: title(item), subtitle: subtitle(item), accessory: accessory(item), close: close) {
                            sheetContent(item)
                        }
                        // One card per kind of sheet, so content that changes inside it
                        // (the next train's stops) does not slide the sheet away and back.
                        .transition(style == .sheet ? .move(edge: .bottom).combined(with: .opacity) : .scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                // While it fades out, the sheet no longer takes touches meant for what is under it.
                .allowsHitTesting(item != nil)
                .animation(Theme.Motion.sheet, value: item != nil)
            }
    }

    private func close() {
        item = nil
    }
}

private struct AppSheetCard<Content: View>: View {
    let style: AppSheetStyle
    let title: String
    let subtitle: String?
    let accessory: AnyView?
    let close: () -> Void
    @ViewBuilder let content: Content

    /// Pulled up to full height.
    @State private var isExpanded = false
    /// How far the finger has moved the card from where it rests (down is positive).
    @State private var drag: CGFloat = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { proxy in
            if style == .popup {
                popup
            } else {
                sheet(in: proxy)
            }
        }
        // A container of its own, so its traits and escape action do not get mixed up
        // with those of a control inside it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    private var popup: some View {
        VStack(spacing: 0) {
            header
            content
                .padding([.horizontal, .bottom], Theme.Spacing.contentSide)
        }
        .frame(maxWidth: 420)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Theme.Radius.sheet))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The card is always laid out at full height and only ever moved, never resized,
    /// so following the finger costs nothing.
    private func sheet(in proxy: GeometryProxy) -> some View {
        let bottomInset = proxy.safeAreaInsets.bottom
        // A phone on its side has little height: the sheet is always full height there.
        let onlyFull = verticalSizeClass == .compact
        let full = proxy.size.height + bottomInset - Theme.Spacing.sm
        let halfRest = onlyFull ? 0 : full - (proxy.size.height * 0.56 + bottomInset)
        let rest = isExpanded || onlyFull ? 0 : halfRest
        // It does not go above full height.
        let offset = max(rest + drag, -Theme.Spacing.sm)

        return VStack(spacing: 0) {
            header
                .gesture(headerDrag(full: full, halfRest: halfRest))
            ScrollView {
                content
                    .padding(.horizontal, Theme.Spacing.contentSide)
                    // The card runs under the tab bar; the content stops above it.
                    .padding(.bottom, bottomInset + Theme.Spacing.lg)
                    .background(SheetScrollBridge(
                        cardFollowsEveryDrag: !(isExpanded || onlyFull),
                        onDrag: { drag = $0 },
                        onEnd: { settle(translation: $0, velocity: $1, full: full, halfRest: halfRest) }
                    ))
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: 560)
        .frame(height: full, alignment: .top)
        .background(Color(.secondarySystemBackground), in: .rect(topLeadingRadius: Theme.Radius.sheet, topTrailingRadius: Theme.Radius.sheet))
        .shadow(color: .black.opacity(0.25), radius: 24, y: -4)
        // Placed by layout, not by a drawing offset, so what is touched is always what is seen.
        .padding(.top, Theme.Spacing.sm + offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .bottom)
    }

    /// The grabber, title, what the sheet is for, any accessory, and the X.
    private var header: some View {
        VStack(spacing: 6) {
            if style == .sheet {
                Capsule()
                    .fill(.secondary)
                    .frame(width: 36, height: 5)
                    .padding(.top, Theme.Spacing.sm)
                    .accessibilityHidden(true)
            }
            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let accessory { accessory }
                RoundButton(symbol: "xmark", label: "Close", action: close)
            }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, style == .popup ? 14 : 0)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .contentShape(.rect)
    }

    private func headerDrag(full: CGFloat, halfRest: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag = $0.translation.height }
            .onEnded { settle(translation: $0.translation.height, velocity: $0.velocity.height, full: full, halfRest: halfRest) }
    }

    /// Where the card comes to rest after being let go. A flick decides by its direction:
    /// down goes one step down (full to half, half to closed), up goes to full. A slow
    /// release goes to whichever resting place is nearest.
    private func settle(translation: CGFloat, velocity: CGFloat, full: CGFloat, halfRest: CGFloat) {
        let rest = isExpanded ? 0 : halfRest
        let position = rest + translation
        let hasHalf = halfRest > 0
        let target: SheetRest
        if velocity > 500 {
            target = isExpanded && hasHalf ? .half : .closed
        } else if velocity < -500 {
            target = .expanded
        } else if !hasHalf {
            target = position > full * 0.35 ? .closed : .expanded
        } else if position < halfRest / 2 {
            target = .expanded
        } else if position < halfRest + (full - halfRest) * 0.4 {
            target = .half
        } else {
            target = .closed
        }
        withAnimation(Theme.Motion.sheet) {
            drag = 0
            switch target {
            case .expanded: isExpanded = true
            case .half: isExpanded = false
            case .closed: close()
            }
        }
    }
}

/// Where a sheet can come to rest.
private enum SheetRest {
    case expanded, half, closed
}

/// Lets a sheet follow drags on its content the way a system sheet does, by listening to
/// the content scroll view's own pan gesture. There is no second gesture competing with
/// it, which is what makes a card stutter or move the wrong way. The content scrolls until
/// the drag is the card's; from then on the content is held still and the card moves:
///
/// - while the card is at half height, every drag is the card's;
/// - at full height, a pull down from the content's top is the card's.
///
/// Because it is the scroll view's pan, a drag cancels the touch on whatever row or button
/// it started on, so nothing is tapped by a swipe.
private struct SheetScrollBridge: UIViewRepresentable {
    let cardFollowsEveryDrag: Bool
    let onDrag: (CGFloat) -> Void
    let onEnd: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.onWindow = { [weak coordinator = context.coordinator] probe in
            coordinator?.attach(from: probe)
        }
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        context.coordinator.cardFollowsEveryDrag = cardFollowsEveryDrag
        context.coordinator.onDrag = onDrag
        context.coordinator.onEnd = onEnd
    }

    final class ProbeView: UIView {
        var onWindow: ((UIView) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { onWindow?(self) }
        }
    }

    final class Coordinator: NSObject {
        var cardFollowsEveryDrag = false
        var onDrag: (CGFloat) -> Void = { _ in }
        var onEnd: (CGFloat, CGFloat) -> Void = { _, _ in }

        private weak var scrollView: UIScrollView?
        /// The card is following this drag.
        private var cardOwns = false
        /// The finger's translation when the card took over.
        private var baseline: CGFloat = 0
        /// Where the content is held while the card moves.
        private var heldOffset: CGFloat = 0

        func attach(from probe: UIView) {
            guard scrollView == nil else { return }
            var view = probe.superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let found = view as? UIScrollView else { return }
            scrollView = found
            found.panGestureRecognizer.addTarget(self, action: #selector(pan(_:)))
        }

        @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
            guard let scrollView else { return }
            let translation = recognizer.translation(in: scrollView.superview).y
            let top = -scrollView.adjustedContentInset.top

            switch recognizer.state {
            case .began:
                cardOwns = false
                heldOffset = scrollView.contentOffset.y
            case .changed:
                if !cardOwns {
                    let atTop = scrollView.contentOffset.y <= top + 0.5
                    if cardFollowsEveryDrag {
                        cardOwns = true
                        baseline = 0
                    } else if atTop && translation > 0 {
                        cardOwns = true
                        baseline = translation
                        heldOffset = top
                    }
                }
                if cardOwns {
                    scrollView.contentOffset.y = heldOffset
                    onDrag(translation - baseline)
                }
            case .ended, .cancelled, .failed:
                guard cardOwns else { return }
                cardOwns = false
                // Stop the scroll view coasting on with the release.
                scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: heldOffset), animated: false)
                onEnd(translation - baseline, recognizer.velocity(in: scrollView.superview).y)
            default:
                break
            }
        }
    }
}
