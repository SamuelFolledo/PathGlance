import SwiftUI

/// One card of a preset carousel.
private struct PresetCard<Look>: Identifiable {
    let id: String
    let name: String
    let look: Look
    /// It differs from the way the preset is built.
    let isEdited: Bool
}

/// The Widget tab: both lock screen widgets as they will look, and everything that
/// changes them. Underline tabs pick the shape; under them the preview is a carousel of
/// that shape's presets. Edits change the preset in hand, show in the preview at once, and
/// reach the real widgets on Save, when they are also kept with that preset. The menu button opens the settings that are not
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
                    if !model.legendHidden {
                        legend(shape)
                    }
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

    // MARK: Legend

    /// What each mark in the widgets means, a page per mark, in the banner the Trains
    /// tab uses for issues. Its X puts the whole legend away for good.
    private func legend(_ shape: WidgetShape) -> some View {
        IssueBannerStack(items: WidgetView.legend(shape), dismissLabel: "Close the legend", name: "widgetLegend", noun: "Mark",
                         subtitleLines: 3) { _ in
            withAnimation(Theme.Motion.sheet) { model.legendHidden = true }
        }
        .infoPopover("Legend", "Swipe sideways for the next mark.", "The X closes it for good. Widget legend, under About in Settings, brings it back.")
    }

    /// The marks each widget can show, most often seen first.
    static func legend(_ shape: WidgetShape) -> [IssueBannerItem] {
        func item(_ id: String, _ symbol: String, _ title: String, _ subtitle: String) -> IssueBannerItem {
            IssueBannerItem(id: "legend-\(id)", symbol: symbol, color: .gray, title: title, subtitle: subtitle, time: "")
        }
        let delay = item("delay", "questionmark", "33rd? and 33rd!",
                         "A ? after a line is a short delay. A ! is a long delay, or an issue PATH has posted about that line.")
        let bold = item("bold", "bold", "Bold names", "Stations and lines are bold, so the eye finds them before the times.")
        switch shape {
        case .rectangle:
            return [
                item("updated", "arrow.clockwise", "From J Sq: 9:04 PM",
                     "Where the trains leave from and when the widget last read the times. Tap that row on the lock screen to refresh."),
                delay,
                item("alert", "exclamationmark.triangle.fill", "Warning triangle",
                     "PATH has an open issue that names none of the lines shown. The Issues tab has it."),
                item("arrival", "arrow.right", "7:16→7:35", "The first train leaves at 7:16 and reaches the end of its line at 7:35."),
                bold,
            ]
        case .round:
            return [
                item("now", "clock", "Now, 4 min, 9:20",
                     "Now is under a minute away. Minutes count down to the next train. Past an hour, it is the time the train leaves."),
                delay,
                item("ring", "circle.dashed", "The ring", "Full at twenty minutes or more, it empties as the train gets closer."),
                bold,
            ]
        }
    }

    // MARK: Carousels

    @ViewBuilder
    private func carousel(_ shape: WidgetShape) -> some View {
        switch shape {
        case .rectangle:
            let cards = WidgetPreset.builtIn.map {
                PresetCard(id: $0.id, name: $0.name, look: model.look(forPreset: $0.id), isEdited: model.isEdited(preset: $0.id, shape: .rectangle))
            }
            Carousel(items: cards, selection: selection(.rectangle), peek: 44, noun: "Preset") { card, isSelected in
                presetCard(card.name, id: card.id, isSelected: isSelected, isEdited: card.isEdited) {
                    WidgetPreviewCard(look: card.look, isInteractive: isSelected, maxScale: 1.6)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lockScreenPreview")
            .infoPopover("Lock screen preview",
                         "This is the widget at its real proportions, with live times. Swipe, or tap a neighbour, for another preset.",
                         "Tap the top row to refresh it. Tap a line to see those trains.",
                         "Changes you save stay with the preset. Restore preset, at the bottom, undoes them.")
        case .round:
            let cards = RoundPreset.builtIn.map {
                PresetCard(id: $0.id, name: $0.name, look: model.roundLook(forPreset: $0.id), isEdited: model.isEdited(preset: $0.id, shape: .round))
            }
            Carousel(items: cards, selection: selection(.round), peek: max(44, (UIScreen.main.bounds.width - 168) / 2), noun: "Preset") { card, isSelected in
                presetCard(card.name, id: "round-\(card.id)", isSelected: isSelected, isEdited: card.isEdited) {
                    RoundPreviewCard(look: card.look)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("roundPreview")
            .infoPopover("Round widget preview",
                         "This is the one-slot widget at its real proportions. Swipe, or tap a neighbour, for another preset.",
                         "It follows one line, chosen under Line.",
                         "Changes you save stay with the preset. Restore preset, at the bottom, undoes them.")
        }
    }

    /// The preset in hand. Turning to another drops what was not saved on this one.
    private func selection(_ shape: WidgetShape) -> Binding<String> {
        Binding {
            shape == .rectangle ? model.presetID : model.roundPresetID
        } set: { id in
            model.selectPreset(id, shape: shape)
        }
    }

    /// A preview on a stand-in lock screen with the preset's name under it.
    private func presetCard<Preview: View>(_ name: String, id: String, isSelected: Bool, isEdited: Bool, @ViewBuilder preview: () -> Preview) -> some View {
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
            Text(isEdited ? "\(name) · Edited" : name)
                .font(.footnote.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(Theme.Colors.brand) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .accessibilityLabel(isEdited ? "\(name), edited" : name)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("preset-\(id)")
        }
        .opacity(isSelected ? 1 : 0.6)
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
        FoldCard(id: "widget-times", title: "Time format", value: model.widgetStyle.timeFormat.name) {
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
        }
        FoldCard(id: "widget-show", title: "Show", value: showSummary) {
            Stepper(value: $model.widgetStyle.maxTimes, in: 1...Board.mostPerLine) {
                Text(model.widgetStyle.maxTimes >= Board.mostPerLine ? "As many trains as fit" : "Up to \(model.widgetStyle.maxTimes) trains per line")
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Divider() }
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
            CheckRow(isOn: model.widgetStyle.skipNext) {
                model.widgetStyle.skipNext.toggle()
            } label: {
                Text("Skip the next train")
            }
            .infoPopover("Skip the next train", "Each line starts from its second train.", "For when the walk to the station is too long to catch the next one.", "The last train of the night still shows.")
            .accessibilityIdentifier("skipNext")
            CheckRow(isOn: model.widgetStyle.showsPeriod) {
                model.widgetStyle.showsPeriod.toggle()
            } label: {
                Text("AM and PM")
            }
            .infoPopover("AM and PM", "Adds AM or PM after each line's first time.", "It shows again where the times cross noon or midnight.")
            .accessibilityIdentifier("showsPeriod")
            CheckRow(isOn: model.widgetStyle.compress) {
                model.widgetStyle.compress.toggle()
            } label: {
                Text("Compress more")
            }
            .infoPopover("Compress more", "Sets the letters closer and drops the space after each comma.", "Often fits one more train on a line.")
            .accessibilityIdentifier("compress")
            CheckRow(isOn: model.widgetStyle.showsHeader) {
                if model.widgetStyle.showsHeader {
                    model.ask(WidgetView.hideHeaderGuide { model.widgetStyle.showsHeader = false })
                } else {
                    model.widgetStyle.showsHeader = true
                }
            } label: {
                Text("From station")
            }
            .infoPopover("From station", "The top row: the station the trains leave from and when the widget last updated.", "Tapping that row on the lock screen refreshes the widget.")
            .accessibilityIdentifier("showsHeader")
        }
        restoreButton(.rectangle)
    }

    /// What the Show section is set to, for when it is folded.
    private var showSummary: String {
        let style = model.widgetStyle
        var parts = [style.maxTimes >= Board.mostPerLine ? "All that fit" : "Up to \(style.maxTimes)"]
        if style.showArrival { parts.append("arrival") }
        if style.skipNext { parts.append("skip next") }
        if style.showsPeriod { parts.append("AM/PM") }
        if style.compress { parts.append("compressed") }
        if !style.showsHeader { parts.append("no station") }
        return parts.joined(separator: ", ")
    }

    /// Asked before the top row is hidden, since more than the station's name goes with it.
    static func hideHeaderGuide(_ hide: @escaping () -> Void) -> Guide {
        Guide(
            id: "hide-widget-header",
            title: "Hide the station row?",
            points: [
                "The widget will show only its train lines, with nothing above them.",
                "This suits you if you always ride from the same station, or only care about certain lines.",
                "The time it last updated, the refresh tap and the alert mark are on that row, so they go too.",
                "Tick From station again to bring the row back.",
            ],
            confirm: "Hide",
            action: hide
        )
    }

    /// Puts the preset in hand back the way it is built.
    private func restoreButton(_ shape: WidgetShape) -> some View {
        let canRestore = model.canRestorePreset(shape)
        return Button {
            model.restorePreset(shape)
        } label: {
            Label("Restore preset", systemImage: "arrow.counterclockwise")
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.contentSide)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(canRestore ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        .card()
        .disabled(!canRestore)
        .accessibilityIdentifier(shape == .rectangle ? "restorePreset" : "restoreRoundPreset")
        .infoPopover("Restore preset", "Puts this preset back the way it came, undoing your changes to it.", "Like any change, it reaches the widget when you tap Save.")
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
        FoldCard(id: "round-show", title: "Show", value: roundShowSummary) {
            CheckRow(isOn: model.roundLook.skipNext) {
                model.roundLook.skipNext.toggle()
            } label: {
                Text("Skip the next train")
            }
            .infoPopover("Skip the next train", "The circle follows the line's second train.", "For when the walk to the station is too long to catch the next one.", "The last train of the night still shows.")
            .accessibilityIdentifier("roundSkipNext")
            // Only a clock time has an AM or PM to show.
            if model.roundLook.hasClock {
                CheckRow(isOn: model.roundLook.showsPeriod) {
                    model.roundLook.showsPeriod.toggle()
                } label: {
                    Text("AM and PM")
                }
                .infoPopover("AM and PM", "Adds AM or PM under the time.")
                .accessibilityIdentifier("roundShowsPeriod")
            }
        }
        restoreButton(.round)
    }

    private var roundShowSummary: String {
        var parts: [String] = []
        if model.roundLook.skipNext { parts.append("Skip next") }
        if model.roundLook.hasClock, model.roundLook.showsPeriod { parts.append("AM/PM") }
        return parts.isEmpty ? "Next train" : parts.joined(separator: ", ")
    }
}

