import SwiftUI

/// One tab of `UnderlineTabs`: a name, and optionally a second line under it.
struct UnderlineTab<ID: Hashable>: Identifiable {
    let id: ID
    var title: String
    /// Stacked under the title, never beside it.
    var detail: String?
    /// The detail's colour while the tab is selected. Unselected tabs are all grey.
    var detailColor: Color = .secondary
    /// What VoiceOver says for the title.
    var spokenTitle: String
}

/// Tabs as plain text on a hairline, the selected one underlined in the brand colour.
/// Not a segmented control and not pills.
struct UnderlineTabs<ID: Hashable>: View {
    let tabs: [UnderlineTab<ID>]
    let selection: ID?
    let onSelect: (ID) -> Void

    @Namespace private var underline

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(tabs) { tab in
                let isSelected = tab.id == selection
                Button {
                    onSelect(tab.id)
                } label: {
                    VStack(spacing: 1) {
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        if let detail = tab.detail {
                            Text(detail)
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? tab.detailColor : .secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.xs)
                    .padding(.bottom, Theme.Spacing.sm)
                    .contentShape(.rect)
                    .overlay(alignment: .bottom) {
                        if isSelected {
                            Rectangle()
                                .fill(Theme.Colors.brand)
                                .frame(height: 3)
                                .matchedGeometryEffect(id: "underline", in: underline)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.spokenTitle)
                .accessibilityValue(tab.detail ?? "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .background(alignment: .bottom) { Divider() }
        .animation(.snappy, value: selection)
    }
}
