import SwiftUI
import SwiftData
import AVFoundation

/// Multi-step pairing and permissions flow shown until the user pairs a gateway.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = OnboardingViewModel(environment: environment, context: context)
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: OnboardingViewModel) -> some View {
        VStack {
            switch vm.step {
            case .welcome: WelcomeStep(viewModel: vm)
            case .pairing: PairingStep(viewModel: vm)
            case .permissions: PermissionsStep(viewModel: vm)
            case .done: ReadyStep(viewModel: vm)
            }
        }
        .padding(24)
        .animation(.atlasSpring, value: vm.step)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.atlasAccent)
                .symbolEffect(.breathe)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Atlas")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Your personal AI agent — paired to a gateway you run yourself. Private by design, voice-ready, and always under your control.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Spacer()
            FeatureRow(symbol: "lock.shield", title: "Self-hosted & private", subtitle: "Keys stay in your Keychain. No trackers.")
            FeatureRow(symbol: "waveform", title: "Talk naturally", subtitle: "Full-duplex voice conversations.")
            FeatureRow(symbol: "checkmark.shield", title: "You approve every action", subtitle: "Risk-scored, one tap to allow or deny.")
            Spacer()

            GlassButton("Get Started") { viewModel.advance() }
        }
    }
}

private struct FeatureRow: View {
    var symbol: String
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.atlasAccent)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pairing

private struct PairingStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showManualEntry = false
    @State private var cameraAuthorized = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair your gateway")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Scan the QR code shown by the Atlas gateway running on your Mac or PC.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            ZStack {
                if cameraAuthorized {
                    QRScannerView { code in viewModel.pair(with: code) }
                } else {
                    GlassCard {
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder").font(.system(size: 48))
                            Text("Camera access is needed to scan the pairing code.")
                                .font(.subheadline).multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            GlassButton("Enable Camera", prominence: .secondary) {
                                Task { cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video) }
                            }
                        }
                    }
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.2)))

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }

            Button("Enter setup code manually") { showManualEntry = true }
                .font(.subheadline.weight(.medium))
        }
        .task { cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized }
        .sheet(isPresented: $showManualEntry) {
            ManualEntrySheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
    }
}

private struct ManualEntrySheet: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Setup Code").font(.headline)
            Text("Paste the JSON setup code from your gateway dashboard.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            TextEditor(text: $viewModel.manualCode)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .padding(8)
                .atlasGlass(cornerRadius: 16)
            GlassButton("Pair") {
                viewModel.pairWithManualCode()
                if viewModel.errorMessage == nil { dismiss() }
            }
        }
        .padding(24)
    }
}

// MARK: - Permissions (requested one at a time)

private struct PermissionsStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("A few permissions")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Grant only what you want. Each is opt-in and revocable anytime in Settings.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PermissionRow(capability: .microphone)
                PermissionRow(capability: .camera)
                NotificationPermissionRow()
            }
            Spacer()
            GlassButton("Continue") { viewModel.advance() }
            Button("Skip for now") { viewModel.advance() }
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct PermissionRow: View {
    var capability: DeviceCapability
    @Environment(AppEnvironment.self) private var environment
    @State private var granted = false

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: capability.symbolName).font(.title2).foregroundStyle(.atlasAccent).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(capability.title).font(.subheadline.weight(.semibold))
                    Text(capability.explanation).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                Button(granted ? "Granted" : "Allow") {
                    Task { granted = await environment.capabilities.request(capability).isGranted }
                }
                .buttonStyle(.borderedProminent)
                .tint(.atlasAccent)
                .disabled(granted)
            }
        }
    }
}

private struct NotificationPermissionRow: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var granted = false

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "bell.badge").font(.title2).foregroundStyle(.atlasAccent).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications").font(.subheadline.weight(.semibold))
                    Text("Get alerted when the agent needs your approval.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(granted ? "Granted" : "Allow") {
                    Task { await environment.notifications.requestAuthorization(); granted = environment.notifications.authorized }
                }
                .buttonStyle(.borderedProminent).tint(.atlasAccent).disabled(granted)
            }
        }
    }
}

// MARK: - Ready

private struct ReadyStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80)).foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("You're all set")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Atlas is paired and ready. Say hello in chat or start a voice conversation.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            GlassButton("Enter Atlas") { viewModel.finish() }
        }
    }
}
