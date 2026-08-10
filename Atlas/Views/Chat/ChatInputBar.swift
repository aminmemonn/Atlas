import SwiftUI

/// Floating glass input bar with an expandable text field, plus voice and image
/// entry points. Grows vertically for longer messages.
struct ChatInputBar: View {
    @Binding var text: String
    var canSend: Bool
    var onSend: () -> Void
    var onVoice: () -> Void
    var onCamera: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: onCamera) {
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Add image")

            TextField("Message Atlas…", text: $text, axis: .vertical)
                .focused($focused)
                .lineLimit(1...6)
                .font(.body)
                .padding(.vertical, 8)

            if canSend {
                Button(action: {
                    Haptics.impact(.light)
                    onSend()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, Color.atlasAccent)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Send")
            } else {
                Button(action: onVoice) {
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.atlasAccent)
                        .frame(width: 36, height: 36)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Talk")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .atlasGlass(cornerRadius: 26, interactive: true)
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
        .animation(.atlasSnappy, value: canSend)
    }
}
