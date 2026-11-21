import Foundation
import Combine
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var schedule: ScheduleData?
    @Published private(set) var isImporting = false
    @Published var errorMessage: String?

    @Published var manualStation: Station? {
        didSet {
            SharedStore.manualStation = manualStation
            reloadWidgets()
        }
    }

    @Published var useRealtime: Bool {
        didSet {
            SharedStore.useRealtime = useRealtime
            reloadWidgets()
        }
    }

    init() {
        schedule = SharedStore.loadSchedule()
        manualStation = SharedStore.manualStation
        useRealtime = SharedStore.useRealtime
    }

    /// Called whenever the app comes to the foreground.
    func becameActive() {
        LocationService.shared.refresh()
        let weekOld = schedule.map { Date().timeIntervalSince($0.importedAt) > 7 * 24 * 60 * 60 } ?? true
        if weekOld {
            Task { await downloadSchedule() }
        }
    }

    func downloadSchedule() async {
        await importSchedule { try await GTFSImporter.download() }
    }

    /// Fallback when the download fails: a GTFS zip saved to Files.
    func importSchedule(fromFile url: URL) async {
        await importSchedule {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            return try await GTFSImporter.parse(zip: data)
        }
    }

    private func importSchedule(_ load: () async throws -> ScheduleData) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let fresh = try await load()
            try SharedStore.save(fresh)
            schedule = fresh
            errorMessage = nil
            reloadWidgets()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedStore.widgetKind)
    }
}
