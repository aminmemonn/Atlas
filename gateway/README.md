# Atlas Gateway

The self-hosted server that powers the [Atlas](../README.md) iOS app. You run it on your own Mac or PC; the app pairs to it over an encrypted WebSocket. It routes each message to **whichever AI provider you have a subscription for** — OpenAI, Anthropic, or Google — using **your own API key**. Nothing goes through a third party.

- **Bring your own key.** Configure only the provider(s) you pay for. The app's model picker (Claude / GPT / Gemini / Local) chooses which one handles each message.
- **Streaming.** Replies stream token-by-token into the app.
- **Tools + approvals.** Sensitive actions (read a file, run a command, **web search**) pause and ask for your approval in the app, with a risk level. Web search is real — add a Tavily or Brave key and the agent can look things up.
- **Automations.** Natural-language recurring tasks ("every weekday at 8am, summarize my unread email") are parsed to a schedule and run on cron.
- **Local models.** Point it at Ollama / LM Studio via an OpenAI-compatible URL.

## Requirements

- Node.js 20+
- At least one provider API key (OpenAI, Anthropic, and/or Google)

## Setup

```bash
cd gateway
npm install
cp .env.example .env
# edit .env — add the key(s) for the provider(s) you use
npm start
```

That's it. On start the gateway **automatically opens a secure `wss://` tunnel** (bundled Cloudflare quick tunnel — no account needed) and prints a **QR code** (and writes `atlas-pairing.png`) plus a **manual setup code**. In the app: Onboarding → *Pair your gateway* → scan the QR (or paste the manual code).

The first run downloads the `cloudflared` binary (~30 MB) once. The pairing token is generated once and stored in `.atlas-gateway.json` (git-ignored — never share it).

To reprint the pairing code without starting the server: `npm run pair`.

## How the app connects (wss://)

For security the iOS app **only connects over `wss://`** (TLS). The gateway handles this for you three ways, in priority order:

1. **Bundled tunnel (default).** With no extra config, `npm start` opens a Cloudflare quick tunnel and puts its `wss://` URL in the QR. The URL is **ephemeral** — it changes every run, so you re-pair each time you restart. Great for trying it out.
2. **Your own stable URL.** Set `PUBLIC_URL` to a `wss://` address you control (a named Cloudflare tunnel, ngrok, Tailscale Funnel, your domain). The bundled tunnel is skipped.
   ```env
   PUBLIC_URL=wss://atlas.yourdomain.com
   ```
3. **Serve TLS directly.** Provide a certificate + key and the gateway serves `wss://` itself:
   ```env
   TLS_CERT=/path/to/fullchain.pem
   TLS_KEY=/path/to/privkey.pem
   PUBLIC_URL=wss://atlas.yourdomain.com
   ```

Set `TUNNEL=off` to disable the bundled tunnel entirely (e.g. when you manage your own).

## Configuration

All settings live in `.env` (see `.env.example` for the full list):

| Variable | Purpose |
| --- | --- |
| `PORT` / `HOST` | Listen address (default `8765` / `0.0.0.0`) |
| `PUBLIC_URL` | The `wss://` URL put in the pairing QR |
| `TLS_CERT` / `TLS_KEY` | Serve `wss://` directly instead of via a tunnel |
| `OPENAI_API_KEY` / `OPENAI_MODEL` | Enables the **GPT** option |
| `ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` | Enables the **Claude** option |
| `GOOGLE_GENERATIVE_AI_API_KEY` / `GOOGLE_MODEL` | Enables the **Gemini** option |
| `LOCAL_BASE_URL` / `LOCAL_MODEL` | OpenAI-compatible local model (Ollama, LM Studio) |
| `SYSTEM_PROMPT` | Prepended to every conversation |
| `ENABLE_FILE_TOOL` | Allow the approval-gated `read_file` tool |
| `ENABLE_SHELL_TOOL` | Allow the approval-gated `run_command` tool (off by default) |
| `TAVILY_API_KEY` / `BRAVE_API_KEY` | Enables the real `web_search` tool (auto-detected) |
| `SEARCH_PROVIDER` / `SEARCH_MAX_RESULTS` | Force a search provider / cap results |

### Web search

The `web_search` tool turns on automatically when you add a key:

- **[Tavily](https://tavily.com)** — free tier, agent-optimized, returns a synthesized answer plus sources. Set `TAVILY_API_KEY`.
- **[Brave Search API](https://brave.com/search/api)** — free tier. Set `BRAVE_API_KEY`.

If both are set, Tavily is used (override with `SEARCH_PROVIDER=brave`). With no key, the tool reports that search isn't configured instead of making anything up. Every search still goes through the in-app approval flow first.

Model IDs are fully configurable — set them to whatever your subscription supports.

## Architecture

```
src/
  index.ts       entry — prints pairing QR, starts the server
  config.ts      env + persisted token/identity
  protocol.ts    wire frames/commands (mirrors the Swift client)
  server.ts      WebSocket server + bearer-token auth
  session.ts     per-connection: streaming, approvals, automations
  providers.ts   maps the app's model choice → AI SDK provider (your key)
  tools.ts       agent tools with approval gating
  search.ts      real web search (Tavily / Brave)
  riskScoring.ts Low/Medium/High classifier (mirrors the app)
  schedule.ts    natural-language → cron
  store.ts       automation persistence (.atlas-store.json)
test/smoke.mjs   handshake/auth/error smoke test
```

The wire protocol is documented in [`../docs/GATEWAY_PROTOCOL.md`](../docs/GATEWAY_PROTOCOL.md).

## Testing

```bash
npm run typecheck          # tsc --noEmit
# smoke test (start the server first, in another terminal):
npm start
node test/smoke.mjs        # checks auth + ready frame + graceful errors
```

## Security notes

- The bearer token lives in `.atlas-gateway.json` (mode 600) and in the app's **Keychain** — never in the app's plaintext storage.
- Only `wss://` is accepted by the app.
- Tool actions are approval-gated and risk-scored; the shell tool is disabled by default.
- No telemetry. The gateway talks only to the AI provider you configured.
