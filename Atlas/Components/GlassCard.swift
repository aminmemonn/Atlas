import SwiftUI

/// A translucent, refractive content container — the workhorse surface used by
/// approval cards, automation rows, settings groups, and message bubbles.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var padding: CGFloat = 16
    var interactive: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .atlasGlass(cornerRadius: cornerRadius, interactive: interactive)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }
}

#Preview {
    ZStack {
        AtlasBackground()
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Card").font(.headline)
                Text("Translucent layered material with subtle refraction.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
