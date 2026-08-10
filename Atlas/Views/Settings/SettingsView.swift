import SwiftUI
import SwiftData
import AVFoundation

/// Settings: gateway management, model/provider selection, capabilities,
/// privacy controls, and about.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Query(sort: \Gateway.createdAt) private var gateways: [Gateway]
    @State private var viewModel: SettingsViewModel?
    @State private var showPurgeConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    connectionSection
                    modelSection
                    capabilitiesSection
                    privacySection
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(AtlasBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(environment: environment, context: context)
            }
        }
    }

    // MARK: Connection

    private var connectionSection: some View {
        SettingsSection(title: "Gateway", systemImage: "antenna.radiowaves.left.and.right") {
            VStack(spacing: 12) {
                HStack {
                    ConnectionBadge(state: environment.connectionState, agent: environment.agentState)
                    Spacer()
                    if environment.connectionState.isConnected {
                        Button("Disconnect") { viewModel?.disconnect() }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }

                ForEach(gateways) { gateway in
                    GatewayRow(
                        gateway: gateway,
                        isActive: environment.activeGateway?.id == gateway.id,
                        onActivate: { viewModel?.activate(gateway) },
                        onRemove: { viewModel?.remove(gateway) }
                    )
                }

                NavigationLink {
                    AddGatewayView()
                } label: {
                    Label("Pair another gateway", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .atlasGlass(cornerRadius: 14)
                }
            }
        }
    }

    // MARK: Model

    private var modelSection: some View {
        SettingsSection(title: "Model", systemImage: "cpu") {
            VStack(spacing: 10) {
                ForEach(ModelProvider.allCases) { provider in
                    Button {
                        viewModel?.selectModel(provider)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: provider.symbolName)
                                .font(.title3).foregroundStyle(.atlasAccent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(provider.displayName).font(.subheadline.weight(.semibold))
                                Text(provider.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if environment.agentState.activeModel == provider {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.atlasAccent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Capabilities

    private var capabilitiesSection: some View {
        SettingsSection(title: "Device Access", systemImage: "hand.raised") {
            NavigationLink {
                CapabilitiesView()
            } label: {
                HStack {
                    Text("Capabilities").font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        SettingsSection(title: "Privacy", systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: 12) {
                Label("No analytics, no trackers, no third-party SDKs.", systemImage: "checkmark.seal")
                    .font(.caption).foregroundStyle(.secondary)
                Label("Keys are stored only in the iOS Keychain.", systemImage: "key")
                    .font(.caption).foregroundStyle(.secondary)
                Button(role: .destructive) {
                    showPurgeConfirm = true
                } label: {
                    Label("Clear local history", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                }
                .confirmationDialog("Clear all locally stored messages and approvals?",
                                    isPresented: $showPurgeConfirm, titleVisibility: .visible) {
                    Button("Clear", role: .destructive) { viewModel?.purgeLocalData() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        SettingsSection(title: "About", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Version", value: Bundle.main.shortVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
                Text("Atlas — your self-hosted personal AI agent.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }
}

// MARK: - Rows & sections

private struct GatewayRow: View {
    let gateway: Gateway
    let isActive: Bool
    var onActivate: () -> Void
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? .atlasAccent : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(gateway.name).font(.subheadline.weight(.semibold))
                Text(gateway.endpoint.host() ?? gateway.endpoint.absoluteString)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if !isActive {
                Button("Use", action: onActivate).font(.caption.weight(.semibold)).buttonStyle(.bordered)
            }
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash").font(.caption)
            }
        }
        .padding(12)
        .atlasGlass(cornerRadius: 14)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            GlassCard { content() }
        }
    }
}

/// A minimal pairing entry point reachable from Settings (re-pair / multi-profile).
struct AddGatewayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel?
    @State private var cameraAuthorized = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Scan the gateway QR code")
                .font(.headline)
            ZStack {
                if cameraAuthorized {
                    QRScannerView { code in
                        viewModel?.pair(with: code)
                        if viewModel?.errorMessage == nil { dismiss() }
                    }
                } else {
                    GlassButton("Enable Camera", prominence: .secondary) {
                        Task { cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video) }
                    }
                }
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            if let error = viewModel?.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(20)
        .background(AtlasBackground())
        .navigationTitle("Add Gateway")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                viewModel = OnboardingViewModel(environment: environment, context: context)
            }
            cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    var buildNumber: String { infoDictionary?["CFBundleVersion"] as? String ?? "1" }
}
