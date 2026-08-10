import Foundation
import SwiftData

/// A single turn in a conversation with the agent.
///
/// Messages are persisted locally via SwiftData so that conversation history is
/// available fully offline. Only live actions require a gateway connection.
@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var text: String
    @Relationship(deleteRule: .cascade) var toolEvents: [ToolEvent]
    var createdAt: Date
    var isStreaming: Bool
    var attachmentIdentifiers: [String]

    init(
        id: UUID = UUID(),
        role: Role,
        text: String = "",
        toolEvents: [ToolEvent] = [],
        createdAt: Date = .now,
        isStreaming: Bool = false,
        attachmentIdentifiers: [String] = []
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.text = text
        self.toolEvents = toolEvents
        self.createdAt = createdAt
        self.isStreaming = isStreaming
        self.attachmentIdentifiers = attachmentIdentifiers
    }

    var role: Role {
        get { Role(rawValue: roleRaw) ?? .agent }
        set { roleRaw = newValue.rawValue }
    }

    enum Role: String, Codable, Sendable, CaseIterable {
        case user
        case agent
        case system
    }
}

/// An inline tool-use event ("Searching the web…", "Reading file…").
@Model
final class ToolEvent {
    @Attribute(.unique) var id: UUID
    var name: String
    var detail: String
    var statusRaw: String
    var startedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        detail: String = "",
        status: Status = .running,
        startedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .running }
        set { statusRaw = newValue.rawValue }
    }

    enum Status: String, Codable, Sendable {
        case running
        case completed
        case failed

        var symbolName: String {
            switch self {
            case .running: "ellipsis"
            case .completed: "checkmark"
            case .failed: "exclamationmark.triangle"
            }
        }
    }
}
