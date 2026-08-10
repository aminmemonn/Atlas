import Testing
import Foundation
@testable import Atlas

struct PairingPayloadTests {

    @Test func decodesValidSecurePayload() throws {
        let json = #"{"name":"Home Mac","endpoint":"wss://atlas.local:8443/ws","token":"secret-token"}"#
        let payload = try PairingPayload.decode(from: json)
        #expect(payload.name == "Home Mac")
        #expect(payload.endpoint.scheme == "wss")
        #expect(payload.token == "secret-token")
    }

    @Test func rejectsInsecureEndpoint() {
        let json = #"{"name":"Mac","endpoint":"ws://atlas.local/ws","token":"t"}"#
        #expect(throws: PairingPayload.PairingError.insecureEndpoint) {
            _ = try PairingPayload.decode(from: json)
        }
    }

    @Test func rejectsHTTPSEndpoint() {
        let json = #"{"name":"Mac","endpoint":"https://atlas.local/ws","token":"t"}"#
        #expect(throws: PairingPayload.PairingError.insecureEndpoint) {
            _ = try PairingPayload.decode(from: json)
        }
    }

    @Test func rejectsMalformedPayload() {
        #expect(throws: PairingPayload.PairingError.malformed) {
            _ = try PairingPayload.decode(from: "garbage")
        }
    }

    @Test func automationTitleTruncatesLongPrompts() {
        let long = String(repeating: "a", count: 100)
        let title = AutomationsViewModel.titleFromPrompt(long)
        #expect(title.count <= 46)
        #expect(title.hasSuffix("…"))
    }

    @Test func automationTitleUsesFirstSentence() {
        let title = AutomationsViewModel.titleFromPrompt("Summarize email. Then notify me.")
        #expect(title == "Summarize email")
    }
}
