import Foundation
import SwiftData

/// Coordinates Talk Mode: starts/stops listening, forwards finalized utterances
/// to the gateway, and speaks streamed agent replies aloud.
@MainActor
@Observable
final class TalkViewModel {
    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case responding
    }

    var phase: Phase = .idle
    var liveTranscript: String = ""
    var lastReply: String = ""

    private let environment: AppEnvironment
    private let context: ModelContext

    var voice: VoiceService { environment.voice }

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
        environment.voice.onUtterance = { [weak self] text in
            self?.handleUtterance(text)
        }
    }

    func start() async {
        #if DEBUG
        // Screenshot/UI-test mode: render an active orb without requesting
        // system permissions or capturing audio. Compiled out of release builds.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "atlas.screenshotMode") || defaults.bool(forKey: "atlas.openTalk") {
            lastReply = "Sure — here's your morning: three new emails, one needs a reply, and your 10 AM moved to 10:30."
            phase = .responding
            return
        }
        #endif
        await environment.voice.requestPermissions()
        beginListening()
    }

    func beginListening() {
        do {
            try environment.voice.startListening()
            phase = .listening
            Haptics.impact(.light)
        } catch {
            phase = .idle
        }
    }

    func stop() {
        environment.voice.stopListening()
        environment.voice.stopSpeaking()
        phase = .idle
    }

    /// Speaks an agent reply that arrived via the gateway stream.
    func present(reply: String) {
        lastReply = reply
        phase = .responding
        environment.voice.speak(reply)
    }

    private func handleUtterance(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            beginListening()
            return
        }
        liveTranscript = text
        phase = .thinking
        Haptics.selection()

        let message = Message(role: .user, text: text)
        context.insert(message)
        try? context.save()

        Task {
            try? await environment.gateway.send(
                .sendMessage(id: UUID(), text: text, model: environment.agentState.activeModel)
            )
        }
    }

    var visualizationLevel: Float {
        switch phase {
        case .responding: return 0.55
        default: return voice.inputLevel
        }
    }

    var isSpeaking: Bool { phase == .responding }
}
