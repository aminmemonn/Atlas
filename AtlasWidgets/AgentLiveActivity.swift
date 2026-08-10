import SwiftUI
import WidgetKit
import ActivityKit

/// Renders the ongoing-task Live Activity in the Dynamic Island and on the Lock
/// Screen, driven by ``AgentActivityAttributes`` updates from the app.
struct AgentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AgentActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.4))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(.tint)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.pendingApprovals > 0 {
                        Label("\(context.state.pendingApprovals)", systemImage: "checkmark.shield")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.activity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let progress = context.state.progress {
                            ProgressView(value: progress).tint(.white)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.tint)
            } compactTrailing: {
                if context.state.pendingApprovals > 0 {
                    Text("\(context.state.pendingApprovals)").font(.caption2.weight(.bold))
                } else {
                    Image(systemName: "ellipsis").symbolEffect(.variableColor)
                }
            } minimal: {
                Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.tint)
            }
            .widgetURL(URL(string: "atlas://chat"))
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<AgentActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.taskTitle).font(.headline)
                Text(context.state.activity).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                if let progress = context.state.progress {
                    ProgressView(value: progress).tint(.white)
                }
            }
            Spacer()
            if context.state.pendingApprovals > 0 {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.shield").foregroundStyle(.orange)
                    Text("\(context.state.pendingApprovals)").font(.caption2.weight(.bold))
                }
            }
        }
    }
}
