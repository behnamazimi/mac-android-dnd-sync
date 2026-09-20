# Phase 0 — Monorepo scaffold

Status: plan only (not implemented).
Source: `handoff-v4.md` §6.1, §6.4, §9 Phase 0.
Last updated: 2026-09-16

This is the locked implementation plan for Phase 0. Later phases stay out of
this file except as “not in Phase 0.” Do not pretend the product works when
this phase is done.

## 1. Goal / non-goals

**Goal:** one private monorepo that later phases can land in. Scaffold **Mac &
Android DND Sync** so Phase 1+ files have a home.

**Exit is** “builds and launches,” **not** “syncs DND.”

**Non-goals:** pairing, E2E crypto, LAN, FCM, Postgres, VPS deploy, Focus /
Shortcuts, Zen rules, menu bar, settings, product chrome, inner/outer envelopes
beyond a `Ping` stub.

If the scaffold is painful, fix the repo in this phase — not after two
harnesses.

## 2. Layout (locked)

```
/
  README.md
  apps/macos/                 # empty SwiftUI app, macOS 14+
  apps/android/               # empty Compose + Hilt, API 35+
  relay/                      # Hono on Node 22, GET /health
    Dockerfile
    docker-compose.yml
    Caddyfile                 # files exist; no VPS
  proto/                      # Ping stub + Buf/protoc config
  scripts/generate-proto.sh   # local codegen gate
```

Docker Compose + Caddy live under `relay/` (or `relay/deploy/` if that keeps
the Node app root cleaner). They are **files only** — no VPS, no Postgres, no
FCM.

## 3. Locked choices

| Area | Choice |
| --- | --- |
| Product name | Mac & Android DND Sync |
| Short label | DND Sync (Mac window title / Android launcher for now) |
| Repo | One private monorepo; four trees above |
| Mac | Swift, SwiftUI App, deployment target **macOS 14**. Window is enough. |
| Android | Kotlin, Jetpack Compose, Material 3, **Hilt**. `minSdk` / `compileSdk` / `targetSdk` **35**. |
| Relay | **Hono** on **Node 22**, TypeScript. Not Bun, not Next.js, not Vercel. |
| Health | `GET /health` → 200 JSON `{ "ok": true }` |
| Proto | `proto3`, package `dndsync.v1`, message `Ping` only |
| Codegen | Buf **or** `protoc`, invoked by **local** `scripts/generate-proto.sh` (CI optional) |
| Deploy | Compose + Caddy files exist; **do not** deploy |

## 4. Work items

Ordered. Check off during implementation.

### 4.1 Repo hygiene

- [ ] Root `.gitignore` covering Xcode, Android/Gradle, Node, generated proto if not committed, `.env`, OS junk.
- [ ] Do **not** add pairing secrets, Firebase configs, or Postgres URLs.

### 4.2 Proto (`/proto`)

- [ ] `syntax = "proto3"`; package `dndsync.v1`.
- [ ] Single message, e.g. `message Ping { string message = 1; }`.
- [ ] Buf or `protoc` config that emits **Swift** and **Kotlin**.
- [ ] `scripts/generate-proto.sh` from repo root; must succeed on a clean machine with documented tools.
- [ ] Document generated output paths in README, e.g.:
  - Swift → `apps/macos/Generated/` (or equivalent, added to the Xcode project)
  - Kotlin → Android Gradle proto module **or** `apps/android/.../generated`
- [ ] Apps need not **call** `Ping` yet; generation must succeed so Phase 4 does not invent two codecs.

### 4.3 Mac (`/apps/macos`)

- [ ] New Xcode SwiftUI App project, deployment target **macOS 14**.
- [ ] One window with placeholder text (e.g. “DND Sync”).
- [ ] Bundle display name / accessibility name: **DND Sync**.
- [ ] Menu bar, `LSUIElement`, Focus, Shortcuts, Keychain, Network.framework: **not this phase**.

### 4.4 Android (`/apps/android`)

- [ ] Kotlin + Compose + Material 3 + **Hilt** wired for real (`@HiltAndroidApp` Application, `@AndroidEntryPoint` Activity).
- [ ] `minSdk` / `compileSdk` / `targetSdk` **35**.
- [ ] Empty screen (placeholder text is enough).
- [ ] DND, FCM, NSD: **not this phase**.

### 4.5 Relay (`/relay`)

- [ ] Hono + Node 22 + TypeScript.
- [ ] `package.json` scripts: `dev`, `start`.
- [ ] `GET /health` → `{ "ok": true }` (or equivalent 200 JSON).
- [ ] `Dockerfile` + `docker-compose.yml` + `Caddyfile` reverse-proxying to the Node process. Compose may omit Caddy for the exit check; Caddy files must still exist.
- [ ] No Postgres, firebase-admin, SSE, or pair routes.

### 4.6 README (root)

- [ ] Prerequisites: Xcode (macOS 14 SDK), Android Studio / JDK, Node 22, Buf or protoc.
- [ ] How to generate proto (`scripts/generate-proto.sh`).
- [ ] How to run relay locally and hit `GET /health`.
- [ ] How to open/build the Mac app and the Android app.
- [ ] No pairing, E2E, or product UX copy.

## 5. Exit criteria

All must be true:

1. Four trees exist: `apps/macos`, `apps/android`, `relay`, `proto`.
2. Mac app installs and launches a blank window.
3. Android app installs and launches a blank screen.
4. `scripts/generate-proto.sh` produces Swift + Kotlin from `/proto`.
5. Relay `GET /health` returns 200 locally (`npm run dev` and/or compose).

## 6. Out of scope (not Phase 0)

- QR pairing, `relay_secret`, build-time app key
- E2E (X25519 / HKDF / AES-GCM), Keychain, Keystore
- LAN (Bonjour / NsdManager / TCP)
- FCM, Postgres, VPS deploy
- Mac Shortcuts / `_NSDoNotDisturbEnabledNotification`
- Android `AutomaticZenRule` / interruption-filter harness
- Menu bar product UI, first-run wizard, settings
- Cloud envelope, last-write-wins, echo suppression
- Any protobuf besides `Ping`

## 7. After this phase

Implement the scaffold per this file. Then Phase 1 (Android DND harness), then
Phase 2 (Mac Focus harness). Do not skip to a finished client or a real relay.
