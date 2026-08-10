# Atlas

A self-hosted personal AI agent for iOS — native Swift 6 / SwiftUI, built around the **Liquid Glass** design system. Atlas pairs with a lightweight gateway you run on your own Mac or PC, giving a personal agent access to chat, voice, device capabilities, and automations through an interface that feels first-party to iOS.

## Highlights

- **Liquid Glass UI** — `.glassEffect()` throughout, translucent layered materials, a floating glass tab bar, spring-driven motion, full Dynamic Type / Dark Mode / accessibility support.
- **Chat** with streaming responses and inline, animated tool-use pills (“Searching the web…”, “Reading file…”).
- **Talk Mode** — full-screen voice conversation with a real-time, audio-reactive liquid-glass orb (Canvas), on-device speech-to-text and text-to-speech, background audio.
- **Per-action risk scoring** — every approval is classified Low / Medium / High based on what the action does, locally and deterministically.
- **Live Activities** in the Dynamic Island & Lock Screen (ActivityKit).
- **Home Screen widgets** (WidgetKit) and a **glanceable Apple Watch companion** for approvals and quick voice.
- **Shortcuts & Siri** via App Intents.
- **Security-first** — `wss://`-only gateway transport, tokens stored exclusively in the Keychain, no analytics or third-party SDKs, local-first history that works fully offline.

## Requirements

- Xcode 26+ (iOS 26 / watchOS 26 SDKs, Liquid Glass APIs)
- [XcodeGen](https://github.com/yonyz/XcodeGen) to generate the project: `brew install xcodegen`

## Getting started

```bash
xcodegen generate     # produces Atlas.xcodeproj from project.yml
open Atlas.xcodeproj
```

Select the **Atlas** scheme and run. Set your signing team in Xcode (the project ships with automatic signing and empty team). The App Group `group.com.atlas.agent` and Keychain sharing must be enabled for your team for widgets/Watch sharing to work.

### Running tests

```bash
xcodebuild test -scheme Atlas -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Unit tests cover the core business logic: gateway message parsing (`GatewayCoder`), approval risk scoring (`RiskScoring`), and pairing-payload validation.

## Architecture

MVVM with the modern Observation framework (`@Observable`) and Swift Concurrency.

```
Atlas/
  App/            AtlasApp, AppEnvironment (composition root + frame routing)
  Models/         Message, Agent, Approval, Automation, Gateway, DeviceCapability
  ViewModels/     Chat, Talk, Onboarding, Automations, Settings
  Services/       Gateway (actor WebSocket), Keychain, Voice, Notification,
                  Capability, LiveActivity, PhoneConnectivity
  Components/     GlassCard, GlassButton, GlassPill, WaveformView, AtlasBackground, Theme
  Views/          Onboarding, Chat, Talk, Approvals, Automations, Settings, Root
  AppIntents/     Siri / Shortcuts
  Resources/      Assets, Info.plist, entitlements, Localizable.strings
Shared/           Cross-target snapshot, Live Activity attributes, Watch contract
AtlasWidgets/     Home Screen widget + Live Activity
AtlasWatch/       watchOS companion
AtlasTests/       Unit tests
```

- **`GatewayService`** is an `actor` wrapping `URLSessionWebSocketTask`, exposing inbound frames and connection state as `AsyncStream`s with bounded exponential-backoff reconnection.
- **`AppEnvironment`** is the `@MainActor` composition root: it fans gateway frames into SwiftData, drives Live Activities, and mirrors a glanceable snapshot to widgets and the Watch.
- All secrets live in **`KeychainService`** only.

## The gateway server

Atlas is the client half; the [`gateway/`](gateway/) directory is the self-hosted server it pairs with. It's a Node.js + TypeScript server that routes each message to **whichever AI provider you have a key for** (OpenAI / Anthropic / Google / local), streams replies back, and drives the approval and automation flows.

```bash
cd gateway
npm install
cp .env.example .env   # add your provider key(s)
npm start              # opens a secure tunnel + prints a pairing QR to scan
```

`npm start` automatically opens a secure `wss://` tunnel (bundled — no account or extra setup) and prints a scannable QR. For a stable address you can instead set `PUBLIC_URL` to your own `wss://` URL. Full instructions: [`gateway/README.md`](gateway/README.md).

See [`docs/GATEWAY_PROTOCOL.md`](docs/GATEWAY_PROTOCOL.md) for the wire protocol both sides implement.
