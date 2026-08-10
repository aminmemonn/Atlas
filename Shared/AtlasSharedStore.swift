import Foundation

/// Cross-process snapshot of agent state shared between the app, its widgets,
/// the Watch app, and App Intents via an App Group container.
///
/// Only non-sensitive, glanceable state lives here — never tokens or message
/// content. Secrets remain in the Keychain exclusively.
struct AtlasSnapshot: Codable, Sendable, Equatable {
    var agentStatus: String
    var statusLabel: String
    var pendingApprovalCount: Int
    var activeAutomationCount: Int
    var connectionLabel: String
    var updatedAt: Date

    static let placeholder = AtlasSnapshot(
        agentStatus: "idle",
        statusLabel: "Ready",
        pendingApprovalCount: 0,
        activeAutomationCount: 0,
        connectionLabel: "Connected",
        updatedAt: .now
    )
}

/// Reads/writes the shared snapshot. The App Group identifier must match the
/// `com.apple.security.application-groups` entitlement on every target.
struct AtlasSharedStore: Sendable {
    static let shared = AtlasSharedStore()
    static let appGroup = "group.com.atlas.agent"

    private let key = "atlas.snapshot"
    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.appGroup) }

    func write(_ snapshot: AtlasSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    func read() -> AtlasSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(AtlasSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }

    var pendingApprovalCount: Int { read().pendingApprovalCount }
}
