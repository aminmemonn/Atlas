# Atlas — Privacy Policy

_Last updated: 2026-07-01_

Atlas is a personal AI agent app that pairs with a **gateway you run yourself**. It is built to be private by design. This policy explains exactly what the app does and does not do with your information.

> **Publish this page** (e.g. GitHub Pages, your own site) and paste its URL into App Store Connect → App Privacy → Privacy Policy URL. Replace the contact email below with yours.

## The short version

- **We collect nothing.** Atlas has no analytics, no advertising, no third‑party trackers, and no backend operated by us.
- Your conversations and data flow only between **your device**, the **gateway you host**, and the **AI provider whose API key you configured** (e.g. OpenAI, Anthropic, or Google).
- Secrets (your gateway token) are stored only in the **iOS Keychain**.
- Conversation history is stored **locally on your device** so you can read it offline.

## Information Atlas handles

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Messages you send / receive | On your device (local history) and passed to your gateway → your chosen AI provider | You, your self‑hosted gateway, your AI provider |
| Gateway pairing token | iOS Keychain only | You |
| Approvals & automations | On your device and your gateway | You |
| Microphone / camera / photos / contacts / calendar / reminders / location | Used **only** when you grant permission and only for the action you request | You, and your gateway if you send that content to the agent |

Atlas does **not** send any of this to the app's developers. There is no developer server.

## Device permissions and why they're requested

Each permission is **opt‑in**, requested one at a time, and revocable at any time in Settings or iOS Settings:

- **Microphone / Speech recognition** — voice conversations and transcription.
- **Camera** — scanning your gateway's pairing QR code, and sharing images with the agent when you choose.
- **Photos, Contacts, Calendar, Reminders, Location** — only used when you explicitly ask the agent to use them, and only after you grant access.
- **Notifications** — to alert you when the agent needs your approval.

## Third‑party AI providers

When you send a message, your self‑hosted gateway forwards it to the AI provider **you** configured with **your** API key. That provider's handling of your data is governed by **their** privacy policy and your agreement with them. Atlas does not choose or control that provider. If you run a local model, your messages never leave your own hardware.

## Data retention and deletion

- Local conversation history and approvals stay on your device until you delete them (Settings → Privacy → Clear local history, or by deleting the app).
- Your gateway token can be removed at any time by disconnecting or re‑pairing in Settings, which deletes it from the Keychain.
- Any data retained by your gateway or your AI provider is under your control / theirs, respectively.

## Children

Atlas is not directed to children under 13 and does not knowingly collect information from them.

## Changes

If this policy changes, the "Last updated" date above will change and the new version will be published at this URL.

## Contact

Questions about privacy: **your-email@example.com**
