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

/// The one row every choice in a sheet is made of: a mark, a label, a hairline under it.
/// `RadioRow` and `CheckRow` only differ in the mark, so every list of choices looks alike.
private struct ChoiceRow<Label: View>: View {
    let symbol: String
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                label
                Spacer(minLength: 0)
            }
            .padding(.vertical, 11)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// One of several: the picked option carries the filled mark.
struct RadioRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        ChoiceRow(symbol: isSelected ? "largecircle.fill.circle" : "circle", isOn: isSelected, action: action) { label }
    }
}

/// Any number of several: a check mark that toggles.
struct CheckRow<Label: View>: View {
    let isOn: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        ChoiceRow(symbol: isOn ? "checkmark.circle.fill" : "circle", isOn: isOn, action: action) { label }
    }
}

/// A row that opens a sheet or popup: title, current value, and a chevron pointing right.
struct OpenRow: View {
    let title: String
    var value: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Pins `bar` above this scrolling screen with nothing behind it: the content scrolls
    /// up under the bar and fades out there, so it can still be made out around whatever
    /// the bar holds. Put it on the scroll view or list. (As usualspots pins Month / Week.)
    func pinnedBarTop<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaBar(edge: .top, spacing: 0) { bar() }
    }
}

/// A tab's name, small and centered like "From Journal Square" on Trains, with room for
/// one round button at the right.
struct TabTitle<Accessory: View>: View {
    let title: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.roundButton)
            .overlay(alignment: .trailing) { accessory }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, Theme.Spacing.sm)
    }
}

extension TabTitle where Accessory == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// A row that leaves the sheet for something else: mail, the share sheet, a web page.
/// A colored symbol, the title, and an arrow that says whether it leaves the app.
struct LinkRow: View {
    let title: String
    let symbol: String
    let color: Color
    var opensOutside = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LinkRowLabel(title: title, symbol: symbol, color: color, opensOutside: opensOutside)
        }
        .buttonStyle(.plain)
    }
}

/// What a `LinkRow` looks like, for controls such as `ShareLink` that bring their own button.
struct LinkRowLabel: View {
    let title: String
    let symbol: String
    let color: Color
    let opensOutside: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: opensOutside ? "arrow.up.right" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Theme.Spacing.row)
        .contentShape(.rect)
    }
}

/// A titled group in its own card that folds away. Open by default; folding is remembered
/// between launches under `id`. The whole title bar folds and unfolds it.
struct FoldCard<Content: View>: View {
    let id: String
    let title: String
    var value: String = ""
    @ViewBuilder let content: Content

    @EnvironmentObject private var model: AppModel

    private var isOpen: Bool { !model.foldedSections.contains(id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.Motion.sheet) {
                    if isOpen { model.foldedSections.insert(id) } else { model.foldedSections.remove(id) }
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.title3.weight(.bold))
                    Spacer()
                    if !isOpen {
                        Text(value)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                .padding(.vertical, Theme.Spacing.md)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("fold-\(id)")
            if isOpen {
                content
            }
        }
        .padding(.horizontal, Theme.Spacing.contentSide)
        .padding(.bottom, isOpen ? Theme.Spacing.sm : 0)
        .card()
    }
}

/// A switch whose whole row toggles it.
struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Toggle(title, isOn: $isOn)
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

/// A station as a round badge with its two or three characters, like a person's avatar.
struct StationBadge: View {
    let station: Station
    var size: CGFloat = 44

    var body: some View {
        Text(station.badge)
            .font(.system(size: size * (station.badge.count > 2 ? 0.3 : 0.4), weight: .bold, design: .rounded))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(.tint, in: .circle)
            .accessibilityLabel(station.name)
    }
}

/// The app's small round button: the X on a sheet, the arrows that step between trains,
/// an icon-only action beside a title.
struct RoundButton: View {
    let symbol: String
    let label: String
    var isOn = false
    /// For UI tests. Set here, on the button itself, so it names nothing else.
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .frame(width: Theme.Size.roundButton, height: Theme.Size.roundButton)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// A small colored dot that says something about a train or an issue at a glance.
struct StatusDot: View {
    let color: Color
    let label: String
    /// A character drawn inside, such as "!".
    var mark: String?

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: mark == nil ? Theme.Size.dot : 18, height: mark == nil ? Theme.Size.dot : 18)
            .overlay {
                if let mark {
                    Text(mark)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel(label)
    }
}
