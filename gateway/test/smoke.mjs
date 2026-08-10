// Minimal end-to-end smoke test: boots nothing itself — assumes the gateway is
// already running on PORT with the token from .atlas-gateway.json. Verifies
// auth acceptance/rejection, the `ready` frame, and a graceful error when a
// message is sent to an unconfigured provider.
import WebSocket from "ws";
import { readFileSync } from "node:fs";

const PORT = process.env.PORT || 8799;
const { token } = JSON.parse(readFileSync(".atlas-gateway.json", "utf8"));

function connect(tok) {
  return new WebSocket(`ws://127.0.0.1:${PORT}`, {
    headers: { Authorization: `Bearer ${tok}`, "X-Atlas-Client": "smoke" },
  });
}

let passed = 0;
let failed = 0;
const ok = (cond, msg) => (cond ? (passed++, console.log("  ✔", msg)) : (failed++, console.log("  ✘", msg)));

// 1) Wrong token must be rejected.
await new Promise((resolve) => {
  const ws = connect("wrong-token");
  ws.on("open", () => {
    ok(false, "rejects invalid token");
    ws.close();
    resolve();
  });
  ws.on("error", () => {
    ok(true, "rejects invalid token");
    resolve();
  });
});

// 2) Valid token connects and receives `ready`, then a graceful error on send.
await new Promise((resolve) => {
  const ws = connect(token);
  let sawReady = false;
  const timer = setTimeout(() => {
    ok(sawReady, "received ready frame");
    ws.close();
    resolve();
  }, 3000);

  ws.on("open", () => {
    ws.send(
      JSON.stringify({
        type: "send_message",
        payload: { id: crypto.randomUUID(), text: "hello", model: "claude" },
      }),
    );
  });
  ws.on("message", (data) => {
    const frame = JSON.parse(data.toString());
    if (frame.type === "ready") {
      sawReady = true;
      ok(true, "received ready frame");
    }
    if (frame.type === "error") {
      ok(true, `graceful error when provider missing: "${frame.payload.message.slice(0, 40)}…"`);
      clearTimeout(timer);
      ws.close();
      resolve();
    }
  });
  ws.on("error", (e) => {
    ok(false, "valid token connects: " + e.message);
    clearTimeout(timer);
    resolve();
  });
});

console.log(`\n  ${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
