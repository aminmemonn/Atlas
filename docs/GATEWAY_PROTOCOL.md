# Atlas Gateway Protocol

Atlas connects to your self-hosted gateway over a single **secure WebSocket** (`wss://` only). All frames are JSON objects with a `type` discriminator and a `payload`. Unknown frame types are ignored by the app, so you can extend the protocol without breaking older clients.

The bearer token from pairing is sent as `Authorization: Bearer <token>` on the WebSocket upgrade request, plus an `X-Atlas-Client: atlas-ios` header.

## Pairing

The app reads a QR code (or manually entered code) containing:

```json
{ "name": "Home Mac", "endpoint": "wss://atlas.local:8443/ws", "token": "…" }
```

The endpoint **must** use `wss://` or the app rejects it.

## Inbound frames (gateway → app)

| `type` | `payload` | Effect |
| --- | --- | --- |
| `ready` | `{ "model": "claude" }` | Marks the agent ready, sets active model. |
| `message_delta` | `{ "id": UUID, "text": String }` | Appends streamed text to a message (creates it if new). |
| `message_completed` | `{ "id": UUID }` | Ends streaming for a message. |
| `tool_started` | `{ "messageID": UUID, "name": String, "detail": String? }` | Shows an inline tool pill. |
| `tool_finished` | `{ "messageID": UUID, "name": String, "success": Bool }` | Resolves the pill. |
| `approval_requested` | `ApprovalRequest` (below) | Creates a risk-scored approval + notification. |
| `automation_updated` | `{ "id": UUID, "title": String, "scheduleDescription": String, "status": String, "nextRunAt": Date? }` | Upserts an automation. |
| `agent_status` | `{ "status": String, "activity": String? }` | Updates status (`idle`/`thinking`/`working`/`awaitingApproval`/`offline`). |
| `heartbeat` | — | Liveness ping. |
| `error` | `{ "message": String }` | Surfaces a recoverable error. |

### `ApprovalRequest`

```json
{
  "id": "UUID",
  "title": "Run build script",
  "description": "Executes build.sh in ~/project",
  "domain": "shell",
  "parameters": { "cmd": "sh build.sh" },
  "riskHint": "high"
}
```

`riskHint` is optional. The app derives a Low/Medium/High level locally from `domain` and escalating keywords; a `riskHint` can only **raise** the displayed level, never lower it.

## Outbound frames (app → gateway)

| `type` | `payload` |
| --- | --- |
| `send_message` | `{ "id": UUID, "text": String, "model": String }` |
| `resolve_approval` | `{ "id": UUID, "approved": Bool }` |
| `create_automation` | `{ "prompt": String }` |
| `set_capability` | `{ "capability": String, "enabled": Bool }` |
| `cancel_message` | `{ "id": UUID }` |

Dates use ISO 8601. The app reconnects automatically with exponential backoff (up to 6 attempts).
