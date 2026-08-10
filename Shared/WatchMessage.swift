import Foundation

/// Contract for messages exchanged between the iOS app and the Watch companion
/// over WatchConnectivity. The phone owns the gateway connection; the Watch is a
/// thin glanceable remote.
enum WatchMessage {
    static let typeKey = "type"
    static let payloadKey = "payload"

    /// Phone → Watch: latest glanceable snapshot (encoded ``AtlasSnapshot``).
    static let snapshot = "snapshot"
    /// Watch → Phone: resolve an approval. Payload: ["id": uuid, "approved": bool].
    static let resolveApproval = "resolveApproval"
    /// Watch → Phone: start a voice command / open talk. Payload: ["text": String?].
    static let quickVoice = "quickVoice"
}

/// Glanceable approval summary mirrored to the Watch (no sensitive parameters).
struct WatchApproval: Codable, Sendable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var risk: String
    var domain: String
}
