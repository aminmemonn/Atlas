import Foundation
import AVFoundation
import CoreLocation
import Photos
import Contacts
import EventKit

/// Bridges Atlas's per-capability toggles to the underlying system permission
/// APIs. Requests are made one capability at a time, only in response to an
/// explicit user toggle — nothing is requested in bulk or speculatively.
@MainActor
@Observable
final class CapabilityService: NSObject {
    private(set) var authorizations: [DeviceCapability: CapabilityAuthorization] = [:]

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CapabilityAuthorization, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func refreshAll() {
        for capability in DeviceCapability.allCases {
            authorizations[capability] = currentStatus(for: capability)
        }
    }

    /// Requests authorization for a single capability and returns the outcome.
    @discardableResult
    func request(_ capability: DeviceCapability) async -> CapabilityAuthorization {
        let result: CapabilityAuthorization
        switch capability {
        case .camera:
            result = await requestAVCapture(.video)
        case .microphone:
            result = await requestAVCapture(.audio)
        case .location:
            result = await requestLocation()
        case .photos:
            result = await requestPhotos()
        case .contacts:
            result = await requestContacts()
        case .calendar:
            result = await requestEvents(.event)
        case .reminders:
            result = await requestEvents(.reminder)
        case .screen:
            // App-level toggle only; streaming is gated at the moment of sharing.
            result = .authorized
        }
        authorizations[capability] = result
        return result
    }

    func currentStatus(for capability: DeviceCapability) -> CapabilityAuthorization {
        switch capability {
        case .camera: map(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone: map(AVCaptureDevice.authorizationStatus(for: .audio))
        case .location: map(locationManager.authorizationStatus)
        case .photos: map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .contacts: map(CNContactStore.authorizationStatus(for: .contacts))
        case .calendar: map(EKEventStore.authorizationStatus(for: .event))
        case .reminders: map(EKEventStore.authorizationStatus(for: .reminder))
        case .screen: authorizations[.screen] ?? .notDetermined
        }
    }

    // MARK: - Per-domain requests

    private func requestAVCapture(_ type: AVMediaType) async -> CapabilityAuthorization {
        let granted = await AVCaptureDevice.requestAccess(for: type)
        return granted ? .authorized : .denied
    }

    private func requestPhotos() async -> CapabilityAuthorization {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return map(status)
    }

    private func requestContacts() async -> CapabilityAuthorization {
        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        return granted ? .authorized : .denied
    }

    private func requestEvents(_ type: EKEntityType) async -> CapabilityAuthorization {
        let store = EKEventStore()
        do {
            let granted: Bool
            if type == .event {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestFullAccessToReminders()
            }
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    private func requestLocation() async -> CapabilityAuthorization {
        if locationManager.authorizationStatus != .notDetermined {
            return map(locationManager.authorizationStatus)
        }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Status mapping

    private func map(_ status: AVAuthorizationStatus) -> CapabilityAuthorization {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func map(_ status: CLAuthorizationStatus) -> CapabilityAuthorization {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func map(_ status: PHAuthorizationStatus) -> CapabilityAuthorization {
        switch status {
        case .authorized, .limited: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func map(_ status: CNAuthorizationStatus) -> CapabilityAuthorization {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private func map(_ status: EKAuthorizationStatus) -> CapabilityAuthorization {
        switch status {
        case .fullAccess, .authorized, .writeOnly: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}

extension CapabilityService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizations[.location] = map(status)
            if status != .notDetermined, let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(returning: map(status))
            }
        }
    }
}
