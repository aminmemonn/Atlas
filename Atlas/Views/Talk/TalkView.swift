import SwiftUI
import SwiftData

/// Full-screen, immersive voice conversation. The orb reacts to live audio
/// amplitude; speech is transcribed and replies are spoken back.
struct TalkView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Message.createdAt, order: .forward) private var messages: [Message]
    @State private var viewModel: TalkViewModel?
    @State private var spokenMessageID: UUID?

    var body: some View {
        ZStack {
            AtlasBackground()
                .overlay(.black.opacity(0.15))

            if let viewModel {
                content(viewModel)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TalkViewModel(environment: environment, context: context)
            }
        }
        .task { await viewModel?.start() }
        .onDisappear { viewModel?.stop() }
        .onChange(of: lastCompletedAgentMessage?.id) { _, _ in speakLatestReply() }
    }

    @ViewBuilder
    private func content(_ vm: TalkViewModel) -> some View {
        VStack(spacing: 0) {
            header(vm)

            Spacer()
            WaveformView(level: vm.visualizationLevel, isSpeaking: vm.isSpeaking)
                .frame(width: 300, height: 300)
                .accessibilityLabel(statusLabel(vm))

            Text(statusLabel(vm))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .padding(.top, 8)
            Spacer()

            transcript(vm)
            controls(vm)
        }
        .padding(24)
    }

    private func header(_ vm: TalkViewModel) -> some View {
        HStack {
            Text("Talk").font(.system(.title2, design: .rounded, weight: .bold))
            Spacer()
            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .atlasGlass(Circle())
            }
            .accessibilityLabel("Close Talk Mode")
        }
    }

    @ViewBuilder
    private func transcript(_ vm: TalkViewModel) -> some View {
        let text = vm.phase == .responding ? vm.lastReply : (vm.voice.transcript.isEmpty ? vm.liveTranscript : vm.voice.transcript)
        if !text.isEmpty {
            GlassCard {
                Text(text)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 16)
            .transition(.opacity)
        }
    }

    private func controls(_ vm: TalkViewModel) -> some View {
        HStack(spacing: 28) {
            ControlButton(symbol: vm.phase == .listening ? "mic.fill" : "mic",
                          active: vm.phase == .listening) {
                vm.phase == .listening ? vm.stop() : vm.beginListening()
            }
            ControlButton(symbol: "stop.fill", active: false) {
                vm.stop()
            }
        }
        .padding(.bottom, 12)
    }

    private func statusLabel(_ vm: TalkViewModel) -> String {
        switch vm.phase {
        case .idle: "Tap the mic to talk"
        case .listening: "Listening…"
        case .thinking: "Thinking…"
        case .responding: "Atlas is speaking"
        }
    }

    private var lastCompletedAgentMessage: Message? {
        messages.last { $0.role == .agent && !$0.isStreaming }
    }

    private func speakLatestReply() {
        guard let reply = lastCompletedAgentMessage,
              reply.id != spokenMessageID,
              !reply.text.isEmpty else { return }
        spokenMessageID = reply.id
        viewModel?.present(reply: reply.text)
    }
}

private struct ControlButton: View {
    var symbol: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(active ? .white : .primary)
                .frame(width: 64, height: 64)
                .background {
                    Circle().fill(active ? Color.atlasAccent : .clear)
                }
                .atlasGlass(Circle(), interactive: true)
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
