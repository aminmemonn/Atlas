import Foundation
import ActivityKit

/// Starts, updates, and ends Live Activities for ongoing agent tasks, and keeps
/// the shared App Group snapshot in sync for widgets, intents, and the Watch app.
///
/// Only the activity's `id` is retained on the main actor; the non-`Sendable`
/// `Activity` handle is re-resolved from `Activity.activities` inside each async
/// task so it never crosses an isolation boundary (Swift 6 region isolation).
@MainActor
final class LiveActivityService {
    private var activityID: String?
    private let store = AtlasSharedStore.shared

    /// Begins (or updates) the Live Activity for a running task.
    func startOrUpdate(taskTitle: String, activityText: String, progress: Double?, pendingApprovals: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = AgentActivityAttributes.ContentState(
            activity: activityText,
            progress: progress,
            pendingApprovals: pendingApprovals
        )
        let content = ActivityContent(state: state, staleDate: nil)

        if let id = activityID {
            // Detached so the lookup and update happen in a nonisolated region —
            // the Activity handle is never sent across an isolation boundary.
            Task.detached {
                if let activity = Activity<AgentActivityAttributes>.activities.first(where: { $0.id == id }) {
                    await activity.update(content)
                }
            }
        } else {
            let attributes = AgentActivityAttributes(taskTitle: taskTitle)
            activityID = (try? Activity.request(attributes: attributes, content: content))?.id
        }
    }

    func end() {
        guard let id = activityID else { return }
        activityID = nil
        Task.detached {
            if let activity = Activity<AgentActivityAttributes>.activities.first(where: { $0.id == id }) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Pushes a fresh glanceable snapshot to the shared store.
    func sync(_ snapshot: AtlasSnapshot) {
        store.write(snapshot)
    }
}
