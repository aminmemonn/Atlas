import Foundation
import SwiftData

/// An action the gateway wants to take that requires explicit user consent.
@Model
final class Approval {
    @Attribute(.unique) var id: UUID
    var title: String
    var actionDescription: String

    /// The capability or surface the action touches (e.g. "filesystem", "shell").
    var domain: String

    var riskRaw: String
    var statusRaw: String
    var createdAt: Date
    var resolvedAt: Date?

    /// Structured details rendered in the expanded card (key/value pairs).
    var parameters: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        actionDescription: String,
        domain: String,
        risk: RiskLevel,
        status: Status = .pending,
        createdAt: Date = .now,
        resolvedAt: Date? = nil,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.actionDescription = actionDescription
        self.domain = domain
        self.riskRaw = risk.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.parameters = parameters
    }

    var risk: RiskLevel {
        get { RiskLevel(rawValue: riskRaw) ?? .medium }
        set { riskRaw = newValue.rawValue }
    }

    var status: Status {
        get { Status(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    enum Status: String, Codable, Sendable {
        case pending
        case approved
        case denied
        case expired
    }
}

/// Per-action risk classification surfaced on every approval card.
///
/// Ordering matters: `Comparable` conformance lets callers sort and threshold
/// by severity. See ``RiskScoring`` for how a raw gateway request is mapped to
/// one of these levels.
enum RiskLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case medium
    case high

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var symbolName: String {
        switch self {
        case .low: "checkmark.shield"
        case .medium: "exclamationmark.shield"
        case .high: "xmark.shield"
        }
    }

    /// Sort weight; higher means more severe.
    var severity: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.severity < rhs.severity
    }
}
