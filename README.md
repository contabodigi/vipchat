# VIP Chat — iOS (vipchat.live)

Native SwiftUI port of the Android app, talking to the **same** live backend
(`vipchat.live`, port 3004) — same REST + Socket.IO contract, same Firebase
project. Built and shipped **without a Mac** via Codemagic cloud CI.

## Status: full source written, NOT yet compiled

Like the Android app before its SDK existed, this is written blind (no Mac here
to compile SwiftUI/WebRTC). Expect the first few Codemagic builds to surface
compile errors to fix — normal for a first cloud build. Everything is structured
and mirrors the proven Android logic 1:1.

Feature parity: phone/OTP auth, chat with optimistic send + retry, media & voice
notes, reactions, reply, WebRTC calling (customer-creates-offer), FCM/APNs push,
remote config (server-changeable Meta ID / force-update / TURN), RB green icon +
green splash, casino login theme + WhatsApp chat theme.

## Project layout
- `project.yml` — XcodeGen spec; CI runs `xcodegen generate` to make the .xcodeproj.
- `codemagic.yaml` — cloud build + automatic signing + TestFlight/App Store publish.
- `VipChat/` — all Swift sources (App, Core/{Network,Socket,Config,Storage}, Auth, Chat, Call, Push, Meta, Theme, Resources).
- `VipChat/Resources/Assets.xcassets` — app icon (from `vipchat-android/vipchatgreen.png`), splash logo, brand green, chat wallpaper.

## Backend shim (already deployed)
The iOS socket.io client sends the auth token as a handshake **query** param
(Android/web use `auth`). A 1-line backward-compatible change in
`backend/middleware/auth.js` (`handshake.auth?.token || handshake.query?.token`)
is already live on all 4 sites. No other backend change is needed.

## Ship checklist (all browser/iPhone — no Mac)

**Accounts (cost: $99/yr Apple only; everything else free):**
1. **Apple Developer Program** — enroll at developer.apple.com ($99/yr; browser or the Apple Developer iPhone app).
2. **App Store Connect** → create the app record (bundle id `live.vipchat.app`).
3. **App Store Connect API key** (Users and Access → Integrations → App Store Connect API) → note Issuer ID, Key ID, download the `.p8`.
4. **Firebase** → add an **iOS app** to the existing `chat-appsvipchat` project (bundle id `live.vipchat.app`) → download **`GoogleService-Info.plist`** → put it in `VipChat/Resources/`.
5. **APNs auth key** (Apple → Certificates, Identifiers & Profiles → Keys → new key with Apple Push Notifications) → upload the `.p8` to Firebase → Project settings → Cloud Messaging → iOS app. This is what lets FCM deliver to iPhones.

**Build & test:**
6. Push this folder to a Git repo (GitHub/GitLab/Bitbucket).
7. In **Codemagic**: connect the repo, add the App Store Connect API key (Integrations), run the `ios-release` workflow. Fix any compile errors it reports, re-run.
8. Green build → lands in **TestFlight** → install on your iPhone via the TestFlight app → run the full test walkthrough.

**Submit:**
9. In `codemagic.yaml` set `submit_to_app_store: true` (add release notes), or promote the TestFlight build in App Store Connect.
10. **App Store review**: keep the listing name + description **neutral** ("customer support chat") — no betting/casino terms — to reduce guideline 4.7/5.3 risk. Fill the privacy nutrition labels: phone number (account), chat content/photos (user content), microphone (calls/voice).

## Meta App Events (optional, no rebuild)
Meta is initialized from remote config, so once you have a Facebook App ID +
Client Token, set them in the server's `appConfig.meta` (via the dashboard/DB) —
the app picks them up on next launch. No app update needed.

## Notes / limitations vs Android
- Same deliberate scope: no message search / edit-own / view-once (customer app).
- Calling is outgoing-only (no CallKit needed) — matches backend (customer-initiated calls).
- iOS push requires the APNs key step above; without it, push is inert (rest of app works).
