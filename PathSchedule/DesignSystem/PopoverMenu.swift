import SwiftUI

/// The app's popover menus: a short list that points at what opened it. Choices that
/// stay picked are `PopoverRadioRow`s; things that happen once are `PopoverActionRow`s.
/// Sections get a small title only when there is more than one.
struct PopoverMenu<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(minWidth: 240, maxWidth: 300, maxHeight: 480)
        .presentationCompactAdaptation(.popover)
    }
}

struct PopoverSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One of several that stays picked: a radio mark, then the label.
struct PopoverRadioRow: View {
    let title: String
    var detail: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(title)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Something that happens once: the label, then its icon.
struct PopoverActionRow: View {
    let title: String
    let symbol: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(title)
                Spacer(minLength: 0)
                Image(systemName: symbol)
            }
            .foregroundStyle(isDestructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
