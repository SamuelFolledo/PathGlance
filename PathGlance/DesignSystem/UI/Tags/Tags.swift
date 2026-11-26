import SwiftUI

/// A small rounded label: why something is shown, which line, whether it is still open.
struct Tag: View {
    let text: String
    var color: Color = .secondary
    /// Tinted background and text in `color`; otherwise a quiet grey chip.
    var isStrong = false
    var symbol: String?
    /// A colored dot before the text, such as a line's color.
    var dot: Color?

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 8, height: 8)
            }
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isStrong ? AnyShapeStyle(color) : AnyShapeStyle(.primary))
        }
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(isStrong ? AnyShapeStyle(color.opacity(0.16)) : AnyShapeStyle(Color(.tertiarySystemFill)), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

/// Lays tags out in rows, starting a new row when the next one does not fit.
struct TagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if size.width == 0 && size.height == 0 { continue }
            if var last = rows.last, last.width + spacing + size.width <= width {
                last.items.append(index)
                last.width += spacing + size.width
                last.height = max(last.height, size.height)
                rows[rows.count - 1] = last
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}
