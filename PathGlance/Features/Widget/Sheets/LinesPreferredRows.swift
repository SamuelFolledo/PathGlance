import SwiftUI
import UIKit

/// A row per line: a handle to drag it up or down, and a check to show or hide it. The
/// order leads the destination tabs, the rectangle widget's rows and the round widget's
/// first line; turning one off removes it from all three. One list, kept in `AppModel`.
struct LinesPreferredRows: View {
    @EnvironmentObject private var model: AppModel
    /// The order on screen. It follows the finger during a drag and is saved when the
    /// drag ends, so the widgets reload once and not at every step.
    @State private var order: [Station] = []
    @State private var dragging: Station?
    @State private var startIndex = 0
    @State private var translation: CGFloat = 0
    @State private var rowHeight: CGFloat = 48
    /// True while a finger is on a handle. It falls back by itself when the drag ends or
    /// is taken away by the system, so a row is never left hanging mid-drag.
    @GestureState private var isHandleHeld = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(order.isEmpty ? model.lineOrder : order) { station in
                row(station)
            }
        }
        .onAppear { order = model.lineOrder }
        .onChange(of: model.lineOrder) { _, saved in
            if dragging == nil { order = saved }
        }
        .onChange(of: isHandleHeld) { _, held in
            if !held { finishDrag() }
        }
        .sensoryFeedback(.selection, trigger: order)
    }

    private func row(_ station: Station) -> some View {
        let index = order.firstIndex(of: station) ?? 0
        let isDragging = dragging == station
        return HStack(spacing: 2) {
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 44)
                .contentShape(.rect)
                .gesture(drag(station))
                .accessibilityLabel("Reorder trains to \(station.name)")
                .accessibilityHint("Drag up or down")
                .accessibilityIdentifier("lineHandle-\(station.rawValue)")
            // In a stack of its own, so the hairline under the row lies flat.
            VStack(spacing: 0) {
                CheckRow(isOn: !model.hiddenTargets.contains(station)) {
                    toggle(station)
                } label: {
                    Text("Trains to \(station.name)")
                }
                .accessibilityIdentifier("line-\(station.rawValue)")
            }
        }
        .background(isDragging ? AnyShapeStyle(Color(.tertiarySystemFill)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = max($0, 1) }
        // The row has already moved `index - startIndex` places in the layout; the rest
        // of the finger's travel is made up here.
        .offset(y: isDragging ? translation - CGFloat(index - startIndex) * rowHeight : 0)
        .zIndex(isDragging ? 1 : 0)
        .infoPopover("Trains to \(station.name)",
                     "Drag the handle to put the line you care about first. The first line leads the tabs and the widgets.",
                     "Off: these trains leave the widgets and the destination tabs.",
                     "A station whose only line is turned off still shows it.")
        .accessibilityAction(named: "Move up") { move(station, by: -1) }
        .accessibilityAction(named: "Move down") { move(station, by: 1) }
    }

    private func drag(_ station: Station) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($isHandleHeld) { _, held, _ in held = true }
            .onChanged { value in
                if dragging != station {
                    dragging = station
                    startIndex = order.firstIndex(of: station) ?? 0
                }
                translation = value.translation.height
                let wanted = min(max(startIndex + Int((translation / rowHeight).rounded()), 0), order.count - 1)
                if let current = order.firstIndex(of: station), wanted != current {
                    withAnimation(.snappy(duration: 0.2)) {
                        order.move(fromOffsets: IndexSet(integer: current), toOffset: wanted > current ? wanted + 1 : wanted)
                    }
                }
            }
            .onEnded { _ in finishDrag() }
    }

    /// The row settles where it was dropped and the order is saved. Safe to call twice.
    private func finishDrag() {
        guard dragging != nil else { return }
        withAnimation(.snappy(duration: 0.2)) {
            dragging = nil
            translation = 0
        }
        model.lineOrder = order
    }

    private func move(_ station: Station, by step: Int) {
        var changed = model.lineOrder
        guard let current = changed.firstIndex(of: station) else { return }
        let wanted = current + step
        guard changed.indices.contains(wanted) else { return }
        changed.swapAt(current, wanted)
        withAnimation(.snappy) { order = changed }
        model.lineOrder = changed
    }

    private func toggle(_ station: Station) {
        if model.hiddenTargets.contains(station) {
            model.setTarget(station, shown: true)
        } else {
            // Hiding a line changes the widgets and the tabs, so it is explained first.
            model.ask(Guide(
                id: "hide-line",
                title: "Hide trains to \(station.name)?",
                points: [
                    "They leave the lock screen widgets and the destination tabs.",
                    "A station left with one line gives it both widget rows, with more times.",
                    "A station whose only line this is still shows it.",
                ],
                confirm: "Hide"
            ) { model.setTarget(station, shown: false) })
        }
    }
}
