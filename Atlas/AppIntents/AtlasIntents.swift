import AppIntents
import SwiftUI

/// Siri / Shortcuts entry points. Keeping intents small and side-effect-light
/// keeps them reliable when invoked out-of-process; richer work is handed to the
/// app via a deep-link app-open so the live gateway connection is used.

/// Opens Atlas directly into Talk Mode.
struct StartTalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Talking to Atlas"
    static let description = IntentDescription("Opens Atlas and starts a voice conversation.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AtlasDeepLink.shared.pending = .talk
        return .result()
    }
}

/// Sends a one-shot message to the agent.
struct AskAtlasIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Atlas"
    static let description = IntentDescription("Send a question or instruction to your agent.")
    static let openAppWhenRun = true

    @Parameter(title: "Message")
    var message: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AtlasDeepLink.shared.pending = .ask(message)
        return .result(dialog: "Sent to Atlas.")
    }
}

/// Surfaces the count of pending approvals to Siri.
struct PendingApprovalsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Atlas Approvals"
    static let description = IntentDescription("Tells you how many actions are awaiting approval.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let count = AtlasSharedStore.shared.pendingApprovalCount
        let dialog: IntentDialog = count == 0
            ? "Nothing is waiting for approval."
            : "You have \(count) action\(count == 1 ? "" : "s") awaiting approval."
        return .result(dialog: dialog)
    }
}

/// Registers the shortcuts so they appear in the Shortcuts app and Siri.
struct AtlasShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTalkIntent(),
            phrases: ["Talk to \(.applicationName)", "Start \(.applicationName) voice"],
            shortTitle: "Talk",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: AskAtlasIntent(),
            phrases: ["Ask \(.applicationName)", "Tell \(.applicationName)"],
            shortTitle: "Ask",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
        AppShortcut(
            intent: PendingApprovalsIntent(),
            phrases: ["Check \(.applicationName) approvals"],
            shortTitle: "Approvals",
            systemImageName: "checkmark.shield"
        )
    }
}

/// Lightweight bridge for intent-triggered deep links the app reacts to on launch.
@MainActor
@Observable
final class AtlasDeepLink {
    static let shared = AtlasDeepLink()
    enum Action: Equatable { case talk, ask(String), approvals, chat, automations, settings }
    var pending: Action?

    /// Maps an `atlas://` URL to a pending action.
    func handle(url: URL) {
        switch url.host() {
        case "talk": pending = .talk
        case "approvals": pending = .approvals
        case "chat": pending = .chat
        case "automations": pending = .automations
        case "settings": pending = .settings
        default: break
        }
    }
}
