import { config } from "./config.js";

export interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

export interface SearchResponse {
  /** A synthesized answer, when the provider offers one (Tavily). */
  answer?: string;
  results: SearchResult[];
}

/** Whether a real web-search provider is configured. */
export function searchConfigured(): boolean {
  return config.search.provider !== "none";
}

/** Runs a web search via the configured provider. Throws on failure. */
export async function webSearch(query: string): Promise<SearchResponse> {
  switch (config.search.provider) {
    case "tavily":
      return tavilySearch(query);
    case "brave":
      return braveSearch(query);
    default:
      throw new Error(
        "Web search is not configured. Add TAVILY_API_KEY or BRAVE_API_KEY to .env.",
      );
  }
}

// ── Tavily (https://tavily.com) ────────────────────────────────────────────

async function tavilySearch(query: string): Promise<SearchResponse> {
  const res = await fetchJSON("https://api.tavily.com/search", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      api_key: config.search.tavilyKey,
      query,
      max_results: config.search.maxResults,
      include_answer: true,
      search_depth: "basic",
    }),
  });

  const results: SearchResult[] = (asArray(res.results)).map((r) => ({
    title: str(r.title),
    url: str(r.url),
    snippet: truncate(str(r.content), 500),
  }));
  const answer = typeof res.answer === "string" ? res.answer : undefined;
  return { answer, results };
}

// ── Brave Search (https://brave.com/search/api) ────────────────────────────

async function braveSearch(query: string): Promise<SearchResponse> {
  const url = new URL("https://api.search.brave.com/res/v1/web/search");
  url.searchParams.set("q", query);
  url.searchParams.set("count", String(config.search.maxResults));

  const res = await fetchJSON(url.toString(), {
    method: "GET",
    headers: {
      accept: "application/json",
      "x-subscription-token": config.search.braveKey ?? "",
    },
  });

  const web = (res.web ?? {}) as Record<string, unknown>;
  const results: SearchResult[] = asArray(web.results).map((r) => ({
    title: str(r.title),
    url: str(r.url),
    snippet: truncate(str(r.description), 500),
  }));
  return { results };
}

// ── Helpers ────────────────────────────────────────────────────────────────

async function fetchJSON(
  url: string,
  init: RequestInit,
): Promise<Record<string, unknown>> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  try {
    const res = await fetch(url, { ...init, signal: controller.signal });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`search provider returned ${res.status} ${text.slice(0, 200)}`);
    }
    return (await res.json()) as Record<string, unknown>;
  } finally {
    clearTimeout(timeout);
  }
}

function asArray(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value) ? (value as Record<string, unknown>[]) : [];
}

function str(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function truncate(s: string, n: number): string {
  return s.length > n ? s.slice(0, n) + "…" : s;
}
