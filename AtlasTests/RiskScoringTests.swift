import Testing
@testable import Atlas

struct RiskScoringTests {

    private func request(
        title: String = "Action",
        description: String = "",
        domain: String,
        parameters: [String: String] = [:],
        hint: String? = nil
    ) -> ApprovalRequest {
        ApprovalRequest(id: UUID(), title: title, description: description,
                        domain: domain, parameters: parameters, riskHint: hint)
    }

    @Test func benignDomainScoresLow() {
        #expect(RiskScoring.score(request(domain: "weather")) == .low)
        #expect(RiskScoring.score(request(domain: "notes")) == .low)
    }

    @Test func sensitiveDomainScoresMedium() {
        #expect(RiskScoring.score(request(domain: "filesystem")) == .medium)
        #expect(RiskScoring.score(request(domain: "email")) == .medium)
    }

    @Test func dangerousDomainScoresHigh() {
        #expect(RiskScoring.score(request(domain: "shell")) == .high)
        #expect(RiskScoring.score(request(domain: "payment")) == .high)
    }

    @Test func escalatingKeywordRaisesLevel() {
        // A medium domain with a destructive verb escalates to high.
        let r = request(description: "delete the project folder", domain: "filesystem")
        #expect(RiskScoring.score(r) == .high)
    }

    @Test func escalatingKeywordInParametersCounts() {
        let r = request(domain: "network", parameters: ["body": "please transfer funds"])
        #expect(RiskScoring.score(r) == .high)
    }

    @Test func keywordMatchesOnWordBoundaryOnly() {
        // "undelete" should not trip the "delete" keyword.
        let r = request(description: "undeleted history view", domain: "notes")
        #expect(RiskScoring.score(r) == .low)
    }

    @Test func gatewayHintCanRaiseButNotLowerRisk() {
        // Hint higher than local estimate wins.
        let raised = request(domain: "notes", hint: "high")
        #expect(RiskScoring.score(raised) == .high)

        // Hint lower than local estimate is ignored (floor behavior).
        let floored = request(domain: "shell", hint: "low")
        #expect(RiskScoring.score(floored) == .high)
    }

    @Test func riskLevelIsOrdered() {
        #expect(RiskLevel.low < RiskLevel.medium)
        #expect(RiskLevel.medium < RiskLevel.high)
        #expect(max(RiskLevel.low, RiskLevel.high) == .high)
    }
}
