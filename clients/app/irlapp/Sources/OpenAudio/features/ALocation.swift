// ALocation.swift
// openaudiostandard
//
// Created by Elijah Arbee on 10/23/24.

import Foundation
import CoreLocation
import Combine

// MARK: - LocationData Struct

/// Stores location data with additional metadata
public struct LocationData: Codable {
    public let uuid: String
    public let latitude: Double?
    public let longitude: Double?
    public let accuracy: Double?
    public let timestamp: Date
    public let altitude: Double?
    public let speed: Double?
    public let course: Double?
    public let isLocationAvailable: Bool

    public init(uuid: String = UUID().uuidString,
                latitude: Double?,
                longitude: Double?,
                accuracy: Double?,
                timestamp: Date,
                altitude: Double?,
                speed: Double?,
                course: Double?,
                isLocationAvailable: Bool) {
        self.uuid = uuid
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.altitude = altitude
        self.speed = speed
        self.course = course
        self.isLocationAvailable = isLocationAvailable
    }
}

// MARK: - LocationManager Class

/// Manages user location tracking with metadata
public class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    // Singleton instance
    public static let shared = LocationManager()

    // Published properties for tracking location and error messages
    @Published public var currentLocation: LocationData?
    @Published public var locationErrorMessage: String?

    // Private properties
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var isMonitoringSignificantChanges = false
    private let locationSubject = PassthroughSubject<LocationData?, Never>()
    
    /// Publisher to emit location updates
    public var locationPublisher: AnyPublisher<LocationData?, Never> {
        locationSubject.eraseToAnyPublisher()
    }

    // Initializer
    private override init() {
        super.init()
        setupLocationManager()
    }

    // Configures CLLocationManager
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
        requestLocationAuthorization()
    }

    /// Requests location authorization.
    public func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    // CLLocationManagerDelegate method for handling authorization changes
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            locationErrorMessage = "Location access denied. Some features may be unavailable."
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    // CLLocationManagerDelegate method for handling location updates
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        if let lastLoc = lastLocation, newLocation.distance(from: lastLoc) < locationManager.distanceFilter {
            locationManager.stopUpdatingLocation()
            startSignificantChangeMonitoring()
            return
        }

        let locationData = generateLocationData(for: newLocation)
        currentLocation = locationData
        locationSubject.send(locationData)
        lastLocation = newLocation
    }

    // Handles errors during location updates
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationErrorMessage = "Failed to get location: \(error.localizedDescription)"
        locationSubject.send(nil)
    }

    /// Starts monitoring significant location changes.
    public func startSignificantChangeMonitoring() {
        guard !isMonitoringSignificantChanges else { return }
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = true
    }

    /// Stops monitoring significant location changes.
    public func stopSignificantChangeMonitoring() {
        guard isMonitoringSignificantChanges else { return }
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoringSignificantChanges = false
    }

    /// Generates LocationData with metadata from a CLLocation
    private func generateLocationData(for location: CLLocation) -> LocationData {
        return LocationData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            altitude: location.altitude,
            speed: location.speed,
            course: location.course,
            isLocationAvailable: true
        )
    }
}
