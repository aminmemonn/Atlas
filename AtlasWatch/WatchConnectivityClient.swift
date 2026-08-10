import Foundation
import WatchConnectivity

/// Watch-side connectivity: receives snapshots/approvals from the phone and
/// sends back approval decisions and quick voice commands.
@MainActor
@Observable
final class WatchConnectivityClient: NSObject {
    private(set) var snapshot: AtlasSnapshot = .placeholder
    private(set) var approvals: [WatchApproval] = []
    private(set) var reachable = false

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func resolve(_ approval: WatchApproval, approved: Bool) {
        send(type: WatchMessage.resolveApproval,
             payload: ["id": approval.id.uuidString, "approved": approved])
        approvals.removeAll { $0.id == approval.id }
    }

    func startVoice() {
        send(type: WatchMessage.quickVoice, payload: [:])
    }

    private func send(type: String, payload: [String: Any]) {
        guard let session, session.isReachable else { return }
        session.sendMessage([WatchMessage.typeKey: type, WatchMessage.payloadKey: payload],
                            replyHandler: nil)
    }

    private func apply(snapshotData: Data?, approvalsData: Data?) {
        if let snapshotData,
           let decoded = try? JSONDecoder().decode(AtlasSnapshot.self, from: snapshotData) {
            snapshot = decoded
        }
        if let approvalsData,
           let decoded = try? JSONDecoder().decode([WatchApproval].self, from: approvalsData) {
            approvals = decoded
        }
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.reachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Extract Sendable Data in the nonisolated context before hopping.
        let snapshotData = applicationContext["snapshotData"] as? Data
        let approvalsData = applicationContext["approvalsData"] as? Data
        Task { @MainActor in self.apply(snapshotData: snapshotData, approvalsData: approvalsData) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.reachable = session.isReachable }
    }
}
