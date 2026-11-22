import SwiftUI

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
    /// and in reach; the content is inset so its last row scrolls clear of the bar.
    ///
    /// Dragging works the way a system sheet does. At half height any vertical drag moves
    /// the sheet: up to full height, down to close. At full height the content scrolls,
    /// and once it is at its top a pull down takes the sheet with it. Tapping the dimmed
    /// area, the X and VoiceOver's escape gesture also close it.
    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        style: AppSheetStyle = .sheet,
        title: @escaping (Item) -> String,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(AppSheetModifier(item: item, style: style, title: title, sheetContent: content))
    }
}

private struct AppSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let style: AppSheetStyle
    let title: (Item) -> String
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
                        AppSheetCard(style: style, title: title(item), close: close) {
                            sheetContent(item)
                        }
                        // One card per kind of sheet, so content that changes inside it
                        // (the next train's stops) does not slide the sheet away and back.
                        .transition(style == .sheet ? .move(edge: .bottom).combined(with: .opacity) : .scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.3), value: item != nil)
            }
    }

    private func close() {
        item = nil
    }
}

private struct AppSheetCard<Content: View>: View {
    let style: AppSheetStyle
    let title: String
    let close: () -> Void
    @ViewBuilder let content: Content

    /// Pulled up to full height.
    @State private var isExpanded = false
    /// How far the finger has moved the card down from rest.
    @State private var dragOffset: CGFloat = 0
    /// The content is scrolled to its very top.
    @State private var isAtTop = true
    /// The content drag in progress is moving the card, not scrolling.
    @State private var isCardDrag = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let isLandscape = verticalSizeClass == .compact
            let full = proxy.size.height + bottomInset - 8
            // A phone on its side has little height: the sheet takes all of it.
            let height = isExpanded || isLandscape ? full : proxy.size.height * 0.56 + bottomInset

            Group {
                if style == .popup {
                    VStack(spacing: 0) {
                        header
                        content
                            .padding([.horizontal, .bottom], 16)
                    }
                    .frame(maxWidth: 420)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        header
                        ScrollView {
                            content
                                .padding(.horizontal, 16)
                                // The card runs under the tab bar; the content stops above it.
                                .padding(.bottom, bottomInset + 16)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        // At half height a drag resizes the sheet, so the content waits.
                        .scrollDisabled(!(isExpanded || isLandscape) || isCardDrag)
                        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y <= 0.5 } action: { _, atTop in
                            isAtTop = atTop
                        }
                        .simultaneousGesture(contentDrag(canScroll: isExpanded || isLandscape))
                    }
                    .frame(maxWidth: 560)
                    .frame(height: max(height - max(dragOffset, -24), 120), alignment: .top)
                    .background(Color(.secondarySystemBackground), in: .rect(topLeadingRadius: 28, topTrailingRadius: 28))
                    .shadow(color: .black.opacity(0.25), radius: 24, y: -4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .animation(.snappy(duration: 0.3), value: isExpanded)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    /// The grabber, title and X. Dragging here always moves the sheet.
    private var header: some View {
        VStack(spacing: 6) {
            if style == .sheet {
                Capsule()
                    .fill(.secondary)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
            HStack {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, style == .popup ? 14 : 0)
            .padding(.bottom, 8)
        }
        .contentShape(.rect)
        .gesture(style == .sheet ? headerDrag : nil)
    }

    private var headerDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { settle(predicted: $0.predictedEndTranslation.height) }
    }

    /// A drag that starts on the content. It moves the card when the content cannot use
    /// it: at half height always, at full height only for a pull down from the top.
    private func contentDrag(canScroll: Bool) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let vertical = abs(value.translation.height) > abs(value.translation.width)
                if !isCardDrag {
                    guard vertical else { return }
                    let pullsDownFromTop = isAtTop && value.translation.height > 0
                    guard !canScroll || pullsDownFromTop else { return }
                    isCardDrag = true
                }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard isCardDrag else { return }
                isCardDrag = false
                settle(predicted: value.predictedEndTranslation.height)
            }
    }

    private func settle(predicted distance: CGFloat) {
        withAnimation(.snappy(duration: 0.3)) {
            dragOffset = 0
            if distance < -60 {
                isExpanded = true
            } else if distance > 60 {
                if isExpanded { isExpanded = false } else { close() }
            }
        }
    }
}
