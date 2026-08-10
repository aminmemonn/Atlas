# Shipping Atlas to TestFlight

A step-by-step runbook tailored to this project. Follow it top to bottom the first time.

---

## 0. Where you are right now

Your Apple Developer enrollment is **in verification** (you have a case ID). Until it's approved you **cannot**:
- get your **Team ID**,
- register App IDs / capabilities,
- create the app record in App Store Connect,
- sign a distribution build.

**Everything in Section 1 below can be done now** while you wait. Sections 2+ need the approved account. If verification stalls, reply to Apple's enrollment email with your case ID or call Apple Developer Support.

---

## 1. Do this now (no approved account needed)

### 1a. Choose a bundle identifier you own
The project ships with the placeholder prefix `com.atlas.agent`. Bundle IDs are **globally unique**, so pick your own reverse‑domain prefix — e.g. `com.yourname.atlas`. You must change it in **every** place:

| File | What to change |
| --- | --- |
| `project.yml` | `PRODUCT_BUNDLE_IDENTIFIER` for **Atlas**, **AtlasWidgets** (`.widgets`), **AtlasWatch** (`.watchkitapp`), **AtlasTests** (`.tests`); and `WKCompanionAppBundleIdentifier` |
| `Atlas/Resources/Atlas.entitlements` | the App Group `group.com.atlas.agent` and `keychain-access-groups` |
| `AtlasWidgets/AtlasWidgets.entitlements` | the App Group |
| `Shared/AtlasSharedStore.swift` | `appGroup = "group.com.atlas.agent"` |
| `Shared/WatchMessage.swift` / connectivity | no ID, leave as‑is |
| `Atlas/Resources/Info.plist` (via `project.yml`) | `CFBundleURLName` (cosmetic) |

The **App Group** must be `group.<your prefix>` and identical across the app + widgets. The **child bundle IDs must be prefixed by the main app's** (`<prefix>.widgets`, `<prefix>.watchkitapp`).

> Tip: keep the structure `<prefix>` = app, `<prefix>.widgets`, `<prefix>.watchkitapp`, group = `group.<prefix>`.

### 1b. Prepare assets & text you'll need
- **App icon** — already included (1024px, `Atlas/Resources/Assets.xcassets/AppIcon`). ✅
- **Privacy policy** — draft is in [`PRIVACY.md`](PRIVACY.md). Publish it somewhere public (GitHub Pages works) and note the URL.
- **What to Test** blurb for testers (1–2 sentences).
- **App name** in App Store Connect must be unique — have 2–3 candidates ready ("Atlas" may be taken; try "Atlas Agent", etc.).

### 1c. Confirm the build is release‑ready
Screenshot/debug hooks are already gated behind `#if DEBUG` (compiled out of release). Verify a clean type-check any time:
```bash
cd "$(git rev-parse --show-toplevel)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swiftc -typecheck -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios26.0 -swift-version 6 $(find Atlas Shared -name '*.swift')
```

---

## 2. Once enrollment is approved — one‑time account setup

### 2a. Find your Team ID
[developer.apple.com/account](https://developer.apple.com/account) → **Membership** → copy the 10‑character **Team ID**.

### 2b. Put the Team ID into the project
Edit `project.yml` → `settings.base.DEVELOPMENT_TEAM: YOURTEAMID`, then regenerate:
```bash
cd gateway/.. && xcodegen generate      # regenerates Atlas.xcodeproj
```
Also set `teamID` in [`../ExportOptions.plist`](../ExportOptions.plist) if you'll upload from the CLI.

### 2c. Register identifiers & capabilities
Easiest path: **let Xcode do it automatically.** Open `Atlas.xcodeproj`, select each target → **Signing & Capabilities** → check **Automatically manage signing** and pick your team. Xcode registers the App IDs and provisioning as needed.

If you register manually at [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list):
1. Create an **App Group**: `group.<your prefix>`.
2. Create three **App IDs**: `<prefix>`, `<prefix>.widgets`, `<prefix>.watchkitapp`.
   - On `<prefix>` and `<prefix>.widgets`: enable **App Groups** (select the group).
   - On `<prefix>`: enable **Keychain Sharing** if you use an explicit access group.
   - **Live Activities** need no capability toggle — they work via `NSSupportsLiveActivities` (already set).
   - You are using **local** notifications only, so **Push Notifications is not required**. (If you later add a server that pushes approvals, add the Push capability and APNs then.)

### 2d. Create the app record
[App Store Connect](https://appstoreconnect.apple.com) → **My Apps → + → New App**:
- Platform: iOS, Name: your chosen name, Primary language, Bundle ID: `<prefix>`, SKU: anything (e.g. `atlas-001`).

---

## 3. Archive and upload

### Option A — Xcode GUI (recommended first time)
1. Open `Atlas.xcodeproj`.
2. Toolbar destination → **Any iOS Device (arm64)**.
3. Bump the build number if re‑uploading: `project.yml` → `CURRENT_PROJECT_VERSION`, regenerate. (Each upload needs a unique build number for the same `MARKETING_VERSION`.)
4. **Product → Archive**.
5. When the **Organizer** opens → **Distribute App → App Store Connect → Upload** → follow prompts (automatic signing).

### Option B — Command line
```bash
cd "$(git rev-parse --show-toplevel)"
xcodegen generate

xcodebuild -project Atlas.xcodeproj -scheme Atlas \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Atlas.xcarchive archive

xcodebuild -exportArchive -archivePath build/Atlas.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export

# then upload the .ipa:
xcrun altool --upload-app -f build/export/Atlas.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
# (create an App Store Connect API key under Users and Access → Integrations)
```

---

## 4. TestFlight

1. App Store Connect → your app → **TestFlight** tab. The build appears after processing (a few minutes to ~1 hour).
2. **Export compliance**: already handled — `ITSAppUsesNonExemptEncryption=false` is set, so you won't be asked each time. (Atlas's only crypto is standard TLS.)
3. **Internal testing** (up to 100 people on your team, no review): add testers → they install the **TestFlight** app → accept invite → install Atlas.
4. **External testing** (up to 10,000, public link): requires a one‑time **Beta App Review** (usually <24h). Fill in the **Test Information** (What to Test, contact, and the **privacy policy URL** from step 1b).

### To actually use the build
Testers need a running **gateway** with an API key (see [`../gateway/README.md`](../gateway/README.md)). On first launch: onboarding → scan the gateway's QR → chat. Without a gateway the app opens to onboarding only.

---

## 5. Bundle identifier reference

| Target | Bundle ID | Notes |
| --- | --- | --- |
| Atlas (app) | `<prefix>` | main app record in App Store Connect |
| AtlasWidgets | `<prefix>.widgets` | app extension, embedded |
| AtlasWatch | `<prefix>.watchkitapp` | watchOS app, embedded; `WKCompanionAppBundleIdentifier = <prefix>` |
| App Group | `group.<prefix>` | shared by app + widgets |

## 6. Common pitfalls

- **"No account for team / no signing certificate"** → open in Xcode, enable *Automatically manage signing*, select your team; let Xcode create the certificate.
- **App Group mismatch** → the string in `Atlas.entitlements`, `AtlasWidgets.entitlements`, and `AtlasSharedStore.swift` must be byte‑for‑byte identical, and registered on the App IDs.
- **watchOS build fails locally** → you need the **watchOS Simulator runtime** installed (Xcode → Settings → Components) to build/run the watch target on a simulator; it's not required to archive for the App Store.
- **Duplicate build number** → bump `CURRENT_PROJECT_VERSION` and regenerate before each upload.
- **Missing privacy policy** → external TestFlight review requires the URL; internal testing does not.

---

Once verification clears, ping me with your Team ID + chosen bundle prefix and I'll apply the rename across `project.yml`, the entitlements, and `AtlasSharedStore.swift`, then regenerate and do a Release archive dry‑run.
