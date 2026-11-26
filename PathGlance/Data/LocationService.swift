import Foundation
import Combine
import CoreLocation
import WidgetKit

/// Works out the nearest PATH station and shares it with the widget.
///
/// With "Always" permission, iOS relaunches the app in the background when the phone
/// enters a station's region, so the lock screen follows you without opening the app.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published private(set) var station: Station? = SharedStore.autoStation
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = manager.authorizationStatus
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            monitorStations()
            manager.startMonitoringSignificantLocationChanges()
            manager.requestLocation()
        case .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    /// First call asks for "While Using", the next one asks to upgrade to "Always".
    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func refresh() {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    private func monitorStations() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let existing = Set(manager.monitoredRegions.map(\.identifier))
        for station in Station.allCases where !existing.contains(station.rawValue) {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude),
                radius: 200,
                identifier: station.rawValue
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    private func update(to newStation: Station) {
        let changed = SharedStore.autoStation != newStation
        SharedStore.setAutoStation(newStation)
        station = newStation
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        update(to: Station.nearest(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if let station = Station(rawValue: region.identifier) {
            update(to: station)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known station; the widget falls back to it.
    }
}
