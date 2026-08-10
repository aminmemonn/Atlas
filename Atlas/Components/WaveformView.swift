import SwiftUI

/// A liquid-glass orb that breathes and ripples in response to live audio
/// amplitude. Rendered with `Canvas` so it animates smoothly at display refresh
/// without UIKit drawing. Used as the centerpiece of Talk Mode.
struct WaveformView: View {
    /// Normalized 0…1 amplitude driving the orb's expansion and ripple energy.
    var level: Float
    /// Whether the agent is actively speaking (shifts the palette warmer).
    var isSpeaking: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var smoothed: CGFloat = 0

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = min(size.width, size.height) * 0.30
                let energy = smoothed

                // Concentric glass rings rippling outward.
                for ring in 0..<3 {
                    let phase = t * 1.4 + Double(ring) * 0.7
                    let wobble = CGFloat(sin(phase)) * (6 + energy * 26)
                    let radius = base + CGFloat(ring) * 22 + wobble + energy * 40
                    let opacity = 0.30 - Double(ring) * 0.08
                    var path = Path()
                    let points = 120
                    for i in 0...points {
                        let angle = (Double(i) / Double(points)) * 2 * .pi
                        let rippled = radius + CGFloat(sin(angle * 6 + phase)) * (2 + energy * 14)
                        let point = CGPoint(
                            x: center.x + cos(angle) * rippled,
                            y: center.y + sin(angle) * rippled
                        )
                        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(palette.opacity(opacity)), lineWidth: 1.5)
                }

                // Core glowing orb.
                let coreRadius = base + energy * 30
                let gradient = Gradient(colors: [
                    palette.opacity(0.9),
                    palette.opacity(0.35),
                    palette.opacity(0)
                ])
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius,
                                           width: coreRadius * 2, height: coreRadius * 2)),
                    with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: coreRadius)
                )

                // Specular highlight for the glass feel.
                let hi = coreRadius * 0.5
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - hi * 0.6, y: center.y - hi * 1.1,
                                           width: hi, height: hi * 0.7)),
                    with: .color(.white.opacity(0.25))
                )
            }
        }
        .onChange(of: level) { _, newValue in
            withAnimation(.easeOut(duration: 0.18)) {
                smoothed = reduceMotion ? CGFloat(newValue) * 0.4 : CGFloat(newValue)
            }
        }
        .accessibilityHidden(true)
    }

    private var palette: Color {
        isSpeaking ? .atlasAccent : .blue
    }
}

#Preview {
    ZStack {
        AtlasBackground()
        WaveformView(level: 0.6, isSpeaking: true)
            .frame(width: 280, height: 280)
    }
}
