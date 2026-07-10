// Central app state — location resolution (GPS + manual), live feed fetching,
// and the derived CivicProfile. A faithful port of the web app's ExposureProvider.

import Foundation
import Observation
import CoreLocation

enum GeoStatus: String {
    case idle, requesting, granted, denied, unsupported, manual
}

struct Coord: Equatable {
    var lat: Double
    var lon: Double
    var accuracy: Double? = nil
    var timestamp: Date
    var label: String? = nil
    var source: Source
    var state: String? = nil
    var stateAbbr: String? = nil
    var county: String? = nil
    var countryCode: String? = nil

    enum Source: String { case gps, manual }
}

@MainActor
@Observable
final class ExposureStore {
    // Location
    var coord: Coord?
    var geoStatus: GeoStatus = .idle
    var geoError: String?

    // Live feeds
    var air: AirReading?
    var water: [WaterSiteReading] = []
    var loadingAir = false
    var loadingWater = false
    var airError: String?
    var waterError: String?
    var lastUpdated: Date?

    // Scenario controls
    var scenario: Double = 0.5
    var population: Double?

    @ObservationIgnored private let location = LocationProvider()
    @ObservationIgnored private let clGeocoder = CLGeocoder()
    @ObservationIgnored private var fetchGeneration = 0
    @ObservationIgnored private var didStart = false

    init() {
        location.onUpdate = { [weak self] loc in self?.handleGPS(loc) }
        location.onDenied = { [weak self] in self?.handleDenied() }
        location.onUnsupported = { [weak self] in self?.handleUnsupported() }
        location.onFailure = { [weak self] error in self?.handleFailure(error) }
    }

    /// The complete derived civic profile — rebuilt reactively as inputs change.
    var civic: CivicProfile? {
        guard let coord else { return nil }
        return buildCivicProfile(BuildArgs(
            lat: coord.lat,
            lon: coord.lon,
            stateAbbr: coord.stateAbbr,
            liveAir: air,
            liveWater: water,
            scenario: scenario,
            populationOverride: population
        ))
    }

    /// Kick off location resolution once, after the disclaimer is accepted.
    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        requestLocation()
    }

    func requestLocation() {
        geoError = nil
        geoStatus = .requesting
        location.request()
    }

    func setManualLocation(_ s: GeoSuggestion) {
        geoStatus = .manual
        geoError = nil
        population = nil // reset any manual population when the place changes
        let label = s.sublabel.map { "\(s.label) · \($0)" } ?? s.label
        let c = Coord(
            lat: s.lat, lon: s.lon, accuracy: nil, timestamp: Date(),
            label: label, source: .manual,
            state: s.state, stateAbbr: s.stateAbbr, county: s.county, countryCode: s.countryCode
        )
        coord = c
        loadData(for: c)
    }

    func refresh() {
        if let c = coord, c.source == .manual {
            var nc = c
            nc.timestamp = Date()
            coord = nc
            loadData(for: nc)
        } else {
            requestLocation()
        }
    }

    func setScenario(_ v: Double) { scenario = min(1, max(0, v)) }
    func setPopulation(_ v: Double?) { population = v }

    // MARK: - Location handling

    private func handleGPS(_ loc: CLLocation) {
        geoStatus = .granted
        geoError = nil
        let c = Coord(
            lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
            accuracy: loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil,
            timestamp: Date(), label: nil, source: .gps
        )
        coord = c
        loadData(for: c)
        reverseGeocode(loc)
    }

    private func handleDenied() {
        geoStatus = .denied
        if geoError == nil { geoError = "Location access denied. Enter a ZIP or place to continue." }
    }

    private func handleUnsupported() {
        geoStatus = .unsupported
        geoError = "Location services are off. Enter a ZIP or place to continue."
    }

    private func handleFailure(_ error: Error) {
        if coord == nil {
            geoStatus = .idle
            geoError = "Couldn't get a GPS fix. Enter a ZIP or place to continue."
        }
    }

    private func reverseGeocode(_ loc: CLLocation) {
        clGeocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let pm = placemarks?.first else { return }
            // Extract Sendable primitives before hopping to the main actor.
            let admin = pm.administrativeArea
            let county = pm.subAdministrativeArea
            let iso = pm.isoCountryCode?.uppercased()
            let isUS = iso == "US"
            let city = pm.locality ?? pm.subAdministrativeArea ?? pm.administrativeArea
            Task { @MainActor in
                guard let self, var c = self.coord, c.source == .gps else { return }
                c.state = admin
                c.stateAbbr = isUS ? admin : nil
                c.county = county
                c.countryCode = iso
                c.label = [city, admin].compactMap { $0 }.joined(separator: ", ")
                self.coord = c
            }
        }
    }

    // MARK: - Data fetching

    private func loadData(for coord: Coord) {
        fetchGeneration += 1
        let gen = fetchGeneration
        loadingAir = true
        loadingWater = true
        airError = nil
        waterError = nil

        Task { [weak self] in
            async let airTask = AirService.fetch(lat: coord.lat, lon: coord.lon)
            async let waterTask = WaterService.fetch(lat: coord.lat, lon: coord.lon)
            let air = try? await airTask
            let water = try? await waterTask

            guard let self, gen == self.fetchGeneration else { return }

            if let air {
                self.air = air
            } else {
                self.air = nil
                self.airError = "Live air feed unavailable — showing modeled estimate."
            }
            if let water {
                self.water = water
                if water.isEmpty { self.waterError = "No USGS gauge nearby — water metrics modeled." }
            } else {
                self.water = []
                self.waterError = "USGS feed unavailable — water metrics modeled."
            }
            self.loadingAir = false
            self.loadingWater = false
            self.lastUpdated = Date()
        }
    }
}

// MARK: - CoreLocation bridge

@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onUpdate: (@MainActor (CLLocation) -> Void)?
    var onDenied: (@MainActor () -> Void)?
    var onUnsupported: (@MainActor () -> Void)?
    var onFailure: (@MainActor (Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onDenied?()
        @unknown default:
            onDenied?()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                onDenied?()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let loc = locations.last { onUpdate?(loc) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            onFailure?(error)
        }
    }
}
