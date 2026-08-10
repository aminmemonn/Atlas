import Testing
import Foundation
@testable import Atlas

struct GatewayCoderTests {
    let coder = GatewayCoder()

    @Test func decodesMessageDelta() throws {
        let id = UUID()
        let json = """
        {"type":"message_delta","payload":{"id":"\(id.uuidString)","text":"Hello"}}
        """
        let frame = try coder.decodeFrame(json)
        #expect(frame == .messageDelta(id: id, text: "Hello"))
    }

    @Test func decodesToolStartedWithMissingDetail() throws {
        let id = UUID()
        let json = """
        {"type":"tool_started","payload":{"messageID":"\(id.uuidString)","name":"web_search"}}
        """
        let frame = try coder.decodeFrame(json)
        #expect(frame == .toolStarted(messageID: id, name: "web_search", detail: ""))
    }

    @Test func decodesApprovalRequest() throws {
        let id = UUID()
        let json = """
        {"type":"approval_requested","payload":{"id":"\(id.uuidString)","title":"Run script","description":"executes build.sh","domain":"shell","parameters":{"cmd":"sh build.sh"}}}
        """
        let frame = try coder.decodeFrame(json)
        guard case let .approvalRequested(req) = frame else {
            Issue.record("expected approvalRequested")
            return
        }
        #expect(req.id == id)
        #expect(req.domain == "shell")
        #expect(req.parameters["cmd"] == "sh build.sh")
    }

    @Test func unknownFrameTypeDoesNotThrow() throws {
        let json = #"{"type":"future_feature","payload":{"x":1}}"#
        let frame = try coder.decodeFrame(json)
        #expect(frame == .unknown(type: "future_feature"))
    }

    @Test func heartbeatDecodes() throws {
        let frame = try coder.decodeFrame(#"{"type":"heartbeat"}"#)
        #expect(frame == .heartbeat)
    }

    @Test func encodesSendMessageRoundTripsFields() throws {
        let id = UUID()
        let text = try coder.encodeCommand(.sendMessage(id: id, text: "hi", model: .claude))
        #expect(text.contains("\"type\":\"send_message\"") || text.contains("\"type\" : \"send_message\""))
        #expect(text.contains(id.uuidString))
        #expect(text.contains("hi"))
    }

    @Test func encodesResolveApproval() throws {
        let id = UUID()
        let text = try coder.encodeCommand(.resolveApproval(id: id, approved: true))
        #expect(text.contains("resolve_approval"))
        #expect(text.contains(id.uuidString))
    }

    @Test func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            _ = try coder.decodeFrame("not json")
        }
    }
}
