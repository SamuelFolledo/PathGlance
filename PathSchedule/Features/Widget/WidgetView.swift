import SwiftUI

/// The Widget tab: the lock screen widget as it will look, and everything that changes
/// it. Edits show in the preview at once but only reach the real widget on Save. The menu
/// button opens the settings that are not about the widget.
struct WidgetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sheet: Sheet?
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private enum Sheet: String, Identifiable {
        case presets, settings

        var id: String { rawValue }
    }

    /// "Default", "Large", "Custom", or "Custom, not saved" while it is being edited.
    private var presetName: String {
        if let preset = WidgetPreset.matching(model.look) { return preset.name }
        return model.customPreset?.look == model.look ? "Custom" : "Custom, not saved"
    }

    /// A phone on its side has too little height to give some of it up for good.
    private var pinsPreview: Bool { verticalSizeClass != .compact }

    private var titleRow: some View {
        TabTitle(title: "Widget") {
            RoundButton(symbol: "line.3.horizontal", label: "Settings", identifier: "settingsButton") { sheet = .settings }
                .infoPopover("Settings", "Station and location, the timetable, text size, the archive and restoring defaults.")
        }
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if !pinsPreview {
                        preview
                    }

                    OpenRow(title: "Presets", value: presetName) { sheet = .presets }
                        .padding(Theme.Spacing.contentSide)
                        .card()
                        .accessibilityIdentifier("presetsRow")
                        .id("top")
                        .infoPopover("Presets", "Ready-made looks to start from.", "Choosing one changes the preview; Save sends it to the widget.", "Changing anything after that makes it your own custom look.")

                    options
                }
                .padding(.horizontal, Theme.Spacing.contentSide)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, 80)
            }
            // The title and the preview stay put above the options, so every change is seen
            // as it is made. Nothing is drawn behind them: the options fade out underneath.
            .pinnedBarTop {
                // Room between the settings button and the preview under it.
                VStack(spacing: Theme.Spacing.lg) {
                    titleRow
                    if pinsPreview {
                        preview
                            .padding(.horizontal, Theme.Spacing.contentSide)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: model.resetCount[.widget]) {
                sheet = nil
                withAnimation { reader.scrollTo("top", anchor: .top) }
            }
        }
        .overlay(alignment: .bottom) {
            if model.hasUnsavedLook {
                HStack(spacing: Theme.Spacing.sm) {
                    // Back to what the widget shows now.
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
        .appSheet(item: $sheet, title: { $0 == .presets ? "Presets" : "Settings" },
                  subtitle: { $0 == .presets ? "Pick a look to start from. It reaches the widget when you tap Save." : "Everything that is not about how the widget looks." }) { sheet in
            switch sheet {
            case .presets: PresetsView { self.sheet = nil }
            case .settings: SettingsSheet()
            }
        }
    }

    /// The widget on a stand-in lock screen, behaving as the widget does.
    private var preview: some View {
        WidgetPreviewCard(look: model.look)
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.28), Color(red: 0.04, green: 0.05, blue: 0.12)], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: Theme.Radius.card)
            )
            .environment(\.colorScheme, .dark)
            .accessibilityIdentifier("lockScreenPreview")
            .infoPopover("Lock screen preview",
                         "This is the widget at its real proportions, with live times.",
                         "Tap the top row to refresh it. Tap a line to see those trains.",
                         "A ? after a line means a short delay, ! a long one.")
    }

    @ViewBuilder
    private var options: some View {
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
        FoldCard(id: "widget-lines", title: "Lines shown", value: model.hiddenTargets.isEmpty ? "All" : "\(BoardRules.terminals.count - model.hiddenTargets.count) of \(BoardRules.terminals.count)") {
            LinesShownRows()
        }
        FoldCard(id: "widget-muted", title: "Muted issues", value: model.mutedKinds.isEmpty ? "None" : "\(model.mutedKinds.count)") {
            MutedKindRows()
        }
        FoldCard(id: "widget-favorites", title: "Favorite stops", value: model.favoriteStops.isEmpty ? "None" : model.favoriteStops.map(\.shortName).joined(separator: ", ")) {
            // The same list the Trains tab opens, so a change in either shows in both.
            FavoriteStopsView(idPrefix: "widgetFavorite")
        }
    }
}

/// The last custom look saved, then the looks to start from, each drawn as it would appear.
struct PresetsView: View {
    let close: () -> Void

    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Your own look comes first once there is one: the list below it is long.
            if let custom = model.customPreset {
                row(name: "Custom", detail: "Saved \(PathFormat.dayTime(custom.savedAt))", look: custom.look, id: "custom")
            }
            ForEach(WidgetPreset.builtIn) { preset in
                row(name: preset.name, detail: preset.detail, look: preset.look, id: preset.id)
            }
            if model.customPreset == nil {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "circle.dashed")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom")
                        Text("N/A. Change any option and tap Save to keep your own look here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Theme.Spacing.row)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func row(name: String, detail: String, look: WidgetLook, id: String) -> some View {
        RadioRow(isSelected: model.look == look) {
            model.look = look
            close()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .fontWeight(.semibold)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                WidgetPreviewCard(look: look, isInteractive: false, maxScale: 1.25)
                    .padding(Theme.Spacing.sm)
                    .background(Color(red: 0.06, green: 0.08, blue: 0.16), in: .rect(cornerRadius: 14))
                    .environment(\.colorScheme, .dark)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("preset-\(id)")
    }
}

/// What the menu button on the Widget tab opens: everything that is not about how the
/// widget looks. Each group folds; press and hold a row for what it does.
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @Environment(\.openURL) private var openURL
    @State private var showsStations = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            FoldCard(id: "settings-station", title: "Station", value: model.station(nearest: location.station).shortName) {
                // The whole row opens the station list.
                Button {
                    showsStations = true
                } label: {
                    HStack {
                        Text("From")
                        Spacer()
                        Text(model.manualStation?.name ?? "Nearest station")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, Theme.Spacing.row)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsStations) { StationMenu(isShowing: $showsStations) }
                .accessibilityIdentifier("settingsFrom")
                .infoPopover("From", "The station the widget and the Trains tab start from.", "Nearest follows your location.")
                if model.manualStation == nil {
                    LabeledContent("Detected", value: location.station?.name ?? "Unknown")
                        .padding(.vertical, Theme.Spacing.row)
                        .infoPopover("Detected", "The nearest station to where the phone last was.")
                    LabeledContent("Location access", value: authorizationText)
                        .padding(.vertical, Theme.Spacing.row)
                        .infoPopover("Location access", "While using: the station updates when the app or widget refreshes.", "Always: it also updates in the background as you reach a station.")
                    if location.authorization == .denied, let settings = URL(string: UIApplication.openSettingsURLString) {
                        Button("Turn on location in Settings") { openURL(settings) }
                            .padding(.vertical, Theme.Spacing.row)
                            .accessibilityIdentifier("openLocationSettings")
                    }
                    if location.authorization == .notDetermined || location.authorization == .authorizedWhenInUse {
                        Button(location.authorization == .notDetermined ? "Allow location" : "Allow in background (Always)") {
                            location.requestPermission()
                        }
                        .padding(.vertical, Theme.Spacing.row)
                    }
                }
            }

            FoldCard(id: "settings-schedule", title: "Schedule", value: model.schedule?.feedVersion ?? "None") {
                if let schedule = model.schedule {
                    LabeledContent("Checked", value: schedule.importedAt.formatted(date: .abbreviated, time: .shortened))
                        .padding(.vertical, Theme.Spacing.row)
                    if let version = schedule.feedVersion {
                        LabeledContent("Timetable", value: version)
                            .padding(.vertical, Theme.Spacing.row)
                    }
                }
                Button {
                    Task { await model.downloadSchedule() }
                } label: {
                    HStack {
                        Text("Update schedule now")
                        Spacer()
                        if model.isImporting { ProgressView() }
                    }
                    .padding(.vertical, Theme.Spacing.row)
                    .contentShape(.rect)
                }
                .disabled(model.isImporting)
                .accessibilityIdentifier("updateSchedule")
                .infoPopover("Schedule", "Read from the timetables on PATH's website.", "Checked about once a day, in the background and when you open the app.", "If a check fails, the last good timetable stays in use.")
                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            FoldCard(id: "settings-text", title: "Text size", value: "Step \(model.textSizeStep + 1)") {
                HStack(spacing: Theme.Spacing.md) {
                    Text("A").font(.system(size: 13)).accessibilityHidden(true)
                    Slider(value: Binding(get: { Double(model.textSizeStep) }, set: { model.textSizeStep = Int($0.rounded()) }),
                           in: 0...Double(AppModel.textSizes.count - 1), step: 1)
                        .accessibilityLabel("Text size")
                        .accessibilityValue("Step \(model.textSizeStep + 1) of \(AppModel.textSizes.count)")
                        .accessibilityIdentifier("textSizeSlider")
                    Text("A").font(.system(size: 24)).accessibilityHidden(true)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .infoPopover("Text size", "Sets the size of text throughout the app.", "The lock screen widget has its own Size option.")
                Button("Restore default text size") {
                    model.textSizeStep = AppModel.defaultTextSizeStep
                }
                .disabled(model.textSizeStep == AppModel.defaultTextSizeStep)
                .padding(.vertical, Theme.Spacing.row)
                .accessibilityIdentifier("restoreTextSize")
            }

            FoldCard(id: "settings-timetables", title: "Timetables", value: "") {
                TimetableArchiveView()
            }
            .infoPopover("Timetables", "Every distinct timetable the app has downloaded.")

            FoldCard(id: "settings-daytypes", title: "Learned day types", value: "") {
                DayTypeLogView()
            }

            FoldCard(id: "settings-support", title: "Support the app", value: "") {
                Text("\(AppInfo.name) is free and made in spare time. A tip is welcome, never needed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Theme.Spacing.sm)
                ForEach(AppInfo.donations) { donation in
                    LinkRow(title: donation.title, symbol: donation.symbol, color: donation.color, opensOutside: true) {
                        openURL(donation.url)
                    }
                    .accessibilityIdentifier("donate-\(donation.id)")
                }
            }
            .infoPopover("Support the app", "Each one opens outside the app.", "Nothing in the app is locked behind a tip.")

            FoldCard(id: "settings-about", title: "About", value: AppInfo.versionText) {
                LinkRow(title: "Email the developer", symbol: "envelope.fill", color: .blue) {
                    if let url = AppInfo.email(subject: "\(AppInfo.name) feedback") { openURL(url) }
                }
                .accessibilityIdentifier("emailDeveloper")
                .infoPopover("Email the developer", "Questions, ideas, or a hello.", "Opens your mail app with the app version filled in.")
                LinkRow(title: "Report a problem", symbol: "ladybug.fill", color: .red) {
                    if let url = reportURL { openURL(url) }
                }
                .accessibilityIdentifier("reportProblem")
                .infoPopover("Report a problem", "Opens an email with your station, timetable and location access filled in.", "For one wrong train time, press and hold that train on the Trains tab instead.")
                ShareLink(item: AppInfo.website) {
                    LinkRowLabel(title: "Share the app", symbol: "square.and.arrow.up.fill", color: .teal, opensOutside: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shareApp")
                LinkRow(title: "Help", symbol: "questionmark.circle.fill", color: .orange, opensOutside: true) {
                    openURL(AppInfo.support)
                }
                .accessibilityIdentifier("helpPage")
                LinkRow(title: "Privacy policy", symbol: "hand.raised.fill", color: .gray, opensOutside: true) {
                    openURL(AppInfo.privacyPolicy)
                }
                .accessibilityIdentifier("privacyPolicy")
                .infoPopover("Privacy", "Your location stays on this phone.", "No account, no ads, no tracking.", "The app only reads timetables, live times and alerts from PATH's website.")
                LabeledContent("Version", value: AppInfo.versionText)
                    .padding(.vertical, Theme.Spacing.row)
                    .accessibilityIdentifier("appVersion")
                    .infoPopover("Version", "The version, then the build number in brackets.", "Mention it when you report a problem.")
                LabeledContent("Developer", value: AppInfo.developer)
                    .padding(.vertical, Theme.Spacing.row)
                Text(AppInfo.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, Theme.Spacing.sm)
            }

            Button("Restore defaults", role: .destructive) {
                // Always asks: it cannot be undone.
                model.ask(Guide(
                    id: "restore-defaults",
                    title: "Restore defaults?",
                    points: [
                        "Every setting goes back to how a fresh install has it: station, the widget's look and your custom preset, favorite stops, lines shown, muted issues and text size.",
                        "Explanations you ticked \"Don't show this again\" on will show again.",
                        "The timetable, the issue history and what the app has learned about holidays are kept.",
                    ],
                    confirm: "Restore",
                    isDestructive: true,
                    canBeSilenced: false
                ) { model.restoreDefaults() })
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.contentSide)
            .card()
            .accessibilityIdentifier("restoreDefaults")
            .infoPopover("Restore defaults", "Puts every setting back the way a fresh install has it.", "Keeps the timetable, issue history and holiday learning.")
        }
    }

    /// An email about the app as a whole, with what a fix usually needs filled in.
    private var reportURL: URL? {
        AppInfo.email(
            subject: "\(AppInfo.name): problem report",
            body: "What happened:\n\n\nWhat you expected:\n",
            details: [
                "Station: \(model.station(nearest: location.station).name)\(model.manualStation == nil ? " (nearest)" : "")",
                "Location access: \(authorizationText)",
                "Timetable: \(model.schedule?.feedVersion ?? "none")",
            ]
        )
    }

    private var authorizationText: String {
        switch location.authorization {
        case .notDetermined: return "Not asked"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "While using"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
}
