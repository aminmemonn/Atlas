import SwiftUI
import SwiftData

@main
struct AtlasApp: App {
    @State private var environment = AppEnvironment()

    /// Shared SwiftData container backing local memory and conversation history.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Message.self,
            ToolEvent.self,
            Approval.self,
            Automation.self,
            Gateway.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(.atlasAccent)
                .task {
                    environment.bootstrap(context: modelContainer.mainContext)
                }
                .onOpenURL { url in
                    AtlasDeepLink.shared.handle(url: url)
                }
        }
        .modelContainer(modelContainer)
    }
}
