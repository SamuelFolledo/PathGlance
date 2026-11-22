import SwiftUI

extension View {
    /// Explains this when it is pressed and held: a small popover with a title and one tip
    /// per line. Used in place of grey footnotes under sections. VoiceOver reads the tips
    /// as the hint.
    func infoPopover(_ title: String, _ tips: String...) -> some View {
        modifier(InfoPopoverModifier(title: title, tips: tips))
    }
}

private struct InfoPopoverModifier: ViewModifier {
    let title: String
    let tips: [String]
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: 0.35) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isShowing = true
            }
            .popover(isPresented: $isShowing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                    ForEach(tips, id: \.self) { tip in
                        Text(tip)
                            .font(.callout)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 220, maxWidth: 320, alignment: .leading)
                .padding(16)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityHint(tips.joined(separator: " "))
            .accessibilityAction(named: "More information") { isShowing = true }
    }
}

/// One of several: the picked option carries the check mark.
struct RadioRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                label
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Any number of several: a check mark that toggles.
struct CheckRow<Label: View>: View {
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                label
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A titled group that folds away, showing its current value when closed.
struct FoldSection<Content: View>: View {
    let title: String
    var value: String = ""
    @State var isOpen = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { isOpen.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            if isOpen {
                content
                    .padding(.leading, 4)
                    .padding(.bottom, 8)
            }
            Divider()
        }
    }
}
