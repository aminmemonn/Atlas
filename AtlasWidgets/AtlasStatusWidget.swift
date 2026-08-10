import SwiftUI
import WidgetKit
import AppIntents

/// Home Screen widget showing agent status, pending approvals, and quick actions.
struct AtlasStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AtlasStatusWidget", provider: SnapshotProvider()) { entry in
            AtlasStatusWidgetView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Atlas")
        .description("Agent status and quick actions.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: AtlasSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: AtlasSharedStore.shared.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: AtlasSharedStore.shared.read())
        // Refresh roughly every 10 minutes; the app also reloads timelines on change.
        let next = Calendar.current.date(byAdding: .minute, value: 10, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct AtlasStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: AtlasSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.tint)
                Text("Atlas").font(.headline)
                Spacer()
                Circle().fill(statusColor).frame(width: 8, height: 8)
            }

            Text(snapshot.statusLabel)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Metric(symbol: "checkmark.shield", value: snapshot.pendingApprovalCount, label: "Approvals")
                if family != .systemSmall {
                    Metric(symbol: "bolt.badge.clock", value: snapshot.activeAutomationCount, label: "Running")
                }
            }

            if family != .systemSmall {
                HStack(spacing: 8) {
                    Link(destination: URL(string: "atlas://talk")!) {
                        Label("Talk", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.tint.opacity(0.18), in: Capsule())
                    }
                    Link(destination: URL(string: "atlas://approvals")!) {
                        Label("Review", systemImage: "checkmark.shield")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(.tint.opacity(0.18), in: Capsule())
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch snapshot.agentStatus.lowercased() {
        case let s where s.contains("offline"): .red
        case let s where s.contains("approval"): .orange
        case let s where s.contains("working"), let s where s.contains("think"): .yellow
        default: .green
        }
    }
}

private struct Metric: View {
    let symbol: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2)
            Text("\(value)").font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
