import Foundation
import SwiftData

/// A self-hosted gateway profile the app can pair with.
///
/// The `token` is **never** stored on this model. It lives exclusively in the
/// Keychain, keyed by ``id``. See ``KeychainService``.
@Model
final class Gateway {
    @Attribute(.unique) var id: UUID
    var name: String

    /// Secure WebSocket endpoint. Only `wss://` is accepted at pairing time.
    var endpoint: URL

    var preferredModelRaw: String
    var createdAt: Date
    var lastConnectedAt: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        endpoint: URL,
        preferredModel: ModelProvider = .claude,
        createdAt: Date = .now,
        lastConnectedAt: Date? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.preferredModelRaw = preferredModel.rawValue
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
        self.isActive = isActive
    }

    var preferredModel: ModelProvider {
        get { ModelProvider(rawValue: preferredModelRaw) ?? .claude }
        set { preferredModelRaw = newValue.rawValue }
    }
}

/// A `Sendable` snapshot of the fields ``GatewayService`` needs to open a
/// connection. Extracted from the (non-`Sendable`) ``Gateway`` model on the main
/// actor so nothing crosses the actor boundary but plain value types.
struct GatewayConnectionInfo: Sendable, Equatable {
    var id: UUID
    var name: String
    var endpoint: URL

    init(id: UUID, name: String, endpoint: URL) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
    }

    @MainActor
    init(_ gateway: Gateway) {
        self.id = gateway.id
        self.name = gateway.name
        self.endpoint = gateway.endpoint
    }
}

/// The payload encoded in a pairing QR code or typed setup code.
///
/// Encoded as compact JSON and, for the manual-entry fallback, Base32 so it can
/// be read aloud or typed without ambiguous characters.
struct PairingPayload: Codable, Sendable, Equatable {
    var name: String
    var endpoint: URL
    var token: String

    enum PairingError: Error, LocalizedError {
        case malformed
        case insecureEndpoint

        var errorDescription: String? {
            switch self {
            case .malformed: "This pairing code could not be read."
            case .insecureEndpoint: "Atlas only connects over a secure wss:// gateway."
            }
        }
    }

    /// Parses a scanned/typed payload, enforcing the `wss://` security invariant.
    static func decode(from raw: String) throws -> PairingPayload {
        guard let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(PairingPayload.self, from: data)
        else {
            throw PairingError.malformed
        }
        guard payload.endpoint.scheme?.lowercased() == "wss" else {
            throw PairingError.insecureEndpoint
        }
        return payload
    }
}

/// Live transport state of the active gateway connection.
enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .reconnecting(let attempt): "Reconnecting (\(attempt))…"
        case .failed(let reason): reason
        }
    }
}
