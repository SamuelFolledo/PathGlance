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
    /// sheet covers that screen and leaves the tab bar showing, unlike the system's sheet
    /// which covers the whole window. Tapping the dimmed area, pulling down, the X and
    /// VoiceOver's escape gesture all close it.
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
                        .id(item.id)
                        .transition(style == .sheet ? .move(edge: .bottom).combined(with: .opacity) : .scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .animation(.snappy(duration: 0.3), value: item?.id)
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
    @State private var dragOffset: CGFloat = 0
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = verticalSizeClass == .compact
            // A phone on its side has little height: the sheet takes all of it.
            let openHeight = style == .popup ? nil : (isExpanded || isLandscape ? proxy.size.height - 8 : proxy.size.height * 0.58)

            VStack(spacing: 0) {
                header
                if style == .popup {
                    content
                        .padding([.horizontal, .bottom], 16)
                } else {
                    ScrollView {
                        content
                            .padding(.horizontal, 16)
                            // Room to scroll the last row clear of the tab bar.
                            .padding(.bottom, 96)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: 560)
            .frame(height: openHeight)
            // Solid, not glass: a sheet holds text, and the screen behind must not show through it.
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 28))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
            .padding(.horizontal, style == .popup ? 20 : 8)
            .offset(y: max(dragOffset, isExpanded ? 0 : -24))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style == .popup ? .center : .bottom)
            .animation(.snappy(duration: 0.3), value: isExpanded)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close() }
    }

    /// The grabber, title and X. Dragging here resizes or closes the sheet; the content
    /// below keeps its own scrolling.
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
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, style == .popup ? 14 : 0)
            .padding(.bottom, 8)
        }
        .contentShape(.rect)
        .gesture(style == .sheet ? drag : nil)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { value in
                let distance = value.predictedEndTranslation.height
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
}
