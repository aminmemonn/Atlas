#!/usr/bin/env node
import { config, resolveEndpoint, setRuntimePublicURL } from "./config.js";
import { availableProviders } from "./providers.js";
import { printPairing } from "./pairing.js";
import { startServer } from "./server.js";
import { startTunnel, type TunnelHandle } from "./tunnel.js";

const DISPLAY: Record<string, string> = {
  claude: "Claude",
  gpt: "GPT",
  gemini: "Gemini",
  local: "Local",
};

async function main(): Promise<void> {
  const providers = availableProviders();

  console.log("\n  Atlas Gateway");
  console.log("  ─────────────");
  if (providers.length === 0) {
    console.log(
      "  ⚠  No providers configured. Add at least one API key to .env\n" +
        "     (OPENAI_API_KEY, ANTHROPIC_API_KEY, or GOOGLE_GENERATIVE_AI_API_KEY).",
    );
  } else {
    console.log(
      `  Providers ready: ${providers.map((p) => DISPLAY[p] ?? p).join(", ")}`,
    );
  }

  // Bring up a bundled secure tunnel unless the operator configured their own
  // PUBLIC_URL / TLS, or disabled it with TUNNEL=off. This makes `npm start`
  // produce a scannable wss:// QR with zero manual setup.
  let tunnel: TunnelHandle | undefined;
  const needsTunnel =
    !config.publicURL &&
    !(config.tlsCert && config.tlsKey) &&
    config.tunnel !== "off";

  if (needsTunnel) {
    console.log("  Starting a secure tunnel (cloudflared)…");
    try {
      tunnel = await startTunnel(config.port);
      setRuntimePublicURL(tunnel.url.replace(/^https:\/\//, "wss://"));
      console.log(`  Tunnel ready: ${tunnel.url}`);
    } catch (err) {
      console.log(
        `  ⚠  Could not start the bundled tunnel (${(err as Error).message}).\n` +
          "     Falling back — set PUBLIC_URL to a wss:// URL to pair the app.",
      );
    }
  }

  const { secure, note } = resolveEndpoint();
  if (!secure && note) console.log(`  ${note}`);

  // Always show the pairing QR on startup so a fresh device can connect.
  await printPairing();

  // `--show-pairing` just prints the code and exits (npm run pair).
  if (process.argv.includes("--show-pairing")) {
    tunnel?.stop();
    process.exit(0);
  }

  const shutdown = () => {
    tunnel?.stop();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);

  startServer();
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
