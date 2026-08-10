import { existsSync } from "node:fs";
import { bin, install, Tunnel } from "cloudflared";

export interface TunnelHandle {
  /** Public https URL of the quick tunnel. */
  url: string;
  stop: () => void;
}

/**
 * Starts a Cloudflare quick tunnel pointing at the local gateway port and
 * returns its public URL. Downloads the `cloudflared` binary on first run.
 * Quick tunnels require no Cloudflare account; the URL is ephemeral and changes
 * each start (set PUBLIC_URL with a named tunnel for a stable address).
 */
export async function startTunnel(port: number): Promise<TunnelHandle> {
  if (!existsSync(bin)) {
    console.log("  Downloading cloudflared (first run only, ~30 MB)…");
    await install(bin);
  }

  // `Tunnel.quick` runs `cloudflared tunnel --url …` — the account-less quick
  // tunnel. (Passing an options object instead would produce `tunnel run`,
  // which is for named tunnels and never yields a quick URL.)
  const t = Tunnel.quick(`http://localhost:${port}`);
  t.process.on("error", (err: Error) =>
    console.error("  Tunnel process error:", err.message),
  );

  // The `url` event fires once cloudflared reports the public address.
  const urlPromise = new Promise<string>((resolve) => {
    t.once("url", (url: string) => resolve(url));
  });
  const url = await withTimeout(urlPromise, 30_000, "tunnel did not come up in time");

  return {
    url,
    stop: () => {
      try {
        t.stop();
      } catch {
        /* ignore */
      }
    },
  };
}

function withTimeout<T>(p: Promise<T>, ms: number, message: string): Promise<T> {
  return Promise.race([
    p,
    new Promise<T>((_, reject) => setTimeout(() => reject(new Error(message)), ms)),
  ]);
}
