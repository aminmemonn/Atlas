import Foundation

/// Derives a per-action risk level from an inbound approval request.
///
/// This is the core differentiator versus a flat approve/deny model: every
/// request is classified Low / Medium / High based on *what the action does*,
/// not merely that it exists. The logic is intentionally pure and deterministic
/// so it is fully unit-testable and produces identical results offline.
enum RiskScoring {
    /// Domains that are inherently sensitive regardless of parameters.
    private static let highRiskDomains: Set<String> = [
        "shell", "exec", "process", "payment", "purchase", "finance",
        "delete", "credentials", "keychain", "ssh"
    ]

    private static let mediumRiskDomains: Set<String> = [
        "filesystem", "file", "network", "http", "email", "message",
        "calendar", "contacts", "automation", "screen"
    ]

    /// Parameter keywords that escalate risk by one level when present.
    private static let escalatingKeywords: Set<String> = [
        "delete", "remove", "rm", "drop", "wipe", "format", "sudo",
        "password", "secret", "token", "transfer", "send", "publish",
        "overwrite", "force"
    ]

    /// Scores a request. A gateway-supplied `riskHint`, when valid, is taken as a
    /// floor — the gateway can raise but never silently lower the local estimate.
    static func score(_ request: ApprovalRequest) -> RiskLevel {
        var level = baseLevel(forDomain: request.domain)

        if containsEscalatingSignal(in: request) {
            level = escalate(level)
        }

        if let hint = request.riskHint.flatMap({ RiskLevel(rawValue: $0.lowercased()) }) {
            level = max(level, hint)
        }

        return level
    }

    // MARK: - Components (exposed for focused testing)

    static func baseLevel(forDomain domain: String) -> RiskLevel {
        let normalized = domain.lowercased()
        if highRiskDomains.contains(normalized) { return .high }
        if mediumRiskDomains.contains(normalized) { return .medium }
        return .low
    }

    static func containsEscalatingSignal(in request: ApprovalRequest) -> Bool {
        let haystack = ([request.title, request.description]
            + request.parameters.values)
            .joined(separator: " ")
            .lowercased()
        return escalatingKeywords.contains { keyword in
            haystack.range(of: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b",
                           options: .regularExpression) != nil
        }
    }

    static func escalate(_ level: RiskLevel) -> RiskLevel {
        switch level {
        case .low: .medium
        case .medium: .high
        case .high: .high
        }
    }
}
