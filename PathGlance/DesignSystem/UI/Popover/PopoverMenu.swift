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

/// A small button at the end of a popover row that does its own thing: tapping it does
/// not pick the row, and does not close the popover.
struct PopoverAccessory {
    let symbol: String
    var isOn = false
    let label: String
    var identifier = ""
    let action: () -> Void
}

/// One of several that stays picked: a radio mark, then the label. An `accessory` sits
/// after it as a separate button.
struct PopoverRadioRow: View {
    let title: String
    var detail: String?
    let isOn: Bool
    var accessory: PopoverAccessory?
    /// For UI tests, on the row's own button. (An identifier put on the whole row would
    /// land on the accessory too.)
    var identifier = ""
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
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
                .padding(.leading, Theme.Spacing.contentSide)
                .padding(.trailing, accessory == nil ? Theme.Spacing.contentSide : Theme.Spacing.xs)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier(identifier)
            if let accessory {
                Button(action: accessory.action) {
                    Image(systemName: accessory.symbol)
                        .foregroundStyle(accessory.isOn ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                        .frame(width: 44, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.trailing, Theme.Spacing.xs)
                .accessibilityLabel(accessory.label)
                .accessibilityAddTraits(accessory.isOn ? .isSelected : [])
                .accessibilityIdentifier(accessory.identifier)
            }
        }
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
