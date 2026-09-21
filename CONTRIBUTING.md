# Contributing

CI, release, and signing live here. Day-to-day build, test, and live-check
commands are in [AGENTS.md](AGENTS.md). The consumer install path is
[README.md](README.md).

## CI

`.github/workflows/ci.yml` runs on every pull request: a Linux job (proto +
`buf lint` + Android unit tests + forwarder typecheck/tests, `npm ci`) and a
macOS job (`test-mac`, unsigned, `CODE_SIGNING_ALLOWED=NO`) on GitHub's
`macos-26` runner. Neither job touches a real device, sends a real push,
or runs `firebase deploy`. Those stay the manual
[Live checks](AGENTS.md#live-checks) until off-LAN CD is an explicit,
OIDC-gated decision. Turn on required status checks for both jobs under
branch protection so `main` can't merge red.

`.github/workflows/release.yml` is a separate, more privileged workflow.
See [Ship](#ship) below. It only ever runs on a version-tag push, never on
a pull request, so a fork PR can't reach its signing secrets.

## Ship

This is the **dogfood** path: a notarized Mac `.dmg` and a signed Android
`.apk`, built and attached to a GitHub Release automatically when you push a
version tag. It does not cover the App Store or a Play Store listing. Those
need their own store-listing/review work on top of this.

### One-time setup

1. Build the signing material locally first. This proves it works before
   CI ever touches it, and CI reuses these exact files and passwords:
   - A Developer ID Application certificate for the team in
     `apps/macos/ExportOptions-DeveloperID.plist` (`teamID`) in your
     keychain (Xcode → Settings → Accounts → Manage Certificates).
   - Notarization credentials, stored once in the keychain (`<team-id>` is
     the same `teamID` from that plist):
     `xcrun notarytool store-credentials dndsync-notary --apple-id you@example.com --team-id <team-id> --password <app-specific password>`
     (the app-specific password comes from
     [appleid.apple.com](https://appleid.apple.com)).
   - `make android-keystore` generates `apps/android/release.keystore.jks`
     once and writes its password into `apps/android/local.properties`
     (gitignored). **Back up the `.jks` file and that password somewhere
     safe.** Lose them and no future release can update an existing
     install without users uninstalling first.
   - Try both locally end to end: `make dmg-mac` and
     `make build-android-release`.
2. Export that same signing material as repo secrets so
   `.github/workflows/release.yml` can reuse it. The comment block at the
   top of that file spells out exactly which secret holds what and how to
   produce it (`MACOS_CERTIFICATE_P12_BASE64`, `MACOS_CERTIFICATE_PASSWORD`,
   `MACOS_KEYCHAIN_PASSWORD`, `APPLE_TEAM_ID`, `NOTARY_APPLE_ID`,
   `NOTARY_APP_SPECIFIC_PASSWORD`, `MACOS_PROVISIONING_PROFILE_BASE64`,
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_ALIAS`, `FORWARDER_APP_KEY`,
   `ANDROID_GOOGLE_SERVICES_JSON_BASE64`). Push Notifications on the Mac
   app means CI also needs a **Developer ID** provisioning profile for
   `com.dndsync.macos` (Apple Developer → Profiles → Developer ID). Encode
   it with `base64 -i Profile.provisionprofile | pbcopy`. CI writes that
   profile name into `apps/macos/DNDSync/CI-signing.xcconfig` (included
   only by the DNDSync Release target) rather than an `xcodebuild`
   override, so SwiftProtobuf is not asked to use a provisioning profile
   it doesn't support. The same name is injected into a copy of
   `ExportOptions-DeveloperID-CI.plist` at export time; without that
   mapping, `exportArchive` fails with "requires a provisioning profile
   with the Push Notifications feature."

   The Mac QR step creates a pair against the live forwarder, so the
   Release binary needs the same `appKey` you already have in
   `ForwarderSecrets.local.swift`. Add it as `FORWARDER_APP_KEY` (optional
   `FORWARDER_BASE_URL` if you are not on the default
   `europe-west1-dnd-sync-2a05c` URL). Without it, CI used to copy the
   empty example file and ship a DMG whose QR step only said "Couldn't
   start pairing. Check the internet." `make dmg-mac` now fails closed if
   those fields are empty. Encode the Android Firebase config the same
   way: `base64 -i apps/android/app/google-services.json | pbcopy` into
   `ANDROID_GOOGLE_SERVICES_JSON_BASE64`, or the release APK never
   registers FCM.
3. Create a GitHub **Environment** named `release` (repo Settings →
   Environments) and add yourself as a **required reviewer**. Every release
   run then pauses for a manual approval before it can touch any secret.
   A compromised token or Action still can't ship silently.

### Every release

`make release VERSION=0.1.0` is the command that starts a ship. It syncs
the marketing version across the Mac app, Android app, and Node packages
(`forwarder`, `scripts/fcm-send`, `scripts/apns-send`), writes `VERSION`,
opens a `release/v0.1.0` branch, commits, tags `v0.1.0`, pushes the branch
and tag, and opens a pull request into `main`. Pushing the tag is the only
thing that starts `release.yml`. It never runs on a pull request, so a fork
PR cannot reach the secrets above.

1. Redeploy the forwarder first if this release touches it (`make deploy`).
   Old and new clients must both keep working against it.
2. From a clean `main`: `make release VERSION=0.1.0`. `DRY_RUN=1` prints
   the plan without writing, and `NO_PUSH=1` commits and tags locally.
3. Approve the `release` environment on the Actions run when prompted. The
   workflow then archives, notarizes, and staples the Mac app, packages a
   compact Applications-drop `.dmg`, signs the Android `.apk`, and
   publishes both as assets on a new GitHub Release named after the tag.

`make dmg-mac` / `make build-android-release` still work standalone anytime
you want a local build without pushing a tag. CI runs those exact targets,
just with secrets instead of your keychain/`local.properties`. Run
`make release-check` to verify the version files already match.

### Things that break the ship if skipped

- The Release build uses `DNDSync-Release.entitlements`
  (`aps-environment: production`), not the Debug entitlements
  (`development`). A production APNs token only works if the forwarder's
  `APNS_HOST` secret is also `https://api.push.apple.com`, not the sandbox
  host. Don't flip one without the other.
- A release-signed Android build uses a different certificate than the debug
  keystore Android Studio uses, so **Firebase needs this release keystore's
  SHA-1/SHA-256 fingerprints added too** (`keytool -list -v -keystore
  apps/android/release.keystore.jks`, then Firebase console → Project
  settings → your Android app) or FCM silently stops working in release
  builds only.
- `FORWARDER_APP_KEY` and `ANDROID_GOOGLE_SERVICES_JSON_BASE64` are not
  signing secrets. Skip them and the GitHub-built `.dmg` cannot start
  pairing (empty `ForwarderSecrets.local.swift`) and the `.apk` cannot
  register FCM. `make dmg-mac` / the Android restore step now fail the
  job instead of shipping that. You still have to add the secrets once.

Not automated on purpose: creating the Developer ID certificate and Apple ID
app-specific password themselves, the Android keystore's key material
(generated once, yours to safeguard), the `release` environment's reviewer
list, and any Play Console / App Store listing work. Those stay one-time,
human, account-bound steps.
