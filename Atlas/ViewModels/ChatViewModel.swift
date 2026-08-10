import Foundation
import SwiftData
import SwiftUI

/// Drives the chat screen: composing input, persisting the user's turn, and
/// dispatching the message to the gateway. Streaming agent responses arrive via
/// ``AppEnvironment`` frame handling and are observed through `@Query` in the view.
@MainActor
@Observable
final class ChatViewModel {
    var draft: String = ""
    var isSending = false
    var errorMessage: String?

    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && environment.connectionState.isConnected
            && !isSending
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let message = Message(role: .user, text: text)
        context.insert(message)
        try? context.save()

        draft = ""
        isSending = true
        Haptics.impact(.light)

        Task {
            do {
                try await environment.gateway.send(
                    .sendMessage(id: UUID(), text: text, model: environment.agentState.activeModel)
                )
            } catch {
                errorMessage = "Couldn't reach the gateway. Check your connection."
                Haptics.notify(.error)
            }
            isSending = false
        }
    }

    func clearHistory() {
        try? context.delete(model: Message.self)
        try? context.save()
        Haptics.impact(.rigid)
    }
}
