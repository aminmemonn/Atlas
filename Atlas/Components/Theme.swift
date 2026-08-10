import SwiftUI
import UIKit

/// Centralized design tokens. Colors are defined in the asset catalog so they
/// adapt automatically to Light/Dark mode and high-contrast settings.
extension Color {
    static let atlasAccent = Color("AccentColor")
    static let atlasSurface = Color("Surface")
    static let atlasUserBubble = Color("UserBubble")
}

extension ShapeStyle where Self == Color {
    static var atlasAccent: Color { .atlasAccent }
}

/// Risk-level tinting used across approval surfaces.
extension RiskLevel {
    var tint: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}

extension Automation.AutomationTint {
    var color: Color {
        switch self {
        case .neutral: .secondary
        case .active: .atlasAccent
        case .success: .green
        case .failure: .red
        }
    }
}

/// Shared spring used for all transitions so motion feels coherent.
extension Animation {
    static let atlasSpring = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let atlasSnappy = Animation.spring(response: 0.3, dampingFraction: 0.78)
}

/// Lightweight haptic helper. Centralizing avoids scattering generator
/// instantiation across views and keeps feedback intensities consistent.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// Applies Liquid Glass on iOS 26+, falling back to layered materials on older
/// systems so the app degrades gracefully without losing its depth.
struct GlassBackground: ViewModifier {
    var shape: AnyShape
    var interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: shape
            )
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(.white.opacity(0.12), lineWidth: 0.5)
                )
        }
    }
}

extension View {
    /// Applies the Atlas glass treatment clipped to `shape`.
    func atlasGlass<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        modifier(GlassBackground(shape: AnyShape(shape), interactive: interactive))
    }

    /// Applies the Atlas glass treatment with a default rounded-rect shape.
    func atlasGlass(cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(GlassBackground(
            shape: AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)),
            interactive: interactive
        ))
    }
}
