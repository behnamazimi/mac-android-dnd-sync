.DEFAULT_GOAL := help
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PROJECT ?= dnd-sync-2a05c
REGION ?= europe-west1
FUNCTION_URL ?= https://$(REGION)-$(PROJECT).cloudfunctions.net/api
DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
TOKEN ?=
CMD ?= on
P8 ?= scripts/apns-send/AuthKey.p8
VERSION ?=
NOTARY_PROFILE ?= dndsync-notary
MAC_TEAM_ID := MVSF9NZ97S
MAC_BUILD_DIR := build/mac
MAC_ARCHIVE := $(MAC_BUILD_DIR)/DNDSync.xcarchive
MAC_EXPORT := $(MAC_BUILD_DIR)/export
EXPORT_OPTIONS_PLIST := apps/macos/ExportOptions-DeveloperID.plist
ifeq ($(CI),true)
EXPORT_OPTIONS_PLIST := apps/macos/ExportOptions-DeveloperID-CI.plist
endif
ANDROID_KEYSTORE ?= apps/android/release.keystore.jks
ANDROID_KEY_ALIAS ?= dndsync-release

export DEVELOPER_DIR
export PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)

.PHONY: help doctor bootstrap proto \
	install-forwarder install-fcm build-forwarder \
	secrets-print secrets-local-mac secrets-apns-p8 secrets-set \
	test test-mac test-android test-forwarder \
	build-mac build-android \
	loopback-on loopback-off \
	apns apns-on apns-off fcm fcm-on fcm-off \
	health smoke logs deploy deploy-rules firebase-use \
	release release-check archive-mac export-mac notarize-mac dmg-mac ship-mac \
	android-keystore build-android-release ship-android

help:
	@printf '%s\n' \
		'Mac & Android DND Sync' \
		'' \
		'Usage:  make <target>' \
		'Vars:   TOKEN=…  CMD=on|off  PROJECT=$(PROJECT)' \
		'' \
		'Setup' \
		'  doctor                Check local tools + gitignored files (never prints secrets)' \
		'  bootstrap             proto + npm ci (forwarder, fcm-send) + copy Mac secrets template' \
		'  proto                 Generate protobuf stubs (Mac, Android, forwarder) + buf lint' \
		'  install-forwarder     npm ci (or install) in forwarder/' \
		'  install-fcm           npm ci (or install) in scripts/fcm-send/' \
		'  secrets-print         Print a new pair_secret, hash, and app key' \
		'  secrets-local-mac     Copy ForwarderSecrets.local.swift from the example' \
		'  secrets-set           Prompt for the 5 remaining Function secrets (never echoed)' \
		'  secrets-apns-p8       Set APNS_P8 from $(P8) (then make deploy)' \
		'' \
		'Build / test' \
		'  build-mac             Debug-build the Mac harness' \
		'  build-android         assembleDebug' \
		'  build-forwarder       tsc the Cloud Function' \
		'  test                  Mac + Android unit tests + forwarder tests' \
		'  test-mac              xcodebuild test DNDSync' \
		'  test-android          Gradle testDebugUnitTest' \
		'  test-forwarder        tsc --noEmit + tsc + node --test' \
		'' \
		'Phase 3  FCM bypass (needs a real FCM token — Firebase console' \
		'         "Cloud Messaging" test-device registration, not Diagnostics)' \
		'  fcm TOKEN=…           Send command=$(CMD) (default on)' \
		'  fcm-on TOKEN=…        Same with on' \
		'  fcm-off TOKEN=…       Same with off' \
		'' \
		'Phase 3  Mac loopback (Debug harness must be running)' \
		'  loopback-on           POST http://127.0.0.1:8787/on' \
		'  loopback-off          POST http://127.0.0.1:8787/off' \
		'' \
		'Phase 5  APNs bypass (Mac hex token, Xcode Debug)' \
		'  apns TOKEN=…          Send silent command=$(CMD) (needs APNS_KEY_ID/TEAM_ID)' \
		'  apns-on TOKEN=…       Same with on' \
		'  apns-off TOKEN=…      Same with off' \
		'' \
		'Phase 6  forwarder' \
		'  firebase-use          firebase use $(PROJECT)' \
		'  deploy                Deploy functions + Firestore rules' \
		'  deploy-rules          Deploy Firestore rules only' \
		'  health                GET $(FUNCTION_URL)/health' \
		'  smoke                 health + confirm an unauthenticated join is rejected (401)' \
		'  logs                  Tail Cloud Function logs' \
		'' \
		'Ship (dogfood: notarized DMG + signed APK, no App Store/Play listing)' \
		'  release VERSION=…           Sync versions, branch, commit, tag, push' \
		'                              (DRY_RUN=1 prints the plan; NO_PUSH=1 skips push)' \
		'  release-check               Verify Mac, Android, and package versions match' \
		'  archive-mac                 xcodebuild archive (Release)' \
		'  export-mac                  Export Developer ID .app from the archive' \
		'  notarize-mac                Submit to Apple + wait + staple (needs one-time' \
		'                               xcrun notarytool store-credentials $(NOTARY_PROFILE))' \
		'  dmg-mac                     archive → export → notarize → build/mac/*.dmg' \
		'  ship-mac                    Alias for dmg-mac' \
		'  android-keystore            Generate apps/android/release.keystore.jks (once)' \
		'  build-android-release       android-keystore + assembleRelease (signed APK)' \
		'  ship-android                Alias for build-android-release'

# --- Doctor / bootstrap ---

doctor:
	@printf 'Doctor (presence and versions only — never prints secret contents)\n\n'
	@fail=0; warn=0; \
	if [ -d "$(DEVELOPER_DIR)" ]; then printf '[ok]   Xcode.app at %s\n' "$(DEVELOPER_DIR)"; \
	else printf '[fail] No full Xcode at %s (xcodebuild/build-mac/test-mac need it, not just Command Line Tools)\n' "$(DEVELOPER_DIR)"; fail=1; fi; \
	if command -v buf >/dev/null 2>&1; then printf '[ok]   buf: %s (generate uses remote BSR plugins — repeated runs can hit rate limits)\n' "$$(buf --version)"; \
	else printf '[fail] buf not on PATH — https://buf.build/docs/installation\n'; fail=1; fi; \
	if command -v node >/dev/null 2>&1; then \
		nv="$$(node --version)"; \
		case "$$nv" in v26.*) printf '[ok]   node %s\n' "$$nv" ;; \
		*) printf '[warn] node %s (repo targets Node 26 — see .nvmrc)\n' "$$nv"; warn=1 ;; esac; \
	else printf '[fail] node not on PATH\n'; fail=1; fi; \
	if command -v java >/dev/null 2>&1; then \
		jv="$$(java -version 2>&1 | head -1)"; \
		case "$$jv" in *'"17'*|*'"21'*) printf '[ok]   java: %s\n' "$$jv" ;; \
		*) printf '[warn] java: %s (Gradle 8.11 needs 17 or 21, not 25)\n' "$$jv"; warn=1 ;; esac; \
	else printf '[warn] java not on PATH (needed for Gradle)\n'; warn=1; fi; \
	if command -v firebase >/dev/null 2>&1; then printf '[ok]   firebase-tools: %s\n' "$$(firebase --version)"; \
	else printf '[warn] firebase CLI not on PATH — needed for make deploy/health/logs\n'; warn=1; fi; \
	printf '\nGitignored files (presence only):\n'; \
	for f in apps/android/app/google-services.json \
		scripts/fcm-send/firebase-service-account.json \
		$(P8) \
		apps/macos/DNDSync/ForwarderSecrets.local.swift; do \
		if [ -f "$$f" ]; then printf '[ok]   %s present\n' "$$f"; \
		else printf '[--]   %s missing (see README Set up)\n' "$$f"; warn=1; fi; \
	done; \
	if [ -f apps/macos/DNDSync/ForwarderSecrets.local.swift ]; then \
		empties="$$(grep -c '= ""' apps/macos/DNDSync/ForwarderSecrets.local.swift || true)"; \
		if [ "$$empties" -gt 0 ]; then printf '[warn] ForwarderSecrets.local.swift has %s empty field(s) — it compiles, but Mac cloud path stays disabled\n' "$$empties"; warn=1; fi; \
	fi; \
	printf '\nShip readiness (only needed for make dmg-mac / build-android-release — never blocks doctor):\n'; \
	printf '[--]   notarytool credential profile "%s" — no reliable way to check presence here;\n' "$(NOTARY_PROFILE)"; \
	printf '       if dmg-mac fails at the submit step, run: xcrun notarytool store-credentials %s ...\n' "$(NOTARY_PROFILE)"; \
	if [ -f "$(ANDROID_KEYSTORE)" ]; then printf '[ok]   %s present\n' "$(ANDROID_KEYSTORE)"; \
	else printf '[--]   %s missing — run: make android-keystore\n' "$(ANDROID_KEYSTORE)"; fi; \
	printf '\nOpen apps/android (not the repo root) in Android Studio.\n'; \
	if [ "$$fail" = "1" ]; then printf '\nMissing required tools — see [fail] lines above.\n'; exit 1; \
	elif [ "$$warn" = "1" ]; then printf '\nNothing blocking, but see [warn] lines above.\n'; \
	else printf '\nLooks good.\n'; fi

bootstrap: proto install-forwarder install-fcm secrets-local-mac
	@printf '\nBootstrap done: stubs generated, forwarder + fcm-send deps installed,\n'
	@printf 'ForwarderSecrets.local.swift exists (fill it in — see README Forwarder).\n'
	@printf 'Run "make doctor" to see what else is still missing.\n'

# --- Proto ---

proto:
	FORCE_PROTO=1 ./scripts/generate-proto.sh

# --- Install ---

install-forwarder:
	@if [ -f forwarder/package-lock.json ]; then npm ci --prefix forwarder; \
	else npm install --prefix forwarder; fi

install-fcm:
	@if [ -f scripts/fcm-send/package-lock.json ]; then npm ci --prefix scripts/fcm-send; \
	else npm install --prefix scripts/fcm-send; fi

build-forwarder: proto install-forwarder
	forwarder/node_modules/.bin/tsc -p forwarder/tsconfig.json

# --- Secrets ---

secrets-print:
	@pair="$$(openssl rand -hex 32)"; \
	app="$$(openssl rand -hex 16)"; \
	hash="$$(printf '%s' "$$pair" | shasum -a 256 | awk '{print $$1}')"; \
	printf 'PAIR_SECRET=%s\nAPP_KEY=%s\nDEV_PAIR_SECRET_HASH=%s\n' "$$pair" "$$app" "$$hash"; \
	printf '\nPut PAIR_SECRET and APP_KEY in ForwarderSecrets.local.swift (Mac only —\n'; \
	printf 'Android has no secrets of its own, it joins by scanning the Mac QR).\n'; \
	printf 'Set the hash and APP_KEY as Function secrets (make secrets-set), then:\n'; \
	printf 'make secrets-apns-p8 && make deploy\n'

secrets-local-mac:
	@test -f apps/macos/DNDSync/ForwarderSecrets.local.swift || \
		cp apps/macos/DNDSync/ForwarderSecrets.local.swift.example \
			apps/macos/DNDSync/ForwarderSecrets.local.swift
	@printf 'Edit apps/macos/DNDSync/ForwarderSecrets.local.swift\n'

secrets-apns-p8:
	@test -f "$(P8)" || { printf 'Missing %s\n' "$(P8)" >&2; exit 1; }
	firebase functions:secrets:set APNS_P8 --project $(PROJECT) < "$(P8)"
	@printf 'Redeploy so the function picks up the new secret version: make deploy\n'

secrets-set:
	@printf 'Prompting for the 5 remaining Function secrets. Values are never echoed\n'
	@printf 'or logged; each is piped straight to "firebase functions:secrets:set".\n'
	@printf 'Leave DEV_PAIR_SECRET_HASH blank to skip it (disables 6.A auto-seed).\n\n'
	@for name in DEV_PAIR_SECRET_HASH APNS_KEY_ID APNS_TEAM_ID APNS_HOST APP_KEY; do \
		printf '%s: ' "$$name"; \
		read -r value; \
		if [ -z "$$value" ]; then printf '  skipped\n'; continue; fi; \
		printf '%s' "$$value" | firebase functions:secrets:set "$$name" --project $(PROJECT); \
	done
	@printf '\nRedeploy so the function picks up the new secret versions: make deploy\n'

# --- Build ---

# No `proto` prerequisite here: the Xcode "Generate Proto" build phase and
# the Gradle `generateProto` task (a `preBuild` dependency) already do it.
# Adding it again here would double every `buf generate` call against the
# BSR remote plugins and makes hitting their rate limit more likely
# (https://buf.build/docs/bsr/rate-limits/) — see README Generate.
build-mac:
	xcodebuild -project apps/macos/DNDSync.xcodeproj -scheme DNDSync \
		-configuration Debug -destination 'platform=macOS' build

build-android:
	cd apps/android && ./gradlew :app:assembleDebug

# --- Tests ---

test: test-mac test-android test-forwarder

test-mac:
	xcodebuild -project apps/macos/DNDSync.xcodeproj -scheme DNDSync \
		-configuration Debug -destination 'platform=macOS' test

test-android:
	cd apps/android && ./gradlew :app:testDebugUnitTest

test-forwarder: proto install-forwarder
	forwarder/node_modules/.bin/tsc -p forwarder/tsconfig.json --noEmit
	forwarder/node_modules/.bin/tsc -p forwarder/tsconfig.json
	find forwarder/lib -name '*.test.js' -print0 | xargs -0 node --test

# --- Phase 3 loopback ---

loopback-on:
	curl -fsS -X POST http://127.0.0.1:8787/on
	@printf '\n'

loopback-off:
	curl -fsS -X POST http://127.0.0.1:8787/off
	@printf '\n'

# --- Phase 3 FCM ---

fcm:
	$(MAKE) fcm-$(CMD)

fcm-on fcm-off:
	@test -n "$(TOKEN)" || { printf 'Set TOKEN=<fcm-token>\n' >&2; exit 1; }
	node scripts/fcm-send/send.mjs "$(TOKEN)" $(@:fcm-%=%)

# --- Phase 5 APNs ---

apns:
	$(MAKE) apns-$(CMD)

apns-on apns-off:
	@test -n "$(TOKEN)" || { printf 'Set TOKEN=<apns-hex-token>\n' >&2; exit 1; }
	@test -n "$${APNS_KEY_ID:-}" || { printf 'Export APNS_KEY_ID\n' >&2; exit 1; }
	@test -n "$${APNS_TEAM_ID:-}" || { printf 'Export APNS_TEAM_ID\n' >&2; exit 1; }
	node scripts/apns-send/send.mjs "$(TOKEN)" $(@:apns-%=%)

# --- Phase 6 ---

firebase-use:
	firebase use $(PROJECT)

deploy: install-forwarder
	firebase deploy --only functions,firestore:rules --project $(PROJECT)

deploy-rules:
	firebase deploy --only firestore:rules --project $(PROJECT)

health:
	curl -fsS "$(FUNCTION_URL)/health"
	@printf '\n'

smoke: health
	@printf 'Confirming an unauthenticated join is rejected...\n'
	@code="$$(curl -s -o /dev/null -w '%{http_code}' -X POST \
		-H 'Authorization: Bearer not-a-real-secret' \
		-H 'Content-Type: application/json' \
		-d '{"sender":"mac","platform":"apns","token":"x"}' \
		"$(FUNCTION_URL)/v1/pairs/dndsync-smoke-check/join")"; \
	if [ "$$code" = "401" ]; then printf '[ok]   unauthenticated join rejected (401)\n'; \
	else printf '[fail] expected 401, got %s\n' "$$code" >&2; exit 1; fi

logs:
	firebase functions:log --project $(PROJECT) --only api -n 50

# --- Ship (dogfood: notarized DMG + signed APK) ---
#
# Not automated on purpose: creating the Developer ID certificate itself,
# the notarytool credential profile, and the Android keystore's *passwords*
# (generated once, then yours to keep) — see README Ship.

RELEASE_FLAGS :=
ifeq ($(DRY_RUN),1)
RELEASE_FLAGS += --dry-run
endif
ifeq ($(NO_PUSH),1)
RELEASE_FLAGS += --no-push
endif

release:
	@test -n "$(VERSION)" || { printf 'Usage: make release VERSION=0.2.0\n' >&2; exit 1; }
	./scripts/release.sh "$(VERSION)" $(RELEASE_FLAGS)

release-check:
	./scripts/release.sh --check

archive-mac:
	rm -rf $(MAC_ARCHIVE)
	@if [ -n "$${CI:-}" ]; then \
		test -n "$${MACOS_PROFILE_SPECIFIER:-}" || { \
			printf 'CI archive needs MACOS_PROFILE_SPECIFIER. Set MACOS_PROVISIONING_PROFILE_BASE64 on the release environment.\n' >&2; \
			exit 1; \
		}; \
		xcodebuild -project apps/macos/DNDSync.xcodeproj -scheme DNDSync \
			-configuration Release -destination 'generic/platform=macOS' \
			-archivePath $(MAC_ARCHIVE) archive \
			CODE_SIGN_STYLE=Manual \
			CODE_SIGN_IDENTITY="Developer ID Application" \
			DEVELOPMENT_TEAM=$(MAC_TEAM_ID) \
			PROVISIONING_PROFILE_SPECIFIER="$$MACOS_PROFILE_SPECIFIER"; \
	else \
		xcodebuild -project apps/macos/DNDSync.xcodeproj -scheme DNDSync \
			-configuration Release -destination 'generic/platform=macOS' \
			-archivePath $(MAC_ARCHIVE) archive; \
	fi

export-mac: archive-mac
	rm -rf $(MAC_EXPORT)
	xcodebuild -exportArchive -archivePath $(MAC_ARCHIVE) \
		-exportPath $(MAC_EXPORT) \
		-exportOptionsPlist $(EXPORT_OPTIONS_PLIST)

notarize-mac: export-mac
	@ditto -c -k --keepParent "$(MAC_EXPORT)/DNDSync.app" "$(MAC_BUILD_DIR)/DNDSync-notarize.zip"
	@if [ -n "$${NOTARY_APPLE_ID:-}" ] && [ -n "$${NOTARY_TEAM_ID:-}" ] && [ -n "$${NOTARY_PASSWORD:-}" ]; then \
		echo "Notarizing with explicit credentials (CI path — no keychain profile available)"; \
		xcrun notarytool submit "$(MAC_BUILD_DIR)/DNDSync-notarize.zip" \
			--apple-id "$$NOTARY_APPLE_ID" --team-id "$$NOTARY_TEAM_ID" --password "$$NOTARY_PASSWORD" --wait; \
	else \
		xcrun notarytool submit "$(MAC_BUILD_DIR)/DNDSync-notarize.zip" \
			--keychain-profile "$(NOTARY_PROFILE)" --wait; \
	fi
	xcrun stapler staple "$(MAC_EXPORT)/DNDSync.app"
	@rm -f "$(MAC_BUILD_DIR)/DNDSync-notarize.zip"

dmg-mac: notarize-mac
	@version="$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
		"$(MAC_EXPORT)/DNDSync.app/Contents/Info.plist")"; \
	name="Mac-Android-DND-Sync-$$version.dmg"; \
	rm -f "$(MAC_BUILD_DIR)/$$name"; \
	hdiutil create -volname "DND Sync" -srcfolder "$(MAC_EXPORT)/DNDSync.app" \
		-ov -format UDZO "$(MAC_BUILD_DIR)/$$name"; \
	printf 'Built %s/%s\n' "$(MAC_BUILD_DIR)" "$$name"

ship-mac: dmg-mac

android-keystore:
	@if [ -f "$(ANDROID_KEYSTORE)" ]; then \
		printf '%s already exists\n' "$(ANDROID_KEYSTORE)"; \
		exit 0; \
	fi; \
	pass="$$(openssl rand -base64 24)"; \
	keytool -genkeypair -v -keystore "$(ANDROID_KEYSTORE)" \
		-alias $(ANDROID_KEY_ALIAS) -keyalg RSA -keysize 2048 -validity 10000 \
		-storepass "$$pass" -keypass "$$pass" \
		-dname "CN=DND Sync, OU=Dogfood, O=DND Sync, C=US"; \
	printf 'dndsync.release.storeFile=release.keystore.jks\n' >> apps/android/local.properties; \
	printf 'dndsync.release.storePassword=%s\n' "$$pass" >> apps/android/local.properties; \
	printf 'dndsync.release.keyAlias=$(ANDROID_KEY_ALIAS)\n' >> apps/android/local.properties; \
	printf 'dndsync.release.keyPassword=%s\n' "$$pass" >> apps/android/local.properties; \
	printf 'Wrote %s and its password into apps/android/local.properties (gitignored).\n' "$(ANDROID_KEYSTORE)"; \
	printf 'Back both up somewhere safe — losing them means future releases can never\n'; \
	printf 'update this same install without users uninstalling first.\n'

build-android-release:
	@if [ ! -f "$(ANDROID_KEYSTORE)" ]; then \
		printf 'Missing %s. Run make android-keystore once, or restore it in CI from secrets.\n' "$(ANDROID_KEYSTORE)" >&2; \
		exit 1; \
	fi
	cd apps/android && ./gradlew :app:assembleRelease
	@printf 'Signed APK: apps/android/app/build/outputs/apk/release/app-release.apk\n'

ship-android: build-android-release
