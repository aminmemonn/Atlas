import { createAnthropic } from "@ai-sdk/anthropic";
import { createGoogleGenerativeAI } from "@ai-sdk/google";
import { createOpenAI } from "@ai-sdk/openai";
import type { LanguageModel } from "ai";
import { config } from "./config.js";
import type { ModelProvider } from "./protocol.js";

export class ProviderError extends Error {}

const DISPLAY: Record<ModelProvider, string> = {
  claude: "Claude (Anthropic)",
  gpt: "GPT (OpenAI)",
  gemini: "Gemini (Google)",
  local: "Local model",
};

/**
 * Resolves the app's selected model to a concrete AI SDK language model,
 * using whichever provider key the operator configured. Throws a friendly
 * ProviderError (surfaced to the app as an `error` frame) when a key is missing.
 */
export function resolveModel(provider: ModelProvider): {
  model: LanguageModel;
  label: string;
  modelId: string;
} {
  const cfg = config.providers[provider];

  switch (provider) {
    case "claude": {
      if (!cfg.apiKey) throw missingKey("ANTHROPIC_API_KEY", provider);
      const anthropic = createAnthropic({ apiKey: cfg.apiKey });
      return wrap(anthropic(cfg.model), provider, cfg.model);
    }
    case "gpt": {
      if (!cfg.apiKey) throw missingKey("OPENAI_API_KEY", provider);
      const openai = createOpenAI({ apiKey: cfg.apiKey });
      return wrap(openai(cfg.model), provider, cfg.model);
    }
    case "gemini": {
      if (!cfg.apiKey) throw missingKey("GOOGLE_GENERATIVE_AI_API_KEY", provider);
      const google = createGoogleGenerativeAI({ apiKey: cfg.apiKey });
      return wrap(google(cfg.model), provider, cfg.model);
    }
    case "local": {
      if (!cfg.baseURL) {
        throw new ProviderError(
          "No local model configured. Set LOCAL_BASE_URL (e.g. Ollama at " +
            "http://localhost:11434/v1) to use the Local Model option.",
        );
      }
      // Local models are reached through an OpenAI-compatible endpoint.
      const local = createOpenAI({ apiKey: cfg.apiKey, baseURL: cfg.baseURL });
      return wrap(local(cfg.model), provider, cfg.model);
    }
  }
}

function wrap(model: LanguageModel, provider: ModelProvider, modelId: string) {
  return { model, label: DISPLAY[provider], modelId };
}

function missingKey(envVar: string, provider: ModelProvider): ProviderError {
  return new ProviderError(
    `${DISPLAY[provider]} isn't configured on this gateway. ` +
      `Add ${envVar} to your .env to use it.`,
  );
}

/** Which providers currently have a usable configuration. */
export function availableProviders(): ModelProvider[] {
  const out: ModelProvider[] = [];
  if (config.providers.claude.apiKey) out.push("claude");
  if (config.providers.gpt.apiKey) out.push("gpt");
  if (config.providers.gemini.apiKey) out.push("gemini");
  if (config.providers.local.baseURL) out.push("local");
  return out;
}
