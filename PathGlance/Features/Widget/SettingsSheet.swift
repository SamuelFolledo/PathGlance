import SwiftUI
import CoreLocation

/// What the menu button on the Widget tab opens: everything that is not about how the
/// widgets look. Each group folds; press and hold a row for what it does. A row always
/// does something: what would be a line of text on its own sits under a row's title.
struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var location: LocationService
    @Environment(\.openURL) private var openURL
    @State private var showsStations = false
    @State private var showsMuted = false
    @State private var timetables: [TimetableArchive.Entry] = []
    @State private var hasDayTypes = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            FoldCard(id: "settings-preferences", title: "Preferences", value: model.station(nearest: location.station).shortName) {
                DetailRow(title: "From \(model.station(nearest: location.station).name)", detail: stationDetail, symbol: "chevron.up.chevron.down") {
                    showsStations = true
                }
                .popover(isPresented: $showsStations) { StationMenu(isShowing: $showsStations) }
                .accessibilityIdentifier("settingsFrom")
                .infoPopover("From", "The station the widgets and the Trains tab start from.", "Nearest follows your location.", "The star beside a station makes it a favorite stop.")
                Divider()
                DetailRow(title: "Location access", detail: locationDetail, symbol: canAskForLocation ? "chevron.right" : nil) {
                    askForLocation()
                }
                .disabled(!canAskForLocation)
                .accessibilityIdentifier("locationAccess")
                .infoPopover("Location access", "While using: the station updates when the app or a widget refreshes.", "Always: it also updates in the background as you reach a station.")
                Divider()
                DetailRow(title: "Muted issues", detail: mutedDetail, symbol: showsMuted ? "chevron.down" : "chevron.right") {
                    withAnimation(Theme.Motion.sheet) { showsMuted.toggle() }
                }
                .accessibilityValue(showsMuted ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("mutedIssues")
                .infoPopover("Muted issues", "A muted kind stays in the Issues tab but leaves its badge, the banners and the lock screen widgets.")
                if showsMuted {
                    MutedKindRows()
                        .padding(.leading, Theme.Spacing.md)
                }
            }

            FoldCard(id: "settings-lines", title: "Lines preferred", value: linesDetail) {
                LinesPreferredRows()
            }

            FoldCard(id: "settings-schedule", title: "Schedule", value: model.schedule?.feedVersion ?? "None") {
                if let schedule = model.schedule {
                    LabeledContent("Last updated", value: schedule.importedAt.formatted(date: .abbreviated, time: .shortened))
                        .padding(.vertical, Theme.Spacing.row)
                        .accessibilityIdentifier("scheduleUpdated")
                    if let version = schedule.feedVersion {
                        LabeledContent("Schedule", value: version)
                            .padding(.vertical, Theme.Spacing.row)
                            .accessibilityIdentifier("scheduleVersion")
                    }
                }
                Button {
                    Task {
                        await model.downloadSchedule()
                        timetables = TimetableArchive.entries()
                    }
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
                // One timetable is the one named above. Only a history is worth listing.
                if timetables.count > 1 {
                    Text("Every timetable downloaded")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.md)
                        .padding(.bottom, Theme.Spacing.xs)
                        .accessibilityAddTraits(.isHeader)
                    TimetableArchiveView()
                        .infoPopover("Every timetable downloaded", "Each distinct timetable the app has read from PATH, and the days it was in use.")
                }
            }

            FoldCard(id: "settings-text", title: "Text size", value: AppModel.textSizeName(offset: model.textSizeOffset)) {
                HStack(spacing: Theme.Spacing.md) {
                    Text("A").font(.system(size: 13)).accessibilityHidden(true)
                    Slider(value: Binding(get: { Double(model.textSizeOffset) }, set: { model.textSizeOffset = Int($0.rounded()) }),
                           in: Double(AppModel.textSizeOffsets.lowerBound)...Double(AppModel.textSizeOffsets.upperBound), step: 1)
                        .accessibilityLabel("Text size")
                        .accessibilityValue(AppModel.textSizeName(offset: model.textSizeOffset))
                        .accessibilityIdentifier("textSizeSlider")
                    Text("A").font(.system(size: 24)).accessibilityHidden(true)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .infoPopover("Text size",
                             "The app follows your phone's text size (Settings, Display & Brightness, Text Size).",
                             "This makes the app's text larger or smaller than that, in steps.",
                             "The lock screen widgets have their own Size option.")
                DetailRow(title: "Back to standard", detail: model.textSizeOffset == 0 ? "The app follows your phone's text size." : "Now \(AppModel.textSizeName(offset: model.textSizeOffset)) from your phone's text size.",
                          symbol: model.textSizeOffset == 0 ? nil : "arrow.uturn.backward") {
                    model.textSizeOffset = 0
                }
                .disabled(model.textSizeOffset == 0)
                .accessibilityIdentifier("restoreTextSize")
            }

            if hasDayTypes {
                FoldCard(id: "settings-daytypes", title: "Learned day types", value: "") {
                    DayTypeLogView()
                }
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
                LinkRow(title: "Email the developer", symbol: "envelope.fill", color: Theme.Colors.brand) {
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
                LinkRow(title: "Welcome note", symbol: "hand.wave.fill", color: Theme.Colors.brand) {
                    model.showWelcome()
                }
                .accessibilityIdentifier("welcomeNote")
                .infoPopover("Welcome note", "What is live, what is the timetable, and who makes the app.", "The note shown when you first opened the app.")
                // The version and who made it, with the disclaimer: one block, nothing to tap.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(AppInfo.versionText) · \(AppInfo.developer)")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("appVersion")
                    Text(AppInfo.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.sm)
                .infoPopover("Version", "The version, then the build number in brackets.", "Mention it when you report a problem.")
            }

            Button("Restore defaults", role: .destructive) {
                // Always asks: it cannot be undone.
                model.ask(SettingsSheet.restoreGuide { model.restoreDefaults(keeping: $0) })
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.contentSide)
            .card()
            .accessibilityIdentifier("restoreDefaults")
            .infoPopover("Restore defaults", "Puts every setting back the way a fresh install has it.", "You can keep favorite stops, muted issues or the lock screen presets.", "Keeps the timetable, issue history and holiday learning.")
        }
        .onAppear {
            timetables = TimetableArchive.entries()
            hasDayTypes = !DayTypeLog.load().observations.isEmpty
        }
    }

    /// The question "Restore defaults" asks, with a box for each thing worth keeping.
    /// Every box starts unticked each time.
    static func restoreGuide(_ restore: @escaping (Set<SharedStore.Kept>) -> Void) -> Guide {
        Guide(
            id: "restore-defaults",
            title: "Restore defaults?",
            points: [
                "Every setting goes back to how a fresh install has it: station, both widgets' looks, favorite stops, the lines you prefer and their order, muted issues and text size.",
                "Tick a box to keep that part as it is now.",
                "Explanations you ticked \"Don't show this again\" on will show again.",
                "The timetable, the issue history and what the app has learned about holidays are always kept.",
            ],
            confirm: "Restore",
            isDestructive: true,
            canBeSilenced: false,
            options: [
                Guide.Option(id: SharedStore.Kept.favoriteStops.rawValue, title: "Keep favorite stops"),
                Guide.Option(id: SharedStore.Kept.mutedIssues.rawValue, title: "Keep muted issues"),
                Guide.Option(id: SharedStore.Kept.presets.rawValue, title: "Keep lock screen presets"),
            ],
            onConfirm: { restore(Set($0.compactMap(SharedStore.Kept.init(rawValue:)))) },
            action: {}
        )
    }

    // MARK: Preferences

    /// Where the station comes from, and what the phone last found nearest.
    private var stationDetail: String {
        let nearest = location.station?.name
        if model.manualStation == nil {
            return nearest.map { "Nearest station. Detected: \($0)" } ?? "Nearest station. None detected yet."
        }
        return nearest.map { "Chosen by you. Nearest: \($0)" } ?? "Chosen by you."
    }

    private var canAskForLocation: Bool {
        switch location.authorization {
        case .authorizedAlways, .restricted: return false
        default: return true
        }
    }

    private var locationDetail: String {
        switch location.authorization {
        case .notDetermined: return "Not asked yet. Tap to allow."
        case .restricted: return "Restricted on this phone."
        case .denied: return "Off. Tap to turn it on in Settings."
        case .authorizedWhenInUse: return "While using the app. Tap to allow Always, so the widgets follow you."
        case .authorizedAlways: return "Always allowed."
        @unknown default: return "Unknown."
        }
    }

    /// Asks for the next step up. iOS shows each question once, so after that the only
    /// way is the Settings app.
    private func askForLocation() {
        switch location.authorization {
        case .notDetermined:
            location.requestPermission()
        case .authorizedWhenInUse:
            if UserDefaults.standard.bool(forKey: "askedForAlways") {
                openSettings()
            } else {
                UserDefaults.standard.set(true, forKey: "askedForAlways")
                location.requestPermission()
            }
        case .denied:
            openSettings()
        default:
            break
        }
    }

    private func openSettings() {
        if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
    }

    private var mutedDetail: String {
        let muted = IssueKind.allCases.filter(model.mutedKinds.contains)
        return muted.isEmpty ? "None. Every kind counts." : muted.map(\.pluralTitle).joined(separator: ", ")
    }

    /// The lines shown, in order: "WTC, 33rd, HOB".
    private var linesDetail: String {
        let shown = model.lineOrder.filter { !model.hiddenTargets.contains($0) }
        return shown.isEmpty ? "None" : shown.map(\.shortName).joined(separator: ", ")
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
