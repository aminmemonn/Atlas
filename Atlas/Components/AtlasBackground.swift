import SwiftUI
import UIKit

/// The ambient app background: a softly animated mesh of translucent color that
/// gives the glass surfaces something to refract. Subtle by design, and it
/// respects Reduce Motion by holding still.
struct AtlasBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.atlasSurface))

                let blobs: [(CGColor, CGFloat, CGFloat)] = [
                    (UIColor.systemIndigo.cgColor, 0.25, 0.20),
                    (UIColor.systemPurple.cgColor, 0.75, 0.30),
                    (UIColor.systemBlue.cgColor, 0.50, 0.80)
                ]
                for (index, blob) in blobs.enumerated() {
                    let (color, bx, by) = blob
                    let drift = CGFloat(sin(t * 0.2 + Double(index))) * 40
                    let center = CGPoint(x: size.width * bx + drift,
                                         y: size.height * by - drift)
                    let radius = max(size.width, size.height) * 0.55
                    let gradient = Gradient(colors: [
                        Color(cgColor: color).opacity(0.45),
                        Color(cgColor: color).opacity(0)
                    ])
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2)),
                        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius)
                    )
                }
            }
            .blur(radius: 60)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    AtlasBackground()
}
