import SwiftUI
import SwiftData

/// Lists scheduled/recurring agent tasks and lets the user create new ones via
/// natural language.
struct AutomationsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Query(sort: \Automation.createdAt, order: .reverse) private var automations: [Automation]
    @State private var viewModel: AutomationsViewModel?
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Tasks", subtitle: subtitle) {
                Button {
                    Haptics.impact(.light)
                    showCreate = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.atlasAccent)
                }
                .accessibilityLabel("New automation")
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    if automations.isEmpty { emptyState }
                    ForEach(automations) { automation in
                        AutomationCard(
                            automation: automation,
                            onToggle: { viewModel?.setEnabled(automation, $0) },
                            onDelete: { viewModel?.delete(automation) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
                .animation(.atlasSpring, value: automations.count)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = AutomationsViewModel(environment: environment, context: context)
            }
        }
        .sheet(isPresented: $showCreate) {
            if let viewModel {
                CreateAutomationSheet(viewModel: viewModel)
                    .presentationDetents([.height(280)])
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private var subtitle: String {
        let running = automations.filter { $0.status == .running }.count
        if running > 0 { return "\(running) running now" }
        return automations.isEmpty ? "No tasks yet" : "\(automations.count) scheduled"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.badge.clock")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.atlasAccent)
            Text("No automations")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("Describe a recurring task in plain language and Atlas will schedule it.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct AutomationCard: View {
    let automation: Automation
    var onToggle: (Bool) -> Void
    var onDelete: () -> Void

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(automation.title).font(.headline)
                        Label(automation.scheduleDescription, systemImage: "calendar")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusChip(status: automation.status)
                }
                Divider().opacity(0.3)
                HStack {
                    Toggle("Enabled", isOn: Binding(
                        get: { automation.isEnabled },
                        set: { onToggle($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(.atlasAccent)
                    .labelsHidden()
                    Text(automation.isEnabled ? "Active" : "Paused")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.subheadline)
                    }
                    .accessibilityLabel("Delete automation")
                }
            }
        }
    }
}

private struct StatusChip: View {
    let status: Automation.Status

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.symbolName)
                .symbolEffect(.rotate, isActive: status == .running)
                .font(.caption2.weight(.bold))
            Text(status.label).font(.caption.weight(.semibold))
        }
        .foregroundStyle(status.tint.color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(status.tint.color.opacity(0.15), in: Capsule())
    }
}

private struct CreateAutomationSheet: View {
    @Bindable var viewModel: AutomationsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Describe what Atlas should do, and when.")
                .font(.subheadline).foregroundStyle(.secondary)

            TextField("e.g. Every weekday at 8am, summarize my unread email",
                      text: $viewModel.newPrompt, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .atlasGlass(cornerRadius: 16)

            GlassButton("Create Task") {
                viewModel.create()
                dismiss()
            }
            .disabled(!viewModel.canCreate)
            .opacity(viewModel.canCreate ? 1 : 0.5)
        }
        .padding(24)
    }
}
