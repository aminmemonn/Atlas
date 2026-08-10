import SwiftUI
import SwiftData

/// App shell. Shows onboarding until pairing completes, then the main surface
/// with a floating glass tab bar.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ZStack {
            AtlasBackground()
            if environment.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.atlasSpring, value: environment.hasCompletedOnboarding)
        .preferredColorScheme(nil) // adapt to system Light/Dark
    }
}

/// The five primary destinations behind a custom floating glass tab bar.
struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: Tab
    @State private var showTalk: Bool

    init() {
        var tab: Tab = .chat
        var talk = false
        #if DEBUG
        // Launch-argument hooks used only for automated screenshots / UI tests.
        // Compiled out of release and TestFlight builds.
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "atlas.initialTab") {
        case "approvals": tab = .approvals
        case "automations": tab = .automations
        case "settings": tab = .settings
        default: tab = .chat
        }
        talk = defaults.bool(forKey: "atlas.openTalk")
        #endif
        _selection = State(initialValue: tab)
        _showTalk = State(initialValue: talk)
    }

    enum Tab: Int, CaseIterable, Identifiable {
        case chat, approvals, automations, settings
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .chat: "Chat"
            case .approvals: "Approvals"
            case .automations: "Tasks"
            case .settings: "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .chat: "bubble.left.and.text.bubble.right"
            case .approvals: "checkmark.shield"
            case .automations: "bolt.badge.clock"
            case .settings: "gearshape"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selection {
                case .chat: ChatView(onOpenTalk: { showTalk = true })
                case .approvals: ApprovalsView()
                case .automations: AutomationsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selection: $selection)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .fullScreenCover(isPresented: $showTalk) {
            TalkView()
        }
        .onChange(of: deepLink.pending) { _, action in
            guard let action else { return }
            switch action {
            case .talk: showTalk = true
            case .approvals: withAnimation(.atlasSpring) { selection = .approvals }
            case .chat, .ask: withAnimation(.atlasSpring) { selection = .chat }
            case .automations: withAnimation(.atlasSpring) { selection = .automations }
            case .settings: withAnimation(.atlasSpring) { selection = .settings }
            }
            deepLink.pending = nil
        }
    }

    private var deepLink: AtlasDeepLink { .shared }
}

/// Floating glass tab bar with a spring-driven selection indicator.
private struct FloatingTabBar: View {
    @Binding var selection: MainTabView.Tab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTabView.Tab.allCases) { tab in
                Button {
                    Haptics.selection()
                    withAnimation(.atlasSpring) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolVariant(selection == tab ? .fill : .none)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? Color.atlasAccent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.atlasAccent.opacity(0.14))
                                .matchedGeometryEffect(id: "indicator", in: indicator)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .atlasGlass(Capsule(), interactive: true)
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }
}
