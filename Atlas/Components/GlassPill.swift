import SwiftUI

/// A small glass capsule used for inline tool-use indicators and status chips.
/// When `animating` is true, the leading symbol pulses to convey live activity.
struct GlassPill: View {
    var symbol: String
    var text: String
    var tint: Color = .atlasAccent
    var animating: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: animating)
                .scaleEffect(animating && pulse ? 1.12 : 1)

            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .atlasGlass(Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
        .onAppear {
            guard animating else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    ZStack {
        AtlasBackground()
        VStack(spacing: 12) {
            GlassPill(symbol: "magnifyingglass", text: "Searching the web…", animating: true)
            GlassPill(symbol: "doc.text", text: "Reading file…", tint: .blue, animating: true)
            GlassPill(symbol: "checkmark", text: "Done", tint: .green)
        }
    }
}
