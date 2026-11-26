import SwiftUI

/// The row of dots under something that pages: one per page, the current one solid.
/// Hidden when there is only one page.
struct PageDots: View {
    let count: Int
    let index: Int
    /// What a page is called, for VoiceOver: "Notice 2 of 3".
    var noun = "Page"

    var body: some View {
        if count > 1 {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { dot in
                    Circle()
                        .fill(dot == index ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(noun) \(index + 1) of \(count)")
        }
    }
}

/// Cards in a row, one centred and its neighbours peeking in at both sides. Swipe, or tap
/// a neighbour, to choose; the choice snaps to the centre and dots under the row say where
/// you are. `peek` is how much room each side leaves for the neighbours.
///
/// The selection only changes once a swipe has come to rest, so whatever the choice
/// drives is not redone for every card that passes.
struct Carousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @Binding var selection: Item.ID
    var peek: CGFloat = 44
    var spacing: CGFloat = Theme.Spacing.md
    var noun = "Page"
    /// Draws one card. The flag says whether it is the chosen one.
    @ViewBuilder let card: (Item, Bool) -> Card

    @State private var position: Item.ID?

    private var index: Int {
        items.firstIndex { $0.id == (position ?? selection) } ?? 0
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(items) { item in
                        let isSelected = item.id == selection
                        card(item, isSelected)
                            .containerRelativeFrame(.horizontal)
                            .contentShape(.rect)
                            // The chosen card keeps its own controls; a neighbour is one button.
                            .onTapGesture {
                                if !isSelected { select(item.id) }
                            }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            // One card per swipe, however hard the flick.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $position)
            .safeAreaPadding(.horizontal, peek)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .idle, let position, position != selection { selection = position }
            }

            PageDots(count: items.count, index: index, noun: noun)
        }
        .onAppear { position = selection }
        .onChange(of: selection) { _, chosen in
            if chosen != position {
                withAnimation(.snappy) { position = chosen }
            }
        }
    }

    private func select(_ id: Item.ID) {
        withAnimation(.snappy) { position = id }
        selection = id
    }
}
