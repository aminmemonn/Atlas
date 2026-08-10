import Foundation

/// Runtime state of the paired agent, derived from gateway events.
///
/// This is an in-memory value type rather than a SwiftData model because it
/// reflects live connection state rather than durable history.
struct AgentState: Equatable, Sendable {
    var status: Status
    var activeModel: ModelProvider
    var currentActivity: String?
    var lastHeartbeat: Date?

    init(
        status: Status = .idle,
        activeModel: ModelProvider = .claude,
        currentActivity: String? = nil,
        lastHeartbeat: Date? = nil
    ) {
        self.status = status
        self.activeModel = activeModel
        self.currentActivity = currentActivity
        self.lastHeartbeat = lastHeartbeat
    }

    enum Status: String, Sendable {
        case idle
        case thinking
        case working
        case awaitingApproval
        case offline

        var label: String {
            switch self {
            case .idle: "Ready"
            case .thinking: "Thinking…"
            case .working: "Working…"
            case .awaitingApproval: "Needs approval"
            case .offline: "Offline"
            }
        }

        var symbolName: String {
            switch self {
            case .idle: "sparkle"
            case .thinking: "brain"
            case .working: "gearshape.2"
            case .awaitingApproval: "exclamationmark.shield"
            case .offline: "bolt.slash"
            }
        }
    }
}

/// A model/provider the gateway can route requests to.
enum ModelProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case claude
    case gpt
    case gemini
    case local

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .gpt: "GPT"
        case .gemini: "Gemini"
        case .local: "Local Model"
        }
    }

    var subtitle: String {
        switch self {
        case .claude: "Anthropic · routed via gateway"
        case .gpt: "OpenAI · routed via gateway"
        case .gemini: "Google · routed via gateway"
        case .local: "On your hardware · fully private"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: "sparkles"
        case .gpt: "circle.hexagongrid"
        case .gemini: "diamond"
        case .local: "desktopcomputer"
        }
    }
}
