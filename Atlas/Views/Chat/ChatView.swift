import SwiftUI
import SwiftData

/// Primary chat surface: scrollable history with streaming responses and a
/// floating glass input bar.
struct ChatView: View {
    var onOpenTalk: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .forward) private var messages: [Message]
    @State private var viewModel: ChatViewModel?

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
        }
        .safeAreaInset(edge: .bottom) {
            if let viewModel {
                ChatInputBar(
                    text: Binding(get: { viewModel.draft }, set: { viewModel.draft = $0 }),
                    canSend: viewModel.canSend,
                    onSend: viewModel.send,
                    onVoice: onOpenTalk,
                    onCamera: {}
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 78) // clear the floating tab bar
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(environment: environment, context: context)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Atlas").font(.system(.title2, design: .rounded, weight: .bold))
                ConnectionBadge(state: environment.connectionState, agent: environment.agentState)
            }
            Spacer()
            Button(action: onOpenTalk) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.atlasAccent)
                    .symbolEffect(.pulse, isActive: environment.agentState.status == .thinking)
            }
            .accessibilityLabel("Open Talk Mode")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if messages.isEmpty { EmptyChatState() }
                    ForEach(messages) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.last?.text) { _, _ in
                if let last = messages.last {
                    withAnimation(.atlasSpring) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.atlasSpring) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

private struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.atlasAccent)
                .symbolEffect(.breathe)
            Text("How can I help?")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("Ask anything, run a task, or tap the waveform to talk.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// Compact connection + agent status indicator shown under the title.
struct ConnectionBadge: View {
    let state: ConnectionState
    let agent: AgentState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.7), radius: 4)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        if !state.isConnected { return state.label }
        return agent.status.label
    }

    private var color: Color {
        switch state {
        case .connected: agent.status == .awaitingApproval ? .orange : .green
        case .connecting, .reconnecting: .yellow
        case .disconnected, .failed: .red
        }
    }
}
