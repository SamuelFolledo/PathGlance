import SwiftUI

/// What one banner says. Built by the screen that shows it; the banner itself knows
/// nothing about issues.
struct IssueBannerItem: Identifiable, Equatable {
    let id: String
    var symbol: String
    var color: Color
    var title: String
    var subtitle: String
    /// When it was last heard about: "8:40 PM".
    var time: String
}

/// One strip that says something is up: an icon, a title, a line under it, the time, and
/// an X that puts it away. Tapping anywhere but the X opens it.
struct IssueBanner: View {
    let item: IssueBannerItem
    let open: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: open) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: item.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(item.color)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !item.time.isEmpty {
                                Text(item.time)
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.leading, Theme.Spacing.md)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows the details")
            .accessibilityIdentifier("issueBanner")

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide until tomorrow")
            .accessibilityIdentifier("issueBannerDismiss")
        }
        .background(item.color.opacity(0.14), in: .rect(cornerRadius: Theme.Radius.banner))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.banner)
                .strokeBorder(item.color.opacity(0.45), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

/// Banners one at a time, a full width each: swipe sideways for the next, with dots under
/// them saying how many there are. Nothing shows when there are none.
struct IssueBannerStack: View {
    let items: [IssueBannerItem]
    let onOpen: (IssueBannerItem) -> Void
    /// Called after the X is tapped. The owner drops the item from `items`.
    let onDismiss: (IssueBannerItem) -> Void

    @State private var page: String?

    private var index: Int {
        items.firstIndex { $0.id == page } ?? 0
    }

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 6) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(items) { item in
                            IssueBanner(item: item, open: { onOpen(item) }, dismiss: { dismiss(item) })
                                .containerRelativeFrame(.horizontal)
                                .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .scrollIndicators(.hidden)
                .scrollDisabled(items.count < 2)
                // As tall as the tallest banner and no taller; each banner fills that.
                .fixedSize(horizontal: false, vertical: true)

                if items.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(items.indices, id: \.self) { dot in
                            Circle()
                                .fill(dot == index ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Notice \(index + 1) of \(items.count)")
                    .accessibilityIdentifier("issueBannerDots")
                }
            }
            .animation(Theme.Motion.content, value: items)
            .onChange(of: items.map(\.id)) { _, ids in
                if let page, !ids.contains(page) { self.page = ids.first }
            }
        }
    }

    /// The one after it takes its place, or the one before when it was the last.
    private func dismiss(_ item: IssueBannerItem) {
        if let at = items.firstIndex(of: item) {
            let next = items.indices.contains(at + 1) ? items[at + 1].id : (at > 0 ? items[at - 1].id : nil)
            page = next
        }
        onDismiss(item)
    }
}
