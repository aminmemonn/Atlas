import Foundation
import SwiftData
import SwiftUI

/// Composition root and dependency container.
///
/// Holds the long-lived services and app-wide live state, and fans inbound
/// gateway frames out to the SwiftData store. Injected into the SwiftUI
/// environment so view models can resolve their dependencies without singletons.
@MainActor
@Observable
final class AppEnvironment {
    // Services
    let keychain: KeychainService
    let gateway: GatewayService
    let voice: VoiceService
    let notifications: NotificationService
    let capabilities: CapabilityService
    let liveActivity = LiveActivityService()
    let watch = PhoneConnectivityService()

    // Live app state
    var connectionState: ConnectionState = .disconnected
    var agentState = AgentState()
    var activeGateway: Gateway?
    var hasCompletedOnboarding: Bool

    /// Set by the app on launch so frame handlers can persist into SwiftData.
    var modelContext: ModelContext?

    private var frameTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private let coder = GatewayCoder()

    init(
        keychain: KeychainService = KeychainService(),
        gateway: GatewayService = GatewayService(),
        voice: VoiceService = VoiceService(),
        notifications: NotificationService = NotificationService(),
        capabilities: CapabilityService = CapabilityService()
    ) {
        self.keychain = keychain
        self.gateway = gateway
        self.voice = voice
        self.notifications = notifications
        self.capabilities = capabilities
        let defaults = UserDefaults.standard
        var onboarded = defaults.bool(forKey: "atlas.onboarded")
        #if DEBUG
        // Any screenshot/UI-test launch arg implies onboarding is done.
        // Compiled out of release and TestFlight builds.
        let screenshotEntry = defaults.string(forKey: "atlas.initialTab") != nil
            || defaults.bool(forKey: "atlas.openTalk")
            || defaults.bool(forKey: "atlas.screenshotMode")
        onboarded = onboarded || screenshotEntry
        #endif
        self.hasCompletedOnboarding = onboarded
    }

    // MARK: - Bootstrap

    func bootstrap(context: ModelContext) {
        self.modelContext = context
        notifications.configure()
        notifications.onApprovalAction = { [weak self] id, approved in
            self?.resolveApproval(id: id, approved: approved)
        }
        capabilities.refreshAll()

        watch.onResolveApproval = { [weak self] id, approved in
            self?.resolveApproval(id: id, approved: approved)
        }
        watch.onQuickVoice = { AtlasDeepLink.shared.pending = .talk }
        watch.activate()

        observeGateway()
        syncSnapshot()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "atlas.onboarded")
    }

    // MARK: - Connection

    func connect(to gateway: Gateway) {
        activeGateway = gateway
        let info = GatewayConnectionInfo(gateway)
        Task { await self.gateway.connect(to: info) }
    }

    func disconnect() {
        Task { await gateway.disconnect() }
        agentState.status = .offline
    }

    private func observeGateway() {
        stateTask?.cancel()
        stateTask = Task { [weak self] in
            guard let self else { return }
            for await state in await self.gateway.connectionStates() {
                self.connectionState = state
                if case .connected = state { self.agentState.status = .idle }
                if case .failed = state { self.agentState.status = .offline }
            }
        }

        frameTask?.cancel()
        frameTask = Task { [weak self] in
            guard let self else { return }
            for await frame in await self.gateway.frames() {
                self.handle(frame)
            }
        }
    }

    // MARK: - Frame handling

    private func handle(_ frame: GatewayFrame) {
        guard let context = modelContext else { return }
        switch frame {
        case .ready(let model):
            agentState.activeModel = model
            agentState.status = .idle

        case let .messageDelta(id, text):
            upsertMessage(id: id, appending: text, in: context)

        case .messageCompleted(let id):
            if let message = fetchMessage(id: id, in: context) {
                message.isStreaming = false
            }
            agentState.status = .idle

        case let .toolStarted(messageID, name, detail):
            if let message = fetchMessage(id: messageID, in: context) {
                message.toolEvents.append(ToolEvent(name: name, detail: detail, status: .running))
            }
            agentState.status = .working
            agentState.currentActivity = name

        case let .toolFinished(messageID, name, success):
            if let message = fetchMessage(id: messageID, in: context),
               let event = message.toolEvents.last(where: { $0.name == name && $0.status == .running }) {
                event.status = success ? .completed : .failed
            }

        case .approvalRequested(let request):
            ingestApproval(request, in: context)

        case .automationUpdated(let update):
            ingestAutomation(update, in: context)

        case let .agentStatus(status, activity):
            agentState.status = status
            agentState.currentActivity = activity

        case .heartbeat:
            agentState.lastHeartbeat = .now

        case .error:
            agentState.status = .idle

        case .unknown:
            break
        }
        try? context.save()
        syncSnapshot()
    }

    /// Publishes a glanceable snapshot for widgets/intents/Watch and drives the
    /// Live Activity for in-progress work.
    private func syncSnapshot() {
        guard let context = modelContext else { return }
        let pending = (try? context.fetchCount(
            FetchDescriptor<Approval>(predicate: #Predicate { $0.statusRaw == "pending" })
        )) ?? 0
        let runningAutomations = (try? context.fetchCount(
            FetchDescriptor<Automation>(predicate: #Predicate { $0.statusRaw == "running" })
        )) ?? 0

        let snapshot = AtlasSnapshot(
            agentStatus: agentState.status.label,
            statusLabel: agentState.currentActivity ?? agentState.status.label,
            pendingApprovalCount: pending,
            activeAutomationCount: runningAutomations,
            connectionLabel: connectionState.label,
            updatedAt: .now
        )
        liveActivity.sync(snapshot)

        let watchApprovals = ((try? context.fetch(
            FetchDescriptor<Approval>(predicate: #Predicate { $0.statusRaw == "pending" })
        )) ?? []).map {
            WatchApproval(id: $0.id, title: $0.title, risk: $0.riskRaw, domain: $0.domain)
        }
        watch.push(snapshot: snapshot, approvals: watchApprovals)

        switch agentState.status {
        case .working, .thinking:
            liveActivity.startOrUpdate(
                taskTitle: "Atlas",
                activityText: agentState.currentActivity ?? agentState.status.label,
                progress: nil,
                pendingApprovals: pending
            )
        case .idle, .offline, .awaitingApproval:
            if pending == 0 { liveActivity.end() }
        }
    }

    private func upsertMessage(id: UUID, appending text: String, in context: ModelContext) {
        if let message = fetchMessage(id: id, in: context) {
            message.text += text
        } else {
            let message = Message(id: id, role: .agent, text: text, isStreaming: true)
            context.insert(message)
        }
        agentState.status = .thinking
    }

    private func ingestApproval(_ request: ApprovalRequest, in context: ModelContext) {
        let risk = RiskScoring.score(request)
        let approval = Approval(
            id: request.id,
            title: request.title,
            actionDescription: request.description,
            domain: request.domain,
            risk: risk,
            parameters: request.parameters
        )
        context.insert(approval)
        agentState.status = .awaitingApproval
        Task { await notifications.notifyApprovalRequest(approval) }
    }

    private func ingestAutomation(_ update: AutomationUpdate, in context: ModelContext) {
        let descriptor = FetchDescriptor<Automation>(predicate: #Predicate { $0.id == update.id })
        if let existing = try? context.fetch(descriptor).first {
            existing.statusRaw = update.status
            existing.scheduleDescription = update.scheduleDescription
            existing.nextRunAt = update.nextRunAt
        } else {
            let automation = Automation(
                id: update.id,
                title: update.title,
                prompt: "",
                scheduleDescription: update.scheduleDescription,
                status: Automation.Status(rawValue: update.status) ?? .idle,
                nextRunAt: update.nextRunAt
            )
            context.insert(automation)
        }
    }

    private func fetchMessage(id: UUID, in context: ModelContext) -> Message? {
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    // MARK: - Commands

    func resolveApproval(id: UUID, approved: Bool) {
        if let context = modelContext {
            let descriptor = FetchDescriptor<Approval>(predicate: #Predicate { $0.id == id })
            if let approval = try? context.fetch(descriptor).first {
                approval.status = approved ? .approved : .denied
                approval.resolvedAt = .now
                try? context.save()
            }
        }
        syncSnapshot()
        Task { try? await gateway.send(.resolveApproval(id: id, approved: approved)) }
    }
}
