#if os(iOS)
import Foundation
import ActivityKit

/// Live Activity describing an ongoing agent task, shown in the Dynamic Island
/// and on the Lock Screen via ActivityKit.
struct AgentActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Human-readable description of the current step ("Searching the web…").
        var activity: String
        /// Progress 0…1 when determinate; `nil` for indeterminate work.
        var progress: Double?
        /// Pending approvals that may be blocking the task.
        var pendingApprovals: Int
    }

    /// The task's title, fixed for the activity's lifetime.
    var taskTitle: String
}
#endif
