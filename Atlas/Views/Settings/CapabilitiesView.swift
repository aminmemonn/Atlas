import SwiftUI
import UIKit

/// Granular per-capability toggles. Each row explains what granting allows and
/// reflects the live system authorization status. Enabling triggers the native
/// permission prompt; disabling routes the user to Settings to revoke.
struct CapabilitiesView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Grant the agent access to device capabilities. Everything is opt-in and can be revoked here or in iOS Settings at any time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(DeviceCapability.allCases) { capability in
                    CapabilityRow(capability: capability)
                }
            }
            .padding(16)
        }
        .background(AtlasBackground())
        .navigationTitle("Capabilities")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { environment.capabilities.refreshAll() }
    }
}

private struct CapabilityRow: View {
    let capability: DeviceCapability
    @Environment(AppEnvironment.self) private var environment

    private var status: CapabilityAuthorization {
        environment.capabilities.authorizations[capability] ?? .notDetermined
    }

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: capability.symbolName)
                    .font(.title2)
                    .foregroundStyle(.atlasAccent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(capability.title).font(.subheadline.weight(.semibold))
                    Text(capability.explanation)
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                control
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        switch status {
        case .authorized:
            Label("On", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.green)
        case .denied, .restricted:
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        case .notDetermined:
            Button("Allow") {
                Task {
                    await environment.capabilities.request(capability)
                    Haptics.selection()
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.atlasAccent)
        }
    }
}
