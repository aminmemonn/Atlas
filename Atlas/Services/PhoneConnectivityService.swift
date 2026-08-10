import Foundation
import WatchConnectivity

/// Phone-side WatchConnectivity bridge. Pushes glanceable state to the Watch and
/// routes the Watch's approval decisions and quick-voice requests back into the
/// app. The phone remains the sole owner of the gateway connection.
@MainActor
final class PhoneConnectivityService: NSObject {
    var onResolveApproval: (@MainActor (UUID, Bool) -> Void)?
    var onQuickVoice: (@MainActor () -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Mirrors the current snapshot and pending approvals to the Watch.
    func push(snapshot: AtlasSnapshot, approvals: [WatchApproval]) {
        guard let session, session.activationState == .activated else { return }
        var context: [String: Any] = [:]
        if let snapshotData = try? JSONEncoder().encode(snapshot) {
            context["snapshotData"] = snapshotData
        }
        if let approvalsData = try? JSONEncoder().encode(approvals) {
            context["approvalsData"] = approvalsData
        }
        try? session.updateApplicationContext(context)
    }

}

extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    // Parse in the nonisolated delegate context and forward only Sendable
    // values (UUID, Bool) to the main actor — the raw `[String: Any]` message
    // is not Sendable and must not cross the isolation boundary.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message[WatchMessage.typeKey] as? String else { return }
        let payload = message[WatchMessage.payloadKey] as? [String: Any] ?? [:]
        switch type {
        case WatchMessage.resolveApproval:
            if let idString = payload["id"] as? String,
               let id = UUID(uuidString: idString),
               let approved = payload["approved"] as? Bool {
                Task { @MainActor in self.onResolveApproval?(id, approved) }
            }
        case WatchMessage.quickVoice:
            Task { @MainActor in self.onQuickVoice?() }
        default:
            break
        }
    }
}
