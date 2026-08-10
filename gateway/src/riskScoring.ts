// Mirror of the app's RiskScoring so the gateway can attach a `riskHint` that
// agrees with what the client would compute. Low / Medium / High.

export type RiskLevel = "low" | "medium" | "high";

const HIGH_RISK_DOMAINS = new Set([
  "shell",
  "exec",
  "process",
  "payment",
  "purchase",
  "finance",
  "delete",
  "credentials",
  "keychain",
  "ssh",
]);

const MEDIUM_RISK_DOMAINS = new Set([
  "filesystem",
  "file",
  "network",
  "http",
  "email",
  "message",
  "calendar",
  "contacts",
  "automation",
  "screen",
]);

const ESCALATING_KEYWORDS = [
  "delete",
  "remove",
  "rm",
  "drop",
  "wipe",
  "format",
  "sudo",
  "password",
  "secret",
  "token",
  "transfer",
  "send",
  "publish",
  "overwrite",
  "force",
];

const SEVERITY: Record<RiskLevel, number> = { low: 0, medium: 1, high: 2 };

function baseLevel(domain: string): RiskLevel {
  const d = domain.toLowerCase();
  if (HIGH_RISK_DOMAINS.has(d)) return "high";
  if (MEDIUM_RISK_DOMAINS.has(d)) return "medium";
  return "low";
}

function escalate(level: RiskLevel): RiskLevel {
  return level === "low" ? "medium" : "high";
}

function containsEscalatingSignal(text: string): boolean {
  const haystack = text.toLowerCase();
  return ESCALATING_KEYWORDS.some((kw) =>
    new RegExp(`\\b${kw.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`).test(
      haystack,
    ),
  );
}

export function scoreRisk(input: {
  title: string;
  description: string;
  domain: string;
  parameters: Record<string, string>;
}): RiskLevel {
  let level = baseLevel(input.domain);
  const blob = [input.title, input.description, ...Object.values(input.parameters)].join(" ");
  if (containsEscalatingSignal(blob)) level = escalate(level);
  return level;
}

export function maxRisk(a: RiskLevel, b: RiskLevel): RiskLevel {
  return SEVERITY[a] >= SEVERITY[b] ? a : b;
}
