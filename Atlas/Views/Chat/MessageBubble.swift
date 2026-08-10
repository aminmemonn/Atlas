import SwiftUI

/// A single chat bubble. User and agent turns are visually distinct: the user's
/// uses the accent-tinted surface, the agent's a neutral glass card. Streaming
/// agent text reveals with a soft cursor.
struct MessageBubble: View {
    let message: Message

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                if !message.toolEvents.isEmpty {
                    toolEvents
                }
                if !message.text.isEmpty || message.isStreaming {
                    bubble
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }

    private var bubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(isUser ? .white : .primary)
            .textSelection(.enabled)
            .overlay(alignment: .bottomTrailing) {
                if message.isStreaming {
                    StreamingCursor()
                        .offset(x: 10, y: -2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
                if isUser {
                    shape.fill(Color.atlasAccent.opacity(0.85))
                } else {
                    shape.fill(.clear).atlasGlass(shape)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(isUser ? 0.18 : 0.12), lineWidth: 0.5)
            )
            .accessibilityLabel("\(isUser ? "You" : "Atlas"): \(message.text)")
    }

    private var toolEvents: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(message.toolEvents) { event in
                GlassPill(
                    symbol: symbol(for: event),
                    text: label(for: event),
                    tint: tint(for: event.status),
                    animating: event.status == .running
                )
            }
        }
    }

    private func symbol(for event: ToolEvent) -> String {
        let name = event.name.lowercased()
        if name.contains("search") || name.contains("web") { return "magnifyingglass" }
        if name.contains("file") || name.contains("read") { return "doc.text" }
        if name.contains("code") || name.contains("run") { return "terminal" }
        return event.status.symbolName
    }

    private func label(for event: ToolEvent) -> String {
        switch event.status {
        case .running: event.detail.isEmpty ? "\(event.name)…" : event.detail
        case .completed: event.name
        case .failed: "\(event.name) failed"
        }
    }

    private func tint(for status: ToolEvent.Status) -> Color {
        switch status {
        case .running: .atlasAccent
        case .completed: .green
        case .failed: .red
        }
    }
}

/// A blinking caret shown while the agent is streaming.
private struct StreamingCursor: View {
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.atlasAccent)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { visible.toggle() }
            }
            .accessibilityHidden(true)
    }
}
