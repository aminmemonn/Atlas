import SwiftUI
import SwiftData

/// Lists pending approvals (sorted by risk, most severe first) and a history log.
struct ApprovalsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query private var allApprovals: [Approval]
    @State private var showHistory = false

    private var pending: [Approval] {
        allApprovals
            .filter { $0.status == .pending }
            .sorted { lhs, rhs in
                if lhs.risk != rhs.risk { return lhs.risk > rhs.risk }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private var resolved: [Approval] {
        allApprovals
            .filter { $0.status != .pending }
            .sorted { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Approvals", subtitle: pendingSubtitle) {
                Button {
                    Haptics.selection()
                    showHistory.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.atlasAccent)
                }
                .accessibilityLabel("Approval history")
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    if pending.isEmpty {
                        emptyState
                    }
                    ForEach(pending) { approval in
                        ApprovalCard(approval: approval) { approved in
                            environment.resolveApproval(id: approval.id, approved: approved)
                            Haptics.notify(approved ? .success : .warning)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
                .animation(.atlasSpring, value: pending.count)
            }
        }
        .sheet(isPresented: $showHistory) {
            ApprovalHistoryView(approvals: resolved)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var pendingSubtitle: String {
        pending.isEmpty ? "Nothing waiting" : "\(pending.count) awaiting your decision"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.green)
            Text("All clear")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("The agent has no actions waiting for approval.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

/// History log of resolved approvals.
struct ApprovalHistoryView: View {
    let approvals: [Approval]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(approvals) { approval in
                        ApprovalCard(approval: approval) { _ in }
                    }
                    if approvals.isEmpty {
                        Text("No history yet")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(AtlasBackground())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Shared screen header used by the non-chat tabs.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.title2, design: .rounded, weight: .bold))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}
