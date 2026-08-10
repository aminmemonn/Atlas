import Foundation
import SwiftData

/// Handles creating automations from natural-language input and toggling them.
@MainActor
@Observable
final class AutomationsViewModel {
    var newPrompt: String = ""
    var isCreating = false

    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
    }

    var canCreate: Bool {
        !newPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    func create() {
        let prompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        isCreating = true

        // Optimistically persist; the gateway confirms the schedule via an update.
        let automation = Automation(
            title: Self.titleFromPrompt(prompt),
            prompt: prompt,
            scheduleDescription: "Pending schedule…",
            status: .idle
        )
        context.insert(automation)
        try? context.save()
        newPrompt = ""
        Haptics.impact(.medium)

        Task {
            try? await environment.gateway.send(.createAutomation(prompt: prompt))
            isCreating = false
        }
    }

    func setEnabled(_ automation: Automation, _ enabled: Bool) {
        automation.isEnabled = enabled
        try? context.save()
        Haptics.selection()
    }

    func delete(_ automation: Automation) {
        context.delete(automation)
        try? context.save()
    }

    /// Derives a concise title from the first clause of the prompt.
    nonisolated static func titleFromPrompt(_ prompt: String) -> String {
        let firstSentence = prompt.split(whereSeparator: { ".!?\n".contains($0) }).first.map(String.init) ?? prompt
        let trimmed = firstSentence.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 48 ? String(trimmed.prefix(45)) + "…" : trimmed
    }
}
