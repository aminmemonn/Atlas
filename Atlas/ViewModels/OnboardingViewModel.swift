import Foundation
import SwiftData
import SwiftUI

/// Drives the pairing flow: validating a scanned/typed payload, persisting the
/// gateway, storing its token in the Keychain, and connecting.
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome
        case pairing
        case permissions
        case done
    }

    var step: Step = .welcome
    var manualCode: String = ""
    var errorMessage: String?
    var isPairing = false

    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
    }

    func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation(.atlasSpring) { step = next }
        Haptics.impact(.light)
    }

    /// Handles a payload from either the QR scanner or manual entry.
    func pair(with raw: String) {
        isPairing = true
        errorMessage = nil
        do {
            let payload = try PairingPayload.decode(from: raw)
            let gateway = Gateway(
                name: payload.name,
                endpoint: payload.endpoint,
                isActive: true
            )
            try environment.keychain.storeToken(payload.token, for: gateway.id)
            context.insert(gateway)
            try context.save()

            environment.connect(to: gateway)
            Haptics.notify(.success)
            advance()
        } catch {
            errorMessage = (error as? PairingPayload.PairingError)?.errorDescription
                ?? "Pairing failed. Try again."
            Haptics.notify(.error)
        }
        isPairing = false
    }

    func pairWithManualCode() {
        let trimmed = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pair(with: trimmed)
    }

    func finish() {
        environment.completeOnboarding()
        Haptics.notify(.success)
    }
}
