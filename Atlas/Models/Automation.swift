import Foundation
import SwiftData

/// A scheduled or recurring task the agent runs on the user's behalf.
@Model
final class Automation {
    @Attribute(.unique) var id: UUID
    var title: String
    var prompt: String
    var scheduleDescription: String
    var statusRaw: String
    var createdAt: Date
    var lastRunAt: Date?
    var nextRunAt: Date?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        title: String,
        prompt: String,
        scheduleDescription: String,
        status: Status = .idle,
        createdAt: Date = .now,
        lastRunAt: Date? = nil,
        nextRunAt: Date? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.scheduleDescription = scheduleDescription
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.lastRunAt = lastRunAt
        self.nextRunAt = nextRunAt
        self.isEnabled = isEnabled
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .idle }
        set { statusRaw = newValue.rawValue }
    }

    enum Status: String, Codable, Sendable {
        case idle
        case running
        case completed
        case failed

        var label: String {
            switch self {
            case .idle: "Scheduled"
            case .running: "Running"
            case .completed: "Completed"
            case .failed: "Failed"
            }
        }

        var symbolName: String {
            switch self {
            case .idle: "clock"
            case .running: "arrow.triangle.2.circlepath"
            case .completed: "checkmark.circle"
            case .failed: "xmark.circle"
            }
        }

        var tint: AutomationTint {
            switch self {
            case .idle: .neutral
            case .running: .active
            case .completed: .success
            case .failed: .failure
            }
        }
    }

    enum AutomationTint: Sendable {
        case neutral, active, success, failure
    }
}
