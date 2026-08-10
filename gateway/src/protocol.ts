// Wire protocol shared with the Atlas iOS app. Every frame is a JSON object
// `{ type, payload }`. This mirrors the Swift `GatewayCoder` on the client.

import type { RawData } from "ws";

// ── Outbound: frames the gateway sends to the app ──────────────────────────

export type ModelProvider = "claude" | "gpt" | "gemini" | "local";

export interface ApprovalRequestPayload {
  id: string;
  title: string;
  description: string;
  domain: string;
  parameters: Record<string, string>;
  riskHint?: string;
}

export interface AutomationUpdatePayload {
  id: string;
  title: string;
  scheduleDescription: string;
  status: string; // idle | running | completed | failed
  nextRunAt?: string | null; // ISO 8601
}

export type AgentStatus =
  | "idle"
  | "thinking"
  | "working"
  | "awaitingApproval"
  | "offline";

interface Envelope {
  type: string;
  payload?: unknown;
}

function frame(type: string, payload?: unknown): string {
  const env: Envelope = payload === undefined ? { type } : { type, payload };
  return JSON.stringify(env);
}

export const Frames = {
  ready: (model: ModelProvider) => frame("ready", { model }),
  messageDelta: (id: string, text: string) =>
    frame("message_delta", { id, text }),
  messageCompleted: (id: string) => frame("message_completed", { id }),
  toolStarted: (messageID: string, name: string, detail = "") =>
    frame("tool_started", { messageID, name, detail }),
  toolFinished: (messageID: string, name: string, success: boolean) =>
    frame("tool_finished", { messageID, name, success }),
  approvalRequested: (p: ApprovalRequestPayload) =>
    frame("approval_requested", p),
  automationUpdated: (p: AutomationUpdatePayload) =>
    frame("automation_updated", p),
  agentStatus: (status: AgentStatus, activity?: string) =>
    frame("agent_status", { status, activity: activity ?? null }),
  heartbeat: () => frame("heartbeat"),
  error: (message: string) => frame("error", { message }),
};

// ── Inbound: commands the app sends to the gateway ─────────────────────────

export type Command =
  | { type: "send_message"; id: string; text: string; model: ModelProvider }
  | { type: "resolve_approval"; id: string; approved: boolean }
  | { type: "create_automation"; prompt: string }
  | { type: "set_capability"; capability: string; enabled: boolean }
  | { type: "cancel_message"; id: string };

/** Parses an inbound message. Returns null for anything unrecognized. */
export function decodeCommand(raw: RawData): Command | null {
  let env: Envelope;
  try {
    env = JSON.parse(raw.toString());
  } catch {
    return null;
  }
  const p = (env.payload ?? {}) as Record<string, unknown>;
  switch (env.type) {
    case "send_message":
      if (typeof p.id === "string" && typeof p.text === "string") {
        return {
          type: "send_message",
          id: p.id,
          text: p.text,
          model: normalizeModel(p.model),
        };
      }
      return null;
    case "resolve_approval":
      if (typeof p.id === "string" && typeof p.approved === "boolean") {
        return { type: "resolve_approval", id: p.id, approved: p.approved };
      }
      return null;
    case "create_automation":
      if (typeof p.prompt === "string") {
        return { type: "create_automation", prompt: p.prompt };
      }
      return null;
    case "set_capability":
      if (typeof p.capability === "string" && typeof p.enabled === "boolean") {
        return {
          type: "set_capability",
          capability: p.capability,
          enabled: p.enabled,
        };
      }
      return null;
    case "cancel_message":
      if (typeof p.id === "string") {
        return { type: "cancel_message", id: p.id };
      }
      return null;
    default:
      return null;
  }
}

function normalizeModel(value: unknown): ModelProvider {
  switch (value) {
    case "gpt":
    case "gemini":
    case "local":
      return value;
    default:
      return "claude";
  }
}
