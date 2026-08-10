import Foundation
import UserNotifications

/// Schedules and routes local/push notifications for new approval requests.
///
/// Approval notifications carry interactive actions so the user can approve or
/// deny directly from the notification without opening the app.
@MainActor
@Observable
final class NotificationService: NSObject {
    static let approvalCategory = "ATLAS_APPROVAL"
    static let approveAction = "ATLAS_APPROVE"
    static let denyAction = "ATLAS_DENY"

    private(set) var authorized = false

    /// Called when the user resolves an approval from a notification action.
    var onApprovalAction: (@MainActor (UUID, Bool) -> Void)?

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let approve = UNNotificationAction(
            identifier: Self.approveAction,
            title: "Approve",
            options: [.authenticationRequired]
        )
        let deny = UNNotificationAction(
            identifier: Self.denyAction,
            title: "Deny",
            options: [.destructive, .authenticationRequired]
        )
        let category = UNNotificationCategory(
            identifier: Self.approvalCategory,
            actions: [approve, deny],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async {
        do {
            authorized = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
        }
    }

    func notifyApprovalRequest(_ approval: Approval) async {
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Approval needed"
        content.subtitle = "\(approval.risk.label) risk · \(approval.domain)"
        content.body = approval.title
        content.categoryIdentifier = Self.approvalCategory
        content.userInfo = ["approvalID": approval.id.uuidString]
        content.sound = .default
        content.interruptionLevel = approval.risk == .high ? .timeSensitive : .active

        let request = UNNotificationRequest(
            identifier: approval.id.uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["approvalID"] as? String,
              let id = UUID(uuidString: idString) else { return }

        let approved: Bool?
        switch response.actionIdentifier {
        case Self.approveAction: approved = true
        case Self.denyAction: approved = false
        default: approved = nil
        }
        if let approved {
            await MainActor.run { self.onApprovalAction?(id, approved) }
        }
    }
}
