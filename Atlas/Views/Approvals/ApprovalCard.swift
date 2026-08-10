import SwiftUI

/// A pending approval rendered as a glass card with a risk badge, expandable
/// parameters, and Approve/Deny actions.
struct ApprovalCard: View {
    let approval: Approval
    var onResolve: (Bool) -> Void

    @State private var expanded = false

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                header
                Text(approval.actionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !approval.parameters.isEmpty {
                    disclosure
                }

                if approval.status == .pending {
                    actions
                } else {
                    resolvedLabel
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(approval.title)
                    .font(.headline)
                Label(approval.domain, systemImage: "puzzlepiece.extension")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            RiskBadge(level: approval.risk)
        }
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.atlasSnappy) { expanded.toggle() }
                Haptics.selection()
            } label: {
                Label(expanded ? "Hide details" : "View details",
                      systemImage: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.atlasAccent)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(approval.parameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.caption.weight(.semibold).monospaced())
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            GlassButton("Deny", prominence: .destructive) { onResolve(false) }
            GlassButton("Approve", prominence: .primary) { onResolve(true) }
        }
    }

    private var resolvedLabel: some View {
        Label(
            approval.status == .approved ? "Approved" : approval.status == .denied ? "Denied" : "Expired",
            systemImage: approval.status == .approved ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(approval.status == .approved ? .green : .secondary)
    }
}

/// Compact pill conveying the per-action risk level.
struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: level.symbolName)
                .font(.caption2.weight(.bold))
            Text(level.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(level.tint.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(level.tint.opacity(0.4), lineWidth: 0.5))
        .accessibilityLabel("\(level.label) risk")
    }
}
