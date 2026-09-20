# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

Mac & Android DND Sync keeps Do Not Disturb / Focus state in sync between a
macOS menu-bar app and an Android app. Same Wi-Fi uses Bonjour/NSD for a
direct LAN connection. Off-LAN uses a request/response push forwarder (FCM to
Android, silent APNs to Mac) backed by a small Firebase Cloud Function. There
is no cloud relay of state and no persistent Mac socket. The cloud path is a
wake-and-pull, not a live channel. Firestore stores only pairing secrets and
push tokens, never an on/off bit.

The product surface is intentionally minimal: users flip the system DND
control on either device and the other follows. Neither app exposes a third,
app-level DND switch. See [README.md](README.md) for the consumer install and
pairing path. See [Live checks](#live-checks) for the phase-by-phase
acceptance criteria (Phase 3 loopback → Phase 4 LAN → Phase 5 APNs →
Phase 6 cloud forwarder → Phase 7 product chrome, which is where the repo
currently is).

## Layout

- `apps/macos/` — Swift/SwiftUI menu-bar app (`DNDSync.xcodeproj`). Source in
  `apps/macos/DNDSync/`, tests in `apps/macos/DNDSyncTests/`. Runs Shortcuts
  (`apps/macos/Shortcuts/*.shortcut`) to actually toggle system Focus.
- `apps/android/` — Kotlin/Compose app, package `com.dndsync.android`, under
  `apps/android/app/src/main/java/com/dndsync/android/`: `dnd/` (Zen rule
  control + FCM), `lan/` (Bonjour/NSD sync), `cloud/` (forwarder client, E2E
  crypto, pairing), `ui/` (screens/routing). Tests under `app/src/test/`.
- `proto/` — protobuf schemas (`dnd_state`, `cloud_envelope`, `ping`) shared
  by both apps and the forwarder. Compiled with Buf; **stubs are generated,
  not committed** (see below).
- `forwarder/` — TypeScript Firebase Cloud Function (`forwarder/src/`) that
  authenticates a pair, stores device push tokens, and fans out a
  `CloudEnvelope` over FCM/APNs. Deploys to Firebase project
  `dnd-sync-2a05c` (`europe-west1`).
- `scripts/apns-send/`, `scripts/fcm-send/` — standalone Node scripts for
  sending diagnostic pushes directly (bypass the forwarder), used for manual
  testing of each phase.
- `Makefile` — the canonical entry point for generate/build/test/deploy/
  diagnostic commands. Run `make help` before reaching for raw
  `xcodebuild`/`gradlew`/`firebase` invocations.

## Prerequisites

You need these tools before you build or generate code:

- Xcode with the macOS 14 SDK. Point `xcode-select` at Xcode.app and accept
  the license (`sudo xcodebuild -license`) if `xcodebuild` asks you to.
- Android Studio, plus JDK 17 or 21 for command-line Gradle. JDK 25 does not
  run Gradle 8.11.
- Node 26 (`.nvmrc` pins this). GitHub Actions reads the same file. The
  forwarder's Cloud Function runtime in `firebase.json` stays `nodejs22`
  until the Firebase CLI accepts `nodejs26`.
- [Buf](https://buf.build/docs/installation)
- The Firebase CLI, logged in with access to project `dnd-sync-2a05c`
  (`firebase login`), if you'll touch the forwarder.

Run `make doctor` any time to check which of the above are on `PATH`, and
which gitignored files below exist. It only reports presence and version,
never contents. Run `make bootstrap` once to generate protobuf stubs, `npm
ci` the forwarder and `scripts/fcm-send`, and copy the Mac secrets template.

Open `apps/android` (not the repository root) in Android Studio. It is the
Gradle root. Wait for Gradle sync, then run the **app** configuration on an
Android 15 (API 35) device or emulator.

These files are gitignored and not in this checkout; `make doctor` tells you
which are missing. They are described by **path**, not by contents. Get the
values from the console or teammate that owns that account, never from this
repo:

- `apps/android/app/google-services.json` — Firebase Android app config.
- `scripts/fcm-send/firebase-service-account.json` — Admin SDK key for the
  FCM diagnostic script.
- `scripts/apns-send/AuthKey.p8` — APNs signing key for the diagnostic
  script (`make secrets-apns-p8` also reads this path).
- `apps/macos/DNDSync/ForwarderSecrets.local.swift` — Mac's forwarder URL,
  app key, and (once created) pair secret. Xcode copies it from the
  `.example` file automatically on first build; `make secrets-local-mac`
  does the same from the command line. Empty fields still compile. The app
  shows "missing ForwarderSecrets.local.swift" in Settings/Diagnostics
  until you fill it in.

Android has no forwarder secrets of its own. It never reads
`local.properties` for pairing. It gets the forwarder URL, pair id/secret,
and Mac's E2E key entirely from scanning (or pasting) the Mac's QR code.

## Before building or editing app code

Generated protobuf stubs are required to compile either app and are
gitignored. If `apps/macos/Generated` or `apps/android/generated` look
missing or stale, run:

```sh
./scripts/generate-proto.sh
```

(or `make proto`). Do this before running tests or builds for the Mac or
Android app after touching anything in `proto/`.

Code generation is a local script, and also runs automatically as an Xcode
build phase ("Generate Proto") and a Gradle task (`generateProto`,
dependency of `preBuild`), so an IDE build regenerates stale stubs on its
own. Run it directly when you just want stubs without a full build. This
runs `buf lint` before `buf generate`. Output paths: Swift
(`apps/macos/Generated`), Java/Kotlin (`apps/android/generated`), TypeScript
(`forwarder/generated`). All three are gitignored.

Adding a new `.proto` message still needs one manual step on Mac: Xcode
tracks generated `*.pb.swift` files as individual project references, not a
synced folder, so a brand-new generated file needs to be added to the
project once (existing files regenerate in place with no extra step).
Android's Gradle `sourceSets` already watches the whole `generated/`
directory, so it needs nothing extra.

## Build, test, run

Prefer `make <target>` (`make help` lists everything, grouped by phase):

- `make test` — Mac unit tests + Android unit tests + forwarder typecheck.
- `make build-mac` / `make test-mac` — `xcodebuild` against the `DNDSync`
  scheme.
- `make build-android` / `make test-android` — Gradle `assembleDebug` /
  `testDebugUnitTest` in `apps/android`.
- `make test-forwarder` — `tsc --noEmit` in `forwarder/`.
- `make loopback-on` / `make loopback-off` — trigger the Mac's loopback-only
  dev listener (`127.0.0.1:8787`) directly.
- `make fcm TOKEN=… CMD=on|off`, `make apns TOKEN=… CMD=on|off` — send a
  diagnostic push bypassing the forwarder, for a specific device token.
- `make deploy` / `make health` / `make logs` — forwarder deploy and
  diagnostics against the live Firebase project.

Android needs JDK 17 or 21 for Gradle (not 25); Mac needs Xcode with the
macOS 14 SDK. See [Prerequisites](#prerequisites) for full setup.

`make test-mac` skips starting the `:8787` loopback listener when it
detects it's running inside the hosted XCTest process, so it no longer
fights a separately-running debug build for the port.

## First run as a developer

The Mac app is a menu-bar extra with no Dock icon. Open
`apps/macos/DNDSync.xcodeproj` in Xcode and run the **DND Sync** scheme, or
`make build-mac`. Generate protobuf stubs first if you're not building
through Xcode. Hardened Runtime is on; App Sandbox is off.

Click the menu-bar icon to open the current wizard step or status screen.
Closing the window hides it; the same step reappears on the next click.
Right-click the menu-bar icon for **Open** and **Quit** only. Settings and
Diagnostics live inside the app window (gear icon on Home, or **⌘,**).

The On and Off shortcuts live at:

- `apps/macos/Shortcuts/DND Sync On.shortcut`
- `apps/macos/Shortcuts/DND Sync Off.shortcut`

Each is a single **Set Focus** action for system **Do Not Disturb**. To
recreate them, build matching actions in Shortcuts.app with those exact
names, export the `.shortcut` files into that folder, and rebuild.

Wizard order: **Allow Shortcuts** (Automation prompt) → **Add the On
shortcut** → **Add the Off shortcut** → **Open at login** (skippable: a
fully quit Mac can't apply Focus from the phone) → **Scan this from the
phone** (Copy pairing code if the camera can't read the QR). Neither app is
on a store yet, so the QR step's own hint (with an inline **Download the
Android app** link) and Settings → **About** both point at the GitHub
Release page if Android isn't installed. After pairing, status shows
**Paired**, Do Not Disturb On/Off, and last error.

Diagnostics (Settings → **Advanced**, debug builds only) is the old harness
without secrets: pair status, permission bits, LAN lines, cloud lines, raw
Focus text, and Force On/Off test buttons. It never shows pair ids, pair
secrets, E2E keys, FCM tokens, or APNs tokens. Copy pairing code (the QR
step's own escape hatch) is the one place a secret is ever surfaced, and
it's a secret the moment you copy it.

Open `apps/android` (not the repository root). The launcher label is **DND
Sync**. The wall order is **Welcome → pair with the Mac's QR → Do Not
Disturb access → notifications → status**. You cannot reach a grant screen
until you've joined a pair, and resume returns to whichever grant is still
missing.

1. On the Mac, finish setup until a QR is visible. On the phone, tap **Scan
   QR code**, or **Paste pairing code instead** if you deny the camera or it
   can't read the QR. Joining needs the internet even on the same Wi-Fi.
   Neither app is on a store yet, so this screen and Settings → About also
   offer **Download the Mac app**, linking to the GitHub Release page.
2. Tap **Open Do Not Disturb access** and enable **DND Sync** in the system
   list, then return.
3. Tap **Allow notifications** (or **Open settings** if you denied
   permanently).
4. Status shows **Paired**, Do Not Disturb On/Off, and last error. Nearby
   devices access is optional after this. It only makes same-Wi-Fi sync
   faster.

Diagnostics (Settings → About → **Diagnostics**, debug builds only) never
shows pair ids, pair secrets, E2E keys, or the FCM token. Failed-off posts
one notification per incident and opens Modes settings.

## If you're stuck

- Empty `ForwarderSecrets.local.swift` values still compile; the cloud path
  just stays disabled until you fill them in.
- A missing `google-services.json` still builds the Android app; the Google
  services Gradle plugin only applies when that file exists, so FCM stays
  unregistered until you add it and rebuild.
- **Unpair** is not a full factory reset. It clears the pair, not: Mac
  Keychain login-item state, the "seen welcome" flag, Shortcuts.app entries,
  or Android's system DND access grant. To start clean, also remove those by
  hand.
- Closing a Mac window hides it; it does not quit the app (LAN, APNs, and
  the pair session keep running). Quit from the menu-bar right-click menu or
  ⌘Q.
- Reinstalling either app does not restore Keychain/Keystore pair keys.
  Re-scan the QR.

## Forwarder

The function lives in `forwarder/` and deploys to Firebase project
`dnd-sync-2a05c` in `europe-west1`.

```sh
make deploy          # functions + Firestore rules
make health           make smoke     # health, then confirm bad auth is rejected
make logs
```

Function secrets: `DEV_PAIR_SECRET_HASH`, `APNS_KEY_ID`, `APNS_TEAM_ID`,
`APNS_P8`, `APNS_HOST`, `APP_KEY`. `make secrets-set` prompts for the first
five one at a time without ever echoing or logging a value (leave
`DEV_PAIR_SECRET_HASH` blank to skip the 6.A auto-seed pair). `make
secrets-apns-p8` sets `APNS_P8` from `scripts/apns-send/AuthKey.p8`.
**Redeploy after changing any secret.** The function reads secret versions
at deploy time, not on every request.

`APNS_HOST` is `https://api.sandbox.push.apple.com` while the Mac app runs
from Xcode Debug, or `https://api.push.apple.com` once it runs from a
Developer ID (or App Store) export. Apple issues a different device token
per environment, and sending it to the wrong host fails closed
(`BadDeviceToken` / `BadEnvironmentKeyInToken`).

Firestore stores `secretHash` and device push tokens only, never an on/off
bit. Deleting a pair (`DELETE /v1/pairs/:pairId`, same bearer token as
`join`) already happens automatically when a client unpairs; there's no
separate admin script.

Release and CI notes live in [CONTRIBUTING.md](CONTRIBUTING.md).

## Live checks

These phases are living acceptance criteria, not just history. Each names
what a script can do for you and what still needs your eyes on a real
device.

- **Phase 3 — fake outside the device.** Android applies a Zen rule from a
  data-only FCM message while backgrounded with the screen off; Mac runs the
  Shortcut from a POST to loopback `127.0.0.1:8787` (dev-only, Debug builds
  only, not reachable from the LAN). `make loopback-on/off` drives the Mac
  side; `make fcm TOKEN=… CMD=on|off` drives Android (get a token from the
  Firebase console's test-device registration. Diagnostics deliberately
  never shows it). Must see: the Quick Settings DND tile or harness state
  flips; a manual-tile veto still fires the existing failed-off
  notification.
- **Phase 4 — same-Wi-Fi sync.** Bonjour/NSD finds the peer, one TCP
  connection carries a length-prefixed `DndState`. Must see: both apps show
  **connected** (not just advertising); flips in either direction follow
  within seconds; rapid flips or a vetoed Android off don't ping-pong.
- **Phase 5 — Mac APNs harness.** A scripted silent push
  (`content-available`, no banner/sound/badge) applies Focus the same way
  loopback does. `make apns TOKEN=… CMD=on|off` needs `APNS_KEY_ID` /
  `APNS_TEAM_ID` exported and a paid Apple team with Push Notifications
  enabled on `com.dndsync.macos`. Must see: Diagnostics shows **APNs:
  registered**; the push (not just loopback curl) flips Do Not Disturb.
- **Phase 6.A — forwarder, off-LAN.** Both apps registered against the
  deployed forwarder; a flip on one reaches the other in ~10s over cellular
  / off that Wi-Fi. Must see: Firestore has `secretHash` and both device
  tokens, no on/off field; breaking the URL fails closed with a cloud error,
  no retry storm; putting both devices back on the same Wi-Fi still works
  and doesn't ping-pong against the cloud path.
- **Phase 6.B — pairing and E2E.** Real QR/paste pairing replaces the
  hardcoded 6.A pair. Must see: ciphertext on the wire, not plaintext
  `DndState`; **Re-pair** invalidates the old bearer token (401).
- **Phase 7 — product chrome.** The wizard and status screen above are the
  exit criteria: no third app-level On/Off control on any product screen,
  On/Off test buttons only on Diagnostics, and Diagnostics only in debug
  builds.

## Working conventions

- Treat the [Live checks](#live-checks) as living acceptance criteria, not
  just history. Each phase documents exact manual verification steps (what
  Diagnostics should show, what must NOT ping-pong, what must fail closed).
  When touching sync/pairing/push logic, check the relevant phase section
  for the behavior it guarantees before changing it.
- Do not add a third, app-visible on/off DND toggle to either product
  surface. The system DND/Focus control is the only switch. On/Off test
  buttons belong only on the Diagnostics screen, and only in debug builds,
  never in release builds or on product/status screens.
- Firestore (via the forwarder) must never store DND on/off state, only
  `secretHash` and per-device push tokens. Don't add fields that leak state
  into the cloud store.
- Secrets stay out of git: `ForwarderSecrets.local.swift`, Android
  `local.properties` keys, `google-services.json`, the APNs `.p8`, and the
  Firebase service account JSON are all gitignored. Never commit them, and
  don't print their contents in logs or diagnostics UI.
- Mirror changes across platforms deliberately: LAN framing
  (`LengthPrefixedFramer`), the `CloudEnvelope`/`DndState` codecs, and E2E
  crypto exist in near-parallel Swift (`apps/macos/DNDSync/`) and Kotlin
  (`apps/android/.../lan/`, `.../cloud/`) implementations. A protocol-level
  change on one side almost always needs the matching change on the other.
- Run the platform-appropriate tests (`make test-mac`, `make test-android`,
  `make test-forwarder`) for whatever you touched before calling work done;
  `make test` runs all three.
