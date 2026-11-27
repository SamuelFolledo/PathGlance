import SwiftUI

/// One card of a preset carousel. `look` is `nil` for a Custom card nothing has filled yet.
private struct PresetCard<Look>: Identifiable {
    let id: String
    let name: String
    let look: Look?

    static var customID: String { "custom" }
}

/// The Widget tab: both lock screen widgets as they will look, and everything that
/// changes them. Underline tabs pick the shape; under them the preview is a carousel of
/// that shape's presets, with your own look first. Edits show in the preview at once but
/// only reach the real widgets on Save. The menu button opens the settings that are not
/// about the widgets.
struct WidgetView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @StateObject private var feed = PreviewFeed()
    @State private var showsSettings: SettingsItem?
    /// The shape whose tab is underlined, and the page showing. They part only mid-swipe.
    @State private var shape = WidgetShape.rectangle
    @State private var page: WidgetShape? = .rectangle
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct SettingsItem: Identifiable {
        let id = "settings"
    }

    /// A phone on its side has too little height to give some of it up for good.
    private var pinsPreview: Bool { verticalSizeClass != .compact }

    private var titleRow: some View {
        TabTitle(title: "Widget") {
            RoundButton(symbol: "line.3.horizontal", label: "Settings", identifier: "settingsButton") { showsSettings = SettingsItem() }
                .infoPopover("Settings", "Your station, location and muted issues, the lines you prefer, the timetable, text size and restoring defaults.")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
            UnderlineTabs(tabs: WidgetShape.allCases.map { UnderlineTab(id: $0, title: $0.name, spokenTitle: "\($0.name) widget") },
                          selection: shape) { chosen in
                shape = chosen
                withAnimation(.snappy) { page = chosen }
            }
            .padding(.horizontal, Theme.Spacing.contentSide)
            .padding(.top, Theme.Spacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shapePicker")

            // The shapes page sideways like the lines on the Trains tab. A swipe on a
            // carousel moves the carousel; a swipe anywhere under it changes the shape.
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(WidgetShape.allCases) { shape in
                        shapePage(shape)
                            .containerRelativeFrame(.horizontal)
                            .id(shape)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .idle, let page, page != shape { shape = page }
            }
        }
        .background(Color(.systemGroupedBackground))
        .environmentObject(feed)
        .task(id: model.station(nearest: location.station)) { await feed.refresh() }
        .overlay(alignment: .bottom) {
            if model.hasUnsavedLook {
                HStack(spacing: Theme.Spacing.sm) {
                    // Back to what the widgets show now.
                    Button {
                        model.revertLook()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.headline)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Cancel changes")
                    .accessibilityIdentifier("cancelLook")
                    Button {
                        model.saveLook()
                    } label: {
                        Label("Save to widget", systemImage: "checkmark")
                            .font(.headline)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(height: 40)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("saveLook")
                }
                .padding(.bottom, Theme.Spacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.sheet, value: model.hasUnsavedLook)
        .appSheet(item: $showsSettings, title: { _ in "Settings" }) { _ in
            SettingsSheet()
        }
    }

    /// One shape's page: its preset carousel held at the top, its options scrolling under.
    private func shapePage(_ shape: WidgetShape) -> some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if !pinsPreview {
                        carousel(shape)
                            .padding(.horizontal, -Theme.Spacing.contentSide)
                    }
                    Color.clear
                        .frame(height: 0)
                        .id("top")
                    switch shape {
                    case .rectangle: rectangleOptions
                    case .round: roundOptions
                    }
                }
                .padding(.horizontal, Theme.Spacing.contentSide)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, 80)
            }
            // The carousel stays put above the options, so every change is seen as it is
            // made. Nothing is drawn behind it: the options fade out underneath.
            .pinnedBarTop {
                if pinsPreview {
                    carousel(shape)
                        .padding(.top, Theme.Spacing.md)
                }
            }
            .onChange(of: model.resetCount[.widget]) {
                showsSettings = nil
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
    }

    // MARK: Carousels

    @ViewBuilder
    private func carousel(_ shape: WidgetShape) -> some View {
        switch shape {
        case .rectangle:
            let cards = [PresetCard(id: PresetCard<WidgetLook>.customID, name: "Custom", look: model.customPreset?.look)]
                + WidgetPreset.builtIn.map { PresetCard(id: $0.id, name: $0.name, look: $0.look) }
            Carousel(items: cards, selection: rectangleSelection, peek: 44, noun: "Preset") { card, isSelected in
                presetCard(card.name, id: card.id, isSelected: isSelected) {
                    if let look = card.look {
                        WidgetPreviewCard(look: look, isInteractive: isSelected, maxScale: 1.6)
                    } else {
                        emptyCustom
                            .frame(height: WidgetPreviewCard.widgetSize.height * 1.6)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lockScreenPreview")
            .infoPopover("Lock screen preview",
                         "This is the widget at its real proportions, with live times. Swipe, or tap a neighbour, for another preset.",
                         "Tap the top row to refresh it. Tap a line to see those trains.",
                         "A ? after a line means a short delay, ! a long one.")
        case .round:
            let cards = [PresetCard(id: PresetCard<RoundLook>.customID, name: "Custom", look: model.customRoundPreset?.look)]
                + RoundPreset.builtIn.map { PresetCard(id: $0.id, name: $0.name, look: $0.look) }
            Carousel(items: cards, selection: roundSelection, peek: max(44, (UIScreen.main.bounds.width - 168) / 2), noun: "Preset") { card, isSelected in
                presetCard(card.name, id: "round-\(card.id)", isSelected: isSelected) {
                    if let look = card.look {
                        RoundPreviewCard(look: look)
                    } else {
                        emptyCustom
                            .frame(height: RoundPreviewCard.widgetSize * 1.6)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("roundPreview")
            .infoPopover("Round widget preview",
                         "This is the one-slot widget at its real proportions. Swipe, or tap a neighbour, for another preset.",
                         "It follows one line, chosen under Line.")
        }
    }

    /// The preset matching the look being edited, or Custom when none does.
    private var rectangleSelection: Binding<String> {
        Binding {
            WidgetPreset.matching(model.look)?.id ?? PresetCard<WidgetLook>.customID
        } set: { id in
            if let preset = WidgetPreset.builtIn.first(where: { $0.id == id }) {
                model.look = preset.look
            } else if let custom = model.customPreset {
                model.look = custom.look
            }
        }
    }

    private var roundSelection: Binding<String> {
        Binding {
            RoundPreset.matching(model.roundLook)?.id ?? PresetCard<RoundLook>.customID
        } set: { id in
            if let preset = RoundPreset.builtIn.first(where: { $0.id == id }) {
                model.roundLook = preset.look
            } else if let custom = model.customRoundPreset {
                model.roundLook = custom.look
            }
        }
    }

    /// A preview on a stand-in lock screen with the preset's name under it.
    private func presetCard<Preview: View>(_ name: String, id: String, isSelected: Bool, @ViewBuilder preview: () -> Preview) -> some View {
        VStack(spacing: 6) {
            preview()
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.28), Color(red: 0.04, green: 0.05, blue: 0.12)], startPoint: .top, endPoint: .bottom),
                    in: .rect(cornerRadius: Theme.Radius.card)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .strokeBorder(Theme.Colors.brand, lineWidth: 2)
                            .allowsHitTesting(false)
                    }
                }
                .environment(\.colorScheme, .dark)
                .accessibilityHidden(!isSelected)
            Text(name)
                .font(.footnote.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.Colors.brand) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("preset-\(id)")
        }
        .opacity(isSelected ? 1 : 0.6)
    }

    /// The Custom card before any look of your own exists.
    private var emptyCustom: some View {
        Text("Change any option below and your own look is kept here.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Options

    @ViewBuilder
    private var rectangleOptions: some View {
        FoldCard(id: "widget-font", title: "Font", value: model.fontStyle.name) {
            ForEach(WidgetFontStyle.allCases) { style in
                RadioRow(isSelected: model.fontStyle == style) {
                    model.fontStyle = style
                } label: {
                    // Each font is named in itself, with a sample line.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.name)
                            .font(style.font(size: 17, weight: .semibold))
                        Text("33rd? 7:16, 7:30, 7:50")
                            .font(style.font(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                .infoPopover(style.name, "Sets the typeface of the whole widget.")
                .accessibilityIdentifier("font-\(style.rawValue)")
            }
        }
        FoldCard(id: "widget-size", title: "Size", value: model.widgetStyle.density.name) {
            ForEach(WidgetDensity.allCases) { density in
                RadioRow(isSelected: model.widgetStyle.density == density) {
                    model.widgetStyle.density = density
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(density.name)
                        Text(density.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .infoPopover(density.name, density.detail + ".", "The text is never shrunk to fit: larger text simply shows fewer trains.")
                .accessibilityIdentifier("size-\(density.rawValue)")
            }
        }
        FoldCard(id: "widget-times", title: "Times", value: model.widgetStyle.timeFormat.name) {
            ForEach(WidgetTimeFormat.allCases) { format in
                RadioRow(isSelected: model.widgetStyle.timeFormat == format) {
                    model.widgetStyle.timeFormat = format
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(format.name)
                        Text(format.example)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .infoPopover(format.name,
                             format == .full ? "Every time is written out." : "The hour is dropped when it repeats, which fits more trains on each line.")
                .accessibilityIdentifier("times-\(format.rawValue)")
            }
            Stepper(value: $model.widgetStyle.maxTimes, in: 1...Board.mostPerLine) {
                Text(model.widgetStyle.maxTimes >= Board.mostPerLine ? "As many trains as fit" : "Up to \(model.widgetStyle.maxTimes) trains per line")
            }
            .padding(.vertical, 6)
            .accessibilityIdentifier("maxTimesStepper")
            .infoPopover("Trains per line",
                         "The most train times a line shows.",
                         "Fewer show when fewer fit.",
                         "A station with one line fills both rows with as many as fit, whatever this is set to.")
            CheckRow(isOn: model.widgetStyle.showArrival) {
                model.widgetStyle.showArrival.toggle()
            } label: {
                Text("Arrival time of the next train")
            }
            .infoPopover("Arrival time", "Adds when the first train on each line reaches its destination.", "Shown as 7:16→7:35.")
            .accessibilityIdentifier("showArrival")
        }
    }

    @ViewBuilder
    private var roundOptions: some View {
        FoldCard(id: "round-font", title: "Font", value: model.roundLook.font.name) {
            ForEach(WidgetFontStyle.allCases) { style in
                RadioRow(isSelected: model.roundLook.font == style) {
                    model.roundLook.font = style
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.name)
                            .font(style.font(size: 17, weight: .semibold))
                        Text("33rd 4 min")
                            .font(style.font(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
                .infoPopover(style.name, "Sets the typeface of the round widget.")
                .accessibilityIdentifier("roundFont-\(style.rawValue)")
            }
        }
        FoldCard(id: "round-line", title: "Line", value: model.roundLine?.shortName ?? "First shown") {
            RadioRow(isSelected: model.roundLine == nil) {
                model.roundLine = nil
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("First line shown")
                    Text("The first line of the rectangle widget")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .infoPopover("First line shown", "Follows whichever line your station lists first.", "It changes with the station and with Lines preferred, in Settings.")
            .accessibilityIdentifier("roundLine-first")
            ForEach(BoardRules.terminals, id: \.self) { station in
                RadioRow(isSelected: model.roundLine == station) {
                    model.roundLine = station
                } label: {
                    Text("Trains to \(station.name)")
                }
                .infoPopover("Trains to \(station.name)", "The circle follows this line.", "At a station this line does not leave from, it follows the first line shown.")
                .accessibilityIdentifier("roundLine-\(station.rawValue)")
            }
        }
    }
}

