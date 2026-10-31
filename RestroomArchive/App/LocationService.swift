#if canImport(CoreLocation) && canImport(MapKit)
import ArchiveCore
import CoreLocation
import Foundation
import MapKit
import Observation

public struct AutofillLocationSnapshot: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double
    public var city: String
    public var country: String
    public var subdivision: String
    public var nearbyPlaceCandidates: [String]

    public var latString: String {
        String(format: "%.6f", latitude)
    }

    public var lngString: String {
        String(format: "%.6f", longitude)
    }
}

@MainActor
@Observable
public final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    public private(set) var currentCoordinate: (lat: Double, lng: Double)?
    public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public private(set) var isLocating: Bool = false
    public private(set) var errorMessage: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    public func requestSingleLocation() async throws -> (lat: Double, lng: Double) {
        errorMessage = nil
        isLocating = true
        defer { isLocating = false }

        let status = manager.authorizationStatus
        if status == .restricted || status == .denied {
            let err = ArchiveLocationError.permissionDenied
            errorMessage = err.localizedDescription
            throw err
        }

        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
            if let existing = self.locationContinuation {
                existing.resume(throwing: CancellationError())
            }
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }

        let coord = (lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        currentCoordinate = coord
        return coord
    }

    /// Captures GPS coordinates, reverse-geocodes city/country/subdivision normalized to
    /// `ArchiveCore.Regions`, and fetches nearby establishment names for 1-tap submission autofill.
    public func fetchAutofillSnapshot() async throws -> AutofillLocationSnapshot {
        let coord = try await requestSingleLocation()
        let clLocation = CLLocation(latitude: coord.lat, longitude: coord.lng)

        var city = ""
        var country = ""
        var subdivision = ""

        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(clLocation),
           let placemark = placemarks.first {
            city = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.subLocality
                ?? ""
            let normalized = Regions.normalizeReverseGeocodedRegion(
                isoCountryCode: placemark.isoCountryCode,
                administrativeArea: placemark.administrativeArea
            )
            country = normalized.country
            subdivision = normalized.subdivision
        }

        var candidates: [String] = []
        if #available(iOS 17.0, *) {
            let poiRequest = MKLocalPointsOfInterestRequest(
                center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
                radius: 85
            )
            if let response = try? await MKLocalSearch(request: poiRequest).start() {
                for item in response.mapItems {
                    if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !name.isEmpty,
                       !candidates.contains(name) {
                        candidates.append(name)
                    }
                    if candidates.count >= 6 { break }
                }
            }
        }

        return AutofillLocationSnapshot(
            latitude: coord.lat,
            longitude: coord.lng,
            city: city,
            country: country,
            subdivision: subdivision,
            nearbyPlaceCandidates: candidates
        )
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways),
           locationContinuation != nil {
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            if let cont = locationContinuation {
                locationContinuation = nil
                cont.resume(throwing: ArchiveLocationError.permissionDenied)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        currentCoordinate = (lat: latest.coordinate.latitude, lng: latest.coordinate.longitude)
        if let cont = locationContinuation {
            locationContinuation = nil
            cont.resume(returning: latest)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError, clErr.code == .locationUnknown {
            return
        }
        errorMessage = error.localizedDescription
        if let cont = locationContinuation {
            locationContinuation = nil
            cont.resume(throwing: error)
        }
    }
}

public enum ArchiveLocationError: LocalizedError {
    case permissionDenied

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location access is turned off. Enable Location in Settings to sort by distance or autofill coordinates."
        }
    }
}
#endif

