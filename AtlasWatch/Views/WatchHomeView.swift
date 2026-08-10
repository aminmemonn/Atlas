import SwiftUI

/// Glanceable Watch view: agent status, pending approvals to resolve in a tap,
/// and a quick voice command button.
struct WatchHomeView: View {
    @Environment(WatchConnectivityClient.self) private var client

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text("Atlas").font(.headline)
                            Text(client.snapshot.statusLabel)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }

                Section {
                    Button {
                        client.startVoice()
                    } label: {
                        Label("Talk", systemImage: "waveform")
                    }
                    .tint(.indigo)
                }

                if client.approvals.isEmpty {
                    Section("Approvals") {
                        Label("All clear", systemImage: "checkmark.shield")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Pending Approvals") {
                        ForEach(client.approvals) { approval in
                            WatchApprovalRow(approval: approval)
                        }
                    }
                }
            }
            .navigationTitle("Atlas")
        }
    }
}

private struct WatchApprovalRow: View {
    @Environment(WatchConnectivityClient.self) private var client
    let approval: WatchApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(approval.title).font(.caption.weight(.semibold)).lineLimit(2)
            Text("\(approval.risk.capitalized) · \(approval.domain)")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Deny") { client.resolve(approval, approved: false) }
                    .tint(.red).controlSize(.mini)
                Button("Approve") { client.resolve(approval, approved: true) }
                    .tint(.green).controlSize(.mini)
            }
        }
        .padding(.vertical, 2)
    }
}
