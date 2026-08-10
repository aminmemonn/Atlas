import "dotenv/config";
import { randomBytes } from "node:crypto";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { hostname, networkInterfaces } from "node:os";
import { join } from "node:path";
import type { ModelProvider } from "./protocol.js";

const STATE_FILE = join(process.cwd(), ".atlas-gateway.json");

interface PersistedState {
  token: string;
  gatewayId: string;
}

/** Loads (or creates) the durable gateway identity + auth token. */
function loadState(): PersistedState {
  if (existsSync(STATE_FILE)) {
    try {
      return JSON.parse(readFileSync(STATE_FILE, "utf8")) as PersistedState;
    } catch {
      // fall through and regenerate
    }
  }
  const state: PersistedState = {
    token: randomBytes(32).toString("base64url"),
    gatewayId: randomUUID(),
  };
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), { mode: 0o600 });
  return state;
}

function randomUUID(): string {
  return crypto.randomUUID();
}

/** Best-effort primary LAN IPv4 address, for the QR fallback. */
function lanAddress(): string {
  const ifaces = networkInterfaces();
  for (const addrs of Object.values(ifaces)) {
    for (const addr of addrs ?? []) {
      if (addr.family === "IPv4" && !addr.internal) return addr.address;
    }
  }
  return "127.0.0.1";
}

export interface ProviderConfig {
  provider: ModelProvider;
  apiKey?: string;
  model: string;
  baseURL?: string;
}

function num(value: string | undefined, fallback: number): number {
  const n = value ? Number(value) : NaN;
  return Number.isFinite(n) ? n : fallback;
}

function bool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined) return fallback;
  return /^(1|true|yes|on)$/i.test(value.trim());
}

/** Picks the web-search provider: explicit override, else auto-detect by key. */
function resolveSearchProvider(): "tavily" | "brave" | "none" {
  const override = process.env.SEARCH_PROVIDER?.trim().toLowerCase();
  if (override === "tavily" || override === "brave" || override === "none") {
    return override;
  }
  if (process.env.TAVILY_API_KEY?.trim()) return "tavily";
  if (process.env.BRAVE_API_KEY?.trim()) return "brave";
  return "none";
}

const state = loadState();

export const config = {
  port: num(process.env.PORT, 8765),
  host: process.env.HOST || "0.0.0.0",
  publicURL: process.env.PUBLIC_URL?.trim() || "",
  tlsCert: process.env.TLS_CERT?.trim() || "",
  tlsKey: process.env.TLS_KEY?.trim() || "",
  gatewayName: process.env.GATEWAY_NAME?.trim() || `${hostname()} · Atlas`,
  tunnel: (process.env.TUNNEL?.trim().toLowerCase() === "off" ? "off" : "auto") as
    | "auto"
    | "off",
  systemPrompt:
    process.env.SYSTEM_PROMPT?.trim() ||
    "You are Atlas, a helpful, concise personal AI agent.",
  enableFileTool: bool(process.env.ENABLE_FILE_TOOL, true),
  enableShellTool: bool(process.env.ENABLE_SHELL_TOOL, false),

  search: {
    provider: resolveSearchProvider(),
    tavilyKey: process.env.TAVILY_API_KEY?.trim(),
    braveKey: process.env.BRAVE_API_KEY?.trim(),
    maxResults: num(process.env.SEARCH_MAX_RESULTS, 5),
  },

  token: state.token,
  gatewayId: state.gatewayId,
  lanAddress: lanAddress(),

  providers: {
    claude: {
      provider: "claude",
      apiKey: process.env.ANTHROPIC_API_KEY?.trim(),
      model: process.env.ANTHROPIC_MODEL?.trim() || "claude-3-5-sonnet-latest",
      baseURL: undefined as string | undefined,
    },
    gpt: {
      provider: "gpt",
      apiKey: process.env.OPENAI_API_KEY?.trim(),
      model: process.env.OPENAI_MODEL?.trim() || "gpt-4o",
      baseURL: undefined as string | undefined,
    },
    gemini: {
      provider: "gemini",
      apiKey: process.env.GOOGLE_GENERATIVE_AI_API_KEY?.trim(),
      model: process.env.GOOGLE_MODEL?.trim() || "gemini-1.5-pro",
      baseURL: undefined as string | undefined,
    },
    local: {
      provider: "local",
      apiKey: process.env.LOCAL_API_KEY?.trim() || "ollama",
      model: process.env.LOCAL_MODEL?.trim() || "llama3.1",
      baseURL: process.env.LOCAL_BASE_URL?.trim() || undefined,
    },
  } satisfies Record<ModelProvider, ProviderConfig>,
};

export type AppConfig = typeof config;

// Set at runtime once a bundled tunnel comes up.
let runtimePublicURL: string | null = null;
export function setRuntimePublicURL(url: string): void {
  runtimePublicURL = url;
}

/** Resolves the public endpoint the app pairs against. */
export function resolveEndpoint(): { url: string; secure: boolean; note?: string } {
  const publicURL = runtimePublicURL || config.publicURL;
  if (publicURL) {
    const secure = publicURL.startsWith("wss://");
    return {
      url: publicURL,
      secure,
      note: secure
        ? undefined
        : "PUBLIC_URL is not wss:// — the iOS app will reject it.",
    };
  }
  if (config.tlsCert && config.tlsKey) {
    return { url: `wss://${config.lanAddress}:${config.port}`, secure: true };
  }
  return {
    url: `ws://${config.lanAddress}:${config.port}`,
    secure: false,
    note:
      "No PUBLIC_URL or TLS configured. The iOS app requires wss:// — " +
      "run a tunnel (see README) and set PUBLIC_URL to its wss URL.",
  };
}
