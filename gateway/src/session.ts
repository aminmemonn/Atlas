import { randomUUID } from "node:crypto";
import { streamText, type CoreMessage } from "ai";
import cron, { type ScheduledTask } from "node-cron";
import { config } from "./config.js";
import { Frames, type Command, type ModelProvider } from "./protocol.js";
import { ProviderError, resolveModel, availableProviders } from "./providers.js";
import { scoreRisk } from "./riskScoring.js";
import { createTools } from "./tools.js";
import { store, type StoredAutomation } from "./store.js";
import { parseSchedule } from "./schedule.js";

type Send = (data: string) => void;

interface PendingApproval {
  resolve: (approved: boolean) => void;
  timer: NodeJS.Timeout;
}

/**
 * Owns everything for a single connected app: conversation history, in-flight
 * streaming, the approval broker, and scheduled automations.
 */
export class Session {
  private history: CoreMessage[] = [];
  private pendingApprovals = new Map<string, PendingApproval>();
  private activeStreams = new Map<string, AbortController>();
  private cronTasks = new Map<string, ScheduledTask>();
  private heartbeat: NodeJS.Timeout;

  constructor(private send: Send) {
    this.send(Frames.ready(defaultProvider()));
    this.heartbeat = setInterval(() => this.send(Frames.heartbeat()), 20_000);
    this.restoreAutomations();
  }

  dispose(): void {
    clearInterval(this.heartbeat);
    for (const c of this.activeStreams.values()) c.abort();
    for (const t of this.cronTasks.values()) t.stop();
    for (const p of this.pendingApprovals.values()) {
      clearTimeout(p.timer);
      p.resolve(false);
    }
  }

  async handle(command: Command): Promise<void> {
    switch (command.type) {
      case "send_message":
        await this.onSendMessage(command.text, command.model);
        break;
      case "resolve_approval":
        this.onResolveApproval(command.id, command.approved);
        break;
      case "create_automation":
        this.onCreateAutomation(command.prompt);
        break;
      case "cancel_message":
        this.activeStreams.get(command.id)?.abort();
        break;
      case "set_capability":
        // Capabilities are enforced client-side; acknowledge silently.
        break;
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────

  private async onSendMessage(text: string, provider: ModelProvider): Promise<void> {
    const responseId = randomUUID();
    const controller = new AbortController();
    this.activeStreams.set(responseId, controller);

    let resolved;
    try {
      resolved = resolveModel(provider);
    } catch (err) {
      const message =
        err instanceof ProviderError
          ? err.message
          : `Could not initialize the model: ${(err as Error).message}`;
      this.send(Frames.error(message));
      this.send(Frames.agentStatus("idle"));
      this.activeStreams.delete(responseId);
      return;
    }

    this.history.push({ role: "user", content: text });
    this.send(Frames.agentStatus("thinking"));

    const tools = createTools({
      toolStarted: (name) => {
        this.send(Frames.toolStarted(responseId, name, describeTool(name)));
        this.send(Frames.agentStatus("working", describeTool(name)));
      },
      toolFinished: (name, success) => {
        this.send(Frames.toolFinished(responseId, name, success));
        this.send(Frames.agentStatus("thinking"));
      },
      requestApproval: (input) => this.requestApproval(input),
    });

    let full = "";
    try {
      const result = streamText({
        model: resolved.model,
        system: config.systemPrompt,
        messages: this.history,
        tools,
        maxSteps: 6,
        abortSignal: controller.signal,
      });

      for await (const part of result.fullStream) {
        switch (part.type) {
          case "text-delta": {
            const delta = (part as { textDelta?: string }).textDelta ?? "";
            if (delta) {
              full += delta;
              this.send(Frames.messageDelta(responseId, delta));
            }
            break;
          }
          case "error": {
            const e = (part as { error?: unknown }).error;
            this.send(Frames.error(readableError(e)));
            break;
          }
        }
      }
    } catch (err) {
      if (!controller.signal.aborted) {
        this.send(Frames.error(readableError(err)));
      }
    } finally {
      if (full.trim()) this.history.push({ role: "assistant", content: full });
      this.trimHistory();
      this.send(Frames.messageCompleted(responseId));
      this.send(Frames.agentStatus("idle"));
      this.activeStreams.delete(responseId);
    }
  }

  private trimHistory(): void {
    // Keep the last ~20 turns to bound token usage.
    const MAX = 40;
    if (this.history.length > MAX) {
      this.history = this.history.slice(this.history.length - MAX);
    }
  }

  // ── Approvals ──────────────────────────────────────────────────────────────

  private requestApproval(input: {
    title: string;
    description: string;
    domain: string;
    parameters: Record<string, string>;
  }): Promise<boolean> {
    const id = randomUUID();
    const risk = scoreRisk(input);
    this.send(
      Frames.approvalRequested({
        id,
        title: input.title,
        description: input.description,
        domain: input.domain,
        parameters: input.parameters,
        riskHint: risk,
      }),
    );
    this.send(Frames.agentStatus("awaitingApproval", input.title));

    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        this.pendingApprovals.delete(id);
        resolve(false); // auto-deny after timeout
      }, 5 * 60_000);
      this.pendingApprovals.set(id, { resolve, timer });
    });
  }

  private onResolveApproval(id: string, approved: boolean): void {
    const pending = this.pendingApprovals.get(id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pendingApprovals.delete(id);
    pending.resolve(approved);
  }

  // ── Automations ────────────────────────────────────────────────────────────

  private onCreateAutomation(prompt: string): void {
    const { cron: cronExpr, description } = parseSchedule(prompt);
    const automation: StoredAutomation = {
      id: randomUUID(),
      title: titleFromPrompt(prompt),
      prompt,
      scheduleDescription: description,
      cron: cronExpr,
      status: "idle",
      createdAt: new Date().toISOString(),
      lastRunAt: null,
      nextRunAt: null,
      enabled: true,
    };
    store.upsertAutomation(automation);
    this.scheduleAutomation(automation);
    this.emitAutomation(automation);
  }

  private restoreAutomations(): void {
    for (const a of store.listAutomations()) {
      if (a.enabled) this.scheduleAutomation(a);
      this.emitAutomation(a);
    }
  }

  private scheduleAutomation(a: StoredAutomation): void {
    this.cronTasks.get(a.id)?.stop();
    if (!a.cron || !cron.validate(a.cron)) return;
    const task = cron.schedule(a.cron, () => this.runAutomation(a.id));
    this.cronTasks.set(a.id, task);
  }

  private async runAutomation(id: string): Promise<void> {
    const running = store.updateAutomation(id, {
      status: "running",
      lastRunAt: new Date().toISOString(),
    });
    if (!running) return;
    this.emitAutomation(running);

    try {
      const provider = defaultProvider();
      const { model } = resolveModel(provider);
      const result = streamText({
        model,
        system: config.systemPrompt,
        messages: [{ role: "user", content: running.prompt }],
        maxSteps: 4,
      });
      // Drain the stream so the task completes.
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      for await (const _ of result.textStream) {
        /* consume */
      }
      const done = store.updateAutomation(id, { status: "completed" });
      if (done) this.emitAutomation(done);
    } catch {
      const failed = store.updateAutomation(id, { status: "failed" });
      if (failed) this.emitAutomation(failed);
    }
  }

  private emitAutomation(a: StoredAutomation): void {
    this.send(
      Frames.automationUpdated({
        id: a.id,
        title: a.title,
        scheduleDescription: a.scheduleDescription,
        status: a.status,
        nextRunAt: a.nextRunAt,
      }),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function defaultProvider(): ModelProvider {
  return availableProviders()[0] ?? "claude";
}

function describeTool(name: string): string {
  switch (name) {
    case "web_search":
      return "Searching the web";
    case "read_file":
      return "Reading a file";
    case "run_command":
      return "Running a command";
    case "get_current_time":
      return "Checking the time";
    default:
      return name.replace(/_/g, " ");
  }
}

function titleFromPrompt(prompt: string): string {
  const first = prompt.split(/[.!?\n]/)[0]?.trim() ?? prompt;
  return first.length > 48 ? first.slice(0, 45) + "…" : first;
}

function readableError(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === "string") return err;
  try {
    return JSON.stringify(err);
  } catch {
    return "An unknown error occurred.";
  }
}
