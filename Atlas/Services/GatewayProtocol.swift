import Foundation

/// Wire protocol shared between the app and the self-hosted gateway.
///
/// All frames are JSON objects with a `type` discriminator and a `payload`.
/// Keeping the envelope explicit (rather than relying on enum synthesis) makes
/// the protocol forward-compatible: unknown frame types decode to ``unknown``
/// instead of throwing, so an older app never crashes against a newer gateway.
enum GatewayFrame: Sendable, Equatable {
    case ready(model: ModelProvider)
    case messageDelta(id: UUID, text: String)
    case messageCompleted(id: UUID)
    case toolStarted(messageID: UUID, name: String, detail: String)
    case toolFinished(messageID: UUID, name: String, success: Bool)
    case approvalRequested(ApprovalRequest)
    case automationUpdated(AutomationUpdate)
    case agentStatus(AgentState.Status, activity: String?)
    case heartbeat
    case error(message: String)
    case unknown(type: String)
}

/// Inbound approval request as it arrives on the wire, before risk scoring.
struct ApprovalRequest: Codable, Sendable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var domain: String
    var parameters: [String: String]

    /// Optional gateway-supplied risk hint. When absent, ``RiskScoring`` derives
    /// a level locally so the user always sees a classification.
    var riskHint: String?
}

struct AutomationUpdate: Codable, Sendable, Equatable {
    var id: UUID
    var title: String
    var scheduleDescription: String
    var status: String
    var nextRunAt: Date?
}

/// Outbound frames the app sends to the gateway.
enum GatewayCommand: Sendable, Equatable {
    case sendMessage(id: UUID, text: String, model: ModelProvider)
    case resolveApproval(id: UUID, approved: Bool)
    case createAutomation(prompt: String)
    case setCapability(DeviceCapability, enabled: Bool)
    case cancelMessage(id: UUID)
}

/// Encodes/decodes ``GatewayFrame`` and ``GatewayCommand`` to/from JSON text.
///
/// Pure and `Sendable`, so it can be unit-tested in isolation and used from any
/// isolation domain.
struct GatewayCoder: Sendable {
    // Computed so the coder stays `Sendable` — JSONEncoder/JSONDecoder are
    // reference types and inexpensive to create per call.
    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: Decoding inbound frames

    func decodeFrame(_ text: String) throws -> GatewayFrame {
        guard let data = text.data(using: .utf8) else {
            throw GatewayCodingError.notUTF8
        }
        let envelope = try decoder.decode(Envelope.self, from: data)
        let payloadData = envelope.payload.flatMap { try? JSONEncoder().encode($0) }

        func payload<T: Decodable>(_ type: T.Type) throws -> T {
            guard let raw = envelope.payload else { throw GatewayCodingError.missingPayload }
            let data = try encoder.encode(raw)
            return try decoder.decode(T.self, from: data)
        }

        switch envelope.type {
        case "ready":
            let p = try payload(ReadyPayload.self)
            return .ready(model: ModelProvider(rawValue: p.model) ?? .claude)
        case "message_delta":
            let p = try payload(MessageDeltaPayload.self)
            return .messageDelta(id: p.id, text: p.text)
        case "message_completed":
            let p = try payload(IDPayload.self)
            return .messageCompleted(id: p.id)
        case "tool_started":
            let p = try payload(ToolStartedPayload.self)
            return .toolStarted(messageID: p.messageID, name: p.name, detail: p.detail ?? "")
        case "tool_finished":
            let p = try payload(ToolFinishedPayload.self)
            return .toolFinished(messageID: p.messageID, name: p.name, success: p.success)
        case "approval_requested":
            return .approvalRequested(try payload(ApprovalRequest.self))
        case "automation_updated":
            return .automationUpdated(try payload(AutomationUpdate.self))
        case "agent_status":
            let p = try payload(AgentStatusPayload.self)
            return .agentStatus(AgentState.Status(rawValue: p.status) ?? .idle, activity: p.activity)
        case "heartbeat":
            return .heartbeat
        case "error":
            let p = try payload(ErrorPayload.self)
            return .error(message: p.message)
        default:
            _ = payloadData
            return .unknown(type: envelope.type)
        }
    }

    // MARK: Encoding outbound commands

    func encodeCommand(_ command: GatewayCommand) throws -> String {
        let envelope: Envelope
        switch command {
        case let .sendMessage(id, text, model):
            envelope = try makeEnvelope("send_message", SendMessagePayload(id: id, text: text, model: model.rawValue))
        case let .resolveApproval(id, approved):
            envelope = try makeEnvelope("resolve_approval", ResolveApprovalPayload(id: id, approved: approved))
        case let .createAutomation(prompt):
            envelope = try makeEnvelope("create_automation", PromptPayload(prompt: prompt))
        case let .setCapability(capability, enabled):
            envelope = try makeEnvelope("set_capability", CapabilityPayload(capability: capability.rawValue, enabled: enabled))
        case let .cancelMessage(id):
            envelope = try makeEnvelope("cancel_message", IDPayload(id: id))
        }
        let data = try encoder.encode(envelope)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GatewayCodingError.notUTF8
        }
        return text
    }

    private func makeEnvelope<T: Encodable>(_ type: String, _ payload: T) throws -> Envelope {
        let data = try encoder.encode(payload)
        let json = try decoder.decode(AnyCodable.self, from: data)
        return Envelope(type: type, payload: json)
    }

    // MARK: Envelope & payloads

    private struct Envelope: Codable {
        var type: String
        var payload: AnyCodable?
    }

    private struct ReadyPayload: Codable { var model: String }
    private struct MessageDeltaPayload: Codable { var id: UUID; var text: String }
    private struct IDPayload: Codable { var id: UUID }
    private struct ToolStartedPayload: Codable { var messageID: UUID; var name: String; var detail: String? }
    private struct ToolFinishedPayload: Codable { var messageID: UUID; var name: String; var success: Bool }
    private struct AgentStatusPayload: Codable { var status: String; var activity: String? }
    private struct ErrorPayload: Codable { var message: String }
    private struct SendMessagePayload: Codable { var id: UUID; var text: String; var model: String }
    private struct ResolveApprovalPayload: Codable { var id: UUID; var approved: Bool }
    private struct PromptPayload: Codable { var prompt: String }
    private struct CapabilityPayload: Codable { var capability: String; var enabled: Bool }
}

enum GatewayCodingError: Error, Equatable {
    case notUTF8
    case missingPayload
}

/// Minimal type-erased JSON value so the envelope can carry heterogeneous
/// payloads without a giant sum type.
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v.mapValues(\.value) }
        else if let v = try? container.decode([AnyCodable].self) { value = v.map(\.value) }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: Any]: try container.encode(v.mapValues(AnyCodable.init))
        case let v as [Any]: try container.encode(v.map(AnyCodable.init))
        default: try container.encodeNil()
        }
    }
}
