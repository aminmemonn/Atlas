import Foundation
import SwiftData

/// Backs the Settings screen: managing gateway profiles, switching the active
/// model/provider, and disconnecting/re-pairing.
@MainActor
@Observable
final class SettingsViewModel {
    private let environment: AppEnvironment
    private let context: ModelContext

    init(environment: AppEnvironment, context: ModelContext) {
        self.environment = environment
        self.context = context
    }

    var connectionState: ConnectionState { environment.connectionState }
    var activeModel: ModelProvider { environment.agentState.activeModel }

    func selectModel(_ model: ModelProvider) {
        environment.agentState.activeModel = model
        environment.activeGateway?.preferredModel = model
        try? context.save()
        Haptics.selection()
    }

    func activate(_ gateway: Gateway) {
        // Deactivate others, then connect to the chosen profile.
        let all = (try? context.fetch(FetchDescriptor<Gateway>())) ?? []
        for g in all { g.isActive = (g.id == gateway.id) }
        try? context.save()
        environment.connect(to: gateway)
        Haptics.impact(.medium)
    }

    func disconnect() {
        environment.disconnect()
        Haptics.impact(.rigid)
    }

    /// Removes a gateway profile and purges its token from the Keychain.
    func remove(_ gateway: Gateway) {
        try? environment.keychain.deleteToken(for: gateway.id)
        if environment.activeGateway?.id == gateway.id {
            environment.disconnect()
            environment.activeGateway = nil
        }
        context.delete(gateway)
        try? context.save()
        Haptics.notify(.warning)
    }

    /// Clears all locally stored conversation history (privacy control).
    func purgeLocalData() {
        try? context.delete(model: Message.self)
        try? context.delete(model: Approval.self)
        try? context.save()
        Haptics.notify(.warning)
    }
}
