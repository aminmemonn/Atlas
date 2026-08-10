import SwiftUI
import UIKit

/// Visual weight of a ``GlassButton``. Declared at file scope (not nested in the
/// generic) so the button and its `ButtonStyle` share one concrete type.
enum GlassProminence {
    case primary
    case secondary
    case destructive
}

/// A glass button that bends light on press and fires haptic feedback. Used for
/// primary actions across onboarding, approvals, and the input bar.
struct GlassButton<Label: View>: View {
    var prominence: GlassProminence = .primary
    var haptic: UIImpactFeedbackGenerator.FeedbackStyle = .medium
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            Haptics.impact(haptic)
            action()
        } label: {
            label()
                .font(.headline)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Capsule())
        }
        .buttonStyle(GlassButtonStyle(prominence: prominence))
    }

    private var foreground: Color {
        switch prominence {
        case .primary: .white
        case .secondary: .primary
        case .destructive: .white
        }
    }
}

/// Press-responsive style applying glass and a light-bending scale/brightness.
private struct GlassButtonStyle: ButtonStyle {
    var prominence: GlassProminence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule().fill(fill(pressed: configuration.isPressed))
            }
            .atlasGlass(Capsule(), interactive: true)
            .overlay(
                Capsule().strokeBorder(.white.opacity(configuration.isPressed ? 0.35 : 0.18), lineWidth: 0.5)
            )
            .brightness(configuration.isPressed ? 0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.atlasSnappy, value: configuration.isPressed)
    }

    private func fill(pressed: Bool) -> some ShapeStyle {
        switch prominence {
        case .primary:
            return AnyShapeStyle(Color.atlasAccent.opacity(pressed ? 0.9 : 0.78))
        case .secondary:
            return AnyShapeStyle(Color.white.opacity(pressed ? 0.16 : 0.08))
        case .destructive:
            return AnyShapeStyle(Color.red.opacity(pressed ? 0.95 : 0.82))
        }
    }
}

extension GlassButton where Label == Text {
    init(_ title: String,
         prominence: GlassProminence = .primary,
         action: @escaping () -> Void) {
        self.init(prominence: prominence, action: action) { Text(title) }
    }
}
