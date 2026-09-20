# Mac & Android DND Sync — Handoff v4

Status: Phases 0–4 are **done** (same-Wi-Fi harness). Cloud path pivoted
2026-09-17: **APNs** wakes the Mac in v1; the always-on **relay** and the
Mac **live socket (SSE)** are dropped.
Last updated: 2026-09-17
Supersedes: the 2026-09-16 v4 text (relay + SSE as the off-LAN Mac path)
and `plan-phase-5.md` (Hono/SSE/VPS). Treat that phase-5 plan as history
until it is rewritten.

v4 product scope is unchanged. Do **not** ship a finished Android app,
then a finished Mac app, then “connect them.”

**Build order:** scaffold → OS harnesses → fake wake → LAN sync (all
done) → **Mac APNs harness** → **request/response push forwarder**
(FCM + APNs, no socket) → real apps.

## 0. Name

- **Product name (v1):** **Mac & Android DND Sync**. Explicit and locked for
  now; not a brand exercise. Rename later if a shorter public name is needed.
- **Short label:** **DND Sync** — Android launcher, Mac menu-bar accessibility
  name, About box secondary line, notarized `.dmg` filename if the full name
  is too long (`Mac-Android-DND-Sync.dmg` is fine).
- **Do not** put “Focus” or “Zen” in the title. Fine in body copy
  (Mac Focus / Android Modes).

---

## 1. What this is

A pair of apps (Mac + Android) that keep Do Not Disturb / Focus state in sync
so silencing **one** device stops interrupts on the **other**.

No mature Mac↔Android **OS DND** sync exists today. AirSync, Bounce Connect,
KonnectMac (KDE Connect), Eunify, and LinkMyMac sync notifications / clipboard /
files; they do not sync system DND/Focus. AirSync has an open request to toggle
phone DND from the Mac. Bounce can silence **mirrored Mac notifications** from
the menu bar without touching Android's OS DND. Google is building DND sync
**across Android devices only** (Play Services strings; not Mac). This product
stays a **standalone** pair of apps — not an AirSync plugin.

## 2. Purpose & success

- **Pain:** after you silence one device, the other still interrupts you
  (calls / notifications).
- **v1 users:** you, plus a handful of friends who will actually install it.
- **“It works”:** put either device on DND; the other follows in **seconds on
  the same Wi-Fi**, and within **~10s** when they are not. Day-to-day the app
  is not something you think about.
- **Done line for v1:** you use it daily for a **week** with no missed
  silences. Not “all friends on stores.”

## 3. Scope (v1)

- One Mac ↔ one Android phone pairing. Data model can grow later; do not
  build multi-device in v1.
- **Binary on/off only.** Any **active Mac Focus** (Work, Sleep, DND, …) is
  **on** for Android. Android **on** activates one **default Mac Focus**
  (system Do Not Disturb). Named-mode mapping (Work↔Work) is post-v1.
- **Sync direction:** bidirectional only. Whoever changes first propagates.
  No Mac-is-master / Android-is-master in v1.
- **Conflicts:** last-write-wins using each device's clock. Accept rare skew.
- **Loops:** last-write-wins does **not** stop ping-pong. After applying a
  remote state, **echo-suppress** the resulting local Focus/DND notification
  (or an equivalent short debounce). LWW = true conflicts; echo suppression =
  “we caused this event.”
- **Offline / server down:** **best-effort**. If devices are not on the same
  LAN and the cloud path is down, the toggle can be dropped; the next
  successful change wins. No durable outbox.

## 4. Identity, pairing, settings

There is **no** Sign in with Apple/Google, and **no** username/password, in
v1. There is **no users table**.

- **Pairing** is QR on the same network (binds this Mac to this phone).
- QR carries: push-forwarder URL, `pair_id`, a high-entropy
  **`pair_secret`**, E2E public keys, and the Mac **APNs device token**.
- Cloud “auth” is that **pair bearer**. Devices **POST** with
  `Authorization: Bearer <pair_secret>`. There is **no** Mac stream to
  authenticate. The forwarder stores only a **hash** of the secret, device
  records, the Android **FCM** token, and the Mac **APNs** token.
- **Create-pair** also requires a **build-time app key** baked into the
  private Mac/Android builds so a public forwarder URL is not an open
  FCM/APNs proxy. That is operator auth, not user auth.
- Android **registers its FCM token during QR pairing** (same `POST` that
  joins the pair). Mac **registers its APNs token** when it creates the
  pair, and again on token refresh.
- **Settings** live on **both devices** and copy over the same encrypted
  pair channel. The server does not store user config.
- **Re-pair:** a new QR on the remaining device **rotates the E2E key and
  `pair_secret`** and kills the old pair hash. There is no account login
  that could rebind a stolen device.
- **Post-v1:** Apple/Google or email/password can attach existing `pair_id`s
  to a user. Not required to ship.

## 5. Architecture

### Off-LAN path (plain language)

There is **no always-on relay** and **no live Mac socket**. SSE, WebSocket,
long-poll, and MQTT are **out** for v1.

The remaining cloud piece is a **push forwarder**: a **request/response**
HTTP service you build. It is **not** Tailscale, not a VPN, not a
marketing site, and not Google's Android-only DND sync. Because it does
not hold a connection, it **may** run as a serverless function (Workers,
Cloud Functions, or equivalent). It must **not** require a VPS just to
keep a socket alive.

- **Same Wi-Fi:** apps discover each other with **Bonjour/mDNS**, talk
  **directly**, short timeout, then fall back. This path is already built
  (Phase 4).
- **Not the same Wi-Fi:** the changing device **POSTs** an **encrypted
  blob** to the forwarder. The forwarder **fans it out** and exits:
  **FCM** high-priority **data-only** wake on Android; **APNs silent
  push** (`content-available`, no alert/sound/badge) on the Mac. Successful
  sync stays silent.

The forwarder is **blind**: outer protobuf envelope has routing ids it
already knows (`pair_id`, sender device) plus **opaque ciphertext**. It
does **not** learn the on/off bit.

You cannot drop the forwarder entirely: APNs and FCM will not accept
pushes from the peer app without server credentials. Putting the APNs
`.p8` or the Firebase service account inside either client is rejected.
The forwarder exists to hold those credentials and the pair's push tokens.

The Phase 0 scaffold included a Hono health stub under `/relay`. That
tree is **removed**. Do not bring it back as SSE, an in-memory stream
registry, or an always-on VPS. Phase 6 introduces a new **push
forwarder** whose role is “POST → push,” not “hold a Mac connection.”

### Other architecture notes

- **No persistent Android background socket.** FCM push-wake only (avoids a
  foreground-service notification). Successful sync is silent in the shade.
- **No persistent Mac network socket** for cloud. APNs wake only. The menu
  bar / login-item app must be **running** for silent pushes to apply
  Focus; a fully quit or sleeping Mac may miss a toggle until it wakes
  (best-effort, same as any missed push).
- **Distribution:** closed-source / private. **Notarized Mac download** +
  **Play internal/closed testing or sideload** for friends. Stores are later.
  Free; no monetization in v1.
- **No marketing site in v1.** Next.js for a landing page is a later,
  **separate deploy** if ever.

## 6. Stack (locked)

Native clients. The product *is* OS APIs; Flutter/KMP/Electron would still
need Swift and Kotlin plugins for almost every real feature.

### 6.1 Shared

- **Repo:** one private monorepo: `/apps/macos`, `/apps/android`,
  `/proto`. Phase 6 adds a small HTTP **push forwarder** (new tree,
  request/response only; no SSE). There is **no** `/relay` folder.
- **Contract:** versioned **protobuf**. Both apps generate from `/proto` in
  CI; conformance fixtures fail the build on codec drift.
- **E2E:** long-term **X25519** keys; QR exchanges public keys + `pair_id`;
  ECDH → **HKDF-SHA256** → **AES-256-GCM**. Independent implementations:
  **CryptoKit** (Mac), **Tink** (Android). No shared Rust/C core in v1.
- **Inner message:** version, on/off, unix-ms timestamp, sender. Outer
  **cloud envelope:** routing metadata + ciphertext. LAN uses the inner
  message only. Envelope must fit an **APNs** payload (plan for ≤4 KiB).
- **HTTP:** `application/protobuf` (or equivalent binary) on device →
  forwarder POSTs. Forwarder → devices is push, not a response body.

### 6.2 Mac (macOS 14+)

- Swift, **SwiftUI `MenuBarExtra`** + Settings scene + wizard window.
  AppKit status item only if MenuBarExtra + `LSUIElement` misbehaves.
- **LAN:** **Network.framework** (`NWBrowser` / `NWListener` / `NWConnection`)
  with an owned Bonjour service type.
- **Set Focus:** **ScriptingBridge / Shortcuts run** as the real
  implementation (App Store path: `scripting-targets` +
  `com.apple.shortcuts.run`). Ship a **prebuilt On/Off** `.shortcut` pair;
  first run opens them, user taps **Add** twice. No silent generation from
  `ModeConfigurations.json`. No `Assertions.json` / `donotdisturbd`.
- **Read Focus:** `_NSDoNotDisturbEnabledNotification` (no polling).
- **Secrets:** **Keychain** (`AfterFirstUnlockThisDeviceOnly`).
- **Cloud receive:** **APNs** silent / data push via
  `registerForRemoteNotifications` + App ID **Push Notifications**.
  Entitlement `aps-environment`. No SSE, no `URLSession` bytes stream, no
  Firebase SDK on Mac.
- **Cloud send:** **URLSession** POST of the envelope to the forwarder.
- **UI:** menu bar live status (paired / DND on / last error), click →
  settings. **No third DND toggle.**
- **First run:** wizard = permissions + QR + Add Shortcut twice. No sign-in.
  “You're paired” only after required grants exist.
- **App Store:** viable later (`SMAppService` login item, etc.). Not a v1 gate.

### 6.3 Android (API 35+)

- Kotlin, **Jetpack Compose**, Material 3, **Hilt**, Coroutines/Flow.
- **LAN:** platform **NsdManager** + TCP; same protobuf frames as cloud.
  Not Nearby Connections, not Wi-Fi Direct, not JmDNS.
- **Read DND:** `ACTION_INTERRUPTION_FILTER_CHANGED` +
  `ACCESS_NOTIFICATION_POLICY`.
- **Set DND:** app **`AutomaticZenRule`** (Play-safe).
- **Rejected:** `CompanionDeviceManager` + `DEVICE_PROFILE_WATCH`.
- **Accepted trade-off:** **on** is real OS DND. **Off** can be vetoed if the
  manual tile or another app's rule is still active (“most restrictive
  wins”). Failed off: one notification **per incident**, deep-link to system
  DND/Modes settings.
- **Secrets:** **Tink** + **Android Keystore** wrapping the pair key.
- **Wake:** **FCM data-only, high priority** via `FirebaseMessagingService`.
  No foreground-service socket.

### 6.4 Push forwarder

- **Role:** authenticate the pair, store token records, **POST → FCM and
  APNs**, return. No open streams.
- **Host:** serverless-capable. Cloudflare Workers, Cloud Functions, or a
  scale-to-zero container are all fine. An always-on VPS is **not**
  required and is **not** the v1 default.
- **DB:** **managed** store (Postgres or equivalent KV). Schema: pair hash,
  devices, FCM token, APNs token, timestamps — never DND state.
- **Android wake:** FCM HTTP v1, high-priority data-only (same Firebase
  project as Phase 3).
- **Mac wake:** APNs HTTP/2 with a **.p8** key (token auth). Silent
  payload; same envelope fields FCM carries, as strings. Do **not** put
  Firebase on the Mac app in order to “reuse FCM.”
- **Not v1:** SSE / WebSocket / long-poll, Pusher, Ably, ntfy, an
  always-on Node process whose job is to hold the Mac connection.

## 7. Mac OS behavior

See §6.2. Writing `Assertions.json` + restarting `donotdisturbd` stays
**rejected**.

## 8. Android OS behavior

See §6.3.

## 9. Build phases (locked)

Phases **0–4 are done**. Prove **APNs apply** before a real forwarder or
product UI. Do **not** finish one client, then the other, then “connect
them.” Do **not** revive SSE as a shortcut around Apple push setup.

**Order:** 5 → 6 → 7. One person: APNs harness first (the Mac wake door
is unproven; Android FCM already exited in Phase 3). Then the forwarder,
then the real apps.

`plan-phase-5.md` described Hono + Postgres + SSE + VPS. That plan is
**superseded**. Do not implement it.

### Phase 0 — Monorepo scaffold — **done**

Layout `/apps/macos`, `/apps/android`, `/proto`. Blank apps and proto
codegen. A health-only `/relay` stub existed in this phase and has
since been **removed** from the repo.

### Phase 1 — Android DND harness — **done**

Read + set via `AutomaticZenRule`; honest failed-off notification.

### Phase 2 — Mac Focus harness — **done**

Shortcuts On/Off + `_NSDoNotDisturbEnabledNotification` (no polling).

### Phase 3 — Fake “outside the device” — **done**

Android FCM data-only apply with the screen off. Mac loopback `POST`
`:8787` runs Shortcuts. That loopback listener stays as a **dev trigger**;
it is not the cloud path.

### Phase 4 — Same-Wi-Fi sync — **done**

Bonjour/NSD + TCP, inner `DndState`, LWW + echo suppression. First real
product path. Hardcoded pair.

### Phase 5 — Mac APNs harness (next)

**Goal:** prove Apple can wake and apply Focus **without a live socket**,
the way Phase 3 proved FCM on Android. Still no pairing, no forwarder,
no product chrome.

- Apple Developer: App ID with **Push Notifications**; `.p8` key; Mac
  bundle id entitlement `aps-environment` (development).
- Harness registers for remote notifications and shows the **device
  token** (copyable), same idea as Android **Copy token**.
- A tiny Node script (`scripts/apns-send/`, parallel to
  `scripts/fcm-send/`) sends a **silent** data push (`content-available`,
  no alert) with `command=on` / `command=off`.
- Handler calls the existing Shortcut `turnOn()` / `turnOff()` path
  (not LAN, not a socket). Keep the Phase 3 loopback server.
- **No** SSE, **no** Hono pair routes, **no** VPS, **no** QR.

**Exit:** with the Mac app **running** (harness window is enough), a
scripted silent push applies system Do Not Disturb. Repeat off. If a
silent push cannot apply Focus while the app is running, **stop** — do
not add a live socket to paper over it.

### Phase 6 — Off-LAN push path

**Goal:** hit the “~10s off LAN” bar with **FCM + APNs** through the
push forwarder. Reuse the Phase 4 `LanSyncGate` (same instance) so LAN
and cloud dedup for free.

Split like the old 5.A / 5.B:

- **6.A — plumbing, hardcoded pair, placeholder envelope.** Forwarder
  routes + token register (FCM + APNs). Mac POSTs envelopes and
  receives APNs; Android POSTs envelopes and receives FCM. Dual-send
  from `onOriginate`; both inbound paths feed `onRemote`. Ciphertext
  may be plaintext `DndState` bytes until 6.B.
- **6.B — QR, E2E, Keychain / Keystore.** Replace the hardcoded pair.
  QR payload per §4. AES-256-GCM on the envelope. Re-pair rotates
  `pair_secret` and keys.

**Exit:** leave the house, flip DND; the other device follows within
~10s (best-effort if the path is down; no durable outbox). Killing the
forwarder does not require either app to hold a socket.

### Phase 7 — Real apps

**Goal:** ship the private dogfood builds.

- Mac menu bar, first-run wizard (permissions + QR + Add Shortcut twice).
  Login item so the app is running for APNs.
- Android settings / failed-off copy.
- Notarized Mac download + Play internal/sideload.

**Exit:** daily use for a **week** with no missed silences (§2 done line).

### Anti-patterns

- Skip Phase 5 and stand up a forwarder (or a VPS) before APNs apply
  works on the harness.
- Revive SSE / WebSocket “until APNs is ready.” APNs **is** the v1 Mac
  path; start it in Phase 5.
- Implement `plan-phase-5.md` (always-on Hono + SSE).
- Finished Android app → finished Mac app → connect them later.
- Product chrome (menu bar polish, branding) before Phase 4 works
  (already satisfied) **and** before Phase 6 off-LAN works.

## 10. What is explicitly not v1

- User accounts, Sign in with Apple/Google, email/password
- Master-device modes
- Named Focus-mode mapping
- Mac App Store / public Play listing
- Marketing / Next.js site
- Silent programmatic Shortcut generation / parsing Focus JSON
- Companion-device WATCH profile
- Open source
- Durable queue while the forwarder is down
- Multi-device beyond one pair
- Mac **SSE / WebSocket / long-poll** (the dropped live socket)
- Always-on **relay** whose job is to hold that socket
- Extra realtime vendors (Pusher, Ably, ntfy)
- Shared native crypto core (Rust/C)
- Flutter / Electron / KMP as the client shell
- APNs `.p8` or Firebase service-account JSON shipped inside a client

## 11. Still open

- A shorter public name later (v1 ships as **Mac & Android DND Sync**)
- Calendar dates / milestones (finish line is dogfood, not a date)
- Exact notification copy for failed Android off
- Which Mac Focus is the default “on” target if the user has renamed or
  removed system Do Not Disturb
- Exact LAN timeout before cloud fallback
- Bonjour service type string (`_dndsync._tcp` is what Phase 4 shipped)
- Push-forwarder **vendor** (Workers vs Cloud Functions vs other) — role
  is locked (request/response, FCM + APNs), brand is not
- Managed store brand (Neon vs KV vs other) — stores tokens + pair hash,
  never DND state
