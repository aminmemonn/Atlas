import { createServer as createHTTPServer, type IncomingMessage } from "node:http";
import { createServer as createHTTPSServer } from "node:https";
import { readFileSync } from "node:fs";
import { timingSafeEqual } from "node:crypto";
import { WebSocketServer, type WebSocket } from "ws";
import { config } from "./config.js";
import { decodeCommand } from "./protocol.js";
import { Session } from "./session.js";

/** Constant-time bearer-token check against the paired token. */
function isAuthorized(req: IncomingMessage): boolean {
  const header = req.headers["authorization"];
  let presented: string | undefined;
  if (typeof header === "string" && header.startsWith("Bearer ")) {
    presented = header.slice("Bearer ".length).trim();
  } else {
    // Fallback: ?token= in the URL (some tunnels strip auth headers).
    const url = new URL(req.url ?? "/", "http://localhost");
    presented = url.searchParams.get("token") ?? undefined;
  }
  if (!presented) return false;
  const a = Buffer.from(presented);
  const b = Buffer.from(config.token);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function startServer(): void {
  const httpServer = config.tlsCert && config.tlsKey
    ? createHTTPSServer({
        cert: readFileSync(config.tlsCert),
        key: readFileSync(config.tlsKey),
      })
    : createHTTPServer();

  // Simple health endpoint for humans, tunnels, and uptime checks.
  httpServer.on("request", (req, res) => {
    if (req.url === "/health" || req.url === "/") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true, service: "atlas-gateway" }));
    } else {
      res.writeHead(404);
      res.end();
    }
  });

  const wss = new WebSocketServer({ noServer: true });

  httpServer.on("upgrade", (req, socket, head) => {
    if (!isAuthorized(req)) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit("connection", ws, req);
    });
  });

  wss.on("connection", (ws: WebSocket, req: IncomingMessage) => {
    const client = req.headers["x-atlas-client"] ?? "unknown";
    console.log(`✔ App connected (${String(client)})`);
    const session = new Session((data) => {
      if (ws.readyState === ws.OPEN) ws.send(data);
    });

    ws.on("message", (raw) => {
      const command = decodeCommand(raw);
      if (!command) return;
      session.handle(command).catch((err) => {
        console.error("Command handler error:", err);
      });
    });

    ws.on("close", () => {
      console.log("✖ App disconnected");
      session.dispose();
    });

    ws.on("error", (err) => {
      console.error("WebSocket error:", err.message);
    });
  });

  httpServer.listen(config.port, config.host, () => {
    const scheme = config.tlsCert && config.tlsKey ? "wss" : "ws";
    console.log(
      `Atlas Gateway listening on ${scheme}://${config.host}:${config.port}`,
    );
  });
}
